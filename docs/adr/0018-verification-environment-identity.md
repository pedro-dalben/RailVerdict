# ADR 0018: Verification Environment Identity and Canonical Freshness Evaluation

Status: Accepted
Decision date: 2026-08-25
Implementation status: Implemented in RailVerdict 1.3.0

## Context

RailVerdict 1.2 introduced Repository State Identity v1 and Verification Receipts v1 with a pre/post guard, but left a freshness asymmetry: `ruby_version` and `railverdict_version` were checked, but `analyzer_versions` were only checked when the caller supplied `current_analyzer_versions`. CLI `receipt verify` and MCP `get_verification_receipt` / `get_pr_intelligence` reused the cached outcome's analyzer versions as if they were current observation, violating Trust Invariant Zero. A receiver could be shown a `fresh` receipt after `rubocop` or `rspec` had been upgraded, replaced, or removed. Repair verification exposed `verification_boundary_changed` but left `gate: PASS` as the authoritative success signal, allowing waiver/baseline/config cheating to appear successful (RVLAB-16).

## Decision

Verification Environment Identity and Canonical Freshness Evaluation completes the trust model.

1. Verification Identity = RepositoryState (HEAD, index_digest, worktree_digest, configuration_digest, baseline_digest, waivers_digest) + VerificationEnvironment (railverdict_version, ruby_engine, ruby_version, analyzer_versions sorted, relevance-filtered, unknown-excluded, environment_digest = sha256(canonical_json{...})).

VerificationEnvironment is captured via lightweight version probes (`--version`, bounded 5s, 64 KiB, no test-suite execution) for every `enabled` analyzer in the effective configuration. SimpleCov without a coverage file is skipped. Non-required analyzer probe failures are skipped; required failures make the environment `unavailable` (fail-closed). `unknown` versions are excluded from receipts and trigger `unavailable`.

Excluded dimensions (portability, no trust gain): hostname, PID, username, time, absolute checkout path, temp dir, CI job ID, CPU model, filesystem path, random seed, machine ID, RUBY_PLATFORM, Bundler version, OS/arch.

2. One canonical freshness evaluator owns all freshness: `Receipt.validate_freshness` and `Receipt.evaluate`. It independently re-observes `current_state` via `RepositoryState.capture` and `current_environment` via `VerificationEnvironment.capture_for_receipt` (filtered to receipt's relevant keys). It never trusts receipt-provided values as current observation. CLI `receipt verify` and MCP cache/tools delegate to this evaluator with the same `Check.effective_input_paths` resolution.

Freshness states remain `fresh` / `stale` / `invalid` / `unavailable`. Stale reasons include `head_changed`, `index_changed`, `worktree_changed`, `configuration_changed`, `baseline_changed`, `waivers_changed`, `railverdict_version_changed`, `ruby_engine_changed`, `ruby_version_changed`, `analyzer_environment_changed`. `fresh` does not imply `PASS`.

3. Receipt schema `verification-receipt-v1` now allows optional `environment.ruby_engine`. `sorted_analyzer_versions` excludes `unknown`. `receipt_id` remains sha256 over canonical payload. 1.2 receipts without `ruby_engine` remain structurally valid but are evaluated as `stale` under the stronger check.

4. MCP Cache stores `state_digest` + `environment_digest` and re-observes current environment with lightweight probes. Analyzer execution count remains one per `verify`; derived tools never rerun analyzers.

5. Repair hardening: `Repair::Verifier` keeps `gate` honest but `overall_status` is `boundary_changed` whenever `verification_boundary_changed` is non-empty, even if `gate` is `PASS`. Boundary cheating can never be `successful`. RVLAB-16 fixed.

## Consequences

- `railverdict receipt verify` now automatically observes all freshness dimensions; no manual `current_analyzer_versions` needed.
- `get_verification_receipt` / `get_pr_intelligence` cannot return stale evidence as fresh; stale is `verification_required`.
- Cross-clone portability holds: same commit, index, worktree, config, baseline, waivers, and relevant analyzer versions → `fresh` regardless of absolute path or process.
- Analyzer drift, Ruby drift, and RailVerdict drift are detected; missing/unobservable analyzer → `unavailable`, never `fresh`.
- Version probes are bounded and do not run the full test suite; a large RSpec suite does not make freshness slow.

## Deferred Work

Implemented in RailVerdict 1.3. No new configuration is introduced for environment observation; timeouts reuse existing analyzer timeout infrastructure. Future cryptographic signing, Sigstore/PKI, trusted timestamps, GitHub App, or autonomous merge remain deferred per charter and require a new ADR and schema version. No 1.4 design is introduced.

## Related Requirements

- FND-08
- DEBT-03
- Agent Verification Protocol (Repository State Identity, Verification Receipts)
- Repair integrity constraints (RepairPacket v1, RVLAB-16)

## Related Documents

- [ADR 0016](0016-canonical-repository-state-identity.md)
- [ADR 0017](0017-verification-receipts.md)
- [docs/agent-verification.md](../agent-verification.md)
- [docs/contracts.md](../contracts.md)
- Lab scenarios RVLAB-FRESH-*, RVLAB-ENV-*, RVLAB-PORTABLE-*, RVLAB-MCP-FRESH-*, RVLAB-REPAIR-BOUNDARY-*, RVLAB-RECEIPT-13X-*
