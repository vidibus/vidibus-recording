# frozen_string_literal: true

# Capistrano Recipes for monitoring recordings.
#
# Load this file from your Capistrano config.rb:
# require 'vidibus/recording/capistrano/recipes'
#
# Add these callbacks to have the recording process restart when the server
# is restarted:
#
#   after 'deploy:stop',    'vidibus:recording:stop'
#   after 'deploy:start',   'vidibus:recording:start'
#   after 'deploy:restart', 'vidibus:recording:restart'
#
Capistrano::Configuration.instance.load do
  namespace :vidibus do
    namespace :recording do
      def rails_env
        fetch(:rails_env, false) ? "RAILS_ENV=#{fetch(:rails_env)}" : ""
      end

      desc "Stop the recording process"
      task :stop, roles: :app do
        run "cd #{current_path};#{rails_env} script/recording stop"
      end

      desc "Start the recording process"
      task :start, roles: :app do
        run "cd #{current_path};#{rails_env} script/recording start"
      end

      desc "Restart the recording process"
      task :restart, roles: :app do
        run "cd #{current_path};#{rails_env} script/recording restart"
      end
    end
  end
end
