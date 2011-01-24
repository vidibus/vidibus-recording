module Vidibus::Recording
  module Mongoid
    extend ActiveSupport::Concern

    class ProcessError < StandardError; end
    class StreamError < StandardError; end

    included do
      include Vidibus::Recording::Helpers
      include Vidibus::Uuid::Mongoid

      field :name
      field :stream
      field :live, :type => Boolean
      field :pid, :type => Integer
      field :info, :type => Hash
      field :size, :type => Integer
      field :duration, :type => Integer
      field :log
      field :error
      field :scheduled_at, :type => DateTime
      field :started_at, :type => DateTime
      field :stopped_at, :type => DateTime
      field :failed_at, :type => DateTime

      validates :name, :presence => true
      validates :stream, :format => {:with => /^rtmp.*?:\/\/.+$/}

      before_destroy :cleanup
    end

    # Starts a recording job now, unless it has been done already.
    # Provide a Time object to schedule start.
    def start(time = :now)
      return false if done? or started?
      if time == :now
        job.start
        update_attributes(:pid => job.pid, :started_at => Time.now)
        job.pid
      else
        schedule(time)
      end
    end

    # Resets data and stars anew.
    def restart(time = :now)
      stop
      reset
      start(time)
    end

    # Stops the recording job and starts postprocessing.
    def stop
      return false if !started_at? or done?
      job.stop
      self.pid = nil
      self.stopped_at = Time.now
      postprocess
    end

    # Receives an error from recording job and stores it.
    # The job gets stopped and postprocessing is started.
    def fail(msg)
      return if done?
      job.stop
      self.pid = nil
      self.error = msg
      self.failed_at = Time.now
      postprocess
    end

    # Removes all acquired data
    def reset
      remove_files
      blank = {}
      [:started_at, :stopped_at, :failed_at, :info, :log, :error, :size, :duration].map {|a| blank[a] = nil }
      update_attributes(blank)
    end

    # Returns an instance of the recording job.
    def job
      @job ||= Vidibus::Recording::Job.new(self)
    end

    # Returns an instance of a fitting recording backend.
    def backend
      @backend ||= Vidibus::Recording::Backend.load(:stream => stream, :file => file, :live => live)
    end

    # Returns true if recording has either been stopped or failed.
    def done?
      stopped_at or failed?
    end

    # Returns true if recording has failed.
    def failed?
      !!failed_at
    end

    # Returns true if if job has been started.
    def started?
      !!started_at
    end

    # Returns true if recording job is still running.
    def running?
      started? and job.running?
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

    # Returns the file name of this recording.
    def file
      @file ||= "#{folder}/#{uuid}.rec"
    end

    # Returns the log file name for this recording.
    def log_file
      @log_file ||= file.gsub(/\.[^\.]+$/, ".log")
    end

    # Returns the YAML file name for this recording.
    def yml_file
      @info_file ||= file.gsub(/\.[^\.]+$/, ".yml")
    end

    protected

    def schedule(time)
      self.delay(:run_at => time).start
    end

    def postprocess
      process_log_file
      process_yml_file
      set_size
      set_duration
      save!
    end

    def process_log_file
      if str = read_file(log_file)
        str.gsub!(/\A[^\n]+\n/, "") # remove first line
        unless str == ""
          self.log = str.gsub(/\r\n?/, "\n")
        end
      end
    end

    def process_yml_file
      if str = read_file(yml_file)
        if values = YAML::load(str)
          fix_value_classes!(values)
          self.info = values
        end
      end
    end

    def set_size
      self.size = File.exists?(file) ? File.size(file) : nil
    end

    def set_duration
      self.duration = failed? ? 0 : Time.now - started_at
    end

    def read_file(file)
      if File.exists?(file)
        str = File.read(file)
        File.delete(file)
        str
      end
    end

    def cleanup
      job.stop
      remove_files
    end

    def remove_files
      [file, log_file, yml_file].each do |f|
        File.delete(f) if File.exists?(f)
      end
    end
  end
end
