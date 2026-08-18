# frozen_string_literal: true

require "json"
require "tmpdir"
require "securerandom"

require_relative "_shared"

module RailVerdict
  module Analyzers
    class Minitest
      ANALYZER_ID = "minitest"
      SUPPORTED_VERSIONS = Gem::Requirement.new(">= 5", "< 7")

      Probe = Struct.new(:status, :version, :message, keyword_init: true)

      class MalformedOutput < StandardError; end

      def initialize(command_resolver: nil)
        @command_resolver = command_resolver || method(:default_command)
      end

      def probe(repository_root, runner: ProcessRunner, timeout_seconds: 15.0)
        command = @command_resolver.call(repository_root)
        probe_argv = probe_argv_for(command, repository_root)
        result = runner.run(
          command.fetch(:executable),
          probe_argv,
          chdir: repository_root,
          timeout_seconds: timeout_seconds
        )

        return Probe.new(status: "unavailable", message: Shared.detail_for(result)) if result.status == :spawn_failed
        return Probe.new(status: "timed_out", message: Shared.detail_for(result)) if result.status == :timed_out
        return Probe.new(status: "signaled", message: Shared.detail_for(result)) if result.status == :signaled
        return Probe.new(status: "truncated", message: Shared.detail_for(result)) if Shared.truncated?(result)
        return Probe.new(status: "unavailable", message: Shared.detail_for(result)) unless result.exit_code == 0

        version = Shared.parse_semver(result.stdout)
        return Probe.new(status: "unsupported", message: "Minitest version could not be parsed") unless version
        return Probe.new(status: "unsupported", version: version, message: "unsupported Minitest version #{version}") unless SUPPORTED_VERSIONS.satisfied_by?(Gem::Version.new(version))

        Probe.new(status: "succeeded", version: version)
      rescue ArgumentError
        Probe.new(status: "unsupported", message: "Minitest reported an invalid version")
      rescue KeyError, ArgumentError => error
        Probe.new(status: "malformed", message: Shared.bounded_message(error.message))
      end

      def run(repository_root, runner: ProcessRunner, timeout_seconds: 30.0, probe_result: nil)
        probe_result ||= probe(repository_root, runner: runner, timeout_seconds: timeout_seconds)

        unless probe_result.status == "succeeded"
          fallback_command = @command_resolver.call(repository_root)
          version_invocation = Shared.invocation_for(fallback_command, ["--version"])
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: version_invocation, status: probe_result.status, message: probe_result.message, tool_version: probe_result.version), []]
        end

        command = @command_resolver.call(repository_root)
        reporter_path = resolve_reporter_path
        unless reporter_path
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: Shared.invocation_for(command, ["run"]), status: "malformed", message: "installed Minitest reporter is missing", tool_version: probe_result.version), []]
        end

        invocation = Shared.invocation_for(command, ["run"])
        output_path = File.join(repository_root, ".railverdict-minitest-#{SecureRandom.hex(6)}.json")
        env_reset_required = false
        previous_env = ENV["RAILVERDICT_MINITEST_OUTPUT"]
        begin
          ENV["RAILVERDICT_MINITEST_OUTPUT"] = output_path
          env_reset_required = true
          augmented_argv = invocation.fetch("argv").dup
          augmented_argv = inject_reporter_require(augmented_argv, reporter_path)
          result = runner.run(
            command.fetch(:executable),
            augmented_argv,
            chdir: repository_root,
            timeout_seconds: timeout_seconds
          )
          tool_version = probe_result.version

          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "unavailable", message: Shared.detail_for(result), tool_version: tool_version), []] if result.status == :spawn_failed
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "truncated", message: Shared.detail_for(result), tool_version: tool_version), []] if Shared.truncated?(result)
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "timed_out", message: Shared.detail_for(result), tool_version: tool_version), []] if result.status == :timed_out
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "signaled", message: Shared.detail_for(result), tool_version: tool_version), []] if result.status == :signaled

          document = load_reporter_document(output_path, result, invocation, tool_version)
          return document if document.is_a?(Array) && document.first.is_a?(AnalyzerResult)

          begin
            summary, findings = normalize_document(document)
          rescue MalformedOutput => error
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "malformed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
          end

          analyzer_result = AnalyzerResult.new(
            analyzer: ANALYZER_ID,
            tool_version: tool_version,
            invocation: invocation,
            execution_status: "succeeded",
            finding_ids: findings.map(&:id),
            evidence_summary: summary
          )
          [analyzer_result, findings]
        ensure
          if env_reset_required
            if previous_env.nil?
              ENV.delete("RAILVERDICT_MINITEST_OUTPUT")
            else
              ENV["RAILVERDICT_MINITEST_OUTPUT"] = previous_env
            end
          end
          begin
            File.unlink(output_path) if File.file?(output_path)
          rescue StandardError
            nil
          end
        end
      end

      private

      def default_command(repository_root)
        if File.file?(File.join(repository_root, "Gemfile"))
          { executable: "bundle", args_prefix: ["exec", "ruby", "-I", "test", "-r", "test_helper"] }
        else
          { executable: "ruby", args_prefix: ["-I", "test", "-r", "test_helper"] }
        end
      end

      def probe_argv_for(command, repository_root)
        args = command.fetch(:args_prefix).dup
        return args.concat(["--version"]) unless args.include?("test_helper")

        if File.file?(File.join(repository_root, "Gemfile"))
          ["exec", "ruby", "-rminitest", "-e", "puts Minitest::VERSION"]
        else
          ["-rminitest", "-e", "puts Minitest::VERSION"]
        end
      end

      def resolve_reporter_path
        candidates = []
        begin
          specs = Gem::Specification.find_all_by_name("rail_verdict")
          if specs.any?
            best = specs.max_by(&:version)
            candidates << File.join(best.full_gem_path, "exe", "railverdict-minitest-reporter.rb")
          end
        rescue StandardError
          nil
        end
        candidates << File.expand_path("../../../exe/railverdict-minitest-reporter.rb", __dir__)
        candidates.find { |path| File.file?(path) && File.readable?(path) }
      end

      def build_run_argv(command, reporter_path)
        base = command.fetch(:args_prefix).dup
        base.concat(["-r", reporter_path])
        base.concat(["-e", "Dir['test/**/*_test.rb'].sort.each{|f| require File.expand_path(f) }"])
        base
      end

      def inject_reporter_require(argv, reporter_path)
        argv = argv.dup
        if argv.include?("run")
          idx = argv.index("run")
          argv[idx] = "-r"
          argv.insert(idx + 1, reporter_path)
          argv.insert(idx + 2, "-e")
          argv.insert(idx + 3, "Dir['test/**/*_test.rb'].sort.each{|f| require File.expand_path(f) }")
        else
          argv.concat(["-r", reporter_path])
          argv.concat(["-e", "Dir['test/**/*_test.rb'].sort.each{|f| require File.expand_path(f) }"])
        end
        argv
      end

      def load_reporter_document(output_path, run_result, invocation, tool_version)
        if File.file?(output_path)
          begin
            bytes = File.binread(output_path)
          rescue SystemCallError => error
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "malformed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
          end
          if bytes.bytesize > 4 * 1024 * 1024
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "truncated", message: "Minitest reporter output exceeds 4 MiB", tool_version: tool_version), []]
          end
          text = bytes.dup.force_encoding(Encoding::UTF_8)
          unless text.valid_encoding?
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "parse_failed", message: "Minitest reporter output is not valid UTF-8", tool_version: tool_version), []]
          end
          begin
            return JSON.parse(text)
          rescue JSON::ParserError => error
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "parse_failed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
          end
        end
        stdout = run_result.stdout.to_s
        if stdout.strip.empty?
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "malformed", message: "Minitest reporter did not produce output", tool_version: tool_version), []]
        end
        begin
          JSON.parse(stdout)
        rescue JSON::ParserError => error
          [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "parse_failed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
        end
      end

      def normalize_document(document)
        raise MalformedOutput, "Minitest JSON root must be an object" unless document.is_a?(Hash)

        required = %w[schema_version runner seed tests_total assertions failures errors skips duration_seconds tests]
        missing = required - document.keys.map(&:to_s)
        raise MalformedOutput, "Minitest JSON is missing keys: #{missing.join(', ')}" unless missing.empty?

        unless document["schema_version"] == "1.0"
          raise MalformedOutput, "Minitest reporter schema_version must be 1.0"
        end

        tests = document["tests"]
        raise MalformedOutput, "Minitest tests must be an array" unless tests.is_a?(Array)

        findings = []
        tests.each_with_index do |test, index|
          finding = normalize_test(test, index, document["tests_total"])
          findings << finding if finding
        end

        findings = findings.uniq { |f| f.fingerprint }.sort_by(&:sort_key)
        summary = build_summary(document)
        [summary, findings]
      end

      def normalize_test(test, index, _total)
        raise MalformedOutput, "Minitest test #{index} must be an object" unless test.is_a?(Hash)

        class_name = test["class_name"]
        method_name = test["method_name"]
        status = test["status"]
        raise MalformedOutput, "Minitest test #{index} has invalid status" unless %w[passed failed errored skipped].include?(status)
        return nil if status == "passed" || status == "skipped"

        unless class_name.is_a?(String) && !class_name.empty? && method_name.is_a?(String) && !method_name.empty?
          raise MalformedOutput, "Minitest test #{index} has invalid class/method"
        end

        severity = status == "errored" ? "critical" : "high"
        category = "test"
        rule_id = "minitest/test:#{class_name}##{method_name}"
        message = (test["failure_message"] || test["method_name"]).to_s
        message = message.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")[0, 4096]
        message = "test failed: #{method_name}" if message.empty?
        unless message.is_a?(String) && message.valid_encoding? && !message.empty? && message.bytesize <= 4096
          raise MalformedOutput, "Minitest finding message is invalid"
        end

        path = normalize_path(test["file"], class_name)
        start_line = test["line"]
        location = { "path" => path }
        location["start_line"] = start_line if start_line.is_a?(Integer) && start_line >= 1
        location["end_line"] = location["start_line"] if location.key?("start_line")

        fingerprint = Finding.fingerprint_for(
          analyzer: ANALYZER_ID,
          rule_id: rule_id,
          path: path,
          message: message
        )
        Finding.new(
          fingerprint: fingerprint,
          origin: "deterministic",
          analyzer: ANALYZER_ID,
          rule_id: rule_id,
          category: category,
          severity: severity,
          confidence: "high",
          state: "observed",
          evidence_ref: "native:minitest:#{fingerprint.delete_prefix("sha256:")[0, 12]}",
          location: location,
          message: message
        )
      rescue ArgumentError => error
        raise MalformedOutput, "Minitest test #{index} is malformed: #{error.message}"
      end

      def normalize_path(file, fallback_class)
        if file.is_a?(String) && !file.empty? && file.match?(Finding::LOCATION_PATH_PATTERN)
          return file.delete_prefix("./")
        end

        fallback = fallback_class.to_s.gsub("::", "/").downcase
        "test/#{fallback}_test.rb"
      end

      def build_summary(document)
        {
          "tests_total" => Integer(document["tests_total"]),
          "assertions" => Integer(document["assertions"]),
          "failures" => Integer(document["failures"]),
          "errors" => Integer(document["errors"]),
          "skips" => Integer(document["skips"]),
          "duration_seconds" => Float(document["duration_seconds"]),
          "seed" => document["seed"] ? Integer(document["seed"]) : nil,
          "runner" => document["runner"].to_s[0, 128]
        }
      rescue ArgumentError, TypeError
        raise MalformedOutput, "Minitest summary fields have invalid types"
      end
    end
  end
end
