---
phase: 01-trustworthy-core
plan: "06"
subsystem: vertical-check-and-verification
tags: [check, cli, fixtures, determinism, offline]

requires: ["01-05"]
provides:
  - Working offline `railverdict check` vertical path
  - Functional init, doctor, and findings commands
  - Synthetic Rails fixtures and negative execution corpus
  - Phase 01 validation and determinism evidence

tech-stack:
  added: []
  patterns: [outcome-based-orchestration, phase-aware-foundation-validator, synthetic-only-e2e]

key-files:
  created:
    - lib/rail_verdict/check.rb
    - lib/rail_verdict/init.rb
    - lib/rail_verdict/doctor.rb
    - lib/rail_verdict/findings_command.rb
    - test/test_check_e2e.rb
    - test/test_determinism.rb
    - test/fixtures/rails_clean/
    - test/fixtures/rails_offense/
    - .planning/phases/01-trustworthy-core/01-VALIDATION.md
  modified:
    - lib/rail_verdict/cli.rb
    - script/validate-foundation
    - docs/contracts.md

key-decisions:
  - "Child execution excludes RUBYOPT and RUBYLIB so RailVerdict's parent Bundler context cannot hijack target RuboCop resolution."
  - "Findings is a complete-evidence projection and returns exit 0 regardless of policy findings; incomplete evidence remains exit 2."
  - "Phase 0's no-production validator boundary retires when the Phase 1 runtime scaffold exists; its network and namespace checks remain active."
  - "Contracts are marked implemented in Phase 01 while compatibility remains provisional and Phase 3/4 ownership boundaries remain explicit."

requirements-completed:
  - CORE-01
  - CORE-02
  - CORE-08
  - CORE-12
  - CORE-13
  - CORE-14

duration: 30 min
completed: 2026-08-16
status: complete
---

# Phase 01 Plan 6: Vertical Check and Deterministic Verification Summary

## Accomplishments

- Wired configuration, RunContext, safe Git revision observation, RuboCop, AnalyzerResult, Finding normalization, policy, GateResult, reporters, and CLI exit mapping into one working path.
- Implemented `init`, `doctor`, and `findings`; preserved `baseline create` and changed-scope options as explicit deferred boundaries.
- Added real-RuboCop clean/offense Rails-style fixtures and synthetic unavailable, unsupported, malformed, non-zero, timeout, oversized, and invalid-configuration paths.
- Proved canonical JSON and console behavior across locale, timezone, ordering, scheduling, and temporary-root variations.
- Updated contracts and the foundation validator to distinguish Phase 01 implementation from publication-only and later-phase boundaries.

## Task Commits

1. Task 1: Wire trustworthy check vertical path — `0ec7a4a` (feat)
2. Task 2: Prove synthetic end-to-end verification — `9c06e53` (test)

Additional concrete remediation: `97733a2` prevents parent Bundler environment injection from changing target analyzer resolution.

## Validation Evidence

- `bundle exec rake test`: 121 runs, 588 assertions, 0 failures, 0 errors, 0 skips.
- Clean fixture command exits `0` with `PASS`.
- Offense fixture JSON command exits `1` with schema-valid `FAIL`.
- Required evidence failures exit `2` with schema-valid `INCOMPLETE` and `not_evaluated` policy.
- `script/validate-foundation` passes, with provenance honestly `NOT RUN` when no private corpus is supplied.
- `gem build rail_verdict.gemspec` succeeds.

## Deviations

- Removed `RUBYOPT` and `RUBYLIB` from child environment after real fixture execution showed parent Bundler context hijacking bare RuboCop. This is a concrete process-boundary correction, not a Phase 00 architecture change.

## Next Phase Readiness

Phase 02 may add the planned evidence adapters. Baselines, production changed scope, AI, GitHub, MCP, and publication work remain out of scope.
