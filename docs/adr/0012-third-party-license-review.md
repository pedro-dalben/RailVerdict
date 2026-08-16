# ADR 0012: Third-Party License Review

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

Analyzer and dependency licenses, versions, distribution terms, and commercial-use boundaries can change independently of RailVerdict. External execution reduces coupling but does not itself answer whether a tool may be shortlisted, supported, bundled, distributed, or used in a release.

## Decision

Every third-party license and commercial-use boundary receives a dated, source-linked review before shortlist, support, bundling, distribution, or release decisions. Unknown or unresolved facts remain explicit and block the affected decision; no owner, contact, reviewer, or legal conclusion is invented. Brakeman remains on HOLD pending its written legal/product review.

## Consequences

- Technical value cannot override an unresolved license or product-use boundary.
- Registry evidence is refreshed at implementation and release decision points.
- External tools remain target-project controlled unless a separate reviewed decision says otherwise.
- Screening notes are not presented as legal advice.

## Deferred Work

Each implementing adapter phase owns a current review before adopting its tool. Phase 9 owns the release review and published license inventory. Qualified reviewers and factual owners remain unresolved until evidenced.

## Related Requirements

- FND-05
- FND-08
- EVID-09
- EVID-10
- REL-02
- REL-08

## Related Documents

- [Analyzer registry](../analyzers.md)
- [Foundation evidence](../foundation.md)
- [Security](../../SECURITY.md)
- [Roadmap](../../ROADMAP.md)
