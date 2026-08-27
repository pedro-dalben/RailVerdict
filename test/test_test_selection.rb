# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "test_helper"

class TestTestSelection < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("railverdict-test-selection-")
    # Setup typical Rails directory tree
    FileUtils.mkdir_p(File.join(@tmpdir, "app", "models"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app", "controllers"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app", "services"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app", "policies"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app", "jobs"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app", "mailers"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app", "helpers"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app", "components"))
    FileUtils.mkdir_p(File.join(@tmpdir, "app", "views", "users"))
    FileUtils.mkdir_p(File.join(@tmpdir, "config", "initializers"))
    FileUtils.mkdir_p(File.join(@tmpdir, "db", "migrate"))
    FileUtils.mkdir_p(File.join(@tmpdir, "spec", "models"))
    FileUtils.mkdir_p(File.join(@tmpdir, "spec", "requests"))
    FileUtils.mkdir_p(File.join(@tmpdir, "spec", "services"))
    FileUtils.mkdir_p(File.join(@tmpdir, "spec", "policies"))
    FileUtils.mkdir_p(File.join(@tmpdir, "spec", "jobs"))
    FileUtils.mkdir_p(File.join(@tmpdir, "spec", "support"))

    # Create dummy files
    File.write(File.join(@tmpdir, "app", "models", "user.rb"), "class User; end")
    File.write(File.join(@tmpdir, "spec", "models", "user_spec.rb"), "RSpec.describe User do; end")
    File.write(File.join(@tmpdir, "app", "controllers", "users_controller.rb"), "class UsersController; end")
    File.write(File.join(@tmpdir, "spec", "requests", "users_spec.rb"), "RSpec.describe 'Users' do; end")
    File.write(File.join(@tmpdir, "app", "services", "payment_processor.rb"), "class PaymentProcessor; end")
    File.write(File.join(@tmpdir, "spec", "services", "payment_processor_spec.rb"), "RSpec.describe PaymentProcessor do; end")
    File.write(File.join(@tmpdir, "app", "policies", "user_policy.rb"), "class UserPolicy; end")
    File.write(File.join(@tmpdir, "spec", "policies", "user_policy_spec.rb"), "RSpec.describe UserPolicy do; end")
    File.write(File.join(@tmpdir, "app", "jobs", "sync_job.rb"), "class SyncJob; end")
    File.write(File.join(@tmpdir, "spec", "jobs", "sync_job_spec.rb"), "RSpec.describe SyncJob do; end")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
  end

  def test_isolated_model_change_resolves_targeted_spec
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["app/models/user.rb"],
      framework: :rspec
    )
    assert_equal "targeted", res.scope
    assert_equal ["spec/models/user_spec.rb"], res.selected_files
    assert_nil res.fallback_reason
  end

  def test_controller_change_resolves_requests_spec
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["app/controllers/users_controller.rb"],
      framework: :rspec
    )
    assert_equal "targeted", res.scope
    assert_equal ["spec/requests/users_spec.rb"], res.selected_files
    assert_nil res.fallback_reason
  end

  def test_service_change_resolves_service_spec
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["app/services/payment_processor.rb"],
      framework: :rspec
    )
    assert_equal "targeted", res.scope
    assert_equal ["spec/services/payment_processor_spec.rb"], res.selected_files
  end

  def test_policy_change_resolves_policy_spec
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["app/policies/user_policy.rb"],
      framework: :rspec
    )
    assert_equal "targeted", res.scope
    assert_equal ["spec/policies/user_policy_spec.rb"], res.selected_files
  end

  def test_direct_spec_change_resolves_itself
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["spec/models/user_spec.rb"],
      framework: :rspec
    )
    assert_equal "targeted", res.scope
    assert_equal ["spec/models/user_spec.rb"], res.selected_files
  end

  def test_doc_only_change_yields_targeted_empty
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["README.md", "docs/architecture.md"],
      framework: :rspec
    )
    assert_equal "targeted", res.scope
    assert_empty res.selected_files
    assert_nil res.fallback_reason
  end

  def test_spec_helper_triggers_safe_fallback_to_full
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["app/models/user.rb", "spec/rails_helper.rb"],
      framework: :rspec
    )
    assert_equal "full", res.scope
    assert_empty res.selected_files
    assert_match(/shared_infrastructure_changed:spec\/rails_helper\.rb/, res.fallback_reason)
  end

  def test_gemfile_triggers_safe_fallback_to_full
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["Gemfile.lock"],
      framework: :rspec
    )
    assert_equal "full", res.scope
    assert_match(/shared_infrastructure_changed:Gemfile\.lock/, res.fallback_reason)
  end

  def test_routes_triggers_safe_fallback_to_full
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["config/routes.rb"],
      framework: :rspec
    )
    assert_equal "full", res.scope
    assert_match(/shared_infrastructure_changed:config\/routes\.rb/, res.fallback_reason)
  end

  def test_schema_triggers_safe_fallback_to_full
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["db/schema.rb"],
      framework: :rspec
    )
    assert_equal "full", res.scope
    assert_match(/shared_infrastructure_changed:db\/schema\.rb/, res.fallback_reason)
  end

  def test_application_record_triggers_safe_fallback_to_full
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["app/models/application_record.rb"],
      framework: :rspec
    )
    assert_equal "full", res.scope
    assert_match(/shared_infrastructure_changed:app\/models\/application_record\.rb/, res.fallback_reason)
  end

  def test_unmapped_source_code_triggers_safe_fallback_to_full
    # New model without a corresponding spec on disk
    File.write(File.join(@tmpdir, "app", "models", "invoice.rb"), "class Invoice; end")
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: ["app/models/invoice.rb"],
      framework: :rspec
    )
    assert_equal "full", res.scope
    assert_match(/unmapped_source_change:app\/models\/invoice\.rb/, res.fallback_reason)
  end

  def test_empty_changed_files_triggers_fallback_to_full
    res = RailVerdict::TestSelection.resolve(
      repository_root: @tmpdir,
      changed_files: [],
      framework: :rspec
    )
    assert_equal "full", res.scope
    assert_equal "empty_or_unresolvable_changed_scope", res.fallback_reason
  end
end
