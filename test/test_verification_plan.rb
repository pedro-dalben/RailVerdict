# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "test_helper"

class TestVerificationPlan < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("railverdict-plan-")
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
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
  end

  def test_initial_plan_without_handoff_executes_all_enabled_analyzers
    plan = RailVerdict::VerificationPlan.build(
      repository_root: @tmpdir,
      configuration: @config,
      changed: false
    )

    assert_empty plan.analyzers_to_reuse
    assert_equal %w[rubocop brakeman rspec].sort, plan.analyzers_to_execute.sort
    assert_equal "full", plan.test_scope
    assert_equal "execute", plan.decisions["rubocop"]["action"]
    assert_equal ["no_previous_evidence"], plan.decisions["rubocop"]["reasons"]
  end

  def test_changed_scope_populates_test_selection_and_target_files
    FileUtils.mkdir_p(File.join(@tmpdir, "app", "models"))
    FileUtils.mkdir_p(File.join(@tmpdir, "spec", "models"))
    File.write(File.join(@tmpdir, "app", "models", "user.rb"), "class User; end")
    File.write(File.join(@tmpdir, "spec", "models", "user_spec.rb"), "RSpec.describe User; end")

    git_context = Struct.new(:changed_files).new(["app/models/user.rb"])

    plan = RailVerdict::VerificationPlan.build(
      repository_root: @tmpdir,
      configuration: @config,
      git_context: git_context,
      changed: true
    )

    assert_equal "targeted", plan.test_scope
    assert_equal ["spec/models/user_spec.rb"], plan.target_files["rspec"]
    assert_nil plan.fallback_reasons["rspec"]
  end
end
