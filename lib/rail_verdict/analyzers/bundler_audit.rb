# frozen_string_literal: true

require "json"

require_relative "_shared"

module RailVerdict
  module Analyzers
    class BundlerAudit
      ANALYZER_ID = "bundler_audit"
      SUPPORTED_VERSIONS = Gem::Requirement.new(">= 0.9.3", "< 1")

      Probe = Struct.new(:status, :version, :message, :database_updated_at, keyword_init: true)

      class MalformedOutput < StandardError; end

      def initialize(command_resolver: nil)
        @command_resolver = command_resolver || method(:default_command)
      end

      def probe(repository_root, runner: ProcessRunner, timeout_seconds: 15.0)
        command = @command_resolver.call(repository_root)
        invocation = Shared.invocation_for(command, ["version"])
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
        return Probe.new(status: "unsupported", message: "bundler-audit version could not be parsed") unless version
        return Probe.new(status: "unsupported", version: version, message: "unsupported bundler-audit version #{version}") unless SUPPORTED_VERSIONS.satisfied_by?(Gem::Version.new(version))

        db_updated = parse_database_updated(result.stdout)

        Probe.new(status: "succeeded", version: version, database_updated_at: db_updated)
      rescue ArgumentError
        Probe.new(status: "unsupported", message: "bundler-audit reported an invalid version")
      rescue KeyError, ArgumentError => error
        Probe.new(status: "malformed", message: Shared.bounded_message(error.message))
      end

      def run(repository_root, runner: ProcessRunner, timeout_seconds: 30.0, probe_result: nil)
        command = @command_resolver.call(repository_root)
        probe_result ||= probe(repository_root, runner: runner, timeout_seconds: timeout_seconds)
        version_invocation = Shared.invocation_for(command, ["version"])

        unless probe_result.status == "succeeded"
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: version_invocation, status: probe_result.status, message: probe_result.message, tool_version: probe_result.version), []]
        end

        invocation = Shared.invocation_for(command, ["check", "--format", "json"])
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
        if result.exit_code.nil? || result.exit_code > 1
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "failed", message: Shared.execution_message(result), tool_version: tool_version), []]
        end

        begin
          document = parse_json_document(result.stdout)
        rescue JSON::ParserError => error
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "parse_failed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
        end

        begin
          summary, findings = normalize_document(document, tool_version)
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
          { executable: "bundle", args_prefix: ["exec", "bundler-audit"] }
        else
          { executable: "bundler-audit", args_prefix: [] }
        end
      end

      def parse_database_updated(output)
        match = output.to_s.match(/database.*?(\d{4}-\d{2}-\d{2})/i)
        match && match[1]
      end

      def normalize_document(document, tool_version)
        raise MalformedOutput, "bundler-audit JSON root must be an object" unless document.is_a?(Hash)

        results = document["results"] || document["vulnerabilities"] || document["advisories"] || []
        raise MalformedOutput, "bundler-audit results must be an array" unless results.is_a?(Array)

        findings = []
        results.each_with_index do |entry, index|
          finding = normalize_entry(entry, index)
          findings << finding if finding
        end

        findings = findings.uniq { |f| f.fingerprint }.sort_by(&:sort_key)
        summary = {
          "vulnerabilities" => findings.length,
          "tool_version" => tool_version.to_s[0, 64],
          "database_updated_at" => parse_database_updated(document.to_s)
        }

        [summary, findings]
      end

      def normalize_entry(entry, index)
        raise MalformedOutput, "bundler-audit entry #{index} must be an object" unless entry.is_a?(Hash)

        advisory = entry["advisory"] || entry
        id = (advisory["id"] || entry["id"] || "advisory-#{index}").to_s
        id = "advisory-#{index}" if id.empty?
        gem_name = (entry["gem"] && entry["gem"]["name"]) || entry["gem_name"] || advisory["gem"] || "unknown"
        gem_name = "unknown" if gem_name.to_s.empty?

        severity = map_severity(advisory["criticality"] || advisory["severity"] || entry["criticality"] || entry["severity"])
        message = (advisory["title"] || advisory["description"] || entry["title"] || entry["description"] || "vulnerability in #{gem_name}").to_s
        message = message.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")[0, 4096]
        message = "vulnerability in #{gem_name}" if message.empty?

        rule_id = "bundler_audit/advisory:#{id}"
        category = "dependency"

        path = "Gemfile.lock"
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
          evidence_ref: "native:bundler_audit:#{fingerprint.delete_prefix("sha256:")[0, 12]}",
          location: { "path" => path },
          message: message
        )
      rescue ArgumentError => error
        raise MalformedOutput, "bundler-audit entry #{index} is malformed: #{error.message}"
      end

      def parse_json_document(stdout)
        text = stdout.to_s
        json_start = text.index(/[\[{]/)
        last_error = nil

        while json_start
          begin
            json_end = json_document_end(text, json_start)
            parsed = JSON.parse(text[json_start..json_end])
            trailing = text[(json_end + 1)..].to_s.strip
            unless trailing.empty?
              raise JSON::ParserError, "trailing content after JSON document: #{trailing[0, 80]}"
            end

            return parsed
          rescue JSON::ParserError => error
            raise error if error.message.start_with?("trailing content")

            last_error = error
            json_start = text.index(/[\[{]/, json_start + 1)
          end
        end

        raise(last_error || JSON::ParserError.new("no JSON document found"))
      end

      def json_document_end(text, start)
        stack = []
        in_string = false
        escaped = false

        text[start..].each_char.with_index do |character, offset|
          index = start + offset
          if in_string
            if escaped
              escaped = false
            elsif character == "\\"
              escaped = true
            elsif character == '"'
              in_string = false
            end
            next
          end

          case character
          when '"'
            in_string = true
          when "{", "["
            stack << character
          when "}", "]"
            expected = character == "}" ? "{" : "["
            raise JSON::ParserError, "mismatched JSON delimiter" unless stack.last == expected

            stack.pop
            return index if stack.empty?
          end
        end

        raise JSON::ParserError, "incomplete JSON document"
      end

      def map_severity(raw)
        case raw.to_s.downcase
        when "critical" then "critical"
        when "high" then "high"
        when "medium" then "medium"
        when "low" then "low"
        when "info", "unknown", "" then "medium"
        else "medium"
        end
      end
    end
  end
end
