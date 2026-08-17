# RailVerdict Philosophy

These invariants define how RailVerdict must behave when implementation begins. An accepted principle is not a claim that its runtime exists today.

## Evidence Before Opinion

Tests, analyzers, coverage artifacts, and runtime observations record facts. Explanations may add context, but they cannot rewrite whether evidence ran, failed, or was incomplete.

**Practical boundary:** incomplete required evidence cannot produce a trustworthy `PASS`; see [ADR 0001](docs/adr/0001-deterministic-pass-fail.md) and the ownership rules in [ARCHITECTURE.md](ARCHITECTURE.md).

## Deterministic Gate

Equivalent repository state, configuration, analyzer versions, and baseline must yield the same `PASS`, `WARN`, or `FAIL` decision regardless of optional intelligence or delivery platform.

**Practical boundary:** only deterministic policy creates the gate. AI, reporters, GitHub, coding agents, and future MCP consumers receive results downstream; see [ADR 0001](docs/adr/0001-deterministic-pass-fail.md) and [ARCHITECTURE.md](ARCHITECTURE.md).

## No New Debt

Legacy applications need an adoption path that does not require an immediate total cleanup. Existing findings may enter an explicit, versioned baseline; new or regressed debt remains policy-addressable.

**Practical boundary:** ordinary checks cannot silently create or mutate baselines, and waivers cannot erase evidence; see [ADR 0006](docs/adr/0006-no-new-debt.md).

## Rails First

RailVerdict is focused on Ruby on Rails verification rather than becoming a universal-language quality platform. Rails conventions should improve bounded evidence and repair context without replacing specialist tools.

**Practical boundary:** Rails-specific behavior must have an owning roadmap phase and evidence; no speculative semantic graph belongs in the core. See [PROJECT.md](PROJECT.md) and [ROADMAP.md](ROADMAP.md).

## Local-First

The complete deterministic gate must work in the repository without an account, hosted RailVerdict service, telemetry, network access, or AI provider.

**Practical boundary:** external services may be explicit adapters, but they cannot become prerequisites for core verification. See [PROJECT.md](PROJECT.md) and [ARCHITECTURE.md](ARCHITECTURE.md).

## Fully Open Source

RailVerdict uses the MIT License and keeps the core available without paid or commercial-only tiers.

**Practical boundary:** trademark presentation rules cannot narrow software rights to use, modify, fork, redistribute, integrate, or sell services around the software. See [ADR 0014](docs/adr/0014-apache-2-license.md) (historical Apache-2.0 decision superseded by MIT), [ADR 0015](docs/adr/0015-separate-trademark-policy.md), [LICENSE](LICENSE), and [TRADEMARKS.md](TRADEMARKS.md).

## AI Optional and Advisory

A project with AI disabled must receive the same deterministic gate as one with AI enabled. Optional intelligence may explain or investigate evidence, but it cannot reinterpret or weaken objective failures.

**Practical boundary:** AI reads immutable results after policy evaluation. Remote AI requires separate explicit opt-in and cannot fail open; see [ADR 0007](docs/adr/0007-advisory-ai.md) and [ADR 0008](docs/adr/0008-remote-ai-explicit-opt-in.md).

## Agent-Native Machine Output

Machine-readable results are a public contract, not a scrapeable rendering detail. Coding agents and CI systems should consume versioned structured data and stable exits.

**Practical boundary:** the CLI and JSON representation project the same deterministic result, keep diagnostics off JSON stdout, and never own policy. See [ADR 0010](docs/adr/0010-cli-and-json-canonical.md) and [ARCHITECTURE.md](ARCHITECTURE.md).

## Privacy by Design

Repository content, analyzer output, diffs, comments, and future model output are untrusted data. Source transmission is never implicit.

**Practical boundary:** public material is synthetic; remote context is minimized, inspectable, secret-scanned, and fail-closed; unresolved provenance blocks publication. See [ADR 0008](docs/adr/0008-remote-ai-explicit-opt-in.md), [ADR 0013](docs/adr/0013-information-firewall.md), and [SECURITY.md](SECURITY.md).

## Authority Summary

Evidence establishes facts. Policy makes the deterministic decision. Intelligence may advise. Consumers may render, transport, or act on the result. No downstream layer gets a second gate.
