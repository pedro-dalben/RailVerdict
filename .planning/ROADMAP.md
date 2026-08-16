# Roadmap: RailVerdict

## Overview

RailVerdict progresses through the supplied horizontal Phase 0–9 sequence: establish the identity and trust contracts first, prove a deterministic local core, broaden objective evidence, add stable debt policy, activate trustworthy Git and pull-request scope, enrich findings with bounded Rails context, and only then add optional AI, repair packets, MCP, and the 1.0 release guarantees. Each v1 requirement belongs to exactly one phase, and later adapters consume earlier contracts without creating another source of gate authority.

## Phases

**Phase Numbering:**

- Integer phases 0 through 9 are planned milestone work.
- Decimal phases are reserved for urgent insertions and execute between their surrounding integers.

- [x] **Phase 0: Product, Naming and Legal Foundation** - Ratify RailVerdict's documentation, identity, legal, architecture, security, and contract foundation before production core implementation.
- [ ] **Phase 1: Trustworthy Core** - Deliver one deterministic, offline, fail-closed verification path through the CLI.
- [ ] **Phase 2: Evidence Ecosystem** - Normalize multiple test, lint, coverage, and dependency evidence sources behind hardened adapter contracts.
- [ ] **Phase 3: Fingerprints, Baselines and Policies** - Let legacy projects adopt stable no-new-debt gates with explicit waivers.
- [ ] **Phase 4: Git Diff and Pull Request Readiness** - Make changed-scope verification and GitHub Actions consume trustworthy local Git facts.
- [ ] **Phase 5: Rails-Aware Intelligence** - Add bounded, provenance-backed Rails context without building a generalized code graph.
- [ ] **Phase 6: Optional AI Intelligence** - Add opt-in, privacy-preserving advisory analysis that cannot change the deterministic gate.
- [ ] **Phase 7: Agent Repair Workflow** - Give external coding agents a deterministic machine contract for repairing and verifying failures.
- [ ] **Phase 8: MCP** - Expose stable application services through a thin read-only MCP adapter.
- [ ] **Phase 9: 1.0 Hardening** - Prove compatibility, security, provenance, documentation, and build-once publication guarantees for 1.0.

## Phase Details

### Phase 0: Product, Naming and Legal Foundation

**Goal**: Maintainers can make implementation decisions from an internally consistent, research-backed RailVerdict foundation without adding production core code.
**Depends on**: Nothing (first phase)
**Requirements**: FND-01, FND-02, FND-03, FND-04, FND-05, FND-06, FND-07, FND-08, FND-09, FND-10, FND-11, FND-12, FND-13, FND-14
**Success Criteria** (what must be TRUE):

  1. Maintainers can review dated package, repository, domain, product-collision, and preliminary trademark evidence for RailVerdict and see that publication stays blocked until the documented launch-jurisdiction and qualified trademark reviews are cleared.
  2. Contributors can use one identity mapping for RailVerdict, `rail_verdict`, `RailVerdict`, `railverdict`, `.railverdict.yml`, repository identity, and schema namespace, with Apache-2.0 rights separated from trademark rules.
  3. Maintainers can inspect a dated analyzer registry and support proposal that document licenses, commercial-use considerations, installation, output, bundling, and version policy; Brakeman is absent from the committed adapter shortlist until a written product/legal decision approves it.
  4. Contributors can understand the deterministic-first product, four one-way layers, fifteen foundation ADRs, threat model, synthetic-only information firewall, English-only policy, and minimal one-gem structure from the repository documents.
  5. Adapter and automation authors can validate the draft Finding and configuration schemas, understand unknown-field behavior and the proposed CLI/stdout/stderr/exit contracts, and trace all 85 v1 requirements through this Phase 0–9 roadmap.

**Exit gate**: Phase 0 may complete its documented foundation when the identity decision, the accurately unresolved external gate, every foundation artifact, and the no-production boundary are mutually consistent. Publication, package or repository reservation, domain action, and public branding remain blocked until documented launch-jurisdiction evidence and qualified trademark review explicitly clear them.
**Non-goals**: Production gem behavior, analyzer execution, baseline implementation, AI, GitHub integration, MCP, or publication.
**Plans**: 7/7 plans executed

