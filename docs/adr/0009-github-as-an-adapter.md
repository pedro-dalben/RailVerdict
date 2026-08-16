# ADR 0009: GitHub as an Adapter

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

Local verification must work independently of GitHub. Pull-request annotations, summaries, statuses, and SARIF are delivery surfaces, while repository scope and policy truth must remain reproducible from local Git and core contracts.

## Decision

GitHub is a downstream adapter over local Git facts and the core `GateResult`; it is not a second verification engine or gate. It may project canonical findings and policy decisions but cannot recompute scope, policy, evidence completeness, PASS, WARN, or FAIL.

The initial delivery remains one gem and one process. A downstream adapter does
not justify a second package, daemon, or platform-specific core.

## Consequences

- The same local gate can serve other CI and automation systems.
- GitHub identifiers and permissions stay outside canonical core objects.
- Fork workflows must keep untrusted code away from secrets, publisher identity, write tokens, and remote-AI credentials.

## Deferred Work

Phase 4 owns trustworthy local Git scope, SARIF, GitHub Actions guidance, annotations, summaries, and fork-security proof. This ADR adds no workflow, action, app, or GitHub runtime behavior.

## Related Requirements

- FND-08
- GIT-01
- GIT-04
- GIT-05
- GIT-06
- GIT-07
- GIT-08

## Related Documents

- [Architecture](../../ARCHITECTURE.md)
- [Security](../../SECURITY.md)
- [Contracts](../contracts.md)
- [Roadmap](../../ROADMAP.md)
