# frozen_string_literal: true

module RailVerdict
  module Git
    module Command
      module_function

      GIT_EXECUTABLE = "git"

      def run(argv, chdir:, timeout_seconds: 5.0, max_stdout_bytes: 524288, max_stderr_bytes: 65536, runner: ProcessRunner)
        argv.each do |element|
          raise ArgumentError, "git argv elements must be strings" unless element.is_a?(String)
          raise ArgumentError, "git argv elements cannot contain NUL bytes" if element.include?("\0")
        end
        runner.run(GIT_EXECUTABLE, argv, chdir: chdir, timeout_seconds: timeout_seconds, max_stdout_bytes: max_stdout_bytes, max_stderr_bytes: max_stderr_bytes)
      end

      def interpret(result, chdir:)
        case result.status
        when :spawn_failed
          raise Git::Unavailable, "git is not available: #{result.detail}"
        when :timed_out
          raise Git::Timeout, "git operation timed out"
        when :truncated
          raise Git::Truncated, "git output was truncated"
        when :signaled
          raise Git::Error, "git terminated by signal #{result.signal}"
        when :exited
          result
        else
          raise Git::Error, "unexpected git result: #{result.status}"
        end
        if result.stdout_truncated || result.stderr_truncated
          raise Git::Truncated, "git output was truncated"
        end
        result
      end

      def require_success(result, context_message: "git command failed")
        return if result.exit_code == 0

        stderr = result.stderr.to_s.strip
        suffix = stderr.empty? ? "" : " (#{stderr[0, 1024]})"
        raise Git::Error, "#{context_message}: exit #{result.exit_code}#{suffix}"
      end
    end
  end
end
