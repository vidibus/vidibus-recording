# frozen_string_literal: true

require "spec_helper"

describe "Vidibus::Recording::Backend" do
  describe ".load" do
    it "should return an error unless a stream attribute is given" do
      expect {
        Vidibus::Recording::Backend.load({})
      }.to raise_error(Vidibus::Recording::Backend::ConfigurationError)
    end

    it "should return a backend instance for given stream protocol" do
      Vidibus::Recording::Backend.load(
        stream: "rtmp://something", file: "test"
        ).should be_an_instance_of(Vidibus::Recording::Backend::Rtmpdump)
    end

    it "should return an error unless a stream attribute with consumable protocol is given" do
      expect {
        Vidibus::Recording::Backend.load(
          stream: "mms://something", file: "test"
        )
      }.to raise_error(Vidibus::Recording::Backend::ProtocolError)
    end

    it "should return an error unless a stream attribute with a protocol is given" do
      expect {
        Vidibus::Recording::Backend.load(
          stream: "something", file: "test"
        )
      }.to raise_error(Vidibus::Recording::Backend::ProtocolError)
    end
  end
end
