# ADR 0011: MCP as an Adapter

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

MCP can expose RailVerdict to compatible consumers, but a transport-specific implementation must not duplicate analyzers, policy, fingerprinting, or verification. Enabling it before the underlying contracts stabilize would create a second compatibility surface around moving behavior.

## Decision

MCP is a thin downstream adapter over stable CLI, `Finding`, `GateResult`, and repair-packet contracts. It starts read-only, calls the same application services as the CLI, and cannot own or recompute analyzer execution, policy, or the deterministic gate.

## Consequences

- MCP transport and capability negotiation stay outside the core.
- Contract-parity tests must compare MCP and CLI results for identical inputs.
- No source-editing, MCP-only policy, or MCP-only verification behavior is authorized.

## Deferred Work

Phase 8 owns the read-only MCP transport, then-current protocol review, supported SDK decision, and CLI/MCP parity tests. This ADR creates no MCP server or dependency.

## Related Requirements

- FND-08
- MCP-01
- MCP-02
- MCP-03

## Related Documents

- [Architecture](../../ARCHITECTURE.md)
- [Contracts](../contracts.md)
- [Security](../../SECURITY.md)
- [Roadmap](../../ROADMAP.md)
