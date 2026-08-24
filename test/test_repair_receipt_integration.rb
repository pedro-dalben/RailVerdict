# frozen_string_literal: true

require "rbconfig"

require_relative "test_helper"

class TestRepairReceiptIntegration < Minitest::Test
  STUB_DIR = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "tmp", "repair_stub")

  def setup
    @dir = Dir.mktmpdir("rv-repair-receipt-")
    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@t.invalid")
    git("config", "user.name", "T")
    File.binwrite(File.join(@dir, ".railverdict.yml"), "version: 1\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: true }\n")
    File.binwrite(File.join(@dir, "app.rb"), "value = 1\nputs value\n")
    commit
    FileUtils.mkdir_p(STUB_DIR)
  end

  def teardown
    FileUtils.rm_rf(@dir)
    FileUtils.rm_rf(STUB_DIR)
  end

  def git(*args)
    system("git", "-C", @dir, *args, out: File::NULL, err: File::NULL) or flunk("git #{args.join(' ')} failed")
  end

  def commit(message = "c")
    git("add", "-A")
    git("commit", "-q", "-m", message)
  end

  def resolver(stub_path)
    ->(_root) { { executable: RbConfig.ruby, args_prefix: [stub_path] } }
  end

  def offense_outcome
    RailVerdict::Check.execute_with_state_guard(
      repository_root: @dir,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: resolver(File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs", "fake_rubocop_offenses.rb"))
    )
  end

  def clean_outcome
    RailVerdict::Check.execute_with_state_guard(
      repository_root: @dir,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: resolver(File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs", "fake_rubocop_clean.rb"))
    )
  end

  def test_packet_v1_contract_stays_immutable_and_boundary_reusable
    failing = offense_outcome
    assert_equal "FAIL", failing.result.gate

    finding = failing.findings.first
    packet = RailVerdict::Repair::ContextAssembler.build(outcome: failing, finding_ref: finding.id, repository_root: @dir)

    # RepairPacket v1 remains a closed contract: no receipt fields were injected
    assert_empty RailVerdict::SchemaValidator.validate_repair_packet(packet.to_h)
    refute_includes packet.to_h.keys, "originating_receipt_id"
    refute_includes packet.to_h.keys, "resulting_receipt_id"

    # Boundary primitives remain present and are content digests
    boundary = packet.to_h.fetch("boundary")
    assert boundary["configuration_digest"]
    assert boundary.key?("baseline_digest")
    assert boundary["source_revision"]

    # The failing verification can produce a receipt bound to this packet
    document = RailVerdict::Receipt.build(outcome: failing, pr_intelligence_document: nil, repair_packet_id: packet.packet_id)
    assert_equal "FAIL", document.dig("gate_projection", "gate")
    assert_equal packet.packet_id, document.dig("repair", "packet_id")
    assert_empty RailVerdict::SchemaValidator.validate_receipt(document)
  end

  def test_baseline_mutation_after_fail_receipt_breaks_boundaries
    failing = offense_outcome
    finding = failing.findings.first
    packet = RailVerdict::Repair::ContextAssembler.build(outcome: failing, finding_ref: finding.id, repository_root: @dir)

    receipt = RailVerdict::Receipt.build(outcome: failing, repair_packet_id: packet.packet_id)
    fresh_state = RailVerdict::RepositoryState.capture(repository_root: @dir)
    validation, = RailVerdict::Receipt.evaluate(JSON.generate(receipt), current_state: fresh_state)
    assert_equal "fresh", validation.fetch("status")

    # Agent attempts to cheat by mutating the baseline
    File.binwrite(File.join(@dir, ".railverdict-baseline.json"), "{}\n")

    mutated_state = RailVerdict::RepositoryState.capture(repository_root: @dir)
    stale_validation, = RailVerdict::Receipt.evaluate(JSON.generate(receipt), current_state: mutated_state)
    assert_equal "stale", stale_validation.fetch("status")
    assert_includes stale_validation.fetch("reasons"), "baseline_changed"

    # Repair verifier must also report the boundary change (shared inputs)
    repaired = clean_outcome
    result = RailVerdict::Repair::Verifier.verify(packet: packet.to_h, new_outcome: repaired)
    changed = result.verification_boundary_changed
    refute_same false, changed
    assert changed[:baseline] || changed["baseline"] || changed == { "baseline" => true } ||
           (changed.respond_to?(:key?) && (changed.key?(:baseline) || changed.key?("baseline"))),
           "baseline mutation must surface as boundary change"
  end

  def test_successful_repair_produces_distinct_pass_receipt
    failing = offense_outcome
    finding = failing.findings.first
    packet = RailVerdict::Repair::ContextAssembler.build(outcome: failing, finding_ref: finding.id, repository_root: @dir)

    fail_document = RailVerdict::Receipt.build(outcome: failing, repair_packet_id: packet.packet_id)

    # external edit resolves the stub offense marker (simulate fix by switching analyzer output)
    repaired = clean_outcome
    verdict = RailVerdict::Repair::Verifier.verify(packet: packet.to_h, new_outcome: repaired)
    assert_equal "fixed", verdict.target_status

    pass_document = RailVerdict::Receipt.build(outcome: repaired, repair_packet_id: packet.packet_id)
    assert_equal "PASS", pass_document.dig("gate_projection", "gate")
    refute_equal fail_document.fetch("receipt_id"), pass_document.fetch("receipt_id"),
                 "origin and resulting receipts must be distinct identities"
  end
end
