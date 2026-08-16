# frozen_string_literal: true

require "open3"

require_relative "test_helper"

class TestRunContext < Minitest::Test
  def build_configuration(dir, mode: "strict")
    path = File.join(dir, ".railverdict.yml")
    File.write(path, <<~YAML)
      version: 1
      mode: #{mode}
      analyzers:
        rubocop:
          enabled: true
          required: true
    YAML
    RailVerdict::Configuration.load(path)
  end

  def test_context_is_deeply_immutable
    with_tmpdir do |dir|
      config = build_configuration(dir)
      context = RailVerdict::RunContext.build(
        repository_root: dir,
        configuration: config,
        analyzer_versions: { "rubocop" => "1.88.0" },
        revision_resolver: ->(_root) { "abc123" }
      )

      assert context.frozen?
      assert context.analyzers.frozen?
      assert context.analyzer_versions.frozen?
      assert context.deterministic_inputs.frozen?
      assert_raises(FrozenError) { context.analyzer_versions["rubocop"] = "9.9.9" }
      assert_raises(FrozenError) { context.deterministic_inputs["locale"] = "changed" }
      refute_respond_to context, :revision=
    end
  end

  def test_records_required_deterministic_inputs
    with_tmpdir do |dir|
      config = build_configuration(dir)
      context = RailVerdict::RunContext.build(
        repository_root: dir,
        configuration: config,
        analyzer_versions: { "rubocop" => "1.88.0" },
        revision_resolver: ->(_root) { "deadbeef" }
      )

      assert_equal File.realpath(dir), context.repository_root
      assert_equal "deadbeef", context.revision
      assert_equal RUBY_VERSION, context.ruby_version
      assert_equal "strict", context.configuration_mode
      assert_equal config.digest, context.configuration_digest
      assert_equal({ "rubocop" => { "enabled" => true, "required" => true } }, context.analyzers)
      assert_equal({ "rubocop" => "1.88.0" }, context.analyzer_versions)
      assert_equal "C.UTF-8", context.deterministic_inputs.fetch("locale")
      assert_equal "UTC", context.deterministic_inputs.fetch("timezone")
      assert_equal "canonical-v1", context.deterministic_inputs.fetch("ordering")
    end
  end

  def test_revision_is_nil_without_resolver_or_repository
    with_tmpdir do |dir|
      config = build_configuration(dir)
      context = RailVerdict::RunContext.build(
        repository_root: dir,
        configuration: config,
        analyzer_versions: {}
      )
      assert_nil context.revision
    end
  end

  def test_revision_resolver_receives_realpath_root
    with_tmpdir do |dir|
      config = build_configuration(dir)
      seen = nil
      RailVerdict::RunContext.build(
        repository_root: dir,
        configuration: config,
        analyzer_versions: {},
        revision_resolver: ->(root) { seen = root; nil }
      )
      assert_equal File.realpath(dir), seen
    end
  end

  def test_rails_and_ruby_versions_parsed_from_lockfile
    with_tmpdir do |dir|
      File.write(File.join(dir, "Gemfile.lock"), <<~LOCKFILE)
        GEM
          remote: https://rubygems.org/
          specs:
            rails (8.1.3)
              activesupport (= 8.1.3)

        PLATFORMS
          x86_64-linux

        RUBY VERSION
           ruby 3.4.5p51
      LOCKFILE

      config = build_configuration(dir)
      context = RailVerdict::RunContext.build(
        repository_root: dir,
        configuration: config,
        analyzer_versions: {}
      )
      assert_equal "8.1.3", context.rails_version
      assert_equal "3.4.5", context.target_ruby_version
    end
  end

  def test_absent_lockfile_degrades_to_nil_versions
    with_tmpdir do |dir|
      config = build_configuration(dir)
      context = RailVerdict::RunContext.build(
        repository_root: dir,
        configuration: config,
        analyzer_versions: {}
      )
      assert_nil context.rails_version
      assert_nil context.target_ruby_version
    end
  end

  def test_missing_repository_root_raises
    config_error = assert_raises(RailVerdict::Error) do
      RailVerdict::RunContext.build(
        repository_root: "/nonexistent/railverdict/path",
        configuration: nil,
        analyzer_versions: {}
      )
    end
    assert_includes config_error.message, "does not exist"
  end
end
