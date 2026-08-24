# PR Intelligence v1

Deterministic, machine-readable summary of one changed-scope verification. PR Intelligence is a projection of the canonical `GateResult` and Git change scope — never a second policy authority and never produced by rerunning analyzers.

## Receipt binding (1.2)

When a changed-scope verification produces a Verification Receipt, the receipt binds PR Intelligence by digest over its **stable projection** (`RailVerdict::PRIntelligence.stable_projection`). Volatile test-runtime fields inside `test_intelligence.analyzers.*` — `duration_seconds` and `seed` — are excluded from the binding so identical meaningful inputs yield identical receipts. The public PR Intelligence document itself is unchanged; see [Agent Verification Protocol](agent-verification.md) and [ADR 0017](adr/0017-verification-receipts.md).

`railverdict pr` explains a pull-request-sized change. It is a read-only
projection over exactly one `Check.execute(changed: true, base: ...)` run.
It does not rerun analyzers, create a second comparison engine, or introduce a
merge/readiness policy.

## Usage

```bash
railverdict pr --base origin/main
railverdict pr --base origin/main --format json
```

The base follows the existing changed-scope rules: an explicit `--base` wins,
then configured `git.base`; if neither resolves, the command fails closed.
`--baseline` and `--waiver` use the same read-only paths as `check`.

## Contract

JSON is `PRIntelligence` schema version `1.0`, validated by
[`schemas/pr-intelligence-v1.schema.json`](../schemas/pr-intelligence-v1.schema.json).
It records `head`, `base`, `merge_base`, and the configuration digest, then
includes an explicit stable projection of the canonical `gate_result`. The
projection contains the schema version, completion status, gate, policy status,
findings, operational failures, and decision reasons; it excludes local
checkout identity and other runtime-only fields such as the repository root,
analyzer invocations, and raw baseline metadata.

The document contains:

- deterministic file, line, and status metrics from the existing Git diff;
- six path-based signals with sorted, bounded evidence paths;
- quality delta counts from canonical baseline comparison;
- canonical analyzer execution/evidence status;
- only normalized RSpec/Minitest metrics already present in analyzer evidence;
- global and changed-line SimpleCov metrics only when already available.

Minimal JSON shape:

```json
{
  "schema_version": "1.0",
  "provenance": { "head": "<sha>", "base": "<sha>", "merge_base": "<sha>", "configuration_digest": "<sha256>" },
  "change": { "available": true, "files_changed": 4, "lines_added": 38, "lines_removed": 7 },
  "signals": { "authorization_change": { "available": true, "present": true, "evidence": ["app/policies/user_policy.rb"] } },
  "quality_delta": { "available": false, "reason": "baseline_not_available" },
  "gate_result": { "completion_status": "complete", "gate": "PASS", "policy_status": "pass" }
}
```

The published document also includes the fixed status-count, analyzer,
test-intelligence, and coverage fields defined by the schema.

## Meaning and failure behavior

Signals mean that a review surface may deserve attention. They are not risk
probabilities and do not infer business meaning. `GateResult` remains the sole
authority for `PASS`, `WARN`, `FAIL`, and `INCOMPLETE`.

When no compatible baseline is loaded, `quality_delta.available` is `false`
with `reason: "baseline_not_available"`. The report does not turn missing
comparison evidence into zero counts. Invalid Git bases, malformed evidence,
and required analyzer timeouts remain `INCOMPLETE` and preserve exit code `2`.

The report has no timestamp, autonomous behavior, AI fields, GitHub state,
webhooks, comments, or merge recommendation. Identical repository state,
configuration, base, evidence, and baseline produce byte-identical JSON.
