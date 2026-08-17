# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "fileutils"

class TestWaiverExpiry < Minitest::Test
  def finding(path: "app/a.rb", message: "msg")
    fingerprint = RailVerdict::Finding.fingerprint_for(analyzer: "rubocop", rule_id: "Style/Foo", path: path, message: message)
    RailVerdict::Finding.new(
      fingerprint: fingerprint,
      origin: "deterministic",
      analyzer: "rubocop",
      rule_id: "Style/Foo",
      category: "style",
      severity: "high",
      confidence: "high",
      state: "observed",
      evidence_ref: "native:rubocop:#{fingerprint.delete_prefix('sha256:')[0, 12]}",
      location: { "path" => path, "start_line" => 1, "end_line" => 1 },
      message: message
    )
  end

  def test_active_waiver_non_blocking_expired_blocking_in_no_new_debt
    item = finding(path: "app/new.rb", message: "introduced")
    baseline_item = finding(path: "app/old.rb", message: "old")
    with_tmpdir do |dir|
      config_path = File.join(dir, ".railverdict.yml")
      File.write(config_path, "version: 1.2\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      config = RailVerdict::Configuration.load(config_path)
      baseline = RailVerdict::Baseline.create(findings: [baseline_item], configuration: config, analyzer_versions: {}, clock: Time.utc(2026, 8, 17, 12, 0, 0))
      waiver = {
        "fingerprint" => item.fingerprint,
        "reason" => "accepted debt",
        "owner" => "team",
        "created_at" => "2026-08-17T12:00:00Z",
        "expires_at" => "2026-08-17T13:00:00Z"
      }
      cmp_active = RailVerdict::Comparison.classify(findings: [baseline_item, item], baseline: baseline, waivers: [waiver], clock: Time.utc(2026, 8, 17, 12, 30, 0))
      assert_equal 1, cmp_active.counts.fetch("waived")
      active_result = RailVerdict::Verification::Policy.evaluate(configuration: config, analyzer_results: [analyzer_result], findings: cmp_active.classified_findings, comparison: { "counts" => cmp_active.counts, "introduced" => cmp_active.introduced.map(&:fingerprint), "existing" => cmp_active.existing.map(&:fingerprint), "resolved" => cmp_active.resolved.map { |entry| entry.fetch("fingerprint") }, "changed" => cmp_active.changed.map(&:fingerprint), "moved" => cmp_active.moved.map(&:fingerprint), "waived" => cmp_active.classified_findings.select { |finding| finding.state == "waived" }.map(&:fingerprint) })
      assert_equal "PASS", active_result.gate

      cmp_expired = RailVerdict::Comparison.classify(findings: [baseline_item, item], baseline: baseline, waivers: [waiver], clock: Time.utc(2026, 8, 17, 14, 0, 0))
      assert_equal 0, cmp_expired.counts.fetch("waived")
      assert_equal 1, cmp_expired.counts.fetch("introduced")
      expired_result = RailVerdict::Verification::Policy.evaluate(configuration: config, analyzer_results: [analyzer_result], findings: cmp_expired.classified_findings, comparison: { "counts" => cmp_expired.counts, "introduced" => cmp_expired.introduced.map(&:fingerprint), "existing" => cmp_expired.existing.map(&:fingerprint), "resolved" => cmp_expired.resolved.map { |entry| entry.fetch("fingerprint") }, "changed" => cmp_expired.changed.map(&:fingerprint), "moved" => cmp_expired.moved.map(&:fingerprint), "waived" => [] })
      assert_equal "FAIL", expired_result.gate
    end
  end

  def test_expiry_is_utc_deterministic
    item = finding
    waiver = {
      "fingerprint" => item.fingerprint,
      "reason" => "reason",
      "owner" => "owner",
      "created_at" => "2026-08-17T12:00:00Z",
      "expires_at" => "2026-08-17T13:00:00Z"
    }
    assert RailVerdict::Waiver.active?(waiver, clock: Time.utc(2026, 8, 17, 12, 59, 59))
    refute RailVerdict::Waiver.active?(waiver, clock: Time.utc(2026, 8, 17, 13, 0, 0))
  end

  private

  def analyzer_result
    RailVerdict::AnalyzerResult.new(
      analyzer: "rubocop",
      invocation: { "executable" => "rubocop", "argv" => [] },
      execution_status: "succeeded",
      finding_ids: []
    )
  end
end
