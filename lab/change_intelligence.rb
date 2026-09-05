# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
NO_ANALYZERS_CONFIG = <<~YAML
  version: 1.6
  mode: strict
  analyzers:
    rubocop: { enabled: false, required: false }
    minitest: { enabled: false, required: false }
    rspec: { enabled: false, required: false }
    simplecov: { enabled: false, required: false }
    bundler_audit: { enabled: false, required: false }
YAML
PROJECT_REVIEW_CONFIG = <<~YAML
  version: 1.6
  mode: strict
  analyzers:
    rubocop: { enabled: false, required: false }
    minitest: { enabled: false, required: false }
    rspec: { enabled: false, required: false }
    simplecov: { enabled: false, required: false }
    bundler_audit: { enabled: false, required: false }
  review:
    sensitive_paths:
      financial:
        - "app/services/billing/**"
        - "app/models/payment.rb"
    risk:
      dependencies: critical
YAML

def git!(directory, *arguments)
  system("git", "-C", directory, *arguments, exception: true, out: File::NULL, err: File::NULL)
end

def run_pr(directory, base:)
  command = [RbConfig.ruby, "-I#{File.join(ROOT, "lib")}", File.join(ROOT, "exe/railverdict"), "pr", "--base", base, "--format", "json"]
  stdout, stderr, status = Open3.capture3(*command, chdir: directory)
  [status.exitstatus, JSON.parse(stdout), stderr]
rescue JSON::ParserError
  raise "PR command did not return JSON (exit #{status&.exitstatus}): #{stderr}#{stdout}"
end

def consumer(config: NO_ANALYZERS_CONFIG)
  directory = Dir.mktmpdir("railverdict-lab-ci-")
  File.write(File.join(directory, ".railverdict.yml"), config)
  FileUtils.mkdir_p(File.join(directory, "app/models"))
  FileUtils.mkdir_p(File.join(directory, "app/controllers"))
  FileUtils.mkdir_p(File.join(directory, "app/services/billing"))
  FileUtils.mkdir_p(File.join(directory, "config"))
  File.write(File.join(directory, "app/models/order.rb"), "class Order; end\n")
  File.write(File.join(directory, "config/routes.rb"), "Rails.application.routes.draw { root to: 'orders#index' }\n")
  File.write(File.join(directory, "Gemfile"), "source 'https://rubygems.org'\n")
  git!(directory, "init", "-q", "-b", "main")
  git!(directory, "config", "user.email", "lab@example.test")
  git!(directory, "config", "user.name", "RailVerdict Lab")
  git!(directory, "add", ".")
  git!(directory, "commit", "-qm", "synthetic base")
  directory
end

def base_of(directory)
  IO.popen(["git", "-C", directory, "rev-parse", "HEAD"], &:read).strip
end

def assert!(condition, message)
  raise message unless condition
end

def commit_all!(directory, message)
  git!(directory, "add", ".")
  git!(directory, "commit", "-qm", message)
end

def authorization_scenario
  directory = consumer
  FileUtils.mkdir_p(File.join(directory, "app/policies"))
  File.write(File.join(directory, "app/policies/order_policy.rb"), "class OrderPolicy; end\n")
  commit_all!(directory, "authorization change")
  exit_code, document, _stderr = run_pr(directory, base: base_of(directory).then { |head| `git -C #{directory} rev-parse HEAD~1`.strip })
  assert!(exit_code == 0, "authorization pr exits 0, got #{exit_code}")
  assert!(document["schema_version"] == "1.1", "schema 1.1, got #{document["schema_version"]}")
  assert!(document.dig("surfaces", "authorization", "changed") == true, "authorization surface changed")
  assert!(document.dig("surfaces", "authorization", "evidence") == ["app/policies/order_policy.rb"], "authorization evidence exact")
  assert!(document.dig("review_risk", "level") == "HIGH", "risk HIGH")
  assert!(document.dig("review_risk", "reasons").include?("authorization_surface_changed"), "risk reason present")
  assert!(document.dig("review_focus", 0, "surface") == "authorization", "focus rank 1 is authorization")
  codes = document.dig("missing_evidence").map { |gap| gap["code"] }
  assert!(codes.include?("authorization_changed_verification_not_established"), "auth verification gap reported as unknown")
  assert!(document.dig("gate_result", "gate") == "PASS", "gate authority untouched")
end

