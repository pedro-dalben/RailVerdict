# frozen_string_literal: true

require_relative "test_helper"

# End-to-end exit-ladder tests for `railverdict policy` (1.7):
# 0 PASS, 1 FAIL, 2 INCOMPLETE, 3 REVIEW_REQUIRED, gate never rewritten.
class TestPolicyCommand < Minitest::Test
  CONFIG = <<~YAML
    version: 1.7
    mode: advisory
    analyzers:
      rubocop:
        enabled: false
        required: false
    engineering_policy:
      review:
        high:
          human_review: required
  YAML

  def make_repo(config: CONFIG, files: { "a.rb" => "x = 1\n" })
    dir = Dir.mktmpdir
    File.write(File.join(dir, ".railverdict.yml"), config)
    Dir.chdir(dir) do
      system("git init -b main -q 2>/dev/null")
      system("git config user.email 't@t.com' 2>/dev/null")
      system("git config user.name 'T' 2>/dev/null")
      files.each { |name, content| File.write(File.join(dir, name), content) }
      system("git add . 2>/dev/null")
      system("git commit -qm init 2>/dev/null")
      yield dir if block_given?
    end
    dir
  end

  def test_policy_pass_exits_zero_and_mirrors_gate
    with_tmpdir do |dir|
      repo = make_repo
      exit_code, stdout, _stderr = run_cli(["policy", "--format", "json", "--base", "HEAD"],
        working_directory: repo)
      assert_equal 0, exit_code
      envelope = JSON.parse(stdout)
      assert_equal "PASS", envelope["decision"]
      assert_equal envelope["gate"], "PASS"
      FileUtils.remove_entry(repo)
    end
  end

  def test_policy_review_required_exits_three_without_touching_gate
    with_tmpdir do |dir|
      repo = make_repo do |inner|
        Dir.chdir(inner) do
          FileUtils.mkdir_p("db/migrate")
          File.write("db/migrate/001_x.rb", "m\n")
          system("git add . 2>/dev/null")
          system("git commit -qm migration 2>/dev/null")
        end
      end
      exit_code, stdout, _stderr = run_cli(["policy", "--format", "json", "--base", "HEAD~1"],
        working_directory: repo)
      assert_equal 3, exit_code
      envelope = JSON.parse(stdout)
      assert_equal "REVIEW_REQUIRED", envelope["decision"]
      assert_equal "PASS", envelope["gate"]
      review = envelope["requirements"].find { |entry| entry["kind"] == "human_review" }
      assert_equal "review_required", review["status"]
      FileUtils.remove_entry(repo)
    end
  end

  def test_policy_without_configuration_exits_no_gate
    with_tmpdir do |dir|
      Dir.chdir(dir) do
        system("git init -b main -q 2>/dev/null")
        File.write("a.rb", "x = 1\n")
        system("git add . 2>/dev/null")
      end
      exit_code, _stdout, stderr = run_cli(["policy", "--format", "json"], working_directory: dir)
      assert_equal 2, exit_code
      assert_includes stderr, "readable configuration"
    end
  end

  def test_policy_rejects_receipt_and_handoff_together
    with_tmpdir do |dir|
      repo = make_repo
      exit_code, _stdout, stderr = run_cli(
        ["policy", "--receipt", "a.json", "--handoff", "b.json"], working_directory: repo)
      assert_equal 2, exit_code
      assert_includes stderr, "only one of --receipt and --handoff"
      FileUtils.remove_entry(repo)
    end
  end
end
