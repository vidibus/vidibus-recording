# frozen_string_literal: true

require "spec_helper"
require "vidibus/recording/backend/rtmpdump"

describe "Vidibus::Recording::Backend::Rtmpdump" do
  def read_log(name)
    File.read("spec/support/backend/rtmpdump/#{name}.stdout")
  end

  let(:subject) do
    Vidibus::Recording::Backend::Rtmpdump.new(
      stream: "rtmp://test", file: "test.rec"
    )
  end
  let(:success_v22) { read_log("success_v22") }
  let(:success_v23) { read_log("success_v23") }
  let(:success_v24) { read_log("success_v24") }
  let(:error_v24) { read_log("error_v24") }

  describe "#extract_metadata" do
    it "should extract relevant metadata from RTMPDump v2.2" do
      subject.extract_metadata(success_v22).should eql(
        "presetname" => "Custom",
        "creationdate" => "Mon Jan 17 15:22:50 2011",
        "videodevice" => "Osprey-210 Video Device 1",
        "framerate" => "25.00",
        "width" => "680.00",
        "height" => "394.00",
        "videocodecid" => "avc1",
        "videodatarate" => "650.00",
        "avclevel" => "31.00",
        "avcprofile" => "66.00",
        "audiodevice" => "Osprey-210 Audio Device 1",
        "audiosamplerate" => "22050.00",
        "audiochannels" => "1.00",
        "audioinputvolume" => "75.00",
        "audiocodecid" => ".mp3",
        "audiodatarate" => "48.00"
      )
    end

    it "should extract relevant metadata from RTMPDump v2.3" do
      subject.extract_metadata(success_v23).should eql(
        "presetname" => "Custom",
        "creationdate" => "Mon Jan 17 15:22:50 2011",
        "videodevice" => "Osprey-210 Video Device 1",
        "framerate" => "25.00",
        "width" => "680.00",
        "height" => "394.00",
        "videocodecid" => "avc1",
        "videodatarate" => "650.00",
        "avclevel" => "31.00",
        "avcprofile" => "66.00",
        "audiodevice" => "Osprey-210 Audio Device 1",
        "audiosamplerate" => "22050.00",
        "audiochannels" => "1.00",
        "audioinputvolume" => "75.00",
        "audiocodecid" => ".mp3",
        "audiodatarate" => "48.00"
      )
    end

    it "should extract relevant metadata from RTMPDump v2.4" do
      subject.extract_metadata(success_v24).should eql(
        "audiocodecid" => "10.00",
        "audiodatarate" => "124.89",
        "audiosamplerate" => "48000.00",
        "audiosamplesize" => "16.00",
        "comment" => "www.dvdvideosoft.com",
        "compatible_brands" => "mp42isomavc1",
        "creation_time" => "2013-02-26 13:47:56",
        "date" => "2013",
        "duration" => "0.00",
        "encoder" => "Lavf53.8.0",
        "filesize" => "0.00",
        "framerate" => "25.00",
        "height" => "350.00",
        "major_brand" => "mp42",
        "stereo" => "TRUE",
        "videocodecid" => "7.00",
        "videodatarate" => "976.57",
        "width" => "620.00"
      )
    end
  end

  describe "#detect_error" do
    context "on a successful request" do
      it "should not raise an error with RTMPDump v2.2" do
        expect { subject.detect_error(success_v22) }.
          not_to raise_error()
      end

      it "should not raise an error with RTMPDump v2.3" do
        expect { subject.detect_error(success_v23) }.
          not_to raise_error()
      end

      it "should not raise an error with RTMPDump v2.4" do
        expect { subject.detect_error(success_v24) }.
          not_to raise_error()
      end
    end

    context "on a request with invalid url" do
      it "should raise an error with RTMPDump v2.4" do
        expect { subject.detect_error(error_v24) }.
          to raise_error("Problem accessing the DNS. (addr: whatever.domain)")
      end
    end
  end
end
