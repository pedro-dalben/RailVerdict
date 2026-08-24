# frozen_string_literal: true

module RailVerdict
  module Analyzers
    module Shared
      module_function

      def bounded_message(message)
        message.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")[0, 4096]
      end

      def detail_for(run_result)
        detail = run_result.detail.to_s
        stderr = run_result.stderr.to_s.lines.first.to_s.strip
        combined = [detail, stderr].reject(&:empty?).join(": ")
        if combined.empty?
          combined = if run_result.status == :exited
            "analyzer exited with status #{run_result.exit_code} and produced no diagnostic output"
          else
            "analyzer produced no diagnostic output"
          end
        end
        bounded_message(combined)
      end

      def execution_message(run_result)
        message = run_result.stderr.to_s.lines.first.to_s.strip
        message = "#{run_result.detail}" if message.empty?
        message = "execution failed with status #{run_result.exit_code}" if message.empty?
        bounded_message(message)
      end

      def truncated?(run_result)
        run_result.stdout_truncated || run_result.stderr_truncated
      end

      def parse_semver(output)
        match = output.to_s.match(/\b(\d+\.\d+\.\d+)\b/)
        match && match[1]
      end

      def invocation_for(command, arguments)
        {
          "executable" => command.fetch(:executable),
          "argv" => command.fetch(:args_prefix).dup.concat(arguments)
        }
      end

      def failure_result(analyzer_id:, invocation:, status:, message:, tool_version: nil)
        status = status.to_s
        bounded = bounded_message(message.to_s)
        bounded = "#{status}: analyzer produced no diagnostic output" if bounded.strip.empty?
        normalized_version = normalize_tool_version(tool_version)
        AnalyzerResult.new(
          analyzer: analyzer_id,
          tool_version: normalized_version,
          invocation: invocation,
          execution_status: status,
          finding_ids: [],
          failure: { "code" => status, "message" => bounded }
        )
      end

      def normalize_tool_version(version)
        return nil if version.nil?
        str = version.to_s.strip
        return nil if str.empty?
        str.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").scrub("?")[0, 128]
      end

      def canonical_tool_version(version)
        normalized = normalize_tool_version(version)
        normalized.nil? || normalized.empty? ? "unknown" : normalized
      end

      # Canonical finding message normalization — single path for all analyzers.
      # Guarantees deterministic, bounded, valid non-empty UTF-8.
      FALLBACK_MESSAGE_SUFFIX = "reported a finding without a message"

      def normalize_finding_message(analyzer_id, raw_message)
        raw = raw_message.to_s.dup
        # Handle invalid UTF-8, null bytes
        raw = raw.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD")
        raw = raw.scrub("\uFFFD")
        raw = raw.delete("\u0000")
        # Strip ANSI escape sequences
        raw = raw.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
        raw = raw.gsub(/\e\][^\a]*\a/, "")
        raw = raw.gsub(/\e\(B/, "")
        # Remove control characters except tab/newline then normalize whitespace
        raw = raw.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")
        raw = raw.strip
        # Collapse whitespace including tabs/newlines
        raw = raw.gsub(/\s+/, " ").strip
        if raw.empty?
          "#{analyzer_id} #{FALLBACK_MESSAGE_SUFFIX}"
        else
          raw = raw.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD").scrub("\uFFFD")
          raw.bytesize > 4096 ? raw.byteslice(0, 4096).scrub("\uFFFD").strip : raw
        end
      end
    end
  end
end
