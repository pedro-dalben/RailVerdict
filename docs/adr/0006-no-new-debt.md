# ADR 0006: No-New-Debt Adoption

Status: Accepted

Decision date: 2026-08-16

Implementation status: Implemented in Phase 03 (plans 03-02..03-06). See `docs/baselines.md` for baseline/comparison/policy semantics.

## Context

Legacy Rails applications need an adoption path that does not require an immediate whole-project cleanup. Accepting existing debt must not make the baseline a mechanism for hiding regressions.

## Decision

No-new-debt is RailVerdict's recommended adoption mode. An explicit reviewed baseline may acknowledge existing findings, while any new or regressed finding cannot pass silently and is evaluated by deterministic project policy. Advisory and strict modes remain explicit alternatives.

## Consequences

- Existing findings stay visible and distinguishable from introduced or changed findings.
- Baseline updates are deliberate review events rather than side effects of a check.
- Policy, not the baseline or analyzer, decides whether a regression warns or fails.

## Deferred Work

Phase 3 owns baseline comparison, finding-state classification, advisory/no-new-debt/strict modes, and policy tests. This ADR recommends a mode but implements no policy behavior.

## Related Requirements

- FND-08
- DEBT-03
- DEBT-04
- DEBT-05
- DEBT-06
- DEBT-07

## Related Documents

- [Philosophy](../../PHILOSOPHY.md)
- [Architecture](../../ARCHITECTURE.md)
- [Security](../../SECURITY.md)
- [Roadmap](../../ROADMAP.md)
