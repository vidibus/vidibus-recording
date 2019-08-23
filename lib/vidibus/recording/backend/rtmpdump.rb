# frozen_string_literal: true

module Vidibus::Recording::Backend
  class Rtmpdump
    PROTOCOLS = %[rtmp rtmpt rtmpe rtmpte rtmps rtmpts]

    attr_accessor :stream, :file, :live, :metadata

    class << self
      attr_writer :executable
    end

    def self.executable
      @executable || "rtmpdump"
    end

    # Sets up a new dumper.
    #
    # Required attributes:
    #   :stream, :file
    #
    # Optional:
    #   :live
    #
    def initialize(attributes)
      self.stream = attributes[:stream]
      self.file = attributes[:file]
      self.live = attributes[:live]
      raise ConfigurationError.new("No output file defined") unless file
      raise ConfigurationError.new("No input stream given") unless stream
    end

    # Command for starting the recording.
    def command
      args = [].tap do |a|
        a << "-r #{stream}"
        a << "-o #{file}"
        a << "--live" if live
      end
      %(#{self.class.executable} #{args.join(" ")} 2>&1)
    end

    # Extract metadata from stdout or stderr.
    # Output delivered by rtmpdump looks like this:
    #
    # RTMPDump v2.2
    # (c) 2010 Andrej Stepanchuk, Howard Chu, The Flvstreamer Team
    # Connecting ...
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
    def extract_metadata(string)
      prefix = /(?:INFO\:\ *)/ if string.match?(/INFO\:/) # INFO: gets prepended since v2.3
      if metadata = string.match(/#{prefix}Metadata\:\n(.+)\Z/m)
        tuples = $1.scan(/#{prefix}([^\n\ \d]+)\ +([^\ \n][^\n]+)\n/)
        self.metadata = Hash[tuples]
      end
    end

    # Detect error from stdout or stderr.
    # Output delivered by rtmpdump looks like this:
    #
    # RTMPDump v2.4
    # (c) 2010 Andrej Stepanchuk, Howard Chu, The Flvstreamer Team
    # Connecting ...
    # ERROR: Problem accessing the DNS. (addr: whatever.domain)
    #
    def detect_error(string)
      if error = string[/(?:ERROR\:\ (.+))/, 1]
        case error
        when "rtmp server sent error"
        else
          raise RtmpStreamError.new($1)
        end
      end
    end
  end
end
