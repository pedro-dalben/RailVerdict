# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "test_helper"

class TestDoctor < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("railverdict-doctor-")
    @config_path = File.join(@tmpdir, ".railverdict.yml")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
  end

  def test_doctor_with_valid_config_and_all_analyzers
    File.write(@config_path, <<~YAML)
      version: 1.5
      mode: strict
      analyzers:
        rubocop: { enabled: true, required: true }
        brakeman: { enabled: true, required: true }
        bundler_audit: { enabled: true, required: true }
        rspec: { enabled: true, required: true }
        simplecov: { enabled: true, required: false }
    YAML

    stubs_dir = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs")
    ruby = RbConfig.ruby
    resolvers = {
      "rubocop" => ->(_r) { { executable: ruby, args_prefix: [File.join(stubs_dir, "fake_rubocop_clean.rb")] } },
      "brakeman" => ->(_r) { { executable: ruby, args_prefix: [File.join(stubs_dir, "fake_brakeman_clean.rb")] } },
      "bundler_audit" => ->(_r) { { executable: ruby, args_prefix: [File.join(stubs_dir, "fake_bundler_audit_clean.rb")] } },
      "rspec" => ->(_r) { { executable: ruby, args_prefix: [File.join(stubs_dir, "fake_rspec_clean.rb")] } },
      "simplecov" => ->(_r) { { executable: ruby, args_prefix: [] } }
    }

    outcome = RailVerdict::Doctor.execute(
      repository_root: @tmpdir,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: resolvers
    )

    assert_equal 0, outcome.exit_code
    assert outcome.report["configuration"]["valid"]
    assert_equal "succeeded", outcome.report["analyzers"]["rubocop"]["status"]
    assert_equal "succeeded", outcome.report["analyzers"]["brakeman"]["status"]
    assert_equal "succeeded", outcome.report["analyzers"]["rspec"]["status"]
    assert_equal "8.0.6", outcome.report["analyzers"]["brakeman"]["version"]
    assert_includes outcome.report["hints"]["simplecov"], "coverage/coverage.json"
  end

  def test_doctor_hints_for_unavailable_analyzers
    File.write(@config_path, <<~YAML)
      version: 1.5
      mode: strict
      analyzers:
        rubocop: { enabled: true, required: true }
        brakeman: { enabled: true, required: true }
    YAML

    resolvers = {
      "rubocop" => ->(_r) { { executable: "non_existent_rubocop", args_prefix: [] } },
      "brakeman" => ->(_r) { { executable: "non_existent_brakeman", args_prefix: [] } }
    }

    outcome = RailVerdict::Doctor.execute(
      repository_root: @tmpdir,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: resolvers
    )

    assert_equal 0, outcome.exit_code
    assert_includes outcome.report["hints"]["rubocop"], "Add `rubocop` to the target bundle"
    assert_includes outcome.report["hints"]["brakeman"], "Add `brakeman` to the target bundle"
  end
end
