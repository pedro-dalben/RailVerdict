# frozen_string_literal: true

require "json"

require_relative "_shared"

module RailVerdict
  module Analyzers
    class SimpleCov
      ANALYZER_ID = "simplecov"
      DEFAULT_COVERAGE_PATH = "coverage/coverage.json"
      DEFAULT_FRESHNESS_WINDOW_SECONDS = 86_400
      SUPPORTED_VERSION_RANGE = Gem::Requirement.new(">= 1", "< 2")

      Probe = Struct.new(:status, :version, :message, keyword_init: true)

      class MalformedOutput < StandardError; end

      def probe(repository_root, runner: nil, timeout_seconds: 5.0)
        config = load_config(repository_root)
        coverage_path = config.fetch("coverage_path") { DEFAULT_COVERAGE_PATH }
        full_path = File.expand_path(coverage_path, repository_root)
        return Probe.new(status: "unavailable", message: "coverage file is absent: #{coverage_path}") unless File.file?(full_path)

        text = File.binread(full_path).force_encoding(Encoding::UTF_8)
        return Probe.new(status: "parse_failed", message: "coverage file is not valid UTF-8") unless text.valid_encoding?

        document = JSON.parse(text)
        return Probe.new(status: "unsupported", message: "coverage document has no version") unless document["version"].is_a?(String)

        version = document["version"]
        return Probe.new(status: "unsupported", message: "unsupported SimpleCov version #{version}") unless version.start_with?("1")

        Probe.new(status: "succeeded", version: version)
      rescue JSON::ParserError => error
        Probe.new(status: "parse_failed", message: Shared.bounded_message(error.message))
      rescue MalformedOutput => error
        Probe.new(status: "malformed", message: Shared.bounded_message(error.message))
      rescue SystemCallError, ArgumentError => error
        Probe.new(status: "unavailable", message: Shared.bounded_message(error.message))
      end

      def run(repository_root, runner: nil, timeout_seconds: 10.0, probe_result: nil, configuration: nil)
        config = load_config(repository_root, configuration: configuration)
        coverage_path = config.fetch("coverage_path") { DEFAULT_COVERAGE_PATH }
        freshness_window = config.fetch("freshness_window_seconds") { DEFAULT_FRESHNESS_WINDOW_SECONDS }
        invocation = { "executable" => "simplecov", "argv" => ["read", coverage_path] }
        full_path = File.expand_path(coverage_path, repository_root)

        unless File.file?(full_path)
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "unavailable", message: "coverage file is absent: #{coverage_path}"), []]
        end

        begin
          bytes = File.binread(full_path)
        rescue SystemCallError => error
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "unavailable", message: Shared.bounded_message(error.message)), []]
        end

        if bytes.bytesize > 8 * 1024 * 1024
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "truncated", message: "coverage file exceeds 8 MiB"), []]
        end

        text = bytes.dup.force_encoding(Encoding::UTF_8)
        unless text.valid_encoding?
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "parse_failed", message: "coverage file is not valid UTF-8"), []]
        end

        begin
          document = JSON.parse(text)
        rescue JSON::ParserError => error
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "parse_failed", message: Shared.bounded_message(error.message)), []]
        end

        version = document["version"].to_s
        probe_result ||= probe(repository_root, timeout_seconds: timeout_seconds)
        unless version.start_with?("1")
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "unsupported", message: "unsupported SimpleCov version #{version}", tool_version: probe_result.version || version), []]
        end

        errors = validate_coverage_schema(document)
        unless errors.empty?
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "malformed", message: errors.first, tool_version: probe_result.version || version), []]
        end

        mtime = File.mtime(full_path)
        stale = (Time.now - mtime) > freshness_window

        covered, executable = coverage_totals(document)

        summary = {
          "covered_lines" => covered,
          "executable_lines" => executable,
          "percent" => executable == 0 ? 100.0 : ((covered.to_f / executable) * 100).round(2),
          "stale" => stale,
          "freshness_window_seconds" => Integer(freshness_window),
          "coverage_path" => coverage_path.to_s[0, 512]
        }

        result = AnalyzerResult.new(
          analyzer: ANALYZER_ID,
          tool_version: version,
          invocation: invocation,
          execution_status: "succeeded",
          finding_ids: [],
          evidence_summary: summary
        )

        [result, []]
      rescue StandardError => error
        [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: { "executable" => "simplecov", "argv" => ["read", DEFAULT_COVERAGE_PATH] }, status: "malformed", message: Shared.bounded_message(error.message)), []]
      end

      private

      def load_config(repository_root, configuration: nil)
        if configuration
          sel = configuration.analyzers["simplecov"]
          return {} unless sel

          return {
            "coverage_path" => sel["coverage_path"],
            "freshness_window_seconds" => sel["freshness_window_seconds"]
          }.compact
        end

        path = File.join(repository_root, ".railverdict.yml")
        return {} unless File.file?(path)

        bytes = File.binread(path) rescue nil
        return {} unless bytes

        text = bytes.dup.force_encoding(Encoding::UTF_8)
        return {} unless text.valid_encoding?

        data = RailVerdict::StrictYaml.parse(text, path) rescue nil
        return {} unless data.is_a?(Hash) && data["analyzers"].is_a?(Hash)

        sel = data["analyzers"]["simplecov"]
        return {} unless sel.is_a?(Hash)

        { "coverage_path" => sel["coverage_path"], "freshness_window_seconds" => sel["freshness_window_seconds"] }.compact
      rescue StandardError
        {}
      end

      def validate_coverage_schema(document)
        schema_path = File.expand_path("../../../schemas/coverage-v1.schema.json", __dir__)
        schema = JSON.parse(File.read(schema_path))
        JSONSchemer.schema(schema).validate(document).map { |err|
          pointer = err["data_pointer"].to_s
          location = pointer.empty? ? "$" : "$#{pointer.gsub('/', '.')}"
          "#{location}: #{err["error"]}"
        }
      rescue StandardError => error
        ["schema validation error: #{error.message}"]
      end

      def coverage_totals(document)
        covered = 0
        executable = 0
        document.fetch("files", []).each do |file|
          lines = file.dig("coverage", "lines")
          next unless lines.is_a?(Array)

          lines.each do |hit|
            next if hit.nil?

            executable += 1
            covered += 1 if hit.to_i > 0
          end
        end
        [covered, executable]
      end
    end
  end
end
