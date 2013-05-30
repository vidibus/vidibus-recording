module Vidibus::Recording
  module Backend
    class ConfigurationError < StandardError; end
    class ProtocolError < ConfigurationError; end

    BACKENDS = %w[rtmpdump]

    # Returns an instance of a backend processor
    # that is able to record the given stream.
    def self.load(attributes)
      stream = attributes[:stream] or raise ConfigurationError.new("No input stream given")
      protocol = stream.match(/^[^:]+/).to_s
      raise ProtocolError.new(%(No protocol could be derived stream "#{stream}")) if protocol == ""

      for backend in BACKENDS
        require "vidibus/recording/backend/#{backend}"
        backend_class = "Vidibus::Recording::Backend::#{backend.classify}".constantize
        if backend_class::PROTOCOLS.include?(protocol)
          return backend_class.new(attributes)
        end
      end
      raise ProtocolError.new(%(No recording backend available for "#{protocol}" protocol.))
    end
  end
end
