# frozen_string_literal: true

require "spec_helper"

describe Vidibus::Recording do
  let(:subject) { Vidibus::Recording }

  def stub_loop(sleep = false)
    if sleep == false
      stub(subject).sleep
    end
    stub(subject).loop do |block|
      block.call
    end
  end

  describe ".monitor" do
    let(:recording) do
      Recording.create(
        name: "Example Stream",
        stream: "rtmp://example.host"
      )
    end

    it "should call #autoload" do
      stub(subject).run
      mock(subject).autoload { [] }
      subject.monitor
    end

    it "should not run without recording classes" do
      dont_allow(subject).run
      subject.monitor
    end

    context "with recording classes available" do
      before do
        subject.autoload_paths = ["app/models/*.rb"]
      end

      it "should call #run" do
        mock(subject).run
        subject.monitor
      end

      it "should loop endlessly" do
        mock(subject).loop
        subject.monitor
      end

      it "should sleep after each iteration" do
        stub_loop(true)
        mock(subject).sleep(Vidibus::Recording.monitoring_interval)
        subject.monitor
      end

      it "should do nothing without started recordings" do
        stub_loop
        dont_allow.any_instance_of(Recording).resume
        subject.monitor
      end

      context "with started recordings" do
        before do
          stub(recording).start_worker
          stub(recording).ensure_pid
          recording.start
        end

        it "should log exceptions" do
          stub_loop
          stub.any_instance_of(Recording).worker_running? do
            raise "That went wrong"
          end
          mock(subject.logger).error.with_any_args
          expect { subject.monitor }.not_to raise_error
        end

        context "with a running worker" do
          before do
            stub.any_instance_of(Recording).worker_running? { true }
          end

          it "should track progress" do
            stub_loop
            mock.any_instance_of(Recording).track_progress
            subject.monitor
          end

          it "should not resume" do
            stub_loop
            dont_allow.any_instance_of(Recording).resume
            subject.monitor
          end
        end

        context "without a running worker" do
          before do
            stub.any_instance_of(Recording).worker_running? { false }
          end

          it "should resume" do
            stub_loop
            mock.any_instance_of(Recording).resume
            subject.monitor
          end
        end
      end
    end
  end

  describe ".autoload" do
    it "should do nothing unless autoload paths have been defined" do
      subject.autoload_paths = []
      dont_allow(Dir)[]
      subject.autoload
    end

    it "should return all recording classes in autoload paths" do
      subject.autoload_paths = ["app/models/*.rb"]
      subject.autoload.should eq([Recording])
    end

    it "should set classes variable" do
      subject.autoload_paths = ["app/models/*.rb"]
      subject.autoload
      subject.classes.should eq([Recording])
    end
  end
end
