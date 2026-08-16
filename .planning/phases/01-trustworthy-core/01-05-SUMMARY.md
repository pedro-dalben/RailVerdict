---
phase: 01-trustworthy-core
plan: "05"
subsystem: policy-and-reporting
tags: [gate-result, policy, fail-closed, console, json]

requires: ["01-04"]
provides:
  - Immutable result-v1 GateResult envelope
  - Sole deterministic Phase 1 policy evaluator
  - Pure deterministic console and schema-validating JSON reporters

tech-stack:
  added: []
  patterns: [policy-owned-gate-authority, result-schema-validation, diagnostic-free-json]

key-files:
  created:
    - lib/rail_verdict/contracts/gate_result.rb
    - lib/rail_verdict/verification/policy.rb
    - lib/rail_verdict/reporters/console.rb
    - lib/rail_verdict/reporters/json_reporter.rb
    - test/test_gate_result.rb
    - test/test_policy.rb
    - test/test_reporters.rb
  modified:
    - lib/rail_verdict.rb

key-decisions:
  - "Required incomplete evidence yields INCOMPLETE/not_evaluated; optional incomplete evidence remains visible while a complete gate may proceed."
  - "advisory yields WARN for findings; strict and Phase 1 no_new_debt yield FAIL; no_new_debt explicitly records Phase 3 deferral."
  - "Console projects result summaries only because result-v1 intentionally excludes analyzer-specific full finding fields; JSON stays exactly result-v1."

requirements-completed:
  - CORE-11
  - CORE-12

duration: 12 min
completed: 2026-08-16
status: complete
---

# Phase 01 Plan 5: Policy and Reporting Summary

## Accomplishments

- Added immutable GateResult with result-v1 coupling and strict summary/operational-failure validation.
- Added policy-only gate authority with complete/incomplete semantics, advisory WARN, strict/no_new_debt FAIL, optional evidence visibility, and deterministic reasons.
- Added deterministic console output with control-character sanitization and JSON output that validates against result-v1 before emission.
- Proved the invariant that every non-succeeded required analyzer status cannot produce PASS.

## Task Commits

1. Task 1: Centralize policy gate authority — `5b1c4c2` (feat)
2. Task 2: Add deterministic console and JSON reporters — `9ecdaa5` (feat)

## Validation Evidence

- `bundle exec rake test`: 102 runs, 488 assertions, 0 failures, 0 errors.
- Complete and incomplete result envelopes validate against `schemas/result-v1.schema.json`.
- JSON reporter emits one newline-terminated document; console and JSON output are deterministic.
- `git diff --check` passes.

## Deviations

None.

## Next Plan Readiness

Check orchestration can now connect configuration, RunContext, RuboCop, policy, reporters, and stable exits.
