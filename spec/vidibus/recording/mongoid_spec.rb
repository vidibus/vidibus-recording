require 'spec_helper'

describe 'Vidibus::Recording::Mongoid' do
  let(:this) do
    Recording.create({
      :name => 'N-TV Live',
      :stream => 'rtmp://fms.rtl.de/ntvlive/livestream/channel1'
    })
  end

  let(:worker) do
    Vidibus::Recording::Worker.new(this)
  end

  def cleanup(recording)
    delete_safely(recording.file)
    delete_safely(recording.log_file)
    delete_safely(recording.yml_file)
  end

  def stub_worker
    stub(this).worker { worker }
    stub(worker).record { true }
    stub(worker).fork do |block|
      block.call
      123
    end
    stub(Process).detach.with_any_args
  end

  before do
    stub_worker
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

    it 'should set #active to true' do
      stub(this).start_worker
      this.start
      this.active.should be_true
    end

    context 'without params' do
      it 'should call #start_worker' do
        mock(this).start_worker
        this.start
      end

      it 'should persist the record with a bang' do
        mock(this).save!
        this.start
      end

      it 'should start a recording job' do
        stub(this.worker).running?.times(2) { true }
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

    context 'on a started recording' do
      before do
        mock(this).started? { true }
      end

      it 'should set #active to true' do
        stub(this).start_worker
        this.resume
        this.active.should be_true
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

    it 'should set #active to false' do
      stub(this).start_worker
      this.start
      this.stop
      this.active.should be_false
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

    it 'should set #active to false' do
      this.start
      this.fail('wtf')
      this.active.should be_false
    end

    context 'with a running worker' do
      before do
        stub_worker
        this.start
      end

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

      it 'should call job#running?' do
        mock(this.worker).running? { true }
        this.worker_running?
      end

      it 'should return true' do
        stub(this.worker).running? { true }
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

  describe '.active' do
    it 'should return a Mongoid::Criteria' do
      Recording.active.should be_a(Mongoid::Criteria)
    end

    it 'should find all active recordings' do
      this.start
      Recording.active.to_a.should eq([this])
    end

    it 'should not find recordings that are not active' do
      this
      Recording.active.to_a.should eq([])
    end
  end

  after {cleanup(this)}
end
