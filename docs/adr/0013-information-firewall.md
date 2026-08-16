# ADR 0013: Information Firewall

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

Public source, documentation, examples, fixtures, history, packages, archives, media, release notes, and CI artifacts can leak private provenance even when no credential is present. A committed detection dictionary could itself disclose the information it is meant to find.

## Decision

RailVerdict uses a synthetic, English-only information firewall for public material. Maintainer-controlled private patterns stay outside Git, scans and reports are non-echoing, and only safe counts, categories, artifact digests, evidence states, and reviewed paths may be recorded. Any unresolved match blocks publication.

## Consequences

- Public examples and fixtures are invented from scratch in generic domains.
- Secret scanning is defense in depth, not proof of provenance safety.
- Passed, failed, not run, and not applicable surfaces remain distinct.
- Credential matches require rotation or revocation before repository cleanup.

The literal name `IntegrarPlus` is allowed only in an authorized concise
historical attribution or in provenance-policy documentation defining that
exception. No private technical, operational, domain, or personal information
may accompany it; all public examples and fixtures remain synthetic.

## Deferred Work

Phase 9 owns enforcement across the generated gem, archives, media, documentation, release notes, CI artifacts, installed artifacts, and the complete release candidate. Phase 0 records policy and current evidence honestly without private pattern values.

## Related Requirements

- FND-08
- FND-12
- REL-02
- REL-08

## Related Documents

- [Security](../../SECURITY.md)
- [Project](../../PROJECT.md)
- [Foundation evidence](../foundation.md)
- [Roadmap](../../ROADMAP.md)
