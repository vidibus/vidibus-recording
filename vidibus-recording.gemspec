# encoding: utf-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'vidibus/recording/version'

Gem::Specification.new do |s|
  s.name        = 'vidibus-recording'
  s.version     = Vidibus::Recording::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = 'Andre Pankratz'
  s.email       = 'andre@vidibus.com'
  s.homepage    = 'https://github.com/vidibus/vidibus-recording'
  s.summary     = 'Video stream recording tools'
  s.description = 'Allows recording of RTMP video streams. Uses RTMPdump.'
  s.license     = 'MIT'

  s.required_rubygems_version = '>= 1.3.6'

  s.add_dependency 'activesupport'
  s.add_dependency 'mongoid'
  s.add_dependency 'delayed_job_mongoid'
  s.add_dependency 'vidibus-uuid'

  s.add_development_dependency 'bundler', '>= 1.0.0'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'rspec', '~> 2'
  s.add_development_dependency 'rr'
  s.add_development_dependency 'simplecov'

  s.files = Dir.glob('{lib,app,config}/**/*') + %w[LICENSE README.md Rakefile]
  s.require_path = 'lib'
end
