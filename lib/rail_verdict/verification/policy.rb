# frozen_string_literal: true

module RailVerdict
  module Verification
    module Policy
      module_function

      def evaluate(configuration:, analyzer_results:, findings:, comparison: nil, baseline_meta: nil, git_context: nil)
        analyzer_results = analyzer_results.sort_by(&:analyzer)
        findings = findings.sort_by(&:sort_key)
        operational_failures = []
        required_incomplete = []

        configuration.analyzers.each do |analyzer, selection|
          next unless selection.fetch("enabled")

          result = analyzer_results.find { |candidate| candidate.analyzer == analyzer }
          if result.nil?
            failure = { "code" => "unavailable", "analyzer" => analyzer, "message" => "required analyzer did not produce a result" }
            operational_failures << failure
            required_incomplete << failure if selection.fetch("required")
          elsif result.evidence_status == "incomplete"
            failure = {
              "code" => result.failure.fetch("code"),
              "analyzer" => analyzer,
              "message" => result.failure.fetch("message")
            }
            operational_failures << failure
            required_incomplete << failure if selection.fetch("required")
          elsif selection.fetch("required") && (failure = incomplete_evidence_failure(analyzer, result))
            operational_failures << failure
            required_incomplete << failure
          end
        end

        unless required_incomplete.empty?
          return GateResult.new(
            completion_status: "incomplete",
            gate: "INCOMPLETE",
            policy_status: "not_evaluated",
            findings: summaries(findings, blocking: false),
            analyzer_results: analyzer_results,
            operational_failures: required_incomplete,
            decision_reasons: [{
              "code" => "required_evidence_incomplete",
              "message" => "Required analyzer evidence is incomplete; policy was not evaluated."
            }]
          )
        end

        optional_failures = operational_failures.reject { |failure| required_incomplete.include?(failure) }

        changed_findings = if git_context
                             filter_to_changed_scope(findings, git_context)
                           else
                             findings
                           end

        mode = configuration.mode

        if mode == "advisory" && git_context
          scoped = changed_findings
          gate = scoped.empty? ? "PASS" : "WARN"
          policy_status = gate.downcase
          reasons = []
          reasons << if scoped.empty?
                       if findings.empty?
                         { "code" => "no_findings_detected", "message" => "All enabled analyzer evidence contains no findings." }
                       else
                         { "code" => "advisory_no_changed_findings", "message" => "No findings in changed scope; #{findings.length} findings outside changed scope are advisory." }
                       end
                     else
                       { "code" => "advisory_findings_in_changed_scope", "message" => "#{scoped.length} findings in changed scope are advisory and do not block." }
                     end
          reasons << { "code" => "changed_scope", "message" => "Evaluated #{scoped.length} findings in changed scope (#{findings.length} total)." }
          reasons << { "code" => "optional_evidence_unavailable", "message" => "Optional analyzer evidence was unavailable and was retained as an operational failure." } unless optional_failures.empty?
          blocking_map = Set.new(scoped.map(&:fingerprint))
          summaries_scoped = findings.sort_by(&:sort_key).map do |finding|
            blocking = false
            { "id" => finding.id, "fingerprint" => finding.fingerprint, "severity" => finding.severity, "state" => finding.state, "blocking" => blocking }
          end
          return GateResult.new(
            completion_status: "complete",
            gate: gate,
            policy_status: policy_status,
            findings: summaries_scoped,
            analyzer_results: analyzer_results,
            operational_failures: optional_failures,
            decision_reasons: reasons
          )
        end

        if mode == "advisory"
          gate = findings.empty? ? "PASS" : "WARN"
          policy_status = gate.downcase
          reasons = []
          reasons << if findings.empty?
                       { "code" => "no_findings_detected", "message" => "All enabled analyzer evidence contains no findings." }
                     else
                       { "code" => "advisory_findings_present", "message" => "#{findings.length} findings are advisory and do not block." }
                     end
          reasons << { "code" => "optional_evidence_unavailable", "message" => "Optional analyzer evidence was unavailable and was retained as an operational failure." } unless optional_failures.empty?
          return GateResult.new(
            completion_status: "complete",
            gate: gate,
            policy_status: policy_status,
            findings: summaries(findings, blocking: false),
            analyzer_results: analyzer_results,
            operational_failures: optional_failures,
            decision_reasons: reasons
          )
        end

        if mode == "no_new_debt" && comparison
          counts = comparison.fetch("counts") rescue comparison["counts"] if comparison.is_a?(Hash)
          counts ||= {}
          waived_fps = Set.new((comparison.is_a?(Hash) ? (comparison["waived"] || []) : []))
          introduced_fps = Set.new((comparison.is_a?(Hash) ? (comparison["introduced"] || []) : []))
          changed_fps = Set.new((comparison.is_a?(Hash) ? (comparison["changed"] || []) : []))
          moved_fps = Set.new((comparison.is_a?(Hash) ? (comparison["moved"] || []) : []))
          regression_fps = introduced_fps | changed_fps | moved_fps
          if git_context
            regression_findings = changed_findings.select { |finding| regression_fps.include?(finding.fingerprint) && !waived_fps.include?(finding.fingerprint) }
            existing_count = counts["existing"] || 0
            gate = regression_findings.empty? ? "PASS" : "FAIL"
            policy_status = gate.downcase
            reasons = []
            reasons << { "code" => "existing_debt_retained", "message" => "#{existing_count} existing findings retained from baseline." } if existing_count > 0
            reasons << { "code" => "changed_scope", "message" => "Evaluated #{changed_findings.length} findings in changed scope (#{findings.length} total)." }
            reasons << if regression_findings.empty?
                         if findings.empty?
                           { "code" => "no_findings_detected", "message" => "All enabled analyzer evidence contains no findings." }
                         elsif changed_findings.empty?
                           { "code" => "no_new_debt_pass_changed_scope", "message" => "No introduced regressions in changed scope." }
                         else
                           { "code" => "no_new_debt_pass", "message" => "No introduced regressions detected." }
                         end
                       else
                         { "code" => "introduced_findings_blocking", "message" => "#{regression_findings.length} introduced findings in changed scope violate no_new_debt policy." }
                       end
            reasons << { "code" => "optional_evidence_unavailable", "message" => "Optional analyzer evidence was unavailable and was retained as an operational failure." } unless optional_failures.empty?
            summaries_with_state = findings.sort_by(&:sort_key).map do |finding|
              in_scope = changed_findings.any? { |scope_finding| scope_finding.fingerprint == finding.fingerprint }
              blocking = in_scope && regression_fps.include?(finding.fingerprint) && !waived_fps.include?(finding.fingerprint)
              blocking = false if finding.state == "existing"
              blocking = false if finding.state == "waived"
              { "id" => finding.id, "fingerprint" => finding.fingerprint, "severity" => finding.severity, "state" => finding.state, "blocking" => blocking }
            end
            return GateResult.new(
              completion_status: "complete",
              gate: gate,
              policy_status: policy_status,
              findings: summaries_with_state,
              analyzer_results: analyzer_results,
              operational_failures: optional_failures,
              decision_reasons: reasons
            )
          end
          blocking_findings = findings.select { |finding| regression_fps.include?(finding.fingerprint) && !waived_fps.include?(finding.fingerprint) }
          existing_count = counts["existing"] || 0
          gate = blocking_findings.empty? ? "PASS" : "FAIL"
          policy_status = gate.downcase
          reasons = []
          reasons << { "code" => "existing_debt_retained", "message" => "#{existing_count} existing findings retained from baseline." } if existing_count > 0
          reasons << if blocking_findings.empty?
                       if findings.empty?
                         { "code" => "no_findings_detected", "message" => "All enabled analyzer evidence contains no findings." }
                       else
                         { "code" => "no_new_debt_pass", "message" => "No introduced regressions detected." }
                       end
                     else
                       { "code" => "introduced_findings_blocking", "message" => "#{blocking_findings.length} introduced findings violate no_new_debt policy." }
                     end
          reasons << { "code" => "optional_evidence_unavailable", "message" => "Optional analyzer evidence was unavailable and was retained as an operational failure." } unless optional_failures.empty?
          summaries_with_state = findings.sort_by(&:sort_key).map do |finding|
            blocking = regression_fps.include?(finding.fingerprint) && !waived_fps.include?(finding.fingerprint)
            blocking = false if finding.state == "existing"
            blocking = false if finding.state == "waived"
            { "id" => finding.id, "fingerprint" => finding.fingerprint, "severity" => finding.severity, "state" => finding.state, "blocking" => blocking }
          end
          return GateResult.new(
            completion_status: "complete",
            gate: gate,
            policy_status: policy_status,
            findings: summaries_with_state,
            analyzer_results: analyzer_results,
            operational_failures: optional_failures,
            decision_reasons: reasons
          )
        end

        if git_context
          scoped = changed_findings
          gate = scoped.empty? ? "PASS" : "FAIL"
          policy_status = gate.downcase
          reasons = []
          reasons << { "code" => "changed_scope", "message" => "Evaluated #{scoped.length} findings in changed scope (#{findings.length} total)." }
          reasons << if scoped.empty?
                       if findings.empty?
                         { "code" => "no_findings_detected", "message" => "All enabled analyzer evidence contains no findings." }
                       else
                         { "code" => "no_findings_in_changed_scope", "message" => "No findings in changed scope." }
                       end
                     else
                       { "code" => "blocking_findings_in_changed_scope", "message" => "#{scoped.length} findings in changed scope require policy FAIL." }
                     end
          reasons << { "code" => "optional_evidence_unavailable", "message" => "Optional analyzer evidence was unavailable and was retained as an operational failure." } unless optional_failures.empty?
          scoped_fps = Set.new(scoped.map(&:fingerprint))
          summaries_scoped = findings.sort_by(&:sort_key).map do |finding|
            blocking = scoped_fps.include?(finding.fingerprint)
            { "id" => finding.id, "fingerprint" => finding.fingerprint, "severity" => finding.severity, "state" => finding.state, "blocking" => blocking }
          end
          return GateResult.new(
            completion_status: "complete",
            gate: gate,
            policy_status: policy_status,
            findings: summaries_scoped,
            analyzer_results: analyzer_results,
            operational_failures: optional_failures,
            decision_reasons: reasons
          )
        end

        strict = true
        blocking = true
        gate = findings.empty? ? "PASS" : "FAIL"
        policy_status = gate.downcase
        reasons = []
        reasons << if findings.empty?
                     { "code" => "no_findings_detected", "message" => "All enabled analyzer evidence contains no findings." }
                   else
                     { "code" => "blocking_findings_present", "message" => "#{findings.length} findings require policy FAIL." }
                   end
        reasons << { "code" => "optional_evidence_unavailable", "message" => "Optional analyzer evidence was unavailable and was retained as an operational failure." } unless optional_failures.empty?

        GateResult.new(
          completion_status: "complete",
          gate: gate,
          policy_status: policy_status,
          findings: summaries(findings, blocking: blocking),
          analyzer_results: analyzer_results,
          operational_failures: optional_failures,
          decision_reasons: reasons
        )
      end

      def incomplete_result(operational_failures:, analyzer_results: [], findings: [], code: "required_evidence_incomplete", message: "Required evidence is incomplete; policy was not evaluated.")
        GateResult.new(
          completion_status: "incomplete",
          gate: "INCOMPLETE",
          policy_status: "not_evaluated",
          findings: summaries(findings, blocking: false),
          analyzer_results: analyzer_results,
          operational_failures: operational_failures,
          decision_reasons: [{ "code" => code, "message" => message }]
        )
      end

      def interrupted_result(analyzer_results: [], findings: [])
        incomplete_result(
          analyzer_results: analyzer_results,
          findings: findings,
          operational_failures: [{ "code" => "interrupted", "message" => "Execution was interrupted after child-process cleanup." }],
          code: "interrupted",
          message: "Execution was interrupted; no trustworthy gate was produced."
        )
      end

      def summaries(findings, blocking:)
        findings.sort_by(&:sort_key).map do |finding|
          {
            "id" => finding.id,
            "fingerprint" => finding.fingerprint,
            "severity" => finding.severity,
            "state" => finding.state,
            "blocking" => blocking
          }
        end
      end
      private_class_method :summaries

      def incomplete_evidence_failure(analyzer, result)
        summary = result.evidence_summary
        return nil unless summary

        if %w[minitest rspec].include?(analyzer)
          total = summary["tests_total"]
          if total.is_a?(Integer) && total == 0
            return { "code" => "incomplete_evidence", "analyzer" => analyzer, "message" => "#{analyzer} reported zero tests" }
          end
        end

        if analyzer == "simplecov"
          fresh = summary["stale"]
          if fresh == true || fresh == "true"
            return { "code" => "incomplete_evidence", "analyzer" => analyzer, "message" => "SimpleCov coverage is stale" }
          end
        end

        nil
      end
      private_class_method :incomplete_evidence_failure

      def filter_to_changed_scope(findings, git_context)
        changed_paths = Set.new(git_context.changed_files.map { |file| file.path }.compact)
        changed_line_set = git_context.changed_line_set

        findings.select do |finding|
          path = finding.location.fetch("path")
          next false unless changed_paths.include?(path)

          lines = changed_line_set[path]
          next true if lines.nil? || lines.empty?

          line = finding.location["start_line"]
          next true if line.nil?

          lines.include?(line.to_i)
        end
      end
      private_class_method :filter_to_changed_scope
    end
  end
end
