# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-08-19

### Highlights

- **Deterministic verification:** `railverdict check` (console / JSON / SARIF 2.1.0), `findings`, `doctor`, `init`, `baseline create`, `repair`; exits 0 PASS/WARN / 1 FAIL / 2 INCOMPLETE / 130 interrupt; stdout single-doc JSON, diagnostics on stderr.
- **Fail-closed evidence:** required incomplete evidence never becomes PASS (unavailable, unsupported, timed_out, signaled, failed, parse_failed, truncated, malformed).
- **Five analyzers (external, target-owned):** RuboCop `>= 1.72, < 2` (+ `rubocop-rails >= 2, < 3` provenance), Minitest `>= 5, < 7` (owned reporter `minitest-reporter-v1`), RSpec `>= 3.13, < 4`, SimpleCov public `coverage.json` v1, bundler-audit `>= 0.9.3, < 1`.
- **Baselines & no-new-debt:** fingerprint v1 `sha256:` over `{analyzer, rule_id, path, message}`, atomic versioned baselines, comparison (`introduced`/`existing`/`resolved`/`changed`/`moved`), policy `advisory` / `no_new_debt` / `strict`, exact-fingerprint waivers with UTC expiry.
- **Git changed scope:** `check --changed --base REV` with merge-base, NUL-safe diffs, rename awareness; shallow/missing base → INCOMPLETE.
- **SARIF / JSON / annotations:** SARIF 2.1.0 and annotation projections are pure `GateResult` projections.
- **Rails context (bounded, no boot):** bounded `rails_context` with confidence + provenance.
- **Optional AI (advisory, off by default):** dual-gate `ai.enabled && ai.remote.enabled`, `trust: redacted` default, secret detection/redaction fail-closed, budgets, cache; AI never changes gate.
- **RepairPacket v1:** deterministic, bounded 256 KiB, `packet_id sha256:`, `Verifier` classification `fixed|still_present|changed|moved|regressed|incomplete`.
- **MCP stdio 2025-11-25:** `mcp ~> 1.2.0`, 7 read-only tools (`verify`, `list_findings`, `get_finding`, `build_repair_packet`, `verify_repair`, `explain`, `investigate`); mutex-serialized verification; same `GateResult`/`Finding`/`RepairPacket` contracts.
- **Security/privacy:** argv-only exec, minimal env, bounded I/O, monotonic timeout, pgroup cleanup, secret isolation, English-only fixtures, information firewall.

### Compatibility

- Ruby `>= 3.3`; Rails target context `>= 8.0`; schemas Draft 2020-12 independent versioning; unknown versions → explicit migration.
- Supported analyzer ranges per `docs/analyzers.md`; fixture-verified at 2026-08-16/17 versions.

### Known limitations

- No Brakeman support (HOLD pending legal/product decision).
- No OS sandbox; subprocess containment is argv/env/bounds/pgroup only.
- No full semantic code graph; Rails context is bounded + provenance-labeled.
- AI does not control GateResult; no autonomous source mutation.
- Qualified trademark/name review (including Brazil INPI) NOT PERFORMED — NON-BLOCKING BY MAINTAINER DECISION 2026-08-19 (Pedro Dalben) for initial open-source publication; recommended but not mandatory; preliminary screen 2026-08-19 found no obvious conflict — NOT LEGAL CLEARANCE; no registration or clearance claimed.
- Private-pattern corpus scan requires external maintainer input (`FOUNDATION_PRIVATE_PATTERNS`).

### Artifact

- Gem `rail_verdict` 1.0.0 built once from the `v1.0.0` tag; SHA-256 recorded in release workflow; installed/tested artifact is the published artifact (Trusted Publishing / OIDC, no long-lived key).

## [1.0.1] — 2026-08-21

### Compatibility hardening

- **Configurable analyzer execution timeout:** per-analyzer `timeout_seconds` (1..3600) on `rubocop`, `minitest`, `rspec`, `simplecov`, and `bundler_audit` via `.railverdict.yml` `version: 1.5` (new compatible schema version). Default remains 30 seconds; existing `version: 1`..`1.4` configs continue to load. Invalid `timeout_seconds` (non-integer, zero, negative, >3600) fails configuration validation. Timeout remains fail-closed operational failure / `INCOMPLETE` (`timed_out`, exit 2 when required).
- **Robust bundler-audit JSON parsing:** `bundler_audit` now robustly extracts the JSON document when informational/download notices precede the payload on stdout (e.g. `Downloading ruby-advisory-db ...`), without depending on pristine JSON. Exit-code handling, `parse_failed`/`malformed`/missing-JSON distinctions, trailing-garbage rejection, and deterministic parsing are preserved; malformed output still fails closed.

## [Unreleased — post-1.0 placeholder]

### Added
- SARIF output via `railverdict check --format sarif` (pure `GateResult` projection, `version: 2.1.0`).
- MCP stdio adapter: `railverdict mcp serve` with 7 read-only tools (`verify`, `list_findings`, `get_finding`, `build_repair_packet`, `verify_repair`, `explain`, `investigate`).

### Changed
- Gem packaging: `spec.files` discovered via gemspec directory with gem-relative normalization; includes `exe/railverdict-minitest-reporter.rb`. CWD-independent build.
- License: project license is **MIT** (see `LICENSE`); historical Apache-2.0 ADR marked superseded.

## [0.1.0] - 2026-08-17

### Added
- Deterministic core: `railverdict check` (console/json), `findings`, `doctor`, `init`, `baseline create`; exits 0/1/2/130; stdout single-doc JSON, diagnostics on stderr.
- Analyzers (external, target-controlled): RuboCop (+ rubocop-rails provenance), Minitest (owned reporter), RSpec, SimpleCov (public `coverage.json` v1), bundler-audit.
- Fingerprint v1 (`sha256:` over `{analyzer, rule_id, path, message}`), versioned baseline (atomic write), no-new-debt comparison, exact-fingerprint waivers.
- Git changed scope: `check --changed --base REV` with deterministic `merge-base` / NUL-safe diffs; `INCOMPLETE` on missing/shallow base.
- Rails-aware context: bounded `rails_context` (`detected`/`scope`/`entries`) with confidence + provenance.
- Optional AI: dual-gate opt-in (`ai.enabled && ai.remote.enabled`), secret detection/redaction (fail-closed), bounded context, budgets, cache.
- Repair: deterministic `RepairPacket v1` (`packet_id sha256:`, bounded 256 KiB), `repair` CLI, `Verifier` classification.

### Security
- Fail-closed: required incomplete evidence never becomes `PASS` (CLI, `check --changed`, baseline, repair, MCP).
- Process boundary: argv-exec only, minimal env, bounded I/O, monotonic timeout, pgroup termination.
- Information firewall: synthetic-only fixtures, English-only policy; external private-pattern corpus scan surfaces enumerated (`NOT RUN` until supplied — publication blocker).
