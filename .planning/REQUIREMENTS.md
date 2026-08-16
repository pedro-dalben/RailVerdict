# Requirements: RailVerdict

**Defined:** 2026-08-16
**Core Value:** Given identical repository state, configuration, analyzer versions, and baseline, RailVerdict returns the same evidence-backed gate regardless of AI configuration.

## User Stories

- As a Rails developer, I can run one local command and receive a trustworthy merge verdict without creating an account or enabling AI.
- As a maintainer of a legacy Rails application, I can baseline existing findings and block newly introduced debt without first fixing the whole project.
- As a coding agent, I can consume versioned JSON findings, understand why the gate failed, and verify a repair without scraping terminal output.
- As a security-conscious team, I can prove what evidence ran, keep untrusted fork code away from secrets, and prevent silent source transmission.
- As an adapter author, I can translate a mature external tool into canonical evidence without adding analyzer-specific policy to the core.

## v1 Requirements

Requirements for the first stable release. Each maps to exactly one roadmap phase.

### Foundation

- [x] **FND-01**: Maintainers have a documented final-name analysis covering RubyGems, GitHub, domains, current product collisions, and preliminary trademark signals.
- [x] **FND-02**: The selected identity has one documented mapping for project name, gem name, Ruby namespace, CLI executable, configuration filename, repository identity, and schema namespace.
- [x] **FND-03**: Publication remains blocked until unresolved launch-jurisdiction and qualified trademark review gates are explicitly cleared.
- [x] **FND-04**: Users can exercise all core rights granted by Apache-2.0, while a separate trademark policy prevents misleading claims of official status or endorsement.
- [x] **FND-05**: Maintainers have a dated third-party analyzer registry containing homepage, license, commercial-use considerations, installation, bundling status, supported-version approach, and output format.
- [x] **FND-06**: Maintainers have a documented Ruby and Rails support proposal tied to official maintenance status and synthetic compatibility lanes.
- [x] **FND-07**: Contributors can understand the product definition, deterministic-first philosophy, four-layer architecture, non-goals, and dependency direction from repository documentation.
- [x] **FND-08**: Initial ADRs record the fifteen product, architecture, licensing, AI, GitHub, MCP, and information-firewall decisions required by the foundation brief.
- [x] **FND-09**: Finding and configuration contracts have versioned JSON Schema drafts, valid examples, and explicit unknown-field behavior.
- [x] **FND-10**: The CLI contract documents commands, options, stdout/stderr separation, deterministic output, and stable proposed exit semantics before implementation.
- [x] **FND-11**: The threat model identifies assets, trust boundaries, adversaries, false-PASS risks, subprocess risks, AI risks, fork risks, supply-chain risks, and required controls.
- [x] **FND-12**: A public information-firewall policy requires synthetic fixtures, English-only repository prose, and a provenance scan across tree, history, package, archives, media, and release artifacts.
- [x] **FND-13**: The proposed repository structure keeps one gem and defers directories or abstractions that have no Phase 1 behavior.
- [x] **FND-14**: The Phase 0 through Phase 9 roadmap maps every v1 requirement once, preserves dependency order, and records observable exit criteria.

### Trustworthy Core

