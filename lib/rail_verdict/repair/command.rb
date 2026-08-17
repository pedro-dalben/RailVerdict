# frozen_string_literal: true

require "json"
require "fileutils"
require "tempfile"

module RailVerdict
  module Repair
    class Command
      def self.execute(repository_root:, config_path:, finding_ref:, format: "console", output_path: nil, changed: false, base: nil, baseline_override: nil, waiver_override: nil, stdout: $stdout, stderr: $stderr)
        outcome, interrupted = run_check(repository_root: repository_root, config_path: config_path, changed: changed, base: base, baseline_override: baseline_override, waiver_override: waiver_override)
        return [130, nil] if interrupted || outcome.result.completion_status == "interrupted"

        begin
          packet = ContextAssembler.build(outcome: outcome, finding_ref: finding_ref, repository_root: repository_root)
        rescue ContextAssembler::StaleFindingError => e
          stderr.puts "railverdict repair: #{e.message}"
          return [2, nil]
        rescue ArgumentError => e
          stderr.puts "railverdict repair: #{e.message}"
          return [2, nil]
        end

        hash = packet.to_h

        if output_path
          write_atomic(output_path, hash, stderr)
          return [2, nil] unless File.file?(output_path)
        end

        if format == "json"
          stdout.write(JSON.generate(hash) + "\n")
        else
          stdout.write(render_console(hash))
        end
        [0, packet]
      end

      def self.run_check(repository_root:, config_path:, changed:, base:, baseline_override:, waiver_override:)
        interrupted = false
        previous = Signal.trap("INT") do
          interrupted = true
          RailVerdict::ProcessRunner.registry.terminate_all
        end
        opts = { repository_root: repository_root, config_path: config_path, interrupted: -> { interrupted } }
        opts[:changed] = changed if changed
        opts[:base] = base if base
        opts[:baseline_path_override] = baseline_override if baseline_override
        opts[:waiver_path_override] = waiver_override if waiver_override
        outcome = Check.execute(**opts)
        [outcome, interrupted]
      ensure
        Signal.trap("INT", previous) if previous
      end
      private_class_method :run_check

      def self.write_atomic(path, hash, stderr)
        dir = File.dirname(File.expand_path(path))
        FileUtils.mkdir_p(dir)
        tmp = "#{path}.tmp.#{Process.pid}.#{SecureRandom.hex(4)}"
        File.write(tmp, JSON.generate(hash) + "\n")
        File.chmod(0o600, tmp) rescue nil
        File.rename(tmp, path)
      rescue StandardError => e
        stderr.puts "railverdict repair: failed to write #{path}: #{e.message}"
      ensure
        File.unlink(tmp) rescue nil
      end
      private_class_method :write_atomic

      def self.render_console(hash)
        lines = []
        lines << "RepairPacket #{hash['packet_id']}"
        lines << "Target: #{hash.dig('target','finding','id')} #{hash.dig('target','finding','location','path')}:#{hash.dig('target','finding','location','start_line')}"
        lines << "Severity: #{hash.dig('target','severity')} Blocking: #{hash.dig('target','blocking')}"
        lines << "Gate: #{hash.dig('verification','gate')} Policy: #{hash.dig('verification','mode')}"
        lines << "Reason: #{hash.dig('verification','decision_reasons',0,'message')}"
        plan = hash.dig("verification_plan","required",0,"display") || "bundle exec railverdict check"
        lines << "Verify: #{plan}"
        lines << "Constraints: do not update baseline/waiver/policy; require verification"
        if hash["ai_analysis"]
          lines << "AI: #{hash.dig('ai_analysis','summary')&.slice(0, 80)}"
        end
        lines.join("\n") + "\n"
      end
      private_class_method :render_console
    end
  end
end
