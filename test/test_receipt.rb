# frozen_string_literal: true

require_relative "test_helper"

class TestReceipt < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("rv-receipt-")
    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@t.invalid")
    git("config", "user.name", "T")
    write_config("version: 1\nmode: strict\nanalyzers:\n  rubocop: { enabled: false, required: false }\n")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def git(*args)
    system("git", "-C", @dir, *args, out: File::NULL, err: File::NULL) or flunk("git #{args.join(' ')} failed")
  end

  def write(path, content)
    File.binwrite(File.join(@dir, path), content)
  end

  def write_config(content)
    write(".railverdict.yml", content)
  end

  def commit(message = "c")
    git("add", "-A")
    git("commit", "-q", "-m", message)
  end

  def guarded_outcome(changed: false, base: nil)
    RailVerdict::Check.execute_with_state_guard(
      repository_root: @dir,
      config_path: ".railverdict.yml",
      changed: changed,
      base: base
    )
  end

  def build(outcome = guarded_outcome, **options)
    RailVerdict::Receipt.build(outcome: outcome, **options)
  end

  def test_build_produces_schema_valid_document
    commit
    document = build
    assert_empty RailVerdict::SchemaValidator.validate_receipt(document)
    assert_equal "1.0", document.fetch("schema_version")
    assert_match(/\Asha256:[0-9a-f]{64}\z/, document.fetch("receipt_id"))
    assert_equal "full", document.fetch("verification_mode")
    assert_nil document.fetch("changed_scope")
    assert_equal "PASS", document.dig("gate_projection", "gate")
    assert_equal "complete", document.dig("gate_projection", "completion_status")
  end

  def test_receipt_id_is_deterministic_and_excludes_volatile_data
    commit
    first = build
    second = build
    assert_equal first.fetch("receipt_id"), second.fetch("receipt_id")

    refute_includes first.keys, "created_at"
    refute_includes first.keys, "duration_seconds"
    json = JSON.generate(first)
    refute_match(/created_at/, json)
    refute_match(/duration/, json)
  end

  def test_receipt_binds_head_index_worktree_and_policy_inputs
    commit
    document = build
    state = document.fetch("repository_state")
    head = `git -C #{@dir} rev-parse HEAD`.strip
    assert_equal head, state.fetch("head")
    assert_match(/\Asha256:[0-9a-f]{64}\z/, state.fetch("index_digest"))
    assert_match(/\Asha256:[0-9a-f]{64}\z/, state.fetch("worktree_digest"))
    assert_match(/\Asha256:[0-9a-f]{64}\z/, state.fetch("configuration_digest"))
    assert_nil state.fetch("baseline_digest")

    write(".railverdict-baseline.json", "{}\n")
    with_baseline = build
    refute_nil with_baseline.dig("repository_state", "baseline_digest")
    refute_equal document.fetch("receipt_id"), with_baseline.fetch("receipt_id"),
                 "baseline presence must change receipt identity"
  end

  def test_any_source_mutation_changes_receipt_id
    commit
    base_id = build.fetch("receipt_id")

    write(".railverdict.yml", "version: 1\nmode: strict   # c\nanalyzers:\n  rubocop: { enabled: false, required: false }\n")
    refute_equal base_id, build.fetch("receipt_id"), "config content must change identity"
    write_config("version: 1\nmode: strict\nanalyzers:\n  rubocop: { enabled: false, required: false }\n")

    write(".railverdict-waivers.json", "{\"schema_version\":\"1.0\",\"waivers\":[]}\n")
    refute_equal base_id, build.fetch("receipt_id"), "waiver presence must change identity"
  end

  def test_changed_scope_mode_and_base_binding
    commit
    write("b.rb", "x\n")
    commit
    outcome = guarded_outcome(changed: true, base: "HEAD~1")
    document = build(outcome)

    assert_empty RailVerdict::SchemaValidator.validate_receipt(document)
    assert_equal "changed", document.fetch("verification_mode")
    scope = document.fetch("changed_scope")
    assert_match(/\A[0-9a-f]{7,64}\z/, scope.fetch("base"))
    assert_match(/\A[0-9a-f]{7,64}\z/, scope.fetch("merge_base"))
  end

  def test_pr_intelligence_binding_ignores_volatile_runtime_fields
    commit
    write("b.rb", "x\n")
    commit
    outcome = guarded_outcome(changed: true, base: "HEAD~1")
    pi_document = RailVerdict::PRIntelligence.document(outcome)

    with_pi = RailVerdict::Receipt.build(outcome: outcome, pr_intelligence_document: pi_document)
    digest = with_pi.dig("pr_intelligence", "digest")
    assert_match(/\Asha256:[0-9a-f]{64}\z/, digest)

    base_doc = {
      "schema_version" => "1.0",
      "gate_result" => { "gate" => "PASS" },
      "test_intelligence" => { "available" => true, "analyzers" => {
        "minitest" => { "tests_total" => 7, "duration_seconds" => 1.25, "seed" => 4242 }
      } }
    }
    other_runtime = Marshal.load(Marshal.dump(base_doc))
    other_runtime["test_intelligence"]["analyzers"]["minitest"]["duration_seconds"] = 9876.5
    other_runtime["test_intelligence"]["analyzers"]["minitest"]["seed"] = 99

    first = RailVerdict::Receipt.build(outcome: outcome, pr_intelligence_document: base_doc)
    second = RailVerdict::Receipt.build(outcome: outcome, pr_intelligence_document: other_runtime)
    assert_equal first.dig("pr_intelligence", "digest"), second.dig("pr_intelligence", "digest"),
                 "volatile runtime fields must not change the PR Intelligence binding"
    assert_equal first.fetch("receipt_id"), second.fetch("receipt_id"),
                 "receipts differing only in volatile runtime fields must be identical"
  ensure
    # no-op
  end

  def test_pr_intelligence_absence_leaves_identity_stable
    commit
    without = build
    with_nil = RailVerdict::Receipt.build(outcome: guarded_outcome, pr_intelligence_document: nil)
    assert_nil without.dig("pr_intelligence")
    assert_equal without.fetch("receipt_id"), with_nil.fetch("receipt_id")
  end

  def test_repair_packet_binding
    commit
    packet_id = "sha256:#{"b" * 64}"
    bound = RailVerdict::Receipt.build(outcome: guarded_outcome, repair_packet_id: packet_id)
    assert_equal packet_id, bound.dig("repair", "packet_id")
    plain = build
    refute_equal plain.fetch("receipt_id"), bound.fetch("receipt_id")

    assert_raises RailVerdict::Receipt::BuildError do
      RailVerdict::Receipt.build(outcome: guarded_outcome, repair_packet_id: "not-a-sha")
    end
  end

  def test_state_change_during_verification_fails_closed
    commit
    pre = RailVerdict::RepositoryState.capture(repository_root: @dir)
    post_state = RailVerdict::RepositoryState.capture(repository_root: @dir)
    outcome = RailVerdict::Check::Outcome.new(
      result: guarded_outcome.result,
      context: guarded_outcome.context,
      configuration: guarded_outcome.configuration,
      findings: [],
      repository_state_pre: pre,
      repository_state_post: post_state
    )
    document = RailVerdict::Receipt.build(outcome: outcome)
    assert document

    different_pre = RailVerdict::RepositoryState.unavailable(:repository_root_unavailable)
    broken = RailVerdict::Check::Outcome.new(
      result: guarded_outcome.result,
      context: guarded_outcome.context,
      configuration: guarded_outcome.configuration,
      findings: [],
      repository_state_pre: different_pre,
      repository_state_post: post_state
    )
    error = assert_raises RailVerdict::Receipt::BuildError do
      RailVerdict::Receipt.build(outcome: broken)
    end
    assert_equal "repository_state_unavailable", error.code

    mutated_dir = File.join(@dir, "..", File.basename(@dir) + "-alt")
    other_pre = Object.new
    def other_pre.available? = false
    def other_pre.unavailable_reason = "git_unavailable"
    unavailable_outcome = RailVerdict::Check::Outcome.new(
      result: guarded_outcome.result, context: nil, configuration: nil, findings: [],
      repository_state_pre: other_pre, repository_state_post: post_state
    )
    error2 = assert_raises RailVerdict::Receipt::BuildError do
      RailVerdict::Receipt.build(outcome: unavailable_outcome)
    end
    assert_equal "repository_state_unavailable", error2.code
  ensure
    FileUtils.rm_rf(mutated_dir) if defined?(mutated_dir) && mutated_dir
  end

  def test_parse_rejects_tampering_matrix
    commit
    document = build
    canonical = JSON.generate(document)

    receipt, reason = RailVerdict::Receipt.parse(canonical)
    assert_nil reason
    assert_equal document.fetch("receipt_id"), receipt.receipt_id

    tampered_gate = Marshal.load(Marshal.dump(document))
    tampered_gate["gate_projection"]["gate"] = "FAIL"
    _r, reason = RailVerdict::Receipt.parse(JSON.generate(tampered_gate))
    assert_equal :receipt_integrity_failed, reason, "gate flip without id update must be integrity failure"

    tampered_state = Marshal.load(Marshal.dump(document))
    tampered_state["repository_state"]["head"] = "0" * 40
    _r, reason = RailVerdict::Receipt.parse(JSON.generate(tampered_state))
    assert_equal :receipt_integrity_failed, reason

    tampered_env = Marshal.load(Marshal.dump(document))
    tampered_env["environment"]["analyzer_versions"]["rubocop"] = "9.9.9"
    _r, reason = RailVerdict::Receipt.parse(JSON.generate(tampered_env))
    assert_equal :receipt_integrity_failed, reason

    missing_field = Marshal.load(Marshal.dump(document))
    missing_field.delete("railverdict_version")
    _r, reason = RailVerdict::Receipt.parse(JSON.generate(missing_field))
    assert_equal :receipt_schema_invalid, reason

    bad_version = Marshal.load(Marshal.dump(document))
    bad_version["schema_version"] = "2.0"
    _r, reason = RailVerdict::Receipt.parse(JSON.generate(bad_version))
    assert_equal :incompatible_receipt_version, reason

    unknown_field = Marshal.load(Marshal.dump(document))
    unknown_field["merge_ready"] = true
    _r, reason = RailVerdict::Receipt.parse(JSON.generate(unknown_field))
    assert_equal :receipt_schema_invalid, reason, "closed contract must reject unknown fields"

    _r, reason = RailVerdict::Receipt.parse("{not json")
    assert_equal :receipt_malformed, reason

    oversized = "{" + "\"pad\":\"#{"x" * (RailVerdict::Receipt::MAX_DOCUMENT_BYTES)}\"}"
    _r, reason = RailVerdict::Receipt.parse(oversized)
    assert_equal :receipt_too_large, reason
  end

  def test_evaluate_reports_fresh_stale_invalid_unavailable
    commit
    document = build
    text = JSON.generate(document)

    fresh_state = RailVerdict::RepositoryState.capture(repository_root: @dir)
    validation, receipt = RailVerdict::Receipt.evaluate(text, current_state: fresh_state)
    assert_equal "fresh", validation.fetch("status")
    assert_empty validation.fetch("reasons")
    assert receipt
    assert_empty RailVerdict::SchemaValidator.validate_receipt_validation(validation)

    write("mutated.rb", "new bytes\n")
    stale_validation, = RailVerdict::Receipt.evaluate(text, current_state: RailVerdict::RepositoryState.capture(repository_root: @dir))
    assert_equal "stale", stale_validation.fetch("status")
    assert_includes stale_validation.fetch("reasons"), "worktree_changed"
    assert_equal "PASS", stale_validation.fetch("gate"), "stale must preserve original gate, never reinterpret it"

    invalid_validation, = RailVerdict::Receipt.evaluate(text.sub("PASS", "WARN"), current_state: fresh_state)
    assert_equal "invalid", invalid_validation.fetch("status")

    unavailable_state = RailVerdict::RepositoryState.unavailable(:git_unavailable)
    unavailable_validation, = RailVerdict::Receipt.evaluate(text, current_state: unavailable_state)
    assert_equal "unavailable", unavailable_validation.fetch("status")
    assert_match(/\Arepository_state_unavailable:/, unavailable_validation.fetch("reasons").first)
  end

  def test_component_level_stale_reasons
    commit
    document = build
    text = JSON.generate(document)

    validations = {}

    write(".railverdict-baseline.json", "{}\n")
    validations[:baseline] = RailVerdict::Receipt.evaluate(text, current_state: RailVerdict::RepositoryState.capture(repository_root: @dir)).first
    File.unlink(File.join(@dir, ".railverdict-baseline.json"))

    write(".railverdict-waivers.json", "{\"schema_version\":\"1.0\",\"waivers\":[]}\n")
    validations[:waivers] = RailVerdict::Receipt.evaluate(text, current_state: RailVerdict::RepositoryState.capture(repository_root: @dir)).first
    File.unlink(File.join(@dir, ".railverdict-waivers.json"))

    write_config("version: 1\nmode: strict # now-with-comment\nanalyzers:\n  rubocop: { enabled: false, required: false }\n")
    validations[:config] = RailVerdict::Receipt.evaluate(text, current_state: RailVerdict::RepositoryState.capture(repository_root: @dir)).first
    write_config("version: 1\nmode: strict\nanalyzers:\n  rubocop: { enabled: false, required: false }\n")

    git("rm", "-q", "--cached", ".railverdict.yml") rescue nil
    validations[:index] = RailVerdict::Receipt.evaluate(text, current_state: RailVerdict::RepositoryState.capture(repository_root: @dir)).first
    git("add", ".railverdict.yml")

    validations.each_value do |validation|
      assert_equal "stale", validation.fetch("status")
      refute_empty validation.fetch("reasons")
    end
    assert_includes validations[:baseline].fetch("reasons"), "baseline_changed"
    assert_includes validations[:waivers].fetch("reasons"), "waivers_changed"
    assert_includes validations[:config].fetch("reasons"), "configuration_changed"
    assert_includes validations[:index].fetch("reasons"), "index_changed"
  end

  def test_verification_environment_unobservable_when_bundle_probe_fails
    write_config("version: 1.5\nmode: no_new_debt\nanalyzers:\n  rubocop: { enabled: false, required: false }\n  rspec: { enabled: true, required: true }\n")
    write("Gemfile", "source 'https://rubygems.org'\n")
    fake_runner = Class.new do
      def run(executable, _argv, chdir:, timeout_seconds:, max_stdout_bytes: nil)
        if executable == "bundle"
          RailVerdict::ProcessRunner::RunResult.new(
            status: :exited,
            exit_code: 7,
            signal: nil,
            stdout: "",
            stderr: "Could not find gem 'rspec'",
            stdout_truncated: false,
            stderr_truncated: false,
            detail: "exit 7"
          )
        else
          RailVerdict::ProcessRunner::RunResult.new(
            status: :exited,
            exit_code: 0,
            signal: nil,
            stdout: "3.13.0\n",
            stderr: "",
            stdout_truncated: false,
            stderr_truncated: false,
            detail: "exit 0"
          )
        end
      end
    end.new

    env = RailVerdict::VerificationEnvironment.capture(repository_root: @dir, runner: fake_runner)
    assert_equal false, env.available?
    assert_match(/analyzer_version_unobservable:rspec/, env.unavailable_reason)
  end

  def test_resolve_probe_timeout_clamps_to_five_seconds
    write_config("version: 1.5\nmode: no_new_debt\nanalyzers:\n  rubocop: { enabled: false, required: false }\n  rspec: { enabled: true, required: true, timeout_seconds: 600 }\n")
    cfg = RailVerdict::Configuration.load(File.join(@dir, ".railverdict.yml"))
    timeout = RailVerdict::VerificationEnvironment.send(:resolve_probe_timeout, cfg, "rspec", 5.0)
    assert_equal 5.0, timeout
  end
end