- [x] 00-01-PLAN.md
- [x] 00-02-PLAN.md
- [x] 00-03-PLAN.md
- [x] 00-04-PLAN.md
- [x] 00-05-PLAN.md
- [x] 00-06-PLAN.md
- [x] 00-07-PLAN.md

**Wave 1** *(parallel, non-overlapping foundation artifacts)*

- [x] `00-01-PLAN.md` — Identity evidence, Apache-2.0, NOTICE, and trademark boundary
- [x] `00-02-PLAN.md` — README, product definition, philosophy, competitive position, and architecture
- [x] `00-03-PLAN.md` — Analyzer license registry and Ruby/Rails support proposal
- [x] `00-04-PLAN.md` — Finding/configuration schemas, synthetic examples, and CLI contract
- [x] `00-05-PLAN.md` — Threat model and information firewall
- [x] `00-06-PLAN.md` — Fifteen foundation ADRs

**Wave 2** *(blocked on all Wave 1 plans)*

- [x] `00-07-PLAN.md` — Public roadmap, planning-state convergence, and offline foundation validation

### Phase 1: Trustworthy Core

**Goal**: Developers can run one offline command path that turns safely collected RuboCop evidence into a deterministic, fail-closed gate and stable human or machine output.
**Depends on**: Phase 0
**Requirements**: CORE-01, CORE-02, CORE-03, CORE-04, CORE-05, CORE-06, CORE-07, CORE-08, CORE-09, CORE-10, CORE-11, CORE-12, CORE-13, CORE-14
**Success Criteria** (what must be TRUE):

   1. A developer can run `railverdict init`, `doctor`, `check`, and `findings`, and `check` works offline with AI, accounts, telemetry, and hosted services absent. The Phase 1 CLI exposes `baseline create` as an explicit deferred boundary; Phase 3 owns its actual baseline write.
  2. A developer receives useful path-specific errors for unknown configuration and can inspect the effective strict configuration plus the immutable repository, revision, Rails, analyzer, tool-version, and deterministic inputs captured in `RunContext`.
  3. External commands run only through executable-plus-argv execution with a verified directory, bounded concurrent output, monotonic timeout, minimal environment, process-group cleanup, reaping, and temporary-file cleanup.
  4. RuboCop evidence is version-checked and normalized into provenance-bearing canonical findings, while every unavailable, unsupported, timed-out, signaled, failed, truncated, parse-failed, or malformed required run remains incomplete and cannot yield a trustworthy PASS.
  5. Equivalent inputs yield equivalent immutable `GateResult` content, deterministic console output, exactly one versioned JSON document on stdout in JSON mode, diagnostics on stderr, and stable pass/policy/incomplete/interruption exits.

**Exit gate**: A synthetic public Rails fixture completes the RuboCop vertical path in both console and JSON modes, and negative execution fixtures prove that incomplete required evidence cannot pass.
**Non-goals**: Adapter breadth, baselines, Git changed scope, Rails context enrichment, AI, repair orchestration, or MCP.
**Plans**: 6/6 plans executed

- [x] `01-01-PLAN.md`
- [x] `01-02-PLAN.md`
- [x] `01-03-PLAN.md`
- [x] `01-04-PLAN.md`
- [x] `01-05-PLAN.md`
- [x] `01-06-PLAN.md`

### Phase 2: Evidence Ecosystem

