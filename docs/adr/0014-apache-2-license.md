# ADR 0014: Apache License 2.0

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

RailVerdict must remain genuinely open source and usable in personal, commercial, proprietary, open-source, internal, consulting, integration, modification, fork, and redistribution contexts. Brand-confusion rules belong outside the software license.

## Decision

RailVerdict software uses the unmodified Apache-2.0 license. NOTICE remains factual and informational, while owner and copyright facts remain unknown unless supported by evidence; they are not invented to make the legal files appear complete.

The open-source license supports RailVerdict's local-first operation: core
verification must remain usable without an account, hosted service, telemetry,
network access, or AI provider.

## Consequences

- No custom source-availability, noncommercial, or no-resale restriction is added.
- Trademark rules cannot narrow the software rights granted by Apache-2.0.
- Factual attribution is added only when its source and required form are established.

## Deferred Work

Phase 9 owns release-time verification of the canonical license text, NOTICE facts, packaged license material, and current third-party obligations. Publication waits for the separate qualified legal and identity gates.

## Related Requirements

- FND-04
- FND-08
- REL-02
- REL-04

## Related Documents

- [Apache License 2.0](../../LICENSE)
- [NOTICE](../../NOTICE)
- [Trademark policy](../../TRADEMARKS.md)
- [Foundation evidence](../foundation.md)
- [Roadmap](../../ROADMAP.md)
