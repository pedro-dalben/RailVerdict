# Agent Handoff & Evidence Reuse (1.4)

RailVerdict 1.4 adds a deterministic, offline, file-based Handoff that lets one agent, process, clone, or CI job transport *previous verification material* to another consumer — which then **independently** decides whether that material is still sufficient.

```
1.3  Receipt: "Is this still same observable identity?"
1.4  Handoff: "Can previous evidence safely replace executing producers now?"
     Gate:   "Given current evidence + current policy, what is decision?"
```

Three different questions. `RECEIPT_FRESH != EVIDENCE_REUSABLE != GATE_REUSABLE`.

## Why not "same identity → skip RSpec"?

Freshness is necessary but not sufficient. The advisory DB can change while source stays identical, so `bundler-audit` evidence is not reusable. `RSpec`/`Minitest` depend on DB, ENV, external services and nondeterminism that are not captured in `VerificationIdentity`. A receiver cannot declare previous `RSpec` evidence reusable. RailVerdict 1.4 is identity-driven, not clock-driven, and fails closed when a reuse predicate is unobservable.

## Flow

```
Verification
  ↓
Verification Receipt (binds VerificationIdentity + gate_projection)
  ↓
Handoff.create(receipt + normalized evidence_set + provenance + scope) → handoff_id
  ↓  (file copy, artifact, any transport — untrusted)
Handoff received
  ↓
Receiver re-observes current RepositoryState + VerificationEnvironment
  ↓
Receipt.validate_freshness → fresh | stale | invalid | unavailable
  ↓ (fresh required)
Reuse.evaluate(handoff, current_identity, current_contract) → REUSABLE | VERIFICATION_REQUIRED | INVALID | UNAVAILABLE
  ↓
REUSABLE: reused normalized evidence → current baseline → current waivers → current policy → NEW GateResult (same canonical pipeline)
VERIFICATION_REQUIRED: run normal verification (Check.execute)
```

A Handoff **never** declares itself current, fresh, reusable, or trusted. The sender cannot authorize reuse. The receiver decides. `handoff_id = sha256(canonical_json[payload])` proves content identity only, not authorship. An attacker who rewrites the whole Handoff and recomputes `handoff_id` produces a self-consistent but untrusted document — same trust model as receipts (no signatures, no PKI, no Sigstore in 1.x).

## What a Handoff contains (v1, bounded 256 KiB)

- `schema_version: "1.0"`, `handoff_id`, `railverdict_version`
- `receipt` — the 1.3 Verification Receipt
- `evidence_set: { analyzer_results[] }` — normalized `AnalyzerResult` (analyzer, execution_status `succeeded`, tool_version, sorted findings via `Finding` schema) — no raw stdout, no source dumps, no secrets
- `evidence_provenance: { analyzer_versions, advisory_db_revision? }`
- `source_scope: { verification_mode, changed_base?, changed_merge_base? }` — binds `full` vs `changed --base`
- Optional references: `PR Intelligence` digest, `RepairPacket` `packet_id` — references, not copies

Excluded from `handoff_id`: timestamps, durations, PIDs, hostnames, absolute paths, CI job IDs, random seeds, JSON key order. Deterministic, clone-portable, offline. Parsing is bounded; unknown schema, oversized, duplicate-field, or path-escape inputs are `INVALID`/`VERIFICATION_REQUIRED`, never `REUSABLE`. No command paths or executable content are taken from a Handoff.

## Evidence predicates (Stage 0)

| Analyzer | 1.4 whole-set predicate |
|---|---|
| **RuboCop** | **REUSABLE** when source + config + `rubocop`/`rubocop-rails` versions + Ruby are equivalent (external `inherit_from` outside repo → fail-closed `provenance_unobservable`) |
| **RSpec / Minitest** | **NOT REUSABLE** — DB/schema/ENV/external services/nondeterminism are unobservable → `VERIFICATION_REQUIRED` |
| **SimpleCov** | **NOT independently reusable** — coupled to test execution producer |
| **bundler-audit** | **REUSABLE only with DB equivalence** — `advisory_db_revision` must match; otherwise `VERIFICATION_REQUIRED` (the canonical `FRESH != REUSABLE` example) |

Whole-set `REUSABLE` requires **every** required analyzer to be reusable; otherwise `VERIFICATION_REQUIRED`. Per-analyzer partial reuse is sound but **deferred to 1.5** (`PER_ANALYZER_REUSE_DEFERRED`); 1.4 ships whole-set only — a previous `PASS` can still require verification, a previous `FAIL` can still carry reusable `rubocop` evidence, and `RSPEC`-heavy configs will correctly fall back to full verification.

## Policy / baseline / waivers

