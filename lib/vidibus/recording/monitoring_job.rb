module Vidibus::Recording
  class MonitoringJob
    INTERVAL = 10.seconds

    def initialize(args)
      unless @uuid = args[:uuid]
        raise(ArgumentError, 'No recording UUID given')
      end
      unless @class_name = args[:class_name]
        raise(ArgumentError, 'Must provide class name of recording')
      end
      unless @identifier = args[:identifier]
        raise(ArgumentError, 'Must provide identifier of monitoring job')
      end
      ensure_recording
    end

    def perform
      r = recording.reload
      return unless r.monitoring_job_identifier == @identifier
      if r.worker_running?
        r.track_progress
        run_again
      elsif !r.stopped?
        r.resume
      end
    end

    # Returns job
    def self.create(args)
      job = new(args)
      Delayed::Job.enqueue(job)
    end

    private

    def recording
      @class_name.constantize.where(:uuid => @uuid).first
    end

    def ensure_recording
      recording || raise(ArgumentError, 'No valid recording UUID given')
    end

    def run_again
      obj = self.class.new({
        :uuid => @uuid, :class_name => @class_name, :identifier => @identifier
      })
      Delayed::Job.enqueue(obj, 0, INTERVAL.from_now)
    end
  end
end