- [ ] **CORE-01**: A developer can run `railverdict init`, `doctor`, `check`, `baseline create`, and `findings` through one lowercase executable.
- [ ] **CORE-02**: A developer can run `railverdict check` offline with AI disabled and without an account, telemetry, or hosted RailVerdict service.
- [ ] **CORE-03**: Configuration is loaded as data, validated against a versioned strict schema, rejects unknown keys with useful paths, and exposes effective values.
- [ ] **CORE-04**: `RunContext` records the repository root, revision scope, Ruby/Rails context, selected analyzers, tool versions, and deterministic inputs without mutable global state.
- [ ] **CORE-05**: External commands execute only as executable-plus-argv arrays with a verified working directory and no interpolated shell string.
- [ ] **CORE-06**: External execution applies monotonic timeouts, bounded concurrent stdout/stderr draining, minimal environment, closed descriptors, process-group termination, child reaping, and temporary-file cleanup.
- [ ] **CORE-07**: Analyzer results distinguish succeeded, unavailable, unsupported, timed out, signaled, failed, parse failed, truncated, and malformed evidence.
- [ ] **CORE-08**: A required analyzer that does not succeed can never be normalized as zero findings or produce a trustworthy PASS.
- [ ] **CORE-09**: A narrow RuboCop adapter detects a supported version, invokes the target bundle, consumes structured output, and preserves execution provenance.
- [ ] **CORE-10**: Every normalized finding follows the versioned analyzer-independent Finding contract and retains its origin and native evidence reference.
- [ ] **CORE-11**: Only the policy evaluator creates immutable policy decisions and `GateResult`; adapters and reporters cannot change gate authority.
- [ ] **CORE-12**: Console output is deterministic and readable, while JSON mode writes exactly one versioned JSON document to stdout and diagnostics only to stderr.
- [ ] **CORE-13**: Stable process exits distinguish pass, policy failure, incomplete/tool/configuration error, and user interruption.
- [ ] **CORE-14**: Repeated runs with equivalent inputs produce equivalent canonical gate content despite locale, timezone, path, ordering, or concurrency variation.

### Evidence Ecosystem

- [ ] **EVID-01**: Minitest evidence records suite identity, passed, failed, errored, skipped, duration, test count, assertions, seed, and failure locations through a RailVerdict-owned structured reporter.
- [ ] **EVID-02**: RSpec evidence records suite identity, examples, failures, pending examples, duration, seed, and failure locations from fixture-tested structured output.
- [ ] **EVID-03**: Zero-test, filtered, load-error, partial, or unexpectedly skipped test runs remain visible and policy-addressable rather than appearing green.
- [ ] **EVID-04**: RuboCop and rubocop-rails execute once per scope, record plugin/configuration provenance, and normalize offenses without analyzer-specific core fields.
- [ ] **EVID-05**: SimpleCov ingestion accepts only its public supported coverage JSON, proves freshness/completeness, and never parses HTML or internal result-cache formats.
- [ ] **EVID-06**: Changed-line coverage logic can be contract-tested against an injected line set but is not advertised as a production Git gate until reliable Git scope exists.
- [ ] **EVID-07**: bundler-audit evidence records tool and advisory-database revisions and separates explicit network refresh from offline gate execution.
- [ ] **EVID-08**: Every shipped adapter has unavailable, supported, empty, malformed, unexpected-version, timeout, non-zero, oversized, partial, and invalid-encoding contract fixtures.
- [ ] **EVID-09**: Every adapter documents supported versions, native output contract, license, install method, execution cost, and failure semantics.
- [ ] **EVID-10**: Brakeman is not advertised as a supported commercial integration until its current license and product-use boundaries receive a written decision.

### Baselines and Policy

- [ ] **DEBT-01**: Fingerprints use a versioned documented canonical payload and full SHA-256 digest rather than file and line alone.
- [ ] **DEBT-02**: Regression vectors prove fingerprint behavior across unrelated edits, line moves, file renames, logical moves, duplicates, copies, collisions, and algorithm migrations.
- [ ] **DEBT-03**: A developer can create a versioned baseline atomically from a complete trusted run without storing source code, credentials, full logs, or AI prompts.
- [ ] **DEBT-04**: Ordinary checks are read-only and cannot silently create or mutate a baseline.
- [ ] **DEBT-05**: Baseline comparison classifies introduced, existing, resolved, changed, moved, suppressed, and waived findings with explainable evidence.
- [ ] **DEBT-06**: Advisory mode reports findings without blocking, no-new-debt mode evaluates introduced regressions, and strict mode evaluates the full current project.
- [ ] **DEBT-07**: Policy is independent of analyzer implementations and maps evidence state, severity, category, completeness, coverage, and regression facts to decisions.
- [ ] **DEBT-08**: A waiver targets an exact fingerprint and requires reason, owner, creation date, UTC expiration, and optional issue reference.
- [ ] **DEBT-09**: Expired, orphaned, malformed, or over-broad waivers remain visible and are never treated as silent suppression.
- [ ] **DEBT-10**: Baseline and waiver readers support documented compatible formats or emit an explicit migration requirement.

### Git and Pull Requests