**Goal**: Developers receive normalized, provenance-rich evidence from the committed test, lint, coverage, and dependency adapter set without weakening core failure semantics.
**Depends on**: Phase 1
**Requirements**: EVID-01, EVID-02, EVID-03, EVID-04, EVID-05, EVID-06, EVID-07, EVID-08, EVID-09, EVID-10
**Success Criteria** (what must be TRUE):

  1. Minitest and RSpec users receive normalized suite identity, counts, statuses, duration, seed, assertions where available, and failure locations, while zero-test, filtered, load-error, partial, and unexpected-skip runs remain visible to policy.
  2. RuboCop with optional rubocop-rails executes once per scope with configuration and plugin provenance, and SimpleCov accepts only fresh, complete public coverage JSON rather than HTML or internal caches.
  3. Maintainers can contract-test changed-line coverage calculations against an injected line set, but users cannot enable or be promised a production Git changed-line gate before Phase 4.
  4. bundler-audit reports tool and advisory-database revisions while keeping explicit network refresh separate from offline verification.
  5. Every shipped adapter publishes supported versions, native output, license, installation, cost, and failure behavior and passes unavailable, empty, malformed, unexpected-version, timeout, non-zero, oversized, partial, and invalid-encoding fixtures; Brakeman remains unsupported pending a written license/product decision.

**Exit gate**: Multiple independent evidence sources normalize through the existing contracts, their complete failure corpora pass, and none can turn incomplete evidence into zero findings or a trustworthy PASS.
**Non-goals**: Production `--changed` coverage, Brakeman support before written approval, Undercover or RubyCritic overlap, runtime Rails analyzers, or analyzer-specific policy fields.
**Plans**: TBD

### Phase 3: Fingerprints, Baselines and Policies

**Goal**: Legacy Rails projects can record trusted existing debt and deterministically block newly introduced regressions without silently changing that record.
**Depends on**: Phase 2
**Requirements**: DEBT-01, DEBT-02, DEBT-03, DEBT-04, DEBT-05, DEBT-06, DEBT-07, DEBT-08, DEBT-09, DEBT-10
**Success Criteria** (what must be TRUE):

  1. Maintainers can inspect a versioned canonical fingerprint payload and full SHA-256 identity whose regression vectors cover unrelated edits, line and logical moves, renames, duplicates, copies, collisions, and algorithm migrations.
  2. A developer can atomically create a versioned baseline only from a complete trusted run, and ordinary checks never create or mutate it or store source, secrets, full logs, or AI prompts.
  3. Baseline comparison explains introduced, existing, resolved, changed, moved, suppressed, and waived findings rather than relying on file and line alone.
  4. A project can select advisory, no-new-debt, or strict policy, and the analyzer-independent evaluator maps evidence completeness, severity, category, coverage, and regression facts to the gate.
  5. Exact-fingerprint waivers require owner, reason, creation date, UTC expiration, and optional issue reference; expired, orphaned, malformed, over-broad, or incompatible waiver/baseline data remains visible or requests explicit migration.

**Exit gate**: A synthetic legacy fixture can create a reviewed baseline, retain existing findings, classify a new regression, and fail only according to its selected policy while baseline and waiver compatibility cases remain explicit.
**Non-goals**: AST identity unless regression evidence requires it, wildcard or permanent waivers, automatic baseline updates, GitHub policy, or an opaque quality score.
**Plans**: TBD

### Phase 4: Git Diff and Pull Request Readiness

**Goal**: Developers and pull-request workflows can enforce the same deterministic changed-scope gate from trustworthy local Git facts.
**Depends on**: Phase 3
**Requirements**: GIT-01, GIT-02, GIT-03, GIT-04, GIT-05, GIT-06, GIT-07, GIT-08
**Success Criteria** (what must be TRUE):

  1. A developer can resolve repository root, HEAD, an explicit or configured base, merge base, NUL-safe changed paths and lines, additions, deletions, binaries, conflicts, and renames from local Git.
  2. `railverdict check --changed` reports an incomplete result when the base or required history is untrustworthy and uses the recorded `RunContext` line scope for production changed-code coverage.
  3. A repository can project canonical findings and policy decisions to SARIF, annotations, and summaries without adding GitHub concepts or a second verification engine to the core.
  4. A documented GitHub Actions workflow enforces the local gate with minimum permissions, runs fork code without secrets or publisher/remote-AI credentials, and never executes or trusts fork code, caches, scripts, or artifacts in a privileged workflow without a reviewed safe handoff.

