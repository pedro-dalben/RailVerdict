# frozen_string_literal: true

require "json"
require "tmpdir"
require "fileutils"
require "rbconfig"
require "open3"

require_relative "test_helper"

class TestMinitestRealIntegration < Minitest::Test
  GEM_NAME = "rail_verdict"
  REPORTER_RELATIVE = "exe/railverdict-minitest-reporter.rb"

  def installed_gem_reporter
    repo_reporter = File.expand_path("../#{REPORTER_RELATIVE}", __dir__)
    direct = File.join(`gem env gemdir 2>/dev/null`.strip, "gems", "#{GEM_NAME}-#{RailVerdict::VERSION}", REPORTER_RELATIVE)
    if File.file?(direct)
      real_direct = File.realpath(direct) rescue File.expand_path(direct)
      repo_real = File.realpath(repo_reporter) rescue File.expand_path(repo_reporter)
      return real_direct unless real_direct == repo_real
    end
    candidates = Gem::Specification.find_all_by_name(GEM_NAME)
    gem_candidates = candidates.reject { |spec| File.expand_path(spec.full_gem_path) == File.expand_path(RailVerdictTestHelpers::REPOSITORY_ROOT) }
    if gem_candidates.any?
      spec = gem_candidates.max_by(&:version)
      path = File.join(spec.full_gem_path, REPORTER_RELATIVE)
      if File.file?(path)
        real = File.realpath(path) rescue File.expand_path(path)
        repo_real = File.realpath(repo_reporter) rescue File.expand_path(repo_reporter)
        return real unless real == repo_real
      end
    end
    if candidates.empty?
      skip "installed gem #{GEM_NAME} not found — run `gem install rail_verdict-*.gem` (current gemdir: #{`gem env gemdir 2>/dev/null`.strip})"
    end
    skip "installed gem #{GEM_NAME} resolved to repository path under Bundler — run real proof outside Bundler: ruby -I test -I lib test/test_minitest_real_integration.rb"
  end

  def run_real_minitest(reporter_path, dir, class_name, body, extra_env: {})
    output = File.join(dir, "#{class_name.downcase}.json")
    run_file = File.join(dir, "run_#{class_name.downcase}.rb")
    File.write(run_file, <<~RUBY)
      ENV["RAILVERDICT_MINITEST_OUTPUT"] = #{output.inspect}
      require #{reporter_path.inspect}
      require "minitest/autorun"
      #{body}
    RUBY
    env = {}
    extra_env.each { |k, v| env[k] = v }
    _out, err, status = Open3.capture3(env, RbConfig.ruby, run_file)
    [output, run_file, status, err]
  end

  def adapter_result_for_reporter_json(dir, output_path)
    runner_script = File.join(dir, "adapter_runner_#{File.basename(output_path, '.json')}.rb")
    File.write(runner_script, <<~RUBY)
      gem #{GEM_NAME.inspect}
      require "rail_verdict"
      require "json"
      output = #{output_path.inspect}
      dir = #{dir.inspect}
      stub = File.join(dir, "stub_\#{File.basename(output, '.json')}.rb")
      File.write(stub, "require 'json'; if ARGV.include?('--version'); puts '6.0.6'; else; puts File.read(\#{output.inspect}); end\\n")
      adapter = RailVerdict::Analyzers::Minitest.new(command_resolver: ->(_r) { { executable: RbConfig.ruby, args_prefix: [stub] } })
      result, findings = adapter.run(dir)
      payload = {
        "execution_status" => result.execution_status,
        "evidence_status" => result.evidence_status,
        "tool_version" => result.tool_version,
        "evidence_summary" => result.evidence_summary,
        "findings" => findings.map(&:to_schema_h),
        "finding_ids" => result.finding_ids
      }
      puts JSON.generate(payload)
    RUBY
    out, err, status = Open3.capture3(RbConfig.ruby, runner_script)
    assert status.success?, "adapter runner must succeed: #{err[0, 500]} status=#{status.exitstatus} out=#{out[0, 500]}"
    JSON.parse(out)
  end

  def policy_via_gem(dir, adapter_payload, config_content)
    runner = File.join(dir, "policy_runner_#{SecureRandom.hex(4)}.rb")
    config_path = File.join(dir, ".railverdict.yml")
    File.write(config_path, config_content)
    payload_path = File.join(dir, "adapter_payload.json")
    File.write(payload_path, JSON.generate(adapter_payload))
    File.write(runner, <<~RUBY)
      gem #{GEM_NAME.inspect}
      require "rail_verdict"
      require "json"
      payload = JSON.parse(File.read(#{payload_path.inspect}))
      config = RailVerdict::Configuration.load(#{config_path.inspect})
      findings = payload["findings"].map do |h|
        RailVerdict::Finding.new(
          fingerprint: h["fingerprint"],
          origin: h["origin"],
          analyzer: h["analyzer"],
          rule_id: h["rule_id"],
          category: h["category"],
          severity: h["severity"],
          confidence: h["confidence"],
          state: h["state"],
          evidence_ref: h["evidence_ref"],
          location: h["location"],
          message: h["message"]
        )
      end
      result = RailVerdict::Verification::Policy.evaluate(
        configuration: config,
        analyzer_results: [RailVerdict::AnalyzerResult.new(
          analyzer: "minitest",
          tool_version: payload["tool_version"],
          invocation: { "executable" => "ruby", "argv" => ["run"] },
          execution_status: payload["execution_status"],
          finding_ids: payload["finding_ids"],
          evidence_summary: payload["evidence_summary"] || {}
        )],
        findings: findings
      )
      puts JSON.generate({ "gate" => result.gate, "completion_status" => result.completion_status, "operational_failures" => result.operational_failures, "policy_status" => result.policy_status })
    RUBY
    out, err, status = Open3.capture3(RbConfig.ruby, runner)
    assert status.success?, "policy runner must succeed: #{err[0, 500]}"
    JSON.parse(out)
  end

  def validate_reporter_schema(document)
    schema_path = File.expand_path("../schemas/minitest-reporter-v1.schema.json", __dir__)
    schema = JSON.parse(File.read(schema_path))
    errors = JSONSchemer.schema(schema).validate(document).to_a
    assert_empty errors, "reporter document must validate against minitest-reporter-v1.schema.json: #{errors.map(&:to_h).inspect}"
  end

  def test_reporter_comes_from_installed_gem
    path = installed_gem_reporter
    assert_match %r{/gems/rail_verdict-}, path
  end

  def test_green_suite_via_installed_gem_reporter_and_adapter_and_policy
    reporter = installed_gem_reporter
    Dir.mktmpdir("rv-minitest-green-") do |dir|
      dir = File.realpath(dir)
      output, _run_file, status, err = run_real_minitest(
        reporter, dir, "GreenSuite",
        <<~RUBY
          class GreenSuiteTest < Minitest::Test
            def test_pass_one
              assert_equal 4, 2 + 2
            end
            def test_pass_two
              assert true, "should pass"
            end
          end
        RUBY
      )
      assert File.file?(output), "green reporter must write #{output}: status=#{status.exitstatus} err=#{err[0, 400]}"
      document = JSON.parse(File.read(output))
      validate_reporter_schema(document)
      assert_equal "1.0", document.fetch("schema_version")
      assert_match(/\Aminitest \d+\.\d+\.\d+\z/, document.fetch("runner"))
      assert_operator document.fetch("tests_total"), :>, 0
      assert_equal 0, document.fetch("failures")
      assert_equal 0, document.fetch("errors")

      payload = adapter_result_for_reporter_json(dir, output)
      assert_equal "succeeded", payload.fetch("execution_status")
      assert_equal "complete", payload.fetch("evidence_status")
      assert_operator payload.fetch("evidence_summary").fetch("tests_total"), :>, 0
      assert_empty payload.fetch("findings"), "green suite must produce no findings"

      gate = policy_via_gem(dir, payload, <<~YML)
        version: 1.4
        mode: strict
        analyzers:
          rubocop: { enabled: false, required: false }
          minitest: { enabled: true, required: true }
      YML
      assert_equal "complete", gate.fetch("completion_status")
      assert_equal "PASS", gate.fetch("gate")
    end
  end

  def test_failing_suite_produces_normalized_finding_with_location_and_deterministic_policy
    reporter = installed_gem_reporter
    Dir.mktmpdir("rv-minitest-fail-") do |dir|
      dir = File.realpath(dir)
      output, run_file, status, err = run_real_minitest(
        reporter, dir, "FailSuite",
        <<~RUBY
          class FailSuiteTest < Minitest::Test
            def test_fails_here
              assert_equal 1, 2, "math is broken"
            end
            def test_also_passes
              assert true
            end
          end
        RUBY
      )
      assert File.file?(output), "fail reporter must write #{output}: status=#{status.exitstatus} err=#{err[0, 400]}"
      document = JSON.parse(File.read(output))
      validate_reporter_schema(document)
      assert_equal 2, document.fetch("tests_total")
      assert_equal 1, document.fetch("failures")
      failed = document.fetch("tests").select { |t| t["status"] == "failed" }
      assert_equal 1, failed.length
      assert_equal "FailSuiteTest", failed.first.fetch("class_name")
      assert_equal "test_fails_here", failed.first.fetch("method_name")
      assert failed.first.key?("failure_message")
      assert failed.first.key?("file")
      assert failed.first.key?("line")
      assert_equal run_file, failed.first.fetch("file")

      payload = adapter_result_for_reporter_json(dir, output)
      assert_equal "succeeded", payload.fetch("execution_status")
      assert_equal 1, payload.fetch("findings").length
      finding = payload.fetch("findings").first
      assert_equal "minitest", finding.fetch("analyzer")
      assert_equal "deterministic", finding.fetch("origin")
      assert_match %r{\Aminitest/test:FailSuiteTest#test_fails_here\z}, finding.fetch("rule_id")
      assert finding.fetch("location").key?("path")
      assert finding.fetch("location").key?("start_line")
      assert_equal run_file.delete_prefix("./"), finding.fetch("location").fetch("path") if finding.fetch("location").fetch("path").start_with?("/")
      assert_empty RailVerdict::SchemaValidator.validate_finding(finding)

      gate1 = policy_via_gem(dir, payload, <<~YML)
        version: 1.4
        mode: strict
        analyzers:
          rubocop: { enabled: false, required: false }
          minitest: { enabled: true, required: true }
      YML
      assert_equal "FAIL", gate1.fetch("gate")
      assert_equal "complete", gate1.fetch("completion_status")

      gate2 = policy_via_gem(dir, payload, <<~YML)
        version: 1.4
        mode: strict
        analyzers:
          rubocop: { enabled: false, required: false }
          minitest: { enabled: true, required: true }
      YML
      assert_equal gate1, gate2, "policy must be deterministic"
    end
  end

  def test_zero_test_suite_is_visible_and_required_incomplete_cannot_pass
    reporter = installed_gem_reporter
    Dir.mktmpdir("rv-minitest-zero-") do |dir|
      dir = File.realpath(dir)
      output, _run_file, _status, err = run_real_minitest(
        reporter, dir, "ZeroSuite",
        <<~RUBY
          class ZeroSuiteTest < Minitest::Test
          end
        RUBY
      )
      assert File.file?(output), "zero reporter must write #{output}: err=#{err[0, 400]}"
      document = JSON.parse(File.read(output))
      validate_reporter_schema(document)
      assert_equal 0, document.fetch("tests_total")
      assert_empty document.fetch("tests")

      payload = adapter_result_for_reporter_json(dir, output)
      assert_equal "succeeded", payload.fetch("execution_status")
      assert_equal 0, payload.fetch("evidence_summary").fetch("tests_total")
      assert_empty payload.fetch("findings")

      required_gate = policy_via_gem(dir, payload, <<~YML)
        version: 1.4
        mode: strict
        analyzers:
          rubocop: { enabled: false, required: false }
          minitest: { enabled: true, required: true }
      YML
      assert_equal "incomplete", required_gate.fetch("completion_status")
      assert_equal "INCOMPLETE", required_gate.fetch("gate")
      assert_equal "not_evaluated", required_gate.fetch("policy_status")
      assert_includes required_gate.fetch("operational_failures").map { |f| f["code"] }, "incomplete_evidence"

      optional_gate = policy_via_gem(dir, payload, <<~YML)
        version: 1.4
        mode: strict
        analyzers:
          rubocop: { enabled: false, required: false }
          minitest: { enabled: true, required: false }
      YML
      assert_equal "complete", optional_gate.fetch("completion_status")
      refute_equal "INCOMPLETE", optional_gate.fetch("gate")
    end
  end

  def test_no_network_during_real_minitest_execution
    reporter = installed_gem_reporter
    Dir.mktmpdir("rv-minitest-offline-") do |dir|
      dir = File.realpath(dir)
      output, _run_file, status, err = run_real_minitest(
        reporter, dir, "OfflineSuite",
        <<~RUBY
          class OfflineSuiteTest < Minitest::Test
            def test_offline; assert true; end
          end
        RUBY
      )
      assert File.file?(output), "offline reporter must write: err=#{err[0, 400]} status=#{status.exitstatus}"
      document = JSON.parse(File.read(output))
      assert_operator document.fetch("tests_total"), :>, 0
    end
  end
end