Evidence may be reusable while policy is not. All paths re-apply current `baseline`, `waivers` (with UTC expiry), `mode`/`required`/`thresholds` through the canonical pipeline:

```
reused evidence
  ↓ current baseline
  ↓ current waivers
  ↓ current policy
  ↓ NEW GateResult
```

Old `GateResult` never becomes second policy authority. `baseline_changed`/`waivers_changed`/`policy_changed`/`required_analyzer_missing` are distinct from `evidence_incomplete`.

## CLI

```console
# Agent A: verify and hand off
$ railverdict handoff create --output /tmp/handoff.json
Handoff: sha256:…  Receipt: sha256:…

# Agent B: inspect / evaluate reuse (no execution)
$ railverdict handoff inspect /tmp/handoff.json
$ railverdict handoff verify /tmp/handoff.json
{"handoff_valid":true,"receipt_fresh":true,"decision":"REUSABLE","reasons":[]}
{"handoff_valid":true,"receipt_fresh":true,"decision":"VERIFICATION_REQUIRED","reasons":["analyzer_not_reusable:rspec"]}

# Check with handoff: reuse if possible, else full verification
$ railverdict check --handoff /tmp/handoff.json --format json
```

Human output distinguishes:

```
Handoff: VALID
Receipt: FRESH
Evidence reuse: VERIFICATION_REQUIRED
Reason: RSpec evidence depends on environment state that cannot be proven equivalent.
```

Machine output exposes `handoff_valid`, `receipt_fresh`, `decision`, `reasons`, `current identity digests`, `reused evidence` / `evidence requiring execution`, and resulting `GateResult` when verification occurs. Ordering deterministic; no volatile timing values in canonical identity.

## MCP

```
create_handoff  → verify + Handoff (one guarded Check)
inspect_handoff → bounded parse, tamper check
verify_handoff  → Reuse.evaluate (re-observes state/env, TOCTOU guard, no execution)
```

MCP delegates to same `Reuse.evaluate`, `Handoff.parse`, and `Check.effective_input_paths`. `MCP cannot trust Handoff-provided current state`, `cannot reuse stale/unavailable/incomplete required evidence`, `cannot introduce second reuse policy`. `verify` still executes analyzers exactly once; `verify_handoff` never executes them. Clock drift, disabled analyzers, lockfile/advisory DB drift are handled where required.

## CI-job-to-CI-job

```yaml
# Job A
- run: railverdict handoff create --output handoff.json
- uses: actions/upload-artifact@v4
  with: { name: handoff, path: handoff.json }

# Job B
- uses: actions/download-artifact@v4
  with: { name: handoff }
- run: railverdict check --handoff handoff.json
# → REUSABLE (equivalent checkout) or VERIFICATION_REQUIRED (drift) — no service, no DB
```

GitHub Artifacts is example transport, not trust. Handoff remains portable outside GitHub.

## TOCTOU

```console
observe reusable
  ↓
repository changes
  ↓
construct GateResult   ← must not happen
```

Implementation guards with `identity_before == identity_after` (re-observed `RepositoryState`/`VerificationIdentity`) around `Reuse.evaluate`; mismatch → `VERIFICATION_REQUIRED`/`INCOMPLETE`, never `REUSABLE`.

## Security

Treat Handoff as untrusted input: bounded JSON, no shell interpolation, no executable paths from Handoff, no filesystem paths outside repo root, no secrets. Tampering → `handoff_invalid`/`handoff_tampered` via `handoff_id` mismatch. Oversized/malformed/unknown schema → `INVALID`. Repair boundary (`RVLAB-16`) unchanged: `waiver`/`baseline`/`config` cheating → `boundary_changed` even if `gate` is `PASS`; `PR Intelligence` and `AI` remain advisory and cannot authorize reuse. `RUBY_PLATFORM`/`Bundler` version etc. remain excluded from identity for portability.

## Trust model (mandatory wording)

A Handoff is a **deterministic integrity-bound transport envelope**, not a signed attestation, not proof of author or machine, not trusted CI attestation, not remotely verified. `handoff_id` proves content identity. An actor able to modify the whole Handoff and recompute its SHA-256 can fabricate a self-consistent document. When adversarial forgery is in scope, a trusted CI/orchestrator remains the trust anchor and must independently execute RailVerdict.

## Scope exclusions

No signing, Sigstore, PKI, remote attestation, trusted timestamping, remote Receipt storage, SaaS, daemon, hosted service, GitHub App/webhooks, autonomous repair bot, distributed verification DB, centralized cache, or cloud orchestration in 1.4 — local-first, offline, deterministic, file/process/clone/CI-job usable, fail-closed.

See `docs/release/1.4-stage-0-investigation.md` (Stage 0), `docs/release/1.4-trust-invariants.md`, and `ADR 0019`.
