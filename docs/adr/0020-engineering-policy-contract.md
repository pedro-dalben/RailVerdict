# ADR 0020: Engineering Policy and Review Governance Contract

Status: Accepted
Decision date: 2026-09-05
Implementation status: Implemented in RailVerdict 1.7.0

## Context

RailVerdict 1.6 turns diffs into canonical change facts: 18 Rails surfaces with
detection tiers, explainable review risk (`LOW`/`MEDIUM`/`HIGH`/`CRITICAL` with
reason codes), executed verification scope (`FULL` vs `TARGETED`), missing-evidence
facts, and an ordered Review Focus list (PR Intelligence v1.1). Facts alone do not
answer the product question: *what does this change require before it may proceed?*

Today that answer lives in three places: `Verification::Policy` modes
(`advisory`/`no_new_debt`/`strict`) decide the gate; human reviewers re-derive a
Definition of Done from the diff; agents guess. A policy that exists only as gate
modes cannot express "authorization changes require RSpec + Brakeman", "migrations
require FULL verification", "changed-lines coverage >= 85%", or "high-risk changes
require human review" — and any attempt to bolt workflow state onto `GateResult`
risks weakening the deterministic authority or, worse, presenting a pending human
action as `PASS`.

## Decision

### 1. GateResult stays the sole verification authority

`GateResult` v1 (`contracts/gate_result.rb`, schema `result-v1`) is frozen in
meaning: it reports what deterministic evidence proves under the configured mode,
baseline, and waivers. The engineering-policy layer **reads** the decided gate and
**never rewrites it**. No AI observation, review document, or policy rule changes a
finding, a severity, a state, or the gate.

### 2. Separate versioned envelope: `engineering-policy-v1`

Governance is a **separate versioned envelope** (`EngineeringPolicy` document,
schema `engineering-policy-v1.schema.json`), not an additive projection inside
`result-v1`, `pr-intelligence-v1.1`, receipt v1, or handoff v1. Rationale: v1
contracts are frozen and embedded in stored receipts/handoffs; widening them would
change the meaning of already-distributed documents. The envelope binds the exact
inputs it was derived from (`gate`, `configuration_digest`, `policy_digest`,
repository state digest) so staleness is detectable without trusting the envelope.

### 3. Requirement statuses and decision semantics

Each requirement: `id` (deterministic, `req-<kind>-<key>`), `kind`, `trigger`,
`status`, `required_evidence`, `observed_evidence`, `reason_codes` (sorted),
`provenance`, `classification` (`deterministic` | `review`). Statuses:

- `satisfied` — rule triggered, evidence complete and sufficient.
- `violated` — rule triggered, complete evidence proves non-compliance → decision `FAIL`.
- `unavailable` — rule triggered but required evidence is missing, stale, or
  unobservable → decision `INCOMPLETE` (fail-closed; a recovery action is emitted,
  never a code-repair suggestion for evidence problems).
- `not_applicable` — rule not triggered. Emitted explicitly; never a fictive "satisfied".
- `review_required` — rule triggered, decision needs a human (or external) review
  whose *presence* is verifiable as fact but whose *correctness* is probabilistic.
  Never rendered as approval, never folded into the gate.

Decision precedence: any `violated` → `FAIL`; else any `unavailable` or gate
`INCOMPLETE`/`interrupted` → `INCOMPLETE`; else any `review_required` →
`REVIEW_REQUIRED`; else mirror the gate (`PASS`/`WARN` → `PASS`, `FAIL` →
`FAIL` with reason `gate_failed`). `REVIEW_REQUIRED` is a readiness state, not a
gate: it is never exit 0/1/2, never `PASS`, never analyzer `FAIL`.

### 4. Human review without fabricated approval

A pending review requirement is exposed as `review_required` with the rule that
triggered it and the evidence that would satisfy *presence* (e.g. a review record
bound to the verified state). RailVerdict 1.7 defines no review-approval proof:
no schema, flag, or file the tool itself produces counts as approval. `REVIEW_REQUIRED`
clears only when the requirement no longer triggers (risk/area unconfigured or
change no longer touches it), or when a future version defines a verifiable
presence proof. AI review is observational: it may add context, it never changes
any requirement status.

### 5. Old consumers fail safe

Configs 1–1.6 contain no `engineering_policy` section: the planner runs, every
rule is `not_applicable`, the decision mirrors the gate byte-for-byte in behavior.
`check`/`pr` exits and JSON shapes are untouched. The new `policy` command uses a
new exit code `3` for `REVIEW_REQUIRED` (0 `PASS`, 1 `FAIL`, 2 `INCOMPLETE`,
130 interrupted — same ladder as `check`); an old consumer that does not know exit
3 treats any nonzero exit as failure, which is the fail-closed direction. Receipts
and handoffs v1 remain structurally valid; under a stronger policy they evaluate
as `stale`/`verification-required` via digest comparison (`policy_drift`), and an
old receipt never satisfies a rule that did not exist when it was produced.

### 6. Receipt/handoff binding

The envelope records `configuration_digest` (bytes of the config file) and
`policy_digest` (canonical JSON of the effective `engineering_policy` section).
`EngineeringPolicy.drift_status(receipt, configuration)` returns `fresh`,
`policy_drift`, or `unavailable` by comparing digests; it never re-labels the
receipt itself. CLI `policy --receipt PATH` / `--handoff PATH` reports drift;
MCP `get_engineering_policy` accepts the same optional inputs.

### 7. Stable vs presentation fields

Stable (digest-covered, canonical order): `schema_version`, `decision`,
`requirements[]` (sorted by `id`), `gate`, `configuration_digest`,
`policy_digest`, `reason_codes`. Presentation (never digest-covered): console
rendering, `summary` strings, evidence `message` text. Human messages are never
used as requirement identity.

### 8. Bounds

Requirements are bounded by the rule count of the effective policy (closed schema,
`additionalProperties: false`, `maxProperties`, enum-closed severities/surfaces,
glob count and length caps, `changed_lines_minimum` 1–100). Evidence lists cap at
20 entries with `additional_evidence_count`, matching intelligence conventions.
Rule order in the canonical document is sorted by `id`, independent of config
file order: reordering rules never changes the canonical digest.

### 9. What is NOT built

No dashboard, server, database, history store, plugin marketplace, provider SDK,
or orchestration. SARIF stays findings-only (policy readiness is JSON/console/MCP;
SARIF has no readiness vocabulary and must not gain a second gate). No new
`review` top-level concept duplicating config-1.6 `review`: `review.risk` and
`review.sensitive_paths` remain the *signal* source; `engineering_policy.review`
rules only *require* review for what those signals flag.

## Consequences

- New canonical service `RailVerdict::EngineeringPolicy` (plan + evaluate),
  consumed by CLI `policy` and MCP `get_engineering_policy` — no interface owns
  its own policy logic.
- New schemas `engineering-policy-v1` and `configuration-v1.7` (dispatch by
  `version == 1.7`); config 1–1.6 behavior unchanged.
- Coverage-gated rules fail closed (`unavailable`) when coverage evidence is
  missing or stale; a valid ratio below threshold is `violated` (`FAIL`).
- `TARGETED`-executed evidence against a `FULL`-required rule is `unavailable`
  with a re-run-FULL recovery action, never `PASS`.
