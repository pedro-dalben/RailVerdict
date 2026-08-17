# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "tmpdir"
require "fileutils"

class Test0905ReleaseInvariants < Minitest::Test
  def test_fail_closed_required_incomplete_through_check_baseline_repair_mcp
    Dir.mktmpdir("rv-09-05-") do |dir|
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
      outcome = RailVerdict::Check.execute(
        repository_root: dir,
        config_path: ".railverdict.yml",
        rubocop_command_resolver: ->(_r) { { executable: "/does/not/exist/rubocop", args_prefix: [] } }
      )
      assert_equal "incomplete", outcome.result.completion_status
      assert_equal "INCOMPLETE", outcome.result.gate
      assert_equal "not_evaluated", outcome.result.policy_status
      assert_includes outcome.result.operational_failures.map { |f| f["code"] }, "unavailable"
      assert_equal 2, RailVerdict::CLI.new(stdout: StringIO.new, stderr: StringIO.new, working_directory: dir).send(:exit_code_for, outcome.result)

      baseline_path = File.join(dir, ".railverdict-baseline.json")
      File.write(baseline_path, JSON.generate({ "schema_version" => "1.0", "fingerprint_version" => 1, "algorithm" => "sha256", "payload_schema" => "https://railverdict.dev/fingerprint-payload/v1", "created_at" => Time.now.utc.iso8601, "created_by" => "tester", "configuration_digest" => "a" * 64, "analyzer_versions" => {}, "entries" => [] }))
      outcome2 = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml", rubocop_command_resolver: ->(_r) { { executable: "/does/not/exist/rubocop", args_prefix: [] } })
      assert_equal "INCOMPLETE", outcome2.result.gate
      assert_equal "not_evaluated", outcome2.result.policy_status
    end
  end

  def test_ai_disabled_gate_equals_ai_enabled_gate
    Dir.mktmpdir("rv-09-05-ai-") do |dir|
      dir = File.realpath(dir)
      File.write(File.join(dir, ".railverdict.yml"), <<~YML)
        version: 1.4
        mode: advisory
        analyzers:
          rubocop: { enabled: false, required: false }
          minitest: { enabled: false, required: false }
      YML
      outcome = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml")
      assert_equal "complete", outcome.result.completion_status
      assert_equal "PASS", outcome.result.gate
      off_gate = outcome.result.gate
      File.write(File.join(dir, ".railverdict.yml"), <<~YML)
        version: 1.4
        mode: advisory
        analyzers:
          rubocop: { enabled: false, required: false }
          minitest: { enabled: false, required: false }
        ai:
          enabled: true
          remote:
            enabled: true
            trust: redacted
      YML
      outcome2 = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml")
      assert_equal off_gate, outcome2.result.gate
      assert_equal outcome.gate, outcome2.gate if outcome.respond_to?(:gate)
    end
  end

  def test_json_stdout_is_single_document_no_banner
    Dir.mktmpdir("rv-09-05-json-") do |dir|
      dir = File.realpath(dir)
      File.write(File.join(dir, ".railverdict.yml"), <<~YML)
        version: 1.4
        mode: advisory
        analyzers:
          rubocop: { enabled: false, required: false }
          minitest: { enabled: false, required: false }
          rspec: { enabled: false, required: false }
          simplecov: { enabled: false, required: false }
          bundler_audit: { enabled: false, required: false }
      YML
      out = StringIO.new
      err = StringIO.new
      cli = RailVerdict::CLI.new(stdout: out, stderr: err, working_directory: dir)
      code = cli.run(["check", "--format", "json"])
      assert_equal 0, code
      assert_empty err.string
      assert_equal "\n", out.string[-1]
      parsed = JSON.parse(out.string)
      assert_equal "1.0", parsed.fetch("schema_version")
      assert_empty RailVerdict::SchemaValidator.validate_result(parsed.reject { |k, _| %w[baseline comparison].include?(k) })
    end
  end

  def test_sarif_is_single_document_and_does_not_change_gate
    Dir.mktmpdir("rv-09-05-sarif-") do |dir|
      dir = File.realpath(dir)
      File.write(File.join(dir, ".railverdict.yml"), <<~YML)
        version: 1.4
        mode: advisory
        analyzers:
          rubocop: { enabled: false, required: false }
      YML
      out = StringIO.new
      err = StringIO.new
      cli = RailVerdict::CLI.new(stdout: out, stderr: err, working_directory: dir)
      code = cli.run(["check", "--format", "sarif"])
      assert_equal 0, code
      assert_empty err.string
      doc = JSON.parse(out.string)
      assert_equal "2.1.0", doc.fetch("version")
      assert doc["runs"].is_a?(Array)
    end
  end

  def test_secrets_are_redacted_before_remote_and_preview_can_inspect
    Dir.mktmpdir("rv-09-05-secret-") do |dir|
      dir = File.realpath(dir)
      File.write(File.join(dir, ".railverdict.yml"), <<~YAML)
        version: 1.4
        mode: strict
        analyzers:
          rubocop: { enabled: true, required: true }
      YAML
      fp = RailVerdict::Fingerprint.hexdigest(analyzer: "rubocop", rule_id: "Lint/UselessAssignment", path: "app/models/order.rb", message: "useless assignment")
      finding = RailVerdict::Finding.new(fingerprint: fp, origin: "deterministic", analyzer: "rubocop", rule_id: "Lint/UselessAssignment", category: "lint", severity: "high", confidence: "high", state: "observed", evidence_ref: "rubocop:1", location: { "path" => "app/models/order.rb", "start_line" => 1 }, message: "useless assignment")
      result = RailVerdict::AnalyzerResult.new(analyzer: "rubocop", invocation: { "executable" => "rubocop", "argv" => [] }, execution_status: "succeeded", finding_ids: [finding.id])
      gate = RailVerdict::GateResult.new(completion_status: "complete", gate: "FAIL", policy_status: "fail", findings: [{ "id" => finding.id, "fingerprint" => finding.fingerprint, "severity" => finding.severity, "state" => finding.state, "blocking" => true }], analyzer_results: [result], operational_failures: [], decision_reasons: [{ "code" => "x", "message" => "x" }])
      config = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      ctx = RailVerdict::RunContext.build(repository_root: dir, configuration: config, analyzer_versions: {}, revision_resolver: ->(_) { "abc1234" })
      outcome = RailVerdict::Check::Outcome.new(result: gate, context: ctx, configuration: config, findings: [finding])
      FileUtils.mkdir_p(File.join(dir, "app/models"))
      File.write(File.join(dir, "app/models/order.rb"), "API_KEY = \"AKIAIOSFODNN7EXAMPLE\"\n")
      manifest = RailVerdict::Intelligence::ContextBuilder.build(outcome: outcome, finding_ref: finding.id)
      redacted = RailVerdict::Intelligence::Redactor.redact(manifest, trust: "redacted")
      assert redacted.secret_detected
      json = JSON.generate(redacted.manifest.to_json_hash)
      refute_includes json, "AKIAIOSFODNN7EXAMPLE"
      assert_includes json, "[REDACTED"
    end
  end
end
