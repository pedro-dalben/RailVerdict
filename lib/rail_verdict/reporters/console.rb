# frozen_string_literal: true

module RailVerdict
  module Reporters
    module Console
      module_function

      def render(result)
        lines = ["RailVerdict #{RailVerdict::VERSION}", "", "Analyzers"]
        result.analyzer_results.each do |analyzer|
          version = analyzer.tool_version ? " (#{analyzer.tool_version})" : ""
          lines << format(
            "  %s: %s%s, %d findings",
            analyzer.analyzer,
            analyzer.execution_status,
            version,
            analyzer.finding_ids.length
          )
        end
        lines << "  none" if result.analyzer_results.empty?

        lines << ""
        lines << "Findings"
        if result.findings.empty?
          lines << "  none"
        else
          result.findings.each do |finding|
            lines << format(
              "  %s [%s] %s %s",
              finding.fetch("severity"),
              finding.fetch("state"),
              finding.fetch("id"),
              finding.fetch("blocking") ? "blocking" : "advisory"
            )
          end
        end

        unless result.operational_failures.empty?
          lines << ""
          lines << "Operational failures"
          result.operational_failures.each do |failure|
            analyzer = failure["analyzer"] ? "#{failure['analyzer']}: " : ""
            lines << "  [#{failure.fetch('code')}] #{analyzer}#{sanitize(failure.fetch('message'))}"
          end
        end

        lines << ""
        lines << "Gate: #{result.gate}"
        lines << "Policy: #{result.policy_status}"
        lines << "Reasons"
        result.decision_reasons.each do |reason|
          lines << "  - #{reason.fetch('code')}: #{sanitize(reason.fetch('message'))}"
        end
        lines.join("\n") + "\n"
      end

      def sanitize(value)
        value.to_s.gsub(/[[:cntrl:]]/) { |character| character == "\n" ? " " : "?" }
      end
      private_class_method :sanitize
    end
  end
end
