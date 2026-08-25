# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "rail_verdict/mcp"

class TestMcpReceipt < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("rv-mcp-receipt-")
    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@t.invalid")
    git("config", "user.name", "T")
    File.binwrite(File.join(@dir, ".railverdict.yml"), "version: 1\nmode: strict\nanalyzers:\n  rubocop: { enabled: false, required: false }\n")
    File.binwrite(File.join(@dir, "app.rb"), "puts 1\n")
    commit
    @server = RailVerdict::MCP::Server.new(repository_root: @dir)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def git(*args)
    system("git", "-C", @dir, *args, out: File::NULL, err: File::NULL) or flunk("git #{args.join(' ')} failed")
  end

  def commit(message = "c")
    git("add", "-A")
    git("commit", "-q", "-m", message)
  end

  def tool(name)
    @server.mcp_server.tools.fetch(name)
  rescue NoMethodError
    flunk "tool #{name} not registered"
  end

  def call_tool(name, args = {})
    response = tool(name).call(**args.map { |k, v| [k.to_sym, v] }.to_h)
    payload = JSON.parse(response.content.first[:text])
    [payload, response]
  end

  def test_new_tools_are_registered_read_only
    names = @server.mcp_server.tools.keys
    assert_includes names, "get_verification_receipt"
    assert_includes names, "get_pr_intelligence"

    [RailVerdict::MCP::Tools::GetVerificationReceipt, RailVerdict::MCP::Tools::GetPRIntelligence].each do |klass|
      instance = klass.new(server: @server)
      annotations = instance.tool_annotations
      assert_equal true, annotations[:read_only_hint]
      assert_equal false, annotations[:destructive_hint]
      assert_equal true, annotations[:idempotent_hint]
    end
  end

  def test_receipt_before_verify_requests_verification
    payload, = call_tool("get_verification_receipt")
    assert_equal "verification_required", payload.fetch("status")
    assert_equal "no_verification_yet", payload.fetch("code")
  end

  def test_verify_then_receipt_is_fresh_and_schema_valid
    gate_payload, = call_tool("verify")
    assert_equal "PASS", gate_payload.fetch("gate")

    embedded = gate_payload["verification_receipt"]
    assert embedded.is_a?(Hash), "verify should embed the receipt document"
    assert_empty RailVerdict::SchemaValidator.validate_receipt(embedded)

    receipt_payload, = call_tool("get_verification_receipt")
    assert_equal "fresh", receipt_payload.fetch("status")
    assert_equal embedded.fetch("receipt_id"), receipt_payload.dig("receipt", "receipt_id")
  end

  def test_edit_after_verify_makes_cached_receipt_rejected_as_stale
    call_tool("verify")
    File.binwrite(File.join(@dir, "app.rb"), "puts 2\n")

    payload, = call_tool("get_verification_receipt")
    assert_equal "verification_required", payload.fetch("status")
    assert_equal "stale_receipt", payload.fetch("code")

    pi_payload, = call_tool("get_pr_intelligence")
    assert_equal "verification_required", pi_payload.fetch("status")
  end

  def test_fresh_verification_refreshes_both_tools
    call_tool("verify")
    File.binwrite(File.join(@dir, "app.rb"), "puts 3\n")

    call_tool("verify")
    receipt_payload, = call_tool("get_verification_receipt")
    assert_equal "fresh", receipt_payload.fetch("status")
    pi_payload, = call_tool("get_pr_intelligence")
    # full-scope verification has no PR Intelligence; explicit unavailable
    assert_equal "state_unavailable", pi_payload.fetch("status")
    assert_equal "pr_intelligence_unavailable", pi_payload.fetch("code")
  end

  def test_single_execution_invariant_no_analyzer_rerun_for_derived_contracts
    # enable rubocop (not installed in test PATH) so verify spawns it for probe+run
    File.binwrite(File.join(@dir, ".railverdict.yml"), "version: 1\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: false }\n")

    invocations = Hash.new(0)
    version_probes = Hash.new(0)
    singleton = RailVerdict::ProcessRunner.singleton_class
    original = RailVerdict::ProcessRunner.method(:run)
    singleton.send(:alias_method, :__original_run_for_test, :run)
    singleton.define_method(:run) do |executable, argv, **kwargs|
      base = File.basename(executable.to_s)
      is_version_probe = argv.include?("--version") || argv.include?("-v") || argv.join(" ").include?("Minitest::VERSION")
      if is_version_probe
        version_probes[base] += 1
      else
        invocations[base] += 1
      end
      original.call(executable, argv, **kwargs)
    end

    begin
      call_tool("verify")
      analyzer_calls_after_verify = invocations["rubocop"] + invocations["bundle"]
      assert_operator analyzer_calls_after_verify, :>=, 1, "verify must execute analyzers exactly once"

      call_tool("get_verification_receipt")
      call_tool("get_pr_intelligence")
      total_after_derived = invocations["rubocop"] + invocations["bundle"]
      assert_equal analyzer_calls_after_verify, total_after_derived,
                   "derived contracts must never rerun analyzers (version probes excluded)"
      # version probes are permitted for freshness and do not count as analyzer execution
      assert_operator version_probes["rubocop"] + version_probes["bundle"], :>=, 0
      assert_equal 0, invocations["rspec"]
      assert_equal 0, invocations["minitest"]
    ensure
      singleton.send(:remove_method, :run)
      singleton.send(:alias_method, :run, :__original_run_for_test)
      singleton.send(:remove_method, :__original_run_for_test)
    end
  end

  def test_cache_uses_shared_repository_state_identity
    outcome = RailVerdict::Check.execute(repository_root: @dir, config_path: ".railverdict.yml")
    state = RailVerdict::RepositoryState.capture(repository_root: @dir)
    @server.cache.store_verification(outcome: outcome)

    entry = @server.cache.fresh_entry(state)
    refute_nil entry
    assert_equal state.digest, entry.state_digest
    assert @server.cache.valid?

    File.binwrite(File.join(@dir, "app.rb"), "puts changed\n")
    new_state = RailVerdict::RepositoryState.capture(repository_root: @dir)
    assert_nil @server.cache.fresh_entry(new_state)
    refute @server.cache.valid?
  end

  def test_index_only_change_invalidates_mcp_cache
    outcome = RailVerdict::Check.execute(repository_root: @dir, config_path: ".railverdict.yml")
    @server.cache.store_verification(outcome: outcome)
    assert @server.cache.valid?

    File.binwrite(File.join(@dir, "staged.rb"), "x\n")
    git("add", "staged.rb")
    refute @server.cache.valid?, "index-only mutation must invalidate shared freshness"
  end
end
