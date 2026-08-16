# ADR 0007: Advisory AI

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

AI can add explanations and investigation guidance, but model output is variable and may be unavailable, invalid, or influenced by untrusted repository text. Core verification must remain useful and reproducible without AI.

## Decision

AI is optional and advisory by default. AI cannot reinterpret or weaken the deterministic PASS/FAIL gate, change its exit status, or become required evidence. Advisory output remains visibly separate from deterministic findings and policy decisions.

## Consequences

- Enabling, disabling, changing, or losing an AI provider does not change the deterministic gate.
- AI output requires provenance, confidence, validation, and an unavailable state.
- RailVerdict grants AI no source-editing or gate authority.

## Deferred Work

Phase 6 owns the advisory analysis contract, provider path, schema validation, degradation behavior, and gate-equivalence tests. No AI integration exists because this decision is accepted.

## Related Requirements

- FND-08
- AI-01
- AI-04
- AI-05

## Related Documents

- [Philosophy](../../PHILOSOPHY.md)
- [Architecture](../../ARCHITECTURE.md)
- [Security](../../SECURITY.md)
- [Roadmap](../../ROADMAP.md)
