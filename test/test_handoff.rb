# frozen_string_literal: true

require_relative "test_helper"

class TestHandoff < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("rv-handoff-")
    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@t.invalid")
    git("config", "user.name", "T")
    write_config(rubocop_only_config)
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

  def rubocop_only_config
    <<~YML
      version: 1.3
      mode: no_new_debt
      analyzers:
        rubocop: { enabled: true, required: true }
        rspec: { enabled: false, required: false }
        minitest: { enabled: false, required: false }
        simplecov: { enabled: false, required: false }
        bundler_audit: { enabled: false, required: false }
    YML
  end

  def full_config
    <<~YML
      version: 1.3
      mode: no_new_debt
      analyzers:
        rubocop: { enabled: true, required: true }
        rspec: { enabled: true, required: true }
        minitest: { enabled: false, required: false }
        simplecov: { enabled: false, required: false }
        bundler_audit: { enabled: false, required: false }
    YML
  end

  def guarded_outcome(config_path: ".railverdict.yml")
    RailVerdict::Check.execute_with_state_guard(repository_root: @dir, config_path: config_path)
  end

  def build_handoff(outcome, config_path: ".railverdict.yml")
    receipt = RailVerdict::Receipt.build(outcome: outcome)
    evidence_set = {
      "analyzer_results" => outcome.result.analyzer_results.map do |ar|
        h = { "analyzer" => ar.analyzer, "execution_status" => ar.execution_status, "tool_version" => ar.tool_version }
        findings = outcome.findings.select { |f| f.analyzer == ar.analyzer }.map(&:to_schema_h).sort_by { |ff| ff["fingerprint"] }
        h["findings"] = findings if findings.any?
        h
      end
    }
    provenance = { "analyzer_versions" => outcome.context&.analyzer_versions || {} }
    scope = { "verification_mode" => "full" }
    RailVerdict::Handoff.build(receipt: receipt, evidence_set: evidence_set, evidence_provenance: provenance, source_scope: scope)
  end

  def test_handoff_build_deterministic_and_bounded
    write("a.rb", "x=1\n")
    commit
    outcome = guarded_outcome
    h1 = build_handoff(outcome)
    h2 = build_handoff(outcome)
    assert_equal h1["handoff_id"], h2["handoff_id"]
    assert_match(/\Asha256:[0-9a-f]{64}\z/, h1["handoff_id"])
    assert_empty RailVerdict::SchemaValidator.validate_handoff(h1)
    assert_operator JSON.generate(h1).bytesize, :<, RailVerdict::Handoff::MAX_DOCUMENT_BYTES
  end

  def test_handoff_tamper_detected
    write("a.rb", "x=1\n")
    commit
    handoff = build_handoff(guarded_outcome)
    text = JSON.generate(handoff)
    tampered = JSON.parse(text)
    tampered["receipt"]["gate_projection"]["gate"] = "FAIL"
    tampered_text = JSON.generate(tampered)
    doc, err = RailVerdict::Handoff.parse(tampered_text)
    assert_nil doc
    assert_equal :handoff_integrity_failed, err
  end

  def test_handoff_oversized_rejected
    write("a.rb", "x=1\n")
    commit
    handoff = build_handoff(guarded_outcome)
    big = JSON.parse(JSON.generate(handoff))
    big["evidence_set"]["analyzer_results"][0]["findings"] = Array.new(6000) { { "fingerprint" => "sha256:" + "a" * 64 } }
    text = JSON.generate(big)
    assert_operator text.bytesize, :>, RailVerdict::Handoff::MAX_DOCUMENT_BYTES
    doc, err = RailVerdict::Handoff.parse(text)
    assert_nil doc
    assert_equal :handoff_too_large, err
  end

  def test_reuse_rubocop_only_reusable
    write("a.rb", "x=1\n")
    commit
    outcome = guarded_outcome
    handoff = build_handoff(outcome)
    effective_paths = RailVerdict::Check.effective_input_paths(root: File.realpath(@dir), config_path: File.join(@dir, ".railverdict.yml"))
    state = RailVerdict::RepositoryState.capture(repository_root: @dir, configuration_paths: effective_paths)
    env_obj = RailVerdict::VerificationEnvironment.capture(repository_root: @dir)
    env = { "ruby_engine" => env_obj.ruby_engine, "ruby_version" => env_obj.ruby_version, "railverdict_version" => env_obj.railverdict_version, "analyzer_versions" => env_obj.analyzer_versions }
    result = RailVerdict::Reuse.evaluate(handoff_document: handoff, current_repository_state: state, current_environment: env, current_contract: { "required_analyzers" => ["rubocop"] })
    assert_equal RailVerdict::Reuse::REUSABLE, result.decision
    assert_equal true, result.handoff_valid
    assert_equal true, result.receipt_fresh
  end

  def test_reuse_full_config_requires_verification_due_to_rspec
    # Switch to full config that requires rspec
    write_config(full_config)
    write("a.rb", "x=1\n")
    commit
    outcome = guarded_outcome
    # Build handoff with full evidence (rubocop+rspec) — but our outcome currently only has rubocop because no spec files? Force evidence to include rspec via manual handoff
    receipt = RailVerdict::Receipt.build(outcome: outcome)
    evidence_set = {
      "analyzer_results" => [
        { "analyzer" => "rubocop", "execution_status" => "succeeded", "tool_version" => "1.89.0" },
        { "analyzer" => "rspec", "execution_status" => "succeeded", "tool_version" => "3.13.6" }
      ]
    }
    handoff = RailVerdict::Handoff.build(receipt: receipt, evidence_set: evidence_set, evidence_provenance: { "analyzer_versions" => { "rubocop" => "1.89.0", "rspec" => "3.13.6" } }, source_scope: { "verification_mode" => "full" })
    effective_paths = RailVerdict::Check.effective_input_paths(root: File.realpath(@dir), config_path: File.join(@dir, ".railverdict.yml"))
    state = RailVerdict::RepositoryState.capture(repository_root: @dir, configuration_paths: effective_paths)
    env_obj = RailVerdict::VerificationEnvironment.capture(repository_root: @dir)
    env = { "ruby_engine" => env_obj.ruby_engine, "ruby_version" => env_obj.ruby_version, "railverdict_version" => env_obj.railverdict_version, "analyzer_versions" => env_obj.analyzer_versions }
    result = RailVerdict::Reuse.evaluate(handoff_document: handoff, current_repository_state: state, current_environment: env, current_contract: { "required_analyzers" => ["rubocop", "rspec"] })
    assert_equal RailVerdict::Reuse::VERIFICATION_REQUIRED, result.decision
    assert_includes result.reasons.join, "analyzer_not_reusable:rspec"
  end

  def test_reuse_worktree_drift_requires_verification
    write("a.rb", "x=1\n")
    commit
    handoff = build_handoff(guarded_outcome)
    # Mutate worktree
    write("a.rb", "x=2\n")
    effective_paths = RailVerdict::Check.effective_input_paths(root: File.realpath(@dir), config_path: File.join(@dir, ".railverdict.yml"))
    state = RailVerdict::RepositoryState.capture(repository_root: @dir, configuration_paths: effective_paths)
    env_obj = RailVerdict::VerificationEnvironment.capture(repository_root: @dir)
    env = { "ruby_engine" => env_obj.ruby_engine, "ruby_version" => env_obj.ruby_version, "railverdict_version" => env_obj.railverdict_version, "analyzer_versions" => env_obj.analyzer_versions }
    result = RailVerdict::Reuse.evaluate(handoff_document: handoff, current_repository_state: state, current_environment: env, current_contract: { "required_analyzers" => ["rubocop"] })
    assert_equal RailVerdict::Reuse::VERIFICATION_REQUIRED, result.decision
    assert_includes result.reasons.join, "repository_changed"
  end

  def test_handoff_clone_portable
    write("a.rb", "x=1\n")
    commit
    handoff = build_handoff(guarded_outcome)
    text = JSON.generate(handoff)
    clone_dir = Dir.mktmpdir("rv-clone-")
    begin
      system("git", "clone", "-q", @dir, clone_dir)
      # Clone has same HEAD/index/worktree/config
      clone_paths = RailVerdict::Check.effective_input_paths(root: File.realpath(clone_dir), config_path: File.join(clone_dir, ".railverdict.yml"))
      clone_state = RailVerdict::RepositoryState.capture(repository_root: clone_dir, configuration_paths: clone_paths)
      env_obj = RailVerdict::VerificationEnvironment.capture(repository_root: clone_dir)
      env = { "ruby_engine" => env_obj.ruby_engine, "ruby_version" => env_obj.ruby_version, "railverdict_version" => env_obj.railverdict_version, "analyzer_versions" => env_obj.analyzer_versions }
      doc, err = RailVerdict::Handoff.parse(text)
      assert_nil err
      result = RailVerdict::Reuse.evaluate(handoff_document: doc, current_repository_state: clone_state, current_environment: env, current_contract: { "required_analyzers" => ["rubocop"] })
      assert_equal RailVerdict::Reuse::REUSABLE, result.decision
    ensure
      FileUtils.rm_rf(clone_dir)
    end
  end
end
