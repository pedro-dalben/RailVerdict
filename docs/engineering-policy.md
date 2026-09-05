# Engineering Policy (1.7)

Turns 1.6 change facts into deterministic requirements. `GateResult` stays the
sole verification authority; policy reports readiness on top of the decided gate.

## Quick start

```yaml
version: 1.7
mode: no_new_debt
analyzers:
  rubocop: { enabled: true, required: true }
engineering_policy:
  findings:
    new_high: forbid
  review:
    high:
      human_review: required
```

```sh
railverdict policy --base main --format json   # exits 0/1/2/3
```

## Decisions

| State | Meaning | Exit |
|---|---|---|
| `PASS` | every triggered rule satisfied, gate clean | 0 |
| `FAIL` | a rule violated with complete evidence | 1 |
| `INCOMPLETE` | a triggered rule lacks observable evidence (fail-closed, with recovery action) | 2 |
| `REVIEW_REQUIRED` | human review required, gate untouched, no approval fabricated | 3 |

## Rules

- `findings.new_critical` / `new_high`: `forbid` fails on introduced/changed/moved
  findings at that severity; existing and waived debt never counts as new. Needs a
  compatible baseline, else `INCOMPLETE`.
- `coverage.changed_lines_minimum` (1–100): valid ratio below the limit is `FAIL`;
  missing or stale coverage is `INCOMPLETE`.
- `changes.<surface>`: `require_analyzers` (analyzers must have executed with
  complete evidence) and/or `verification_scope: full` (TARGETED evidence is
  `INCOMPLETE` with a re-run-FULL recovery action, never `PASS`). Keys must be
  known change surfaces or `review.sensitive_paths` areas; unknown keys are a
  configuration error.
- `review.<level|surface|area>`: `human_review: required` yields `review_required`
  when triggered. There is no machine approval proof in 1.7.

Untriggered rules are reported `not_applicable`, never fictive `satisfied`.

## Migration

- Configs 1–1.6 load unchanged and behave identically; add `version: 1.7` plus an
  `engineering_policy` section only when you want governance.
- `check`/`pr` commands, exits, and JSON shapes are untouched. `policy` is new;
  exit 3 is new — old consumers treat any nonzero exit as failure (fail-closed).
- Receipts/handoffs v1 stay valid; under a stronger policy they report
  `policy_drift` via `policy --receipt PATH`. An old receipt never satisfies a
  rule that did not exist when it was produced.
- MCP `get_engineering_policy` mirrors CLI `policy`. SARIF stays findings-only.

## Limitations

- Human-review presence has no verifiable proof yet; `REVIEW_REQUIRED` clears only
  when the trigger goes away.
- Changed-lines coverage needs fresh SimpleCov evidence joined against the Git
  diff; uncovered-but-untracked files count as missing.
- Intelligence remains path-convention heuristics (1.6 limits apply).
