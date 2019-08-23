# frozen_string_literal: true

class Recording
  include Mongoid::Document
  include Vidibus::Recording::Mongoid
end
