# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "fileutils"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "rail_verdict"

module RailVerdictTestHelpers
  REPOSITORY_ROOT = File.expand_path("..", __dir__)

  def run_cli(argv, working_directory: Dir.pwd)
    stdout = StringIO.new
    stderr = StringIO.new
    cli = RailVerdict::CLI.new(stdout: stdout, stderr: stderr, working_directory: working_directory)
    exit_code = cli.run(argv)
    [exit_code, stdout.string, stderr.string]
  end

  def with_tmpdir
    Dir.mktmpdir("railverdict-test-") do |dir|
      yield File.realpath(dir)
    end
  end
end

Minitest::Test.include(RailVerdictTestHelpers)
