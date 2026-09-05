# frozen_string_literal: true

require "json"
require "json_schemer"

module RailVerdict
  module SchemaValidator
    CONFIGURATION_SCHEMA = "configuration-v1.schema.json"
    CONFIGURATION_V17_SCHEMA = "configuration-v1.7.schema.json"
    CONFIGURATION_V16_SCHEMA = "configuration-v1.6.schema.json"
    CONFIGURATION_V11_SCHEMA = "configuration-v1.1.schema.json"
    CONFIGURATION_V12_SCHEMA = "configuration-v1.2.schema.json"
    CONFIGURATION_V13_SCHEMA = "configuration-v1.3.schema.json"
    CONFIGURATION_V14_SCHEMA = "configuration-v1.4.schema.json"
    CONFIGURATION_V15_SCHEMA = "configuration-v1.5.schema.json"
    AI_ANALYSIS_SCHEMA = "ai-analysis-v1.schema.json"
    FINDING_SCHEMA = "finding-v1.schema.json"
    RESULT_SCHEMA = "result-v1.schema.json"
    BASELINE_SCHEMA = "baseline-v1.schema.json"
    WAIVER_SCHEMA = "waiver-v1.schema.json"
    WAIVERS_SCHEMA = "waivers-v1.schema.json"
    REPAIR_PACKET_SCHEMA = "repair-packet-v1.schema.json"
    PR_INTELLIGENCE_SCHEMA = "pr-intelligence-v1.schema.json"
    PR_INTELLIGENCE_V11_SCHEMA = "pr-intelligence-v1.1.schema.json"
    VERIFICATION_RECEIPT_SCHEMA = "verification-receipt-v1.schema.json"
    VERIFICATION_HANDOFF_SCHEMA = "verification-handoff-v1.schema.json"
    ENGINEERING_POLICY_SCHEMA = "engineering-policy-v1.schema.json"

    def self.schema_dir
      File.expand_path("../../schemas", __dir__)
    end

    def self.validate_configuration(data)
      schema_name = if data.is_a?(Hash) && data["version"] == 1.7
                      CONFIGURATION_V17_SCHEMA
                    elsif data.is_a?(Hash) && data["version"] == 1.6
                      CONFIGURATION_V16_SCHEMA
                    elsif data.is_a?(Hash) && data["version"] == 1.5
                      CONFIGURATION_V15_SCHEMA
                    elsif data.is_a?(Hash) && data["version"] == 1.4
                      CONFIGURATION_V14_SCHEMA
                    elsif data.is_a?(Hash) && data["version"] == 1.3
                      CONFIGURATION_V13_SCHEMA
                    elsif data.is_a?(Hash) && data["version"] == 1.2
                      CONFIGURATION_V12_SCHEMA
                    elsif data.is_a?(Hash) && data["version"] == 1.1
                      CONFIGURATION_V11_SCHEMA
                    else
                      CONFIGURATION_SCHEMA
                    end
      validate(data, schema_name)
    end

    def self.validate_ai_analysis(data)
      validate(data, AI_ANALYSIS_SCHEMA)
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

    def self.validate_waiver(data)
      validate(data, WAIVER_SCHEMA)
    end

    def self.validate_waivers(data)
      validate(data, WAIVERS_SCHEMA)
    end

    def self.validate_repair_packet(data)
      validate(data, REPAIR_PACKET_SCHEMA)
    end

    def self.validate_pr_intelligence(data)
      schema_name = data.is_a?(Hash) && data["schema_version"] == "1.1" ? PR_INTELLIGENCE_V11_SCHEMA : PR_INTELLIGENCE_SCHEMA
      validate(data, schema_name)
    end

    def self.validate_change_intelligence(data)
      validate_pr_intelligence(data)
    end

    def self.validate_receipt(data)
      validate(data, VERIFICATION_RECEIPT_SCHEMA)
    end

    def self.validate_receipt_validation(data)
      validate(data, RECEIPT_VALIDATION_SCHEMA)
    end

    def self.validate_handoff(data)
      validate(data, VERIFICATION_HANDOFF_SCHEMA)
    end

    def self.validate_engineering_policy(data)
      validate(data, ENGINEERING_POLICY_SCHEMA)
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
