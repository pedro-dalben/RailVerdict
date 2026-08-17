# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "timeout"

class TestMCPProtocol < Minitest::Test
  def mcp_roundtrip(requests, timeout_s: 10)
    stdin_w, stdout_r, stderr_r, wait_thr = Open3.popen3("bundle", "exec", "railverdict", "mcp", "serve")
    stdin_w.set_encoding("UTF-8")
    stdout_r.set_encoding("UTF-8")
    begin
      requests.each { |line| stdin_w.puts(line) }
      stdin_w.flush
      stdin_w.close
      resps = []
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_s
      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        ready = IO.select([stdout_r], nil, nil, 0.2)
        if ready
          line = stdout_r.gets
          break unless line
          next if line.strip.empty?

          resps << (JSON.parse(line.strip) rescue nil)
          break if resps.compact.size >= requests.size
        end
        break if wait_thr.status == false && resps.compact.size >= 1
      end
      resps.compact
    ensure
      stdout_r.close rescue nil
      stderr_r.close rescue nil
      Process.kill("TERM", wait_thr.pid) rescue nil
      wait_thr.join(1) rescue nil
    end
  end

  def test_initialize_returns_capabilities
    lines = [JSON.generate({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "test", version: "0" } } })]
    out = mcp_roundtrip(lines)
    resp = out.find { |o| o && o["id"] == 1 }
    assert resp, "no response for initialize: #{out.inspect}"
    assert_equal "2025-11-25", resp["result"]["protocolVersion"]
    assert_equal "railverdict", resp["result"]["serverInfo"]["name"]
    assert resp["result"]["capabilities"]["tools"]
  end

  def test_unknown_tool_returns_invalid_params
    lines = [
      JSON.generate({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "test", version: "0" } } }),
      JSON.generate({ jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "nope", arguments: {} } })
    ]
    out = mcp_roundtrip(lines)
    resp = out.find { |o| o && o["id"] == 2 }
    assert resp, "no response for unknown tool: #{out.inspect}"
    assert_equal(-32602, resp["error"]["code"])
  end

  def test_verify_base_without_changed_is_error_not_protocol_error
    lines = [
      JSON.generate({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "test", version: "0" } } }),
      JSON.generate({ jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "verify", arguments: { base: "abc1234" } } })
    ]
    out = mcp_roundtrip(lines)
    resp = out.find { |o| o && o["id"] == 2 }
    assert resp, "no response: #{out.inspect}"
    assert_equal true, resp["result"]["isError"]
    assert_equal "invalid_arguments", resp["result"]["structuredContent"]["code"]
  end

  def test_stdout_purity
    lines = [
      JSON.generate({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "test", version: "0" } } }),
      JSON.generate({ jsonrpc: "2.0", id: 2, method: "ping", params: {} })
    ]
    out = mcp_roundtrip(lines)
    assert_equal 2, out.size
    out.each { |o| assert o["jsonrpc"] == "2.0" }
  end
end
