# frozen_string_literal: true

require "json"

module RailVerdict
  module Reporters
    module JsonReporter
      module_function

      def render(result)
        document = result.to_schema_h
        if document.key?("baseline") || document.key?("comparison")
          JSON.generate(document) + "\n"
        else
          errors = SchemaValidator.validate_result(document)
          raise RailVerdict::Error, "result-v1 validation failed: #{errors.join('; ')}" unless errors.empty?

          JSON.generate(document) + "\n"
        end
      end
    end
  end
end
