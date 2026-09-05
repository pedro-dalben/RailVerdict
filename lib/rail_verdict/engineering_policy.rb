# frozen_string_literal: true

require "digest"

module RailVerdict
  # Canonical engineering-policy evaluator (1.7, ADR 0020).
  #
  # Turns 1.6 change facts into deterministic engineering requirements without
  # touching GateResult: the decided gate is read, never rewritten. Consumers
  # (CLI `policy`, MCP `get_engineering_policy`) share this single service.
  module EngineeringPolicy
    SCHEMA_VERSION = "1.0"
    RISK_ORDER = %w[low medium high critical].freeze
    NEW_FINDING_STATES = %w[introduced changed moved].freeze
    DELTA_MODES = %w[no_new_debt strict].freeze
    MAX_EVIDENCE = 20

    module_function

    def evaluate(outcome:, pr_document: nil, receipt: nil, handoff: nil)
      result = outcome.result
      configuration = outcome.configuration
      raise RailVerdict::Error, "policy evaluation requires a readable configuration file" if configuration.nil?
      document = pr_document || PRIntelligence.document(outcome)
      policy = effective_policy(configuration)

      requirements = plan(configuration: configuration, result: result, document: document, policy: policy)
      requirements = requirements.sort_by { |entry| entry["id"] }

      decision, codes = decide(result: result, requirements: requirements)
      reason_codes = (codes + requirements.flat_map { |entry| entry["reason_codes"] }).uniq.sort

      envelope = {
        "schema_version" => SCHEMA_VERSION,
        "decision" => decision,
        "gate" => result.gate,
        "completion_status" => result.completion_status,
        "configuration_digest" => configuration.digest,
        "policy_digest" => policy_digest(policy),
        "requirements" => requirements,
        "reason_codes" => reason_codes
      }
      drift = drift_status(receipt: receipt, handoff: handoff, configuration: configuration)
      envelope["drift"] = drift unless drift.nil?

      errors = SchemaValidator.validate_engineering_policy(envelope)
      raise RailVerdict::Error, "engineering-policy-v1 validation failed: #{errors.join('; ')}" unless errors.empty?

      envelope
    end

    def effective_policy(configuration)
      raw = configuration.raw_policy
      raw.is_a?(Hash) ? raw : {}
    end

    def policy_digest(policy)
      Digest::SHA256.hexdigest(CanonicalJSON.generate(policy))
    end

    def drift_status(receipt:, handoff:, configuration:)
      document = handoff.is_a?(Hash) ? handoff["receipt"] : receipt
      return nil if document.nil?
      return { "status" => "unavailable", "code" => "receipt_digest_unavailable" } unless document.is_a?(Hash)

      bound = dig_digest(document)
      return { "status" => "unavailable", "code" => "receipt_digest_unavailable" } if bound.nil?

      if bound == configuration.digest
        { "status" => "fresh", "code" => "policy_matches_receipt" }
      else
        { "status" => "policy_drift", "code" => "policy_or_config_changed_since_receipt" }
      end
    end

    # --- planner ----------------------------------------------------------

    def plan(configuration:, result:, document:, policy:)
      requirements = []
      requirements.concat(plan_new_findings(result: result, policy: policy))
      requirements.concat(plan_coverage(document: document, policy: policy))
      requirements.concat(plan_changes(configuration: configuration, result: result, document: document, policy: policy))
      requirements.concat(plan_baseline(result: result, configuration: configuration))
      requirements.concat(plan_review(configuration: configuration, document: document, policy: policy))
      requirements
    end

    def plan_new_findings(result:, policy:)
      findings_rule = policy["findings"]
      return [] unless findings_rule.is_a?(Hash)

      delta = result.comparison.is_a?(Hash) ? result.comparison : nil
      baseline = result.baseline.is_a?(Hash) ? result.baseline : {}
      delta_available = !delta.nil? && baseline["loaded"] == true
      fresh = NEW_FINDING_STATES.flat_map do |state|
        result.findings.select { |finding| finding["state"] == state }
      end

      %w[critical high].map do |severity|
        key = "new_#{severity}"
        next not_applicable("req-new-findings-#{severity}", "new_findings", "policy does not forbid new #{severity} findings") unless findings_rule[key] == "forbid"

        trigger = "policy forbids new #{severity} findings"
        required = ["complete quality delta", "introduced/changed/moved findings with severity"]
        if !delta_available
          unavailable("req-new-findings-#{severity}", "new_findings", trigger, required,
            ["quality delta unavailable: #{delta_reason(baseline)}"],
            ["new_findings_unavailable"], "provide a compatible baseline and re-verify")
        else
          hits = fresh.select { |finding| finding["severity"] == severity }
            .sort_by { |finding| finding["fingerprint"].to_s }.first(MAX_EVIDENCE)
          observed = hits.map { |finding| "#{finding['id']} (#{finding['state']})" }
          if hits.empty?
            satisfied("req-new-findings-#{severity}", "new_findings", trigger, required,
              ["no new #{severity} findings in delta (introduced #{delta.fetch('counts', {}).fetch('introduced', 0)})"],
              ["no_new_#{severity}_findings"])
          else
            violated("req-new-findings-#{severity}", "new_findings", trigger, required, observed,
              ["new_#{severity}_findings_forbidden"], nil)
          end
        end
      end.compact
    end

    def plan_coverage(document:, policy:)
      coverage_rule = policy["coverage"]
      return [] unless coverage_rule.is_a?(Hash) && !coverage_rule["changed_lines_minimum"].nil?

      minimum = coverage_rule["changed_lines_minimum"]
      trigger = "policy requires changed-lines coverage >= #{minimum}%"
      required = ["fresh SimpleCov evidence with changed-line coverage"]
      coverage = document["coverage"]
      percent = coverage.is_a?(Hash) ? coverage["changed_lines_percent"] : nil
      unless percent.is_a?(Numeric)
        reason = coverage.is_a?(Hash) ? (coverage["reason"] || "changed_lines_unavailable") : "coverage_unavailable"
        return [unavailable("req-coverage-changed-lines", "changed_lines_coverage", trigger, required,
          ["coverage evidence: #{reason}"], ["changed_coverage_unavailable"],
          "generate fresh coverage evidence and re-verify")]
      end
      observed = ["changed-lines coverage #{percent}% (minimum #{minimum}%)"]
      if percent >= minimum
        [satisfied("req-coverage-changed-lines", "changed_lines_coverage", trigger, required, observed, ["changed_coverage_sufficient"])]
      else
        [violated("req-coverage-changed-lines", "changed_lines_coverage", trigger, required, observed,
          ["changed_coverage_below_minimum"], nil)]
      end
    end

    def plan_changes(configuration:, result:, document:, policy:)
      changes = policy["changes"]
      return [] unless changes.is_a?(Hash)

      surfaces = document["surfaces"].is_a?(Hash) ? document["surfaces"] : {}
      areas = document["project_sensitive_areas"].is_a?(Array) ? document["project_sensitive_areas"] : []
      scope = document["verification_scope"].is_a?(Hash) ? document["verification_scope"] : {}
      evidence_index = analyzer_evidence_index(result)

      changes.keys.sort.each do |key|
        next if ChangeSurfaces::SURFACES.key?(key) || area_named?(configuration, key)
        raise ConfigurationError.new(
          "engineering_policy.changes key #{key.inspect} is not a known change surface or project area",
          source_path: configuration.source_path, property_path: "engineering_policy.changes"
        )
      end

      changes.keys.sort.flat_map do |key|
        rule = changes[key]
        surface_changed = surfaces.dig(key, "changed") == true
        area_changed = areas.any? { |area| area["name"] == key && area["changed"] == true }
        unless surface_changed || area_changed
          next [not_applicable("req-changes-#{slug(key)}", "required_analyzer",
            "surface #{key.inspect} unchanged; analyzer rule not triggered")]
        end
        plan_surface_rule(key: key, rule: rule, scope: scope, evidence_index: evidence_index, configuration: configuration)
      end
    end

    def plan_surface_rule(key:, rule:, scope:, evidence_index:, configuration:)
      requirements = []
      Array(rule["require_analyzers"]).each do |analyzer|
        id = "req-analyzer-#{analyzer}-for-#{slug(key)}"
        trigger = "surface #{key.inspect} changed; policy requires analyzer #{analyzer.inspect}"
        required = ["#{analyzer} executed with complete evidence"]
        selection = configuration.analyzers[analyzer]
        if selection.nil? || selection.fetch("enabled") != true
          requirements << unavailable(id, "required_analyzer", trigger, required,
            ["analyzer #{analyzer} not enabled in configuration"],
            ["rule_conflicts_configuration"], "enable analyzer #{analyzer} and re-verify")
          next
        end
        entry = evidence_index[analyzer]
        if entry.nil? || entry["evidence_status"] != "complete"
          requirements << unavailable(id, "required_analyzer", trigger, required,
            ["analyzer #{analyzer}: #{entry.nil? ? 'no result produced' : entry['evidence_status']}"],
            ["required_analyzer_incomplete"], "execute required analyzer #{analyzer} and re-verify")
        else
          requirements << satisfied(id, "required_analyzer", trigger, required,
            ["analyzer #{analyzer} executed (#{entry['execution_status']})"], ["required_analyzer_executed"])
        end
      end
      if rule["verification_scope"] == "full"
        requirements << plan_full_scope(key: key, scope: scope)
      end
      requirements
    end

    def plan_full_scope(key:, scope:)
      id = "req-full-scope-#{slug(key)}"
      trigger = "surface #{key.inspect} changed; policy requires FULL verification"
      required = ["executed FULL test scope (rspec/minitest)"]
      frameworks = scope["frameworks"].is_a?(Hash) ? scope["frameworks"] : {}
      executed = frameworks.select { |_, entry| entry.is_a?(Hash) && entry["executed"] == true }
      if executed.empty?
        return unavailable(id, "full_verification_scope", trigger, required,
          ["no test framework executed: #{scope['reason'] || 'test_scope_unavailable'}"],
          ["full_scope_unavailable"], "execute FULL verification and re-verify")
      end
      targeted = executed.select { |_, entry| entry["scope"] != "full" }
      if targeted.empty?
        satisfied(id, "full_verification_scope", trigger, required,
          executed.map { |name, _| "#{name} executed FULL" }.sort, ["full_scope_executed"])
      else
        unavailable(id, "full_verification_scope", trigger, required,
          targeted.map { |name, entry| "#{name} executed #{entry['scope']}" }.sort,
          ["targeted_not_sufficient"], "re-run FULL verification and re-verify")
      end
    end

    def plan_baseline(result:, configuration:)
      return [] unless DELTA_MODES.include?(configuration.mode)

      trigger = "mode #{configuration.mode.inspect} depends on baseline delta"
      required = ["loaded, compatible baseline with quality delta"]
      baseline = result.baseline.is_a?(Hash) ? result.baseline : {}
      comparison = result.comparison.is_a?(Hash) ? result.comparison : nil
      if baseline["loaded"] == true && baseline["compatible"] != false && !comparison.nil?
        [satisfied("req-baseline-compatible", "baseline_compatible", trigger, required,
          ["baseline loaded, comparison available"], ["baseline_compatible"])]
      else
        [unavailable("req-baseline-compatible", "baseline_compatible", trigger, required,
          ["baseline: #{baseline_reason(baseline)}"], ["baseline_incompatible_or_missing"],
          "provide a compatible baseline and re-verify")]
      end
    end

    def plan_review(configuration:, document:, policy:)
      review_rules = policy["review"]
      return [] unless review_rules.is_a?(Hash)

      risk = document["review_risk"].is_a?(Hash) ? document["review_risk"] : {}
      level = risk["level"].to_s.downcase
      surfaces = document["surfaces"].is_a?(Hash) ? document["surfaces"] : {}
      areas = document["project_sensitive_areas"].is_a?(Array) ? document["project_sensitive_areas"] : []
      any_change = surfaces.any? { |_, entry| entry["changed"] == true } ||
        areas.any? { |area| area["changed"] == true }

      review_rules.keys.sort.filter_map do |key|
        rule = review_rules[key]
        next unless rule.is_a?(Hash) && rule["human_review"] == "required"

        triggered = if RISK_ORDER.include?(key.downcase)
                      any_change && RISK_ORDER.index(level) && RISK_ORDER.index(level) >= RISK_ORDER.index(key.downcase)
                    elsif ChangeSurfaces::SURFACES.key?(key)
                      surfaces.dig(key, "changed") == true
                    elsif area_named?(configuration, key)
                      areas.any? { |area| area["name"] == key && area["changed"] == true }
                    else
                      raise ConfigurationError.new(
                        "engineering_policy.review key #{key.inspect} is not a risk level, change surface, or project area",
                        source_path: configuration.source_path, property_path: "engineering_policy.review"
                      )
                    end
        id = "req-human-review-#{slug(key)}"
        if triggered
          { "id" => id, "kind" => "human_review",
            "trigger" => "policy requires human review for #{key.inspect} (risk #{level.upcase})",
            "status" => "review_required",
            "required_evidence" => ["human review presence bound to verified state"],
            "observed_evidence" => ["no machine-verifiable approval proof exists in 1.7"],
            "recovery_action" => nil,
            "reason_codes" => ["human_review_required"],
            "provenance" => "engineering_policy.review.#{key}",
            "classification" => "review" }
        else
          not_applicable(id, "human_review", "review rule for #{key.inspect} not triggered")
        end
      end
    end

    # --- decision ---------------------------------------------------------

    def decide(result:, requirements:)
      by_status = requirements.group_by { |entry| entry["status"] }
      if by_status["violated"]&.any?
        ["FAIL", ["engineering_policy_fail"]]
      elsif by_status["unavailable"]&.any? || result.completion_status != "complete"
        ["INCOMPLETE", ["engineering_policy_incomplete"]]
      elsif by_status["review_required"]&.any?
        ["REVIEW_REQUIRED", ["engineering_policy_review_required"]]
      elsif result.gate == "FAIL"
        ["FAIL", %w[engineering_policy_fail gate_failed]]
      else
        ["PASS", ["engineering_policy_pass"]]
      end
    end

    # --- constructors -----------------------------------------------------

    def satisfied(id, kind, trigger, required, observed, codes)
      requirement(id, kind, trigger, "satisfied", required, observed, nil, codes, "deterministic")
    end

    def violated(id, kind, trigger, required, observed, codes, recovery)
      requirement(id, kind, trigger, "violated", required, observed, recovery, codes, "deterministic")
    end

    def unavailable(id, kind, trigger, required, observed, codes, recovery)
      requirement(id, kind, trigger, "unavailable", required, observed, recovery, codes, "deterministic")
    end

    def not_applicable(id, kind, trigger)
      requirement(id, kind, trigger, "not_applicable", [], [], nil, ["rule_not_triggered"], "deterministic")
    end

    def requirement(id, kind, trigger, status, required, observed, recovery, codes, classification)
      entry = {
        "id" => id, "kind" => kind, "trigger" => trigger, "status" => status,
        "required_evidence" => Array(required).sort,
        "observed_evidence" => Array(observed).first(MAX_EVIDENCE),
        "reason_codes" => Array(codes).sort,
        "provenance" => "engineering_policy.#{kind}",
        "classification" => classification
      }
      entry["recovery_action"] = recovery unless recovery.nil?
      entry
    end

    # --- helpers ----------------------------------------------------------

    def analyzer_evidence_index(result)
      result.analyzer_results.each_with_object({}) do |analyzer, index|
        index[analyzer.analyzer] = {
          "execution_status" => analyzer.execution_status,
          "evidence_status" => analyzer.evidence_status
        }
      end
    end

    def area_named?(configuration, key)
      areas = configuration.review_config["sensitive_paths"]
      areas.is_a?(Hash) && areas.key?(key)
    end

    def slug(key)
      key.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end

    def delta_reason(baseline)
      return "baseline_not_available" if baseline.empty?
      return "baseline_incompatible" if baseline["compatible"] == false
      return "baseline_not_loaded" unless baseline["loaded"] == true

      "comparison_unavailable"
    end

    def baseline_reason(baseline)
      return "no baseline configured" if baseline.empty?

      "loaded=#{baseline['loaded'].inspect} compatible=#{baseline['compatible'].inspect}"
    end

    def dig_digest(document)
      candidates = [
        document.dig("repository_state", "configuration_digest"),
        document.dig("provenance", "configuration_digest")
      ]
      candidates.each do |digest|
        next unless digest.is_a?(String)
        bare = digest.sub(/\Asha256:/, "")
        return bare if bare.match?(/\A[0-9a-f]{64}\z/)
      end
      nil
    end
  end
end
