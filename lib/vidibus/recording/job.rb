# TODO: extend from Vidibus::Loop

module Vidibus::Recording
  class Job
    class ProcessError < StandardError; end

    attr_accessor :recording, :pid, :metadata

    def initialize(recording)
      self.recording = recording
      self.pid = recording.pid
      self.metadata = nil
    end

    def start
      self.pid = fork do
        record!
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

    def record!
      Open3::popen3(recording.backend.command) do |stdin, stdout, stderr, process|
        maxloops = 10
        loop do
          begin
            string = stdout.read_nonblock(1024)
            log(string)
            extract_metadata(string) unless metadata
          rescue Errno::EAGAIN
          rescue EOFError
          end

          unless metadata
            maxloops -= 1
            if maxloops == 0
              recording.fail("No Metadata has been received. This stream does not work.")
              return
            end
          end
          sleep 2
        end
      end
      process.join
    end

    def log(msg)
      File.open(recording.log_file, "a") do |f|
        f.write(msg)
      end
    end

    def extract_metadata(string)
      self.metadata = recording.backend.extract_metadata(string)
      if metadata
        File.open(recording.yml_file, "w") do |f|
          f.write(metadata.to_yaml)
        end
      end
      metadata
    end
  end
end
