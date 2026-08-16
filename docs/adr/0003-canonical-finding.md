# ADR 0003: Canonical Finding

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

Analyzer-native outputs differ in identifiers, severity, location, provenance, and lifecycle. Policy, baselines, reporters, and downstream adapters need one evidence record without importing tool-specific or platform-specific authority into the core.

## Decision

The versioned `Finding` is RailVerdict's canonical, analyzer-independent evidence record. It retains origin and native evidence provenance, has no policy authority, and cannot carry analyzer-supplied blocking, PASS, WARN, or FAIL decisions.

## Consequences

- Adapters normalize facts into one contract while preserving native references.
- Policy decisions and gate status remain separate immutable outputs.
- GitHub, AI, MCP, and reporters consume findings without adding fields to the canonical evidence model.

## Deferred Work

Phase 1 owns the runtime `Finding` construction and validation path. The existing schema is a draft contract, and this accepted ADR does not claim that normalization is implemented.

## Related Requirements

- FND-08
- FND-09
- CORE-10
- CORE-11
- GIT-08

## Related Documents

- [Contracts](../contracts.md)
- [Finding schema](../../schemas/finding-v1.schema.json)
- [Architecture](../../ARCHITECTURE.md)
- [Roadmap](../../ROADMAP.md)
