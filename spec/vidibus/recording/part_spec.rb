# frozen_string_literal: true

require "spec_helper"

describe "Vidibus::Recording::Part" do
  let(:recording) do
    Recording.create(
      name: "Example Stream",
      stream: "rtmp://example.host"
    )
  end
  let(:part) do
    recording.parts.create!(number: 1)
  end

  describe "validation" do
    let(:part) do
      recording.parts.build(number: 1)
    end

    it "should pass with valid attributes" do
      part.should be_valid
    end

    it "should fail without a number" do
      part.number = nil
      part.should be_invalid
    end
  end

  describe "#data_file" do
    it "should return a string matching <uuid>_<number>.f4v" do
      part.data_file.
        should eq("recordings/#{recording.uuid}_#{part.number}.f4v")
    end
  end

  describe "#yml_file" do
    it "should return a string matching <uuid>_<number>.log" do
      part.yml_file.
        should eq("recordings/#{recording.uuid}_#{part.number}.yml")
    end
  end

  describe "#has_data?" do
    it "should return false if this part has no size" do
      stub(part).size { }
      part.has_data?.should be_falsey
    end

    it "should return false if this part has a size smaller than 2000 bytes" do
      stub(part).size { 1999 }
      part.has_data?.should be_falsey
    end

    it "should return true if this part has a size of at least 2000 bytes" do
      stub(part).size { 2000 }
      part.has_data?.should be_truthy
    end
  end

  describe "#track_progress" do
    it "should set the size from data file"

    it "should set the duration"
  end

  describe "#postprocess" do
    it "should process the yml file"

    it "should call #track_progress"
  end
end
