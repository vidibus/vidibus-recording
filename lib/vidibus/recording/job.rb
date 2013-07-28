require 'timeout'

# TODO: RENAME TO 'WORKER'

module Vidibus::Recording
  class Job
    class ProcessError < StandardError; end

    # START_TIMEOUT = 20
    STOP_TIMEOUT = 5

    attr_accessor :recording, :pid, :metadata

    def initialize(recording)
      self.recording = recording
      self.pid = recording.pid
      self.metadata = nil
    end

    def start
      self.pid = fork do
        begin
          record
        rescue => e
          puts %(e.inspect = #{e.inspect.inspect})
          fail(e.inspect)
        end
      end
      Process.detach(pid)
      pid
    end

    def stop
      if running?
        begin
          Timeout::timeout(STOP_TIMEOUT) do
            begin
              Process.kill('SIGTERM', pid)
              Process.wait(pid)
            rescue Errno::ECHILD
            end
          end
        rescue Timeout::Error
          begin
            Process.kill('KILL', pid)
          rescue
          end
        end
      end
    end

    def running?
      return false unless pid
      begin
        Process.kill(0, pid)
        return true
      rescue Errno::ESRCH
        return false
      rescue Errno::EPERM
        raise ProcessError.new("No permission to check #{pid}")
      rescue
        raise ProcessError.new("Unable to determine status of #{pid}: #{$!}")
      end
    end

    protected

    def record
      cmd = recording.backend.command
      log("START: #{recording.stream}", true)
      Open3::popen3(cmd) do |stdin, stdout, stderr, process|
        maxloops = 10
        loop do
          begin
            string = stdout.read_nonblock(1024)
            # string = string.force_encoding('UTF-8') # TODO: Does not work anymore under Ruby 1.8.
            log(string)
            extract_metadata(string) unless metadata
            recording.backend.detect_error(string)
          rescue Errno::EAGAIN
          rescue EOFError
            if metadata
              halt('No more data!') && return
            end
          rescue Backend::RuntimeError => e
            fail(e.message) && return
          end

          unless metadata
            maxloops -= 1
            if maxloops == 0
              halt('No Metadata has been received so far.') && return
            end
          end
          sleep 2
        end
      end
      process.join
    end

    def log(msg, print_header = false)
      if print_header
        header = "--- #{Time.now.strftime('%F %R:%S %z')}"
        header << " | Process #{Process.pid}"
        msg = "#{header}\n#{msg}\n"
      end
      msg = "\n#{msg}" unless msg[/A\n/]
      File.open(recording.log_file, "a") do |f|
        f.write(msg)
      end
    end

    def fail(msg)
      log("ERROR: #{msg}", true)
      recording.reload.fail(msg)
    end

    def halt(msg)
      log("HALT: #{msg}", true)
      recording.reload.halt(msg)
    end

    def extract_metadata(string)
      self.metadata = recording.backend.extract_metadata(string)
      if metadata
        File.open(recording.current_part.yml_file, 'w') do |f|
          f.write(metadata.to_yaml)
        end
      end
      metadata
    end
  end
end
