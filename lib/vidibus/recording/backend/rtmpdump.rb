module Vidibus::Recording::Backend
  class Rtmpdump

    PROTOCOLS = %[rtmp rtmpt rtmpe rtmpte rtmps rtmpts]

    attr_accessor :stream, :file, :live, :metadata

    def initialize(attributes)
      self.stream = attributes[:stream] or raise ConfigurationError.new("No input stream given")
      self.file = attributes[:file] or raise ConfigurationError.new("No output file defined")
      self.live = attributes[:live]
    end

    # Command for starting the recording.
    def command
      args = [].tap do |a|
        a << "-r #{stream}"
        a << "-o #{file}"
        a << "--live" if live
      end
      %(rtmpdump #{args.join(" ")} 2>&1)
    end

    # Extract metadata from stdout or stderr.
    # Output delivered by rtmpdump looks like this:
    #
    # RTMPDump v2.2
    # (c) 2010 Andrej Stepanchuk, Howard Chu, The Flvstreamer Team; license: GPL
    # Connecting ...
    # ERROR: rtmp server sent error
    # Starting Live Stream
    # Metadata:
    #   author
    #   copyright
    #   description
    #   keywords
    #   rating
    #   title
    #   presetname            Custom
    #   creationdate          Mon Jan 17 15:22:50 2011
    #   videodevice           Osprey-210 Video Device 1
    #   framerate             25.00
    #   width                 680.00
    #   height                394.00
    #   videocodecid          avc1
    #   videodatarate         650.00
    #   avclevel              31.00
    #   avcprofile            66.00
    #   videokeyframe_frequency5.00
    #   audiodevice           Osprey-210 Audio Device 1
    #   audiosamplerate       22050.00
    #   audiochannels         1.00
    #   audioinputvolume      75.00
    #   audiocodecid          .mp3
    #   audiodatarate         48.00
    #
    def extract_metadata(std)
      if metadata = std.match(/Metadata\:\n\s+(.+)\Z/m)
        tuples = $1.scan(/([^\n\ \d]+)\ +([^\ ][^\n]+)\n/mi)
        self.metadata = Hash[tuples]
      end
    end
  end
end
