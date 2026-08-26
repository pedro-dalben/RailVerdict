# ADR 0019: Agent Handoff and Evidence Reuse Trust Model

Status: Accepted
Decision date: 2026-08-25
Implementation status: Implemented in RailVerdict 1.4.0

## Context

RailVerdict 1.2 provided Repository State Identity v1 and 1.3 added Verification Environment Identity v1 + canonical `Receipt.validate_freshness`. A receipt now proves `RECEIPT_FRESH` when current `VerificationIdentity` (repository_digest + environment_digest) equals verified identity. The 1.3 model intentionally stopped at freshness: it never asked whether previous evidence remains *sufficient* when policy, baseline, waivers, advisory DB, or required analyzers changed, or whether a subset of evidence could be reused without re-running every producer.

1.4 must answer: *When may previous evidence safely replace executing its producers now?* under a stronger claim than freshness. Freshness is necessary but not sufficient — a classic example is `bundler-audit`: the advisory DB can change while source and Ruby remain identical, so `RECEIPT_FRESH` must not imply `bundler-audit` evidence reusable. Similarly `RSpec` with DB/env/external-service nondeterminism cannot be proven equivalent from identity alone. The architecture must distinguish three questions:

- Receipt freshness: “Is this still same observable verification identity?”
- Evidence reuse: “Can previous normalized evidence safely replace producers now?”
- GateResult: “Given current evidence + current policy/baseline/waivers, what is deterministic decision?”

Constraints carry from Stage -1: local-first, offline-capable, deterministic, file/process/clone/CI-job usable, fail-closed, bounded, portable, no crypto/signatures/PKI/Sigstore/remote attestation/server/DB in 1.4 (per NON-GOALS, deferred to 2.x). Handoff must be a deterministic integrity-bound envelope, not authorization.

## Decision

### 1. Freshness vs Reuse vs Gate

- `RECEIPT_FRESH` — current `VerificationIdentity` == receipt-bound identity (`Receipt.validate_freshness` == `fresh`). Sender cannot prove this; receiver re-observes.
- `EVIDENCE_REUSABLE` — previous normalized evidence remains semantically sufficient under currently observed repository state, verification environment, analyzer environment, dependency state where relevant (e.g., advisory DB), configuration, policy, baseline, waivers, Git/base scope, provenance, completeness. Stronger than freshness.
- `GATE_REUSABLE` is rejected as a concept; reuse never reuses old `GateResult`. Only `EVIDENCE_REUSABLE` exists. `ANALYZER_EVIDENCE_REUSABLE` is per-analyzer predicate (deferred).

Invariant: `RECEIPT_FRESH != EVIDENCE_REUSABLE != GATE_REUSABLE`; `EVIDENCE_REUSABLE` requires `RECEIPT_FRESH` but not conversely (§3 Stage 0).

### 2. Sender vs Receiver Authority

Handoff is a bounded transport envelope, not authorization, signature, or agent identity. It contains sufficient material for receiver to decide. `handoff_id` proves content identity, not authorship. Receiver independently observes current `RepositoryState` + `VerificationEnvironment`; trusts no sender-provided current values. Sender cannot make Handoff `fresh`, `reusable`, or `trusted`.

### 3. Evidence Semantics

Evidence = normalized `AnalyzerResult{analyzer, execution_status, tool_version, findings[]|coverage}` sorted, message-bounded, deterministic. Raw stdout/logs not reused. Per-analyzer predicates (Stage 0 §5):

- **RuboCop: REUSABLE** under bounded source+config+rubocop/rails versions+Ruby equivalence (fail-closed on external `inherit_from` unobservable).
- **RSpec/Minitest: NOT REUSABLE** — unobservable DB/schema/ENV/external services/random seed/nondeterminism → fail-closed.
- **SimpleCov: NOT independently reusable** — coupled to test execution producer.
- **bundler-audit: REUSABLE ONLY WITH ADVISORY DB EQUIVALENCE** — DB revision must match; otherwise `VERIFICATION_REQUIRED`. Source-equivalence alone insufficient.

Whole-set reuse requires **every** required analyzer's predicate to hold; otherwise `VERIFICATION_REQUIRED`.

### 4. Current-Policy Reevaluation

Reused evidence never bypasses current `baseline`/`waivers`/`policy`/`analyzer requirement` evaluation. Architecture:

```
previous normalized evidence + newly executed evidence
  ↓ (same canonical Comparison/Baseline/WaiverStore/Policy pipeline)
new GateResult
```

