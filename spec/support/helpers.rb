# frozen_string_literal: true

def delete_safely(file)
  return unless file.match(/.{32}\..{3}/)
  File.delete(file) if File.exist?(file)
end
