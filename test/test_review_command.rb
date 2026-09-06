# frozen_string_literal: true

require_relative "test_helper"

# End-to-end exit-ladder tests for `railverdict review` and `repair verify`
# (1.8): packet projection, observation validation, workflow closure, and the
# CLI repair loop — all against real git fixtures and real analyzer runs.
class TestReviewCommand < Minitest::Test
  CONFIG = <<~YAML
    version: 1.7
    mode: advisory
    analyzers:
      rubocop:
        enabled: true
        required: false
  YAML

  def make_repo(config: CONFIG)
    dir = Dir.mktmpdir
    File.write(File.join(dir, ".railverdict.yml"), config)
    Dir.chdir(dir) do
      system("git init -b main -q 2>/dev/null")
      system("git config user.email 't@t.com' 2>/dev/null")
      system("git config user.name 'T' 2>/dev/null")
      File.write(File.join(dir, "a.rb"), "x = 1\n")
      system("git add . 2>/dev/null")
      system("git commit -qm init 2>/dev/null")
      yield dir if block_given?
    end
    dir
  end

  def test_review_show_mirrors_policy_decision
    with_tmpdir do |dir|
      repo = make_repo
      exit_code, stdout, _stderr = run_cli(["review", "show", "--format", "json", "--base", "HEAD"],
        working_directory: repo)
      assert_equal 0, exit_code
      packet = JSON.parse(stdout)
      assert_empty RailVerdict::SchemaValidator.validate_review_packet(packet)
      assert_equal "PASS", packet["deterministic"]["verification"]["gate"]
      assert_match(/\Asha256:[0-9a-f]{64}\z/, packet["packet_id"])
      FileUtils.remove_entry(repo)
    end
  end

  def test_review_bare_is_show
    with_tmpdir do |dir|
      repo = make_repo
      exit_code, _stdout, _stderr = run_cli(["review", "--format", "json", "--base", "HEAD"],
        working_directory: repo)
      assert_equal 0, exit_code
      FileUtils.remove_entry(repo)
    end
  end

  def test_review_observe_valid_and_tampered
    with_tmpdir do |dir|
      repo = make_repo
      head = `git -C #{repo} rev-parse HEAD`.strip
      config = RailVerdict::Configuration.load(File.join(repo, ".railverdict.yml"))
      policy_digest = RailVerdict::EngineeringPolicy.policy_digest(
        RailVerdict::EngineeringPolicy.effective_policy(config))
      document = RailVerdict::ReviewObservation.build(author: "human", confidence: "medium",
        state_binding: { "head" => head, "configuration_digest" => config.digest, "policy_digest" => policy_digest },
        observations: [{ "summary" => "checked" }])
      path = File.join(dir, "obs.json")
      File.write(path, JSON.generate(document))

      exit_code, stdout, _stderr = run_cli(["review", "observe", "--observation", path, "--format", "json"],
        working_directory: repo)
      assert_equal 0, exit_code
      assert_equal "valid_bound", JSON.parse(stdout)["observations"].first["status"]

      tampered = document.merge("confidence" => "high")
      File.write(path, JSON.generate(tampered))
      exit_code, stdout, _stderr = run_cli(["review", "observe", "--observation", path, "--format", "json"],
        working_directory: repo)
      assert_equal 2, exit_code
      assert_equal "invalid", JSON.parse(stdout)["observations"].first["status"]
      FileUtils.remove_entry(repo)
    end
  end

  def test_review_complete_reports_readiness
    with_tmpdir do |dir|
      repo = make_repo do |inner|
        Dir.chdir(inner) do
          FileUtils.mkdir_p("db/migrate")
          File.write("db/migrate/001_x.rb", "m\n")
          system("git add . 2>/dev/null")
          system("git commit -qm migration 2>/dev/null")
        end
      end
      config = <<~YAML
        version: 1.7
        mode: advisory
        analyzers:
          rubocop:
            enabled: false
            required: false
        engineering_policy:
          review:
            high:
              human_review: required
      YAML
      File.write(File.join(repo, ".railverdict.yml"), config)
      exit_code, stdout, _stderr = run_cli(["review", "complete", "--format", "json", "--base", "HEAD~1"],
        working_directory: repo)
      assert_equal 3, exit_code
      receipt = JSON.parse(stdout)
      assert_equal "review_pending", receipt["readiness"]
      assert_empty RailVerdict::SchemaValidator.validate_workflow_receipt(receipt)
      FileUtils.remove_entry(repo)
    end
  end

  def test_repair_verify_closes_loop_on_fix
    with_tmpdir do |dir|
      repo = Dir.mktmpdir
      File.write(File.join(repo, ".railverdict.yml"), CONFIG)
      Dir.chdir(repo) do
        system("git init -b main -q 2>/dev/null")
        system("git config user.email 't@t.com' 2>/dev/null")
        system("git config user.name 'T' 2>/dev/null")
        File.write("bad.rb", "y = 2   \n")
        system("git add . 2>/dev/null")
        system("git commit -qm offense 2>/dev/null")
      end
      exit_code, stdout, _stderr = run_cli(["check", "--format", "json"], working_directory: repo)
      assert_equal 0, exit_code
      findings = JSON.parse(stdout)["findings"]
      refute_empty findings
      finding_id = findings.first["id"]
      exit_code, stdout, _stderr = run_cli(["repair", finding_id, "--format", "json"], working_directory: repo)
      assert_equal 0, exit_code
      packet = JSON.parse(stdout)
      packet_path = File.join(dir, "packet.json")
      File.write(packet_path, JSON.generate(packet))
      assert packet["verification_plan"].key?("execution")

      exit_code, _stdout, _stderr = run_cli(["repair", "verify", "--packet", packet_path, "--format", "json"],
        working_directory: repo)
      assert_equal 1, exit_code

      Dir.chdir(repo) do
        File.write("bad.rb", "# frozen_string_literal: true\nputs 2\n")
      end
      exit_code, stdout, _stderr = run_cli(["repair", "verify", "--packet", packet_path, "--format", "json"],
        working_directory: repo)
      assert_equal 0, exit_code
      assert_equal "successful", JSON.parse(stdout)["overall_status"]
      FileUtils.remove_entry(repo)
    end
  end
end
