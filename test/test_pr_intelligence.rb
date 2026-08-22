# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "json"

class TestPRIntelligence < Minitest::Test
  CONFIG = <<~YAML
    version: 1.4
    mode: strict
    analyzers:
      rubocop: { enabled: false, required: false }
      minitest: { enabled: false, required: false }
      rspec: { enabled: false, required: false }
      simplecov: { enabled: false, required: false }
      bundler_audit: { enabled: false, required: false }
  YAML

  def git!(dir, *args)
    system("git", "-C", dir, *args, exception: true, out: File::NULL, err: File::NULL)
  end

  def make_repo
    dir = Dir.mktmpdir("rv-pr-")
    File.write(File.join(dir, ".railverdict.yml"), CONFIG)
    FileUtils.mkdir_p(File.join(dir, "app/policies"))
    FileUtils.mkdir_p(File.join(dir, "config"))
    FileUtils.mkdir_p(File.join(dir, "db"))
    FileUtils.mkdir_p(File.join(dir, "test"))
    File.write(File.join(dir, "app/policies/user_policy.rb"), "class UserPolicy; end\n")
    File.write(File.join(dir, "config/routes.rb"), "Rails.application.routes.draw { root to: 'home#index' }\n")
    File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
    File.write(File.join(dir, "test_helper.rb"), "# fixture\n")
    git!(dir, "init", "-q", "-b", "main")
    git!(dir, "config", "user.email", "test@example.test")
    git!(dir, "config", "user.name", "RailVerdict Test")
    git!(dir, "add", ".")
    git!(dir, "commit", "-qm", "base")
    dir
  end

  def changed_repo
    dir = make_repo
    File.write(File.join(dir, "db/schema.rb"), "ActiveRecord::Schema.define {}\n")
    File.write(File.join(dir, "config/routes.rb"), "Rails.application.routes.draw { root to: 'orders#index' }\n")
    File.write(File.join(dir, "Gemfile.lock"), "GEM\n")
    File.write(File.join(dir, "test/orders_test.rb"), "assert true\n")
    FileUtils.mv(File.join(dir, "app/policies/user_policy.rb"), File.join(dir, "app/policies/order_policy.rb"))
    File.delete(File.join(dir, "test_helper.rb"))
    git!(dir, "add", ".")
    git!(dir, "commit", "-qm", "change")
    [dir, `git -C #{dir} rev-parse HEAD~1`.strip]
  end

  def test_cli_json_contains_change_metrics_signals_and_unavailable_delta
    dir, base = changed_repo
    exit_code, stdout, stderr = run_cli(["pr", "--base", base, "--format", "json"], working_directory: dir)
    assert_equal 0, exit_code
    assert_empty stderr

    document = JSON.parse(stdout)
    assert_empty RailVerdict::SchemaValidator.validate_pr_intelligence(document)
    assert_equal "1.0", document.fetch("schema_version")
    assert_equal base, document.dig("provenance", "base")
    assert_equal 6, document.dig("change", "files_changed")
    assert_equal 4, document.dig("change", "lines_added")
    assert_equal 2, document.dig("change", "lines_removed")
    assert_equal 1, document.dig("change", "status_counts", "renamed")
    assert_equal 1, document.dig("change", "status_counts", "deleted")
    assert_equal true, document.dig("signals", "database_change", "present")
    assert_equal true, document.dig("signals", "routes_change", "present")
    assert_equal true, document.dig("signals", "dependency_change", "present")
    assert_equal true, document.dig("signals", "authorization_change", "present")
    assert_equal true, document.dig("signals", "tests_change", "present")
    assert_equal true, document.dig("signals", "configuration_change", "present")
    assert_equal false, document.dig("quality_delta", "available")
    assert_equal "baseline_not_available", document.dig("quality_delta", "reason")
  ensure
    FileUtils.remove_entry(dir) if dir && File.directory?(dir)
  end

  def test_console_is_bounded_and_keeps_gate_visible
    dir, base = changed_repo
    exit_code, stdout, = run_cli(["pr", "--base", base], working_directory: dir)
    assert_equal 0, exit_code
    assert_includes stdout, "RailVerdict PR Intelligence"
    assert_includes stdout, "Gate: PASS"
    assert_includes stdout, "Quality Delta"
    refute_includes stdout, "app/policies/order_policy.rb"
  ensure
    FileUtils.remove_entry(dir) if dir && File.directory?(dir)
  end

  def test_invalid_base_is_incomplete_and_json_exposes_it
    dir = make_repo
    exit_code, stdout, stderr = run_cli(["pr", "--base", "not-a-real-base", "--format", "json"], working_directory: dir)
    assert_equal 2, exit_code
    assert_empty stderr
    document = JSON.parse(stdout)
    assert_equal "INCOMPLETE", document.dig("gate_result", "gate")
    assert_equal "incomplete", document.dig("gate_result", "completion_status")
    assert_equal false, document.dig("change", "available")
  ensure
    FileUtils.remove_entry(dir) if dir && File.directory?(dir)
  end

  def test_quality_delta_uses_canonical_comparison
    dir, base = changed_repo
    config = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
    git_context = RailVerdict::Git::Context.build(repository_root: dir, base_override: base, configuration: config)
    result = RailVerdict::GateResult.new(
      completion_status: "complete",
      gate: "PASS",
      policy_status: "pass",
      findings: [],
      analyzer_results: [],
      operational_failures: [],
      decision_reasons: [],
      baseline: { "loaded" => true, "schema_version" => "1.0", "fingerprint_version" => 1 },
      comparison: {
        "counts" => { "introduced" => 1, "existing" => 2, "resolved" => 3, "changed" => 4, "moved" => 5, "waived" => 6 },
        "orphaned_waivers" => ["sha256:orphan"]
      },
      git: git_context.to_h
    )
    context = Struct.new(:git_context, :configuration_digest).new(git_context, "sha256:config")
    outcome = Struct.new(:result, :context).new(result, context)

    document = RailVerdict::PRIntelligence.document(outcome)
    assert_equal({
      "available" => true,
      "introduced" => 1,
      "existing" => 2,
      "resolved" => 3,
      "changed" => 4,
      "moved" => 5,
      "waived" => 6,
      "orphaned_waivers" => 1
    }, document.fetch("quality_delta"))
  ensure
    FileUtils.remove_entry(dir) if dir && File.directory?(dir)
  end

  def test_incomplete_analyzer_stays_incomplete_in_gate_result
    analyzer = RailVerdict::AnalyzerResult.new(
      analyzer: "rspec",
      invocation: { "executable" => "rspec", "argv" => [] },
      execution_status: "timed_out",
      finding_ids: [],
      failure: { "code" => "timed_out", "message" => "timeout" }
    )
    result = RailVerdict::GateResult.new(
      completion_status: "incomplete",
      gate: "INCOMPLETE",
      policy_status: "not_evaluated",
      findings: [],
      analyzer_results: [analyzer],
      operational_failures: [{ "code" => "timed_out", "analyzer" => "rspec", "message" => "timeout" }],
      decision_reasons: [{ "code" => "required_evidence_incomplete", "message" => "RSpec timed out" }]
    )
    outcome = Struct.new(:result, :context).new(result, nil)
    document = RailVerdict::PRIntelligence.document(outcome)
    assert_equal "INCOMPLETE", document.dig("gate_result", "gate")
    assert_equal "timed_out", document.dig("analyzer_evidence", 0, "execution_status")
  end

  def test_test_and_coverage_intelligence_uses_canonical_summaries
    rspec = RailVerdict::AnalyzerResult.new(
      analyzer: "rspec",
      tool_version: "3.13.6",
      invocation: { "executable" => "rspec", "argv" => [] },
      execution_status: "succeeded",
      finding_ids: [],
      evidence_summary: {
        "tests_total" => 3,
        "assertions" => 3,
        "failures" => 0,
        "errors" => 0,
        "skips" => 1,
        "duration_seconds" => 0.2,
        "runner" => "rspec 3.13.6"
      }
    )
    simplecov = RailVerdict::AnalyzerResult.new(
      analyzer: "simplecov",
      tool_version: "1.0",
      invocation: { "executable" => "simplecov", "argv" => [] },
      execution_status: "succeeded",
      finding_ids: [],
      evidence_summary: {
        "percent" => 88.5,
        "changed_line_coverage" => { "percent" => 75.0, "covered_lines" => 3, "executable_lines" => 4 }
      }
    )
    result = RailVerdict::GateResult.new(
      completion_status: "complete",
      gate: "PASS",
      policy_status: "pass",
      findings: [],
      analyzer_results: [rspec, simplecov],
      operational_failures: [],
      decision_reasons: []
    )
    document = RailVerdict::PRIntelligence.document(Struct.new(:result, :context).new(result, nil))

    assert_equal 3, document.dig("test_intelligence", "analyzers", "rspec", "tests_total")
    assert_equal 1, document.dig("test_intelligence", "analyzers", "rspec", "skips")
    assert_equal 88.5, document.dig("coverage", "global_percent")
    assert_equal 75.0, document.dig("coverage", "changed_lines_percent")
  end

  def test_json_is_byte_identical_for_same_outcome
    dir, base = changed_repo
    config = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
    first = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml", changed: true, base: base)
    second = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml", changed: true, base: base)
    assert_equal RailVerdict::PRIntelligence.render_json(first), RailVerdict::PRIntelligence.render_json(second)
  ensure
    FileUtils.remove_entry(dir) if dir && File.directory?(dir)
  end
end
