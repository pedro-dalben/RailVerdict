# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "json"
require "rbconfig"

class TestRailsDogfood < Minitest::Test
  SYNTH_APP = {
    ".railverdict.yml" => <<~YML,
      version: 1.4
      mode: strict
      analyzers:
        rubocop: { enabled: false, required: false }
        minitest: { enabled: true, required: true }
        rspec: { enabled: false, required: false }
        simplecov: { enabled: false, required: false }
        bundler_audit: { enabled: false, required: false }
    YML
    "app/models/order.rb" => "class Order; belongs_to :user; has_many :items; end\n",
    "app/controllers/orders_controller.rb" => "class OrdersController; end\n",
    "config/routes.rb" => "Rails.application.routes.draw do\n  resources :orders\nend\n",
    "db/schema.rb" => "ActiveRecord::Schema.define do\n  create_table \"orders\" do |t|\n    t.string \"name\"\n  end\nend\n",
    "test/models/order_test.rb" => "require \"minitest/autorun\"\nclass OrderTest < Minitest::Test\n  def test_dummy; assert true; end\nend\n",
    "test/test_helper.rb" => "require \"minitest/autorun\"\n",
    ".gitignore" => ""
  }.freeze

  def write_synth_app(dir)
    SYNTH_APP.each do |rel, content|
      path = File.join(dir, rel)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
  end

  def minitest_stub_for(dir, failures: false)
    name = failures ? "stub_minitest_fail.rb" : "stub_minitest_pass.rb"
    stub = File.join(dir, name)
    payload = if failures
                {
                  "schema_version" => "1.0", "runner" => "minitest 6.0.6", "seed" => 1,
                  "tests_total" => 1, "assertions" => 1, "failures" => 1, "errors" => 0, "skips" => 0, "duration_seconds" => 0.01,
                  "tests" => [{ "class_name" => "OrderTest", "method_name" => "test_fails", "status" => "failed", "time_seconds" => 0.01, "file" => "test/models/order_test.rb", "line" => 4, "failure_message" => "Expected true to be false", "failure_class" => "Minitest::Assertion" }]
                }
              else
                {
                  "schema_version" => "1.0", "runner" => "minitest 6.0.6", "seed" => 1,
                  "tests_total" => 1, "assertions" => 1, "failures" => 0, "errors" => 0, "skips" => 0, "duration_seconds" => 0.01,
                  "tests" => [{ "class_name" => "OrderTest", "method_name" => "test_dummy", "status" => "passed", "time_seconds" => 0.01, "file" => "test/models/order_test.rb", "line" => 3 }]
                }
              end
    File.write(stub, "require \"json\"; if ARGV.include?(\"--version\"); puts \"6.0.6\"; else; puts JSON.generate(#{payload.inspect}); end\n")
    stub
  end

  def test_synthetic_rails_app_check_pass_with_minitest_stub
    Dir.mktmpdir("rv-dogfood-") do |dir|
      dir = File.realpath(dir)
      write_synth_app(dir)
      stub = minitest_stub_for(dir, failures: false)
      adapter = RailVerdict::Analyzers::Minitest.new(command_resolver: ->(_r) { { executable: RbConfig.ruby, args_prefix: [stub] } })
      result, findings = adapter.run(dir)
      assert_equal "succeeded", result.execution_status
      assert_empty findings
      assert_equal 1, result.evidence_summary.fetch("tests_total")
    end
  end

  def test_synthetic_rails_app_minitest_fail_then_pass_is_deterministic
    Dir.mktmpdir("rv-dogfood-") do |dir|
      dir = File.realpath(dir)
      write_synth_app(dir)
      stub_fail = minitest_stub_for(dir, failures: true)
      stub_pass = minitest_stub_for(dir, failures: false)

      adapter_fail = RailVerdict::Analyzers::Minitest.new(command_resolver: ->(_r) { { executable: RbConfig.ruby, args_prefix: [stub_fail] } })
      adapter_pass = RailVerdict::Analyzers::Minitest.new(command_resolver: ->(_r) { { executable: RbConfig.ruby, args_prefix: [stub_pass] } })

      result_fail, findings_fail = adapter_fail.run(dir)
      result_pass, findings_pass = adapter_pass.run(dir)

      assert_equal "succeeded", result_fail.execution_status
      assert_equal 1, findings_fail.length
      assert_equal "succeeded", result_pass.execution_status
      assert_empty findings_pass

      # Strict mode: fail should be FAIL/incomplete boundary, pass should be PASS — tested at policy layer
      File.write(File.join(dir, ".railverdict.yml"), <<~YML)
        version: 1.1
        mode: strict
        analyzers:
          rubocop: { enabled: false, required: false }
          minitest: { enabled: true, required: true }
      YML
      config = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      gate_fail = RailVerdict::Verification::Policy.evaluate(configuration: config, analyzer_results: [result_fail], findings: findings_fail)
      gate_pass = RailVerdict::Verification::Policy.evaluate(configuration: config, analyzer_results: [result_pass], findings: findings_pass)
      assert_equal "FAIL", gate_fail.gate
      assert_equal "PASS", gate_pass.gate
    end
  end

  def test_synthetic_rails_app_rails_context_is_bounded_and_offline
    Dir.mktmpdir("rv-dogfood-") do |dir|
      dir = File.realpath(dir)
      write_synth_app(dir)
      ctx = RailVerdict::RailsContext::Context.build(repository_root: dir, git_context: nil)
      h = ctx.to_h
      assert h.is_a?(Hash)
      assert h["detected"].is_a?(Hash) || h[:detected].is_a?(Hash)
    end
  end

  def test_rspec_stub_check_is_offline_and_deterministic
    Dir.mktmpdir("rv-rspec-") do |dir|
      dir = File.realpath(dir)
      File.write(File.join(dir, ".railverdict.yml"), <<~YML)
        version: 1.1
        mode: strict
        analyzers:
          rubocop: { enabled: false, required: false }
          minitest: { enabled: false, required: false }
          rspec: { enabled: true, required: true }
      YML
      stub = File.join(dir, "stub_rspec.rb")
      payload = {
        "version" => "3.13.6",
        "examples" => [
          { "id" => "./spec/order_spec.rb[1:1]", "description" => "orders list", "full_description" => "orders list", "status" => "passed", "file_path" => "./spec/order_spec.rb", "line_number" => 3, "run_time" => 0.01 },
          { "id" => "./spec/order_spec.rb[1:2]", "description" => "fails", "full_description" => "fails", "status" => "failed", "file_path" => "./spec/order_spec.rb", "line_number" => 10, "run_time" => 0.01, "exception" => { "class" => "RSpec::Expectations::ExpectationNotMetError", "message" => "expected true", "backtrace" => ["./spec/order_spec.rb:11"] } }
        ],
        "summary" => { "duration" => 0.02, "example_count" => 2, "failure_count" => 1, "pending_count" => 0 },
        "summary_line" => "2 examples, 1 failure"
      }
      File.write(stub, "require \"json\"; if ARGV.include?(\"--version\"); puts \"3.13.6\"; else; puts JSON.generate(#{payload.inspect}); end\n")
      adapter = RailVerdict::Analyzers::RSpec.new(command_resolver: ->(_r) { { executable: RbConfig.ruby, args_prefix: [stub] } })
      result, findings = adapter.run(dir)
      assert_equal "succeeded", result.execution_status
      assert_equal 1, findings.length
      assert_empty RailVerdict::SchemaValidator.validate_finding(findings.first.to_schema_h)
    end
  end

  def test_offline_no_network_dependency
    Dir.mktmpdir("rv-offline-") do |dir|
      dir = File.realpath(dir)
      write_synth_app(dir)
      # Run with all stubs — no network call should occur
      stub = minitest_stub_for(dir, failures: false)
      adapter = RailVerdict::Analyzers::Minitest.new(command_resolver: ->(_r) { { executable: RbConfig.ruby, args_prefix: [stub] } })
      result, findings = adapter.run(dir)
      assert_equal "succeeded", result.execution_status
      # Verify no HTTP was attempted — if it were, it would timeout or fail in offline test env
      assert result.tool_version
    end
  end
end
