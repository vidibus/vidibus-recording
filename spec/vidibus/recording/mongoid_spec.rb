# frozen_string_literal: true

require "spec_helper"

describe "Vidibus::Recording::Mongoid" do
  let(:subject) do
    Recording.create(
      name: "Example Stream",
      stream: "rtmp://example.host"
    )
  end

  let(:worker) do
    Vidibus::Recording::Worker.new(subject)
  end

  def cleanup(recording)
    delete_safely(recording.file)
    delete_safely(recording.log_file)
    delete_safely(recording.yml_file)
  end

  def stub_worker
    stub(subject).worker { worker }
    stub(worker).record { true }
    stub(worker).fork do |block|
      block.call
      99999
    end
    stub(Process).detach.with_any_args
  end

  before do
    stub_worker
  end

  describe "validation" do
    let(:subject) do
      Recording.new(
        name: "Example Stream",
        stream: "rtmp://example.host",
        live: true
      )
    end

    it "should pass with valid attributes" do
      subject.should be_valid
    end

    it "should fail without a stream" do
      subject.stream = nil
      subject.should be_invalid
    end

    it "should fail without a valid stream address" do
      subject.stream = "something"
      subject.should be_invalid
    end

    it "should fail without a valid rtmp stream address" do
      subject.stream = "rtmp://something"
      subject.should be_valid
    end

    it "should fail without a name" do
      subject.name = nil
      subject.should be_invalid
    end
  end

  describe "destroying" do
    it "should work" do
      subject.destroy
    end
  end

  describe "#worker" do
    it "should return a worker instance" do
      subject.worker.should be_an_instance_of(Vidibus::Recording::Worker)
    end
  end

  describe "#backend" do
    it "should return a backend instance for given stream protocol" do
      subject.send(:setup_next_part)
      subject.backend.
        should be_an_instance_of(Vidibus::Recording::Backend::Rtmpdump)
    end
  end

  describe "#start" do
    it "should return false if stream is done" do
      mock(subject).done? { true }
      subject.start.should be_falsey
    end

    it "should return false if stream has already been started" do
      mock(subject).started? { true }
      subject.start.should be_falsey
    end

    it "should set #active to true" do
      stub(subject).start_worker
      stub(subject).ensure_pid
      subject.start
      subject.active.should be_truthy
    end

    context "without params" do
      before do
        stub(subject).ensure_pid
      end

      it "should call #start_worker" do
        mock(subject).start_worker
        subject.start
      end

      it "should persist the record with a bang" do
        mock(subject).save!
        stub(subject).reload { subject }
        subject.start
      end

      it "should start a recording job" do
        stub(subject.worker).running?.times(2) { true }
        subject.start
        subject.worker_running?.should be_truthy
      end

      it "should set the process id" do
        stub(subject.worker).running?.any_number_of_times { false }
        stub(subject.worker).start
        mock(subject.worker).pid.any_number_of_times { 99999 }
        subject.start
        subject.pid.should eq(99999)
      end

      it "should set the start time" do
        stub_time
        subject.start
        subject.started_at.should eq(Time.now)
      end

      it "should set running to true" do
        subject.start
        subject.running.should be_truthy
      end

      it "should add first part of recording" do
        subject.start
        subject.parts.size.should eq(1)
      end
    end

    context "with a given Time" do
      it "raises message" do
        stub_time("2011-01-12 00:00")
        run_at = 10.minutes.since
        expect { subject.start(run_at) }.to raise_error
      end
    end
  end

  describe "#resume" do
    it "should return false unless stream has been started" do
      mock(subject).started? { false }
      subject.resume.should be_falsey
    end

    it "should return false if stream is running" do
      mock(subject).running? { true }
      subject.resume.should be_falsey
    end

    context "on a started recording" do
      before do
        mock(subject).started? { true }
      end

      it "should set #active to true" do
        stub(subject).start_worker
        stub(subject).ensure_pid
        subject.resume
        subject.active.should be_truthy
      end

      it "should work even if stream has been stopped" do
        stub(subject).stopped? { true }
        mock(subject).start_worker
        subject.resume
      end

      it "should call #start_worker" do
        mock(subject).start_worker
        subject.resume
      end

      it "should call #postprocess in case last recording process died" do
        mock(subject).postprocess
        subject.resume
      end

      it "should persist the record with a bang" do
        mock(subject).save!
        stub(subject).reload { subject }
        subject.resume
      end

      context "and an existing part" do
        before do
          subject.send(:setup_next_part)
        end

        context "without data" do
          before do
            stub(subject.current_part).has_data? { false }
          end

          it "should re-use the first part" do
            subject.resume
            subject.parts.size.should eq(1)
          end
        end

        context "with data" do
          before do
            stub(subject.current_part).has_data? { true }
          end

          it "should create the second part" do
            subject.resume
            subject.parts.size.should eq(2)
          end

          context "that has been processed" do
            before do
              stub(subject.current_part).stopped? { true }
            end

            it "should not process the part again" do
              dont_allow(subject.current_part).postprocess
              subject.resume
            end
          end
        end
      end
    end
  end

  describe "#restart" do
    it "should call stop" do
      mock(subject).stop
      subject.restart
    end

    it "should call reset" do
      mock(subject).reset
      subject.restart
    end

    it "should call start" do
      mock(subject).start
      subject.restart
    end
  end

  describe "#stop" do
    it "should return false unless recording has been started" do
      subject.stop.should be_falsey
    end

    context "on a recording that has been stopped" do
      before do
        stub(subject).stopped? { true }
      end

      it "should return false" do
        subject.stop.should eq(false)
      end

      it "should not return false if it is still running" do
        stub(subject).running? { true }
        mock(subject).stop_worker
        subject.stop.should_not eq(false)
      end
    end

    context "on a recording that has failed" do
      before do
        stub(subject).failed? { true }
      end

      it "should not return false" do
        mock(subject).stop_worker
        subject.stop.should_not eq(false)
      end
    end

    it "should set #active to false" do
      stub(subject).start_worker
      stub(subject).ensure_pid { true }
      subject.start
      subject.stop
      subject.active.should be_falsey
    end

    context "with a running worker" do
      before do
        stub(subject).start!
        subject.start
      end

      it "should reset the pid" do
        subject.stop
        subject.pid.should be_nil
      end

      it "should set running to false" do
        subject.stop
        subject.running.should be_falsey
      end

      it "should set the stop time" do
        stub_time
        subject.stop
        subject.stopped_at.should eq(Time.now)
      end

      it "should stop the recording worker" do
        subject.stop
        subject.worker_running?.should be_falsey
      end

      it "should start postprocessing" do
        mock(subject).postprocess
        subject.stop
      end
    end
  end

  describe "#fail" do
    it "should return false unless recording has been started" do
      subject.fail("wtf").should be_falsey
    end

    it "should return false if recording is done" do
      subject.stopped_at = Time.now
      subject.fail("wtf").should be_falsey
    end

    it "should keep #active set to true" do
      stub(subject).start_worker
      subject.start
      subject.fail("wtf")
      subject.active.should be_truthy
    end

    context "with a running worker" do
      before do
        stub_worker
        subject.start
      end

      it "should reset the pid" do
        subject.fail("wtf")
        subject.pid.should be_nil
      end

      it "should set running to false" do
        subject.fail("wtf")
        subject.running.should be_falsey
      end

      it "should set the time of failure" do
        stub_time
        subject.fail("wtf")
        subject.failed_at.should eq(Time.now)
      end

      it "should stop the recording worker" do
        mock(subject).stop_worker
        subject.fail("wtf")
      end

      it "should set the error" do
        subject.fail("wtf")
        subject.error.should eq("wtf")
      end

      it "should start postprocessing" do
        mock(subject).postprocess
        subject.fail("wtf")
      end
    end
  end

  describe "#running?" do
    it "should be false by default" do
      subject.running?.should be_falsey
    end
  end

  describe "#worker_running?" do
    context "without a running worker" do
      it "should return false" do
        subject.worker_running?.should be_falsey
      end
    end

    context "with a started worker" do
      before { subject.start }

      it "should call job#running?" do
        mock(subject.worker).running? { true }
        subject.worker_running?
      end

      it "should return true" do
        stub(subject.worker).running? { true }
        subject.worker_running?.should be_truthy
      end

      context "that has been stopped already" do
        before { subject.worker.stop }

        it "should return false" do
          stub(Process).kill(0, subject.worker.pid) do
            raise Errno::ESRCH
          end
          subject.worker_running?.should be_falsey
        end
      end
    end
  end

  describe ".active" do
    it "should return a Mongoid::Criteria" do
      Recording.active.should be_a(Mongoid::Criteria)
    end

    it "should find all active recordings" do
      subject.start
      Recording.active.to_a.should eq([subject])
    end

    it "should not find recordings that are not active" do
      subject
      Recording.active.to_a.should eq([])
    end
  end

  after { cleanup(subject) }
end
