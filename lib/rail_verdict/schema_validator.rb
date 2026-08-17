# frozen_string_literal: true

require "json"
require "json_schemer"

module RailVerdict
  module SchemaValidator
    CONFIGURATION_SCHEMA = "configuration-v1.schema.json"
    CONFIGURATION_V11_SCHEMA = "configuration-v1.1.schema.json"
    CONFIGURATION_V12_SCHEMA = "configuration-v1.2.schema.json"
    FINDING_SCHEMA = "finding-v1.schema.json"
    RESULT_SCHEMA = "result-v1.schema.json"
    BASELINE_SCHEMA = "baseline-v1.schema.json"

    def self.schema_dir
      File.expand_path("../../schemas", __dir__)
    end

    def self.validate_configuration(data)
      schema_name = if data.is_a?(Hash) && data["version"] == 1.2
                      CONFIGURATION_V12_SCHEMA
                    elsif data.is_a?(Hash) && data["version"] == 1.1
                      CONFIGURATION_V11_SCHEMA
                    else
                      CONFIGURATION_SCHEMA
                    end
      validate(data, schema_name)
    end

    def self.validate_finding(data)
      validate(data, FINDING_SCHEMA)
    end

    def self.validate_result(data)
      validate(data, RESULT_SCHEMA)
    end

    def self.validate_baseline(data)
      validate(data, BASELINE_SCHEMA)
    end

    def self.validate(data, schema_name)
      schema = load_schema(schema_name)
      JSONSchemer.schema(schema).validate(data).map { |error| format_error(error) }
    end

    def self.load_schema(schema_name)
      JSON.parse(File.read(File.join(schema_dir, schema_name)))
    end

    def self.format_error(error)
      pointer = error["data_pointer"].to_s
      location = pointer.empty? ? "$" : "$#{pointer.gsub('/', '.')}"
      "#{location}: #{error["error"]}"
    end

    private_class_method :load_schema, :format_error
  end
end
