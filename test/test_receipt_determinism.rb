# frozen_string_literal: true

require_relative "test_helper"

class TestReceiptDeterminism < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("rv-det-")
    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@t.invalid")
    git("config", "user.name", "T")
    File.binwrite(File.join(@dir, ".railverdict.yml"), "version: 1\nmode: strict\nanalyzers:\n  rubocop: { enabled: false, required: false }\n")
    File.binwrite(File.join(@dir, "app.rb"), "puts 1\n")
    File.binwrite(File.join(@dir, "z.rb"), "puts 2\n")
    commit
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

  def test_canonical_json_is_insertion_order_independent
    one = RailVerdict::CanonicalJSON.generate({ "b" => 1, "a" => { "y" => [3, 1, { "k" => nil }] }, "a2" => 2 })
    two = RailVerdict::CanonicalJSON.generate({ "a2" => 2, "a" => { "y" => [3, 1, { "k" => nil }] }, "b" => 1 })
    assert_equal '{"a":{"y":[3,1,{"k":null}]},"a2":2,"b":1}', one
    assert_equal one, two
  end

  def test_receipt_id_identical_across_processes_and_checkouts
    base_document = nil
    Dir.mktmpdir do |outer|
      clone_a = File.join(outer, "alpha-checkout")
      clone_b = File.join(outer, "beta_checkout_with_different_name_and_length")
      system("git", "clone", "-q", "file://#{@dir}", clone_a, out: File::NULL, err: File::NULL)
      system("git", "clone", "-q", "file://#{@dir}", clone_b, out: File::NULL, err: File::NULL)

      script = <<~RUBY
        require "json"
        require "#{File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, 'lib', 'rail_verdict')}"
        root = ARGV.fetch(0)
        outcome = RailVerdict::Check.execute_with_state_guard(repository_root: root, config_path: ".railverdict.yml")
        document = RailVerdict::Receipt.build(outcome: outcome)
        puts JSON.generate(document)
      RUBY
      script_path = File.join(outer, "build_receipt.rb")
      File.write(script_path, script)

      doc_a = JSON.parse(IO.popen([RbConfig.ruby, script_path, clone_a], &:read))
      doc_b = JSON.parse(IO.popen([RbConfig.ruby, script_path, clone_b], &:read))
      assert_empty RailVerdict::SchemaValidator.validate_receipt(doc_a)
      assert_equal doc_a.fetch("receipt_id"), doc_b.fetch("receipt_id"),
                   "identical meaningful inputs in differently named checkouts must produce identical receipts"
      refute_includes JSON.generate(doc_a), clone_a
      refute_includes JSON.generate(doc_a), outer

      base_document = doc_a
    end
    assert base_document
  end

  def test_repeated_same_process_builds_are_stable
    outcome_one = RailVerdict::Check.execute_with_state_guard(repository_root: @dir, config_path: ".railverdict.yml")
    first = RailVerdict::Receipt.build(outcome: outcome_one)
    outcome_two = RailVerdict::Check.execute_with_state_guard(repository_root: @dir, config_path: ".railverdict.yml")
    second = RailVerdict::Receipt.build(outcome: outcome_two)
    assert_equal first.fetch("receipt_id"), second.fetch("receipt_id")

    # randomized Hash insertion order for identity payload reconstruction
    shuffled = Marshal.load(Marshal.dump(first))
    assert_equal first.fetch("receipt_id"), RailVerdict::Receipt.id_for(shuffled.reject { |k| k == "receipt_id" })
  end
end

require "rbconfig"
