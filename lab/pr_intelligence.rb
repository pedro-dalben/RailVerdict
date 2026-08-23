# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
RUBOCOP_CONFIG = <<~YAML
  version: 1.4
  mode: no_new_debt
  analyzers:
    rubocop: { enabled: true, required: true }
    minitest: { enabled: false, required: false }
    rspec: { enabled: false, required: false }
    simplecov: { enabled: false, required: false }
    bundler_audit: { enabled: false, required: false }
YAML
NO_ANALYZERS_CONFIG = <<~YAML
  version: 1.4
  mode: strict
  analyzers:
    rubocop: { enabled: false, required: false }
    minitest: { enabled: false, required: false }
    rspec: { enabled: false, required: false }
    simplecov: { enabled: false, required: false }
    bundler_audit: { enabled: false, required: false }
YAML

def git!(directory, *arguments)
  system("git", "-C", directory, *arguments, exception: true, out: File::NULL, err: File::NULL)
end

def git_output(directory, *arguments)
  IO.popen(["git", "-C", directory, *arguments], &:read).strip
end

def run_pr(directory, base:, environment: {})
  command = [RbConfig.ruby, "-I#{File.join(ROOT, "lib")}", File.join(ROOT, "exe/railverdict"), "pr", "--base", base, "--format", "json"]
  stdout, stderr, status = Open3.capture3(environment, *command, chdir: directory)
  document = JSON.parse(stdout)
  [status.exitstatus, document, stderr]
rescue JSON::ParserError
  raise "PR command did not return JSON (exit #{status&.exitstatus}): #{stderr}#{stdout}"
end

def run_railverdict(directory, *arguments, environment: {})
  command = [RbConfig.ruby, "-I#{File.join(ROOT, "lib")}", File.join(ROOT, "exe/railverdict"), *arguments]
  Open3.capture3(environment, *command, chdir: directory)
end

def consumer(config: NO_ANALYZERS_CONFIG)
  directory = Dir.mktmpdir("railverdict-lab-")
  File.write(File.join(directory, ".railverdict.yml"), config)
  FileUtils.mkdir_p(File.join(directory, "app/models"))
  FileUtils.mkdir_p(File.join(directory, "config"))
  FileUtils.mkdir_p(File.join(directory, "db"))
  File.write(File.join(directory, "app/models/order.rb"), "class Order; end\n")
  File.write(File.join(directory, "config/routes.rb"), "Rails.application.routes.draw { root to: 'orders#index' }\n")
  git!(directory, "init", "-q", "-b", "main")
  git!(directory, "config", "user.email", "lab@example.test")
  git!(directory, "config", "user.name", "RailVerdict Lab")
  git!(directory, "add", ".")
  git!(directory, "commit", "-qm", "synthetic base")
  directory
end

def assert!(condition, message)
  raise message unless condition
end

def route_signal_scenario
  directory = consumer
  base = git_output(directory, "rev-parse", "HEAD")
  File.write(File.join(directory, "config/routes.rb"), "Rails.application.routes.draw { root to: 'orders#show' }\n")
  git!(directory, "add", "config/routes.rb")
  git!(directory, "commit", "-qm", "change routes")
  exit_code, document, stderr = run_pr(directory, base: base)
  assert!(exit_code == 0, "route signal command failed: #{stderr}")
  assert!(document.dig("signals", "routes_change", "present"), "route signal was not present")
ensure
  FileUtils.remove_entry(directory) if directory && File.directory?(directory)
end

def write_fake_rubocop(directory)
  bin = File.join(directory, "bin")
  FileUtils.mkdir_p(bin)
  executable = File.join(bin, "rubocop")
  File.write(executable, <<~'RUBY')
    #!/usr/bin/env ruby
    require "json"

    if ARGV.include?("--version")
      puts "1.88.0"
      exit 0
    end

    offenses = []
    offenses << ["Style/StringLiterals", 1, "synthetic baseline offense"] if File.file?("baseline.marker")
    offenses << ["Lint/UselessAssignment", 2, "synthetic introduced offense"] if File.file?("new.marker")
    files = offenses.empty? ? [] : [{
      "path" => "app/models/order.rb",
      "offenses" => offenses.map do |cop_name, line, message|
        {
          "cop_name" => cop_name,
          "severity" => "warning",
          "message" => message,
          "location" => { "start_line" => line, "last_line" => line }
        }
      end
    }]
    puts JSON.generate("files" => files)
  RUBY
  File.chmod(0o755, executable)
  bin
