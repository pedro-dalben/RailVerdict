# ADR 0010: CLI and JSON as Canonical Interfaces

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

Humans, CI systems, and coding agents need one local automation boundary that does not depend on terminal scraping, hosted services, GitHub, AI, or MCP. Machine consumers require stable structure and failure semantics.

## Decision

The local CLI and versioned canonical JSON output are RailVerdict's stable automation interfaces. Given equivalent inputs, commands emit deterministic content and ordering; JSON mode writes exactly one document to stdout, diagnostics only to stderr, and the CLI alone maps completed policy, incomplete execution, and interruption to documented exits.

## Consequences

- Human presentation may evolve without breaking machine consumers of versioned JSON.
- Reporters are projections and do not call `exit` or alter gate authority.
- GitHub, coding-agent, and future MCP adapters reuse the same application services and contracts.
- Pre-1.0 command, JSON, stream, and exit behavior remains a draft until proven.

## Deferred Work

Phase 1 owns the initial CLI, console and JSON reporters, deterministic ordering, stream isolation, and exit tests. Later phases extend only behavior assigned by the roadmap.

## Related Requirements

- FND-08
- FND-10
- CORE-01
- CORE-12
- CORE-13
- CORE-14
- AGNT-01

## Related Documents

- [Contracts](../contracts.md)
- [Architecture](../../ARCHITECTURE.md)
- [Project](../../PROJECT.md)
- [Roadmap](../../ROADMAP.md)
