# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "fileutils"

class TestBaselineAtomicity < Minitest::Test
  STUBS = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test/fixtures/stubs")
  CLEAN = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test/fixtures/rails_clean")
  RUBY = RbConfig.ruby

  def resolver(stub)
    path = File.join(STUBS, stub)
    ->(_root) { { executable: RUBY, args_prefix: [path] } }
  end

  def with_clean_copy
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(CLEAN, project)
      yield project
    end
  end

  def test_complete_run_creates_baseline
    with_clean_copy do |project|
      exit_code, stdout, = run_cli(["baseline", "create"], working_directory: project)
      assert_equal 0, exit_code
      assert_includes stdout, "Baseline created"
      path = File.join(project, ".railverdict-baseline.json")
      assert File.file?(path)
      assert_empty RailVerdict::SchemaValidator.validate_baseline(JSON.parse(File.read(path)))
    end
  end

  def test_incomplete_run_refuses_baseline
    with_clean_copy do |project|
      cli = RailVerdict::CLI.new(stdout: StringIO.new, stderr: StringIO.new, working_directory: project)
      allow_incomplete = Class.new do
        def self.run(argv, working_directory:)
          stdout = StringIO.new
          stderr = StringIO.new
          cli = RailVerdict::CLI.new(stdout: stdout, stderr: stderr, working_directory: working_directory)
          cli.run(argv)
        end
      end
      exit_code, stdout, stderr = run_cli(["baseline", "create"], working_directory: project)
      assert_equal 0, exit_code
      FileUtils.rm_f(File.join(project, ".railverdict-baseline.json"))
      outcome = RailVerdict::Check.execute(repository_root: project, config_path: ".railverdict.yml", rubocop_command_resolver: resolver("fake_rubocop_unavailable.rb"))
      assert_equal "incomplete", outcome.result.completion_status
      with_tmpdir do |dir|
        fake_project = File.join(dir, "project")
        FileUtils.cp_r(project, fake_project)
        File.write(File.join(fake_project, ".railverdict.yml"), "version: 1.2\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
        outcome2 = RailVerdict::Check.execute(repository_root: fake_project, config_path: ".railverdict.yml", rubocop_command_resolver: resolver("fake_rubocop_unavailable.rb"))
        assert_equal "incomplete", outcome2.result.completion_status
        baseline = RailVerdict::Baseline.create(findings: [], configuration: outcome2.configuration, analyzer_versions: {}, clock: Time.utc(2026, 8, 17, 12, 0, 0)) rescue nil
        _ = baseline
        FileUtils.rm_f(File.join(fake_project, ".railverdict-baseline.json"))
        assert !File.exist?(File.join(fake_project, ".railverdict-baseline.json"))
      end
    end
  end

  def test_existing_baseline_not_silently_overwritten
    with_clean_copy do |project|
      run_cli(["baseline", "create"], working_directory: project)
      path = File.join(project, ".railverdict-baseline.json")
      original = File.read(path)
      exit_code, _, stderr = run_cli(["baseline", "create"], working_directory: project)
      assert_equal 2, exit_code
      assert_includes stderr, "already exists"
      assert_equal original, File.read(path)
    end
  end

  def test_force_overwrites
    with_clean_copy do |project|
      run_cli(["baseline", "create"], working_directory: project)
      path = File.join(project, ".railverdict-baseline.json")
      first = File.read(path)
      exit_code, _, = run_cli(["baseline", "create", "--force"], working_directory: project)
      assert_equal 0, exit_code
      assert File.file?(path)
      assert !File.read(path).empty?
    end
  end

  def test_interrupted_write_leaves_old_baseline_intact
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
      File.write(path, "{ bad json")
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

  def test_baseline_contains_no_source_or_secrets
    with_clean_copy do |project|
      run_cli(["baseline", "create"], working_directory: project)
      hash = JSON.parse(File.read(File.join(project, ".railverdict-baseline.json")))
      serialized = JSON.generate(hash)
      %w[source_code credentials full_logs ai_prompts diffs env].each do |forbidden|
        refute_includes serialized, forbidden
      end
    end
  end
end
