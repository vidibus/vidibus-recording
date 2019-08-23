# frozen_string_literal: true

require "mongoid"
require "vidibus-uuid"
require "active_support/core_ext"

module Vidibus::Recording
  module Mongoid
    extend ActiveSupport::Concern

    included do
      include ::Mongoid::Timestamps
      include Vidibus::Uuid::Mongoid

      embeds_many :parts, as: :recording, class_name: "Vidibus::Recording::Part"

      field :name, type: String
      field :stream, type: String
      field :pid, type: Integer
      field :info, type: Hash
      field :size, type: Integer
      field :duration, type: Integer
      field :error, type: String
      field :scheduled_at, type: DateTime
      field :started_at, type: DateTime
      field :stopped_at, type: DateTime
      field :failed_at, type: DateTime
      field :active, type: Boolean, default: false
      field :running, type: Boolean, default: false
      field :action, type: String, default: "standby"

      index(active: 1)

      validates :name, presence: true
      validates :stream, format: { with: /\Artmp.*?:\/\/.+\z/ }

      before_destroy :cleanup

      scope :active, -> { where(active: true) }
      scope :for_recording, -> { active }
      attr_accessor :live
    end

    def start_recording?
      action == "start"
    end

    def stop_recording?
      action == "stop"
    end

    def resume_recording?
      action == "resume"
    end

    def start_recording!
      self.action = "start"
      self.active = true
      save!
    end

    def stop_recording!
      self.action = "stop"
      save!
    end

    def resume_recording!
      self.action = "resume"
      self.active = true
      save!
    end

    def standby!
      return true if action == "standby"
      self.action = "standby"
      save!
    end
    # Starts a recording worker now, unless it has been done already.
    # Provide a Time object to schedule start.
    def start(time = :now)
      return false if done? || started?
      if time == :now
        self.started_at = Time.now
        self.active = true
        start!
      else
        schedule(time)
      end
    end

    # Continue recording that is not running anymore.
    def resume
      return false if running? || !started?
      self.stopped_at = nil
      self.failed_at = nil
      self.active = true
      start!
    end

    # Resets data and starts anew.
    def restart
      stop
      reset
      start
    end

    # Stops the recording worker and starts postprocessing.
    def stop
      return false unless running? || !stopped?
      stop_worker do
        self.pid = nil
        self.stopped_at = Time.now
        self.failed_at = nil
        self.running = false
        self.active = false
        postprocess
      end
    end

    # Gets called from recording worker if it receives no more data.
    def halt
      return false unless running?
      stop_worker do
        self.pid = nil
        self.running = false
        postprocess
      end
    end

    # Receives an error from recording worker and stores it.
    # The worker gets stopped and postprocessing is started.
    def fail(msg)
      return false unless running?
      stop_worker do
        self.pid = nil
        self.error = msg
        self.failed_at = Time.now
        self.running = false
        postprocess
      end
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
        :duration
      ].map { |a| blank[a] = nil }
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
      @backend ||= Vidibus::Recording::Backend.load(
        stream: stream,
        file: current_part&.data_file,
        live: true
      )
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
      if fresh_worker.running?
        unless running?
          self.update_attributes!(running: true)
        end
        true
      else
        if running?
          self.update_attributes!(pid: nil, running: false)
        end
        false
      end
    end

    # Return folder to store recordings in.
    def folder
      @folder ||= begin
        f = ["recordings"]
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
      self.update_attributes!(parts: [])
    end

    def start_worker
      return if worker_running?
      setup_next_part
      fresh_worker.start
    end

    def ensure_pid
      unless worker.pid
        fail("Worker did not return a PID!") && (return)
      end
      unless self.reload.pid == worker.pid
        fail("Worker PID could not be stored!") && (return)
      end
    end

    def start!
      postprocess
      start_worker
      self.running = true
      self.pid = worker.pid
      save!
      ensure_pid
    end

    # Stop worker and then call block.
    # If this method is invoked (indirectly) by a running worker process
    # the block is called before exiting the process.
    def stop_worker(&block)
      worker = fresh_worker
      if worker.pid == Process.pid
        block.call if block
        worker.stop
      else
        worker.stop
        block.call if block
      end
    end

    def fresh_worker
      @worker = nil
      worker
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
        parts.build(number: number)
      end
      current_part.start
    end

    def schedule(time)
      abort("Implement your background processing here to delay the start of the recording.\n For example:\n\ndef schedule(time)\n  self.delay(run_at: time).start\nend\n")
    end

    def postprocess
      if current_part && !current_part.stopped?
        current_part.postprocess
        set_size
        set_duration
        save!
      end
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
      stop_worker
      remove_files
    end

    def remove_files
      Dir["#{basename}*"].each do |f|
        File.delete(f)
      end
    end
  end
end
