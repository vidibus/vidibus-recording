require "open3"
require "yaml"
require "delayed_job_mongoid"
require "active_support/core_ext"
require "vidibus-uuid"

module Vidibus
  module Recording
    if defined?(Rails)
      class Engine < ::Rails::Engine; end
    end
  end
end

$:.unshift(File.join(File.dirname(__FILE__), "vidibus"))
require "recording"
