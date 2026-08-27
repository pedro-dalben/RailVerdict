# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "test_helper"

class TestReusePartial < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("railverdict-partial-reuse-")
    @config_path = File.join(@tmpdir, ".railverdict.yml")
    File.write(@config_path, <<~YAML)
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
        brakeman:
          enabled: true
          required: true
        rspec:
          enabled: true
          required: true
    YAML
    @config = RailVerdict::Configuration.load(@config_path)

    # Initialize a clean git repo
    system("git", "-C", @tmpdir, "init", "-q", exception: true)
    system("git", "-C", @tmpdir, "config", "user.email", "test@railverdict.org", exception: true)
    system("git", "-C", @tmpdir, "config", "user.name", "RailVerdict Test", exception: true)
    system("git", "-C", @tmpdir, "add", ".", exception: true)
    system("git", "-C", @tmpdir, "commit", "-q", "-m", "Initial commit", exception: true)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
  end

  def build_handoff(outcome)
    receipt = RailVerdict::Receipt.build(outcome: outcome)
    evidence_set = {
      "analyzer_results" => outcome.result.analyzer_results.map do |ar|
        h = { "analyzer" => ar.analyzer, "execution_status" => ar.execution_status, "tool_version" => ar.tool_version }
        findings = outcome.findings.select { |f| f.analyzer == ar.analyzer }.map(&:to_schema_h).sort_by { |ff| ff["fingerprint"] }
        h["findings"] = findings if findings.any?
        h
      end
    }
    provenance = { "analyzer_versions" => outcome.context&.analyzer_versions || {} }
    scope = { "verification_mode" => "full" }
    RailVerdict::Handoff.build(receipt: receipt, evidence_set: evidence_set, evidence_provenance: provenance, source_scope: scope)
  end

  def test_partial_reuse_reuses_static_evidence_and_executes_dynamic_specs
    stubs_dir = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs")
    ruby = RbConfig.ruby
    rubocop_stub = File.join(stubs_dir, "fake_rubocop_clean.rb")
    brakeman_stub = File.join(stubs_dir, "fake_brakeman_clean.rb")
    rspec_stub = File.join(stubs_dir, "fake_rspec_clean.rb")

    resolvers = {
      "rubocop" => ->(_r) { { executable: ruby, args_prefix: [rubocop_stub] } },
      "brakeman" => ->(_r) { { executable: ruby, args_prefix: [brakeman_stub] } },
      "rspec" => ->(_r) { { executable: ruby, args_prefix: [rspec_stub] } }
    }

    # 1. Run full verification first with state guard
    outcome_initial = RailVerdict::Check.execute_with_state_guard(
      repository_root: @tmpdir,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: resolvers
    )

    # 2. Build a handoff document from the initial outcome
    handoff_doc = build_handoff(outcome_initial)
    refute_nil handoff_doc

    # 3. Create a custom runner tracking which commands actually execute
    executed_commands = []
    custom_runner = Class.new(RailVerdict::ProcessRunner) do
      define_singleton_method(:run) do |executable, argv, **kwargs|
        executed_commands << [executable, argv]
        super(executable, argv, **kwargs)
      end
    end

    # 4. Execute check with the handoff document passed in
    outcome_partial = RailVerdict::Check.execute(
      repository_root: @tmpdir,
      config_path: ".railverdict.yml",
      handoff_document: handoff_doc,
      rubocop_command_resolver: resolvers,
      runner: custom_runner
    )

    assert_equal "complete", outcome_partial.result.completion_status
    # RuboCop & Brakeman were reused, RSpec had to execute
    ar_rubocop = outcome_partial.result.analyzer_results.find { |ar| ar.analyzer == "rubocop" }
    ar_brakeman = outcome_partial.result.analyzer_results.find { |ar| ar.analyzer == "brakeman" }
    ar_rspec = outcome_partial.result.analyzer_results.find { |ar| ar.analyzer == "rspec" }

    assert ar_rubocop
    assert ar_brakeman
    assert ar_rspec
    assert_equal "succeeded", ar_rubocop.execution_status
    assert_equal "succeeded", ar_brakeman.execution_status
    assert_equal "succeeded", ar_rspec.execution_status

    # Verify only RSpec actually ran its test suite, while rubocop and brakeman scans were reused!
    full_runs = executed_commands.select { |_exe, argv| argv.include?("--out") || argv.include?("-f") || argv.include?("json") && !argv.include?("--version") }
    assert_equal 1, full_runs.length
    assert_includes full_runs.first.last, rspec_stub
  end
end
