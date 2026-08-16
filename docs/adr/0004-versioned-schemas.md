# ADR 0004: Versioned Schemas

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

Configuration, findings, results, baselines, and adapter payloads become integration surfaces as soon as people and automation depend on them. One product version cannot accurately describe the compatibility history of every contract.

## Decision

Independently versioned schemas are the strict canonical machine contracts. Each contract rejects unknown data at its boundaries, validates offline where required, and receives its own compatibility and migration history before any stability promise is made.

## Consequences

- Contract versions may evolve independently from the gem version and from one another.
- Producers and consumers must declare the schema version they use.
- Pre-implementation schemas remain drafts until fixture-backed runtime enforcement proves them.

## Deferred Work

Phase 1 owns initial runtime schema enforcement and machine-result validation. Later owning phases define and test baseline, waiver, AI, repair-packet, and adapter schemas before promising stability.

## Related Requirements

- FND-08
- FND-09
- FND-10
- CORE-03
- CORE-10
- CORE-12

## Related Documents

- [Contracts](../contracts.md)
- [Finding schema](../../schemas/finding-v1.schema.json)
- [Configuration schema](../../schemas/configuration-v1.schema.json)
- [Architecture](../../ARCHITECTURE.md)
- [Roadmap](../../ROADMAP.md)
