# ADR 0008: Remote AI Requires Explicit Opt-In

Status: Accepted

Decision date: 2026-08-16

Implementation status: Not started

## Context

Remote AI can transmit repository-derived material across a trust boundary. Source, diffs, messages, model input, and model output are untrusted, and likely secrets or excessive context must stop transmission rather than degrade privacy silently.

## Decision

Remote AI requires explicit opt-in before every authorized provider path. The user can inspect the exact minimized context manifest before transmission; secret exclusions, detection, and redaction run first; request, finding, context, time, and cost budgets apply before invocation; and invalid, unsafe, or unavailable response handling is fail-closed. Remote AI remains advisory and cannot own or alter the deterministic gate.

The AI boundary is provider-independent. Provider credentials, transport, model
selection, and provider-specific failures stay behind the intelligence adapter;
the verification core consumes only the versioned advisory result contract.

## Consequences

- No provider, account, network access, or source transmission is required for core verification.
- Likely secrets or an invalid context manifest prevent the request.
- Provider responses are bounded, schema-validated untrusted data with explicit provenance.
- Raw sensitive context is not cached by default.

## Deferred Work

Phase 6 owns consent, manifest inspection, context minimization, secret controls, budgets, provider-response validation, caching boundaries, and failure tests. This ADR authorizes no remote call today.

## Related Requirements

- FND-08
- AI-02
- AI-03
- AI-04
- AI-05
- AI-06
- AI-07
- AI-08

## Related Documents

- [Architecture](../../ARCHITECTURE.md)
- [Security](../../SECURITY.md)
- [Roadmap](../../ROADMAP.md)
