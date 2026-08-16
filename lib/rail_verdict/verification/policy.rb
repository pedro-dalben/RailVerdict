# frozen_string_literal: true

module RailVerdict
  module Verification
    module Policy
      module_function

      def evaluate(configuration:, analyzer_results:, findings:)
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
        mode = configuration.mode
        strict = mode != "advisory"
        blocking = strict
        gate = if findings.empty?
          "PASS"
        elsif strict
          "FAIL"
        else
          "WARN"
        end
        policy_status = gate.downcase
        reasons = []
        if mode == "no_new_debt"
          reasons << {
            "code" => "no_new_debt_evaluated_as_strict",
            "message" => "no_new_debt is evaluated as strict until Phase 3 baseline comparison exists."
          }
        end
        reasons << if findings.empty?
          { "code" => "no_findings_detected", "message" => "All enabled analyzer evidence contains no findings." }
        elsif strict
          { "code" => "blocking_findings_present", "message" => "#{findings.length} findings require policy FAIL." }
        else
          { "code" => "advisory_findings_present", "message" => "#{findings.length} findings are advisory and do not block." }
        end
        reasons << {
          "code" => "optional_evidence_unavailable",
          "message" => "Optional analyzer evidence was unavailable and was retained as an operational failure."
        } unless optional_failures.empty?

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
    end
  end
end
