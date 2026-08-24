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
        AnalyzerResult.new(
          analyzer: analyzer_id,
          tool_version: tool_version,
          invocation: invocation,
          execution_status: status,
          finding_ids: [],
          failure: { "code" => status, "message" => bounded }
        )
      end
    end
  end
end
