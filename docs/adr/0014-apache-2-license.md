# ADR 0014: Apache License 2.0 — Superseded by MIT

Status: Superseded

Decision date: 2026-08-16

Superseded date: 2026-08-17

Implementation status: Superseded

## Context

RailVerdict must remain genuinely open source and usable in personal, commercial, proprietary, open-source, internal, consulting, integration, modification, fork, and redistribution contexts. Brand-confusion rules belong outside the software license.

## Decision

**Historical decision (superseded):** RailVerdict software originally used the unmodified Apache-2.0 license. NOTICE remained factual and informational, while owner and copyright facts remained unknown unless supported by evidence; they were not invented to make the legal files appear complete.

**Current decision:** Effective 2026-08-17, the project license is the MIT License (see `LICENSE`). This ADR is retained for historical traceability. References to Apache-2.0 below describe the prior decision; the operative grant is MIT. History is preserved; Git history is not rewritten.

The open-source license supports RailVerdict's local-first operation: core
verification must remain usable without an account, hosted service, telemetry,
network access, or AI provider.

## Consequences

- No custom source-availability, noncommercial, or no-resale restriction is added.
- Trademark rules cannot narrow the software rights granted by the operative license (now MIT; historically Apache-2.0).
- Factual attribution is added only when its source and required form are established.

## Deferred Work

Phase 9 owns release-time verification of the canonical license text, NOTICE facts, packaged license material, and current third-party obligations. Publication waits for the separate qualified legal and identity gates.

## Related Requirements

- FND-04
- FND-08
- REL-02
- REL-04

## Related Documents

- [LICENSE (MIT — current)](../../LICENSE)
- [NOTICE](../../NOTICE)
- [Trademark policy](../../TRADEMARKS.md)
- [Foundation evidence](../foundation.md)
- [Roadmap](../../ROADMAP.md)
