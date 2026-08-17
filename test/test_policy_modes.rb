# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "fileutils"

class TestPolicyModes < Minitest::Test
  def configuration_for(mode, version: 1.2)
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.write(path, "version: #{version}\nmode: #{mode}\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      config = RailVerdict::Configuration.load(path)
      return config
    end
  end

  def analyzer_result(analyzer: "rubocop")
    RailVerdict::AnalyzerResult.new(
      analyzer: analyzer,
      invocation: { "executable" => analyzer, "argv" => [] },
      execution_status: "succeeded",
      finding_ids: []
    )
  end

  def finding(path: "app/a.rb", message: "msg", rule_id: "Style/Foo", state: "observed")
    fingerprint = RailVerdict::Finding.fingerprint_for(analyzer: "rubocop", rule_id: rule_id, path: path, message: message)
    RailVerdict::Finding.new(
      fingerprint: fingerprint,
      origin: "deterministic",
      analyzer: "rubocop",
      rule_id: rule_id,
      category: "style",
      severity: "low",
      confidence: "high",
      state: state,
      evidence_ref: "native:rubocop:#{fingerprint.delete_prefix('sha256:')[0, 12]}",
      location: { "path" => path, "start_line" => 1, "end_line" => 1 },
      message: message
    )
  end

  def baseline_for(findings)
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.write(path, "version: 1.2\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      config = RailVerdict::Configuration.load(path)
      RailVerdict::Baseline.create(findings: findings, configuration: config, analyzer_versions: { "rubocop" => "1.89.0" }, clock: Time.utc(2026, 8, 17, 12, 0, 0))
    end
  end

  def test_advisory_all_non_blocking
    config = configuration_for("advisory")
    findings = [finding(path: "app/a.rb", message: "one"), finding(path: "app/b.rb", message: "two")]
    result = RailVerdict::Verification::Policy.evaluate(configuration: config, analyzer_results: [analyzer_result], findings: findings)
    assert_equal "WARN", result.gate
    assert result.findings.all? { |item| item["blocking"] == false }
  end

  def test_no_new_debt_existing_non_blocking_introduced_blocking
    findings_existing = [finding(path: "app/a.rb", message: "keep", state: "existing"), finding(path: "app/b.rb", message: "keep2", state: "existing")]
    baseline = baseline_for(findings_existing)
    current = [finding(path: "app/a.rb", message: "keep", state: "existing"), finding(path: "app/b.rb", message: "keep2", state: "existing"), finding(path: "app/c.rb", message: "new", state: "introduced")]
    cmp = RailVerdict::Comparison.classify(findings: current, baseline: baseline)
    comparison = { "counts" => cmp.counts, "introduced" => cmp.introduced.map(&:fingerprint), "existing" => cmp.existing.map(&:fingerprint), "resolved" => cmp.resolved.map { |entry| entry.fetch("fingerprint") }, "changed" => cmp.changed.map(&:fingerprint), "moved" => cmp.moved.map(&:fingerprint), "waived" => [] }
    config = configuration_for("no_new_debt")
    result = RailVerdict::Verification::Policy.evaluate(configuration: config, analyzer_results: [analyzer_result], findings: cmp.classified_findings, comparison: comparison)
    assert_equal "FAIL", result.gate
    assert result.findings.any? { |item| item["state"] == "introduced" && item["blocking"] == true }
    assert result.findings.any? { |item| item["state"] == "existing" && item["blocking"] == false }
  end

  def test_no_new_debt_only_existing_passes
    findings = [finding(path: "app/a.rb", message: "keep")]
    baseline = baseline_for(findings)
    cmp = RailVerdict::Comparison.classify(findings: findings, baseline: baseline)
    comparison = { "counts" => cmp.counts, "introduced" => [], "existing" => cmp.existing.map(&:fingerprint), "resolved" => [], "changed" => [], "moved" => [], "waived" => [] }
    config = configuration_for("no_new_debt")
    result = RailVerdict::Verification::Policy.evaluate(configuration: config, analyzer_results: [analyzer_result], findings: cmp.classified_findings, comparison: comparison)
    assert_equal "PASS", result.gate
  end

  def test_strict_fails_on_any_finding_regardless_of_baseline
    config = configuration_for("strict")
    findings = [finding(path: "app/a.rb", message: "one", state: "existing")]
    result = RailVerdict::Verification::Policy.evaluate(configuration: config, analyzer_results: [analyzer_result], findings: findings, comparison: { "counts" => { "existing" => 1 }, "introduced" => [], "existing" => findings.map(&:fingerprint), "resolved" => [], "changed" => [], "moved" => [], "waived" => [] })
    assert_equal "FAIL", result.gate
    assert result.findings.all? { |item| item["blocking"] == true }
  end

  def test_incomplete_always_wins_over_baseline
    config = configuration_for("no_new_debt")
    incomplete_result = RailVerdict::AnalyzerResult.new(
      analyzer: "rubocop",
      invocation: { "executable" => "rubocop", "argv" => [] },
      execution_status: "unavailable",
      finding_ids: [],
      failure: { "code" => "unavailable", "message" => "missing" }
    )
    findings = [finding(path: "app/a.rb", message: "one")]
    baseline = baseline_for(findings)
    cmp = RailVerdict::Comparison.classify(findings: findings, baseline: baseline)
    comparison = { "counts" => cmp.counts, "introduced" => [], "existing" => cmp.existing.map(&:fingerprint), "resolved" => [], "changed" => [], "moved" => [], "waived" => [] }
    result = RailVerdict::Verification::Policy.evaluate(configuration: config, analyzer_results: [incomplete_result], findings: findings, comparison: comparison)
    assert_equal "INCOMPLETE", result.gate
    assert_equal "not_evaluated", result.policy_status
  end

  def test_policy_is_deterministic_across_shuffled_order
    config = configuration_for("no_new_debt")
    findings = [finding(path: "app/c.rb", message: "c"), finding(path: "app/a.rb", message: "a")]
    result1 = RailVerdict::Verification::Policy.evaluate(configuration: config, analyzer_results: [analyzer_result], findings: findings.shuffle)
    result2 = RailVerdict::Verification::Policy.evaluate(configuration: config, analyzer_results: [analyzer_result], findings: findings.shuffle)
    assert_equal result1.findings.map { |item| item["fingerprint"] }, result2.findings.map { |item| item["fingerprint"] }
  end
end
