module Vidibus::Recording
  class Job
    class ProcessError < StandardError; end

    attr_accessor :recording, :pid

    def initialize(recording)
      self.recording = recording
      self.pid = recording.pid
    end

    def start
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
      timeout = 5
      metadata = nil

      Open3::popen3(recording.backend.command) do |stdin, stdout, stderr, waiter|
        loop do
          size = stderr.stat.blocks * stderr.stat.blksize
          if size > 0
            std = stderr.readpartial(size) rescue ""
            log(std)
            metadata = extract_metadata(std) unless metadata
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
      end
      waiter.join
    end

    def log(msg)
      File.open(recording.log_file, "a") do |f|
        f.write(msg)
      end
    end

    def extract_metadata(std)
      metadata = recording.backend.extract_metadata(std)
      if metadata
        File.open(recording.yml_file, "w") do |f|
          f.write(metadata.to_yaml)
        end
      end
      metadata
    end
  end
end
