# ADR 0005: Fingerprint-Based Baseline

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

File and line alone are unstable finding identities. Legacy projects need a reviewable way to recognize existing debt across unrelated edits without storing source or silently absorbing new findings.

## Decision

Stable, versioned fingerprints are the finding identity used by explicit baselines. A baseline records reviewed canonical fingerprint data from a complete trusted run; ordinary checks never create or silently mutate it, and fingerprint-algorithm changes require explicit compatibility or migration handling.

## Consequences

- Fingerprint payloads and algorithms are public compatibility contracts.
- Baseline changes are explicit, atomic, and reviewable.
- Ambiguous correlation remains visible rather than silently merging distinct findings.
- Source code, credentials, full logs, and AI prompts do not belong in a baseline.

## Deferred Work

Phase 3 owns fingerprint regression vectors, baseline creation and comparison, collision handling, and migrations. This ADR accepts the identity model but implements no fingerprint or baseline behavior.

## Related Requirements

- FND-08
- DEBT-01
- DEBT-02
- DEBT-03
- DEBT-04
- DEBT-10

## Related Documents

- [Philosophy](../../PHILOSOPHY.md)
- [Architecture](../../ARCHITECTURE.md)
- [Security](../../SECURITY.md)
- [Roadmap](../../ROADMAP.md)
