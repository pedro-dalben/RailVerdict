# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "shellwords"

class TestFinalAcceptance < Minitest::Test
  def test_positive_path_synthetic_rails_via_installed_gem_style_checks
    Dir.mktmpdir("rv-final-pos-") do |dir|
      dir = File.realpath(dir)
      File.write(File.join(dir, ".railverdict.yml"), <<~YML)
        version: 1.4
        mode: strict
        analyzers:
          rubocop: { enabled: true, required: true }
          minitest: { enabled: false, required: false }
          rspec: { enabled: false, required: false }
          simplecov: { enabled: false, required: false }
          bundler_audit: { enabled: false, required: false }
      YML
      FileUtils.mkdir_p(File.join(dir, "app/models"))
      File.write(File.join(dir, "app/models/order.rb"), "class Order; end\n")
      File.write(File.join(dir, "Gemfile.lock"), "GEM\n  specs:\n    rubocop (1.89.0)\n")

      system("git init -q -b main", chdir: dir)
      system("git config user.email 't@t.com'", chdir: dir)
      system("git config user.name 'T'", chdir: dir)
      system("git add .railverdict.yml app/models/order.rb Gemfile.lock", chdir: dir)
      system("git commit -qm baseline", chdir: dir)

      stubs = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs")
      clean_resolver = ->(_r) { { executable: RbConfig.ruby, args_prefix: [File.join(stubs, "fake_rubocop_clean.rb")] } }
      order_offense_stub = File.join(dir, "stub_order_offense.rb")
      File.write(order_offense_stub, <<~RUBY)
        require "json"
        if ARGV.include?("--version")
          puts "1.88.0"
        else
          puts JSON.generate("files" => [{ "path" => "app/models/order.rb", "offenses" => [{ "cop_name" => "Lint/UselessAssignment", "severity" => "warning", "message" => "Useless assignment to variable - x", "location" => { "start_line" => 1, "last_line" => 1 } }] }])
        end
      RUBY
      offense_resolver = ->(_r) { { executable: RbConfig.ruby, args_prefix: [order_offense_stub] } }

      outcome_init = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml", rubocop_command_resolver: clean_resolver)
      assert_equal "complete", outcome_init.result.completion_status
      assert_equal "PASS", outcome_init.result.gate

      baseline = RailVerdict::Baseline.create(findings: outcome_init.findings, configuration: outcome_init.configuration, analyzer_versions: outcome_init.context.analyzer_versions, clock: Time.now.utc)
      baseline_path = File.join(dir, ".railverdict-baseline.json")
      RailVerdict::Baseline.write(path: baseline_path, baseline: baseline, force: false)
      assert File.file?(baseline_path)

      File.write(File.join(dir, "app/models/order.rb"), "class Order; x = 1; end\n")
      system("git add app/models/order.rb", chdir: dir)
      system("git commit -qm 'introduce offense' 2>/dev/null", chdir: dir)

      base = `git -C #{Shellwords.shellescape(dir)} rev-parse HEAD~1 2>/dev/null`.strip
      outcome_fail = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml", rubocop_command_resolver: offense_resolver, changed: true, base: base)
      assert_equal "complete", outcome_fail.result.completion_status
      assert_equal "FAIL", outcome_fail.result.gate

      finding = outcome_fail.findings.first
      refute_nil finding

      packet = RailVerdict::Repair::ContextAssembler.build(outcome: outcome_fail, finding_ref: finding.id, repository_root: dir)
      assert_match(/\Asha256:[0-9a-f]{64}\z/, packet.packet_id)

      File.write(File.join(dir, "app/models/order.rb"), "class Order; end\n")
      outcome_pass = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml", rubocop_command_resolver: clean_resolver, changed: true, base: base)
      assert_equal "PASS", outcome_pass.result.gate

      verifier = RailVerdict::Repair::Verifier.verify(packet: packet, new_outcome: outcome_pass)
      assert_equal "fixed", verifier.target_status
      assert_equal "PASS", verifier.gate

      schema = JSON.parse(File.read(File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "schemas", "repair-packet-v1.schema.json")))
      errors = JSONSchemer.schema(schema).validate(packet.to_h).to_a
      assert_empty errors
    end
  end

  def test_negative_required_unavailable_stays_incomplete_even_with_baseline_changed_mcp
    Dir.mktmpdir("rv-final-neg-") do |dir|
      dir = File.realpath(dir)
      File.write(File.join(dir, ".railverdict.yml"), <<~YML)
        version: 1.4
        mode: strict
        analyzers:
          rubocop: { enabled: true, required: true }
          minitest: { enabled: false, required: false }
      YML
      stubs = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs")
      missing_resolver = ->(_r) { { executable: "/does/not/exist/rubocop", args_prefix: [] } }

      outcome = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml", rubocop_command_resolver: missing_resolver)
      assert_equal "INCOMPLETE", outcome.result.gate
      assert_equal "not_evaluated", outcome.result.policy_status

      baseline_path = File.join(dir, ".railverdict-baseline.json")
      File.write(baseline_path, JSON.generate({ "schema_version" => "1.0", "fingerprint_version" => 1, "algorithm" => "sha256", "payload_schema" => "https://railverdict.dev/fingerprint-payload/v1", "created_at" => Time.now.utc.iso8601, "created_by" => "t", "configuration_digest" => "a" * 64, "analyzer_versions" => {}, "entries" => [] }))
      outcome2 = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml", rubocop_command_resolver: missing_resolver)
      assert_equal "INCOMPLETE", outcome2.result.gate
      assert_equal 2, RailVerdict::CLI.new(stdout: StringIO.new, stderr: StringIO.new, working_directory: dir).send(:exit_code_for, outcome2.result)
    end
  end

  def test_cli_check_exit_mapping_is_stable
    cli = RailVerdict::CLI.new(stdout: StringIO.new, stderr: StringIO.new)
    pass_result = RailVerdict::Verification::Policy.evaluate(
      configuration: RailVerdict::Configuration.load(File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "rails_clean", ".railverdict.yml")),
      analyzer_results: [],
      findings: []
    )
    pass_result = RailVerdict::GateResult.new(completion_status: "complete", gate: "PASS", policy_status: "pass", findings: [], analyzer_results: [], operational_failures: [], decision_reasons: [])
    assert_equal 0, cli.send(:exit_code_for, pass_result)
    assert_equal 1, cli.send(:exit_code_for, RailVerdict::GateResult.new(completion_status: "complete", gate: "FAIL", policy_status: "fail", findings: [], analyzer_results: [], operational_failures: [], decision_reasons: []))
    assert_equal 2, cli.send(:exit_code_for, RailVerdict::GateResult.new(completion_status: "incomplete", gate: "INCOMPLETE", policy_status: "not_evaluated", findings: [], analyzer_results: [], operational_failures: [{ "code" => "configuration", "message" => "x" }], decision_reasons: []))
    assert_equal 130, cli.send(:exit_code_for, pass_result, interrupted: true)
  end
end
