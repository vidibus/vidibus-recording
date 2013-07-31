require 'spec_helper'

describe Vidibus::Recording::Worker do
  let(:recording) do
    Recording.create({
      :name => 'Example Stream',
      :stream => 'rtmp://example.host'
    })
  end

  let(:subject) do
    Vidibus::Recording::Worker.new(recording)
  end

  def stub_fork
    pid = 123
    stub(subject).fork do |block|
      block.call
      pid
    end
    stub(Process).detach(pid)
  end

  def process_alive?(pid)
    begin
      Process.kill(0, pid)
      return true
    rescue Errno::ESRCH
      return false
    end
  end

  describe '#start' do
    it 'should fork and detach a separate process' do
      mock(subject).fork {123}
      mock(Process).detach(123)
      subject.start
    end

    context 'with forked process' do
      before do
        stub_fork
      end

      it 'should call #record' do
        mock(subject).record
        subject.start
      end
    end
  end

  describe '#stop' do
    before do
      subject.start
    end

    it 'should kill the process' do
      pid = subject.pid
      subject.stop
      process_alive?(pid).should be_false
    end
  end
end
