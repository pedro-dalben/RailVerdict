# frozen_string_literal: true

module RailVerdict
  module Reporters
    module PRIntelligence
      SIGNAL_LABELS = {
        "database_change" => "Database",
        "authorization_change" => "Authorization",
        "routes_change" => "Routes",
        "dependency_change" => "Dependencies",
        "configuration_change" => "Configuration",
        "tests_change" => "Tests"
      }.freeze

      module_function

      def render(document)
        gate_result = document.fetch("gate_result")
        lines = ["RailVerdict PR Intelligence", "", "Gate: #{gate_result.fetch('gate')}", "Completion: #{gate_result.fetch('completion_status')}"]
        provenance = document.fetch("provenance")
        lines << "Revision: #{short(provenance['head'])} (base #{short(provenance['base'])})"

        change = document.fetch("change")
        lines << ""
        lines << "Change"
        if change["available"]
          lines << "  #{change.fetch('files_changed')} files"
          lines << "  +#{change['lines_added'] || '?'} / -#{change['lines_removed'] || '?'}"
          counts = change.fetch("status_counts")
          lines << "  added #{counts['added']}  modified #{counts['modified']}  deleted #{counts['deleted']}  renamed #{counts['renamed']}"
        else
          lines << "  unavailable (#{change.fetch('reason')})"
        end

        delta = document.fetch("quality_delta")
        lines << ""
        lines << "Quality Delta"
        if delta["available"]
          lines << "  introduced #{delta['introduced']}  resolved #{delta['resolved']}  existing #{delta['existing']}"
          lines << "  changed #{delta['changed']}  moved #{delta['moved']}  waived #{delta['waived']}  orphaned waivers #{delta['orphaned_waivers']}"
        else
          lines << "  unavailable (#{delta.fetch('reason')})"
        end

        lines << ""
        lines << "Signals"
        document.fetch("signals").each do |name, signal|
          label = SIGNAL_LABELS.fetch(name, name)
          value = signal["available"] ? (signal["present"] ? "YES" : "NO") : "N/A"
          lines << format("  %-14s %s", label, value)
        end

        lines << ""
        lines << "Evidence"
        evidence = document.fetch("analyzer_evidence")
        if evidence.empty?
          lines << "  none"
        else
          evidence.each { |entry| lines << "  #{entry.fetch('analyzer')}: #{entry.fetch('execution_status')}" }
        end

        tests = document.fetch("test_intelligence")
        lines << ""
        lines << "Tests: #{tests['available'] ? tests.fetch('analyzers').map { |name, summary| "#{name} #{summary['tests_total']} total, #{summary['failures']} failures" }.join('; ') : tests.fetch('reason')}"
        coverage = document.fetch("coverage")
        coverage_text = if coverage["available"]
          parts = []
          parts << "global #{coverage['global_percent']}%" if coverage.key?("global_percent")
          parts << "changed #{coverage['changed_lines_percent']}%" if coverage.key?("changed_lines_percent")
          parts.join(", ")
        else
          coverage.fetch("reason")
        end
        lines << "Coverage: #{coverage_text}"
        lines.join("\n") + "\n"
      end

      def short(value)
        value ? value.to_s[0, 12] : "unknown"
      end
      private_class_method :short
    end
  end
end