**Exit gate**: A synthetic repository exercises normal, shallow/incomplete, rename, binary, conflict, and unusual-path cases locally, and an unprivileged pull-request workflow enforces the same `GateResult` including production changed-line coverage.
**Non-goals**: Guessing or fetching an undeclared base, treating rename heuristics as finding identity, a custom GitHub App, or privileged execution of untrusted pull-request material.
**Plans**: TBD

### Phase 5: Rails-Aware Intelligence

**Goal**: Consumers can inspect bounded, deterministic Rails context for a finding with explicit confidence and provenance.
**Depends on**: Phase 4
**Requirements**: RAIL-01, RAIL-02, RAIL-03, RAIL-04
**Success Criteria** (what must be TRUE):

  1. A Rails project reports detected Ruby and Rails versions, test framework, database adapter, dependencies, application structure, and selected Git scope through documented conventions.
  2. A finding can identify bounded related tests, routes, models, associations, policies, jobs, services, and schema fragments without scanning or presenting the whole repository.
  3. Every inferred context item carries confidence and provenance, and no runtime integration such as query or migration diagnostics is offered until non-destructive execution, lifecycle isolation, structured evidence, and contract fixtures are proven.

**Exit gate**: Synthetic Rails fixtures produce reproducible bounded context, including uncertainty and absence cases, without changing findings, policy, or gate authority.
**Non-goals**: A full semantic code graph, analyzer replacement, a Rails runtime dependency in the core, or generalized certainty claims.
**Plans**: TBD

### Phase 6: Optional AI Intelligence

**Goal**: Users can opt into bounded AI explanation or investigation without changing deterministic verification or silently transmitting sensitive material.
**Depends on**: Phase 5
**Requirements**: AI-01, AI-02, AI-03, AI-04, AI-05, AI-06, AI-07, AI-08
**Success Criteria** (what must be TRUE):

  1. The same deterministic inputs produce the same gate with AI off, available, unavailable, or returning different advisory content.
  2. Before remote invocation, a user explicitly opts in and can inspect the exact bounded context manifest selected for transmission.
  3. Secret-file exclusions, secret-pattern detection, and redaction run before transmission and fail closed, while repository text, diffs, messages, and model output remain untrusted data rather than instructions.
  4. Provider responses are schema-validated and labeled advisory with provenance and confidence; invalid or unavailable responses degrade cleanly without changing the gate, and request, finding, context, time, and cost budgets stop excess calls before invocation.
  5. Cache identities bind the finding, context, provider, model, prompt, and schema versions without storing raw sensitive context by default, while the initial provider path stays outside the core and preserves a future local-provider boundary.

**Exit gate**: A synthetic finding can be explained through the initial provider path, and tests prove consent, manifest inspection, secret failure, injection isolation, budget limits, cache separation, invalid-response degradation, and gate equivalence.
**Non-goals**: Mandatory or gate-authoritative AI, silent uploads, whole-repository transmission, multiple initial providers, agent tool authority, or autonomous source edits.
**Plans**: TBD

### Phase 7: Agent Repair Workflow

**Goal**: External coding agents can understand a failed gate, make a repair under their existing authority, and verify the result through stable machine contracts.
**Depends on**: Phase 6
**Requirements**: AGNT-01, AGNT-02, AGNT-03, AGNT-04, AGNT-05
**Success Criteria** (what must be TRUE):

  1. A coding agent can identify a failed check and its exit meaning from versioned JSON without parsing ANSI output or prose logs.
  2. A deterministic repair packet provides the finding, policy decision, bounded evidence, relevant diff and Rails context, related tests, and executable-plus-argv verification commands.
  3. Optional AI guidance is visibly separate from deterministic packet evidence and cannot become verification truth.
  4. An external agent can change a synthetic Rails fixture, observe failure, repair it, rerun RailVerdict, and reach PASS without RailVerdict editing source or granting additional permissions.

