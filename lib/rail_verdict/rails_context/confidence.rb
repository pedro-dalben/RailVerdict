# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module Confidence
      VALUES = %w[exact conventional inferred unresolved].freeze

      def self.valid?(value)
        VALUES.include?(value.to_s)
      end
    end
  end
end
