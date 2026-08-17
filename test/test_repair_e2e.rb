# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "json"

class TestRepairE2E < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir
    File.write(File.join(@tmp, ".railverdict.yml"), <<~YAML)
      version: 1.4
      mode: strict
      analyzers:
        rubocop: { enabled: true, required: true }
    YAML
    FileUtils.mkdir_p(File.join(@tmp, "app/models"))
    File.write(File.join(@tmp, "app/models/book.rb"), "class Book; def foo; x = 1; end; end\n")
  end

  def teardown
    FileUtils.remove_entry(@tmp) if Dir.exist?(@tmp)
  end

  def make_outcome_with_finding(still_present: true)
    fp = RailVerdict::Fingerprint.hexdigest(analyzer: "rubocop", rule_id: "Lint/UselessAssignment", path: "app/models/book.rb", message: "useless assignment")
    finding = RailVerdict::Finding.new(
      fingerprint: fp, origin: "deterministic", analyzer: "rubocop", rule_id: "Lint/UselessAssignment", category: "lint",
      severity: "high", confidence: "high", state: "introduced", evidence_ref: "rubocop:1",
      location: { "path" => "app/models/book.rb", "start_line" => 1 }, message: "useless assignment"
    )
    analyzer_result = RailVerdict::AnalyzerResult.new(
      analyzer: "rubocop", invocation: { "executable" => "rubocop", "argv" => [] }, execution_status: "succeeded", finding_ids: [finding.id]
    )
    findings = still_present ? [finding] : []
    gate = still_present ? "FAIL" : "PASS"
    policy = still_present ? "fail" : "pass"
    result = RailVerdict::GateResult.new(
      completion_status: "complete", gate: gate, policy_status: policy,
      findings: findings.map { |f| { "id" => f.id, "fingerprint" => f.fingerprint, "severity" => f.severity, "state" => f.state, "blocking" => true } },
      analyzer_results: [analyzer_result], operational_failures: [], decision_reasons: [{ "code" => "x", "message" => "x" }]
    )
    config = RailVerdict::Configuration.load(File.join(@tmp, ".railverdict.yml"))
    context = RailVerdict::RunContext.build(repository_root: @tmp, configuration: config, analyzer_versions: { "rubocop" => "1.0" }, revision_resolver: ->(_) { "abc1234" })
    [finding, RailVerdict::Check::Outcome.new(result: result, context: context, configuration: config, findings: findings)]
  end

  def test_fail_repair_pass_loop
    finding, outcome = make_outcome_with_finding(still_present: true)
    packet = RailVerdict::Repair::ContextAssembler.build(outcome: outcome, finding_ref: finding.id, repository_root: @tmp)
    assert_equal "FAIL", packet.to_h["verification"]["gate"]
    File.write(File.join(@tmp, "app/models/book.rb"), "class Book; def foo; end; end\n")
    _, outcome2 = make_outcome_with_finding(still_present: false)
    verifier = RailVerdict::Repair::Verifier.verify(packet: packet, new_outcome: outcome2)
    assert_equal "fixed", verifier.target_status
    assert_equal "PASS", verifier.gate
  end

  def test_still_present
    finding, outcome = make_outcome_with_finding(still_present: true)
    packet = RailVerdict::Repair::ContextAssembler.build(outcome: outcome, finding_ref: finding.id, repository_root: @tmp)
    verifier = RailVerdict::Repair::Verifier.verify(packet: packet, new_outcome: outcome)
    assert_equal "still_present", verifier.target_status
  end

  def test_incomplete_when_analyzer_missing
    finding, outcome = make_outcome_with_finding(still_present: true)
    packet = RailVerdict::Repair::ContextAssembler.build(outcome: outcome, finding_ref: finding.id, repository_root: @tmp)
    incomplete = RailVerdict::GateResult.new(
      completion_status: "incomplete", gate: "INCOMPLETE", policy_status: "not_evaluated",
      findings: [], analyzer_results: [], operational_failures: [{ "code" => "unavailable", "message" => "rubocop unavailable" }],
      decision_reasons: [{ "code" => "incomplete", "message" => "incomplete" }]
    )
    config = RailVerdict::Configuration.load(File.join(@tmp, ".railverdict.yml"))
    context = RailVerdict::RunContext.build(repository_root: @tmp, configuration: config, analyzer_versions: {}, revision_resolver: ->(_) { "abc1234" })
    out2 = RailVerdict::Check::Outcome.new(result: incomplete, context: context, configuration: config, findings: [])
    verifier = RailVerdict::Repair::Verifier.verify(packet: packet, new_outcome: out2)
    assert_equal "incomplete", verifier.target_status
  end

  def test_boundary_changed_on_config
    finding, outcome = make_outcome_with_finding(still_present: true)
    packet = RailVerdict::Repair::ContextAssembler.build(outcome: outcome, finding_ref: finding.id, repository_root: @tmp)
    File.write(File.join(@tmp, ".railverdict.yml"), <<~YAML)
      version: 1.4
      mode: advisory
      analyzers:
        rubocop: { enabled: true, required: true }
    YAML
    config2 = RailVerdict::Configuration.load(File.join(@tmp, ".railverdict.yml"))
    context2 = RailVerdict::RunContext.build(repository_root: @tmp, configuration: config2, analyzer_versions: { "rubocop" => "1.0" }, revision_resolver: ->(_) { "abc1234" })
    result2 = RailVerdict::GateResult.new(
      completion_status: "complete", gate: "PASS", policy_status: "pass",
      findings: [], analyzer_results: [RailVerdict::AnalyzerResult.new(analyzer: "rubocop", invocation: { "executable" => "rubocop", "argv" => [] }, execution_status: "succeeded", finding_ids: [])],
      operational_failures: [], decision_reasons: []
    )
    out2 = RailVerdict::Check::Outcome.new(result: result2, context: context2, configuration: config2, findings: [])
    verifier = RailVerdict::Repair::Verifier.verify(packet: packet, new_outcome: out2)
    assert verifier.verification_boundary_changed.is_a?(Hash)
    assert verifier.verification_boundary_changed["config"]
  end

  def test_packet_does_not_edit_source
    finding, outcome = make_outcome_with_finding(still_present: true)
    mtime_before = File.mtime(File.join(@tmp, "app/models/book.rb")) rescue Time.now
    RailVerdict::Repair::ContextAssembler.build(outcome: outcome, finding_ref: finding.id, repository_root: @tmp)
    mtime_after = File.mtime(File.join(@tmp, "app/models/book.rb")) rescue mtime_before
    assert_equal mtime_before, mtime_after
  end
end
