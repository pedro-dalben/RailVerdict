# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "fileutils"

class TestLegacyE2E < Minitest::Test
  LEGACY = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test/fixtures/legacy_app")

  def test_legacy_baseline_create_and_classification
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(LEGACY, project)

      exit_code, stdout, = run_cli(["baseline", "create"], working_directory: project)
      assert_equal 0, exit_code
      assert_includes stdout, "Baseline created"
      baseline_path = File.join(project, ".railverdict-baseline.json")
      assert File.file?(baseline_path)
      baseline = JSON.parse(File.read(baseline_path))
      assert_equal 3, baseline.fetch("entries").length

      FileUtils.rm_f(File.join(project, "app/models/legacy_three.rb"))
      File.write(File.join(project, "app/models/legacy_new.rb"), "# frozen_string_literal: true\n\nclass LegacyNew\n  def label\n    'single quoted new'\n  end\nend\n")
      exit_code, stdout, = run_cli(["check"], working_directory: project)
      assert_equal 1, exit_code
      assert_includes stdout, "Introduced:"
      assert_includes stdout, "Existing:"

      exit_code, stdout, = run_cli(["check", "--format", "json"], working_directory: project)
      assert_equal 1, exit_code
      result = JSON.parse(stdout)
      comparison = result.fetch("comparison")
      counts = comparison.fetch("counts")
      assert_equal 2, counts.fetch("existing")
      assert_equal 1, counts.fetch("moved") + counts.fetch("introduced")
      assert_equal "FAIL", result.fetch("gate")
    end
  end

  def test_advisory_no_new_debt_strict_modes
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(LEGACY, project)
      run_cli(["baseline", "create"], working_directory: project)
      FileUtils.rm_f(File.join(project, "app/models/legacy_three.rb"))
      File.write(File.join(project, "app/models/legacy_new.rb"), "# frozen_string_literal: true\n\nclass LegacyNew\n  def label\n    'single quoted new'\n  end\nend\n")

      File.write(File.join(project, ".railverdict.yml"), "version: 1.2\nmode: advisory\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      exit_code, stdout, = run_cli(["check"], working_directory: project)
      assert_equal 0, exit_code
      assert_includes stdout, "WARN"

      File.write(File.join(project, ".railverdict.yml"), "version: 1.2\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      exit_code, _, = run_cli(["check"], working_directory: project)
      assert_equal 1, exit_code

      File.write(File.join(project, ".railverdict.yml"), "version: 1.2\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      exit_code, _, = run_cli(["check"], working_directory: project)
      assert_equal 1, exit_code
    end
  end

  def test_waiver_e2e_active_and_expired
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(LEGACY, project)
      run_cli(["baseline", "create"], working_directory: project)

      FileUtils.rm_f(File.join(project, "app/models/legacy_three.rb"))
      File.write(File.join(project, "app/models/legacy_new.rb"), "# frozen_string_literal: true\n\nclass LegacyNew\n  def label\n    'single quoted new'\n  end\nend\n")

      outcome = RailVerdict::Check.execute(repository_root: project, config_path: ".railverdict.yml")
      introduced = outcome.findings.find { |finding| finding.location["path"] == "app/models/legacy_new.rb" }
      raise "no introduced finding" unless introduced

      waiver_path = File.join(project, ".railverdict-waivers.json")
      File.write(waiver_path, JSON.generate({
        "schema_version" => "1.0",
        "waivers" => [{
          "fingerprint" => introduced.fingerprint,
          "reason" => "accepted",
          "owner" => "team",
          "created_at" => "2026-08-17T12:00:00Z",
          "expires_at" => "2026-08-18T12:00:00Z"
        }]
      }))
      outcome_active = RailVerdict::Check.execute(repository_root: project, config_path: ".railverdict.yml", clock: Time.utc(2026, 8, 17, 13, 0, 0))
      assert_equal "PASS", outcome_active.result.gate

      outcome_expired = RailVerdict::Check.execute(repository_root: project, config_path: ".railverdict.yml", clock: Time.utc(2026, 8, 18, 13, 0, 0))
      assert_equal "FAIL", outcome_expired.result.gate
    end
  end
end
