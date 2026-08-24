# frozen_string_literal: true

require "rbconfig"

require_relative "test_helper"

class TestVerificationRace < Minitest::Test
  SYNC_DIR = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "tmp", "race_sync")

  def setup
    @dir = Dir.mktmpdir("rv-race-")
    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@t.invalid")
    git("config", "user.name", "T")
    File.binwrite(File.join(@dir, ".railverdict.yml"), "version: 1\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: true }\n")
    File.binwrite(File.join(@dir, "app.rb"), "puts 1\n")
    commit
    FileUtils.mkdir_p(SYNC_DIR)
    write_slow_stub
  end

  def teardown
    FileUtils.rm_rf(@dir)
    FileUtils.rm_rf(SYNC_DIR)
  end

  def git(*args)
    system("git", "-C", @dir, *args, out: File::NULL, err: File::NULL) or flunk("git #{args.join(' ')} failed")
  end

  def commit(message = "c")
    git("add", "-A")
    git("commit", "-q", "-m", message)
  end

  def write_slow_stub
    ready = File.join(SYNC_DIR, "ready")
    go = File.join(SYNC_DIR, "go")
    File.delete(ready) if File.exist?(ready)
    File.delete(go) if File.exist?(go)
    stub = <<~RUBY
      require "json"
      if ARGV.include?("--version")
        puts "1.88.0"
      else
        File.write("#{ready}", "1")
        deadline = Time.now + 30
        until File.exist?("#{go}") || Time.now > deadline
          sleep 0.01
        end
        puts JSON.generate({ "files" => [] })
      end
    RUBY
    path = File.join(SYNC_DIR, "slow_rubocop.rb")
    File.write(path, stub)
    @resolver = ->(_root) { { executable: RbConfig.ruby, args_prefix: [path] } }
  end

  def run_guarded_verification_with_mutation
    ready = File.join(SYNC_DIR, "ready")
    go = File.join(SYNC_DIR, "go")

    outcome = nil
    thread = Thread.new do
      outcome = RailVerdict::Check.execute_with_state_guard(
        repository_root: @dir,
        config_path: ".railverdict.yml",
        rubocop_command_resolver: @resolver
      )
    end

    deadline = Time.now + 10
    sleep 0.01 until File.exist?(ready) || Time.now > deadline
    flunk "analyzer never signalled readiness" unless File.exist?(ready)

    yield # perform the repository mutation while analyzers are running

    File.write(go, "1")
    thread.join(60)
    flunk "verification thread did not finish" if thread.alive?
    outcome
  ensure
    File.delete(go) if go && File.exist?(go)
  end

  def test_source_mutation_during_verification_refuses_receipt
    outcome = run_guarded_verification_with_mutation do
      File.open(File.join(@dir, "app.rb"), "ab") { |f| f.write("\nputs 2\n") }
    end

    assert_equal "complete", outcome.result.completion_status,
                 "the canonical GateResult may still represent the executed check"
    pre = outcome.repository_state_pre
    post = outcome.repository_state_post
    assert pre.available?
    assert post.available?
    refute_equal pre.digest, post.digest, "mutation during verification must be observable"

    error = assert_raises RailVerdict::Receipt::BuildError do
      RailVerdict::Receipt.build(outcome: outcome)
    end
    assert_equal "repository_changed_during_verification", error.code
  end

  def test_config_mutation_during_verification_refuses_receipt
    outcome = run_guarded_verification_with_mutation do
      File.binwrite(File.join(@dir, ".railverdict.yml"), "version: 1\nmode: strict # mutated\nanalyzers:\n  rubocop: { enabled: true, required: true }\n")
    end

    error = assert_raises RailVerdict::Receipt::BuildError do
      RailVerdict::Receipt.build(outcome: outcome)
    end
    assert_equal "repository_changed_during_verification", error.code
  end

  def test_untracked_mutation_during_verification_refuses_receipt
    outcome = run_guarded_verification_with_mutation do
      File.binwrite(File.join(@dir, "sneaky_untracked.rb"), "x\n")
    end

    refute_equal outcome.repository_state_pre.digest, outcome.repository_state_post.digest
    error = assert_raises RailVerdict::Receipt::BuildError do
      RailVerdict::Receipt.build(outcome: outcome)
    end
    assert_equal "repository_changed_during_verification", error.code
  end

  def test_no_mutation_yields_binding_receipt
    clean_resolver = ->(_root) { { executable: RbConfig.ruby, args_prefix: [File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs", "fake_rubocop_clean.rb")] } }
    outcome = RailVerdict::Check.execute_with_state_guard(
      repository_root: @dir,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: clean_resolver
    )
    document = RailVerdict::Receipt.build(outcome: outcome)
    assert_match(/\Asha256:[0-9a-f]{64}\z/, document.fetch("receipt_id"))
  end
end