Old `GateResult` is input to Handoff provenance but never second policy authority. Policy/baseline/waiver/analyzer-requirement drift ⇒ new `GateResult` even if evidence still valid.

### 5. Git/Scope, Dependency/Environment

- Changed vs full scope, `base`/`merge_base`, HEAD/index/worktree/untracked relevant state are part of reuse validity. Fresh receipt over `full` does not imply `changed --base X` reusable.
- Ruby/analyzer drift via environment digest; relevant analyzer versions only. Adding all installed gems would break portability — rejected; minimum observable state per §5.
- Advisory DB revision handled where relevant; otherwise identity-driven, not clock/TTL.

### 6. TOCTOU

Reuse evaluation guards with pre/post `VerificationIdentity` observation: `identity_before` == `identity_after` required, else `VERIFICATION_REQUIRED`/`INCOMPLETE` (never `REUSABLE`).

### 7. Handoff Transport

Conceptual `VerificationHandoff {schema_version:handoff-v1, handoff_id, verification_receipt, evidence_set[normalized], evidence_provenance, source/scope identity, optional PR/repair references}`. Deterministic canonical JSON, bounded `256 KiB`, no source/log/secret/env dump, references/digests preferred over duplication. Sensitive to trust-relevant content, insensitive to timestamps/PID/host/path/duration/key order. Fail-closed on oversized/malformed/unknown schema.

### 8. Reuse Evaluator

One canonical `Reuse.evaluate(handoff, current_identity, current_contract)` used by CLI, MCP, CI helpers, Repair, PR Intelligence. Returns `REUSABLE` | `VERIFICATION_REQUIRED` | `INVALID`/`UNAVAILABLE` with machine-readable reasons (`receipt_stale`, `repository_changed`, `environment_changed`, `policy_changed`, `required_analyzer_missing`, `analyzer_version_changed`, `dependency_state_changed`, `advisory_database_changed`, `scope_changed`, `base_changed`, `evidence_incomplete`, `provenance_unobservable`, `handoff_tampered`, `reuse_toctou`). Deterministic reason ordering. Cannot turn incomplete into complete; missing required evidence cannot disappear.

### 9. Execution Strategy

- **Model A (1.4): whole evidence-set reuse.** If all required evidence reusable → skip producers; else normal verification. **Selected for 1.4.**
- **Model B (per-analyzer reuse): sound but deferred to 1.5** per Stage 0 §11 (`PER_ANALYZER_REUSE_DEFERRED`). Not rejected as unsound; deferred to avoid audit surface while RSpec/Minitest not reusable provides limited benefit. Architecture already supports extension without second engine.

### 10. Non-Goals Preserved

No signing/Sigstore/PKI/remote attestation/trusted timestamping/remote Receipt storage/SaaS/daemon/GitHub App/webhook/distributed DB/cache/network-required verification. Handoff remains file-based, offline.

## Consequences

- CLI/MCP expose `handoff create|inspect|verify` and `check --handoff PATH` (minimal coherent surface) delegating to canonical evaluator; human/machine output distinguishes `Receipt:FRESH` vs `Evidence:REUSABLE|VERIFICATION_REQUIRED`.
- MCP `create_handoff`/`inspect_handoff`/`verify_handoff`/`verify_with_handoff` delegate to same services; CLI/MCP parity, analyzer no-execution proven via instrumentation.
- Repair/PR Intelligence remain non-authoritative; RVLAB-16 boundary protection holds; waiver/baseline/config cheating surfaces as `boundary_changed` not `successful`.
- Determinism: `handoff_id`, reuse identity, reason ordering stable across clones; `handoff_id` recomputable proves integrity not authorship.

## Deferred Work

Per-analyzer partial reuse, cryptographic signing, distributed cache — require new ADR and schema version. No 1.5 design. Implemented in RailVerdict 1.4.

## Related Requirements

- FND-08
- DEBT-03
- Agent Verification Protocol (Handoff, Evidence Reuse)
- Handoff trust invariants 1–25

## Related Documents

- [ADR 0016](0016-canonical-repository-state-identity.md)
- [ADR 0017](0017-verification-receipts.md)
- [ADR 0018](0018-verification-environment-identity.md)
- [Stage 0 Investigation](../release/1.4-stage-0-investigation.md)
- [Trust Invariants](../release/1.4-trust-invariants.md)
- [Agent Handoff](../agent-handoff.md)
