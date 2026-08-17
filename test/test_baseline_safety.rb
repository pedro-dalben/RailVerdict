# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "fileutils"
require "digest"

class TestBaselineSafety < Minitest::Test
  STUBS = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test/fixtures/stubs")
  CLEAN = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test/fixtures/rails_clean")
  RUBY = RbConfig.ruby

  def test_complete_run_creates_baseline
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(CLEAN, project)
      exit_code, _, = run_cli(["baseline", "create"], working_directory: project)
      assert_equal 0, exit_code
      assert File.file?(File.join(project, ".railverdict-baseline.json"))
    end
  end

  def test_incomplete_run_refuses_baseline
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(CLEAN, project)
      File.write(File.join(project, ".railverdict.yml"), "version: 1.2\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      File.write(File.join(project, ".rubocop.yml"), "AllCops:\n  NewCops: disable\n")
      original = File.read(File.join(project, ".railverdict.yml"))
      File.write(File.join(project, ".railverdict.yml"), "version: 1.2\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\nminitest:\n    enabled: true\n    required: true\n")
      exit_code, _, = run_cli(["baseline", "create"], working_directory: project)
      assert_equal 2, exit_code
      assert !File.exist?(File.join(project, ".railverdict-baseline.json"))
      File.write(File.join(project, ".railverdict.yml"), original)
    end
  end

  def test_existing_baseline_not_silently_overwritten
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(CLEAN, project)
      run_cli(["baseline", "create"], working_directory: project)
      path = File.join(project, ".railverdict-baseline.json")
      original = File.read(path)
      exit_code, _, stderr = run_cli(["baseline", "create"], working_directory: project)
      assert_equal 2, exit_code
      assert_includes stderr, "already exists"
      assert_equal original, File.read(path)
    end
  end

  def test_interrupted_write_leaves_old_intact
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(CLEAN, project)
      run_cli(["baseline", "create"], working_directory: project)
      path = File.join(project, ".railverdict-baseline.json")
      original = File.read(path)
      config = RailVerdict::Configuration.load(File.join(project, ".railverdict.yml"))
      baseline = RailVerdict::Baseline.create(findings: [], configuration: config, analyzer_versions: {}, clock: Time.utc(2026, 8, 17, 12, 0, 0))
      original_rename = File.method(:rename)
      File.define_singleton_method(:rename) { |*_args| raise IOError, "disk full" }
      begin
        assert_raises(IOError) { RailVerdict::Baseline.write(path: path, baseline: baseline, force: true) }
      ensure
        File.define_singleton_method(:rename, original_rename)
      end
      assert_equal original, File.read(path)
      assert Dir.glob(File.join(File.dirname(path), ".*.tmp.*")).empty?
    end
  end

  def test_malformed_baseline_fails_closed
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict-baseline.json")
      File.write(path, "{ bad")
      assert_raises(RailVerdict::Baseline::IncompatibleError) { RailVerdict::Baseline.read(path) }
    end
  end

  def test_unsupported_version_fails_closed
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(CLEAN, project)
      run_cli(["baseline", "create"], working_directory: project)
      path = File.join(project, ".railverdict-baseline.json")
      hash = JSON.parse(File.read(path))
      hash["fingerprint_version"] = 99
      File.write(path, JSON.generate(hash))
      assert_raises(RailVerdict::Baseline::IncompatibleError) { RailVerdict::Baseline.read(path) }
    end
  end

  def test_check_does_not_mutate_baseline
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(CLEAN, project)
      run_cli(["baseline", "create"], working_directory: project)
      path = File.join(project, ".railverdict-baseline.json")
      before = File.read(path)
      mtime = File.mtime(path)
      RailVerdict::Check.execute(repository_root: project, config_path: ".railverdict.yml")
      assert_equal before, File.read(path)
      assert_equal mtime, File.mtime(path)
    end
  end

  def test_check_does_not_mutate_waiver
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(CLEAN, project)
      run_cli(["baseline", "create"], working_directory: project)
      waiver_path = File.join(project, ".railverdict-waivers.json")
      File.write(waiver_path, JSON.generate({ "schema_version" => "1.0", "waivers" => [] }))
      before = File.read(waiver_path)
      RailVerdict::Check.execute(repository_root: project, config_path: ".railverdict.yml")
      assert_equal before, File.read(waiver_path)
    end
  end

  def test_baseline_contains_no_source_or_secrets
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(CLEAN, project)
      run_cli(["baseline", "create"], working_directory: project)
      content = File.read(File.join(project, ".railverdict-baseline.json"))
      %w[source_code credentials full_logs ai_prompts].each do |forbidden|
        refute_includes content, forbidden
      end
    end
  end

  def test_deterministic_output_across_locale
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(CLEAN, project)
      run_cli(["baseline", "create"], working_directory: project)
      out1 = RailVerdict::Check.execute(repository_root: project, config_path: ".railverdict.yml")
      out2 = RailVerdict::Check.execute(repository_root: project, config_path: ".railverdict.yml")
      assert_equal RailVerdict::Reporters::JsonReporter.render(out1.result), RailVerdict::Reporters::JsonReporter.render(out2.result)
    end
  end

  def test_large_baseline_hash_lookup
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.write(path, "version: 1.2\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      config = RailVerdict::Configuration.load(path)
      findings = 1000.times.map do |index|
        message = "msg #{index}"
        fingerprint = RailVerdict::Finding.fingerprint_for(analyzer: "rubocop", rule_id: "Style/Foo", path: "app/#{index}.rb", message: message)
        RailVerdict::Finding.new(
          fingerprint: fingerprint,
          origin: "deterministic",
          analyzer: "rubocop",
          rule_id: "Style/Foo",
          category: "style",
          severity: "low",
          confidence: "high",
          state: "observed",
          evidence_ref: "native:rubocop:#{fingerprint.delete_prefix('sha256:')[0, 12]}",
          location: { "path" => "app/#{index}.rb", "start_line" => 1, "end_line" => 1 },
          message: message
        )
      end
      baseline = RailVerdict::Baseline.create(findings: findings, configuration: config, analyzer_versions: {}, clock: Time.utc(2026, 8, 17, 12, 0, 0))
      current = findings.first(500)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = RailVerdict::Comparison.classify(findings: current, baseline: baseline)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      assert_equal 500, result.counts.fetch("existing")
      assert elapsed < 1.0
    end
  end

  def test_operational_failure_still_wins_with_baseline
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(CLEAN, project)
      run_cli(["baseline", "create"], working_directory: project)
      incomplete = RailVerdict::AnalyzerResult.new(
        analyzer: "rubocop",
        invocation: { "executable" => "rubocop", "argv" => [] },
        execution_status: "unavailable",
        finding_ids: [],
        failure: { "code" => "unavailable", "message" => "missing" }
      )
      result = RailVerdict::Verification::Policy.evaluate(configuration: RailVerdict::Configuration.load(File.join(project, ".railverdict.yml")), analyzer_results: [incomplete], findings: [], comparison: { "counts" => { "existing" => 100 }, "introduced" => [], "existing" => [], "resolved" => [], "changed" => [], "moved" => [], "waived" => [] })
      assert_equal "INCOMPLETE", result.gate
    end
  end
end