- [ ] **GIT-01**: Local Git context resolves repository root, HEAD, explicit or configured base, merge base, changed files, NUL-safe paths, added/deleted lines, additions, deletions, binaries, conflicts, and renames.
- [ ] **GIT-02**: `--changed` fails as incomplete when a trustworthy base or required history cannot be resolved and never guesses a passing scope.
- [ ] **GIT-03**: Production changed-code coverage uses the same local Git line scope recorded in `RunContext`.
- [ ] **GIT-04**: SARIF output maps existing canonical findings and policy decisions without introducing a GitHub-specific verification engine.
- [ ] **GIT-05**: A documented GitHub Actions workflow can enforce the same local gate using minimum token permissions and no custom GitHub App.
- [ ] **GIT-06**: Untrusted pull-request code runs only in an unprivileged context without repository secrets, publisher identity, write tokens, or remote-AI credentials.
- [ ] **GIT-07**: No privileged workflow executes or trusts fork code, scripts, caches, or artifacts without an explicitly reviewed safe handoff.
- [ ] **GIT-08**: GitHub annotations and summaries remain projections of `GateResult`, and the core imports no GitHub concepts.

### Rails Context

- [ ] **RAIL-01**: RailVerdict detects supported Ruby/Rails versions, test framework, database adapter, dependencies, application structure, and selected Git scope through explicit conventions.
- [ ] **RAIL-02**: Deterministic resolvers can identify bounded related tests, routes, models, associations, policies, jobs, services, and schema fragments for a finding.
- [ ] **RAIL-03**: Rails context records confidence and provenance and never claims generalized semantic certainty.
- [ ] **RAIL-04**: Runtime integrations such as Prosopite or migration safety checks remain deferred until they have non-destructive execution, lifecycle isolation, structured evidence, and contract tests.

### Optional AI Intelligence

- [ ] **AI-01**: A project with AI off receives exactly the same deterministic gate result as a project with AI enabled.
- [ ] **AI-02**: Remote AI requires explicit opt-in and presents an inspectable manifest of the exact bounded context selected for transmission.
- [ ] **AI-03**: Secret-file exclusions, secret-pattern detection, and redaction run before remote transmission and fail closed on likely secrets.
- [ ] **AI-04**: Repository content, diffs, issues, commits, comments, analyzer messages, and model output are treated as untrusted data rather than instructions.
- [ ] **AI-05**: AI provider responses are schema-validated, labeled advisory with provenance/confidence, and degrade to unavailable without changing the gate.
- [ ] **AI-06**: Request count, finding count, context size, time, and cost budgets are enforced before provider invocation.
- [ ] **AI-07**: AI cache keys bind finding fingerprint, context hash, provider, model, prompt version, and schema version without storing raw sensitive context by default.
- [ ] **AI-08**: Provider abstractions stay outside the verification core, support one initial provider path, and preserve local-model compatibility as a future target.

### Agent Repair Workflow

- [ ] **AGNT-01**: A coding agent can understand a failed check from versioned JSON and exit status without parsing ANSI or prose logs.
- [ ] **AGNT-02**: A deterministic repair packet contains the finding, policy decision, bounded evidence, relevant diff/context, related tests, and argv-form verification commands.
- [ ] **AGNT-03**: Optional AI guidance is clearly separated from deterministic repair-packet evidence.
- [ ] **AGNT-04**: RailVerdict never edits target source code or grants an external agent permissions beyond the caller's existing authority.
- [ ] **AGNT-05**: An external agent can change a synthetic Rails project, observe a failure, repair it, rerun RailVerdict, and reach PASS using only machine contracts.

### MCP Adapter

- [ ] **MCP-01**: MCP is implemented only after CLI, Finding, GateResult, and repair-packet contracts have demonstrated stability.
- [ ] **MCP-02**: MCP tools call the same application services and return the same versioned contracts as the CLI.
- [ ] **MCP-03**: Initial MCP capabilities are read-only and contain no duplicate policy, analyzer execution, or code-editing engine.

### 1.0 Hardening and Release

