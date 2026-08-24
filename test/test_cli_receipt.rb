# frozen_string_literal: true

require_relative "test_helper"

class TestCliReceipt < Minitest::Test
  STUB_DIR = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "tmp", "receipt_stub")

  def setup
    @dir = Dir.mktmpdir("rv-cli-receipt-")
    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@t.invalid")
    git("config", "user.name", "T")
    write(".railverdict.yml", "version: 1\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: true }\n")
    write("app.rb", "puts 1\n")
    commit
    FileUtils.mkdir_p(STUB_DIR)
    write_stub
  end

  def teardown
    FileUtils.rm_rf(@dir)
    FileUtils.rm_rf(STUB_DIR)
  end

  def git(*args)
    system("git", "-C", @dir, *args, out: File::NULL, err: File::NULL) or flunk("git #{args.join(' ')} failed")
  end

  def write(path, content)
    File.binwrite(File.join(@dir, path), content)
  end

  def commit(message = "c")
    git("add", "-A")
    git("commit", "-q", "-m", message)
  end

  def write_stub
    stub = <<~RUBY
      #!/usr/bin/env ruby
      require "json"
      if ARGV.include?("--version")
        puts "1.88.0"
      elsif File.exist?(File.join(Dir.pwd, ".stub-offense"))
        files = [{ "path" => "app.rb", "offenses" => [{
          "cop_name" => "Lint/Stub",
          "severity" => "convention",
          "message" => "Stub offense",
          "location" => { "start_line" => 1, "last_line" => 1 }
        }] }]
        puts JSON.generate({ "files" => files })
      else
        puts JSON.generate({ "files" => [] })
      end
    RUBY
    File.binwrite(File.join(STUB_DIR, "rubocop"), "#!/usr/bin/env ruby\n{ File.binread(__FILE__) }\n")
    File.write(File.join(STUB_DIR, "rubocop"), stub)
    File.chmod(0o755, File.join(STUB_DIR, "rubocop"))
  end

  def run_cli(argv)
    stdout = StringIO.new
    stderr = StringIO.new
    cli = RailVerdict::CLI.new(stdout: stdout, stderr: stderr, working_directory: @dir)
    previous_path = ENV.fetch("PATH", nil)
    ENV["PATH"] = "#{STUB_DIR}#{File::PATH_SEPARATOR}#{previous_path}"
    begin
      exit_code = cli.run(argv)
    ensure
      ENV["PATH"] = previous_path
    end
    [exit_code, stdout.string, stderr.string]
  end

  def create_receipt(extra: [])
    code, stdout, stderr = run_cli(["receipt", "create", "--format", "json"] + extra)
    [code, stdout, stderr]
  end

  def run_validation(receipt_path, extra: [])
    code, output, = run_cli(["receipt", "verify", receipt_path, "--format", "json"] + extra)
    [JSON.parse(output), code]
  end

  def test_create_pass_receipt_stdout_and_exit_zero
    code, stdout, stderr = create_receipt
    assert_equal 0, code, stderr
    document = JSON.parse(stdout)
    assert_empty RailVerdict::SchemaValidator.validate_receipt(document)
    assert_equal "PASS", document.dig("gate_projection", "gate")
    assert_equal "complete", document.dig("gate_projection", "completion_status")
    assert_match(/\Asha256:[0-9a-f]{64}\z/, document.fetch("receipt_id"))
  end

  def test_create_fail_receipt_exit_one_gate_stays_fail
    write(".stub-offense", "on\n")
    code, stdout, _stderr = create_receipt
    assert_equal 1, code
    document = JSON.parse(stdout)
    assert_equal "FAIL", document.dig("gate_projection", "gate")
    assert_equal 1, document.dig("gate_projection", "findings").length
  end

  def test_create_with_output_writes_atomically_with_private_permissions
    target = File.join(@dir, "..", "#{File.basename(@dir)}-receipt-out.json")
    begin
      code, _stdout, stderr = create_receipt(extra: ["--output", target])
      assert_equal 0, code, stderr
      assert File.file?(target)
      assert_equal 0o600, (File.stat(target).mode & 0o777)
      document = JSON.parse(File.read(target))
      assert document.fetch("receipt_id")
    ensure
      FileUtils.rm_f(target)
    end
  end

  def test_console_format_summary
    code, stdout, stderr = run_cli(["receipt", "create", "--format", "console"])
    assert_equal 0, code, stderr
    assert_includes stdout, "Receipt: sha256:"
    assert_includes stdout, "Gate: PASS"
  end

  def test_verify_fresh_pass_is_exit_zero
    _code, stdout, = create_receipt
    receipt_path = File.join(@dir, "..", "#{File.basename(@dir)}.receipt.json")
    File.binwrite(receipt_path, stdout)
    begin
      code, output, stderr = run_cli(["receipt", "verify", receipt_path, "--format", "json"])
      assert_equal 0, code, stderr
      validation = JSON.parse(output)
      assert_equal "fresh", validation.fetch("status")
      assert_equal "PASS", validation.fetch("gate")
    ensure
      FileUtils.rm_f(receipt_path)
    end
  end

  def test_worktree_mutation_makes_receipt_stale_exit_two
    _code, stdout, = create_receipt
    receipt_path = File.join(@dir, "..", "#{File.basename(@dir)}.receipt.json")
    File.binwrite(receipt_path, stdout)
    begin
      write("app.rb", "puts 2\n")
      code, output, = run_cli(["receipt", "verify", receipt_path, "--format", "json"])
      assert_equal 2, code
      validation = JSON.parse(output)
      assert_equal "stale", validation.fetch("status")
      assert_includes validation.fetch("reasons"), "worktree_changed"
    ensure
      FileUtils.rm_f(receipt_path)
    end
  end

  def test_committed_change_makes_receipt_stale_with_head_reason
    _code, stdout, = create_receipt
    receipt_path = File.join(@dir, "..", "#{File.basename(@dir)}.receipt.json")
    File.binwrite(receipt_path, stdout)
    begin
      write("other.rb", "x\n")
      commit
      code, output, = run_cli(["receipt", "verify", receipt_path, "--format", "json"])
      assert_equal 2, code
      reasons = JSON.parse(output).fetch("reasons")
      assert_includes reasons, "head_changed"
      assert_includes reasons, "index_changed"
    ensure
      FileUtils.rm_f(receipt_path)
    end
  end

  def test_tampered_receipt_is_invalid_not_fresh
    _code, stdout, = create_receipt
    tampered = JSON.parse(stdout)
    tampered["gate_projection"]["gate"] = "FAIL"
    receipt_path = File.join(@dir, "tampered.receipt.json")
    File.binwrite(receipt_path, JSON.generate(tampered))
    code, output, = run_cli(["receipt", "verify", receipt_path, "--format", "json"])
    assert_equal 2, code
    validation = JSON.parse(output)
    assert_equal "invalid", validation.fetch("status")
    assert_nil validation.fetch("gate")
  end

  def test_missing_receipt_file_reports_error_on_stderr
    code, _stdout, stderr = run_cli(["receipt", "verify", File.join(@dir, "nope.json"), "--format", "json"])
    assert_equal 2, code
    assert_match(/cannot read receipt/, stderr)
  end

  def test_untracked_receipt_file_itself_changes_state
    # A receipt written INTO the repository becomes part of observable state:
    # verifying it afterwards must report stale (untracked state changed).
    receipt_path = File.join(@dir, "inside.receipt.json")
    code, stdout, = create_receipt(extra: ["--output", receipt_path])
    assert_equal 0, code
    code, output, = run_cli(["receipt", "verify", receipt_path, "--format", "json"])
    assert_equal 2, code
    validation = JSON.parse(output)
    assert_equal "stale", validation.fetch("status")
    assert_includes validation.fetch("reasons"), "worktree_changed"
  ensure
    FileUtils.rm_f(receipt_path)
  end

  def test_usage_errors
    code, _stdout, stderr = run_cli(["receipt"])
    assert_equal 2, code
    assert_match(/requires a subcommand/, stderr)

    code, _stdout, stderr = run_cli(["receipt", "create", "--base", "HEAD~1"])
    assert_equal 2, code
    assert_match(/--base requires --changed/, stderr)
  end

  def test_changed_scope_receipt_binds_base
    write("more.rb", "y\n")
    commit
    code, stdout, stderr = create_receipt(extra: ["--changed", "--base", "HEAD~1"])
    assert_equal 0, code, stderr
    document = JSON.parse(stdout)
    assert_equal "changed", document.fetch("verification_mode")
    assert_match(/\A[0-9a-f]{7,64}\z/, document.dig("changed_scope", "base"))
    assert document.dig("pr_intelligence", "digest"), "changed scope must bind PR Intelligence digest"
  end

  def test_external_waiver_file_is_bound_into_identity_and_freshness
    # Inputs outside the working directory are rejected outright, so an
    # adversarial "invisible input" cannot participate in verification.
    # Config-declared paths INSIDE the repo (including gitignored ones) must
    # be bound into identity and freshness.
    state_dir = File.join(@dir, ".local-state")
    FileUtils.mkdir_p(state_dir)
    File.write(File.join(@dir, ".gitignore"), ".local-state/\n")
    File.write(File.join(@dir, ".railverdict.yml"),
               "version: 1.2
mode: strict
waivers:
  path: .local-state/waivers.json\nanalyzers:\n  rubocop: { enabled: true, required: true }\n")
    commit
    waiver = File.join(state_dir, "waivers.json")
    File.write(waiver, '{"schema_version":"1.0","waivers":[]}')
    code, stdout, stderr = create_receipt
    assert_equal 0, code, stderr
    document = JSON.parse(stdout)
    refute_nil document.dig("repository_state", "waivers_digest"),
              "config-declared waiver content must appear in the receipt identity"

    receipt_path = File.join(state_dir, "receipt.json")
    File.binwrite(receipt_path, JSON.generate(document))
    validation, = run_validation(receipt_path)
    assert_equal "fresh", validation.fetch("status")

    File.write(waiver, '{"schema_version":"1.0","waivers":[{"fingerprint":"sha256:#{"a" * 64}","reason":"x","owner":"y","created_at":"2026-01-01T00:00:00Z","expires_at":"2099-01-01T00:00:00Z"}]}')
    stale, = run_validation(receipt_path)
    assert_equal "stale", stale.fetch("status")
    assert_includes stale.fetch("reasons"), "waivers_changed"
  ensure
    FileUtils.rm_rf(state_dir) if defined?(state_dir)
  end

  def test_create_rejects_paths_escaping_working_directory
    outside = File.join(Dir.tmpdir, "rv-outside-waivers.json")
    File.write(outside, "{}")
    begin
      code, _stdout, stderr = run_cli(["receipt", "create", "--format", "json", "--waiver", outside])
      assert_equal 2, code
      assert_match(/escapes working directory/, stderr)
    ensure
      FileUtils.rm_f(outside)
    end
  end

  def test_verify_rejects_out_of_root_input_overrides
    _code, stdout, = create_receipt
    receipt_path = File.join(@dir, "..", "#{File.basename(@dir)}.receipt.json")
    File.binwrite(receipt_path, stdout)
    outside = File.join(Dir.tmpdir, "rv-verify-escape-waivers.json")
    File.write(outside, '{"schema_version":"1.0","waivers":[]}')
    begin
      code, _output, stderr = run_cli(["receipt", "verify", receipt_path, "--format", "json", "--waiver", outside])
      assert_equal 2, code
      assert_match(/escapes working directory/, stderr, "verify must reject out-of-root overrides or a fraudulent verify could mask staleness")
      code2, _o, err2 = run_cli(["receipt", "verify", receipt_path, "--format", "json", "--baseline", outside])
      assert_equal 2, code2
      assert_match(/escapes working directory/, err2)
    ensure
      FileUtils.rm_f(receipt_path)
      FileUtils.rm_f(outside)
    end
  end

  def test_gitignored_input_files_are_still_bound
    ignored_dir = File.join(@dir, ".local-state")
    FileUtils.mkdir_p(ignored_dir)
    File.write(File.join(@dir, ".gitignore"), ".local-state/\n")
    commit
    waiver = File.join(ignored_dir, "waivers.json")
    File.write(waiver, '{"schema_version":"1.0","waivers":[]}')
    code, stdout, = create_receipt(extra: ["--waiver", waiver])
    assert_equal 0, code
    document = JSON.parse(stdout)
    refute_nil document.dig("repository_state", "waivers_digest"),
               "gitignored inputs are invisible to git status but must still be bound by content"
  ensure
    FileUtils.rm_rf(ignored_dir) if defined?(ignored_dir)
  end
end
