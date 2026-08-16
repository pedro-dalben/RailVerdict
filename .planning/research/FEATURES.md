# Feature Landscape

**Project:** LineClear (working name)
**Domain:** Rails-native deterministic verification layer
**Researched:** 2026-08-16
**Overall confidence:** MEDIUM

## Executive Position

LineClear should not try to become another hosted code-quality dashboard or another bundle of linters. Its useful position is narrower: a fully open-source, local-first verification layer for Rails projects that turns evidence from existing tools into a stable finding model and a deterministic `PASS` / `WARN` / `FAIL` decision. RuboCop, Brakeman, tests, SimpleCov, Packwerk, Prosopite, Semgrep, and similar tools remain the analyzers; the product supplies safe execution, normalization, policy, baselines, reporting, and an agent-readable contract.

The working name is not suitable for a public release. Although the exact RubyGems names checked were unclaimed on the research date, the preferred GitHub organization is already owned, `lineclear.app` is an active software product, other software and logistics products use LineClear/Line Clear, and TMview returns exact registered marks including one in Nice Class 9. These facts do not prove infringement, but they create avoidable legal, discoverability, packaging, and identity risk. The Phase 0 recommendation is to rename before publishing a gem, repository, domain, logo, or documentation site.

The evidence below is separated from product inference and roadmap recommendations. Trademark checks are preliminary knockout research only; they are not legal advice or legal clearance.

## Phase 0 Identity Research

### Verified evidence: package and repository names

