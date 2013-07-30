require 'spec_helper'

describe 'Vidibus::Recording::Mongoid' do
  let(:this) do
    Recording.create({
      :name => 'N-TV Live',
      :stream => 'rtmp://fms.rtl.de/ntvlive/livestream/channel1'
    })
  end

  def cleanup(recording)
    if recording.pid
      begin
        Process.kill('SIGTERM', recording.pid)
      rescue Errno::ESRCH
      end
    end
    delete_safely(recording.file)
    delete_safely(recording.log_file)
    delete_safely(recording.yml_file)
  end

  def delete_safely(file)
    return unless file.match(/.{32}\..{3}/)
    File.delete(file) if File.exists?(file)
  end

  def process_alive?(pid)
    begin
      Process.kill(0, pid)
      return true
    rescue Errno::ESRCH
      return false
    end
  end

  def job_payload_object
    job = Delayed::Backend::Mongoid::Job.first
    job.payload_object
  end

  describe 'validation' do
    let(:this) do
      Recording.new({
        :name => 'N-TV Live',
        :stream => 'rtmp://fms.rtl.de/ntvlive/livestream/channel1',
        :live => true
      })
    end

    it 'should pass with valid attributes' do
      this.should be_valid
    end

    it 'should fail without a stream' do
      this.stream = nil
      this.should be_invalid
    end

    it 'should fail without a valid stream address' do
      this.stream = 'something'
      this.should be_invalid
    end

    it 'should fail without a valid rtmp stream address' do
      this.stream = 'rtmp://something'
      this.should be_valid
    end

    it 'should fail without a name' do
      this.name = nil
      this.should be_invalid
    end
  end

  describe '#worker' do
    it 'should return a worker instance' do
      this.worker.should be_an_instance_of(Vidibus::Recording::Worker)
    end
  end

  describe '#backend' do
    it 'should return a backend instance for given stream protocol' do
      this.send(:setup_next_part)
      this.backend.
        should be_an_instance_of(Vidibus::Recording::Backend::Rtmpdump)
    end
  end

  describe '#start' do
    it 'should return false if stream is done' do
      mock(this).done? { true }
      this.start.should be_false
    end

    it 'should return false if stream has already been started' do
      mock(this).started? { true }
      this.start.should be_false
    end

    context 'without params' do
      it 'should call #start_worker' do
        mock(this).start_worker
        this.start
      end

      it 'should call #start_monitoring_job' do
        mock(this).start_monitoring_job
        this.start
      end

      it 'should persist the record with a bang' do
        mock(this).save!
        this.start
      end

      it 'should start a recording job' do
        this.start
        this.worker_running?.should be_true
      end

      it 'should set the process id' do
        stub(this.worker).start
        mock(this.worker).pid.any_number_of_times {123}
        this.start
        this.pid.should eq(123)
      end

      it 'should set the start time' do
        stub_time
        this.start
        this.started_at.should eq(Time.now)
      end

      it 'should set running to true' do
        this.start
        this.running.should be_true
      end

      it 'should add first part of recording' do
        this.start
        this.parts.size.should eq(1)
      end

      it 'should create a monitoring job' do
        this.start
        Delayed::Backend::Mongoid::Job.count.should eq(1)
        job_payload_object.should be_a(Vidibus::Recording::MonitoringJob)
      end

      it 'should should generate a unique identifier' do
        uuid = '4c996890d99c0130df0238f6b1180e6b'
        stub(Vidibus::Uuid).generate { uuid }
        this.start
        this.monitoring_job_identifier.should eq(uuid)
      end

      it 'should store identifier on monitoring job' do
        uuid = '4c996890d99c0130df0238f6b1180e6b'
        stub(Vidibus::Uuid).generate { uuid }
        this.start
        po = job_payload_object
        po.instance_variable_get('@identifier').should eq(uuid)
      end

      it 'should store uuid on monitoring job' do
        this.start
        po = job_payload_object
        po.instance_variable_get('@uuid').should eq(this.uuid)
      end

      it 'should store class name on monitoring job' do
        this.start
        po = job_payload_object
        po.instance_variable_get('@class_name').should eq('Recording')
      end
    end

    context 'with a given Time' do
      it 'should schedule a recording job' do
        stub_time('2011-01-12 00:00')
        run_at = 10.minutes.since
        this.start(run_at)
        Delayed::Backend::Mongoid::Job.count.should eq(1)
        Delayed::Backend::Mongoid::Job.first.run_at.should eq(run_at)
      end
    end
  end

  describe '#resume' do
    it 'should return false unless stream has been started' do
      mock(this).started? { false }
      this.resume.should be_false
    end

    it 'should return false if stream is running' do
      mock(this).running? { true }
      this.resume.should be_false
    end

    context 'with a started job' do
      before do
        mock(this).started? { true }
      end

      it 'should work even if stream has been stopped' do
        stub(this).stopped? { true }
        mock(this).start_worker
        this.resume
      end

      it 'should call #start_worker' do
        mock(this).start_worker
        this.resume
      end

      it 'should call #start_monitoring_job' do
        mock(this).start_monitoring_job
        this.resume
      end

      it 'should persist the record with a bang' do
        mock(this).save!
        this.resume
      end

      context 'and an existing part' do
        before do
          this.send(:setup_next_part)
        end

        context 'without data' do
          before do
            mock(this.current_part).has_data? { false }
          end

          it 'should re-use the first part' do
            this.resume
            this.parts.size.should eq(1)
          end
        end

        context 'with data' do
          before do
            mock(this.current_part).has_data? { true }
          end

          it 'should create the second part' do
            this.resume
            this.parts.size.should eq(2)
          end
        end
      end
    end
  end

  describe '#restart' do
    it 'should call stop' do
      mock(this).stop
      this.restart
    end

    it 'should call reset' do
      mock(this).reset
      this.restart
    end

    it 'should call start' do
      mock(this).start
      this.restart
    end
  end

  describe '#stop' do
    it 'should return false unless recording has been started' do
      this.stop.should be_false
    end

    it 'should return false if recording is done' do
      this.stopped_at = Time.now
      this.stop.should be_false
    end

    context 'with a running worker' do
      before {this.start}

      it 'should reset the pid' do
        this.stop
        this.pid.should be_nil
      end

      it 'should set running to false' do
        this.stop
        this.running.should be_false
      end

      it 'should set the stop time' do
        stub_time
        this.stop
        this.stopped_at.should eq(Time.now)
      end

      it 'should stop the recording worker' do
        this.stop
        this.worker_running?.should be_false
      end

      it 'should start postprocessing' do
        mock(this).postprocess
        this.stop
      end

    end
  end

  describe '#fail' do
    it 'should return false unless recording has been started' do
      this.fail('wtf').should be_false
    end

    it 'should return false if recording is done' do
      this.stopped_at = Time.now
      this.fail('wtf').should be_false
    end

    context 'with a running worker' do
      before {this.start}

      it 'should reset the pid' do
        this.fail('wtf')
        this.pid.should be_nil
      end

      it 'should set running to false' do
        this.fail('wtf')
        this.running.should be_false
      end

      it 'should set the time of failure' do
        stub_time
        this.fail('wtf')
        this.failed_at.should eq(Time.now)
      end

      it 'should stop the recording worker' do
        this.fail('wtf')
        this.worker_running?.should be_false
      end

      it 'should set the error' do
        this.fail('wtf')
        this.error.should eq('wtf')
      end

      it 'should start postprocessing' do
        mock(this).postprocess
        this.fail('wtf')
      end
    end
  end

  describe '#running?' do
    it 'should be false by default' do
      this.running?.should be_false
    end
  end

  describe '#worker_running?' do
    context 'without a running worker' do
      it 'should return false' do
        this.worker_running?.should be_false
      end
    end

    context 'with a started worker' do
      before {this.start}

      it 'should return true' do
        this.worker_running?.should be_true
      end

      context 'that has been stopped already' do
        before {this.worker.stop}

        it 'should return false' do
          this.worker_running?.should be_false
        end
      end
    end
  end

  # TODO: use separate worker specs
  describe '#worker.stop' do
    before {this.start}

    it 'should stop the recording worker' do
      this.worker.stop
      this.worker_running?.should be_false
    end

    it 'should kill the process' do
      pid = this.pid
      this.worker.stop
      process_alive?(pid).should be_false
    end
  end

  after {cleanup(this)}
end
