# frozen_string_literal: true

module RailVerdict
  module Reporters
    # Bounded console projection of an engineering-policy-v1 envelope.
    # Presentation only: requirement identity lives in the JSON document.
    module EngineeringPolicy
      MAX_OBSERVED = 5

      module_function

      def render(document)
        lines = []
        lines << "Engineering policy: #{document['decision']} (gate #{document['gate']})"
        lines << "Policy: #{short(document['policy_digest'])}  Config: #{short(document['configuration_digest'])}"
        requirements = document["requirements"] || []
        if requirements.empty?
          lines << "Requirements: none configured; decision mirrors the deterministic gate."
        else
          lines << "Requirements:"
          requirements.each do |entry|
            lines << "  [#{entry['status']}] #{entry['id']} — #{entry['trigger']}"
            observed = Array(entry["observed_evidence"])
            unless observed.empty?
              head = observed.first(MAX_OBSERVED)
              head.each { |line| lines << "      #{truncate(line.to_s)}" }
              extra = observed.length - head.length
              lines << "      (+#{extra} more)" if extra.positive?
            end
            lines << "      recovery: #{entry['recovery_action']}" if entry["recovery_action"]
          end
        end
        drift = document["drift"]
        lines << "Policy drift: #{drift['status']} (#{drift['code']})" if drift.is_a?(Hash)
        lines << "Reason codes: #{Array(document['reason_codes']).join(', ')}"
        "#{lines.join("\n")}\n"
      end

      def short(digest)
        digest.is_a?(String) ? digest[0, 12] : "unknown"
      end
      private_class_method :short

      def truncate(text)
        text.length > 160 ? "#{text[0, 157]}..." : text
      end
      private_class_method :truncate
    end
  end
end
