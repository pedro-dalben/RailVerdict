# frozen_string_literal: true

require "fileutils"
require "json"

require_relative "test_helper"

class TestDeterminism < Minitest::Test
  ROOT = RailVerdictTestHelpers::REPOSITORY_ROOT
  CLEAN = File.join(ROOT, "test", "fixtures", "rails_clean")

  def canonical_result(root)
    outcome = RailVerdict::Check.execute(repository_root: root, config_path: ".railverdict.yml")
    RailVerdict::Reporters::JsonReporter.render(outcome.result)
  end

  def test_locale_timezone_and_tempdir_variations_do_not_change_gate_content
    original_locale = ENV["LC_ALL"]
    original_timezone = ENV["TZ"]
    original_tmpdir = ENV["TMPDIR"]
    outputs = []
    with_tmpdir do |first_tmp|
      with_tmpdir do |second_tmp|
        [["C", "UTC", first_tmp], ["C.UTF-8", "America/New_York", second_tmp]].each do |locale, timezone, tempdir|
          ENV["LC_ALL"] = locale
          ENV["TZ"] = timezone
          ENV["TMPDIR"] = tempdir
          outputs << canonical_result(CLEAN)
        end
      end
    end
    assert_equal 1, outputs.uniq.length
  ensure
    ENV["LC_ALL"] = original_locale
    ENV["TZ"] = original_timezone
    ENV["TMPDIR"] = original_tmpdir
  end

  def test_distinct_project_roots_have_identical_canonical_result
    outputs = []
    with_tmpdir do |first_dir|
      with_tmpdir do |second_dir|
        [first_dir, second_dir].each do |destination|
          project = File.join(destination, "project")
          FileUtils.cp_r(CLEAN, project)
          outputs << canonical_result(project)
        end
      end
    end
    assert_equal 1, outputs.uniq.length
  end

  def test_repeated_runs_are_byte_identical
    assert_equal canonical_result(CLEAN), canonical_result(CLEAN)
  end

  def test_result_maps_are_emitted_in_contract_order
    parsed = JSON.parse(canonical_result(CLEAN))
    expected = %w[schema_version completion_status gate policy_status findings analyzer_results operational_failures decision_reasons]
    assert_equal expected, parsed.keys.first(expected.length)
  end
end
