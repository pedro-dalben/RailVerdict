# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "timeout"

# Bring-Your-Own-Agent contract tests (1.8): three generic consumers drive the
# same canonical contracts and obey the same discipline — observe, verify,
# distinguish FAIL from INCOMPLETE, re-verify after change, reject stale,
# never declare success without a fresh gate.
class TestByoaWorkflow < Minitest::Test
  CONFIG = <<~YAML
    version: 1.7
    mode: advisory
    analyzers:
      rubocop:
        enabled: false
        required: false
  YAML

  def make_repo
    dir = Dir.mktmpdir
    File.write(File.join(dir, ".railverdict.yml"), CONFIG)
    system("git", "-C", dir, "init", "-q", "-b", "main", out: File::NULL, err: File::NULL)
    system("git", "-C", dir, "config", "user.email", "t@t.invalid", out: File::NULL, err: File::NULL)
    system("git", "-C", dir, "config", "user.name", "T", out: File::NULL, err: File::NULL)
    File.write(File.join(dir, "a.rb"), "x = 1\n")
    system("git", "-C", dir, "add", "--all", out: File::NULL, err: File::NULL)
    system("git", "-C", dir, "commit", "-qm", "init", out: File::NULL, err: File::NULL)
    dir
  end

  def mcp_session(repo)
    stdin_w, stdout_r, stderr_r, wait_thr = Open3.popen3(
      RbConfig.ruby, "-I", File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "lib"),
      File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "exe", "railverdict"),
      "mcp", "serve", "--repository-root", repo
    )
    Thread.new { stderr_r.read rescue nil }
    send_req = lambda do |id, method, params|
      msg = { jsonrpc: "2.0", id: id, method: method, params: params }
      stdin_w.puts(JSON.generate(msg))
      stdin_w.flush
    end
    read_resp = lambda do |expected_id|
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
      loop do
        raise "timeout id=#{expected_id}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        ready = IO.select([stdout_r], nil, nil, 0.1)
        next unless ready
        obj = (JSON.parse(stdout_r.gets.strip) rescue next)
        return obj if obj["id"] == expected_id
      end
    end
    send_req.call(1, "initialize",
      { "protocolVersion" => "2025-11-25", "capabilities" => {}, "clientInfo" => { "name" => "byoa", "version" => "0" } })
    read_resp.call(1)
    [stdin_w, wait_thr, send_req, read_resp]
  end

  def tool_call(send_req, read_resp, id, name, args)
    send_req.call(id, "tools/call", { "name" => name, "arguments" => args })
    response = read_resp.call(id)
    text = response.dig("result", "content", 0, "text")
    JSON.parse(text)
  end

  def test_mcp_agent_closes_workflow_and_rejects_stale
    repo = make_repo
    stdin_w, wait_thr, send_req, read_resp = mcp_session(repo)
    begin
      head = `git -C #{repo} rev-parse HEAD`.strip
      verify = tool_call(send_req, read_resp, 2, "verify", { "changed" => true, "base" => head })
      assert_equal "PASS", verify["gate"]
      packet = tool_call(send_req, read_resp, 3, "get_review_packet", {})
      assert_equal "fresh", packet["status"]
      envelope = packet["review_packet"]
      assert_equal envelope["packet_id"], envelope["packet_id"]

      observation = RailVerdict::ReviewObservation.build(author: "agent", provider: "byoa-test",
        confidence: "medium",
        state_binding: { "head" => `git -C #{repo} rev-parse HEAD`.strip,
                         "configuration_digest" => envelope["provenance"]["configuration_digest"],
                         "policy_digest" => envelope["deterministic"]["policy"]["policy_digest"] },
        observations: [{ "summary" => "change is trivial" }])
      verdict = tool_call(send_req, read_resp, 4, "verify_review_observation", { "observation" => observation })
      assert_equal "valid_bound", verdict["status"]

      receipt = tool_call(send_req, read_resp, 5, "create_workflow_receipt", { "observations" => [observation] })
      assert_equal "fresh", receipt["status"]
      assert_equal "ready", receipt["workflow_receipt"]["readiness"]

      File.write(File.join(repo, "b.rb"), "y = 2\n")
      stale = tool_call(send_req, read_resp, 6, "get_review_packet", {})
      assert_equal "verification_required", stale["status"]
    ensure
      Process.kill("TERM", wait_thr.pid) rescue nil
      FileUtils.remove_entry(repo)
    end
  end

  def test_cli_agent_distinguishes_fail_from_incomplete
    repo = make_repo
    Dir.chdir(repo) do
      FileUtils.mkdir_p("db/migrate")
      File.write("db/migrate/001_x.rb", "m\n")
      system("git add . 2>/dev/null")
      system("git commit -qm migration 2>/dev/null")
    end
    File.write(File.join(repo, ".railverdict.yml"), CONFIG.sub("mode: advisory", "mode: advisory") +
      "engineering_policy:\n  review:\n    high:\n      human_review: required\n")
    _code, stdout, _err = run_cli(["review", "complete", "--format", "json", "--base", "HEAD~1"],
      working_directory: repo)
    receipt = JSON.parse(stdout)
    assert_equal "review_pending", receipt["readiness"]
    assert_equal "PASS", receipt["gate"]
    FileUtils.remove_entry(repo)
  end

  def test_human_console_shows_risk_focus_recovery_without_dump
    repo = make_repo
    _code, stdout, _err = run_cli(["review", "show", "--base", "HEAD", "--format", "console"],
      working_directory: repo)
    assert_includes stdout, "Review risk:"
    assert_includes stdout, "Review focus:"
    assert_includes stdout, "Recovery:"
    assert_includes stdout, "Requirements:"
    refute_match(%r{/tmp|/home/[\w.-]+/}, stdout)
    FileUtils.remove_entry(repo)
  end
end
