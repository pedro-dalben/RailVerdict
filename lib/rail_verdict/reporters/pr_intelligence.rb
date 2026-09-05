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

        risk = document.fetch("review_risk")
        lines << ""
        lines << "Review risk: #{risk.fetch('level')}"
        lines << "  reasons: #{risk.fetch('reasons').join(', ')}" unless risk.fetch("reasons").empty?

        lines << ""
        lines << "Sensitive surfaces"
        sensitive = document.fetch("surfaces").select { |_, entry| entry["changed"] && entry["sensitive"] }
        project_hit = Array(document.fetch("project_sensitive_areas")).select { |area| area["changed"] }
        if sensitive.empty? && project_hit.empty?
          lines << "  none"
        else
          sensitive.each do |id, entry|
            lines << "  #{label_for(id)} (#{entry.fetch('evidence').length} files, #{entry.fetch('detection')})"
          end
          project_hit.each { |area| lines << "  #{area.fetch('name')} (project-defined, #{area.fetch('evidence').length} files)" }
        end

        scope = document.fetch("verification_scope")
        lines << ""
        lines << "Verification scope"
        if scope["available"]
          scope.fetch("frameworks").each do |name, entry|
            detail = entry["scope"].upcase
            detail += " (#{entry.fetch('selected_files').length} files)" if entry["selected_files"]
            detail += " fallback: #{entry.fetch('fallback_reason')}" if entry["fallback_reason"]
            detail += " [not executed]" if entry["executed"] == false
            lines << "  #{name}: #{detail}"
          end
        else
          lines << "  unavailable (#{scope.fetch('reason')})"
        end

        missing = document.fetch("missing_evidence")
        unless missing.empty?
          lines << ""
          lines << "Missing evidence"
          missing.each { |gap| lines << "  #{gap.fetch('code')}: #{gap.fetch('reason')}" }
        end

        focus = document.fetch("review_focus")
        lines << ""
        lines << "Reviewer focus"
        if focus.empty?
          lines << "  none"
        else
          focus.first(10).each do |item|
            lines << "  #{item.fetch('rank')}. #{item.fetch('title')} (#{item.fetch('paths').length + item.fetch('additional_evidence_count')} files)"
          end
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

      def label_for(surface_id)
        spec = RailVerdict::ChangeSurfaces::SURFACES[surface_id.to_s]
        spec ? spec["label"] : surface_id.to_s
      end
      private_class_method :label_for

      def short(value)
        value ? value.to_s[0, 12] : "unknown"
      end
      private_class_method :short
    end
  end
end