**Exit gate**: The end-to-end synthetic repair loop succeeds using only versioned machine contracts, and packet fixtures cover boundedness, unavailable context, unsafe command rejection, and deterministic replay.
**Non-goals**: Source rewriting by RailVerdict, permission escalation, an embedded coding agent, or terminal-scraping integrations.
**Plans**: TBD

### Phase 8: MCP

**Goal**: MCP-compatible consumers can query the proven RailVerdict services without gaining a duplicate verification or editing engine.
**Depends on**: Phase 7
**Requirements**: MCP-01, MCP-02, MCP-03
**Success Criteria** (what must be TRUE):

  1. Maintainers can demonstrate that CLI, Finding, GateResult, and repair-packet contracts are stable enough before the MCP transport is enabled.
  2. An MCP client can run the approved read-only capabilities and receive the same versioned checks, findings, policies, and repair packets produced by the underlying application services.
  3. MCP requests cannot invoke separate policy, analyzer execution, or source-editing logic and do not change core gate authority.

**Exit gate**: Contract parity tests compare CLI and MCP results for the same synthetic inputs against the then-current official MCP specification and supported SDK.
**Non-goals**: MCP-only product behavior, code-editing tools, duplicate policy or analyzer engines, or MCP as a core dependency.
**Plans**: TBD

### Phase 9: 1.0 Hardening

**Goal**: Users can install and trust RailVerdict 1.0 with documented compatibility, complete public-safe evidence, and a verifiable build-to-publication chain.
**Depends on**: Phase 8
**Requirements**: REL-01, REL-02, REL-03, REL-04, REL-05, REL-06, REL-07, REL-08, REL-09
**Success Criteria** (what must be TRUE):

  1. Users and adapter authors can rely on documented 1.0 compatibility and migration policies for findings, configuration, results, baselines, waivers, fingerprints, analyzers, reporters, AI providers, repair packets, exits, and stored formats.
  2. The complete unit, contract, integration, CLI, schema, adapter, fingerprint, baseline, policy, security, and AI-boundary suite passes using only synthetic fixtures across every supported Ruby/Rails lane, and the project can dogfood its deterministic gate.
  3. Users can follow executable documentation for philosophy, architecture, configuration, findings, baselines, policies, analyzers, AI/privacy, agents, GitHub Actions, security, and adapter development without needing a paid service, AI credential, account, or network for core verification.
  4. Release verification builds once, tests and installs that exact gem, records its digest and source revision, and publishes the same artifact through protected RubyGems Trusted Publishing with MFA and minimum GitHub permissions.
  5. Tree, history, gem, archives, media metadata, documentation, release notes, and CI artifacts pass private-provenance and English-only gates, and each release publishes SemVer notes, schema/migration changes, checksums/provenance, current third-party license review, and known compatibility boundaries.

**Exit gate**: Every compatibility, supported-lane, security, provenance, language, clean-install, documentation, and artifact-identity gate passes against the release candidate; current identity/legal and third-party license decisions are revalidated immediately before publication.
**Non-goals**: Paid or hosted dependencies, long-lived routine publishing keys, rebuilding after verification, private-derived fixtures, untested compatibility promises, or expanding v1 analyzer scope during release hardening.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. Product, Naming and Legal Foundation | 7/7 | Independently verified | 2026-08-16 |
| 1. Trustworthy Core | 6/6 | Complete | 2026-08-16 |
| 2. Evidence Ecosystem | 0/TBD | Not started | - |
| 3. Fingerprints, Baselines and Policies | 0/TBD | Not started | - |
| 4. Git Diff and Pull Request Readiness | 0/TBD | Not started | - |
| 5. Rails-Aware Intelligence | 0/TBD | Not started | - |
| 6. Optional AI Intelligence | 0/TBD | Not started | - |
| 7. Agent Repair Workflow | 0/TBD | Not started | - |
| 8. MCP | 0/TBD | Not started | - |
| 9. 1.0 Hardening | 0/TBD | Not started | - |