| Surface | Evidence as of 2026-08-16 | Signal |
|---------|---------------------------|--------|
| RubyGems exact name `lineclear` | The official RubyGems API returned `404` for [`/api/v1/gems/lineclear.json`](https://rubygems.org/api/v1/gems/lineclear.json), and an exact remote gem search returned no result. | Exact name appears available, but availability is not a reservation or trademark clearance. |
| RubyGems punctuation variants | The official API also returned `404` for [`line-clear`](https://rubygems.org/api/v1/gems/line-clear.json) and [`line_clear`](https://rubygems.org/api/v1/gems/line_clear.json). RubyGems requires a unique published name and recommends checking both RubyGems and GitHub before naming a gem ([RubyGems patterns guide](https://guides.rubygems.org/patterns/)). | All three exact spellings appeared unclaimed. They are separate claimable identifiers, so a launch would still carry typo-squatting and `gem`/`require` ambiguity risk. |
| Ruby naming convention | RubyGems advises lowercase names and describes underscore and dash semantics for multiword gems ([Name your gem](https://guides.rubygems.org/name-your-gem/)). | If the name were retained despite this report, the least surprising interface would be gem/executable/config `lineclear`, Ruby namespace `LineClear`, and `.lineclear.yml`; uppercase package or command names should not be used. |
| GitHub organization | The official API resolves [`github.com/lineclear`](https://github.com/lineclear) as an organization created in 2015. Its public repository list was empty at access time. | The preferred organization identity is unavailable even though it has no public repositories. An empty organization is not evidence of abandonment or availability. |
| GitHub canonical repository path | [`github.com/lineclear/lineclear`](https://github.com/lineclear/lineclear) returned `404`, while GitHub repository search returned several exact-name repositories under other owners. | Repository names are owner-scoped, so another owner could publish `lineclear`; however, the clean `lineclear/lineclear` identity cannot be assumed and search results would be noisy. |

### Verified evidence: trademark and common-law collision signals

| Source | Exact-name result | Limitations |
|--------|-------------------|-------------|
| USPTO Trademark Search | An exact all-status wordmark search for `LINECLEAR` at the official [USPTO Trademark Search](https://tmsearch.uspto.gov/) returned no live or dead records in the research session. | Search-result URLs are session-bound. An exact-text result does not cover confusingly similar marks, related goods/services, state registrations, or unregistered use. The USPTO says comprehensive clearance requires multiple sources and similarity analysis ([Federal trademark searching](https://www.uspto.gov/trademarks/search/federal-trademark-searching)). |
| TMview | The official-office aggregator returned three exact `LINECLEAR` records: a Korean Class 9 registration, an ended Korean Classes 3/35 record, and a Malaysian Class 39 registration associated with logistics. See the reproducible [TMview exact-name query](https://www.tmdn.org/tmview/#/tmview/results?page=1&pageSize=30&criteria=I&basicSearch=LINECLEAR). | TMview warns that its data is not an official register and has no legal effect. Displayed registration statuses and expiry dates require verification with each national office before relying on them. |
| WIPO Global Brand Database | The official [Global Brand Database](https://www.wipo.int/en/web/global-brand-database/index) was consulted, but its interactive search presented an anti-bot challenge that prevented a reproducible exact-result record. | WIPO itself recommends also searching national and regional registers. No conclusion should be drawn from the blocked query. |
| Brazil INPI | The official [INPI trademark search](https://servicos.busca.inpi.gov.br/marcas) was in maintenance during research. The service entry point is the [INPI trademarks portal](https://www.gov.br/inpi/pt-br/servicos/marcas). | Brazil remains an unresolved jurisdiction and must be checked before adoption of any final name. |
| EU and UK | TMview's exact query did not show an EU or UK exact `LINECLEAR` result. The official [EUIPO search portal](https://www.euipo.europa.eu/en/search) was also reviewed; direct UK search was impeded by an anti-bot challenge. | Absence from this preliminary exact query is not clearance. Similarity and goods/services searches remain necessary. |

### Verified evidence: general web and product collisions

| Use | Evidence | Naming risk |
|-----|----------|-------------|
| Active business software | [`lineclear.app`](https://lineclear.app/) markets a web software application named Lineclear that transforms ERP/open-purchase-order exports into delivery reports. | Direct software-name collision, strong search and common-law risk even though the use case differs. |
| Mobile assessment software | Agile Cookies markets a mobile application named [LineClear](https://www.agilecookies.com/apps/lineclear/) for UK train-driver assessment preparation. | Another exact software/product name and app-store search collision. |
| Logistics software | Apple's listing for [Line Clear OMS](https://apps.apple.com/us/app/line-clear-oms/id1555210200) showed a current logistics order-management app version released in December 2025. | Exact two-word variant in active software. |
| Logistics company and integrations | Anchanto documents a [Line Clear Express integration](https://anchanto.com/integration/line-clear/) for warehouse, order, and parcel operations and describes the Malaysian business as established in 2015. | Active commercial use aligns with the exact Malaysian Class 39 TMview record. |
| Historical UK company | UK Companies House records [LINECLEAR LIMITED](https://find-and-update.company-information.service.gov.uk/company/06774732/filing-history), dissolved in 2015. | Low current product risk by itself, but further evidence that the term has prior commercial use. |
| Regulated manufacturing term | FDA enforcement material uses “line clearance” as a drug-packaging control ([FDA warning letter](https://www.fda.gov/inspections-compliance-enforcement-and-criminal-investigations/warning-letters/coupler-enterprises-607662-09152020)); WHO GMP guidance likewise discusses line clearance to prevent mix-ups ([WHO GMP guidance](https://cdn.who.int/media/docs/default-source/medicines/norms-and-standards/guidelines/production/trs1044-annex7-good-manufacturing-practices-for-investigational-products.pdf?sfvrsn=66b15a93_1)). | The ordinary industry phrase adds non-software search noise and weakens distinctiveness. |

### Inference: naming risk

The exact RubyGems availability is the only strong positive signal. It is outweighed by five independent negatives: the preferred GitHub organization is already owned; an exact-name `.app` software product is active; multiple other apps and a logistics company use the same or spaced form; an exact Class 9 record appears in TMview; and “line clearance” is a generic regulated-manufacturing term. The collision set spans software and non-software industries, making search results noisy and making a clean common-law narrative harder even if individual trademark classes ultimately do not conflict.

The main risk is not merely whether a registration could technically be obtained. It is the cumulative cost of disclaimers, package/repository inconsistency, mistaken identity, search competition, and a later rename after users have installed a gem or linked to documentation.

### Recommendation: decision matrix

Scores use 1 = poor and 5 = strong. “Clearance confidence” evaluates the present evidence, not a legal conclusion.

| Option | Registry coherence | Discoverability | Clearance confidence | Switching cost now | Long-term fit | Decision |
|--------|-------------------:|----------------:|---------------------:|-------------------:|--------------:|----------|
| Retain `LineClear` for public release | 1 | 1 | 1 | 5 | 2 | **Reject.** A free RubyGems name does not compensate for the occupied GitHub organization, active exact-name software, and trademark signals. |
| Retain provisionally with conditions | 2 | 2 | 2 | 4 | 2 | **Allow only as an unpublished internal codename.** Freeze public packaging and branding while a replacement is selected. |
| Rename during Phase 0 | 5 | 5 | 4 | 4 | 5 | **Recommend.** Identity change is cheapest before Phase 1 creates public artifacts or compatibility obligations. |

**Phase 0 exit criterion:** choose a more distinctive name, then repeat exact, fuzzy, phonetic, common-law, domain, RubyGems, GitHub, and relevant trademark-register checks. Confirm Brazil INPI and any launch jurisdictions that could not be searched here. Obtain qualified trademark counsel before material commercial use. Do not reserve a public gem, publish a public repository, commission a logo, or build search equity under `LineClear` while the decision is open.

The positioning line “Evidence before merge” can remain a working descriptor, subject to its own search. It should not be treated as legally cleared merely because the product name changes.

## Competitive Landscape

### Verified evidence: broad quality and security platforms

| Product | Current verified scope | What it establishes as table stakes | Boundary for this project |
|---------|------------------------|------------------------------------|---------------------------|
| Qlty / Code Climate Quality | Qlty describes itself as a cloud code-health platform with local CLI analysis, new-issue workflows, and quality gates ([What is Qlty](https://docs.qlty.sh/what-is-qlty), [CLI quickstart](https://docs.qlty.sh/cli/quickstart)). Its plugin catalog includes RuboCop, Brakeman, Reek, Standard Ruby, and Semgrep ([plugins](https://docs.qlty.sh/plugins)); coverage and configurable pull-request gates are cloud features ([coverage](https://docs.qlty.sh/coverage)). Code Climate states that Quality is being replaced by Qlty Cloud ([open-source program](https://docs.codeclimate.com/docs/open-source-free)); migration documentation says the old Code Climate API was disabled on 2025-07-18 ([migration guide](https://docs.qlty.sh/migration/guide)). | Changed-code focus, analyzer aggregation, consistent CLI output, coverage visibility, and new-issue gates. | This is the nearest conceptual competitor. The project must win on fully local/offline operation, Rails execution evidence, a versioned analyzer-independent contract, and deterministic policy rather than breadth of plugins or a hosted dashboard. |
| SonarQube | SonarQube defines quality gates that can fail analysis and block merges based on new issues, security, coverage, and duplication ([quality gates](https://docs.sonarsource.com/sonarqube/latest/user-guide/quality-gates), [new code](https://docs.sonarsource.com/sonarqube-server/user-guide/about-new-code)). It analyzes Ruby and imports externally generated coverage such as SimpleCov JSON ([Ruby](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/languages/ruby), [coverage parameters](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/test-coverage/test-coverage-parameters)). | Explicit gate conditions, new-code policy, merge status, and coverage ingestion. | Do not build a smaller Sonar server. Keep the core process-local, repository-owned, explainable, and Rails-specific. |
| Codacy | Codacy documents Git-integrated pull-request analysis, diff coverage, and gates for new issues, new security issues, complexity, duplication, and coverage variation ([quality gates](https://docs.codacy.com/repositories-configure/adjusting-quality-gates/), [pull requests](https://docs.codacy.com/repositories/pull-requests/)). | Pull-request feedback and visible reasons for gate failure. | Treat hosted repository management and dashboarding as anti-features. The value is a portable local decision that CI may publish. |
| Semgrep | Semgrep supplies SAST, software-composition analysis, and secrets scanning, supports Ruby, and can run locally or in CI ([documentation](https://docs.semgrep.dev/), [Semgrep Code](https://docs.semgrep.dev/semgrep-code/overview)). Semgrep Supply Chain supports policy actions including comment, block, and fail ([SCA overview](https://docs.semgrep.dev/semgrep-supply-chain/overview)). | Security findings, policy severity, local/CI execution, and machine-readable evidence. | Integrate it later as a security evidence source; do not reimplement its rule engine or claim equivalent semantic analysis. |
| GitHub code scanning | GitHub code scanning supports CodeQL and third-party SARIF uploads, runs on pull requests and pushes, and accepts categorized SARIF results ([setup types](https://docs.github.com/en/code-security/concepts/code-scanning/setup-types), [workflow options](https://docs.github.com/en/code-security/reference/code-scanning/workflow-configuration-options)). CodeQL is primarily a security scanner ([CodeQL code scanning](https://docs.github.com/en/code-security/concepts/code-scanning/codeql/code-scanning)). | SARIF export, source locations, stable identifiers, and PR annotations. | GitHub is a downstream reporter, not the source of truth. Core decisions must work without GitHub and without network access. |
| MegaLinter | MegaLinter is an actively maintained, AGPL-licensed meta-linter for many languages and CI environments, with numerous output formats ([repository](https://github.com/oxsecurity/megalinter), [releases](https://github.com/oxsecurity/megalinter/releases)). | Easy multi-tool execution and consolidated output. | Do not compete on tool count. Distinguish with evidence provenance, test/runtime normalization, Rails context, baselines, policy, and agent contracts. |

### Verified evidence: review orchestration and Rails specialists

| Tool | Current verified scope | Relationship to the product |
|------|------------------------|-----------------------------|
| reviewdog | Converts analyzer output formats including errorformat, RDJSON, Checkstyle, and SARIF into local or pull-request feedback, with diff filters and fail levels ([repository](https://github.com/reviewdog/reviewdog)). | A reporting/orchestration peer and possible inspiration for format boundaries; not a Rails evidence model or cross-analyzer policy engine. |
| pronto | A Ruby framework for quickly reviewing changed lines with analyzer runners ([repository](https://github.com/prontolabs/pronto)). | Validates changed-code analysis as expected behavior. Avoid reproducing its runner ecosystem; normalize selected evidence instead. |
| Danger | Runs team review conventions in CI and publishes feedback to code-review systems ([What does Danger do?](https://danger.systems/guides/what_does_danger_do/)). | A programmable PR feedback layer. The project should produce deterministic evidence that Danger could consume, not require a repository-host API. |
| Packwerk | Shopify's Rails tool enforces package boundaries and helps modularize applications while documenting known limitations ([repository](https://github.com/Shopify/packwerk)). | A later Rails-context analyzer. Preserve Packwerk's native meaning and normalize its evidence; do not invent another dependency-boundary checker. |
| Prosopite | A Rails library that detects N+1 queries through ActiveSupport SQL instrumentation and can raise during tests ([repository](https://github.com/charkost/prosopite)). | A valuable runtime-evidence source after the static/test contract is stable. Its lifecycle and instrumentation make it inappropriate for the Phase 1 adapter. |
| Brakeman | A Rails static security scanner with automation-friendly exit behavior and stable JSON output ([quickstart](https://brakemanscanner.org/docs/quickstart/), [automation](https://brakemanscanner.org/docs/automation/)). | A high-value early analyzer integration. Brakeman remains the security authority; the product adds common findings, baselines, and policy. |

### Inference: defensible product distinction

There is no credible advantage in “runs many linters”: Qlty and MegaLinter already do that, while SonarQube and Codacy already provide mature hosted gates. There is also no advantage in “posts comments”: reviewdog, Pronto, Danger, and GitHub already cover that workflow. Rails-specific analyzers already own their technical domains.

The credible gap is the intersection these tools leave fragmented:

- one local, versioned evidence contract across tests, static analysis, security, coverage, architecture, and selected runtime signals;
- Rails-aware context without replacing specialist analyzers;
- deterministic policy and baseline comparison that produce the same decision locally and in CI;
- first-class analyzer failures, timeouts, unsupported states, and provenance, instead of silently treating missing evidence as success;
- agent-readable outputs and repair packets derived from deterministic evidence, with optional AI explicitly outside the gate.

## Table Stakes

Missing any of these capabilities by the relevant roadmap phase makes the product feel unreliable or incomplete.

| Feature | Why expected | Complexity | Target phase | Notes |
|---------|--------------|------------|--------------|-------|
| Local deterministic CLI | Developers must reproduce the CI result without an account, network connection, or AI provider. | Medium | 1 | One primary command, stable exit semantics, and no hidden network calls. |
| Strict versioned configuration | Repository-owned policy must fail clearly on invalid or unknown keys rather than silently drift. | Medium | 1 | Include schema versioning and actionable validation errors from the start. |
| Canonical `Finding` model | Findings from different analyzers need comparable identity, severity, location, message, evidence, and origin. | High | 1 | Version the schema before ecosystem growth creates compatibility debt. |
| `AnalyzerResult` and `GateResult` contracts | Tool execution state and final policy decision must remain distinct. | Medium | 1 | Represent unavailable, unsupported, timeout, parser failure, and internal error explicitly. |
| Safe subprocess execution | External tools are unavoidable and can hang, flood output, or fail unexpectedly. | High | 1 | Use argument arrays, timeouts, bounded capture, cancellation, and sanitized diagnostics. Never build shell command strings from configuration. |
| Console and JSON reporters | Humans and automation require separate stable interfaces. | Medium | 1 | Machine output must be versioned and free from logs; diagnostics go to stderr. |
| One dependable real analyzer adapter | A framework without end-to-end evidence is only a schema exercise. | Medium | 1 | Use a narrow RuboCop JSON adapter to validate the contract; expand analyzer coverage later. |
| Test result normalization | Rails users expect RSpec and Minitest failures to participate in the same gate. | High | 2 | Preserve native failure detail and command provenance; do not reduce tests to a count. |
| Coverage ingestion and changed-line coverage | Mature quality tools make coverage-on-new-code an expected signal. | High | 2 | Consume SimpleCov output; do not create a coverage engine. Define missing/stale coverage behavior explicitly. |
| Stable fingerprints and baseline comparison | Existing Rails applications cannot adopt an all-debt-at-once gate. | High | 3 | Distinguish introduced, existing, resolved, moved, and materially changed findings without depending only on line numbers. |
| Explainable policy and waivers | Every failure or exception needs a repository-visible reason. | High | 3 | Waivers require scope, owner, reason, and expiry. Avoid opaque aggregate quality scores. |
| Git-diff awareness | Fast local and pull-request feedback depends on a shared definition of changed code. | High | 4 | Handle renames, deletions, merge bases, shallow clones, and missing base refs explicitly. |
| CI and SARIF integration | Users expect annotations and merge-blocking status in existing platforms. | Medium | 4 | Ship a GitHub Actions reference workflow and SARIF export, while keeping the core provider-neutral. |
| Rails-aware evidence context | Generic file/line output is insufficient for framework conventions and architecture. | High | 5 | Enrich rather than override analyzer evidence; include provenance for inferred Rails context. |
| Documentation and diagnostic command | Installation problems, missing analyzers, and configuration errors must be self-service. | Medium | 1–4 | A `doctor` capability can grow incrementally; never auto-install project dependencies. |

## Differentiators

These capabilities make the product meaningfully different rather than merely compatible with category expectations.

| Feature | Value proposition | Complexity | Earliest phase | Notes |
|---------|-------------------|------------|----------------|-------|
| Evidence-before-opinion invariant | A deterministic result remains authoritative; AI cannot convert a known failure into a pass. | Medium | 1 | Encode this boundary in the data model and documentation before optional AI exists. |
| Fully OSS, local-first core | Teams can audit, reproduce, and run the complete gate without SaaS, accounts, telemetry, or code upload. | Medium | 1 | CI is another local invocation, not a special hosted control plane. |
| Analyzer-independent versioned evidence | Automation and agents depend on one stable contract rather than parsing every tool's evolving output. | High | 1 | Retain raw/source provenance so normalization never erases the authority of the original analyzer. |
| Failure-as-evidence execution model | Missing executables, timeouts, malformed output, and unsupported project states cannot masquerade as clean code. | High | 1 | Policy decides the impact, but reporters must never hide the state. |
| Cross-tool no-new-debt baseline | One baseline can gate newly introduced problems across tests, lint, security, coverage, architecture, and runtime evidence. | High | 3 | Robust fingerprints and schema migration are prerequisites. |
| Explicit expiring waivers | Exceptions remain reviewable debt rather than permanent suppression scattered through tool configs. | Medium | 3 | Preserve analyzer-native suppressions, but expose unified project-policy exceptions. |
| Rails context graph for findings | Routes, models, jobs, boundaries, migrations, and framework conventions can make generic findings more actionable. | High | 5 | Start with narrowly verifiable context. Do not promise whole-program semantics. |
| Versioned agent repair packet | Coding agents receive compact evidence, constraints, provenance, and verification commands without scraping terminal prose. | High | 7 | Must be derived from the stable JSON contract, not an alternate AI-specific truth. |
| Privacy-controlled optional AI | AI can summarize, cluster, and suggest repairs while remaining disabled by default and outside deterministic policy. | High | 6 | Require explicit provider, data scope, redaction behavior, and failure isolation. |
| Provider-neutral automation | The same result can drive local terminals, generic CI, GitHub SARIF, future MCP, or other agents. | Medium | 4–8 | Avoid making GitHub APIs part of the core domain model. |

## Anti-Features

These are explicit non-goals, not missing roadmap items.

| Anti-feature | Why avoid | What to do instead |
|--------------|-----------|--------------------|
| Hosted dashboard, accounts, billing, or repository database | Recreates Qlty/SonarQube/Codacy and breaks the local-first promise. | Store configuration, policy, baselines, and waivers in the repository; emit portable reports. |
| A new linter, security scanner, coverage engine, or test runner | Mature Rails tools already own these domains and evolve faster. | Execute supported tools safely and normalize their evidence without changing its meaning. |
| Mandatory AI or AI-authored gate results | Makes results non-reproducible and creates cost, privacy, and availability dependencies. | Keep AI optional, advisory, and incapable of overriding deterministic failures. |
| Autonomous code editing in the verification core | Blurs evidence and mutation, increasing trust and safety risk. | Produce bounded repair packets; let an explicitly invoked external agent own edits. |
| Broad plugin marketplace at launch | Creates maintenance, trust, versioning, and support burden before the core contract is proven. | Ship a small curated Rails adapter set with documented compatibility. |
| Universal-language quality platform | Competes head-on with mature broad platforms and dilutes Rails expertise. | Optimize semantics, defaults, documentation, and context for Rails. |
| Proprietary universal quality score | Hides policy tradeoffs and creates an arbitrary metric users cannot reproduce. | Report explicit evidence, thresholds, statuses, and the exact reasons for the gate decision. |
| Semantic whole-codebase graph in early phases | Expensive, fragile, and unnecessary for initial deterministic value. | Add narrow Rails context only when it improves a specific verified finding. |
| Automatic installation or mutation of project dependencies | Can change application behavior and violates verification-only expectations. | Detect missing/incompatible tools and provide exact manual remediation. |
| Telemetry, hidden network access, or source upload | Violates privacy and offline reproducibility. | Default to no network; require an explicit opt-in for later AI providers or publishing integrations. |
| Line-number-only fingerprints | Produces baseline churn whenever code moves. | Combine analyzer/rule identity, normalized message/evidence, and structural file context. |
| Privileged fork workflows such as unguarded `pull_request_target` | Can expose repository secrets to untrusted changes. | Document least-privilege workflows and treat SARIF/status publication as a separate boundary. |
| A large command/config surface | Raises adoption cost and freezes speculative abstractions. | Begin with one command and one schema; add switches only for demonstrated workflows. |
| Custom GitHub App or MCP server before the core stabilizes | Couples product identity to integration surfaces before output contracts are trustworthy. | Use ordinary CI/SARIF first; add MCP only after agent packets and JSON schemas are stable. |

## Feature Dependencies

```text
Phase 0 name clearance
  -> public gem/repository identity
  -> all compatibility-bearing releases

Versioned config + RunContext + safe runner
  -> one real adapter
  -> AnalyzerResult + canonical Finding
  -> console/JSON reporters
  -> deterministic GateResult

RSpec/Minitest + SimpleCov + Git diff
  -> changed-line coverage and changed-code evidence

Stable fingerprint
  -> baseline comparison
  -> no-new-debt policy
  -> scoped, expiring waivers

Stable JSON + policy
  -> CI/SARIF publication
  -> repair packet
  -> MCP/agent interoperability

Rails-aware context
  -> richer deterministic findings
  -> bounded AI explanation and repair context

Optional AI advice -X-> deterministic GateResult
```

The broken arrow is intentional: AI output must not become an input capable of weakening the deterministic gate.

## MVP and Nine-Phase Scope Recommendation

### Phase 0: identity and legal foundation

Rename before public release. A replacement-name shortlist should be tested against package registries, GitHub organizations/repositories, domains, exact and similar web uses, and relevant official trademark sources. Document the final spelling, lowercase package/executable/config conventions, Ruby constant, repository organization, and schema namespace as one decision. This phase blocks publication because renaming after Phase 1 creates executable, config, JSON-schema, and gem compatibility debt.

### Phase 1: minimum useful deterministic vertical slice

Build only enough to prove that trusted evidence can travel from a real Rails analyzer to a stable local decision:

1. One primary `check` command under the cleared replacement identity.
2. A versioned configuration file with strict validation and unknown-key errors.
3. Versioned `RunContext`, `Finding`, `AnalyzerResult`, and `GateResult` schemas.
4. A safe subprocess runner with argument arrays, timeouts, bounded output, cancellation, and explicit execution states.
5. One narrow RuboCop JSON adapter as the first real evidence source.
6. Human console output and clean, versioned JSON output with stdout/stderr separation.
7. Stable documented exit codes and golden/contract tests proving deterministic output.

RuboCop is appropriate for the vertical slice because it is common in Rails projects and provides structured evidence without requiring application boot or runtime instrumentation. Phase 1 should not attempt adapter breadth, baselines, diff logic, GitHub integration, or AI.

### Deferred implementation phases 2–9

| Phase | Add | Defer beyond this phase |
|-------|-----|-------------------------|
| 2 — Core Rails evidence | RSpec and Minitest normalization, RuboCop hardening, Brakeman, SimpleCov ingestion, and a precisely defined changed-coverage calculation. | Runtime instrumentation, broad plugin discovery, or hosted reporting. |
| 3 — Baselines and policy | Stable fingerprints, introduced/existing/resolved classification, repository-owned policies, and scoped expiring waivers. | Opaque quality scoring or centrally hosted policy. |
| 4 — Change and CI surfaces | Robust Git diff semantics, SARIF export, provider-neutral CI examples, and a least-privilege GitHub Actions workflow. | Custom GitHub App, comment bot, or cloud control plane. |
| 5 — Rails context | Narrow Rails-aware enrichment and selected Packwerk/Prosopite-style evidence where lifecycle behavior is testable. | A speculative semantic graph or replacement for specialist tools. |
| 6 — Optional AI | Privacy-explicit summarization, clustering, and repair suggestions derived from deterministic evidence. | Mandatory provider, hidden uploads, or AI control of pass/fail. |
| 7 — Agent repair loop | Versioned repair packets, verification commands, bounded retry state, and audit-friendly handoff to external agents. | Unprompted autonomous mutation inside the verifier. |
| 8 — MCP interoperability | Read-focused access to runs, findings, policies, and repair packets after the schemas are stable. | MCP as the only automation interface or an alternate source of truth. |
| 9 — Hardening and 1.0 | Schema/CLI compatibility policy, performance, cancellation, cross-platform behavior, security review, migration tooling, and release documentation. | New product categories that would delay contract stability. |

### MVP acceptance test

Phase 1 is a credible MVP when a developer can clone a representative Rails repository, install the cleared-name gem, run one command entirely offline, receive the same structured RuboCop-derived findings and gate status on repeated runs, distinguish analyzer failure from clean results, and consume either human output or versioned JSON without parsing logs. It is not necessary for the MVP to support every Rails analyzer or pull-request platform.

## Confidence Assessment

| Area | Confidence | Reason |
|------|------------|--------|
| RubyGems and GitHub name signals | HIGH | Direct official APIs and registry/organization pages were queried on the research date. Availability can still change after the query. |
| Trademark/legal risk | MEDIUM | USPTO and TMview produced useful exact-name evidence, but this was not a similarity search, WIPO was blocked, INPI was in maintenance, and national-office/legal review remains outstanding. |
| General product collisions | HIGH | Multiple current first-party product, app-store, integration, and government pages document active or historical uses. |
| Competitive capabilities | HIGH | Claims are limited to current official documentation and primary project repositories. |
| Feature and roadmap recommendations | MEDIUM | The recommendations are reasoned inferences from verified competitors and the supplied product constraints; adoption evidence will still be needed during implementation. |

## Sources

All sources below were accessed on **2026-08-16**.

### Naming, registries, and trademark guidance

- [RubyGems API: `lineclear`](https://rubygems.org/api/v1/gems/lineclear.json)
- [RubyGems API: `line-clear`](https://rubygems.org/api/v1/gems/line-clear.json)
- [RubyGems API: `line_clear`](https://rubygems.org/api/v1/gems/line_clear.json)
- [RubyGems Guides: Patterns](https://guides.rubygems.org/patterns/)
- [RubyGems Guides: Name your gem](https://guides.rubygems.org/name-your-gem/)
- [GitHub organization: lineclear](https://github.com/lineclear)
- [GitHub API: organization record](https://api.github.com/orgs/lineclear)
- [GitHub API: exact-name repository search](https://api.github.com/search/repositories?q=lineclear+in:name&per_page=100)
- [USPTO Trademark Search](https://tmsearch.uspto.gov/)
- [USPTO: Federal trademark searching](https://www.uspto.gov/trademarks/search/federal-trademark-searching)
- [TMview exact `LINECLEAR` query](https://www.tmdn.org/tmview/#/tmview/results?page=1&pageSize=30&criteria=I&basicSearch=LINECLEAR)
- [EUIPO search portal](https://www.euipo.europa.eu/en/search)
- [WIPO Global Brand Database](https://www.wipo.int/en/web/global-brand-database/index)
- [Brazil INPI trademarks portal](https://www.gov.br/inpi/pt-br/servicos/marcas)
- [Brazil INPI trademark search](https://servicos.busca.inpi.gov.br/marcas)

### General web and non-software collisions

- [Lineclear ERP reporting application](https://lineclear.app/)
- [Agile Cookies: LineClear](https://www.agilecookies.com/apps/lineclear/)
- [Apple App Store: Line Clear OMS](https://apps.apple.com/us/app/line-clear-oms/id1555210200)
- [Anchanto: Line Clear integration](https://anchanto.com/integration/line-clear/)
- [UK Companies House: LINECLEAR LIMITED](https://find-and-update.company-information.service.gov.uk/company/06774732/filing-history)
- [FDA warning letter using the regulated “line clearance” term](https://www.fda.gov/inspections-compliance-enforcement-and-criminal-investigations/warning-letters/coupler-enterprises-607662-09152020)
- [WHO GMP guidance using the “line clearance” term](https://cdn.who.int/media/docs/default-source/medicines/norms-and-standards/guidelines/production/trs1044-annex7-good-manufacturing-practices-for-investigational-products.pdf?sfvrsn=66b15a93_1)

### Competitive products and specialist tools

- [Qlty: What is Qlty?](https://docs.qlty.sh/what-is-qlty)
- [Qlty CLI quickstart](https://docs.qlty.sh/cli/quickstart)
- [Qlty plugins](https://docs.qlty.sh/plugins)
- [Qlty coverage](https://docs.qlty.sh/coverage)
- [Qlty migration overview](https://docs.qlty.sh/migration/overview)
- [Qlty migration guide](https://docs.qlty.sh/migration/guide)
- [Code Climate open-source program and Qlty transition](https://docs.codeclimate.com/docs/open-source-free)
- [SonarQube quality gates](https://docs.sonarsource.com/sonarqube/latest/user-guide/quality-gates)
- [SonarQube new-code model](https://docs.sonarsource.com/sonarqube-server/user-guide/about-new-code)
- [SonarQube Ruby analysis](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/languages/ruby)
- [SonarQube coverage parameters](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/test-coverage/test-coverage-parameters)
- [Codacy quality gates](https://docs.codacy.com/repositories-configure/adjusting-quality-gates/)
- [Codacy pull requests](https://docs.codacy.com/repositories/pull-requests/)
- [Semgrep documentation](https://docs.semgrep.dev/)
- [Semgrep Code overview](https://docs.semgrep.dev/semgrep-code/overview)
- [Semgrep Supply Chain overview](https://docs.semgrep.dev/semgrep-supply-chain/overview)
- [GitHub code-scanning setup types](https://docs.github.com/en/code-security/concepts/code-scanning/setup-types)
- [GitHub code-scanning workflow options](https://docs.github.com/en/code-security/reference/code-scanning/workflow-configuration-options)
- [GitHub CodeQL code scanning](https://docs.github.com/en/code-security/concepts/code-scanning/codeql/code-scanning)
- [MegaLinter repository](https://github.com/oxsecurity/megalinter)
- [MegaLinter releases](https://github.com/oxsecurity/megalinter/releases)
- [reviewdog repository](https://github.com/reviewdog/reviewdog)
- [Pronto repository](https://github.com/prontolabs/pronto)
- [Danger: What does Danger do?](https://danger.systems/guides/what_does_danger_do/)
- [Packwerk repository](https://github.com/Shopify/packwerk)
- [Prosopite repository](https://github.com/charkost/prosopite)
- [Brakeman quickstart](https://brakemanscanner.org/docs/quickstart/)
- [Brakeman automation](https://brakemanscanner.org/docs/automation/)
