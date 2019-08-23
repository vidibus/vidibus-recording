# frozen_string_literal: true

require "spec_helper"

describe Vidibus::Recording::Worker do
  let(:recording) do
    Recording.create(
      name: "Example Stream",
      stream: "rtmp://example.host/live/stream/sd-123"
    )
  end
  let(:part) do
    recording.parts.create!(number: 1)
  end

  let(:subject) do
    Vidibus::Recording::Worker.new(recording)
  end

  def stub_fork
    pid = 999999
    stub(subject).fork do |block|
      block.call
      pid
    end
    stub(Process).detach(pid)
  end

  describe "#start" do
    it "should fork and detach a separate process" do
      mock(subject).fork { 999999 }
      mock(Process).detach(999999)
      subject.start
    end

    context "with forked process" do
      before do
        stub_fork
      end

      it "should call #record" do
        mock(subject).record
        subject.start
      end
    end
  end

  describe "#stop" do
    before do
      part
      subject.start
    end

    it "should terminate the process" do
      pid = subject.pid
      mock(Process).kill("SIGTERM", pid)
      subject.stop
    end

    it "should kill the process after timeout" do
      pid = subject.pid
      stub(Timeout).timeout(Vidibus::Recording::Worker::STOP_TIMEOUT) do
        raise Timeout::Error
      end
      mock(Process).kill("KILL", pid)
      subject.stop
    end
  end
end
