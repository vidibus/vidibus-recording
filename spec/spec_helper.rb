$:.unshift File.expand_path('../../', __FILE__)

require "rspec"
require "rr"
require "mongoid"

require "vidibus-recording"
require "app/models/recording"

Mongoid.configure do |config|
  name = "vidibus-recording_test"
  host = "localhost"
  config.master = Mongo::Connection.new.db(name)
  config.logger = nil
end

RSpec.configure do |config|
  config.mock_with :rr
  config.before(:each) do
    Mongoid.master.collections.select {|c| c.name !~ /system/}.each(&:drop)
  end
end

# Helper for stubbing time. Define String to be set as Time.now.
# Usage:
#   stub_time('01.01.2010 14:00')
#   stub_time(2.days.ago)
#
def stub_time(string = nil)
  string ||= Time.now.to_s(:db)
  now = Time.parse(string.to_s)
  stub(Time).now { now }
  now
end

#I18n.load_path += Dir[File.join('config', 'locales', '**', '*.{rb,yml}')]
