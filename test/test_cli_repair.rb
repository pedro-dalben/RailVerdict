# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "stringio"
require "json"

class TestCliRepair < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir
    File.write(File.join(@tmp, ".railverdict.yml"), <<~YAML)
      version: 1.4
      mode: strict
      analyzers:
        rubocop: { enabled: true, required: true }
    YAML
  end

  def teardown
    FileUtils.remove_entry(@tmp) if Dir.exist?(@tmp)
  end

  def run_cli(args)
    out = StringIO.new
    err = StringIO.new
    cli = RailVerdict::CLI.new(stdout: out, stderr: err, working_directory: @tmp)
    code = cli.run(args)
    [code, out.string, err.string]
  end

  def test_unknown_finding_returns_2
    FileUtils.mkdir_p(File.join(@tmp, "app/models"))
    File.write(File.join(@tmp, "app/models/book.rb"), "x=1\n")
    code, _out, err = run_cli(["repair", "rv:deadbeefdeadbeefdead", "--format", "json"])
    assert_equal 2, code
    assert_match(/finding not found/, err)
  end

  def test_base_requires_changed
    code, _out, err = run_cli(["repair", "rv:abc", "--base", "abc"])
    assert_equal 2, code
    assert_match(/--base requires --changed/, err)
  end

  def test_invalid_format
    code, _out, err = run_cli(["repair", "rv:abc", "--format", "xml"])
    assert_equal 2, code
  end
end
