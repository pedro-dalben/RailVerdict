# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "tmpdir"
require "fileutils"
require "timeout"

class TestMCPSecurity < Minitest::Test
  def mcp_call(tmp, method, params, id: 2)
    stdin_w, stdout_r, stderr_r, wait_thr = Open3.popen3("bundle", "exec", "railverdict", "mcp", "serve", "--repository-root", tmp)
    stdin_w.set_encoding("UTF-8")
    stdout_r.set_encoding("UTF-8")
    begin
      stdin_w.puts(JSON.generate({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "test", version: "0" } } }))
      stdin_w.puts(JSON.generate({ jsonrpc: "2.0", id: id, method: method, params: params }))
      stdin_w.flush
      stdin_w.close
      resps = []
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        ready = IO.select([stdout_r], nil, nil, 0.2)
        if ready
          line = stdout_r.gets
          break unless line
          next if line.strip.empty?

          resps << (JSON.parse(line.strip) rescue nil)
          break if resps.compact.any? { |o| o["id"] == id }
        end
        break if wait_thr.status == false
      end
      resps.compact.find { |o| o["id"] == id }
    ensure
      stdout_r.close rescue nil
      stderr_r.close rescue nil
      Process.kill("TERM", wait_thr.pid) rescue nil
      wait_thr.join(1) rescue nil
    end
  end

  def mcp_tools_list(tmp)
    stdin_w, stdout_r, stderr_r, wait_thr = Open3.popen3("bundle", "exec", "railverdict", "mcp", "serve", "--repository-root", tmp)
    stdin_w.set_encoding("UTF-8")
    stdout_r.set_encoding("UTF-8")
    begin
      stdin_w.puts(JSON.generate({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "test", version: "0" } } }))
      stdin_w.puts(JSON.generate({ jsonrpc: "2.0", id: 2, method: "tools/list", params: {} }))
      stdin_w.flush
      stdin_w.close
      resps = []
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        ready = IO.select([stdout_r], nil, nil, 0.2)
        if ready
          line = stdout_r.gets
          break unless line
          next if line.strip.empty?

          resps << (JSON.parse(line.strip) rescue nil)
          break if resps.compact.any? { |o| o["id"] == 2 }
        end
      end
      resps.compact.find { |o| o["id"] == 2 }
    ensure
      stdout_r.close rescue nil
      stderr_r.close rescue nil
      Process.kill("TERM", wait_thr.pid) rescue nil
      wait_thr.join(1) rescue nil
    end
  end

  def with_repo
    Dir.mktmpdir do |tmp|
      tmp = File.realpath(tmp)
      File.write(File.join(tmp, ".railverdict.yml"), "version: 1.4\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: false }\n")
      yield tmp
    end
  end

  def test_config_path_escape_rejected
    with_repo do |tmp|
      resp = mcp_call(tmp, "tools/call", { name: "verify", arguments: { config_path: "../../etc/passwd" } })
      assert_equal true, resp["result"]["isError"]
      assert_equal "invalid_arguments", resp["result"]["structuredContent"]["code"]
    end
  end

  def test_absolute_config_path_outside_root_rejected
    with_repo do |tmp|
      resp = mcp_call(tmp, "tools/call", { name: "verify", arguments: { config_path: "/etc/passwd" } })
      assert_equal true, resp["result"]["isError"]
    end
  end

  def test_finding_ref_with_nul_rejected
    with_repo do |tmp|
      resp = mcp_call(tmp, "tools/call", { name: "get_finding", arguments: { finding_ref: "rv:abc\u0000def" } })
      assert resp["result"]["isError"] || resp["error"]
    end
  end

  def test_finding_ref_oversized_rejected
    with_repo do |tmp|
      big = "rv:" + "a" * 1000
      resp = mcp_call(tmp, "tools/call", { name: "get_finding", arguments: { finding_ref: big } })
      assert_equal true, resp["result"]["isError"]
    end
  end

  def test_finding_ref_malformed_rejected
    with_repo do |tmp|
      resp = mcp_call(tmp, "tools/call", { name: "get_finding", arguments: { finding_ref: "not-a-ref" } })
      assert_equal true, resp["result"]["isError"]
    end
  end

  def test_base_shell_metachars_rejected
    with_repo do |tmp|
      resp = mcp_call(tmp, "tools/call", { name: "verify", arguments: { changed: true, base: "; rm -rf /" } })
      assert_equal true, resp["result"]["isError"]
      assert_equal "invalid_arguments", resp["result"]["structuredContent"]["code"]
    end
  end

  def test_limit_exceeds_max_rejected
    with_repo do |tmp|
      resp = mcp_call(tmp, "tools/call", { name: "list_findings", arguments: { limit: 101 } })
      assert_equal true, resp["result"]["isError"]
    end
  end

  def test_unknown_tool_no_exec
    with_repo do |tmp|
      resp = mcp_call(tmp, "tools/call", { name: "exec", arguments: { cmd: "whoami" } })
      assert resp["error"]
      assert_equal(-32602, resp["error"]["code"])
    end
  end

  def test_ai_disabled_still_verify_offline
    with_repo do |tmp|
      resp1 = mcp_call(tmp, "tools/call", { name: "explain", arguments: { finding_ref: "rv:" + "a" * 20 } })
      assert_equal true, resp1["result"]["isError"]
      assert_equal "ai_disabled", resp1["result"]["structuredContent"]["code"]

      resp2 = mcp_call(tmp, "tools/call", { name: "verify", arguments: {} })
      assert_equal false, resp2["result"]["isError"]
      assert_includes %w[PASS WARN FAIL INCOMPLETE], resp2["result"]["structuredContent"]["gate"]
    end
  end

  def test_no_baseline_or_waiver_creation_tools
    with_repo do |tmp|
      resp = mcp_tools_list(tmp)
      tools = resp["result"]["tools"].map { |t| t["name"] }
      refute_includes tools, "baseline_create"
      refute_includes tools, "waiver_create"
      refute_includes tools, "exec"
      refute_includes tools, "read_file"
      refute_includes tools, "edit"
    end
  end

  def test_annotations_readonly
    with_repo do |tmp|
      resp = mcp_tools_list(tmp)
      tools = resp["result"]["tools"]
      tools.each do |t|
        assert_equal true, t["annotations"]["readOnlyHint"], "tool #{t['name']} should be readOnly"
        assert_equal false, t["annotations"]["destructiveHint"]
      end
    end
  end
end