def migration_and_dependency_scenario
  directory = consumer
  FileUtils.mkdir_p(File.join(directory, "db/migrate"))
  File.write(File.join(directory, "db/migrate/20260801000000_add_index.rb"), "class AddIndex < ActiveRecord::Migration[8.0]; end\n")
  File.write(File.join(directory, "Gemfile.lock"), "GEM\n")
  commit_all!(directory, "migration plus dependency")
  exit_code, document, _stderr = run_pr(directory, base: `git -C #{directory} rev-parse HEAD~1`.strip)
  assert!(exit_code == 0, "migration pr exits 0")
  assert!(document.dig("surfaces", "migration", "changed") == true, "migration detected")
  assert!(document.dig("surfaces", "dependencies", "changed") == true, "dependency detected")
  rspec = document.dig("verification_scope", "frameworks", "rspec")
  assert!(rspec["scope"] == "full", "dependency forces full scope")
  assert!(rspec["fallback_reason"].to_s.start_with?("shared_infrastructure_changed:"), "fallback reason names Gemfile.lock")
  signals = document.dig("review_signals").map { |signal| signal["code"] }
  assert!(signals.include?("migration_added"), "migration signal code")
  assert!(signals.include?("dependency_changed"), "dependency signal code")
end

def project_sensitive_scenario
  directory = consumer(config: PROJECT_REVIEW_CONFIG)
  File.write(File.join(directory, "app/services/billing/charge.rb"), "class Charge; end\n")
  commit_all!(directory, "billing change")
  exit_code, document, _stderr = run_pr(directory, base: `git -C #{directory} rev-parse HEAD~1`.strip)
  assert!(exit_code == 0, "project sensitive pr exits 0")
  areas = document["project_sensitive_areas"]
  financial = areas.find { |area| area["name"] == "financial" }
  assert!(financial && financial["changed"] == true, "project financial area detected")
  signals = document.dig("review_signals").map { |signal| signal["code"] }
  assert!(signals.include?("project_sensitive_path_changed:financial"), "project signal code")
  assert!(document.dig("review_risk", "configured") == true, "project risk config honored")
end

def adversarial_ambiguous_auth_scenario
  directory = consumer
  FileUtils.mkdir_p(File.join(directory, "app/services"))
  File.write(File.join(directory, "app/services/order_access.rb"), "class OrderAccess\n  def allowed?(user)\n    user.admin?\n  end\nend\n")
  commit_all!(directory, "generic service with access logic")
  exit_code, document, _stderr = run_pr(directory, base: `git -C #{directory} rev-parse HEAD~1`.strip)
  assert!(exit_code == 0, "adversarial pr exits 0")
  assert!(document.dig("surfaces", "authorization", "changed") == false,
    "no false authorization claim from generic service filename")
  assert!(document.dig("review_risk", "level") == "LOW", "no inflated risk, got #{document.dig("review_risk", "level")}")
end

def adversarial_renamed_policy_scenario
  directory = consumer
  FileUtils.mkdir_p(File.join(directory, "app/policies"))
  File.write(File.join(directory, "app/policies/user_policy.rb"), "class UserPolicy; end\n")
  commit_all!(directory, "base policy")
  FileUtils.mv(File.join(directory, "app/policies/user_policy.rb"), File.join(directory, "app/policies/account_policy.rb"))
  commit_all!(directory, "renamed policy")
  exit_code, document, _stderr = run_pr(directory, base: `git -C #{directory} rev-parse HEAD~1`.strip)
  assert!(exit_code == 0, "rename pr exits 0")
  evidence = document.dig("surfaces", "authorization", "evidence")
  assert!(document.dig("surfaces", "authorization", "changed") == true, "renamed policy still detected")
  assert!(evidence.include?("app/policies/account_policy.rb") && evidence.include?("app/policies/user_policy.rb"),
    "rename evidence covers old and new path, got #{evidence.inspect}")
end

def contract_validation_scenario
  directory = consumer
  File.write(File.join(directory, "config/routes.rb"), "Rails.application.routes.draw { root to: 'orders#show' }\n")
  commit_all!(directory, "routes change")
  exit_code, document, _stderr = run_pr(directory, base: `git -C #{directory} rev-parse HEAD~1`.strip)
  assert!(exit_code == 0, "contract pr exits 0")
  assert!(document.dig("surfaces", "routes", "changed") == true, "routes detected")
  assert!(document.dig("review_signals").any? { |signal| signal["code"] == "routes_changed" }, "routes signal")
  focus_surfaces = document.dig("review_focus").map { |item| item["surface"] }
  assert!(focus_surfaces.include?("routes"), "routes in focus")
  assert!(document.dig("review_focus").all? { |item| item["rank"].is_a?(Integer) && !item["reason"].empty? }, "focus ranked with reasons")
end

authorization_scenario
migration_and_dependency_scenario
project_sensitive_scenario
adversarial_ambiguous_auth_scenario
adversarial_renamed_policy_scenario
contract_validation_scenario
puts "RailVerdict Lab Change Intelligence: PASS (authorization, migration+dependency, project areas, adversarial x2, contract)"
