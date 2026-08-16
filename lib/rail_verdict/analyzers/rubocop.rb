# frozen_string_literal: true

require "json"

module RailVerdict
  module Analyzers
    class RuboCop
      ANALYZER_ID = "rubocop"
      SUPPORTED_VERSIONS = Gem::Requirement.new(">= 1.72", "< 2")
      SEVERITY_MAP = {
        "info" => "info",
        "refactor" => "low",
        "convention" => "low",
        "warning" => "medium",
        "error" => "high",
        "fatal" => "critical"
      }.freeze

      Probe = Struct.new(:status, :version, :message, keyword_init: true)

      class MalformedOutput < StandardError; end

      def initialize(command_resolver: nil)
        @command_resolver = command_resolver || method(:default_command)
      end

      def probe(repository_root, runner: ProcessRunner, timeout_seconds: 15.0)
        command = @command_resolver.call(repository_root)
        invocation = invocation_for(command, ["--version"])
        result = runner.run(
          command.fetch(:executable),
          invocation.fetch("argv"),
          chdir: repository_root,
          timeout_seconds: timeout_seconds
        )

        return Probe.new(status: "unavailable", message: detail_for(result)) if result.status == :spawn_failed
        return Probe.new(status: "timed_out", message: detail_for(result)) if result.status == :timed_out
        return Probe.new(status: "signaled", message: detail_for(result)) if result.status == :signaled
        return Probe.new(status: "truncated", message: detail_for(result)) if truncated?(result)
        return Probe.new(status: "unavailable", message: detail_for(result)) unless result.exit_code == 0

        version = parse_version(result.stdout)
        return Probe.new(status: "unsupported", message: "RuboCop version could not be parsed") unless version
        return Probe.new(status: "unsupported", version: version, message: "unsupported RuboCop version #{version}") unless SUPPORTED_VERSIONS.satisfied_by?(Gem::Version.new(version))

        Probe.new(status: "succeeded", version: version)
      rescue ArgumentError
        Probe.new(status: "unsupported", message: "RuboCop reported an invalid version")
      rescue KeyError, ArgumentError => error
        Probe.new(status: "malformed", message: bounded_message(error.message))
      end

      def run(repository_root, runner: ProcessRunner, timeout_seconds: 30.0)
        command = @command_resolver.call(repository_root)
        probe_result = probe(repository_root, runner: runner, timeout_seconds: timeout_seconds)
        version_invocation = invocation_for(command, ["--version"])

        unless probe_result.status == "succeeded"
          return [failure_result(version_invocation, probe_result.status, probe_result.message, tool_version: probe_result.version), []]
        end

        invocation = invocation_for(command, ["--format", "json"])
        result = runner.run(
          command.fetch(:executable),
          invocation.fetch("argv"),
          chdir: repository_root,
          timeout_seconds: timeout_seconds
        )
        tool_version = probe_result.version

        if result.status == :spawn_failed
          return [failure_result(invocation, "unavailable", detail_for(result), tool_version: tool_version), []]
        end
        if truncated?(result)
          return [failure_result(invocation, "truncated", detail_for(result), tool_version: tool_version), []]
        end
        if result.status == :timed_out
          return [failure_result(invocation, "timed_out", detail_for(result), tool_version: tool_version), []]
        end
        if result.status == :signaled
          return [failure_result(invocation, "signaled", detail_for(result), tool_version: tool_version), []]
        end
        if result.exit_code && result.exit_code >= 2
          return [failure_result(invocation, "failed", execution_message(result), tool_version: tool_version), []]
        end

        begin
          parsed = JSON.parse(result.stdout)
        rescue JSON::ParserError => error
          return [failure_result(invocation, "parse_failed", bounded_message(error.message), tool_version: tool_version), []]
        end

        findings = normalize_findings(parsed)
        analyzer_result = AnalyzerResult.new(
          analyzer: ANALYZER_ID,
          tool_version: tool_version,
          invocation: invocation,
          execution_status: "succeeded",
          finding_ids: findings.map(&:id)
        )
        [analyzer_result, findings]
      rescue MalformedOutput => error
        [failure_result(invocation || { "executable" => "rubocop", "argv" => [] }, "malformed", bounded_message(error.message)), []]
      end

      private

      def default_command(repository_root)
        if File.file?(File.join(repository_root, "Gemfile"))
          { executable: "bundle", args_prefix: ["exec", "rubocop"] }
        else
          { executable: "rubocop", args_prefix: [] }
        end
      end

      def invocation_for(command, arguments)
        {
          "executable" => command.fetch(:executable),
          "argv" => command.fetch(:args_prefix).dup.concat(arguments)
        }
      end

      def parse_version(output)
        match = output.to_s.match(/\b(\d+\.\d+\.\d+)\b/)
        match && match[1]
      end

      def truncated?(result)
        result.stdout_truncated || result.stderr_truncated
      end

      def detail_for(result)
        detail = result.detail.to_s
        stderr = result.stderr.to_s.lines.first.to_s.strip
        bounded_message([detail, stderr].reject(&:empty?).join(": "))
      end

      def execution_message(result)
        message = result.stderr.to_s.lines.first.to_s.strip
        message = "RuboCop exited with status #{result.exit_code}" if message.empty?
        bounded_message(message)
      end

      def bounded_message(message)
        message.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")[0, 4096]
      end

      def failure_result(invocation, status, message, tool_version: nil)
        status = status.to_s
        AnalyzerResult.new(
          analyzer: ANALYZER_ID,
          tool_version: tool_version,
          invocation: invocation,
          execution_status: status,
          finding_ids: [],
          failure: { "code" => status, "message" => bounded_message(message.to_s) }
        )
      end

      def normalize_findings(document)
        raise MalformedOutput, "RuboCop JSON root must be an object" unless document.is_a?(Hash)

        files = document["files"]
        raise MalformedOutput, "RuboCop JSON is missing files array" unless files.is_a?(Array)

        findings = files.each_with_index.flat_map do |file, file_index|
          normalize_file(file, file_index)
        end
        findings.uniq { |finding| finding.fingerprint }.sort_by(&:sort_key)
      end

      def normalize_file(file, file_index)
        raise MalformedOutput, "RuboCop file entry #{file_index} must be an object" unless file.is_a?(Hash)

        path = normalize_path(file["path"])
        offenses = file["offenses"]
        raise MalformedOutput, "RuboCop file #{path} is missing offenses array" unless offenses.is_a?(Array)

        offenses.each_with_index.map do |offense, offense_index|
          normalize_offense(offense, path, file_index, offense_index)
        end
      end

      def normalize_path(path)
        raise MalformedOutput, "RuboCop path must be a string" unless path.is_a?(String) && !path.empty?

        normalized = path.delete_prefix("./")
        unless normalized.match?(Finding::LOCATION_PATH_PATTERN)
          raise MalformedOutput, "RuboCop emitted unsafe path"
        end
        normalized
      end

      def normalize_offense(offense, path, file_index, offense_index)
        raise MalformedOutput, "RuboCop offense must be an object" unless offense.is_a?(Hash)

        rule_id = offense["cop_name"]
        severity = SEVERITY_MAP.fetch(offense["severity"]) do
          raise MalformedOutput, "RuboCop emitted unknown severity"
        end
        category = rule_id.to_s.split("/", 2).first
        raise MalformedOutput, "RuboCop cop name has no department" unless rule_id.is_a?(String) && rule_id.include?("/") && !category.empty?

        location = offense["location"]
        raise MalformedOutput, "RuboCop offense location is invalid" unless location.is_a?(Hash)

        start_line = location["start_line"]
        end_line = location["last_line"]
        unless start_line.is_a?(Integer) && end_line.is_a?(Integer) && start_line >= 1 && end_line >= start_line
          raise MalformedOutput, "RuboCop offense line range is invalid"
        end

        message = offense["message"]
        unless message.is_a?(String) && message.valid_encoding? && !message.empty? && message.bytesize <= 4096
          raise MalformedOutput, "RuboCop offense message is invalid"
        end

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
          category: category.downcase,
          severity: severity,
          confidence: "high",
          state: "observed",
          evidence_ref: "native:rubocop:#{fingerprint.delete_prefix("sha256:")[0, 12]}",
          location: { "path" => path, "start_line" => start_line, "end_line" => end_line },
          message: message
        )
      rescue KeyError
        raise MalformedOutput, "RuboCop offense has unknown severity"
      rescue ArgumentError => error
        raise MalformedOutput, "RuboCop offense #{file_index}:#{offense_index} is malformed: #{error.message}"
      end
    end
  end
end
