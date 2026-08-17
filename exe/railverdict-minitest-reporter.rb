#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "minitest"

class RailverdictMinitestReporter < Minitest::AbstractReporter
  def initialize(output_path)
    @output_path = output_path
    @results = []
    @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def record(result)
    status =
      if result.skipped?
        "skipped"
      elsif result.error?
        "errored"
      elsif result.failure
        "failed"
      else
        "passed"
      end

    failure = result.failure
    entry = {
      "class_name" => result.klass.to_s,
      "method_name" => result.name.to_s,
      "status" => status,
      "time_seconds" => result.time.to_f.round(6)
    }
    if failure
      entry["failure_message"] = failure.message.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")[0, 4096]
      entry["failure_class"] = failure.class.name.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")[0, 256]
      loc = failure.location.to_s
      captures = loc.match(/\A(.+):(\d+)(\z|:\d+:\z)/)&.captures
      file = captures && captures[0]
      line_str = captures && captures[1]
      if file && line_str
        line = Integer(line_str, 10) rescue nil
        if line && line >= 1
          entry["file"] = file.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")[0, 1024]
          entry["line"] = line
        end
      end
    end
    @results << entry
  end

  def report
    duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time).round(6)
    runner = Minitest::VERSION ? "minitest #{Minitest::VERSION}" : "minitest unknown"
    seed = Minitest.respond_to?(:seed) ? Minitest.seed : nil
    failures = @results.count { |r| r["status"] == "failed" }
    errors = @results.count { |r| r["status"] == "errored" }
    skips = @results.count { |r| r["status"] == "skipped" }
    assertions = @results.count { |r| %w[passed failed errored].include?(r["status"]) }
    seed_val = seed && Integer(seed) rescue nil
    @results.sort_by! { |t| [t["class_name"], t["method_name"]] }
    document = {
      "schema_version" => "1.0",
      "runner" => runner,
      "seed" => seed_val,
      "tests_total" => @results.length,
      "assertions" => assertions,
      "failures" => failures,
      "errors" => errors,
      "skips" => skips,
      "duration_seconds" => duration,
      "tests" => @results
    }
    File.write(@output_path, JSON.generate(document))
  end
end

output_path = ENV["RAILVERDICT_MINITEST_OUTPUT"].to_s
unless output_path.empty?
  Minitest.load_plugins
  Minitest.extensions << :railverdict
  module Minitest
    class << self
      def plugin_railverdict_init(options)
        self.reporter << RailverdictMinitestReporter.new(ENV["RAILVERDICT_MINITEST_OUTPUT"].to_s)
      end

      def plugin_railverdict_options(opts, options); end
    end
  end
end
