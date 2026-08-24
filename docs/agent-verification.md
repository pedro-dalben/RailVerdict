# Agent Verification Protocol

RailVerdict 1.2 introduces a deterministic protocol that binds verification evidence to the exact observable repository state that was verified. Coding agents, CI systems, and human reviewers consume the same machine contracts.

## Product progression

```
1.0 Deterministic Verification
        ↓
1.1 PR Intelligence
        ↓
1.2 Verification Receipt + Repository State Identity
        ↓
Agent Verification Protocol (this document)
```

## The problem

A coding agent can run `railverdict check`, see PASS, and then report "done" — but what exact repository state did that PASS verify? If anything changes afterwards (source, index, untracked files, configuration, baseline, waivers), the old evidence no longer represents the current repository.

## Receipt lifecycle

```
edit
  ↓
verify  (one canonical Check execution)
  ↓
PASS/FAIL/INCOMPLETE + Verification Receipt A   ← receipt_id = sha256:<64 hex>
  ↓
any repository mutation?
  ├─ no   → receipt stays FRESH for this state
  └─ yes  → receipt becomes STALE → new verification required → Receipt B
```

Freshness states:

| Status        | Meaning                                                              |
|---------------|----------------------------------------------------------------------|
| `fresh`       | Current observable state is identical to the verified state.         |
| `stale`       | At least one identity component changed; deterministic reasons listed.|
| `invalid`     | Document failed integrity/schema/version checks.                     |
| `unavailable` | Current state could not be determined fail-closed.                   |

Stale reasons: `head_changed`, `index_changed`, `worktree_changed`, `configuration_changed`, `baseline_changed`, `waivers_changed`, plus environment drift (`railverdict_version_changed`, `ruby_version_changed`, and `analyzer_environment_changed` when fresh analyzer versions are supplied by the caller).

FAIL vs INCOMPLETE vs STALE — three different facts:

- **fresh FAIL**: "this exact state was fully verified and policy rejected it".
- **fresh INCOMPLETE**: "this exact state could not be fully verified; evidence missing".
- **stale**: "previous evidence says nothing about the current state".

A stale or invalid receipt can never be treated as success; a FAIL receipt stays FAIL; an INCOMPLETE receipt stays INCOMPLETE.

## What a receipt binds

Identity fields (all inside `receipt_id`):

- RailVerdict version and bounded environment (Ruby version, enabled analyzer versions);
- Repository State Identity v1 digest components: HEAD, Git index snapshot digest, worktree-vs-index delta digest with per-path content hashes, configuration/baseline/waiver content digests;
- verification mode (`full` / `changed`) with base and merge-base for changed scope;
- canonical GateResult projection (statuses, finding summaries sorted by fingerprint, analyzer evidence, failure/reason codes);
- optional PR Intelligence binding as a digest over its stable projection (volatile test runtime fields such as `duration_seconds` and `seed` are excluded);
- optional repair packet linkage.

Excluded from identity: timestamps, durations, seeds, temp paths, absolute paths, diagnostics text, AI output. There is deliberately no `created_at`.

See [contracts](contracts.md#verification-receipt-v1) for the full field reference and [ADR 0017](adr/0017-verification-receipts.md) for rationale.

## Snapshot guard

Guarded executions capture repository state immediately before and after analyzers run:

```
pre_verification_state
      ↓ Check.execute (analyzers inspecting)
post_verification_state
pre == post ? issue receipt : FAIL CLOSED (repository_changed_during_verification)
```

If state changed while analyzers were running, no trustworthy current-state receipt is issued. The canonical GateResult still reports what happened; the agent simply re-verifies.

## Completion protocol

1. Agent edits source (focused tests allowed during development).
2. Before claiming completion the agent performs one canonical verification:
   `railverdict check` (or MCP `verify`).
3. The agent obtains the Verification Receipt bound to that execution.
4. The agent may treat verification as current ONLY while the receipt remains `fresh`.
5. Any repository mutation after verification makes the prior receipt stale.
6. `FAIL` means work is not complete. `INCOMPLETE` means work is not verified.
   `STALE` means previous evidence cannot be used for the current state.
7. In all three cases the agent must re-verify before claiming completion.

Orchestrators (CI, supervisors) apply the protocol using exit semantics:

| Situation                                   | Exit |
|---------------------------------------------|------|
| `receipt create` complete + PASS/WARN        | 0    |
| `receipt create` complete + FAIL             | 1    |
| incomplete / interrupted                     | 2 / 130 |
| `receipt verify` fresh + original PASS/WARN  | 0    |
| `receipt verify` fresh + original FAIL       | 1    |
| `receipt verify` stale / invalid / unavailable / fresh INCOMPLETE | 2 |

## CLI

```console
$ railverdict receipt create --format json > receipt.json     # one guarded verification
$ railverdict receipt verify receipt.json --format json
{"schema_version":"1.0","status":"fresh","reasons":[],"gate":"PASS",...}
$ # ... repository edited ...
$ railverdict receipt verify receipt.json
Receipt validation: stale
  reason: worktree_changed
Original gate: PASS (complete)
```

Write receipts outside the repository (or to ignored paths): a receipt file created inside the repo is itself new observable state and immediately makes itself stale.

Input containment is symmetric: `receipt create` and `receipt verify` reject `--config/--baseline/--waiver` paths that escape the working directory (symlink-aware), and both sides bind the EFFECTIVE inputs — configuration-declared `baseline.path`/`waivers.path` included — into the repository state identity. An input file that git cannot see (gitignored or out of root) therefore cannot silently participate in verification: either its content digest appears in the receipt, or the command refuses.

## MCP workflow

MCP stays read-only. One `verify` executes analyzers exactly once; derived tools read the cached canonical outcome without rerunning them:

```
verify ──► GateResult + receipt (embedded in response)
   │
   ├─ get_verification_receipt   (no rerun; stale ⇒ verification_required)
   └─ get_pr_intelligence        (changed-scope runs only; no rerun)

edit → previous evidence becomes stale → verify again
```

If cached evidence is stale, the tools return an explicit
`verification_required` state instead of silently returning stale data.

## Repair lifecycle

```
Verification Receipt A (FAIL, packet_id bound)
   ↓ RepairPacket v1 (unchanged closed contract)
external edit by agent
   ↓ verify_repair / new verification
Verifier verdict (fixed/still_present/changed/moved/regressed/boundary_changed)
   ↓
Verification Receipt B (resulting)
```

RepairPacket v1 is immutable; receipts link to packets via the optional `repair.packet_id` field on the receipt side. Baseline/waiver/config manipulation after a FAIL receipt turns it stale and surfaces as a repair boundary change — there is no bypass.

## Trust model (mandatory wording)

Verification Receipts are deterministic integrity records. They are NOT signed attestations. `receipt_id` proves deterministic content identity only — never authorship. Someone able to modify the whole receipt AND recompute its SHA-256 can fabricate a self-consistent receipt. When adversarial forgery is in scope, a trusted CI/orchestrator remains the trust anchor and must independently execute RailVerdict. No signing keys, HMAC secrets, PKI, Sigstore, or remote attestation are part of 1.2.

## Scope exclusions

No GitHub App/webhooks/PR comments, no autonomous merge orchestration ("PR Babysitter" remains out of scope), no daemon/SaaS/accounts/telemetry, no signed attestations, no AI gate decisions or risk scores. AI remains advisory-only and off by default.
