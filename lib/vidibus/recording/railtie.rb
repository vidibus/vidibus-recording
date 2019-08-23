# frozen_string_literal: true

require "rails"

module Vidibus
  module Recording
    if defined?(Rails)
      class Engine < ::Rails::Engine; end
    end
  end
end
