require 'mongoid'
require 'vidibus-uuid'
require 'active_support/core_ext'
require 'delayed_job_mongoid'

module Vidibus::Recording
  module Mongoid
    extend ActiveSupport::Concern

    included do
      include ::Mongoid::Timestamps
      include Vidibus::Uuid::Mongoid

      embeds_many :parts, :as => :recording, :class_name => 'Vidibus::Recording::Part'

      field :name
      field :stream
      field :pid, :type => Integer
      field :info, :type => Hash
      field :size, :type => Integer
      field :duration, :type => Integer
      field :error
      field :scheduled_at, :type => DateTime
      field :started_at, :type => DateTime
      field :stopped_at, :type => DateTime
      field :failed_at, :type => DateTime
      field :started, :type => Boolean, :default => false
      field :running, :type => Boolean, :default => false
      field :monitoring_job_identifier, :type => String

      index :started

      validates :name, :presence => true
      validates :stream, :format => {:with => /^rtmp.*?:\/\/.+$/}

      before_destroy :cleanup

      scope :started, where(started: true)
    end

    # Starts a recording worker now, unless it has been done already.
    # Provide a Time object to schedule start.
    def start(time = :now)
      return false if done? || started?
      if time == :now
        self.started_at = Time.now
        self.started = true
        start_worker
        start_monitoring_job
        save!
      else
        schedule(time)
      end
    end

    # Continue recording that is not running anymore.
    def resume
      return false if running? || !started?
      self.stopped_at = nil
      self.failed_at = nil
      start_worker
      start_monitoring_job
      save!
    end

    # Resets data and starts anew.
    def restart
      stop
      reset
      start
    end

    # Stops the recording worker and starts postprocessing.
    def stop
      return false if done? || !started?
      worker.stop
      self.pid = nil
      self.stopped_at = Time.now
      self.running = false
      self.started = false
      self.monitoring_job_identifier = nil
      postprocess
    end

    # Gets called from recording worker if it receives no more data.
    def halt(msg = nil)
      return false unless running?
      worker.stop
      self.pid = nil
      self.running = false
      postprocess
    end

    # Receives an error from recording worker and stores it.
    # The worker gets stopped and postprocessing is started.
    def fail(msg)
      return false unless running?
      worker.stop
      self.pid = nil
      self.error = msg
      self.failed_at = Time.now
      self.running = false
      self.started = false
      postprocess
    end

    # TODO: really a public method?
    # Removes all acquired data!
    def reset
      remove_files
      blank = {}
      [
        :started_at,
        :stopped_at,
        :failed_at,
        :info,
        :error,
        :size,
        :duration,
        :monitoring_job_identifier
      ].map {|a| blank[a] = nil }
      update_attributes!(blank)
      destroy_all_parts
    end

    # TODO: really a public method?
    # Returns an instance of the recording worker.
    def worker
      @worker ||= Vidibus::Recording::Worker.new(self)
    end

    # TODO: really a public method?
    # Returns an instance of a fitting recording backend.
    def backend
      @backend ||= Vidibus::Recording::Backend.load({
        :stream => stream,
        :file => current_part.data_file,
        :live => true
      })
    end

    # Returns true if recording has either been stopped or failed.
    def done?
      stopped? || failed?
    end

    # Returns true if recording has failed.
    def failed?
      !!failed_at
    end

    # Returns true if recording has been started.
    def started?
      !!started_at
    end

    def stopped?
      !!stopped_at
    end

    def has_data?
      size.to_i > 0
    end

    # Returns true if recording worker is still running.
    # Persists attributes accordingly.
    def worker_running?
      if worker.running?
        update_attributes(:running => true) unless running?
        true
      else
        update_attributes(:pid => nil, :running => false)
        false
      end
    end

    # Return folder to store recordings in.
    def folder
      @folder ||= begin
        f = ['recordings']
        f.unshift(Rails.root) if defined?(Rails)
        path = File.join(f)
        FileUtils.mkdir_p(path) unless File.exist?(path)
        path
      end
    end

    def basename
      "#{folder}/#{uuid}"
    end

    # Returns the log file name for this recording.
    def log_file
      @log_file ||= "#{basename}.log"
    end

    # Returns the file name of this recording.
    # DEPRECATED: this is kept for existing records only.
    def file
      @file ||= "#{basename}.rec"
    end

    # Returns the YAML file name for this recording.
    # DEPRECATED: this is kept for existing records only.
    def yml_file
      @yml_file ||= "#{basename}.yml"
    end

    def current_part
      parts.last
    end

    def track_progress
      current_part.track_progress if current_part
      set_size
      set_duration
      save!
    end

    private

    def destroy_all_parts
      parts.each do |part|
        part.destroy
      end
      self.update_attributes!(:parts => [])
    end

    def start_worker
      return if worker_running?
      setup_next_part
      worker.start
      self.running = true
      self.pid = worker.pid
    end

    # Start a new monitoring job
    def start_monitoring_job
      self.monitoring_job_identifier = Vidibus::Uuid.generate
      Vidibus::Recording::MonitoringJob.create({
        :class_name => self.class.to_s,
        :uuid => uuid,
        :identifier => monitoring_job_identifier
      })
    end

    def setup_next_part
      number = nil
      if current_part
        if current_part.has_data?
          number = current_part.number + 1
        else
          current_part.reset
        end
      else
        number = 1
      end
      if number
        parts.build(:number => number)
      end
      current_part.start
    end

    def schedule(time)
      self.delay(:run_at => time).start
    end

    def postprocess
      current_part.postprocess if current_part
      set_size
      set_duration
      save!
    end

    def set_size
      accumulate_parts(:size)
    end

    def set_duration
      accumulate_parts(:duration)
    end

    def accumulate_parts(attr)
      value = 0
      parts.each do |part|
        value += part.send(attr).to_i
      end
      self.send("#{attr}=", value)
    end

    def cleanup
      worker.stop
      remove_files
    end

    # DEPRECATED: this is kept for existing records only.
    def remove_files
      [file, log_file, yml_file].each do |f|
        File.delete(f) if File.exists?(f)
      end
    end
  end
end
