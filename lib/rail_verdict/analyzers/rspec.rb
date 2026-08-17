# frozen_string_literal: true

require "json"

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
        command = @command_resolver.call(repository_root)
        invocation = Shared.invocation_for(command, ["--version"])
        result = runner.run(
          command.fetch(:executable),
          invocation.fetch("argv"),
          chdir: repository_root,
          timeout_seconds: timeout_seconds
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

      def run(repository_root, runner: ProcessRunner, timeout_seconds: 30.0, probe_result: nil)
        command = @command_resolver.call(repository_root)
        probe_result ||= probe(repository_root, runner: runner, timeout_seconds: timeout_seconds)
        version_invocation = Shared.invocation_for(command, ["--version"])

        unless probe_result.status == "succeeded"
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: version_invocation, status: probe_result.status, message: probe_result.message, tool_version: probe_result.version), []]
        end

        invocation = Shared.invocation_for(command, ["--format", "json"])
        result = runner.run(
          command.fetch(:executable),
          invocation.fetch("argv"),
          chdir: repository_root,
          timeout_seconds: timeout_seconds
        )
        tool_version = probe_result.version

        return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "unavailable", message: Shared.detail_for(result), tool_version: tool_version), []] if result.status == :spawn_failed
        return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "truncated", message: Shared.detail_for(result), tool_version: tool_version), []] if Shared.truncated?(result)
        return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "timed_out", message: Shared.detail_for(result), tool_version: tool_version), []] if result.status == :timed_out
        return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "signaled", message: Shared.detail_for(result), tool_version: tool_version), []] if result.status == :signaled

        begin
          document = JSON.parse(result.stdout)
        rescue JSON::ParserError => error
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "parse_failed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
        end

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
      end

      private

      def default_command(repository_root)
        if File.file?(File.join(repository_root, "Gemfile"))
          { executable: "bundle", args_prefix: ["exec", "rspec", "--format", "json"] }
        else
          { executable: "rspec", args_prefix: ["--format", "json"] }
        end
      end

      def normalize_document(document)
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

        message = (example["exception"] && example["exception"]["message"]) || example["full_description"] || example["description"] || "rspec example failed"
        message = message.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")[0, 4096]
        message = "rspec example failed" if message.empty?

        rule_id = "rspec/example:#{example['id'] || id_for(example, index)}"
        path = normalize_path(example["file_path"] || example["file"] || "spec/unknown_spec.rb")
        start_line = example["line_number"] || extract_line(example["id"])

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

      def id_for(example, index)
        (example["full_description"] || example["description"] || "example_#{index}").to_s.gsub(/[^a-zA-Z0-9_-]/, "_")[0, 64]
      end

      def normalize_path(file)
        return file.delete_prefix("./") if file.is_a?(String) && !file.empty? && file.match?(Finding::LOCATION_PATH_PATTERN)

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
    end
  end
end
