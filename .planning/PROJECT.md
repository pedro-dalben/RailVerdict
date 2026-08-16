# RailVerdict

## What This Is

RailVerdict is a fully open-source, local-first verification framework for Ruby on Rails applications. It collects evidence from established quality tools, normalizes that evidence into stable findings, applies project policy and historical baselines, and returns a deterministic merge gate that humans, CI systems, and coding agents can consume.

Phase 0 rejected the working name LineClear after finding avoidable software, GitHub, and trademark collision risk. The selected identity is RailVerdict: gem `rail_verdict`, Ruby namespace `RailVerdict`, CLI `railverdict`, and configuration `.railverdict.yml`. Publication remains blocked until the documented jurisdictional and qualified trademark review is complete. The product is not a SaaS and does not depend on accounts, telemetry, hosted services, or AI.

## Core Value

Given the same repository state, configuration, analyzer versions, and baseline, RailVerdict must produce the same evidence-backed PASS, WARN, or FAIL decision regardless of whether AI is configured.

## Requirements

### Validated

(None yet — Phase 00 remediation requires another independent verification)

### Active

- [ ] Establish a research-backed product, naming, licensing, trademark, architecture, security, schema, CLI, and roadmap foundation before production implementation.
- [ ] Provide a local `railverdict check` interface that emits human-readable output and versioned machine-readable JSON without network or AI dependencies.
- [ ] Normalize analyzer and test output into a versioned, analyzer-independent Finding contract with explicit evidence origin.
- [ ] Execute external analyzers safely with timeouts, bounded output, explicit failure semantics, version detection, and no shell interpolation.
- [ ] Support fingerprint-based baselines and deterministic advisory, no-new-debt, and strict policies.
- [ ] Treat machine-readable output, changed-code verification, and repair packets as first-class agent interfaces.
- [ ] Keep AI optional, advisory by default, provider-independent, explicitly opt-in for remote transmission, redacted, budgeted, cached, and outside the default gate.
- [ ] Keep GitHub and future MCP support as adapters over the same core application services.
- [ ] Publish synthetic fixtures and English-only documentation without leaking private project information.
- [ ] Distribute the project under Apache-2.0 through GitHub and RubyGems after the provisional name clears Phase 0 validation.

### Out of Scope

- SaaS, hosted dashboards, accounts, billing, subscriptions, hosted databases, and commercial-only tiers — RailVerdict is a local-first open-source tool.
- A custom analyzer, vulnerability scanner, test framework, LLM, editor, or autonomous code-editing agent — RailVerdict orchestrates mature tools and verifies repairs.
- A custom GitHub App, MCP adapter, AI repair mode, or quality score in the initial trustworthy core — these depend on stable CLI and schema contracts.
- Mandatory AI, telemetry, network access, code upload, or privileged fork workflows — these violate deterministic and privacy boundaries.
- IntegrarPlus-derived code, data, identifiers, architecture, fixtures, metrics, or operational details are prohibited; the literal name is allowed only in authorized high-level historical attribution or provenance-policy documentation. Any actual private detail remains a release blocker.

## Context

Coding agents reduce the cost and time required to produce Rails code, shifting the bottleneck toward trustworthy verification. Existing tools provide valuable but fragmented signals: tests, lint, security, coverage, maintainability, migration safety, dependency health, and runtime observations. RailVerdict's product value is the stable verification model that correlates those signals with a versioned baseline and explicit policy.

The planned architecture has four one-way layers: evidence collection, deterministic verification core, optional intelligence, and agent consumers. Evidence owns facts; the core owns normalization and policy; intelligence explains or investigates; agents consume structured results and act externally.

The initial research set includes Minitest, RSpec, RuboCop, rubocop-rails, SimpleCov, Undercover, RubyCritic, Brakeman, Prosopite, bundler-audit, and strong_migrations. Phase 0 must decide which integrations belong in early releases based on maintenance, licensing, output stability, Rails relevance, execution cost, and overlap.

## Constraints

- **Language**: Repository content is English-only except explicit internationalization fixtures — public contracts and collaboration must not mix languages.
- **License**: Apache License 2.0 with separate NOTICE and trademark policy — no custom source-availability restrictions.
- **Architecture**: Deterministic evidence and policy own the default gate — AI cannot reinterpret objective failures.
- **Adoption**: Existing debt can enter a versioned baseline; new changes cannot silently worsen it — no-new-debt is the recommended mode.
- **Execution**: Core behavior works offline and invokes external tools with argument arrays, bounded I/O, timeouts, and explicit failures.
- **Privacy**: Remote AI is explicit opt-in, context-minimized, inspectable, secret-scanned, and fail-closed.
- **Security**: Repository text and fork contributions are untrusted; privileged credentials cannot be exposed to untrusted code.
- **Contracts**: Findings, configuration, JSON results, baselines, fingerprints, analyzer APIs, reporters, exit codes, and future AI/MCP adapters are versioned before 1.0 stability promises.
- **Scope**: One Ruby gem until a demonstrated need justifies separation; no full semantic code graph in the MVP.
- **Provenance**: Only synthetic public examples; a repository-wide private-information scan blocks the first public release.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Evidence before merge | Objective evidence must remain reproducible and auditable | — Pending |
| Rails-first verification framework | Rails conventions provide focus and differentiation from generic quality platforms | — Pending |
| Deterministic gate with optional advisory AI | AI can add context without becoming the source of truth | — Pending |
| Local-first, fully open-source product | Core verification must not depend on a vendor, account, network, or hosted backend | — Pending |
| External analyzer processes | Reuse mature tools while avoiding dependency, redistribution, and version coupling | — Pending |
| Versioned canonical Finding | Policy, baseline, reporters, and agents need one stable analyzer-independent contract | — Pending |
| Fingerprint baseline and no-new-debt adoption | Legacy applications need incremental adoption without a full cleanup prerequisite | — Pending |
| GitHub and MCP remain adapters | Core contracts must work locally and remain platform-independent | — Pending |
| Apache-2.0 plus separate trademark policy | Preserve genuine open-source use while protecting official project identity | — Pending |
| Horizontal project structure | Contract and infrastructure layers must stabilize before higher-level adapters consume them | — Pending |
| Rename LineClear to RailVerdict before publication | LineClear had avoidable exact-name software, GitHub, and trademark collision signals; RailVerdict's dated package/repository/domain checks returned no exact record at that time, which is technical evidence rather than legal clearance | — Pending qualified trademark review |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? Move to Out of Scope with reason.
2. Requirements validated? Move to Validated with phase reference.
3. New requirements emerged? Add to Active.
4. Decisions to log? Add to Key Decisions.
5. "What This Is" still accurate? Update if drifted.

**After each milestone** (via `$gsd-complete-milestone`):
1. Review every section.
2. Confirm the Core Value still drives priorities.
3. Audit Out of Scope reasons.
4. Update Context with current evidence.

---
*Last updated: 2026-08-16 after Phase 00 remediation pass*
