# ADR 0002: External Analyzer Execution

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

Mature analyzers have independent installation, version, license, output, and failure contracts. Pulling them into RailVerdict would couple the gem to target-project dependencies and could obscure third-party licensing or execution failures.

## Decision

RailVerdict will execute analyzers as external processes from the target-project bundle and record their exact identity and result. It will not vendor, bundle, silently install, or reimplement those analyzers. Executable-plus-argv isolation reduces command-injection risk but is not an OS sandbox. Brakeman remains on HOLD and outside the supported shortlist until the required written legal/product review resolves its current license and product-use boundary.

## Consequences

- Target projects control analyzer installation and versions.
- Every adapter needs explicit version, command, output, timeout, and failure contracts.
- Missing, unsupported, malformed, or failed required analyzer evidence stays incomplete rather than becoming zero findings.
- External execution does not restrict the analyzer's host-level authority by itself.

## Deferred Work

Phase 1 owns the first external execution boundary and narrow adapter. Later adapter phases may add only reviewed tools behind the same boundary; no analyzer support is implemented by this ADR.

## Related Requirements

- FND-05
- FND-08
- CORE-05
- CORE-06
- CORE-07
- CORE-09
- EVID-09
- EVID-10

## Related Documents

- [Analyzer registry](../analyzers.md)
- [Architecture](../../ARCHITECTURE.md)
- [Security](../../SECURITY.md)
- [Roadmap](../../ROADMAP.md)
