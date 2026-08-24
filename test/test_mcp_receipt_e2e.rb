# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "timeout"

class TestMcpReceiptE2E < Minitest::Test
  def mcp_session(tmp)
    stdin_w, stdout_r, stderr_r, wait_thr = Open3.popen3(
      RbConfig.ruby, "-I", File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "lib"),
      File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "exe", "railverdict"),
      "mcp", "serve", "--repository-root", tmp
    )
    stdin_w.set_encoding("UTF-8")
    stdout_r.set_encoding("UTF-8")
    exhaust = ->(io) { Thread.new { io.read rescue nil } }
    _t = exhaust.call(stderr_r)

    send_req = lambda do |method, params, id|
      msg = { jsonrpc: "2.0", id: id, method: method }
      msg[:params] = params if params
      stdin_w.puts(JSON.generate(msg))
      stdin_w.flush
    end

    read_resp = lambda do |expected_id, timeout_s: 15|
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_s
      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        ready = IO.select([stdout_r], nil, nil, 0.1)
        next unless ready

        line = stdout_r.gets
        next unless line

        obj = JSON.parse(line.strip) rescue next
        return obj if obj["id"] == expected_id
      end
      flunk "timeout waiting for response id=#{expected_id}"
    end

    [stdin_w, stdout_r, wait_thr, send_req, read_resp]
  end

  def tool_result(response)
    payload = response.dig("result", "structuredContent") || {}
    unless payload["status"] || payload["gate"]
      text = response.dig("result", "content", 0, "text")
      payload = JSON.parse(text) if text.is_a?(String) && !text.empty?
    end
    payload
  end

  def test_stdio_verify_receipt_and_stale_cycle
    Dir.mktmpdir do |tmp|
      tmp = File.realpath(tmp)
      File.binwrite(File.join(tmp, ".railverdict.yml"), "version: 1\nmode: strict\nanalyzers:\n  rubocop: { enabled: false, required: false }\n")
      File.binwrite(File.join(tmp, "app.rb"), "puts 1\n")
      system("git", "-C", tmp, "init", "-q", "-b", "main", out: File::NULL, err: File::NULL)
      system("git", "-C", tmp, "config", "user.email", "t@t.invalid", out: File::NULL, err: File::NULL)
      system("git", "-C", tmp, "config", "user.name", "T", out: File::NULL, err: File::NULL)
      system("git", "-C", tmp, "add", "-A", out: File::NULL, err: File::NULL)
      system("git", "-C", tmp, "commit", "-q", "-m", "init", out: File::NULL, err: File::NULL)

      stdin_w, _stdout_r, wait_thr, send_req, read_resp = mcp_session(tmp)
      begin
        send_req.call("initialize", { "protocolVersion" => "2025-11-25", "capabilities" => {}, "clientInfo" => { "name" => "test", "version" => "0" } }, 1)
        read_resp.call(1)
        send_req.call("notifications/initialized", {}, nil)

        send_req.call("tools/list", {}, 2)
        listed = read_resp.call(2)
        names = listed.dig("result", "tools").map { |t| t["name"] }
        assert_includes names, "get_verification_receipt"
        assert_includes names, "get_pr_intelligence"

        send_req.call("tools/call", { "name" => "verify", "arguments" => {} }, 3)
        verify_payload = tool_result(read_resp.call(3))
        assert_equal "PASS", verify_payload["gate"]
        receipt = verify_payload["verification_receipt"]
        assert receipt.is_a?(Hash)
        assert_match(/\Asha256:[0-9a-f]{64}\z/, receipt["receipt_id"])

        send_req.call("tools/call", { "name" => "get_verification_receipt", "arguments" => {} }, 4)
        fresh = tool_result(read_resp.call(4))
        assert_equal "fresh", fresh["status"]
        assert_equal receipt["receipt_id"], fresh.dig("receipt", "receipt_id")

        # mutate repository -> cached evidence must be refused as stale
        File.binwrite(File.join(tmp, "app.rb"), "puts 2\n")
        send_req.call("tools/call", { "name" => "get_verification_receipt", "arguments" => {} }, 5)
        stale = tool_result(read_resp.call(5))
        assert_equal "verification_required", stale["status"]
        assert_equal "stale_receipt", stale["code"]

        send_req.call("tools/call", { "name" => "verify", "arguments" => {} }, 6)
        refreshed = tool_result(read_resp.call(6))
        refute_equal receipt["receipt_id"], refreshed.dig("verification_receipt", "receipt_id")

        send_req.call("tools/call", { "name" => "get_verification_receipt", "arguments" => {} }, 7)
        fresh_again = tool_result(read_resp.call(7))
        assert_equal "fresh", fresh_again["status"]
      ensure
        stdin_w.close rescue nil
        wait_thr.terminate rescue nil
      end
    end
  end
end
