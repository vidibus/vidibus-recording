module Vidibus::Recording
  class Job
    include Open4

    class ProcessError < StandardError; end

    attr_accessor :recording, :pid

    def initialize(recording)
      self.recording = recording
      self.pid = recording.pid
    end

    def start
      start_logger
      self.pid = fork do
        start_thread
      end
      Process.detach(pid)
      pid
    end

    def stop
      if pid and running?
        Process.kill("SIGTERM", pid)
        sleep 2
        raise ProcessError.new("Recording job is still running!") if running?
      end
    end

    def running?
      pid and self.class.running?(pid)
    end

    def self.running?(pid)
      begin
        Process.kill(0, pid)
        return true
      rescue Errno::ESRCH
        return false
      rescue Errno::EPERM
        raise ProcessError.new("No permission to check #{pid}")
      rescue
        raise ProcessError.new("Unable to determine status for #{pid}: #{$!}")
      end
    end

    protected

    def start_thread
      stdin = ""
      stdout = ""
      stderr = ""
      last_stderr = ""
      last_stdout = ""
      task = background(recording.backend.command, 0=>stdin, 1=>stdout, 2=>stderr)

      waiter = Thread.new {y(task.pid => task.exitstatus)} # t.exitstatus is a blocking call!
      timeout = 5

      while(status = task.status)
        unless stderr == last_stderr
          metadata = extract_metadata(stderr)
          last_stderr = stderr
        end

        unless stdout == last_stdout
          metadata = extract_metadata(stdout)
          last_stdout = stdout
        end

        unless metadata
          timeout -= 1
          if timeout == 0
            recording.fail("No Metadata has been received. This stream does not work.")
            return
          end
        end

        sleep 2
      end

      waiter.join
    end

    def extract_metadata(std)
      metadata = recording.backend.extract_metadata(std)
      if metadata
        File.open(recording.yml_file, "w") do |file|
          file.write(metadata.to_yaml)
        end
      end
      metadata
    end

    def start_logger
      RobustThread.logger = Logger.new(recording.log_file)
      RobustThread.exception_handler do |exception|
        RobustThread.log exception
      end
    end
  end
end
