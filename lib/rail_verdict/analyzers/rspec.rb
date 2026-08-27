# frozen_string_literal: true

require "json"
require "tmpdir"
require "securerandom"

require_relative "_shared"

module RailVerdict
  module Analyzers
    class RSpec
      ANALYZER_ID = "rspec"
      SUPPORTED_VERSIONS = Gem::Requirement.new(">= 3.13", "< 4")

      Probe = Struct.new(:status, :version, :message, keyword_init: true)

      class MalformedOutput < StandardError; end

      def initialize(command_resolver: nil)
        @command_resolver = command_resolver || method(:default_command)
      end

      def probe(repository_root, runner: ProcessRunner, timeout_seconds: 15.0)
        effective_timeout = [timeout_seconds.to_f, 5.0].min
        command = @command_resolver.call(repository_root)
        clean_prefix = clean_args_prefix(command.fetch(:args_prefix))
        clean_command = command.merge(args_prefix: clean_prefix)
        invocation = Shared.invocation_for(clean_command, ["--version"])
        result = runner.run(
          clean_command.fetch(:executable),
          invocation.fetch("argv"),
          chdir: repository_root,
          timeout_seconds: effective_timeout
        )

        return Probe.new(status: "unavailable", message: Shared.detail_for(result)) if result.status == :spawn_failed
        return Probe.new(status: "timed_out", message: Shared.detail_for(result)) if result.status == :timed_out
        return Probe.new(status: "signaled", message: Shared.detail_for(result)) if result.status == :signaled
        return Probe.new(status: "truncated", message: Shared.detail_for(result)) if Shared.truncated?(result)
        return Probe.new(status: "unavailable", message: Shared.detail_for(result)) unless result.exit_code == 0

        version = Shared.parse_semver(result.stdout)
        return Probe.new(status: "unsupported", message: "RSpec version could not be parsed") unless version
        return Probe.new(status: "unsupported", version: version, message: "unsupported RSpec version #{version}") unless SUPPORTED_VERSIONS.satisfied_by?(Gem::Version.new(version))

        Probe.new(status: "succeeded", version: version)
      rescue ArgumentError
        Probe.new(status: "unsupported", message: "RSpec reported an invalid version")
      rescue KeyError, ArgumentError => error
        Probe.new(status: "malformed", message: Shared.bounded_message(error.message))
      end

      def run(repository_root, runner: ProcessRunner, timeout_seconds: 30.0, probe_result: nil, configuration: nil, target_files: nil, test_scope: "full", fallback_reason: nil)
        command = @command_resolver.call(repository_root)
        clean_prefix = clean_args_prefix(command.fetch(:args_prefix))
        clean_command = command.merge(args_prefix: clean_prefix)
        probe_result ||= probe(repository_root, runner: runner, timeout_seconds: timeout_seconds)
        version_invocation = Shared.invocation_for(clean_command, ["--version"])

        unless probe_result.status == "succeeded"
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: version_invocation, status: probe_result.status, message: probe_result.message, tool_version: probe_result.version), []]
        end

        if target_files.is_a?(Array) && target_files.empty? && test_scope == "targeted"
          summary = {
            "tests_total" => 0,
            "duration_seconds" => 0.0,
            "failures" => 0,
            "errors" => 0,
            "assertions" => 0,
            "skips" => 0,
            "runner" => "rspec #{probe_result.version}",
            "test_scope" => "targeted",
            "target_files" => [],
            "fallback_reason" => fallback_reason
          }.compact
          analyzer_result = AnalyzerResult.new(
            analyzer: ANALYZER_ID,
            tool_version: probe_result.version,
            invocation: Shared.invocation_for(clean_command, ["--format", "json"]),
            execution_status: "succeeded",
            finding_ids: [],
            evidence_summary: summary
          )
          return [analyzer_result, []]
        end

        output_path = File.join(Dir.tmpdir, "railverdict-rspec-#{SecureRandom.hex(8)}.json")
        target_list = Array(target_files).compact.reject(&:empty?)
        public_argv = target_list.empty? ? ["--format", "json"] : target_list + ["--format", "json"]
        public_invocation = Shared.invocation_for(clean_command, public_argv)
        run_argv = clean_prefix.dup.concat(target_list).concat(["--format", "json", "--out", output_path])

        max_stdout = resolve_stdout_limit(configuration, repository_root, 16 * 1024 * 1024)
        tool_version = probe_result.version

        begin
          result = runner.run(
            clean_command.fetch(:executable),
            run_argv,
            chdir: repository_root,
            timeout_seconds: timeout_seconds,
            max_stdout_bytes: max_stdout
          )

          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "unavailable", message: Shared.detail_for(result), tool_version: tool_version), []] if result.status == :spawn_failed
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "truncated", message: Shared.detail_for(result), tool_version: tool_version), []] if Shared.truncated?(result)
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "timed_out", message: Shared.detail_for(result), tool_version: tool_version), []] if result.status == :timed_out
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "signaled", message: Shared.detail_for(result), tool_version: tool_version), []] if result.status == :signaled

          unless File.file?(output_path)
            detail = Shared.detail_for(result)
            msg = detail.strip.empty? ? "RSpec did not produce structured output" : detail
            status = result.exit_code && result.exit_code != 0 ? "failed" : "malformed"
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: status, message: msg, tool_version: tool_version), []]
          end

          begin
            bytes = File.binread(output_path)
          rescue SystemCallError => error
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "malformed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
          end

          if bytes.bytesize > max_stdout
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "truncated", message: "RSpec output exceeds #{max_stdout} bytes", tool_version: tool_version), []]
          end

          text = bytes.dup.force_encoding(Encoding::UTF_8)
          unless text.valid_encoding?
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "parse_failed", message: "RSpec output is not valid UTF-8", tool_version: tool_version), []]
          end

          begin
            document = JSON.parse(text)
          rescue JSON::ParserError => error
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "parse_failed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
          end

          begin
            summary, findings = normalize_document(document, test_scope: test_scope, target_files: target_list, fallback_reason: fallback_reason)
          rescue MalformedOutput => error
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "malformed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
          end

          # Process exit reconciliation (RH-02):
          # 0: all examples passed, 0 failures/errors
          # 1: failed examples present (failures > 0 or findings non-empty)
          # Any other exit code or contradiction: fail closed
          failures_count = summary["failures"] || 0
          if result.exit_code == 0
            if failures_count > 0 || !findings.empty?
              return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "malformed", message: "RSpec exited with status 0 but reported #{failures_count} failures", tool_version: tool_version), []]
            end
          elsif result.exit_code == 1
            if failures_count == 0 && findings.empty?
              detail = Shared.detail_for(result)
              msg = detail.strip.empty? ? "RSpec exited with status 1 but reported 0 failed examples" : detail
              return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "failed", message: msg, tool_version: tool_version), []]
            end
          else
            detail = Shared.detail_for(result)
            msg = detail.strip.empty? ? "RSpec exited with unexpected status #{result.exit_code}" : detail
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "failed", message: msg, tool_version: tool_version), []]
          end

          analyzer_result = AnalyzerResult.new(
            analyzer: ANALYZER_ID,
            tool_version: tool_version,
            invocation: public_invocation,
            execution_status: "succeeded",
            finding_ids: findings.map(&:id),
            evidence_summary: summary
          )
          [analyzer_result, findings]
        ensure
          begin
            File.unlink(output_path) if output_path && File.exist?(output_path)
          rescue StandardError
            nil
          end
        end
      end

      private

      def default_command(repository_root)
        if File.file?(File.join(repository_root, "Gemfile"))
          { executable: "bundle", args_prefix: ["exec", "rspec"] }
        else
          { executable: "rspec", args_prefix: [] }
        end
      end

      def clean_args_prefix(prefix)
        cleaned = []
        skip_next = false
        Array(prefix).each_with_index do |arg, i|
          if skip_next
            skip_next = false
            next
          end
          if arg == "--format" && Array(prefix)[i + 1] == "json"
            skip_next = true
            next
          elsif arg == "--format=json"
            next
          end
          cleaned << arg
        end
        cleaned
      end

      def normalize_document(document, test_scope: "full", target_files: nil, fallback_reason: nil)
        raise MalformedOutput, "RSpec JSON root must be an object" unless document.is_a?(Hash)

        summary = document["summary"]
        examples = document["examples"]
        raise MalformedOutput, "RSpec JSON is missing summary" unless summary.is_a?(Hash)
        raise MalformedOutput, "RSpec JSON is missing examples array" unless examples.is_a?(Array)

        version = document["version"] || document["rspec_version"] || "unknown"

        findings = []
        examples.each_with_index do |example, index|
          finding = normalize_example(example, index)
          findings << finding if finding
        end

        findings = findings.uniq { |f| f.fingerprint }.sort_by(&:sort_key)
        summary_h = build_summary(summary, version)
        summary_h["tests_total"] = examples.length
        summary_h["test_scope"] = test_scope if test_scope
        summary_h["target_files"] = target_files if target_files && !target_files.empty?
        summary_h["fallback_reason"] = fallback_reason if fallback_reason

        [summary_h, findings]
      end

      def normalize_example(example, index)
        raise MalformedOutput, "RSpec example #{index} must be an object" unless example.is_a?(Hash)

        status = example["status"]
        raise MalformedOutput, "RSpec example #{index} has invalid status" unless %w[passed failed pending].include?(status.to_s)
        return nil if status == "passed"

        if status == "pending"
          id = example["full_description"] || example["description"] || "example:#{index}"
          return nil
        end

        raw_msg = (example["exception"] && example["exception"]["message"]) || example["full_description"] || example["description"] || nil
        message = Shared.normalize_finding_message(ANALYZER_ID, raw_msg.nil? || raw_msg.to_s.strip.empty? ? "rspec example failed" : raw_msg)

        rule_id = "example:#{example[id] || id_for(example, index)}"
        path = normalize_path(example["file_path"] || example["file"] || "spec/unknown_spec.rb")
        failure_line, failure_path = failure_location(example, path)
        start_line = failure_line || example["line_number"] || extract_line(example["id"])

        if failure_path && failure_path != path
          path = failure_path if failure_path.match?(Finding::LOCATION_PATH_PATTERN)
        end

        severity = "high"
        category = "test"

        location = { "path" => path }
        location["start_line"] = Integer(start_line) if start_line && Integer(start_line) >= 1 rescue nil
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
          evidence_ref: "native:rspec:#{fingerprint.delete_prefix("sha256:")[0, 12]}",
          location: location,
          message: message
        )
      rescue ArgumentError => error
        raise MalformedOutput, "RSpec example #{index} is malformed: #{error.message}"
      end

      def failure_location(example, default_path)
        exception = example["exception"]
        return [nil, nil] unless exception.is_a?(Hash)

        backtrace = exception["backtrace"]
        return [nil, nil] unless backtrace.is_a?(Array)

        backtrace.each do |frame|
          next unless frame.is_a?(String) && !frame.empty? && frame.bytesize <= 4096

          stripped = frame.strip
          next if stripped.empty?

          match = stripped.match(/\A(.+?):(\d+)(?::in |\z)/)
          next unless match

          raw_path = match[1].to_s.strip
          raw_line = match[2].to_s
          next if raw_path.empty?

          normalized = normalize_path_for_backtrace(raw_path)
          next unless normalized

          repository_relative = normalized.delete_prefix("./")
          next unless repository_relative.match?(Finding::LOCATION_PATH_PATTERN)
          next if repository_relative.start_with?("gems/") || repository_relative.include?("/gems/")

          base = File.basename(repository_relative)
          next if base.start_with?("rspec-") || base.start_with?("minitest")

          default_base = File.basename(default_path)
          same_file = repository_relative == default_path
          same_dir = File.dirname(repository_relative) == File.dirname(default_path)
          next unless same_file || (repository_relative.end_with?(default_base) && same_dir) || repository_relative.start_with?("spec/")

          line = begin Integer(raw_line) rescue nil end
          next unless line && line >= 1

          return [line, repository_relative]
        end
        [nil, nil]
      rescue StandardError
        [nil, nil]
      end

      def normalize_path_for_backtrace(raw_path)
        cleaned = raw_path.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").strip[0, 1024]
        return nil if cleaned.empty?

        cleaned = cleaned.sub(/\A\.\//, "")
        cleaned = cleaned.sub(%r{\A#{Regexp.escape(Dir.pwd)}/}, "") rescue cleaned
        cleaned.split(":").first.to_s.strip
      rescue StandardError
        nil
      end

      def id_for(example, index)
        (example["full_description"] || example["description"] || "example_#{index}").to_s.gsub(/[^a-zA-Z0-9_-]/, "_")[0, 64]
      end

      def normalize_path(file)
        return file.delete_prefix("./").then { |cleaned| cleaned.match?(Finding::LOCATION_PATH_PATTERN) ? cleaned : "spec/unknown_spec.rb" } if file.is_a?(String) && !file.empty?

        stripped = file.to_s.delete_prefix("./")
        return stripped if stripped.match?(Finding::LOCATION_PATH_PATTERN)

        "spec/unknown_spec.rb"
      end

      def extract_line(id)
        return nil unless id.is_a?(String)

        match = id.match(/:(\d+)\]?\z/)
        match && match[1]
      end

      def build_summary(summary, version)
        {
          "tests_total" => 0,
          "duration_seconds" => Float(summary["duration"] || summary["duration_seconds"] || 0),
          "failures" => Integer(summary["failure_count"] || summary["failures"] || 0),
          "errors" => Integer(summary["errors"] || 0),
          "assertions" => Integer(summary["example_count"] || summary["tests_total"] || 0),
          "skips" => Integer(summary["pending_count"] || summary["pending"] || 0),
          "seed" => summary["seed"] ? Integer(summary["seed"]) : nil,
          "runner" => "rspec #{version}"[0, 128]
        }
      rescue ArgumentError, TypeError
        raise MalformedOutput, "RSpec summary fields have invalid types"
      end

      def resolve_stdout_limit(configuration, repository_root, default_bytes)
        raw_limit = nil
        if configuration
          sel = configuration.analyzers[ANALYZER_ID] rescue nil
          raw_limit = sel && sel["output_limit_bytes"]
        end
        raw_limit ||= default_bytes
        limit = Integer(raw_limit) rescue default_bytes
        limit = default_bytes if limit <= 0
        max = RailVerdict::ProcessRunner::MAX_SAFE_STDOUT_BYTES
        [[limit, max].min, 1024].max
      end
    end
  end
end
