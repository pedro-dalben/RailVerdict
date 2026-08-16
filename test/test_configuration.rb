# frozen_string_literal: true

require "digest"

require_relative "test_helper"

class TestConfiguration < Minitest::Test
  FIXTURES = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "configurations")

  def fixture(name)
    File.join(FIXTURES, name)
  end

  def load_error(*path)
    error = assert_raises(RailVerdict::ConfigurationError) { RailVerdict::Configuration.load(*path) }
    error
  end

  def test_valid_configuration_loads_effective_values
    config = RailVerdict::Configuration.load(fixture("valid.yml"))
    assert_equal 1, config.version
    assert_equal "no_new_debt", config.mode
    assert_equal true, config.analyzer_enabled?("rubocop")
    assert_equal true, config.analyzer_required?("rubocop")
    assert config.frozen?
    assert config.analyzers.frozen?
    assert config.analyzers.fetch("rubocop").frozen?
  end

  def test_digest_is_stable_sha256_of_raw_bytes
    config = RailVerdict::Configuration.load(fixture("valid.yml"))
    expected = Digest::SHA256.hexdigest(File.binread(fixture("valid.yml")))
    assert_equal expected, config.digest
  end

  def test_optional_disabled_selection_is_valid
    config = RailVerdict::Configuration.load(fixture("valid_optional_disabled.yml"))
    assert_equal false, config.analyzer_enabled?("rubocop")
    assert_equal false, config.analyzer_required?("rubocop")
  end

  def test_missing_file_is_explicit_failure
    error = load_error(File.join(FIXTURES, "absent.yml"))
    assert_includes error.message, "configuration file not found"
    assert_includes error.message, "absent.yml"
    assert_equal File.join(FIXTURES, "absent.yml"), error.source_path
  end

  def test_duplicate_keys_are_rejected_with_path
    error = load_error(fixture("duplicate_key.yml"))
    assert_includes error.message, "duplicate key"
    assert_includes error.message, "$.mode"
  end

  def test_aliases_and_anchors_are_rejected
    error = load_error(fixture("alias_anchor.yml"))
    assert_includes error.message, "anchors are not permitted"
  end

  def test_object_tags_are_rejected
    error = load_error(fixture("object_tag.yml"))
    assert_includes error.message, "explicit YAML tags are not permitted"
  end

  def test_unknown_key_reports_property_path_without_echoing_value
    error = load_error(fixture("unknown_key.yml"))
    assert_includes error.message, "$.analyzers.rubocop.strictness"
    assert_includes error.message, "disallowed additional property"
    refute_includes error.message, "high"
  end

  def test_disabled_required_selection_is_rejected
    error = load_error(fixture("disabled_required.yml"))
    assert_includes error.message, "$.analyzers.rubocop"
  end

  def test_wrong_version_is_rejected_with_path
    error = load_error(fixture("wrong_version.yml"))
    assert_includes error.message, "$.version"
  end

  def test_missing_mode_is_rejected
    error = load_error(fixture("missing_mode.yml"))
    assert_includes error.message, "mode"
  end

  def test_quoted_version_is_rejected
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.write(path, "version: \"1\"\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      error = load_error(path)
      assert_includes error.message, "$.version"
    end
  end

  def test_invalid_utf8_is_rejected
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.binwrite(path, "version: 1\nmode: \xFF\xFE strict\n")
      error = load_error(path)
      assert_includes error.message, "valid UTF-8"
    end
  end

  def test_byte_order_mark_is_rejected
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.binwrite(path, "\xEF\xBB\xBFversion: 1\n")
      error = load_error(path)
      assert_includes error.message, "byte order mark"
    end
  end

  def test_non_mapping_root_is_rejected
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.write(path, "- one\n- two\n")
      error = load_error(path)
      assert_includes error.message, "must be a mapping"
    end
  end

  def test_syntax_error_reports_source_path
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.write(path, "version: 1\n  mode: broken\n")
      error = load_error(path)
      assert_includes error.message, File.basename(path)
      assert_includes error.message, "syntax"
    end
  end

  def test_error_messages_do_not_echo_scalar_values
    error = load_error(fixture("unknown_key.yml"))
    refute_includes error.message, "strictness: high"
  end
end
