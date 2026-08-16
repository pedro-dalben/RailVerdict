# frozen_string_literal: true

module RailVerdict
  class Error < StandardError; end

  class UsageError < Error; end

  class ConfigurationError < Error
    attr_reader :source_path, :property_path

    def initialize(message, source_path: nil, property_path: nil)
      super(message)
      @source_path = source_path
      @property_path = property_path
    end
  end
end
