# frozen_string_literal: true

module RailVerdict
  module FindingsCommand
    module_function

    def document(outcome)
      {
        "schema_version" => "1.0",
        "findings" => outcome.findings.sort_by(&:sort_key).map(&:to_schema_h)
      }
    end

    def console(outcome)
      return "No findings.\n" if outcome.findings.empty?

      outcome.findings.sort_by(&:sort_key).map do |finding|
        location = finding.location
        line = location["start_line"] ? ":#{location['start_line']}" : ""
        rule = finding.rule_id
        rule_display = if rule.start_with?("#{finding.analyzer}/") || rule.start_with?("#{finding.analyzer}:")
                         rule
                       else
                         "#{finding.analyzer}/#{rule}"
                       end
        "#{location.fetch('path')}#{line} [#{finding.severity}] #{rule_display}: #{finding.message}"
      end.join("\n") + "\n"
    end
  end
end
