# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "json"

class TestRailsContext < Minitest::Test
  def cp_fixture(src, dest)
    Dir.glob(File.join(src, "*")).each { |entry| FileUtils.cp_r(entry, dest) }
    dotfiles = Dir.glob(File.join(src, ".*")).reject { |entry| entry.end_with?("/.") || entry.end_with?("/..") }
    dotfiles.each { |entry| FileUtils.cp_r(entry, dest) }
  end

  def git_init(dir)
    system("git -C #{dir} init -q")
    system("git -C #{dir} config user.email 'test@test.com'")
    system("git -C #{dir} config user.name 'Test'")
  end
  def test_classifier_model
    assert_equal "model", RailVerdict::RailsContext::Classifier.classify("app/models/user.rb")
  end

  def test_classifier_controller
    assert_equal "controller", RailVerdict::RailsContext::Classifier.classify("app/controllers/users_controller.rb")
  end

  def test_classifier_namespaced
    assert_equal "model", RailVerdict::RailsContext::Classifier.classify("app/models/admin/user.rb")
  end

  def test_constant_inference_model
    assert_equal "User", RailVerdict::RailsContext::ConstantInferencer.infer(kind: "model", path: "app/models/user.rb")
  end

  def test_constant_inference_namespaced_model
    assert_equal "Admin::User", RailVerdict::RailsContext::ConstantInferencer.infer(kind: "model", path: "app/models/admin/user.rb")
  end

  def test_constant_inference_controller
    assert_equal "UsersController", RailVerdict::RailsContext::ConstantInferencer.infer(kind: "controller", path: "app/controllers/users_controller.rb")
  end

  def test_constant_inference_namespaced_controller
    assert_equal "Admin::UsersController", RailVerdict::RailsContext::ConstantInferencer.infer(kind: "controller", path: "app/controllers/admin/users_controller.rb")
  end

  def test_detector_rails_version
    root = File.expand_path("fixtures/rails_phase05/conventional_app", __dir__)
    detected = RailVerdict::RailsContext::Detector.detect(repository_root: root)
    assert_equal "8.0.1", detected["rails_version"]
  end

  def test_detector_database_adapter
    root = File.expand_path("fixtures/rails_phase05/conventional_app", __dir__)
    detected = RailVerdict::RailsContext::Detector.detect(repository_root: root)
    assert_equal "postgresql", detected["database_adapter"]
  end

  def test_detector_test_framework
    root = File.expand_path("fixtures/rails_phase05/conventional_app", __dir__)
    detected = RailVerdict::RailsContext::Detector.detect(repository_root: root)
    assert_includes %w[rspec both minitest], detected["test_framework"]
  end

  def test_detector_structure
    root = File.expand_path("fixtures/rails_phase05/conventional_app", __dir__)
    detected = RailVerdict::RailsContext::Detector.detect(repository_root: root)
    assert detected["structure"]["has_routes"]
    assert detected["structure"]["has_schema"]
  end

  def test_related_tests_for_model
    root = File.expand_path("fixtures/rails_phase05/conventional_app", __dir__)
    related = RailVerdict::RailsContext::Resolvers::TestCandidates.for(repository_root: root, kind: "model", path: "app/models/user.rb")
    paths = related.map { |entry| entry["path"] }
    assert_includes paths, "test/models/user_test.rb"
    assert_includes paths, "spec/models/user_spec.rb"
    related.each { |entry| assert_equal "conventional", entry["confidence"] }
  end

  def test_policy_match
    root = File.expand_path("fixtures/rails_phase05/conventional_app", __dir__)
    related = RailVerdict::RailsContext::Resolvers::PolicyResolver.for(repository_root: root, kind: "model", path: "app/models/user.rb", constant: "User")
    assert_equal 1, related.length
    assert_equal "app/policies/user_policy.rb", related.first["path"]
  end

  def test_view_match
    root = File.expand_path("fixtures/rails_phase05/conventional_app", __dir__)
    related = RailVerdict::RailsContext::Resolvers::ViewResolver.for(repository_root: root, kind: "controller", path: "app/controllers/users_controller.rb", constant: "UsersController")
    assert_equal 1, related.length
    assert_match "app/views/users", related.first["path"]
  end

  def test_schema_table_match
    root = File.expand_path("fixtures/rails_phase05/conventional_app", __dir__)
    related = RailVerdict::RailsContext::Resolvers::SchemaResolver.for(repository_root: root, kind: "model", constant: "User", path: "app/models/user.rb")
    assert_equal 1, related.length
    assert_equal "conventional", related.first["confidence"]
  end

  def test_custom_table_literal
    root = File.expand_path("fixtures/rails_phase05/custom_table_app", __dir__)
    related = RailVerdict::RailsContext::Resolvers::SchemaResolver.for(repository_root: root, kind: "model", constant: "Account", path: "app/models/account.rb")
    assert_equal 1, related.length
    assert_equal "exact", related.first["confidence"]
  end

  def test_dynamic_table_unresolved
    root = File.expand_path("fixtures/rails_phase05/custom_table_app", __dir__)
    related = RailVerdict::RailsContext::Resolvers::SchemaResolver.for(repository_root: root, kind: "model", constant: "DynamicTable", path: "app/models/dynamic_table.rb")
    assert_equal 1, related.length
    assert_equal "unresolved", related.first["confidence"]
  end

  def test_association_extraction
    root = File.expand_path("fixtures/rails_phase05/conventional_app", __dir__)
    assocs = RailVerdict::RailsContext::Resolvers::AssociationExtractor.extract(repository_root: root, path: "app/models/user.rb")
    names = assocs.map { |entry| entry["name"] }
    assert_includes names, "account"
    assert_includes names, "orders"
    assocs.each { |entry| assert_equal "exact", entry["confidence"] }
  end

  def test_route_scanner_literal
    root = File.expand_path("fixtures/rails_phase05/conventional_app", __dir__)
    scan = RailVerdict::RailsContext::Resolvers::RouteScanner.scan(repository_root: root)
    controllers = scan[:declarations].map { |decl| decl["controller"] }
    assert_includes controllers, "users"
  end

  def test_route_scanner_dynamic
    root = File.expand_path("fixtures/rails_phase05/dynamic_routes_app", __dir__)
    scan = RailVerdict::RailsContext::Resolvers::RouteScanner.scan(repository_root: root)
    assert scan[:unresolved]
  end

  def test_missing_schema_inferred
    root = File.expand_path("fixtures/rails_phase05/missing_schema_app", __dir__)
    related = RailVerdict::RailsContext::Resolvers::SchemaResolver.for(repository_root: root, kind: "model", constant: "User", path: "app/models/user.rb")
    assert_equal 1, related.length
    assert_equal "inferred", related.first["confidence"]
  end

  def test_confidence_values
    assert_equal %w[exact conventional inferred unresolved], RailVerdict::RailsContext::Confidence::VALUES
    refute_includes RailVerdict::RailsContext::Confidence::VALUES, "0.873"
  end

  def test_context_build_changed
    Dir.mktmpdir do |dir|
      cp_fixture(File.expand_path("fixtures/rails_phase05/conventional_app", __dir__), dir)
      Dir.chdir(dir) do
        system("git init -q")
        system("git config user.email 'test@test.com'")
        system("git config user.name 'Test'")
        File.write("app/models/user.rb", "# frozen_string_literal: true\nclass User; end\n")
        system("git add . && git commit -qm init")
        base = `git rev-parse HEAD`.strip
        File.write("app/models/user.rb", "# frozen_string_literal: true\nclass User\n  belongs_to :account\nend\n")
        system("git add app/models/user.rb && git commit -qm change")
        runner = RailVerdict::ProcessRunner
        config = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
        git_ctx = RailVerdict::Git::Context.build(repository_root: dir, base_override: base, configuration: config, runner: runner)
        rails_ctx = RailVerdict::RailsContext::Context.build(repository_root: dir, git_context: git_ctx)
        assert_equal "changed", rails_ctx.scope
        assert rails_ctx.entries.any? { |entry| entry["source_path"] == "app/models/user.rb" }
        entry = rails_ctx.entries.find { |item| item["source_path"] == "app/models/user.rb" }
        assert entry["related"].any? { |related| related["relationship"] == "related_test" }
      end
    end
  end

  def test_context_full
    root = File.expand_path("fixtures/rails_phase05/conventional_app", __dir__)
    rails_ctx = RailVerdict::RailsContext::Context.build(repository_root: root, git_context: nil)
    assert_equal "full", rails_ctx.scope
    assert_empty rails_ctx.entries
  end

  def test_rails_context_does_not_change_gate
    Dir.mktmpdir do |dir|
      cp_fixture(File.expand_path("fixtures/rails_phase05/conventional_app", __dir__), dir)
      Dir.chdir(dir) do
        system("git init -q")
        system("git config user.email 'test@test.com'")
        system("git config user.name 'Test'")
        system("git add . && git commit -qm init")
        base = `git rev-parse HEAD`.strip
        File.write("app/models/user.rb", "# changed\n")
        system("git add app/models/user.rb && git commit -qm change")
        config = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
        # Run check with and without rails context should have same gate for same findings
        result = RailVerdict::Check.execute(repository_root: dir, config_path: File.join(dir, ".railverdict.yml"), changed: true, base: base)
        assert result.result.rails_context
        # rails_context should not make gate INCOMPLETE when check succeeded
        refute_equal "INCOMPLETE", result.result.gate
      end
    end
  end

  def test_structure_sql_unresolved
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db"))
      File.write(File.join(dir, "db/structure.sql"), "CREATE TABLE users (id INT);")
      File.write(File.join(dir, "Gemfile.lock"), "GEM\n  specs:\n    rails (8.0.1)\n")
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.3\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n")
      FileUtils.mkdir_p(File.join(dir, "app/models"))
      Dir.chdir(dir) do
        system("git init -q")
        system("git config user.email 'test@test.com'")
        system("git config user.name 'Test'")
        system("git add . && git commit -qm init")
        base = `git rev-parse HEAD`.strip
        File.write(File.join(dir, "app/models/user.rb"), "class User; end")
        system("git add app/models/user.rb && git commit -qm change")
        config = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
        git_ctx = RailVerdict::Git::Context.build(repository_root: dir, base_override: base, configuration: config, runner: RailVerdict::ProcessRunner)
        rails_ctx = RailVerdict::RailsContext::Context.build(repository_root: dir, git_context: git_ctx)
        assert rails_ctx.unresolved.any? { |entry| entry["source_path"] == "db/structure.sql" }
      end
    end
  end

  def test_check_json_includes_rails_context
    Dir.mktmpdir do |dir|
      cp_fixture(File.expand_path("fixtures/rails_phase05/conventional_app", __dir__), dir)
      Dir.chdir(dir) do
        system("git init -q")
        system("git config user.email 'test@test.com'")
        system("git config user.name 'Test'")
        system("git add . && git commit -qm init")
        base = `git rev-parse HEAD`.strip
        File.write(File.join(dir, "app/models/user.rb"), "# frozen_string_literal: true\nclass User\n  belongs_to :account\nend\n")
        system("git add app/models/user.rb && git commit -qm change")
        result = RailVerdict::Check.execute(repository_root: dir, config_path: File.join(dir, ".railverdict.yml"), changed: true, base: base)
        h = result.result.to_schema_h
        assert h.key?("rails_context")
        assert_equal "changed", h["rails_context"]["scope"]
        errors = RailVerdict::SchemaValidator.validate_result(h)
        assert_empty errors, errors.join(", ")
      end
    end
  end

  def test_symlink_outside_rejected
    Dir.mktmpdir do |dir|
      cp_fixture(File.expand_path("fixtures/rails_phase05/conventional_app", __dir__), dir)
      outside = Dir.mktmpdir
      File.write(File.join(outside, "evil.rb"), "class Evil; end")
      File.symlink(File.join(outside, "evil.rb"), File.join(dir, "app/models/evil_link.rb"))
      Dir.chdir(dir) do
        system("git init -q")
        system("git config user.email 'test@test.com'")
        system("git config user.name 'Test'")
        system("git add . && git commit -qm init")
        base = `git rev-parse HEAD`.strip
        File.write(File.join(dir, "app/models/user.rb"), "# touched\n")
        system("git add app/models/user.rb && git commit -qm change")
        config = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
        git_ctx = RailVerdict::Git::Context.build(repository_root: dir, base_override: base, configuration: config, runner: RailVerdict::ProcessRunner)
        assert git_ctx
        rails_ctx = RailVerdict::RailsContext::Context.build(repository_root: dir, git_context: git_ctx)
        assert rails_ctx
      end
    end
  end
end
