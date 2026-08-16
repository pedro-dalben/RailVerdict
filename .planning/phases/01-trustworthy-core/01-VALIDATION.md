---
phase: 1
slug: trustworthy-core
status: verified
nyquist_compliant: true
created: 2026-08-16
updated: 2026-08-16
verified: 2026-08-16
---

# Phase 01 Validation

Phase 00 was independently verified before this phase. This validation records
runtime evidence for CORE-01 through CORE-14; publication-only legal,
provenance, ownership/contact, and Brakeman licensing gates remain outside the
Phase 01 development exit.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Minitest 6.0.6 via Rake 13.4.2 |
| Full suite | `bundle exec rake test` |
| Schema validation | `json_schemer` 2.5.0 against local Draft 2020-12 schemas |
| Runtime verification | `bundle exec exe/railverdict check` from synthetic fixtures |
| Network requirement | None during tests or verification |

## Requirement Evidence

| Requirement | Implementation evidence | Automated evidence |
|-------------|-------------------------|--------------------|
| CORE-01 | `exe/railverdict`, `lib/rail_verdict/cli.rb`, init/doctor/check/findings and baseline boundary | `test/test_cli_surface.rb` |
| CORE-02 | `Check.execute` uses local config, local process execution, no AI/network/GitHub path | `test/test_check_e2e.rb`; real fixture command |
| CORE-03 | `Configuration`, `StrictYaml`, `SchemaValidator` | `test/test_configuration.rb`; `script/validate-foundation schemas` |
| CORE-04 | Frozen `RunContext` with repository, revision, Ruby/Rails, analyzer, config and deterministic inputs | `test/test_run_context.rb` |
| CORE-05 | `ProcessRunner` executable-plus-argv and verified `chdir` | `test/test_process_runner.rb` argv corpus; shell-form source assertion |
| CORE-06 | Concurrent bounded drains, monotonic deadline, minimal env, process groups, reaping, cleanup | `test/test_process_runner.rb` timeout, flood, grandchild, env, signal tests |
| CORE-07 | `AnalyzerResult` and RuboCop explicit execution/evidence states | `test/test_analyzer_result.rb`, `test/test_rubocop_adapter.rb` |
| CORE-08 | Required incomplete evidence maps to INCOMPLETE, never PASS | `test/test_policy.rb`, `test/test_check_e2e.rb` |
| CORE-09 | Version-checked structured RuboCop adapter with provenance and bundle preference | `test/test_rubocop_adapter.rb`; real RuboCop fixtures |
| CORE-10 | Immutable analyzer-independent `Finding` and opaque evidence reference | `test/test_finding.rb`; finding schema validation |
| CORE-11 | `Verification::Policy` owns GateResult decisions | `test/test_policy.rb`, `test/test_gate_result.rb` |
| CORE-12 | Pure console and one-document JSON reporters | `test/test_reporters.rb`, CLI JSON tests |
| CORE-13 | CLI maps PASS/WARN, FAIL, incomplete, and interruption to 0/1/2/130 | `test/test_cli_surface.rb` |
| CORE-14 | Stable ordering and canonical JSON across locale/timezone/temp-root variation | `test/test_determinism.rb`, adapter ordering tests |

## Failure Corpus

Synthetic fixtures cover invalid UTF-8, duplicate YAML keys, aliases,
object tags, unknown configuration keys, disabled-required selection,
missing configuration, unavailable RuboCop, unsupported versions, malformed
JSON, malformed offense structures, non-zero execution, timeout, signaled
execution, and oversized output. Every required analyzer failure remains
incomplete and schema-valid as a result envelope.

## Exit Evidence

- Clean synthetic Rails fixture: console `PASS`, exit `0`.
- Offense synthetic Rails fixture: JSON `FAIL`, exit `1`.
- Required configuration/tool/parser/process failures: JSON `INCOMPLETE`, exit `2`.
- Interrupted policy result: exit mapping `130`.
- `baseline create`: explicit Phase 3 deferral, exit `2`, no write.
- `check --changed` and `--base`: explicit Phase 4 deferral, exit `2`.

## Validation Runs

- `bundle exec rake test`: 121 runs, 588 assertions, 0 failures, 0 errors, 0 skips.
- `script/validate-foundation`: all Phase 0 checks pass; provenance reports `NOT RUN` without maintainer corpus; no-production boundary retires after Phase 1 scaffold.
- `script/validate-foundation schemas contracts links language`: pass.
- `git diff --check`: pass.
- `gem build rail_verdict.gemspec`: `rail_verdict-0.1.0.gem` built successfully.

## Known Limits

- Phase 1 uses a draft fingerprint payload; final fingerprint migration and baseline comparison belong to Phase 3.
- `no_new_debt` is evaluated as strict until Phase 3 baseline semantics exist.
- Production `--changed`/`--base` Git scope belongs to Phase 4.
- Only RuboCop is implemented; broader evidence adapters belong to Phase 2.
- The private provenance corpus and publication/legal gates were not run or cleared.
