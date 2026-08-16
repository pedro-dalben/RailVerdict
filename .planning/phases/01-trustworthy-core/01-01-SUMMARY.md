---
phase: 01-trustworthy-core
plan: "01"
subsystem: gem-and-cli
tags: [gem, cli, exit-codes, minitest]

requires: []
provides:
  - One gem rail_verdict with executable railverdict
  - Contracted five-command CLI surface with exit-2 usage and deferral semantics
  - Minitest harness under rake test
affects: [configuration, process-runner, rubocop-adapter, policy, reporters]

tech-stack:
  added:
    - json_schemer 2.5.0 (runtime, schema validation)
    - minitest 6.0.6 (test)
    - rake 13.4.2 (build)
  patterns: [single-result-to-exit-mapping, optionparser-only-cli]

key-files:
  created:
    - rail_verdict.gemspec
    - Gemfile
    - Gemfile.lock
    - Rakefile
    - .gitignore
    - exe/railverdict
    - lib/rail_verdict.rb
    - lib/rail_verdict/version.rb
    - lib/rail_verdict/errors.rb
    - lib/rail_verdict/cli.rb
    - test/test_helper.rb
    - test/test_cli_surface.rb
  modified: []

key-decisions:
  - "json_schemer is the single intentional runtime dependency and its transitive deps (bigdecimal, hana, regexp_parser, simpleidn) are locked in Gemfile.lock."
  - "Positional leftovers after option parsing are usage errors; usage text goes to stdout only for --help."

requirements-completed:
  - CORE-01 (surface skeleton; behaviors wired in plan 06)
  - CORE-13 (single exit-mapping point; full mapping proven in plan 06)

duration: 12 min
completed: 2026-08-16
status: complete
---

# Phase 01 Plan 1: Gem and CLI Foundation Summary

## Accomplishments

- Created the one-gem foundation with exact Phase 00 identity mapping (`rail_verdict` / `RailVerdict` / `railverdict`).
- CLI parses the five contracted command surfaces with exact draft options and maps unknown commands/options, deferred `baseline create`, and deferred `--changed`/`--base` to exit 2 with diagnostics on stderr.
- `--version` and `--help` exit 0; 13 surface tests pass (`rake test`).

## Task Commits

1. Task 1: Create gem foundation — `c6c11a4` (feat)
2. Task 2: Implement CLI surface and exit skeleton — `d47944d` (feat)

## Deviations from Plan

None.

## Next Plan Readiness

Configuration and RunContext (01-02) can build on `RailVerdict::Error`, `UsageError`, and `ConfigurationError`.