- [ ] **REL-01**: Finding, configuration, result, baseline, waiver, fingerprint, analyzer, reporter, AI-provider, repair-packet, exit-code, and migration contracts have documented 1.0 compatibility policies.
- [ ] **REL-02**: The full automated suite covers unit, contract, integration, CLI, schema, adapter, fingerprint, baseline, policy, security, and AI-boundary behavior using only synthetic fixtures.
- [ ] **REL-03**: Documentation covers philosophy, architecture, configuration, findings, baselines, policies, analyzers, AI, privacy, agents, GitHub Actions, security, and adapter development with executable examples where practical.
- [ ] **REL-04**: Core development, tests, and release verification require no paid service, AI credential, account, or network access except explicit dependency/advisory refresh and publication steps.
- [ ] **REL-05**: CI verifies every supported Ruby/Rails lane and required checks before publication, while the project dogfoods its own deterministic gate when stable.
- [ ] **REL-06**: The release process builds once, tests and installs the exact gem artifact, records its digest and source revision, and publishes that same artifact.
- [ ] **REL-07**: RubyGems publication uses protected Trusted Publishing with MFA and minimum GitHub permissions instead of a routine long-lived API key.
- [ ] **REL-08**: Current tree, full history, generated gem, archives, media metadata, documentation, release notes, and CI artifacts pass the private-provenance and English-only release gates.
- [ ] **REL-09**: Every release publishes SemVer notes, schema/migration changes, checksums/provenance, third-party license review, and known compatibility boundaries.

## v2 Requirements

Deferred until real adoption evidence justifies them.

### Ecosystem Expansion

- **ECO-01**: Additional analyzer adapters are added only when they provide unique Rails evidence and stable safe execution contracts.
- **ECO-02**: Local model providers can explain findings under the same advisory schema and budgets.
- **ECO-03**: An informational quality trend may summarize evidence without becoming gate authority.
- **ECO-04**: Agent repair-rate observability can measure successful repairs, human escalation, attempts, and regressions without influencing deterministic policy.
- **ECO-05**: A generalized extension API can be published only after multiple real third-party adapters prove the boundary.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Hosted RailVerdict service or dashboard | Violates local-first product scope and adds an unnecessary control plane. |
| Accounts, organizations, billing, subscriptions, or license keys | The core is fully open-source and usable without a commercial tier. |
| Mandatory telemetry, network, or AI | Gate equivalence and privacy require a complete offline path. |
| Custom vulnerability scanner, linter, test framework, or LLM | Mature external tools own those evidence domains. |
| Autonomous source rewriting | External coding agents repair; RailVerdict verifies. |
| Custom GitHub App in v1 | GitHub Actions and SARIF provide the required merge-gate path. |
| Full semantic code graph | Explicit Rails conventions cover the initial context need with less complexity. |
| Plugin marketplace or multiple gems | One gem and internal adapter contracts are sufficient until ecosystem demand is proven. |
| Opaque quality score as gate | Explicit policy decisions are auditable; aggregate scores are not gate authority. |
| Private-project-derived fixtures or examples | Synthetic provenance is a non-negotiable release boundary. |

## Acceptance Criteria

- Every v1 requirement maps to exactly one roadmap phase and every phase has observable success criteria.
- Phase 0 produces research-backed artifacts without production core implementation.
- Required evidence failures are represented explicitly and cannot produce a trustworthy PASS.
- Core verification is deterministic, offline, Rails-first, and independent of AI and GitHub.
- Public schemas, exits, baseline identity, waiver behavior, and release artifacts have compatibility and migration evidence before 1.0.

## Definition of Done

A requirement is complete only when its implementation or document exists, its specified automated and manual evidence has passed, related documentation is current, security/privacy implications are reviewed, and the exact change is committed. Runtime and publication claims require runtime and registry evidence; passing a narrower unit check is not sufficient.

## Traceability

