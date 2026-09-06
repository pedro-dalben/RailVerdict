# ADR 0021: Agent Workflow and Review Orchestration Contracts

Status: Accepted
Decision date: 2026-09-06
Implementation status: Implemented in RailVerdict 1.8.0

## Context

RailVerdict 1.7 answers *what a change requires* (deterministic requirements with
`PASS`/`FAIL`/`INCOMPLETE`/`REVIEW_REQUIRED`). What is missing is the *workflow
closure* for humans and external agents: which single document carries review
context, how an outside observation (human note, agent finding, AI comment) is
recorded without ever becoming deterministic evidence, what to do when evidence
is missing (as opposed to code being wrong), and how the loop re-verifies.

Inventory (G2.0) verdicts: RepairPacket assembly/identity, Verifier,
`Verification::Policy`, EngineeringPolicy envelope, receipt/handoff/PR bindings,
freshness evaluators, MCP cache semantics, and AI fencing all **keep**. The gaps
are compositional, not foundational:

- The packet repair plan is argv-only (no analyzers-to-run/reuse, test scope,
  requirements, reasons the internal engine already knows).
- Recovery guidance is scattered (policy `recovery_action` + `missing_evidence`
  + fallback reasons + Verifier passthrough) with no unified playbook.
- `verify_repair` is MCP-only; CLI agents cannot close the repair loop.
- No bounded review-context document, no observation validation path, no
  workflow-closure record.

## Decision

### 1. Three new documents, zero new gates

- `review-packet-v1`: the review context **to** review. Built from one Check
  outcome by a canonical builder: stable receipt/gate projection, policy
  envelope (decision + requirements), verification plan (analyzers to
  execute/reuse, test scope + target files, fallback reasons), review focus,
  evidence gaps with an ordered `recovery` list, limits, and a hard split
  between `deterministic` and `review` lanes. `packet_id =
  sha256(canonical stable core)`.
- `review-observation-v1`: an outside observation **about** a state. Declared
  author (`human` | `agent` | `ai`), provider/model for non-humans, free
  observational findings, confidence (`low` | `medium` | `high`), state binding
  (`head`, `configuration_digest`, `policy_digest`), and an explicit
  `authoritative: false` marker. Bounded (findings cap, bytes cap).
- `workflow-receipt-v1`: the workflow **record**. Binds packet digest, policy
  digest, validated observations (digests + per-observation binding verdicts),
  and final `readiness` (`ready` | `blocked_by_gate` | `blocked_by_evidence` |
  `review_pending`). It reports; it never reclassifies opinion as fact and never
  rewrites the gate.

Folded, not duplicated: ProjectPolicy (effective policy + origin + digest) is
the packet `policy` section; VerificationPlan projection is the packet `plan`
section; EvidenceRecoveryContext is the packet `recovery` section (at most one,
per the program). Separate documents would triple digest-chasing with no new
consumer question answered.

### 2. Observation validation is fail-closed and gate-neutral

`ReviewObservationValidator.validate(observation, current_state:)` returns
`valid_bound`, `stale` (state moved), `untrusted` (author/provider unknown or
declaration malformed), `invalid` (schema/integrity), or `unavailable`
(unobservable state). Validation NEVER changes any gate, requirement, finding,
or receipt. A `stale` observation is reported, never silently re-bound. Replay
is detected by digest: the same observation validates identically and can never
upgrade readiness by itself — readiness moves only on fresh verification.

### 3. Repair loop closes on both interfaces

- Packet `verification_plan` is extended with `analyzers_to_execute`,
  `analyzers_to_reuse`, `test_scope`, `target_files`, `requirements`, and
  `reasons` (projected from the internal engine + policy result). Existing
  `required`/`suggested` argv keys are unchanged (alias vocabulary, compat).
- New thin CLI `repair verify --packet PATH` over the same `Repair::Verifier`
  service (MCP `verify_repair` keeps working; session packet cache unchanged).

### 4. New surface, mapped to needs (nothing per-field)

| Need | Contract |
|---|---|
| review context for human/agent | `review` CLI family + `get_review_packet` MCP |
| validate an outside observation | `review observe` + `verify_review_observation` |
| close the workflow with observations | `review complete` + `create_workflow_receipt` |
| re-verify a repair without MCP | `repair verify` |

`create_workflow_receipt` derives from the MCP-cached outcome (freshness
automatic: stale cache yields `verification_required`, never a receipt).
`verify_review_observation` takes the observation inline (bounded); the server
re-observes state itself and trusts no caller-provided current values. No
`edit`, `exec`, `commit`, `waiver create`, or `baseline mutate` anywhere.

### 5. Deterministic vs review lanes stay structurally separate

Every composed document carries both lanes with disjoint key sets; schemas forbid
review-lane keys inside deterministic objects and vice versa. AI observations
enter only as `author: ai` observations with confidence and provider provenance;
`authoritative: false` is schema-required, not conventional. `bound_to_state`
proves reference to a state, never correctness of the conclusion.

### 6. Old consumers fail safe

No existing command, tool, schema, or exit changes meaning. `review`,
`get_review_packet`, `verify_review_observation`, `create_workflow_receipt`, and
`repair verify` are purely additive. Packets v1 validate under the extended
schema (new keys optional-read? No: additive keys with defaults — old packets
remain structurally valid; the extended plan section is absent, treated as
`unavailable`, never assumed).

### 7. Bounds

Packet: receipt/gate projection + bounded focus/evidence lists (same caps as
intelligence: 20 evidence, 10 focus paths). Observation: 32 findings max,
`256 KiB` document cap, message bounds. Workflow receipt: 32 observations max
(digests only, not bodies). Canonical JSON + sorted ids everywhere; digests
cover stable cores only (digests of digests for nesting, never volatile text).

### 8. What is NOT built

No provider SDKs, no agent runtime, no orchestration, no auto-apply of repairs,
no review-approval proofs (still deferred, per ADR 0020), no dashboard/server,
no observation store (observations live with their authors; RailVerdict validates
copies). No new `review` top-level config: 1.7 policy sections drive everything.

## Consequences

- Canonical services `ReviewPacket`, `ReviewObservationValidator`,
  `WorkflowReceipt` (+ extended packet plan), consumed by CLI `review`
  (`show`/`observe`/`complete`), CLI `repair verify`, MCP `get_review_packet` /
  `verify_review_observation` / `create_workflow_receipt` — 13 → 16 tools.
- New schemas `review-packet-v1`, `review-observation-v1`,
  `workflow-receipt-v1`; repair-packet-v1 extended additively.
- The G2.5 experiment runs against these contracts and is labeled exploratory
  with a single available model.

## Deferred Work

Review-approval presence proofs, provider-specific agent adapters, and
observation stores with multi-signer thresholds — each requires a new ADR and
schema version. No 1.9 design. Implemented in RailVerdict 1.8.

## Related Requirements

- FND-08
- DEBT-03
- Agent Verification Protocol (verify, repair, receipt)
- Agent Handoff trust invariants 1–25 (ADR 0019)
- Engineering policy requirements (ADR 0020)

## Related Documents

- [ADR 0001](0001-deterministic-pass-fail.md)
- [ADR 0019](0019-agent-handoff-evidence-reuse.md)
- [ADR 0020](0020-engineering-policy-contract.md)
- [Agent Verification](../agent-verification.md)
- [Agent Handoff](../agent-handoff.md)
