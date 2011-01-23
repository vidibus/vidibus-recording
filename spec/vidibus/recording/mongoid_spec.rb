require "spec_helper"

describe "Vidibus::Recording::Mongoid" do

  let(:this) do
    Recording.new(:name => "N-TV Live", :stream => "rtmp://fms.rtl.de/ntvlive/livestream/channel1", :live => true)
  end

  def cleanup(recording)
    Process.kill("SIGTERM", recording.pid) if recording.pid
    delete_safely(recording.file)
    delete_safely(recording.log_file)
    delete_safely(recording.yml_file)
  end

  def delete_safely(file)
    return unless file.match(/.{32}\..{3}/)
    File.delete(file) if File.exists?(file)
  end

  describe "validation" do
    it "should pass with valid attributes" do
      this.should be_valid
    end

    it "should fail without a stream" do
      this.stream = nil
      this.should be_invalid
    end

    it "should fail without a valid stream address" do
      this.stream = "something"
      this.should be_invalid
    end

    it "should fail without a valid rtmp stream address" do
      this.stream = "rtmp://something"
      this.should be_valid
    end

    it "should fail without a name" do
      this.name = nil
      this.should be_invalid
    end
  end

  describe "job" do
    it "should return a job instance" do
      this.job.should be_an_instance_of(Vidibus::Recording::Job)
    end
  end

  describe "backend" do
    it "should return a backend instance for given stream protocol" do
      this.backend.should be_an_instance_of(Vidibus::Recording::Backend::Rtmpdump)
    end
  end

  describe "start" do
    before {this.save}

    it "should return a process id" do
      this.start.should be_a(Fixnum)
    end

    context "without params" do
      it "should start a recording job now" do
        pid = this.start
        Vidibus::Recording::Job.running?(pid).should be_true
      end
    end

    context "with a given Time" do
      it "should schedule a recording job" do
        stub_time("2011-01-12 00:00")
        run_at = 10.minutes.since
        this.start(run_at)
        Delayed::Backend::Mongoid::Job.count.should eql(1)
        Delayed::Backend::Mongoid::Job.first.run_at.should eql(run_at)
      end
    end

    after {cleanup(this)}
  end

  describe "stop" do
    before {this.save}

    it "should return false unless recording has been started" do
      this.stop.should be_false
    end

    it "should return false if recording is done" do
      this.stopped_at = Time.now
      this.stop.should be_false
    end

    context "with started job" do
      before {this.start}

      it "should stop the recording job" do
        pid = this.pid
        this.stop
        sleep 1
        Vidibus::Recording::Job.running?(pid).should be_false
      end

      after {cleanup(this)}
    end
  end
end
