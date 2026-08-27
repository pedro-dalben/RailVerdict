# frozen_string_literal: true

require_relative "canonical_json"
require_relative "receipt"
require_relative "handoff"
require_relative "repository_state"
require_relative "verification_environment"
require_relative "verification_identity"

module RailVerdict
  module Reuse
    Result = Struct.new(:decision, :reasons, :handoff_valid, :receipt_fresh, keyword_init: true)
    AnalyzerReuseResult = Struct.new(:decision, :reasons, :analyzer_result, :findings, keyword_init: true)

    REUSABLE = "REUSABLE"
    VERIFICATION_REQUIRED = "VERIFICATION_REQUIRED"
    INVALID = "INVALID"
    UNAVAILABLE = "UNAVAILABLE"

    # One canonical evaluator — CLI/MCP/CI/Repair must delegate here.
    def self.evaluate(handoff_document:, current_repository_state:, current_environment:, current_contract: {})
      # 1. Validate handoff structurally
      unless handoff_document.is_a?(Hash) && handoff_document["handoff_id"]
        return Result.new(decision: INVALID, reasons: ["handoff_invalid"], handoff_valid: false, receipt_fresh: false)
      end
      stored = handoff_document["handoff_id"]
      payload = handoff_document.reject { |k, _| k == "handoff_id" }
      expected = Handoff.id_for(payload)
      unless stored == expected
        return Result.new(decision: INVALID, reasons: ["handoff_tampered"], handoff_valid: false, receipt_fresh: false)
      end
      errors = SchemaValidator.validate_handoff(handoff_document)
      unless errors.empty?
        return Result.new(decision: INVALID, reasons: ["handoff_invalid"], handoff_valid: false, receipt_fresh: false)
      end

      # Size bound already enforced in Handoff.build/parse, but check
      if JSON.generate(handoff_document).bytesize > Handoff::MAX_DOCUMENT_BYTES
        return Result.new(decision: INVALID, reasons: ["handoff_too_large"], handoff_valid: false, receipt_fresh: false)
      end

      receipt = handoff_document["receipt"]
      unless receipt && receipt["receipt_id"]
        return Result.new(decision: INVALID, reasons: ["handoff_invalid"], handoff_valid: false, receipt_fresh: false)
      end

      # 2. TOCTOU guard: observe identity_before, then evaluate, then re-observe is caller's responsibility
      # Here we check provided current state/env vs receipt binding
      # Freshness via Receipt.validate_freshness equivalent — compare repository_state + environment digests
      freshness = evaluate_freshness(receipt, current_repository_state, current_environment)
      unless freshness[:fresh]
        return Result.new(decision: VERIFICATION_REQUIRED, reasons: freshness[:reasons], handoff_valid: true, receipt_fresh: false)
      end

      # 3. Completeness / required evidence
      required = Array(current_contract["required_analyzers"] || current_contract[:required_analyzers]).map(&:to_s)
      evidence_analyzers = Array(handoff_document.dig("evidence_set", "analyzer_results")).map { |ar| ar["analyzer"].to_s }

      missing = required - evidence_analyzers
      unless missing.empty?
        return Result.new(decision: VERIFICATION_REQUIRED, reasons: ["required_analyzer_missing:#{missing.join(',')}"], handoff_valid: true, receipt_fresh: true)
      end

      # 4. Incomplete evidence cannot be reused as complete
      handoff_document.dig("evidence_set", "analyzer_results")&.each do |ar|
        if !%w[succeeded success].include?(ar["execution_status"])
          return Result.new(decision: VERIFICATION_REQUIRED, reasons: ["evidence_incomplete:#{ar['analyzer']}"], handoff_valid: true, receipt_fresh: true)
        end
      end

      # 5. Per-analyzer predicates (whole-set: all must be reusable)
      # RuboCop: reusable if analyzer_versions match current environment for rubocop
      # RSpec/Minitest/SimpleCov: never reusable (fail-closed) — forces VERIFICATION_REQUIRED
      # bundler-audit: requires advisory DB equivalence — unobservable → VERIFICATION_REQUIRED
      non_reusable = []
      required.each do |analyzer|
        case analyzer
        when "rspec", "minitest", "simplecov"
          non_reusable << "analyzer_not_reusable:#{analyzer}"
        when "bundler_audit", "bundler-audit"
          # If advisory DB revision not observable or not proven equal, fail-closed
          prov = handoff_document["evidence_provenance"]
          current_db = current_contract["advisory_db_revision"] || current_contract[:advisory_db_revision]
          handoff_db = prov && (prov["advisory_db_revision"] || prov[:advisory_db_revision])
          if handoff_db.nil? || current_db.nil? || handoff_db.to_s != current_db.to_s
            non_reusable << "advisory_database_changed"
          end
        when "rubocop"
          # Check analyzer version equality
          receipt_versions = receipt.dig("environment", "analyzer_versions") || {}
          current_versions = current_environment.is_a?(Hash) ? (current_environment["analyzer_versions"] || current_environment[:analyzer_versions] || {}) : {}
          # Also check handoff provenance
          if receipt_versions["rubocop"].to_s != current_versions["rubocop"].to_s && !current_versions["rubocop"].nil?
            non_reusable << "analyzer_version_changed:rubocop"
          end
        end
      end

      unless non_reusable.empty?
        return Result.new(decision: VERIFICATION_REQUIRED, reasons: non_reusable.uniq, handoff_valid: true, receipt_fresh: true)
      end

      # Scope / policy checks (current_contract may include base, mode)
      if current_contract["verification_mode"] || current_contract[:verification_mode]
        handoff_mode = handoff_document["source_scope"] && handoff_document["source_scope"]["verification_mode"]
        current_mode = (current_contract["verification_mode"] || current_contract[:verification_mode]).to_s
        if handoff_mode && handoff_mode != current_mode
          return Result.new(decision: VERIFICATION_REQUIRED, reasons: ["scope_changed"], handoff_valid: true, receipt_fresh: true)
        end
      end
      if current_contract["changed_base"] || current_contract[:changed_base]
        handoff_base = handoff_document.dig("source_scope", "changed_base")
        current_base = (current_contract["changed_base"] || current_contract[:changed_base]).to_s
        if handoff_base && handoff_base != current_base
          return Result.new(decision: VERIFICATION_REQUIRED, reasons: ["base_changed"], handoff_valid: true, receipt_fresh: true)
        end
      end

      Result.new(decision: REUSABLE, reasons: [], handoff_valid: true, receipt_fresh: true)
    end

    def self.evaluate_freshness(receipt, current_state, current_env)
      reasons = []
      # RepositoryState digests
      repo = receipt["repository_state"]
      if repo && current_state
        cs = current_state.is_a?(Hash) ? current_state : (current_state.respond_to?(:components) ? current_state.components : {})
        # components may have symbol keys
        check_keys = %w[head index_digest worktree_digest configuration_digest baseline_digest waivers_digest]
        check_keys.each do |k|
          expected = repo[k]
          actual = cs[k] || cs[k.to_sym]
          if expected && actual && expected != actual
            reasons << "repository_changed:#{k}"
          elsif expected.nil? ^ actual.nil?
            reasons << "repository_changed:#{k}"
          end
        end
      end
      # Environment
      env = receipt["environment"]
      if env && current_env
        ce = current_env.is_a?(Hash) ? current_env : {}
        if env["ruby_engine"] && ce["ruby_engine"] && env["ruby_engine"] != ce["ruby_engine"]
          reasons << "ruby_engine_changed"
        end
        if env["ruby_version"] && ce["ruby_version"] && env["ruby_version"] != ce["ruby_version"]
          reasons << "ruby_version_changed"
        end
        if env["railverdict_version"] && ce["railverdict_version"] && env["railverdict_version"] != ce["railverdict_version"]
          reasons << "railverdict_version_changed"
        end
        # Analyzer versions — any relevant enabled analyzer drift
        receipt_av = env["analyzer_versions"] || {}
        current_av = ce["analyzer_versions"] || ce[:analyzer_versions] || {}
        receipt_av.each do |k, v|
          if current_av[k] && current_av[k] != v
            reasons << "analyzer_environment_changed:#{k}"
          elsif current_av[k].nil? && !v.nil?
            reasons << "analyzer_environment_changed:#{k}"
          end
        end
      end

      { fresh: reasons.empty?, reasons: reasons.empty? ? [] : reasons }
    end
    private_class_method :evaluate_freshness

    def self.evaluate_analyzer(analyzer_id:, handoff_document:, current_repository_state:, current_environment:, configuration: nil, current_contract: {})
      # 1. Structural handoff check
      unless handoff_document.is_a?(Hash) && handoff_document["handoff_id"]
        return AnalyzerReuseResult.new(decision: INVALID, reasons: ["handoff_invalid"])
      end
      stored = handoff_document["handoff_id"]
      payload = handoff_document.reject { |k, _| k == "handoff_id" }
      expected = Handoff.id_for(payload)
      unless stored == expected
        return AnalyzerReuseResult.new(decision: INVALID, reasons: ["handoff_tampered"])
      end
      errors = SchemaValidator.validate_handoff(handoff_document)
      unless errors.empty?
        return AnalyzerReuseResult.new(decision: INVALID, reasons: ["handoff_invalid"])
      end

      receipt = handoff_document["receipt"]
      unless receipt && receipt["receipt_id"]
        return AnalyzerReuseResult.new(decision: INVALID, reasons: ["handoff_invalid"])
      end

      # 2. Freshness check
      freshness = evaluate_freshness(receipt, current_repository_state, current_environment)
      unless freshness[:fresh]
        return AnalyzerReuseResult.new(decision: VERIFICATION_REQUIRED, reasons: freshness[:reasons])
      end

      # 3. Find analyzer result in evidence set
      ar_hash = Array(handoff_document.dig("evidence_set", "analyzer_results")).find { |ar| ar["analyzer"] == analyzer_id.to_s }
      unless ar_hash
        return AnalyzerReuseResult.new(decision: VERIFICATION_REQUIRED, reasons: ["evidence_missing:#{analyzer_id}"])
      end

      unless %w[succeeded success].include?(ar_hash["execution_status"])
        return AnalyzerReuseResult.new(decision: VERIFICATION_REQUIRED, reasons: ["evidence_incomplete:#{analyzer_id}"])
      end

      # 4. Analyzer-specific rules
      case analyzer_id.to_s
      when "rspec", "minitest", "simplecov"
        return AnalyzerReuseResult.new(decision: VERIFICATION_REQUIRED, reasons: ["policy_requires_execution:#{analyzer_id}"])
      when "bundler_audit", "bundler-audit"
        prov = handoff_document["evidence_provenance"]
        current_db = current_contract["advisory_db_revision"] || current_contract[:advisory_db_revision]
        handoff_db = prov && (prov["advisory_db_revision"] || prov[:advisory_db_revision])
        if handoff_db.nil? || current_db.nil? || handoff_db.to_s != current_db.to_s
          return AnalyzerReuseResult.new(decision: VERIFICATION_REQUIRED, reasons: ["advisory_database_changed"])
        end
        receipt_versions = receipt.dig("environment", "analyzer_versions") || {}
        current_versions = current_environment.is_a?(Hash) ? (current_environment["analyzer_versions"] || current_environment[:analyzer_versions] || {}) : {}
        if receipt_versions["bundler_audit"].to_s != current_versions["bundler_audit"].to_s && !current_versions["bundler_audit"].nil?
          return AnalyzerReuseResult.new(decision: VERIFICATION_REQUIRED, reasons: ["analyzer_version_changed:bundler_audit"])
        end
      when "rubocop"
        receipt_versions = receipt.dig("environment", "analyzer_versions") || {}
        current_versions = current_environment.is_a?(Hash) ? (current_environment["analyzer_versions"] || current_environment[:analyzer_versions] || {}) : {}
        if receipt_versions["rubocop"].to_s != current_versions["rubocop"].to_s && !current_versions["rubocop"].nil?
          return AnalyzerReuseResult.new(decision: VERIFICATION_REQUIRED, reasons: ["analyzer_version_changed:rubocop"])
        end
      when "brakeman"
        receipt_versions = receipt.dig("environment", "analyzer_versions") || {}
        current_versions = current_environment.is_a?(Hash) ? (current_environment["analyzer_versions"] || current_environment[:analyzer_versions] || {}) : {}
        if receipt_versions["brakeman"].to_s != current_versions["brakeman"].to_s && !current_versions["brakeman"].nil?
          return AnalyzerReuseResult.new(decision: VERIFICATION_REQUIRED, reasons: ["analyzer_version_changed:brakeman"])
        end
      end

      # 5. Extract AnalyzerResult and Findings
      raw_findings = Array(ar_hash["findings"]) + Array(handoff_document.dig("evidence_set", "findings")).select { |f| f["analyzer"] == analyzer_id.to_s }
      raw_findings = raw_findings.uniq { |f| f["fingerprint"] }

      reused_findings = raw_findings.map do |fh|
        Finding.new(
          fingerprint: fh["fingerprint"],
          origin: fh["origin"] || "deterministic",
          analyzer: fh["analyzer"],
          rule_id: fh["rule_id"],
          category: fh["category"] || "lint",
          severity: fh["severity"] || "medium",
          confidence: fh["confidence"] || "high",
          state: "observed",
          evidence_ref: fh["evidence_ref"] || "reused:#{fh['fingerprint'][0, 12]}",
          location: fh["location"] || { "path" => fh["path"] || "unknown.rb" },
          message: fh["message"] || "reused"
        )
      end

      reused_ar = AnalyzerResult.new(
        analyzer: ar_hash["analyzer"],
        tool_version: ar_hash["tool_version"],
        invocation: ar_hash["invocation"] || { "executable" => ar_hash["analyzer"].to_s, "argv" => ["reused"] },
        execution_status: ar_hash["execution_status"],
        finding_ids: reused_findings.map(&:id),
        evidence_summary: ar_hash["evidence_summary"] || {},
        failure: ar_hash["failure"]
      )

      AnalyzerReuseResult.new(
        decision: REUSABLE,
        reasons: [],
        analyzer_result: reused_ar,
        findings: reused_findings
      )
    end
  end
end
