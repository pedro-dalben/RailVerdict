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
        detected = detect_format(document)
        case detected
        when :coverage_v1
          version = document["version"].to_s
          return Probe.new(status: "unsupported", message: "unsupported SimpleCov version #{version}") unless version.start_with?("1")
          Probe.new(status: "succeeded", version: version)
        when :native_simplecov
          version = extract_native_version(document)
          # Accept any native simplecov version >=0.20 with coverage hash; version check is permissive.
          Probe.new(status: "succeeded", version: version)
        when :unsupported
          Probe.new(status: "unsupported", message: "unsupported coverage document shape")
        else
          Probe.new(status: "malformed", message: "coverage document is malformed")
        end
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

        detected = detect_format(document)
        if detected == :unsupported
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "unsupported", message: "unsupported coverage document shape", tool_version: probe_result&.version), []]
        elsif detected == :malformed
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "malformed", message: "coverage document is malformed", tool_version: probe_result&.version), []]
        end

        normalized = nil
        version = nil
        if detected == :coverage_v1
          version = document["version"].to_s
          probe_result ||= probe(repository_root, timeout_seconds: timeout_seconds)
          unless version.start_with?("1")
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "unsupported", message: "unsupported SimpleCov version #{version}", tool_version: probe_result.version || version), []]
          end
          errors = validate_coverage_schema(document)
          unless errors.empty?
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "malformed", message: errors.first, tool_version: probe_result.version || version), []]
          end
          normalized = normalize_coverage_v1(document)
          version = document["version"].to_s
        elsif detected == :native_simplecov
          begin
            normalized = normalize_native_document(document, repository_root)
            version = extract_native_version(document)
          rescue MalformedOutput => error
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "malformed", message: Shared.bounded_message(error.message), tool_version: probe_result&.version), []]
          end
          # Validate normalized shape via same schema
          errors = validate_coverage_schema(normalized)
          unless errors.empty?
            return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "malformed", message: errors.first, tool_version: version), []]
          end
        else
          return [Shared.failure_result(analyzer_id: ANALYZER_ID, invocation: invocation, status: "malformed", message: "coverage document shape is not supported", tool_version: probe_result&.version), []]
        end

        mtime = File.mtime(full_path)
        stale = (Time.now - mtime) > freshness_window

        covered, executable = coverage_totals(normalized)

        summary = {
          "covered_lines" => covered,
          "executable_lines" => executable,
          "percent" => executable == 0 ? 100.0 : ((covered.to_f / executable) * 100).round(2),
          "stale" => stale,
          "freshness_window_seconds" => Integer(freshness_window),
          "coverage_path" => coverage_path.to_s[0, 512],
          "files" => normalized["files"],
          "_coverage_document" => normalized
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

      def detect_format(document)
        return :malformed unless document.is_a?(Hash)

        # coverage-v1 has version starting with "1" and files array
        if document["version"].is_a?(String) && document["files"].is_a?(Array)
          return :coverage_v1
        end

        # Native SimpleCov JSON: has "coverage" hash where values contain lines
        if document["coverage"].is_a?(Hash) && !document["coverage"].empty?
          sample = document["coverage"].values.first
          # Native values are hashes with "lines" key
          if sample.is_a?(Hash) && sample.key?("lines")
            return :native_simplecov
          end
        end

        # Native may have empty coverage hash (empty file)
        if document.key?("coverage") && document["coverage"].is_a?(Hash) && document["meta"].is_a?(Hash)
          return :native_simplecov
        end

        # Also consider empty coverage hash without meta but with groups
        if document.key?("coverage") && document["coverage"].is_a?(Hash) && document["coverage"].empty?
          # Could be native empty or malformed; treat as native if meta or groups present
          return :native_simplecov if document.key?("meta") || document.key?("groups")
          # Fallback: if no files and no version, it's unsupported rather than malformed
          return :unsupported
        end

        # If document has no recognizable shape but is Hash with coverage key mismatched
        if document.key?("coverage") || document.key?("meta") || document.key?("groups")
          return :native_simplecov if document["coverage"].is_a?(Hash)
        end

        # If it has version but not files, or files but wrong shape => unsupported/malformed via validator
        if document.key?("version") || document.key?("files") || document.key?("timestamp")
          # Let schema validation decide malformed vs unsupported
          # If version exists but not starting 1 => unsupported
          if document["version"].is_a?(String) && !document["version"].start_with?("1")
            return :unsupported
          end
          return :malformed if document.key?("files") || document.key?("version")
        end

        :unsupported
      end

      def extract_native_version(document)
        meta = document["meta"]
        if meta.is_a?(Hash) && meta["simplecov_version"].is_a?(String) && !meta["simplecov_version"].empty?
          return meta["simplecov_version"].to_s[0, 64]
        end
        if document["version"].is_a?(String) && !document["version"].empty?
          return document["version"].to_s[0, 64]
        end
        # Default for native without explicit version
        "1.0"
      end

      def normalize_native_document(document, repository_root)
        coverage_hash = document["coverage"]
        raise MalformedOutput, "native SimpleCov document has no coverage hash" unless coverage_hash.is_a?(Hash)

        files = []
        coverage_hash.keys.sort.each do |raw_path|
          entry = coverage_hash[raw_path]
          raise MalformedOutput, "coverage entry for #{raw_path} must be an object" unless entry.is_a?(Hash)

          lines_raw = entry["lines"]
          raise MalformedOutput, "coverage lines for #{raw_path} must be an array" unless lines_raw.is_a?(Array)

          lines = lines_raw.map do |hit|
            case hit
            when Integer
              hit >= 0 ? hit : (raise MalformedOutput, "negative coverage hit")
            when NilClass
              nil
            when String
              # SimpleCov uses "ignored" for skipped lines
              hit == "ignored" ? nil : (raise MalformedOutput, "unexpected string in coverage lines: #{hit.inspect}")
            else
              raise MalformedOutput, "coverage lines must be integers, null, or \"ignored\""
            end
          end

          filename = normalize_native_path(raw_path, repository_root)

          # Skip empty paths after normalization
          raise MalformedOutput, "normalized path is empty for #{raw_path}" if filename.empty?
          unless filename.match?(RailVerdict::Finding::LOCATION_PATH_PATTERN)
            raise MalformedOutput, "coverage filename is not a clean repository-relative path: #{filename.inspect}"
          end

          files << { "filename" => filename, "coverage" => { "lines" => lines } }
        end

        files.sort_by! { |f| f["filename"] }

        {
          "version" => "1.0",
          "timestamp" => document["timestamp"].is_a?(Integer) ? document["timestamp"] : Time.now.to_i,
          "files" => files
        }
      end

      def normalize_native_path(raw_path, repository_root)
        str = raw_path.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").scrub("?").strip
        str = str.delete("\u0000")
        # Remove leading ./ 
        str = str.delete_prefix("./")
        # If absolute, make relative to repository_root if possible
        if str.start_with?("/")
          begin
            root = File.realpath(repository_root)
            abs = File.expand_path(str)
            # Use Pathname relative if inside root
            require "pathname"
            rel = Pathname.new(abs).relative_path_from(Pathname.new(root)).to_s rescue nil
            if rel && !rel.start_with?("..") && rel.match?(RailVerdict::Finding::LOCATION_PATH_PATTERN)
              return rel
            end
          rescue StandardError
            nil
          end
          # Fallback: strip leading slash
          str = str.delete_prefix("/")
        end
        # Normalize redundant separators and strip
        str = str.gsub(%r{//+}, "/")
        str = str.strip
        str
      end

      def normalize_coverage_v1(document)
        # Already validated; ensure deterministic ordering by filename
        files = document["files"].map do |f|
          { "filename" => f["filename"].to_s, "coverage" => { "lines" => f.dig("coverage", "lines") } }
        end.sort_by { |f| f["filename"] }
        {
          "version" => document["version"].to_s,
          "timestamp" => document["timestamp"],
          "files" => files
        }
      end

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
