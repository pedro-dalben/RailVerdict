# ADR 0018: Verification Environment Identity and Canonical Freshness Evaluation

Status: Accepted
Decision date: 2026-08-25
Implementation status: Implemented in RailVerdict 1.3.0

## Context

RailVerdict 1.2 introduced Repository State Identity v1 and Verification Receipts v1 with a pre/post guard, but left a freshness asymmetry: `ruby_version` and `railverdict_version` were checked, but `analyzer_versions` were only checked when the caller supplied `current_analyzer_versions`. CLI `receipt verify` and MCP `get_verification_receipt` / `get_pr_intelligence` reused the cached outcome's analyzer versions as if they were current observation, violating Trust Invariant Zero. A receiver could be shown a `fresh` receipt after `rubocop` or `rspec` had been upgraded, replaced, or removed. Repair verification exposed `verification_boundary_changed` but left `gate: PASS` as the authoritative success signal, allowing waiver/baseline/config cheating to appear successful (RVLAB-16).

## Decision

### 1. Verification Identity

```
VerificationIdentity
├── RepositoryState (HEAD, index_digest, worktree_digest, configuration_digest, baseline_digest, waivers_digest)
└── VerificationEnvironment
    ├── railverdict_version
    ├── ruby_engine
    ├── ruby_version
    ├── analyzer_versions (sorted, relevance-filtered, unknown-excluded)
    └── environment_digest = sha256(canonical_json{railverdict_version, ruby_engine, ruby_version, analyzer_versions})
```

`VerificationEnvironment` is captured via lightweight version probes (`--version`, bounded 5s, 64 KiB, no test-suite execution) for every `enabled` analyzer in the effective configuration. Probes are cheap, bounded, and deterministic. SimpleCov without a coverage file is skipped (not a version probe failure). Non-required analyzer probe failures are skipped; required analyzer failures make the environment `unavailable` (fail-closed). `unknown` versions are excluded from receipts and trigger `unavailable` when observed.

Excluded dimensions (portability, no trust gain): hostname, PID, username, time, absolute checkout path, temp dir, CI job ID, CPU model, filesystem path, random seed, machine ID, RUBY_PLATFORM, Bundler version, OS/arch. These would break clone portability without strengthening the freshness promise.

### 2. Canonical Freshness Evaluator

One evaluator owns all freshness: `Receipt.validate_freshness` and `Receipt.evaluate`. It independently re-observes `current_state` via `RepositoryState.capture` and `current_environment` via `VerificationEnvironment.capture_for_receipt` (filtered to receipt's relevant keys). It never trusts receipt-provided values as current observation. CLI `receipt verify` and MCP cache/tools delegate to this evaluator with the same `Check.effective_input_paths` resolution, so custom `config`/`baseline`/`waivers` paths are bound identically.

Freshness states remain `fresh` / `stale` / `invalid` / `unavailable`. Stale reasons include `head_changed`, `index_changed`, `worktree_changed`, `configuration_changed`, `baseline_changed`, `waivers_changed`, `railverdict_version_changed`, `ruby_engine_changed`, `ruby_version_changed`, `analyzer_environment_changed`. Unavailable reasons include `repository_state_unavailable:*` and `analyzer_version_unobservable:*`. `fresh` means the current observable repository+environment is byte-identical to what produced the receipt; `stale` means at least one bound dimension changed; `invalid` means the receipt fails integrity/schema; `unavailable` means the current state could not be observed fail-closed.

`fresh` does not imply `PASS`; a fresh `FAIL` remains a verified rejection, and a fresh `INCOMPLETE` cannot become success.

### 3. Receipt Schema

`verification-receipt-v1.schema.json` now allows optional `environment.ruby_engine`. `Receipt.build` includes `ruby_engine`. `sorted_analyzer_versions` excludes `unknown`. `receipt_id` remains `sha256` over the canonical payload (now including `ruby_engine` when present). 1.2 receipts without `ruby_engine` remain structurally valid but are evaluated as `stale` or `unavailable` under the stronger 1.3 check (prefer `stale` over `invalid`). Tampering any bound field breaks `receipt_id` → `invalid`.

### 4. MCP Cache

`MCP::Cache` now stores `state_digest` + `environment_digest` (both via `VerificationEnvironment`). `fresh_entry` and `verification_state` re-observe the current environment with lightweight probes and compare both digests. Analyzer execution count remains one per `verify`; derived tools never rerun analyzers (probes are not analyzer runs). Custom path inputs use the same `Check.effective_input_paths` as CLI.

### 5. Repair Hardening

`Repair::Verifier` keeps `gate` honest (current policy evaluation) but `overall_status` is `boundary_changed` whenever `verification_boundary_changed` is non-empty, even if `gate` is `PASS` and `target_status` is `fixed`. A boundary change (waivers/baseline/config) can never be a `successful` repair. RVLAB-16 now expects `gate: PASS` with `target_status: still_present` and `boundary_changed: {waivers: true}` and `overall_status: boundary_changed` – cheating is exposed, not hidden.

## Consequences

- `railverdict receipt verify` now automatically observes all freshness dimensions; no manual `current_analyzer_versions` needed.
- `get_verification_receipt` / `get_pr_intelligence` cannot return stale evidence as fresh; stale is `verification_required`.
- Cross-clone portability holds: same commit, index, worktree, config, baseline, waivers, and relevant analyzer versions → `fresh` regardless of absolute path or process.
- Analyzer drift, Ruby drift, and RailVerdict drift are detected; missing/unobservable analyzer → `unavailable`, never `fresh`.
- Version probes are bounded and do not run the full test suite; a large RSpec suite does not make freshness slow.

## Alternatives Considered

- Include `RUBY_PLATFORM` / OS / arch: rejected – breaks portability without proving freshness.
- Include `unknown` in receipt: rejected – `unknown == unknown` is self-confirmation, not observation.
- Cryptographic signatures / Sigstore: deferred to future milestone per charter; not in 1.3.

## Related Documents

- ADR 0016 (Repository State Identity)
- ADR 0017 (Verification Receipts)
- docs/agent-verification.md
- docs/contracts.md
- Lab scenarios RVLAB-FRESH-*, RVLAB-ENV-*, RVLAB-PORTABLE-*, RVLAB-MCP-FRESH-*, RVLAB-REPAIR-BOUNDARY-*, RVLAB-RECEIPT-13X-*

## References

- Implementation: `lib/rail_verdict/verification_environment.rb`, `lib/rail_verdict/verification_identity.rb`, `lib/rail_verdict/receipt.rb`, `lib/rail_verdict/mcp/cache.rb`
- Tests: `test/test_cli_receipt.rb`, `test/test_cache_freshness.rb`, Lab 1.3 campaign 118 scenarios (81 original + 37 new)