end

def quality_delta_scenario
  directory = consumer(config: RUBOCOP_CONFIG)
  bin = write_fake_rubocop(directory)
  File.write(File.join(directory, "baseline.marker"), "baseline\n")
  git!(directory, "add", "baseline.marker", "bin/rubocop")
  git!(directory, "commit", "-qm", "controlled baseline")
  base = git_output(directory, "rev-parse", "HEAD")
  path = [bin, ENV.fetch("PATH")].join(File::PATH_SEPARATOR)
  stdout, stderr, status = run_railverdict(directory, "baseline", "create", "--format", "json", environment: { "PATH" => path })
  assert!(status.success?, "baseline creation failed: #{stderr}#{stdout}")

  File.write(File.join(directory, "new.marker"), "introduced\n")
  git!(directory, "add", "new.marker")
  git!(directory, "commit", "-qm", "controlled introduction")
  introduced_base = git_output(directory, "rev-parse", "HEAD")
  exit_code, introduced, stderr = run_pr(directory, base: base, environment: { "PATH" => path })
  assert!(exit_code == 0 || exit_code == 1, "introduced quality delta command failed: #{stderr}")
  assert!(introduced.dig("quality_delta", "available"), "introduced quality delta was unavailable")
  assert!(introduced.dig("quality_delta", "introduced") == 1, "introduced quality delta was not one")

  FileUtils.rm_f(File.join(directory, "baseline.marker"))
  FileUtils.rm_f(File.join(directory, "new.marker"))
  git!(directory, "add", "baseline.marker", "new.marker")
  git!(directory, "commit", "-qm", "controlled resolution")
  exit_code, resolved, stderr = run_pr(directory, base: introduced_base, environment: { "PATH" => path })
  assert!(exit_code == 0, "resolved quality delta command failed: #{stderr}")
  assert!(resolved.dig("quality_delta", "available"), "resolved quality delta was unavailable")
  assert!(resolved.dig("quality_delta", "resolved") == 1, "resolved quality delta was not one")
ensure
  FileUtils.remove_entry(directory) if directory && File.directory?(directory)
end

def incomplete_evidence_scenario
  directory = consumer(config: RUBOCOP_CONFIG)
  bin = File.join(directory, "missing-bin")
  FileUtils.mkdir_p(bin)
  missing = File.join(bin, "rubocop")
  File.write(missing, "#!/bin/sh\necho 'synthetic rubocop unavailable' >&2\nexit 127\n")
  File.chmod(0o755, missing)
  base = git_output(directory, "rev-parse", "HEAD")
  File.write(File.join(directory, "config/routes.rb"), "Rails.application.routes.draw { root to: 'orders#show' }\n")
  git!(directory, "add", "config/routes.rb")
  git!(directory, "commit", "-qm", "incomplete evidence")
  exit_code, document, stderr = run_pr(directory, base: base, environment: { "PATH" => "#{bin}:#{ENV.fetch("PATH")}" })
  assert!(exit_code == 2, "incomplete evidence returned #{exit_code}: #{stderr}")
  assert!(document.dig("gate_result", "completion_status") == "incomplete", "incomplete evidence was normalized")
  assert!(document.dig("gate_result", "gate") == "INCOMPLETE", "incomplete evidence changed the gate")
ensure
  FileUtils.remove_entry(directory) if directory && File.directory?(directory)
end

route_signal_scenario
quality_delta_scenario
incomplete_evidence_scenario
puts "RailVerdict Lab PR Intelligence: PASS (route signal, quality delta, incomplete evidence)"
