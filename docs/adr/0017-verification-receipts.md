# ADR 0017: Verification Receipts (Non-Attestation)

Status: Accepted

Decision date: 2026-08-24

Implementation status: Implemented in RailVerdict 1.2. `RailVerdict::Receipt` issues Verification Receipt v1 documents bound to a Repository State Identity v1 and the canonical verification outcome.

## Context

Coding agents need to prove that "done" corresponds to a verification of the current repository state. A PASS from minutes ago must not remain usable evidence after any mutation. The receipt must be deterministic, machine-readable, freshness-checkable, and honest about what it does not prove.

## Decision

RailVerdict 1.2 introduces Verification Receipt v1: a versioned, closed JSON contract whose identity-bearing fields are canonicalized into `receipt_id = sha256:<64 hex>`. A receipt binds:

- RailVerdict version and bounded verification environment (Ruby version, enabled analyzer versions);
- Repository State Identity v1 digest and its components;
- verification mode (`full` or `changed`, with base/merge-base when changed);
- a stable projection digest of the canonical GateResult;
- an optional stable-projection digest of PR Intelligence for changed-scope verifications;
- an optional repair packet linkage.

Volatile data is excluded from identity: creation timestamps, durations, seeds, temp paths, absolute paths, diagnostics text, and AI output. Receipts exist for PASS, WARN, FAIL, and INCOMPLETE outcomes alike; document integrity, freshness, and the gate are separate concepts.

A pre/post repository state guard wraps guarded executions; if state changed while analyzers ran, receipt issuance fails closed with `repository_changed_during_verification`.

## Explicit Non-Goals

- Receipts are NOT cryptographically signed attestations, certificates, PKI, Sigstore, remote attestation, or supply-chain signatures.
- `receipt_id` proves deterministic content identity only — never authorship. An actor able to modify the whole receipt AND recompute its SHA-256 can fabricate a self-consistent receipt.
- When adversarial forgery is in scope, a trusted CI/orchestrator remains the trust anchor and must independently execute RailVerdict.
- No signing keys, HMAC secrets, or trusted hardware are introduced.

## Consequences

- Freshness states are public: `fresh`, `stale`, `invalid`, `unavailable` with deterministic reasons.
- Stale evidence can never be reinterpreted as success; FAIL/INCOMPLETE receipts stay FAIL/INCOMPLETE.
- MCP stays read-only and exposes receipts without rerunning analyzers.
- RepairPacket v1 stays immutable; repair integration uses packet linkage on the receipt side plus shared boundary digests.

## Related Documents

- [ADR 0016](0016-canonical-repository-state-identity.md)
- [docs/agent-verification.md](../agent-verification.md)

## Deferred Work

A future attestation milestone owns any cryptographic signing, PKI/Sigstore integration, or remote verification anchor; none of these may be retrofitted into receipt identity without a new decision and schema version. Broader orchestrator policy (merge automation) remains out of scope by charter.

## Related Requirements

- FND-08
- DEBT-03
- MCP read-only adapter guarantees ([ADR 0011](0011-mcp-as-an-adapter.md))
- Repair integrity constraints (RepairPacket v1)

## Related Documents

- [ADR 0016](0016-canonical-repository-state-identity.md)
- [docs/agent-verification.md](../agent-verification.md)
- [docs/contracts.md](../contracts.md)
