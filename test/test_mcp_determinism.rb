# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "tmpdir"
require "timeout"

class TestMCPDeterminism < Minitest::Test
  def mcp_verify(tmp)
    stdin_w, stdout_r, stderr_r, wait_thr = Open3.popen3("bundle", "exec", "railverdict", "mcp", "serve", "--repository-root", tmp)
    stdin_w.set_encoding("UTF-8")
    stdout_r.set_encoding("UTF-8")
    begin
      stdin_w.puts(JSON.generate({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "test", version: "0" } } }))
      stdin_w.puts(JSON.generate({ jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "verify", arguments: {} } }))
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
      resp = resps.compact.find { |o| o["id"] == 2 }
      resp["result"]["structuredContent"]
    ensure
      stdout_r.close rescue nil
      stderr_r.close rescue nil
      Process.kill("TERM", wait_thr.pid) rescue nil
      wait_thr.join(1) rescue nil
    end
  end

  def test_verify_deterministic_across_calls
    Dir.mktmpdir do |tmp|
      tmp = File.realpath(tmp)
      File.write(File.join(tmp, ".railverdict.yml"), "version: 1.4\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: false }\n")
      a = mcp_verify(tmp)
      b = mcp_verify(tmp)
      assert_equal a["gate"], b["gate"]
      assert_equal a["completion_status"], b["completion_status"]
      assert_equal a["policy_status"], b["policy_status"]
      assert_equal JSON.generate(a["findings"].sort_by { |f| f["fingerprint"] }), JSON.generate(b["findings"].sort_by { |f| f["fingerprint"] })
    end
  end

  def test_fail_is_not_protocol_error
    Dir.mktmpdir do |tmp|
      tmp = File.realpath(tmp)
      File.write(File.join(tmp, ".railverdict.yml"), "version: 1.4\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: false }\n")
      stdin_w, stdout_r, stderr_r, wait_thr = Open3.popen3("bundle", "exec", "railverdict", "mcp", "serve", "--repository-root", tmp)
      begin
        stdin_w.set_encoding("UTF-8")
        stdout_r.set_encoding("UTF-8")
        stdin_w.puts(JSON.generate({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "test", version: "0" } } }))
        stdin_w.puts(JSON.generate({ jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "verify", arguments: {} } }))
        stdin_w.flush
        stdin_w.close
        resps = []
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
        while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
          ready = IO.select([stdout_r], nil, nil, 0.2)
          if ready
            line = stdout_r.gets
            break unless line

            resps << (JSON.parse(line.strip) rescue nil)
            break if resps.compact.any? { |o| o["id"] == 2 }
          end
        end
        resp = resps.compact.find { |o| o["id"] == 2 }
        assert_equal false, resp["result"]["isError"]
        assert_nil resp["error"]
      ensure
        stdout_r.close rescue nil
        stderr_r.close rescue nil
        Process.kill("TERM", wait_thr.pid) rescue nil
        wait_thr.join(1) rescue nil
      end
    end
  end
end
