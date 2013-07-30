
module Vidibus
  module Recording
    if defined?(Rails)
      class Engine < ::Rails::Engine; end
    end
  end
end

require 'vidibus/recording'
