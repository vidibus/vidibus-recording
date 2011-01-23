# -*- encoding: utf-8 -*-
require File.expand_path("../lib/vidibus/recording/version", __FILE__)

Gem::Specification.new do |s|
  s.name              = "vidibus-recording"
  s.rubyforge_project = "vidibus-recording"
  s.version           = Vidibus::Recording::VERSION
  s.platform          = Gem::Platform::RUBY
  s.authors           = "Andre Pankratz"
  s.email             = "andre@vidibus.com"
  s.homepage          = "http://rubygems.org/gems/vidibus-rtmpdump"
  s.summary           = "Video stream recording tools"
  s.description       = "Allows recording of RTMP video streams. Uses RTMPdump."

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency "mongoid", "~> 2.0.0.beta.20"
  s.add_dependency "open4"
  s.add_dependency "robustthread"
  s.add_dependency "delayed_job_mongoid"

  s.add_dependency "vidibus-uuid"

  s.add_development_dependency "bundler", ">= 1.0.0"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 2.0.0.beta.20"
  s.add_development_dependency "rr"
  s.add_development_dependency "relevance-rcov"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
