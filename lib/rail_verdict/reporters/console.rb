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

        if result.baseline
          baseline = result.baseline
          if baseline["loaded"]
            lines << ""
            lines << "Baseline: loaded #{baseline['path']} (v#{baseline['schema_version']}, fp v#{baseline['fingerprint_version']})"
          else
            lines << ""
            lines << "Baseline: none (#{baseline['path']})"
          end
        end

        if result.comparison
          counts = result.comparison["counts"] || {}
          lines << ""
          lines << format("Comparison: Introduced: %d  Existing: %d  Resolved: %d  Changed: %d  Moved: %d  Waived: %d",
            counts["introduced"] || 0, counts["existing"] || 0, counts["resolved"] || 0,
            counts["changed"] || 0, counts["moved"] || 0, counts["waived"] || 0)
        end

        if result.git
          git = result.git
          if git["error"]
            lines << ""
            lines << "Git: error #{sanitize(git.fetch('error'))}: #{sanitize(git.fetch('error_message', ''))}"
          else
            changed_count = (git["changed_files"] || []).length
            lines << ""
            lines << format("Git: head %s base %s merge-base %s (%d changed files)",
              sanitize(git["head"].to_s[0, 7]), sanitize(git["base"].to_s[0, 7]), sanitize(git["merge_base"].to_s[0, 7]), changed_count)
            lines << "Scope: changed" if git["head"] && git["merge_base"]
          end
        end

        if result.rails_context
          rc = result.rails_context
          entries = rc["entries"] || []
          detected = rc["detected"] || {}
          lines << ""
          lines << format("Rails context: %d entries (%s, %s)",
            entries.length,
            sanitize(detected["rails_version"] || "no rails"),
            sanitize(rc["scope"] || "unknown"))
        end

        append_change_intelligence(lines, result)

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

      # Compact reviewer summary for changed-scope runs. Path-derived only;
      # verification scope reflects executed analyzer evidence.
      def append_change_intelligence(lines, result)
        git = result.git
        return unless git.is_a?(Hash) && git["error"].nil?

        paths = Array(git["changed_files"]).map { |file| file["path"] }.compact
        surfaces = RailVerdict::ChangeSurfaces.detect(paths, available: true)
        signals = RailVerdict::ChangeIntelligence.review_signals(surfaces, [])
        risk = RailVerdict::ChangeIntelligence.review_risk(signals, {})
        lines << ""
        lines << "Review risk: #{risk.fetch('level')}"
        lines << "  reasons: #{risk.fetch('reasons').join(', ')}" unless risk.fetch("reasons").empty?
        sensitive = surfaces.select { |_, entry| entry["changed"] && entry["sensitive"] }
        lines << "Sensitive surfaces: #{sensitive.empty? ? 'none' : sensitive.map { |id, _| sanitize(RailVerdict::ChangeSurfaces::SURFACES[id]['label']) }.join(', ')}"
        scopes = executed_test_scopes(result)
        lines << "Tests: #{scopes.empty? ? 'no test evidence' : scopes.join('; ')}"
        focus = RailVerdict::ChangeIntelligence.review_focus(surfaces, [])
        unless focus.empty?
          lines << "Reviewer focus:"
          focus.first(3).each { |item| lines << "  #{item.fetch('rank')}. #{sanitize(item.fetch('title'))}" }
        end
        nil
      end
      private_class_method :append_change_intelligence


      def executed_test_scopes(result)
        result.analyzer_results.filter_map do |analyzer|
          next unless %w[rspec minitest].include?(analyzer.analyzer)

          summary = analyzer.evidence_summary
          scope = summary.is_a?(Hash) ? summary["test_scope"] : nil
          "#{analyzer.analyzer} #{scope || analyzer.execution_status}"
        end
      end
      private_class_method :executed_test_scopes
    end
  end
end