The roadmap is the authoritative requirement-to-phase mapping. Every v1 requirement belongs to exactly one phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FND-01 | Phase 0 | Complete |
| FND-02 | Phase 0 | Complete |
| FND-03 | Phase 0 | Complete |
| FND-04 | Phase 0 | Complete |
| FND-05 | Phase 0 | Complete |
| FND-06 | Phase 0 | Complete |
| FND-07 | Phase 0 | Complete |
| FND-08 | Phase 0 | Complete |
| FND-09 | Phase 0 | Complete |
| FND-10 | Phase 0 | Complete |
| FND-11 | Phase 0 | Complete |
| FND-12 | Phase 0 | Complete |
| FND-13 | Phase 0 | Complete |
| FND-14 | Phase 0 | Complete |
| CORE-01 | Phase 1 | Pending |
| CORE-02 | Phase 1 | Pending |
| CORE-03 | Phase 1 | Pending |
| CORE-04 | Phase 1 | Pending |
| CORE-05 | Phase 1 | Pending |
| CORE-06 | Phase 1 | Pending |
| CORE-07 | Phase 1 | Pending |
| CORE-08 | Phase 1 | Pending |
| CORE-09 | Phase 1 | Pending |
| CORE-10 | Phase 1 | Pending |
| CORE-11 | Phase 1 | Pending |
| CORE-12 | Phase 1 | Pending |
| CORE-13 | Phase 1 | Pending |
| CORE-14 | Phase 1 | Pending |
| EVID-01 | Phase 2 | Pending |
| EVID-02 | Phase 2 | Pending |
| EVID-03 | Phase 2 | Pending |
| EVID-04 | Phase 2 | Pending |
| EVID-05 | Phase 2 | Pending |
| EVID-06 | Phase 2 | Pending |
| EVID-07 | Phase 2 | Pending |
| EVID-08 | Phase 2 | Pending |
| EVID-09 | Phase 2 | Pending |
| EVID-10 | Phase 2 | Pending |
| DEBT-01 | Phase 3 | Pending |
| DEBT-02 | Phase 3 | Pending |
| DEBT-03 | Phase 3 | Pending |
| DEBT-04 | Phase 3 | Pending |
| DEBT-05 | Phase 3 | Pending |
| DEBT-06 | Phase 3 | Pending |
| DEBT-07 | Phase 3 | Pending |
| DEBT-08 | Phase 3 | Pending |
| DEBT-09 | Phase 3 | Pending |
| DEBT-10 | Phase 3 | Pending |
| GIT-01 | Phase 4 | Pending |
| GIT-02 | Phase 4 | Pending |
| GIT-03 | Phase 4 | Pending |
| GIT-04 | Phase 4 | Pending |
| GIT-05 | Phase 4 | Pending |
| GIT-06 | Phase 4 | Pending |
| GIT-07 | Phase 4 | Pending |
| GIT-08 | Phase 4 | Pending |
| RAIL-01 | Phase 5 | Pending |
| RAIL-02 | Phase 5 | Pending |
| RAIL-03 | Phase 5 | Pending |
| RAIL-04 | Phase 5 | Pending |
| AI-01 | Phase 6 | Pending |
| AI-02 | Phase 6 | Pending |
| AI-03 | Phase 6 | Pending |
| AI-04 | Phase 6 | Pending |
| AI-05 | Phase 6 | Pending |
| AI-06 | Phase 6 | Pending |
| AI-07 | Phase 6 | Pending |
| AI-08 | Phase 6 | Pending |
| AGNT-01 | Phase 7 | Pending |
| AGNT-02 | Phase 7 | Pending |
| AGNT-03 | Phase 7 | Pending |
| AGNT-04 | Phase 7 | Pending |
| AGNT-05 | Phase 7 | Pending |
| MCP-01 | Phase 8 | Pending |
| MCP-02 | Phase 8 | Pending |
| MCP-03 | Phase 8 | Pending |
| REL-01 | Phase 9 | Pending |
| REL-02 | Phase 9 | Pending |
| REL-03 | Phase 9 | Pending |
| REL-04 | Phase 9 | Pending |
| REL-05 | Phase 9 | Pending |
| REL-06 | Phase 9 | Pending |
| REL-07 | Phase 9 | Pending |
| REL-08 | Phase 9 | Pending |
| REL-09 | Phase 9 | Pending |

**Coverage:**

- v1 requirements: 85
- Mapped to phases: 85
- Unmapped: 0

---
*Requirements defined: 2026-08-16*
*Last updated: 2026-08-16 after Plan 00-07 close-out*
