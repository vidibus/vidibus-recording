# frozen_string_literal: true

require "open3"
require "timeout"

module Vidibus::Recording
  class Worker
    class ProcessError < StandardError; end

    START_TIMEOUT = 30
    STOP_TIMEOUT = 2

    attr_accessor :recording, :pid, :metadata

    def initialize(recording)
      self.recording = recording
      self.pid = recording.pid
      self.metadata = nil
    end

    def start
      self.pid = fork do
        record
      rescue => e
        fail(e.message)
      end
      Process.detach(pid)
      pid
    end

    def stop
      if running?
        begin
          Timeout.timeout(STOP_TIMEOUT) do
            log("Stopping process #{pid}...")
            Process.kill("SIGTERM", pid)
            Process.wait(pid)
            log("STOPPED")
          rescue Errno::ECHILD
            log("STOPPED")
          end
        rescue Timeout::Error
          begin
            log("Killing process #{pid}")
            Process.kill("KILL", pid)
            Process.wait(pid)
            log("KILLED")
          rescue Errno::ECHILD
            log("KILLED")
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
        raise ProcessError.new("No permission to check process #{pid}")
      rescue
        raise ProcessError.new("Unable to determine status of process #{pid}: #{$!}")
      end
    end

    protected

    def record
      cmd = recording.backend.command
      log("START: #{recording.stream}", true)
      timeout = Time.now + START_TIMEOUT
      Open3.popen3(cmd) do |stdin, stdout, stderr|
        loop do
          begin
            string = stdout.read_nonblock(1024).force_encoding("UTF-8")
            log(string)
            extract_metadata(string) unless metadata
            recording.backend.detect_error(string)
          rescue Errno::EAGAIN
          rescue EOFError
            if metadata
              halt("No more data!") && break
            end
          rescue Backend::RtmpStreamError => e
            fail(e.message) && break
          end
          unless metadata
            if Time.now > timeout
              halt("No Metadata has been received so far, exiting.") && break
            end
          end
          sleep(2)
        end
      end
    end

    def log(msg, print_header = false)
      if print_header
        header = "--- #{Time.now.strftime('%F %R:%S %z')}".dup
        header << " | Process #{Process.pid}"
        msg = "#{header}\n#{msg}\n"
      end
      msg = "\n#{msg}" unless msg[/A\n/]
      File.open(recording.log_file, "a") do |f|
        f.write(msg)
      end
    end

    def fail(msg)
      log("FATAL: #{msg}", true)
      with_fresh_recording do |recording|
        recording.fail(msg)
        exit!
      end
    end

    def halt(msg)
      log("HALT: #{msg}", true)
      with_fresh_recording do |recording|
        recording.halt
        exit!
      end
    end

    def with_fresh_recording(&block)
      rec = recording.reload # reload to get fresh object
      if rec.pid == Process.pid
        block.call(rec)
      else
        exit!
      end
    end

    def exit!
      self.pid = Process.pid
      stop
      exit
    end

    def extract_metadata(string)
      self.metadata = recording.backend.extract_metadata(string)
      if metadata
        File.open(recording.current_part.yml_file, "w") do |f|
          f.write(metadata.to_yaml)
        end
      end
      metadata
    end
  end
end
