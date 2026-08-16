---
phase: 01-trustworthy-core
plan: "04"
subsystem: evidence-contracts-and-rubocop
tags: [finding, analyzer-result, rubocop, normalization, fail-closed]

requires: ["01-02", "01-03"]
provides:
  - Finding v1 value object with draft deterministic fingerprint identity
  - AnalyzerResult execution/completeness contract
  - Narrow RuboCop adapter with supported-version and structured-output parsing
affects: [policy, gate-result, reporters, check]

tech-stack:
  added: []
  patterns: [immutable-evidence-values, explicit-operational-failures, bundle-preferring-adapter]

key-files:
  created:
    - lib/rail_verdict/contracts/finding.rb
    - lib/rail_verdict/contracts/analyzer_result.rb
    - lib/rail_verdict/analyzers/rubocop.rb
    - test/test_finding.rb
    - test/test_analyzer_result.rb
    - test/test_rubocop_adapter.rb
  modified:
    - lib/rail_verdict.rb

key-decisions:
  - "Phase 1 uses a documented draft SHA-256 payload excluding line numbers; Phase 3 owns final fingerprint migration and collision behavior."
  - "RuboCop exit 1 with valid JSON is a successful analyzer run because it represents offenses; exit 2 and malformed/oversized output remain incomplete."
  - "Identical normalized fingerprints deduplicate findings while preserving deterministic sort order."

requirements-completed:
  - CORE-07
  - CORE-09
  - CORE-10

duration: 15 min
completed: 2026-08-16
status: complete
---

# Phase 01 Plan 4: Canonical Contracts and RuboCop Adapter Summary

## Accomplishments

- Added immutable Finding and AnalyzerResult contracts aligned with finding-v1 and result-v1 semantics.
- Added draft deterministic fingerprinting, stable finding IDs, repository-relative location validation, and schema checks.
- Added RuboCop availability/version probing, target-bundle preference, structured JSON parsing, provenance, offense normalization, deduplication, ordering, and explicit unavailable/unsupported/timed-out/signaled/failed/parse-failed/truncated/malformed outcomes.
- Added synthetic adapter fixtures covering clean, offenses, unsupported versions, malformed output, non-zero execution, timeout, and oversized output.

## Task Commits

1. Task 1: Implement canonical evidence contracts — `0973e70` (feat)
2. Task 2: Add fail-closed RuboCop adapter — `a3addf5` (feat)

## Validation Evidence

- `bundle exec rake test`: 85 runs, 386 assertions, 0 failures, 0 errors.
- Finding and analyzer-result contract tests pass.
- Adapter failure corpus maps to explicit incomplete states; no failure path emits successful zero findings.
- `git diff --check` passes.

## Deviations

None.

## Next Plan Readiness

Policy, GateResult, and reporters can consume immutable findings and analyzer results without adding analyzer-specific gate authority.
