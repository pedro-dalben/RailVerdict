# frozen_string_literal: true

require_relative "lib/rail_verdict/version"

Gem::Specification.new do |spec|
  spec.name = "rail_verdict"
  spec.version = RailVerdict::VERSION
  spec.authors = ["RailVerdict Maintainers"]
  spec.summary = "Deterministic, offline, fail-closed merge verification for Ruby on Rails projects"
  spec.description = <<~DESCRIPTION
    RailVerdict collects evidence from established Ruby and Rails quality
    tools, normalizes it into stable findings, applies project policy, and
    returns a deterministic merge gate for humans, CI, and coding agents.
    The core is offline, fail-closed, and independent of AI and hosted
    services.
  DESCRIPTION
  spec.homepage = "https://railverdict.dev"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir[
    "lib/**/*.rb",
    "exe/railverdict",
    "schemas/*.json",
    "README.md",
    "LICENSE",
    "NOTICE"
  ]
  spec.bindir = "exe"
  spec.executables = ["railverdict"]
  spec.require_paths = ["lib"]

  spec.add_dependency "json_schemer", ">= 2.5", "< 3"
  spec.add_dependency "mcp", ">= 1.2", "< 2"

  spec.metadata["rubygems_mfa_required"] = "true"
end
