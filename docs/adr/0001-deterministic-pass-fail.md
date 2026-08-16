# ADR 0001: Deterministic PASS/FAIL Authority

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

RailVerdict must give humans, CI systems, and coding agents the same evidence-backed gate for equivalent repository state, configuration, analyzer versions, and baseline. Analyzer, parser, timeout, or evidence-completeness failures are not clean runs.

## Decision

Deterministic policy is the sole authority for PASS and FAIL. Required evidence that is incomplete cannot produce PASS, and AI, reporters, GitHub, MCP, and other adapters cannot reinterpret or recompute the gate.

## Consequences

- Evidence completeness remains distinct from finding count and policy outcome.
- Optional consumers may explain or project a result but cannot weaken it.
- Later implementations must preserve deterministic ordering, inputs, and failure semantics.

## Deferred Work

Phase 1 owns the deterministic evaluator, immutable gate result, incomplete-evidence behavior, and equivalence tests. This accepted decision does not claim that any runtime gate exists today.

## Related Requirements

- FND-08
- CORE-08
- CORE-11
- CORE-14
- AI-01

## Related Documents

- [Project](../../PROJECT.md)
- [Philosophy](../../PHILOSOPHY.md)
- [Architecture](../../ARCHITECTURE.md)
- [Contracts](../contracts.md)
- [Security](../../SECURITY.md)
- [Roadmap](../../ROADMAP.md)
