# frozen_string_literal: true

require "vidibus/recording/backend/rtmpdump"

module Vidibus::Recording
  module Backend
    class RtmpStreamError < StandardError; end
    class RuntimeError < StandardError; end
    class ConfigurationError < StandardError; end
    class ProtocolError < ConfigurationError; end

    BACKENDS = %w[rtmpdump]

    # Returns an instance of a backend processor
    # that is able to record the given stream.
    def self.load(attributes)
      stream = attributes[:stream]
      raise ConfigurationError.new("No input stream given") unless stream
      protocol = stream.match(/^[^:]+/).to_s
      raise ProtocolError.new(%(No protocol could be derived stream "#{stream}")) if protocol == ""

      for backend in BACKENDS
        backend_class = "Vidibus::Recording::Backend::#{backend.classify}".constantize
        if backend_class::PROTOCOLS.include?(protocol)
          return backend_class.new(attributes)
        end
      end
      raise ProtocolError.new(%(No recording backend available for "#{protocol}" protocol.))
    end
  end
end
