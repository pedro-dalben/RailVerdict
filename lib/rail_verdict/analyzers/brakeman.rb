# frozen_string_literal: true

require "json"
require "tmpdir"
require "securerandom"

require_relative "_shared"

module RailVerdict
  module Analyzers
    class Brakeman
      ANALYZER_ID = "brakeman"
      SUPPORTED_VERSIONS = Gem::Requirement.new(">= 7.0", "< 9")

      SEVERITY_MAP = {
        "High" => "high",
        "Medium" => "medium",
        "Weak" => "low"
      }.freeze

      CONFIDENCE_MAP = {
        "High" => "high",
        "Medium" => "medium",
        "Weak" => "low"
      }.freeze

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
        return Probe.new(status: "unsupported", message: "Brakeman version could not be parsed") unless version
        return Probe.new(status: "unsupported", version: version, message: "unsupported Brakeman version #{version}") unless SUPPORTED_VERSIONS.satisfied_by?(Gem::Version.new(version))

        Probe.new(status: "succeeded", version: version)
      rescue ArgumentError
        Probe.new(status: "unsupported", message: "Brakeman reported an invalid version")
      rescue KeyError, ArgumentError => error
        Probe.new(status: "malformed", message: Shared.bounded_message(error.message))
      end

      def run(repository_root, runner: ProcessRunner, timeout_seconds: 30.0, probe_result: nil, configuration: nil)
        command = @command_resolver.call(repository_root)
        clean_prefix = clean_args_prefix(command.fetch(:args_prefix))
        clean_command = command.merge(args_prefix: clean_prefix)
        probe_result ||= probe(repository_root, runner: runner, timeout_seconds: timeout_seconds)
        version_invocation = Shared.invocation_for(clean_command, ["--version"])

        unless probe_result.status == "succeeded"
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: version_invocation, status: probe_result.status, message: probe_result.message, tool_version: probe_result.version), []]
        end

        output_path = File.join(Dir.tmpdir, "railverdict-brakeman-#{SecureRandom.hex(8)}.json")
        public_invocation = Shared.invocation_for(clean_command, ["-q", "--no-pager", "-f", "json"])
        run_argv = clean_prefix.dup.concat(["-q", "--no-pager", "-f", "json", "-o", output_path])

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
            msg = detail.strip.empty? ? "Brakeman did not produce structured output" : detail
            status = result.exit_code && result.exit_code != 0 ? "failed" : "malformed"
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: status, message: msg, tool_version: tool_version), []]
          end

          begin
            bytes = File.binread(output_path)
          rescue SystemCallError => error
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "malformed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
          end

          if bytes.bytesize > max_stdout
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "truncated", message: "Brakeman output exceeds #{max_stdout} bytes", tool_version: tool_version), []]
          end

          text = bytes.dup.force_encoding(Encoding::UTF_8)
          unless text.valid_encoding?
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "parse_failed", message: "Brakeman output is not valid UTF-8", tool_version: tool_version), []]
          end

          begin
            document = JSON.parse(text)
          rescue JSON::ParserError => error
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "parse_failed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
          end

          begin
            summary, findings = normalize_document(document)
          rescue MalformedOutput => error
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "malformed", message: Shared.bounded_message(error.message), tool_version: tool_version), []]
          end

          # Process exit reconciliation:
          # 0: Clean scan (0 warnings) or explicit no-exit-on-warn
          # 3: Warnings reported by Brakeman (findings > 0)
          # Any other status: execution failure
          warnings_count = summary["security_warnings"] || 0
          if result.exit_code == 0
            # Clean scan or non-failing mode
          elsif result.exit_code == 3
            if warnings_count == 0 && findings.empty?
              detail = Shared.detail_for(result)
              msg = detail.strip.empty? ? "Brakeman exited with status 3 but reported 0 warnings" : detail
              return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: public_invocation, status: "failed", message: msg, tool_version: tool_version), []]
            end
          else
            detail = Shared.detail_for(result)
            msg = detail.strip.empty? ? "Brakeman exited with unexpected status #{result.exit_code}" : detail
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
          { executable: "bundle", args_prefix: ["exec", "brakeman"] }
        else
          { executable: "brakeman", args_prefix: [] }
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
          if (arg == "-f" || arg == "--format" || arg == "-o" || arg == "--output") && Array(prefix)[i + 1]
            skip_next = true
            next
          elsif arg.start_with?("-f=") || arg.start_with?("--format=") || arg.start_with?("-o=") || arg.start_with?("--output=")
            next
          elsif arg == "-q" || arg == "--quiet" || arg == "--no-pager"
            next
          end
          cleaned << arg
        end
        cleaned
      end

      def normalize_document(document)
        raise MalformedOutput, "Brakeman JSON root must be an object" unless document.is_a?(Hash)

        scan_info = document["scan_info"]
        warnings = document["warnings"]
        errors = document["errors"]

        raise MalformedOutput, "Brakeman JSON is missing scan_info" unless scan_info.is_a?(Hash)
        raise MalformedOutput, "Brakeman JSON is missing warnings array" unless warnings.is_a?(Array)

        findings = []
        warnings.each_with_index do |warning, index|
          finding = normalize_warning(warning, index)
          findings << finding if finding
        end

        findings = findings.uniq(&:fingerprint).sort_by(&:sort_key)
        summary_h = build_summary(scan_info, findings.length)

        [summary_h, findings]
      end

      def normalize_warning(warning, index)
        raise MalformedOutput, "Brakeman warning #{index} must be an object" unless warning.is_a?(Hash)

        check_name = warning["check_name"] || warning["warning_type"] || "warning_#{warning['warning_code'] || index}"
        rule_id = check_name.to_s.gsub(/[^a-zA-Z0-9_-]/, "_")[0, 64]
        rule_id = "warning_#{index}" if rule_id.empty?

        raw_msg = warning["message"] || warning["warning_type"] || "security warning"
        message = Shared.normalize_finding_message(ANALYZER_ID, raw_msg)

        confidence_str = warning["confidence"].to_s
        confidence = CONFIDENCE_MAP.fetch(confidence_str) { "medium" }
        severity = SEVERITY_MAP.fetch(confidence_str) { "medium" }

        category = "security"
        path = normalize_path(warning["file"] || "unknown")
        start_line = extract_line(warning["line"])

        location = { "path" => path }
        location["start_line"] = start_line if start_line && start_line >= 1
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
          confidence: confidence,
          state: "observed",
          evidence_ref: "native:brakeman:#{fingerprint.delete_prefix("sha256:")[0, 12]}",
          location: location,
          message: message
        )
      rescue ArgumentError => error
        raise MalformedOutput, "Brakeman warning #{index} is malformed: #{error.message}"
      end

      def normalize_path(file)
        return "unknown" unless file.is_a?(String) && !file.empty?

        cleaned = file.delete_prefix("./").delete_prefix("/")
        return cleaned if cleaned.match?(Finding::LOCATION_PATH_PATTERN)

        "unknown"
      end

      def extract_line(line)
        return nil if line.nil?
        val = Integer(line) rescue nil
        val && val >= 1 ? val : nil
      end

      def build_summary(scan_info, security_warnings_count)
        {
          "security_warnings" => security_warnings_count,
          "checks_performed" => scan_info["checks_performed"].is_a?(Array) ? scan_info["checks_performed"].length : 0,
          "duration_seconds" => Float(scan_info["duration"] || scan_info["duration_seconds"] || 0),
          "rails_version" => scan_info["rails_version"].to_s,
          "ruby_version" => scan_info["ruby_version"].to_s,
          "brakeman_version" => scan_info["brakeman_version"].to_s
        }
      rescue ArgumentError, TypeError
        raise MalformedOutput, "Brakeman scan_info fields have invalid types"
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
