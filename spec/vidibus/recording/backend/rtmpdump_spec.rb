require 'spec_helper'
require 'vidibus/recording/backend/rtmpdump'

describe 'Vidibus::Recording::Backend::Rtmpdump' do

  def read_log(name)
    File.read("spec/support/backend/rtmpdump/#{name}.stdout")
  end

  let(:this) do
    Vidibus::Recording::Backend::Rtmpdump.new({
      :stream => 'rtmp://test', :file => 'test.rec'
    })
  end
  let(:success_v22) { read_log('success_v22') }
  let(:success_v23) { read_log('success_v23') }

  describe 'extract_metadata' do
    it 'should extract relevant metadata from RTMPDump v2.2' do
      this.extract_metadata(success_v22).should eql({
        'presetname' => 'Custom',
        'creationdate' => 'Mon Jan 17 15:22:50 2011',
        'videodevice' => 'Osprey-210 Video Device 1',
        'framerate' => '25.00',
        'width' => '680.00',
        'height' => '394.00',
        'videocodecid' => 'avc1',
        'videodatarate' => '650.00',
        'avclevel' => '31.00',
        'avcprofile' => '66.00',
        'audiodevice' => 'Osprey-210 Audio Device 1',
        'audiosamplerate' => '22050.00',
        'audiochannels' => '1.00',
        'audioinputvolume' => '75.00',
        'audiocodecid' => '.mp3',
        'audiodatarate' => '48.00'
      })
    end

    it 'should extract relevant metadata from RTMPDump v2.3' do
      this.extract_metadata(success_v23).should eql({
        'presetname' => 'Custom',
        'creationdate' => 'Mon Jan 17 15:22:50 2011',
        'videodevice' => 'Osprey-210 Video Device 1',
        'framerate' => '25.00',
        'width' => '680.00',
        'height' => '394.00',
        'videocodecid' => 'avc1',
        'videodatarate' => '650.00',
        'avclevel' => '31.00',
        'avcprofile' => '66.00',
        'audiodevice' => 'Osprey-210 Audio Device 1',
        'audiosamplerate' => '22050.00',
        'audiochannels' => '1.00',
        'audioinputvolume' => '75.00',
        'audiocodecid' => '.mp3',
        'audiodatarate' => '48.00'
      })
    end
  end
end