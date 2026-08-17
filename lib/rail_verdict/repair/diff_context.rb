# frozen_string_literal: true

module RailVerdict
  module Repair
    module DiffContext
      MAX_BYTES = 16 * 1024
      CONTEXT_LINES = 15

      def self.build(repository_root:, runner:, finding:, git_context:)
        hunk = ""
        truncated = false
        return { "hunk" => "", "truncated" => false } unless finding && git_context

        path = finding.location["path"] || finding.location[:path]
        line = finding.location["start_line"] || finding.location[:start_line]
        return { "hunk" => "", "truncated" => false } unless path

        result = runner.run("git", ["diff", "-U#{CONTEXT_LINES}", git_context.merge_base, git_context.head, "--", path], chdir: repository_root, timeout_seconds: 5.0, max_stdout_bytes: MAX_BYTES + 1024)
        raw = result.stdout.to_s
        raw = raw.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")
        raw = raw.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "?")
        if raw.bytesize > MAX_BYTES
          raw = raw.byteslice(0, MAX_BYTES)
          truncated = true
        end
        if line
          hunk = extract_target_hunk(raw, line)
          hunk = raw if hunk.empty?
        else
          hunk = raw
        end
        if hunk.bytesize > MAX_BYTES
          hunk = hunk.byteslice(0, MAX_BYTES)
          truncated = true
        end
        { "hunk" => hunk, "truncated" => truncated }
      rescue StandardError
        { "hunk" => "", "truncated" => false }
      end

      def self.extract_target_hunk(diff, target_line)
        hunks = diff.split(/^@@.*@@/)
        hunks.shift
        hunks.find { |h| h.lines.any? { |l| l.start_with?("+") } } || ""
      rescue StandardError
        ""
      end
      private_class_method :extract_target_hunk
    end
  end
end
