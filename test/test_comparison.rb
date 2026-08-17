# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class TestComparison < Minitest::Test
  def finding(path: "app/models/user.rb", message: "msg", rule_id: "Style/StringLiterals", analyzer: "rubocop", severity: "low")
    fingerprint = RailVerdict::Finding.fingerprint_for(analyzer: analyzer, rule_id: rule_id, path: path, message: message)
    RailVerdict::Finding.new(
      fingerprint: fingerprint,
      origin: "deterministic",
      analyzer: analyzer,
      rule_id: rule_id,
      category: "style",
      severity: severity,
      confidence: "high",
      state: "observed",
      evidence_ref: "native:rubocop:#{fingerprint.delete_prefix('sha256:')[0, 12]}",
      location: { "path" => path, "start_line" => 1, "end_line" => 1 },
      message: message
    )
  end

  def baseline_for(findings, dir: nil)
    with_tmpdir do |tmp|
      root = dir || tmp
      path = File.join(root, ".railverdict.yml")
      File.write(path, "version: 1.2\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      config = RailVerdict::Configuration.load(path)
      baseline = RailVerdict::Baseline.create(findings: findings, configuration: config, analyzer_versions: { "rubocop" => "1.89.0" }, clock: Time.utc(2026, 8, 17, 12, 0, 0))
      return baseline
    end
  end

  def test_all_intersection_is_existing
    findings = [finding(path: "app/a.rb", message: "one"), finding(path: "app/b.rb", message: "two")]
    baseline = baseline_for(findings)
    result = RailVerdict::Comparison.classify(findings: findings, baseline: baseline)
    assert_equal 2, result.counts.fetch("existing")
    assert_equal 0, result.counts.fetch("introduced")
    assert_equal 0, result.counts.fetch("resolved")
    assert result.existing.all? { |item| item.state == "existing" }
  end

  def test_two_remain_one_resolved_one_introduced
    original = [finding(path: "app/a.rb", message: "one"), finding(path: "app/b.rb", message: "two"), finding(path: "app/c.rb", message: "three")]
    baseline = baseline_for(original)
    current = [finding(path: "app/a.rb", message: "one"), finding(path: "app/b.rb", message: "two"), finding(path: "app/d.rb", message: "four")]
    result = RailVerdict::Comparison.classify(findings: current, baseline: baseline)
    assert_equal 2, result.counts.fetch("existing")
    assert_equal 1, result.counts.fetch("resolved")
    assert_equal 1, result.counts.fetch("introduced")
  end

  def test_moved_when_path_differs_same_message
    baseline = baseline_for([finding(path: "app/a.rb", message: "same", rule_id: "Style/Foo")])
    current = [finding(path: "app/b.rb", message: "same", rule_id: "Style/Foo")]
    result = RailVerdict::Comparison.classify(findings: current, baseline: baseline)
    assert_equal 1, result.counts.fetch("moved")
    assert_equal 0, result.counts.fetch("introduced")
    assert_equal 0, result.counts.fetch("resolved")
    assert_equal "moved", result.moved.first.state
  end

  def test_changed_when_message_differs_same_path
    baseline = baseline_for([finding(path: "app/a.rb", message: "old msg", rule_id: "Style/Foo")])
    current = [finding(path: "app/a.rb", message: "new msg", rule_id: "Style/Foo")]
    result = RailVerdict::Comparison.classify(findings: current, baseline: baseline)
    assert_equal 1, result.counts.fetch("changed")
    assert_equal 0, result.counts.fetch("introduced")
    assert_equal 0, result.counts.fetch("resolved")
  end

  def test_ambiguous_multi_match_stays_introduced_and_resolved
    baseline = baseline_for([finding(path: "app/a.rb", message: "dup", rule_id: "Style/Foo"), finding(path: "app/b.rb", message: "dup", rule_id: "Style/Foo")])
    current = [finding(path: "app/c.rb", message: "dup", rule_id: "Style/Foo")]
    result = RailVerdict::Comparison.classify(findings: current, baseline: baseline)
    assert_equal 1, result.counts.fetch("introduced")
    assert_equal 2, result.counts.fetch("resolved")
    assert_equal 0, result.counts.fetch("moved")
  end

  def test_no_baseline_all_introduced
    findings = [finding(path: "app/a.rb", message: "one")]
    result = RailVerdict::Comparison.classify(findings: findings, baseline: nil)
    assert_equal 1, result.counts.fetch("introduced")
    assert_equal 0, result.counts.fetch("existing")
  end

  def test_determinism_shuffled_input
    original = [finding(path: "app/c.rb", message: "c"), finding(path: "app/a.rb", message: "a"), finding(path: "app/b.rb", message: "b")]
    baseline = baseline_for(original)
    first = RailVerdict::Comparison.classify(findings: original.shuffle, baseline: baseline)
    second = RailVerdict::Comparison.classify(findings: original.shuffle, baseline: baseline)
    assert_equal first.counts, second.counts
    assert_equal first.classified_findings.map(&:fingerprint), second.classified_findings.map(&:fingerprint)
  end

  def test_large_baseline_hash_lookup
    many = 500.times.map { |index| finding(path: "app/#{index}.rb", message: "msg #{index}") }
    baseline = baseline_for(many)
    current = many.first(250) + [finding(path: "app/new.rb", message: "brand new")]
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = RailVerdict::Comparison.classify(findings: current, baseline: baseline)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    assert_equal 250, result.counts.fetch("existing")
    assert elapsed < 1.0
  end

  def test_existing_remains_visible_and_not_hidden
    findings = [finding(path: "app/a.rb", message: "keep")]
    baseline = baseline_for(findings)
    result = RailVerdict::Comparison.classify(findings: findings, baseline: baseline)
    assert_includes result.classified_findings.map(&:fingerprint), findings.first.fingerprint
  end
end
