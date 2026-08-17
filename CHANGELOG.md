# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
