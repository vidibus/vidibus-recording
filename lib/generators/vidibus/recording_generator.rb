# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module Vidibus
  class RecordingGenerator < Rails::Generators::Base
    self.source_paths << File.join(File.dirname(__FILE__), "templates")

    def create_script_file
      template "script", "script/recording"
      chmod "script/recording", 0755
    end
  end
end
