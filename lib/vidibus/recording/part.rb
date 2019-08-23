# frozen_string_literal: true

require "yaml"
require "mongoid"
require "vidibus-uuid"

module Vidibus::Recording
  class Part
    include Mongoid::Document
    include Mongoid::Timestamps
    include Vidibus::Recording::Helpers

    SIZE_THRESHOLD = 2000

    embedded_in :recording, polymorphic: true

    field :number, type: Integer
    field :info, type: Hash
    field :size, type: Integer
    field :duration, type: Integer
    field :started_at, type: DateTime
    field :stopped_at, type: DateTime

    validates :number, presence: true

    before_destroy :remove_files

    # Returns the file path of this part.
    def data_file
      @data_file ||= "#{basename}.f4v"
    end

    # Returns the YAML file path of this part.
    def yml_file
      @yml_file ||= "#{basename}.yml"
    end

    def has_data?
      size.to_i >= SIZE_THRESHOLD
    end

    def stopped?
      !!stopped_at
    end

    def reset
      remove_files
      blanks = {}
      [
        :info,
        :size,
        :duration,
        :started_at
      ].map { |a| blanks[a] = nil }
      update_attributes(blanks)
    end

    def track_progress
      set_size
      set_duration
    end

    def postprocess
      process_yml_file
      track_progress
      self.stopped_at = Time.now
    end

    def start
      self.started_at = Time.now
      self.stopped_at = nil
    end

    private

    def process_yml_file
      if str = read_and_delete_file(yml_file)
        if values = YAML.load(str)
          fix_value_classes!(values)
          self.info = values
        end
      end
    end

    def set_size
      self.size = File.exist?(data_file) ? File.size(data_file) : 0
    end

    def set_duration
      self.duration = has_data? ? Time.now - started_at : 0
    end

    def read_and_delete_file(file)
      if File.exist?(file)
        str = File.read(file)
        File.delete(file)
        str
      end
    end

    def basename
      "#{_parent.basename}_#{number}"
    end

    def remove_files
      [data_file, yml_file].each do |f|
        File.delete(f) if File.exist?(f)
      end
    end
  end
end
