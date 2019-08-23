# frozen_string_literal: true

require "vidibus/recording/capistrano/recipes"

# Run Capistrano Recipes for monitoring recordings.
#
# Load this file from your Capistrano config.rb:
# require 'vidibus/recording/capistrano'
#
Capistrano::Configuration.instance.load do
  after "deploy:stop",    "vidibus:recording:stop"
  after "deploy:start",   "vidibus:recording:start"
  after "deploy:restart", "vidibus:recording:restart"
end
