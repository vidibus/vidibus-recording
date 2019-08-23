# frozen_string_literal: true

module Vidibus::Recording
  module Helpers
    # Recursively fixes classes of value strings
    def fix_value_classes!(value)
      c = value.class

      # Get nested items in Hash
      if c == Hash
        value.each do |v|
          value[v[0]] = fix_value_classes!(v[1])
        end

      # Get nested items in Array
      elsif c == Array
        value.each_with_index do |v, i|
          value[i] = fix_value_classes!(v)
        end

      # Fix classes of values
      else
        if value.match? /^\d+[\.,]\d+$/
          value = value.to_f
        elsif value.match? /^\d+$/
          value = value.to_i
        elsif value.match? /^true$/
          value = true
        elsif value.match? /^false$/
          value = false
        end
      end
      value
    end
  end
end
