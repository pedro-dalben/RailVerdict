# RailVerdict Product Definition

## Product

RailVerdict is a fully open-source, local-first verification framework for Ruby on Rails applications. It is intended to collect evidence from established quality tools, normalize that evidence into stable findings, apply project policy and historical baselines, and return a deterministic `PASS`, `WARN`, or `FAIL` gate for humans, CI systems, and coding agents.

RailVerdict is the verification layer, not the analyzer. Tests, linters, security scanners, coverage tools, and Rails specialists retain ownership of their technical findings. RailVerdict's role is to make their evidence complete, comparable, policy-addressable, and machine-readable.

## Core Value

Given the same repository state, configuration, analyzer versions, and baseline, RailVerdict must produce the same evidence-backed gate regardless of whether AI is configured.

The practical invariants behind that value are defined in [PHILOSOPHY.md](PHILOSOPHY.md), and their structural enforcement is proposed in [ARCHITECTURE.md](ARCHITECTURE.md).

## Intended Users

- Rails developers who need the same explainable gate locally and in CI.
- Maintainers of legacy Rails applications who need no-new-debt adoption without hiding existing findings.
- Teams that need explicit evidence completeness, tool provenance, and stable policy decisions.
- Coding agents and automation that need versioned JSON and exit semantics instead of terminal scraping.
- Adapter authors translating mature tools without adding analyzer-specific policy to the core.

## Active Scope

The planned v1 scope is one local Ruby gem and one process. It covers safe external-tool execution, normalized evidence, deterministic policy, baselines and waivers, Git-scoped verification, bounded Rails context, optional advisory AI, agent repair packets, and thin downstream adapters. Each capability belongs to the phase listed in [ROADMAP.md](ROADMAP.md); none is implied present merely because it is described here.

Phase 0 contains documentation, legal files, decisions, draft schemas, synthetic examples, and foundation validation only. It does not contain a gem or production runtime scaffold. The current public identity remains provisional: [publication is blocked](docs/foundation.md#publication-gate-record) until launch-jurisdiction evidence and qualified trademark review are recorded.

## Non-Goals

RailVerdict is not:

- a SaaS, hosted dashboard, account system, billing product, or hosted control plane;
- a replacement linter, vulnerability scanner, test framework, coverage engine, or LLM;
- an editor, autonomous coding agent, or source-rewriting system;
- a custom GitHub App or a GitHub-specific verification engine;
- a generic multi-language quality platform or full semantic code graph;
- a plugin marketplace, analyzer bundle, telemetry service, or multiple-gem ecosystem;
- a gate whose objective failures can be reinterpreted by AI or presentation adapters.

## Competitive Landscape

The observations below were checked against the linked primary project documentation on **2026-08-16**. They describe observed capabilities, not permanent comparisons or claims of superiority.

| Product or category | Verified capability observed on 2026-08-16 | Boundary for RailVerdict |
|---|---|---|
| Qlty / Code Climate Quality | Qlty documents cloud code health, local CLI analysis, plugins, new-issue workflows, and quality gates; Code Climate documents migration to Qlty Cloud. ([Qlty overview](https://docs.qlty.sh/what-is-qlty), [plugins](https://docs.qlty.sh/plugins), [migration](https://docs.qlty.sh/migration/guide)) | Do not compete on hosted dashboards or plugin count. |
| SonarQube | SonarQube documents quality gates for new issues, security, coverage, and duplication, plus Ruby coverage ingestion. ([quality gates](https://docs.sonarsource.com/sonarqube/latest/user-guide/quality-gates), [Ruby](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/languages/ruby)) | Do not build a smaller server platform. |
| Codacy | Codacy documents Git-integrated pull-request analysis, diff coverage, and configurable quality gates. ([quality gates](https://docs.codacy.com/repositories-configure/adjusting-quality-gates/), [pull requests](https://docs.codacy.com/repositories/pull-requests/)) | Keep the canonical decision repository-owned and local. |
| Semgrep | Semgrep documents local and CI security analysis for Ruby, including code, dependency, and secrets findings. ([documentation](https://docs.semgrep.dev/), [Semgrep Code](https://docs.semgrep.dev/semgrep-code/overview)) | Treat Semgrep as a possible evidence source, never reimplement its rule engine. |
| GitHub code scanning | GitHub documents CodeQL and third-party SARIF ingestion with pull-request annotations. ([setup types](https://docs.github.com/en/code-security/concepts/code-scanning/setup-types), [workflow options](https://docs.github.com/en/code-security/reference/code-scanning/workflow-configuration-options)) | GitHub remains a downstream projection, not gate authority. |
| MegaLinter | MegaLinter documents broad multi-language linter orchestration and multiple CI/reporting formats. ([repository](https://github.com/oxsecurity/megalinter)) | Analyzer breadth alone is not a differentiator. |
| reviewdog | reviewdog translates analyzer formats into local and pull-request feedback with diff filtering and fail levels. ([repository](https://github.com/reviewdog/reviewdog)) | Reporting is useful but does not replace a cross-analyzer evidence and policy contract. |
| Pronto | Pronto runs review tooling against changed lines through Ruby runners. ([repository](https://github.com/prontolabs/pronto)) | Avoid recreating a general runner ecosystem. |
| Danger | Danger executes repository-defined review conventions and publishes feedback to code-review systems. ([guide](https://danger.systems/guides/what_does_danger_do/)) | Produce evidence Danger could consume; do not require repository-host access. |
| Rails specialists | Tools such as [RuboCop Rails](https://github.com/rubocop/rubocop-rails), [Packwerk](https://github.com/Shopify/packwerk), [Prosopite](https://github.com/charkost/prosopite), and [Brakeman](https://brakemanscanner.org/docs/quickstart/) own distinct Rails style, architecture, runtime, and security domains. | Preserve each tool's meaning and provenance rather than claiming equivalent analysis. |

### Project Inference and Decision

The observed market already covers broad analyzer orchestration, hosted quality gates, security scanning, changed-line review, and pull-request presentation. RailVerdict therefore does not claim an advantage from “running many linters” or “posting comments.”

The project's chosen position is the narrower intersection of:

- offline, Rails-focused evidence normalization;
- explicit incomplete, unavailable, unsupported, timed-out, and malformed evidence states;
- deterministic repository-owned policy and no-new-debt baselines;
- stable machine contracts for CI and coding agents;
- optional intelligence that remains downstream of the gate.

This differentiation is a project inference and design decision, not a verified market outcome. Adoption value, ergonomics, and comparative effectiveness remain to be demonstrated.

## Constraints

- Repository content is English-only except explicit internationalization fixtures.
- Core verification works offline, without accounts, telemetry, hosted services, or AI.
- Policy alone owns gate authority; evidence producers and consumers cannot weaken it.
- External analyzers remain installed and versioned by the target project.
- Remote AI, if later implemented, is explicit opt-in, inspectable, minimized, secret-scanned, and fail-closed.
- Public examples are synthetic, and complete provenance review blocks first publication.
- MIT software rights remain separate from trademark presentation rules.

## Status

This document ratifies product scope, not implementation or publication readiness. The authoritative name evidence, identity mapping, and unresolved publication gate are in [docs/foundation.md](docs/foundation.md).
