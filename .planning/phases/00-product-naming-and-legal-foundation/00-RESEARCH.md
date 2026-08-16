# Phase 0: Product, Naming and Legal Foundation - Research

**Researched:** 2026-08-16
**Domain:** Product identity, open-source licensing, public contracts, security governance, and documentation-only validation
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Phase Boundary

Phase 0 delivers the complete research-backed foundation needed to begin implementation: final-name analysis and identity mapping; Apache-2.0, NOTICE, and trademark terms; analyzer licensing and support research; product, philosophy, architecture, ADR, schema, CLI, repository, security, information-firewall, and roadmap contracts. It produces documentation and draft contracts only. It must not add a gem skeleton, runtime code, analyzer execution, CI integration, AI, GitHub integration, MCP, or publication.

The phase can record RailVerdict as the selected identity, but public use remains blocked until launch-jurisdiction searches, including Brazil, and qualified trademark review are explicitly cleared. Phase completion records this unresolved publication gate rather than representing legal clearance.

#### Product identity and legal boundary
- Use one identity everywhere: project `RailVerdict`, gem `rail_verdict`, Ruby namespace `RailVerdict`, executable `railverdict`, configuration `.railverdict.yml`, repository identity `railverdict`, and schema namespace rooted in `https://railverdict.dev/schemas/` unless the name-clearance record requires another non-breaking draft URI.
- Preserve dated evidence for RubyGems, GitHub, domain, current-product, and preliminary trademark checks. Distinguish verified availability from inference and legal advice.
- Treat RailVerdict as provisional for publication. Do not create public branding, publish packages, or claim trademark clearance until documented launch-jurisdiction and qualified review gates are cleared.
- License the project under Apache License 2.0. Keep NOTICE and trademark rules separate; trademark terms may restrict misleading official status or endorsement but must not narrow Apache-2.0 software rights.

#### Product and architecture
- Define RailVerdict as a local-first, fully open-source Rails verification framework, not a SaaS, hosted dashboard, analyzer, LLM, editor, or autonomous coding agent.
- Make the default merge decision deterministic: identical repository state, configuration, analyzer versions, and baseline produce the same gate regardless of AI.
- Document four one-way layers: evidence collection; deterministic verification core; optional intelligence; and CLI, CI, GitHub, coding-agent, and future MCP consumers.
- Only policy evaluation owns gate authority. Analyzer findings are evidence, reporters are projections, and AI remains optional and advisory.
- Keep external analyzers in target-project processes; do not bundle, silently install, or reimplement them.
- Keep one gem and one process. Defer directories and abstractions without Phase 1 behavior.

#### Analyzer and platform research
- Maintain a dated analyzer registry for Minitest, RSpec, RuboCop, rubocop-rails, SimpleCov, Undercover, RubyCritic, Brakeman, Prosopite, bundler-audit, and strong_migrations.
- For each analyzer record homepage, current license, commercial-use considerations, installation, whether it is bundled, proposed version policy, native output, execution cost, and disposition.
- Do not put Brakeman in the committed adapter shortlist until a written legal/product decision addresses its current custom license and product-use boundary.
- Propose Ruby and Rails support from official maintenance status and synthetic compatibility lanes; do not imply support before those lanes pass.

#### Foundation decision records
- Create fifteen initial ADRs covering: deterministic evidence before merge; Rails-first scope; local-first fully open source; external analyzer processes; canonical Finding; policy-owned gate authority; fingerprint baselines and no-new-debt; safe subprocess boundary; one-gem structure; Apache-2.0 plus trademark separation; optional advisory AI; provider-independent AI boundary; GitHub as an adapter; MCP after stable contracts; and synthetic-only public provenance with English-only repository content.
- ADRs must identify status, context, decision, consequences, and deferred work. They describe foundation choices, not implemented behavior.

#### Draft public contracts
- Publish versioned JSON Schema 2020-12 drafts for canonical Finding and configuration, with valid synthetic examples and explicit rejection of unknown fields.
- Keep evidence separate from policy: `Finding` must not accept analyzer-supplied blocking authority. Any rendered blocking state is derived from a policy decision.
- Document draft CLI commands `init`, `doctor`, `check`, `baseline create`, and `findings`; options; deterministic ordering; exactly one JSON document on stdout in JSON mode; diagnostics on stderr; and proposed stable exits for pass, policy failure, incomplete/tool/configuration failure, and interruption.
- Label every pre-implementation schema, exit, support, and compatibility surface as a draft rather than a proven promise.

#### Security, privacy, and provenance
- Threat-model false PASS, hostile repositories and output, subprocess handling, AI transmission and prompt injection, fork workflows, dependency and release supply chain, baseline poisoning, and artifact substitution.
- Require executable-plus-argv process boundaries, bounded I/O, timeouts, process-tree cleanup, minimal environment, explicit incomplete evidence, least-privilege CI, build-once publication, and opt-in remote AI with inspection and redaction.
- Treat source repositories, analyzer output, Git metadata, pull requests, model input, and model output as untrusted data.
- Permit only synthetic public fixtures and examples. Require English-only repository prose and release-time provenance scanning across tree, history, gem, archives, media metadata, documentation, release notes, and CI artifacts.
- An authorized high-level historical attribution may name IntegrarPlus as the private Rails application experience that partly motivated RailVerdict. The literal name may also appear in provenance-policy documentation to define this exception. Never copy any private IntegrarPlus source, data, model/controller/service names, schema, business rule, domain, infrastructure, fixture, metric, screenshot, log, prompt, path, branch, URL, security detail, credential, environment value, or operational information.

#### Roadmap and phase gate
- Preserve the approved Phase 0 through Phase 9 order and map every v1 requirement to exactly one phase with observable success and exit criteria.
- Phase 2 may define and fixture-test changed-line coverage calculations against injected line sets; production Git-scoped changed coverage belongs to Phase 4.
- Phase 0 ends only when its artifacts are mutually consistent, every FND requirement is evidenced, the identity decision and remaining publication blocker are explicit, and no production core implementation exists.

### the agent's Discretion
- Group closely related requirements into the fewest clear public documents without omitting any requested artifact or ADR.
- Choose filenames, document cross-links, table layouts, schema `$id` suffixes, and synthetic example values.
- Add only small validation scripts or standard commands needed to prove JSON, schema examples, link targets, requirement coverage, English-only scope, and the absence of production code. Prefer existing or standard tools and do not add dependencies for documentation-only checks.

### Deferred Ideas (OUT OF SCOPE)
- Phase 1: strict configuration loading, `RunContext`, safe process execution, narrow RuboCop adapter, canonical runtime objects, deterministic policy, reporters, and CLI behavior.
- Phases 2–5: analyzer breadth, coverage, fingerprints, baselines, waivers, Git/CI, and bounded Rails context.
- Phases 6–8: opt-in AI, deterministic repair packets, and MCP.
- Phase 9: compatibility freeze, release hardening, provenance enforcement, and public publication.
- v2: broader analyzer ecosystem, local model providers, trend reporting, repair observability, and a generalized extension API.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FND-01 | Maintainers have a documented final-name analysis covering RubyGems, GitHub, domains, current product collisions, and preliminary trademark signals. | Use the dated evidence matrix and durable official URLs in “Name Evidence Record”; preserve HTTP/result status and limitations. [VERIFIED: official registry/API queries] |
| FND-02 | The selected identity has one documented mapping for project name, gem name, Ruby namespace, CLI executable, configuration filename, repository identity, and schema namespace. | Use the single identity table in `docs/foundation.md` and validate all public artifacts against it. [VERIFIED: 00-CONTEXT.md] |
| FND-03 | Publication remains blocked until unresolved launch-jurisdiction and qualified trademark review gates are explicitly cleared. | Add a prominent publication status, clearance checklist, named evidence owner, date, and human approval record; do not replace it with automated checks. [VERIFIED: 00-CONTEXT.md] |
| FND-04 | Users can exercise all core rights granted by Apache-2.0, while a separate trademark policy prevents misleading claims of official status or endorsement. | Copy the official license text unchanged, keep NOTICE informational, and restrict `TRADEMARKS.md` to source-confusion/endorsement rules. [CITED: https://www.apache.org/licenses/LICENSE-2.0.txt] |
| FND-05 | Maintainers have a dated third-party analyzer registry containing homepage, license, commercial-use considerations, installation, bundling status, supported-version approach, and output format. | Use the required registry columns and current RubyGems/API snapshot below; keep Brakeman on HOLD. [VERIFIED: RubyGems API and official repositories] |
| FND-06 | Maintainers have a documented Ruby and Rails support proposal tied to official maintenance status and synthetic compatibility lanes. | Propose Ruby `>= 3.3`, core lanes 3.3/3.4/4.0, and Rails 8.0/8.1 fixture lanes; label them unproven until tests pass. [CITED: https://www.ruby-lang.org/en/downloads/branches/] |
| FND-07 | Contributors can understand the product definition, deterministic-first philosophy, four-layer architecture, non-goals, and dependency direction from repository documentation. | Keep the short definition in `PROJECT.md`, invariants in `PHILOSOPHY.md`, and data/dependency flow in `ARCHITECTURE.md`; link all three from README. [VERIFIED: source brief and 00-CONTEXT.md] |
| FND-08 | Initial ADRs record the fifteen product, architecture, licensing, AI, GitHub, MCP, and information-firewall decisions required by the foundation brief. | Create exactly the fifteen mapped ADRs below, each with status, context, decision, consequences, and deferred work. [VERIFIED: 00-CONTEXT.md] |
| FND-09 | Finding and configuration contracts have versioned JSON Schema drafts, valid examples, and explicit unknown-field behavior. | Use Draft 2020-12, strict object schemas, valid synthetic examples, and negative mutation tests that add unknown fields. [CITED: https://json-schema.org/draft/2020-12] |
| FND-10 | The CLI contract documents commands, options, stdout/stderr separation, deterministic output, and stable proposed exit semantics before implementation. | Put the minimal command/option/stream/exit draft in `docs/contracts.md`, explicitly labeled unimplemented. [VERIFIED: 00-CONTEXT.md] |
| FND-11 | The threat model identifies assets, trust boundaries, adversaries, false-PASS risks, subprocess risks, AI risks, fork risks, supply-chain risks, and required controls. | Use the threat/control matrix and ASVS mapping below; state that subprocess isolation is not an OS sandbox. [VERIFIED: .planning/research/PITFALLS.md] |
| FND-12 | A public information-firewall policy requires synthetic fixtures, English-only repository prose, and a provenance scan across tree, history, package, archives, media, and release artifacts. | Define every scan surface, an external private-pattern input, non-echoing reports, narrow i18n exceptions, and zero-unresolved-match release behavior. [VERIFIED: 00-CONTEXT.md] |
| FND-13 | The proposed repository structure keeps one gem and defers directories or abstractions that have no Phase 1 behavior. | Publish only foundation docs, draft schemas/examples, and one validation script; assert gem skeleton/runtime paths are absent. [VERIFIED: codebase inventory] |
| FND-14 | The Phase 0 through Phase 9 roadmap maps every v1 requirement once, preserves dependency order, and records observable exit criteria. | The current roadmap already maps 85 unique v1 requirements exactly once; retain a parser check and review the external Phase 0 gate. [VERIFIED: Ruby roadmap audit on 2026-08-16] |
</phase_requirements>

## Summary

Phase 0 should create a small, public-facing documentation and draft-contract set, not a gem scaffold. The planner should organize work around eight coherent documents (`foundation`, analyzer/support research, product, philosophy, architecture, contracts, security, and information firewall), the required license/trademark files, two schemas with two examples, fifteen ADRs, and one phase-only validation script. The existing `.planning/ROADMAP.md` remains the authoritative requirement-to-phase map. [VERIFIED: 00-CONTEXT.md]

RailVerdict is the selected internal identity. Exact package, repository, and `.dev`/`.com`/`.org` registration surfaces returned no current record on 2026-08-16, but those responses are time-limited signals, not reservations and not trademark clearance. Publication remains blocked until a qualified reviewer records searches for Brazil and every intended launch jurisdiction, similarity and related-goods analysis, current/common-law product use, and a written decision. Phase 0 may finish by accurately recording that unresolved publication gate; it must not represent the name as cleared. [VERIFIED: official RubyGems, GitHub, and registry RDAP queries] [CITED: https://www.uspto.gov/trademarks/search/federal-trademark-searching]

No external package is needed for this phase. Ruby, Git, ripgrep, and the already-available Python `jsonschema` module can validate the documentation and Draft 2020-12 examples without creating a runtime dependency. The analyzer registry is evidence for later adapter phases, not installation authority. Brakeman remains explicitly held pending written legal/product review of its current custom license and intended product-use boundary. [VERIFIED: environment audit and 00-CONTEXT.md]

**Primary recommendation:** Create the complete draft foundation now, gate it with one repository validation script, record the unresolved trademark checkpoint as a publication blocker, and do not add `lib/`, `exe/`, a gemspec, workflows, or adapter code.

## Project Constraints (from AGENTS.md)

- Repository content and collaboration are English-only except explicit internationalization fixtures. [VERIFIED: AGENTS.md]
- Use Apache License 2.0 with separate NOTICE and trademark policy; do not add custom source-availability restrictions. [VERIFIED: AGENTS.md]
- Deterministic evidence and policy own the gate; AI cannot reinterpret objective failures. [VERIFIED: AGENTS.md]
- Existing debt may enter a versioned baseline, while no-new-debt is the recommended adoption mode. [VERIFIED: AGENTS.md]
- Core behavior must work offline and external tools must use argv arrays, bounded I/O, timeouts, and explicit failures. [VERIFIED: AGENTS.md]
- Remote AI must be opt-in, context-minimized, inspectable, secret-scanned, and fail-closed. [VERIFIED: AGENTS.md]
- Repository text and fork contributions are untrusted; privileged credentials must not be exposed to untrusted code. [VERIFIED: AGENTS.md]
- Findings, configuration, JSON, baselines, fingerprints, analyzer APIs, reporters, exits, and future AI/MCP adapters require versions before 1.0 promises. [VERIFIED: AGENTS.md]
- Keep one Ruby gem until demonstrated need justifies separation; do not build a full semantic graph in the MVP. [VERIFIED: AGENTS.md]
- Use only synthetic public examples and require a repository-wide private-information scan before public release. [VERIFIED: AGENTS.md]
- The proposed platform baseline is Ruby `>= 3.3` with Ruby 3.3/3.4/4.0 lanes and Rails 8.0/8.1 fixture lanes, with no Rails runtime dependency; these remain proposals until proven. [VERIFIED: AGENTS.md]
- Prefer Ruby standard library choices and do not add a CLI framework, Rails/ActiveSupport runtime dependency, analyzer bundle, or documentation generator without a demonstrated need. [VERIFIED: AGENTS.md]
- No project-defined skills or established code conventions exist yet; follow the locked context and keep the foundation boring and explicit. [VERIFIED: AGENTS.md and project skill discovery]
- File changes must run through a GSD workflow. This research was created inside the Phase 0 planning workflow. [VERIFIED: AGENTS.md]

## Architectural Responsibility Map

Phase 0 is pre-runtime governance. “Tier” below names the future architectural owner of the contract, not implementation work authorized in this phase. [VERIFIED: 00-CONTEXT.md]

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Product identity and publication gate | Repository governance | External legal review | Identity is a repository-wide contract; legal clearance cannot be automated or delegated to runtime code. |
| Apache-2.0, NOTICE, and trademark terms | Repository governance | External legal review | Software rights and brand-use rules are public legal documents, not application behavior. |
| Analyzer registry and support proposal | Evidence collection contract | Repository governance | Future adapters consume the registry, but Phase 0 records evidence only. |
| Finding and configuration schemas | Deterministic verification core contract | CLI/adapter consumers | The core owns normalized evidence meaning; adapters and consumers only translate or render it. |
| CLI/stream/exit contract | Agent-consumer boundary | Deterministic verification core | The CLI projects application results and maps one final status; it does not own policy. |
| Threat model and information firewall | Cross-cutting repository governance | Every future runtime tier | The controls constrain evidence, core, optional AI, CI, and publication boundaries. |
| Roadmap traceability | Planning governance | All future phases | Requirement ownership and dependency order are planning contracts, not runtime behavior. |
| Foundation validation | Development tooling | Repository governance | A small script proves document/schema consistency without becoming product code. |

## Standard Stack

### Core

| Tool / Standard | Version | Purpose | Why Standard |
|-----------------|---------|---------|--------------|
| Markdown | CommonMark/GFM subset | Public product, architecture, legal, security, and ADR documents | Existing repository format; no documentation generator is required. [VERIFIED: codebase inventory] |
| JSON Schema | Draft 2020-12 | Draft Finding and configuration contracts | Current selected dialect with official meta-schema and explicit object-closure keywords. [CITED: https://json-schema.org/draft/2020-12] |
| Apache License | 2.0, January 2004 | Software copyright and patent license | Locked project decision; official text defines grants, redistribution, NOTICE, and trademark separation. [CITED: https://www.apache.org/licenses/LICENSE-2.0.txt] |
| Ruby | 3.4.5 available locally | Foundation validation and roadmap/link checks | Already installed and sufficient through `JSON`, `Pathname`, and file APIs; no project dependency. [VERIFIED: environment audit] |
| Git | 2.43.0 available locally | Tracked-tree/history scope and exact commits | Already installed; required to validate roadmap/provenance scope and absence of production files. [VERIFIED: environment audit] |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| Python `jsonschema` | 4.10.3 available locally | Validate Draft 2020-12 schemas/examples and negative unknown-field mutations | Phase-only validation; do not add it to RailVerdict dependencies. [VERIFIED: environment audit] |
| ripgrep | 15.2.0 available locally | Fast identity, language-marker, and prohibited-path scans | Use inside the validation script and manual audit commands. [VERIFIED: environment audit] |
| `file` | 5.45 available locally | Identify binary/media/archive inputs during provenance review | Use to classify scan surfaces; it is not a provenance detector. [VERIFIED: environment audit] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing Python `jsonschema` | Add `json_schemer` now | Rejected for Phase 0: it creates a dependency before runtime validation exists; add it only with Phase 1 boundary validation. [VERIFIED: 00-CONTEXT.md and STACK.md] |
| One validation script | Rake/Minitest project scaffold | Rejected: it resembles the forbidden gem skeleton and adds files with no product behavior. [VERIFIED: 00-CONTEXT.md] |
| Markdown files | RDoc/YARD/static site generator | Rejected: no Phase 0 requirement needs generated documentation or hosting. [VERIFIED: STACK.md] |
| Official Apache license text | A custom “open-source” license | Forbidden: custom resale or commercial-use restrictions would narrow the selected open-source rights. [CITED: https://www.apache.org/licenses/LICENSE-2.0.txt] |

**Installation:** none. Do not change `Gemfile`, add a gemspec, or install a package for Phase 0. [VERIFIED: 00-CONTEXT.md]

## Package Legitimacy Audit

Not applicable. Phase 0 installs no external packages. The analyzer registry describes tools that remain external to RailVerdict and does not authorize their installation. [VERIFIED: 00-CONTEXT.md]

## Minimal Public Artifact Map

Use this exact shape unless the planner discovers an existing equivalent file during execution. It is the smallest set that preserves the explicit source-brief artifacts and all FND contracts. [VERIFIED: source brief and 00-CONTEXT.md]

```text
README.md                       # concise entry point; links, status, non-goals
PROJECT.md                      # authoritative public product definition and scope
PHILOSOPHY.md                   # evidence-first, deterministic, local-first invariants
ARCHITECTURE.md                 # four layers, dependency direction, proposed one-gem shape
LICENSE                         # unmodified Apache License 2.0 text
NOTICE                          # factual attribution only; cannot modify the license
TRADEMARKS.md                   # separate source-confusion and endorsement policy
docs/
├── foundation.md               # dated naming evidence, identity map, publication gate
├── analyzers.md                # Ruby/Rails proposal and analyzer/license registry
├── contracts.md                # schema semantics and draft CLI/result contract
├── SECURITY.md                 # threats, controls, and information firewall
└── adr/                        # exactly fifteen grouped foundation decisions
    ├── 0001-deterministic-pass-fail.md
    ├── 0002-external-analyzer-execution.md
    ├── 0003-canonical-finding.md
    ├── 0004-versioned-schemas.md
    ├── 0005-fingerprint-baseline.md
    ├── 0006-no-new-debt.md
    ├── 0007-advisory-ai.md
    ├── 0008-remote-ai-explicit-opt-in.md
    ├── 0009-github-as-an-adapter.md
    ├── 0010-cli-and-json-canonical.md
    ├── 0011-mcp-as-an-adapter.md
    ├── 0012-third-party-license-review.md
    ├── 0013-information-firewall.md
    ├── 0014-apache-2-license.md
    └── 0015-separate-trademark-policy.md
schemas/
├── finding-v1.schema.json
├── configuration-v1.schema.json
└── result-v1.schema.json
examples/
├── finding-v1.json
├── configuration-v1.yml
└── result-v1.json
script/
└── validate-foundation          # phase-only validation; not the product CLI
.planning/ROADMAP.md             # existing canonical 85-requirement phase map
```

Do not create `lib/`, `exe/`, `bin/railverdict`, `rail_verdict.gemspec`, `Gemfile`, `Rakefile`, analyzer fixtures, Rails fixtures, GitHub workflows, AI/MCP files, or release automation in Phase 0. [VERIFIED: 00-CONTEXT.md]

## Exact Content and Consistency Obligations

| Artifact | Must contain | Must not contain | Canonical cross-check |
|----------|--------------|------------------|-----------------------|
| `README.md` | One-paragraph product definition, “Evidence before merge,” current publication-blocked notice, core properties, non-goals, links to every foundation document | Installation or working-command claims, badges implying CI/release, package links, trademark-clearance claims | Identity/status must match `PROJECT.md` and `docs/foundation.md`. |
| `PROJECT.md` | Product definition, core value, users, scope, non-goals, constraints, Phase 0 status | Roadmap task detail, analyzer-version tables, implementation claims | Product wording must match `.planning/PROJECT.md` and FND-07. |
| `PHILOSOPHY.md` | Evidence before opinion, deterministic gate, no-new-debt, Rails-first, local-first, AI optional/advisory, agent-native JSON, privacy | Algorithms or adapter-specific mechanics | Every invariant must map to at least one ADR. |
| `ARCHITECTURE.md` | Four one-way layers, gate authority, component responsibility, dependency direction, proposed future one-gem structure | Existing-class/file claims, speculative directories beyond Phase 1, GitHub/AI/MCP inside core | Diagram and prose must agree with ADRs 0004–0009 and 0011–0014. |
| `docs/foundation.md` | Dated name evidence, exact URLs/results/limitations, identity map, legal disclaimer, unresolved launch-jurisdiction checklist, named publication state | “Available,” “cleared,” “registered,” or “safe to use” without qualified evidence | All identity tokens match schemas, docs, and CLI draft. |
| `LICENSE` | Byte-for-byte official Apache-2.0 license text | Project-specific restrictions or commentary | Compare to official source. [CITED: https://www.apache.org/licenses/LICENSE-2.0.txt] |
| `NOTICE` | Product/copyright attribution and required third-party notices actually applicable now | License terms, trademark policy, speculative dependency notices | Must be factual and informational under Apache section 4(d). [CITED: https://www.apache.org/licenses/LICENSE-2.0.txt] |
| `TRADEMARKS.md` | Accurate nominative references, fork/modified-product renaming, no false official status, sponsorship, or endorsement; legal-contact/review status | Restrictions on running, modifying, redistributing, selling, consulting, or integrating the software | Must not narrow `LICENSE`; align with ADR 0010. |
| `docs/analyzers.md` | Dated platform proposal and all eleven analyzer registry entries with the fields below | Support claims without fixture lanes; mandatory Brakeman; analyzer bundling | Versions/URLs/licenses match registry evidence; dispositions match roadmap. |
| `docs/contracts.md` | Draft labels, schema field semantics, strict unknown behavior, CLI commands/options, ordering, streams, exits, migration warning | Runtime guarantees or “supported” language before tests | Links to both schemas/examples; no `blocking` input on Finding. |
| `SECURITY.md` | Assets, actors, trust boundaries, false-PASS/control matrix, subprocess non-sandbox disclaimer, AI/fork/supply-chain threats, ASVS mapping, and information firewall | Claims that ProcessRunner or CI fully sandboxes hostile code | Controls match ADRs and later roadmap ownership. |
| ADRs | Title, status, date, context, decision, consequences, deferred work, related requirements/docs | Claims that deferred behavior exists | Exactly fifteen files/titles; accepted decision is distinct from implementation status. |
| Schemas/examples | Draft 2020-12 dialect, stable versioned `$id`, strict objects, valid synthetic data | External `$ref` requiring network, analyzer-specific policy fields, real/private data | Both examples validate offline; unknown-field mutations fail. |
| `script/validate-foundation` | Focused subchecks for schema, links, identity, ADRs, roadmap, language/provenance scope, and no-production assertion | Network access, package installation, product CLI behavior | Default run invokes every automated subcheck and exits nonzero on failure. |

Every public document must use one of four claim labels where ambiguity exists: **Decision**, **Draft contract**, **Dated evidence**, or **Unresolved external gate**. Avoid bare “supported,” “available,” “secure,” or “cleared.” [VERIFIED: 00-CONTEXT.md]

## Name Evidence Record

### Identity Mapping

| Surface | Canonical value | Status |
|---------|-----------------|--------|
| Project/product | `RailVerdict` | Selected internally; publication not cleared |
| Gem | `rail_verdict` | Draft/unreserved |
| Ruby namespace | `RailVerdict` | Draft/unimplemented |
| CLI executable | `railverdict` | Draft/unimplemented |
| Configuration | `.railverdict.yml` | Draft/unimplemented |
| Repository identity | `railverdict` | Draft; owner/organization unresolved |
| Schema root | `https://railverdict.dev/schemas/` | Draft; domain not reserved by this phase |

[VERIFIED: 00-CONTEXT.md]

### Dated Surface Checks to Preserve

The public name record should preserve request date, query, durable URL, observed status/result count, reviewer, and a limitations column. Re-run immediately before any reservation or publication. [CITED: https://www.uspto.gov/trademarks/search/federal-trademark-searching]

| Surface / query | 2026-08-16 observation | Durable source | Required wording |
|-----------------|------------------------|----------------|------------------|
| RubyGems `rail_verdict` | HTTP 404 | `https://rubygems.org/api/v1/gems/rail_verdict.json` | “No published exact gem record was returned at the checked time”; never “name is available.” [VERIFIED: RubyGems API] |
| RubyGems `rail-verdict` | HTTP 404 | `https://rubygems.org/api/v1/gems/rail-verdict.json` | Preserve variant to assess typo/confusion surfaces. [VERIFIED: RubyGems API] |
| RubyGems `railverdict` | HTTP 404 | `https://rubygems.org/api/v1/gems/railverdict.json` | Preserve compact variant. [VERIFIED: RubyGems API] |
| GitHub organization `railverdict` | HTTP 404 | `https://api.github.com/orgs/railverdict` | “No organization record was returned”; ownership can change. [VERIFIED: GitHub API] |
| GitHub canonical repository | HTTP 404 | `https://api.github.com/repos/railverdict/railverdict` | Does not reserve the owner or repository. [VERIFIED: GitHub API] |
| GitHub exact-name search | `total_count: 0` | `https://api.github.com/search/repositories?q=railverdict%20in:name&per_page=100` | Search result is dated and owner-scoped. [VERIFIED: GitHub API] |
| `railverdict.dev` | RDAP HTTP 404 | `https://pubapi.registry.google/rdap/domain/railverdict.dev` | “No RDAP registration record was returned”; not a reservation. [VERIFIED: Google Registry RDAP] |
| `railverdict.com` | RDAP HTTP 404 | `https://rdap.verisign.com/com/v1/domain/railverdict.com` | Same limitation. [VERIFIED: Verisign RDAP] |
| `railverdict.org` | RDAP HTTP 404 | `https://rdap.publicinterestregistry.org/rdap/domain/railverdict.org` | Same limitation. [VERIFIED: Public Interest Registry RDAP] |
| Exact current-product web search | No durable authoritative clearance result exists | Preserve query strings and dated screenshots/export in the qualified review record | Web search is discovery evidence only; it cannot establish absence of common-law use. [ASSUMED] |
| USPTO exact/similar search | Not reproducibly completed in this session | `https://tmsearch.uspto.gov/` and official guidance below | **Unresolved external gate.** Search exact, expanded, alternate spelling/pronunciation, and related goods/services. [CITED: https://www.uspto.gov/trademarks/search/federal-trademark-searching] |
| WIPO Global Brand Database | Portal identified; result not captured | `https://www.wipo.int/en/web/global-brand-database/index` | **Unresolved external gate.** WIPO is additional evidence, not a substitute for national offices. [CITED: https://www.wipo.int/en/web/global-brand-database/index] |
| TMview | Query endpoint identified; result not captured | `https://www.tmdn.org/tmview/#/tmview/results?page=1&pageSize=30&criteria=I&basicSearch=RAILVERDICT` | **Unresolved external gate.** Verify any result against the relevant official office. [CITED: https://www.tmdn.org/tmview/] |
| Brazil INPI | Official portal/search identified; result not captured | `https://www.gov.br/inpi/pt-br/servicos/marcas` | **Blocking unresolved jurisdiction.** Preserve search exports and qualified interpretation. [CITED: https://www.gov.br/inpi/pt-br/servicos/marcas] |

The name analysis must retain a short decision-history appendix explaining that LineClear was rejected because of documented exact software, GitHub, and trademark collision signals. Link the existing primary URLs from `.planning/research/FEATURES.md`; do not copy stale conclusions into the RailVerdict evidence table. [VERIFIED: .planning/research/FEATURES.md]

### Legal Wording Boundaries

Use these formulations:

- “RailVerdict is the selected project identity, provisional for publication.” [VERIFIED: 00-CONTEXT.md]
- “No exact record was returned from the named registry/API on 2026-08-16.” [VERIFIED: official registry/API queries]
- “This is a preliminary search record, not legal advice, reservation, registration, or clearance.” [CITED: https://www.uspto.gov/trademarks/search/federal-trademark-searching]
- “Publication is blocked pending documented launch-jurisdiction searches and qualified trademark review.” [VERIFIED: 00-CONTEXT.md]
- “Apache-2.0 grants software rights; the separate trademark policy addresses use of project identity and false endorsement.” [CITED: https://www.apache.org/licenses/LICENSE-2.0.txt]

Do not use: “available,” “clear,” “legally safe,” “trademark approved,” “registered,” “exclusive,” or “counsel approved” unless the public evidence record names the competent reviewer, jurisdiction/scope, date, and actual conclusion. [CITED: https://www.uspto.gov/trademarks/search/federal-trademark-searching]

### Apache-2.0 / NOTICE / Trademark Separation

The official Apache-2.0 text grants copyright rights to reproduce, modify, sublicense, and distribute, grants a patent license subject to its terms, defines redistribution/NOTICE conditions, and withholds trademark rights except reasonable descriptive origin and NOTICE use. [CITED: https://www.apache.org/licenses/LICENSE-2.0.txt]

Prescriptive boundary:

1. Copy the official license text unchanged into `LICENSE`.
2. Put only factual attribution notices in `NOTICE`; Apache section 4(d) says NOTICE is informational and does not modify the license. [CITED: https://www.apache.org/licenses/LICENSE-2.0.txt]
3. Put project-name/logo rules only in `TRADEMARKS.md`.
4. Permit accurate nominative statements such as “compatible with RailVerdict” or “powered by RailVerdict,” subject to no-confusion wording.
5. Require forks/materially modified products to avoid presenting themselves as the official project.
6. Never use trademark policy to forbid commercial use, modification, redistribution, consulting, integration, or resale of the software itself.
7. Do not claim a registered mark or use a registration symbol unless qualified review confirms the jurisdiction and status.

[CITED: https://www.apache.org/foundation/marks/] [VERIFIED: 00-CONTEXT.md]

## Analyzer and Platform Registry

### Required Registry Fields

Each row must include: `tool`, `capability`, `homepage`, `package/registry URL`, `observed version`, `version published`, `evidence date`, `license identifier`, `license text URL`, `commercial-use consideration`, `target-project install`, `bundled/external`, `proposed supported range`, `native machine output`, `schema stability`, `execution model/cost`, `Rails relevance`, `overlap`, `failure semantics`, `disposition`, `decision owner/blocker`, and `next review date/event`. [VERIFIED: 00-CONTEXT.md and STACK.md]

“Commercial-use consideration” is a screening note, not legal advice. “Supported range” is a proposal until synthetic lower/current fixtures pass. “External” means RailVerdict neither vendors nor silently installs the analyzer. [VERIFIED: 00-CONTEXT.md]

### Current Registry Snapshot

Versions and publish timestamps below were read from official RubyGems APIs on 2026-08-16. `rubocop-rails` is now 2.37.0; the earlier STACK snapshot showing 2.36.0 is stale and must not be copied. [VERIFIED: RubyGems API]

| Tool | Observed version / published UTC | License | Machine-output position | Proposed disposition |
|------|----------------------------------|---------|-------------------------|----------------------|
| RuboCop | 1.89.0 / 2026-08-04 | MIT | Documented JSON formatter; fixture the supported range | Phase 1 narrow vertical adapter; Phase 2 hardening. [CITED: https://docs.rubocop.org/rubocop/latest/formatters.html] |
| rubocop-rails | 2.37.0 / 2026-08-16 | MIT | Shares RuboCop JSON; record plugin identity/version | Phase 2 RuboCop capability, not a second process. [CITED: https://docs.rubocop.org/rubocop-rails/latest/usage.html] |
| Minitest | 6.0.6 / 2026-05-01 | MIT | No built-in owned JSON contract; use documented reporter callbacks to emit a RailVerdict-owned format | Phase 2. [CITED: https://github.com/minitest/minitest] |
| RSpec Core | 3.13.6 / 2025-10-19 | MIT | Documented JSON formatter; upstream has no project-owned JSON Schema | Phase 2 with stored fixtures. [CITED: https://rspec.info/features/3-13/rspec-core/formatters/json-formatter/] |
| SimpleCov | 1.1.1 / 2026-08-12 | MIT | Consume public `coverage.json` schema v1; never internal `.resultset.json` | Phase 2 ingestion; Phase 4 activates production changed-scope coverage. [CITED: https://github.com/simplecov-ruby/simplecov] |
| bundler-audit | 0.9.3 / 2025-11-28 | GPL-3.0-or-later | JSON output; record advisory DB revision; separate refresh from offline gate | Phase 2 external adapter. [CITED: https://github.com/rubysec/bundler-audit] |
| Undercover | 0.8.5 / 2026-04-21 | MIT | JSON exists but no versioned public schema was found in prior official-doc review | Defer; overlaps SimpleCov plus RailVerdict diff logic. [VERIFIED: STACK.md] |
| RubyCritic | 5.0.0 / 2026-01-27 | MIT | JSON exists but aggregate/raw contract needs fixtures | Defer; do not adopt its composite score as gate authority. [VERIFIED: STACK.md] |
| Brakeman | 8.0.6 / 2026-08-12 | Brakeman Public Use License | JSON/JUnit/SARIF available | **HOLD. Not shortlisted, supported, or advertised pending written legal/product review.** [CITED: https://github.com/presidentbeef/brakeman/blob/main/LICENSE.md] |
| Prosopite | 2.2.0 / 2026-04-16 | Apache-2.0 | No native stable JSON identified; runtime instrumentation/logger boundary required | Defer to Phase 5/runtime evidence research. [CITED: https://github.com/charkost/prosopite] |
| strong_migrations | 2.8.0 / 2026-05-14 | MIT | Human exception output; useful behavior occurs during migration execution | Defer; never auto-run a target migration. [CITED: https://github.com/ankane/strong_migrations] |

Official registry URLs follow `https://rubygems.org/api/v1/gems/<package>.json`; preserve those URLs beside homepage/license/output sources in the public registry. [VERIFIED: RubyGems API]

### Ruby and Rails Proposal

| Surface | Proposal | Evidence / qualification |
|---------|----------|--------------------------|
| Ruby runtime floor | `>= 3.3` | Ruby 3.3 is in security maintenance, 3.4 and 4.0 are in normal maintenance, and 3.2 is EOL as of the dated official status. [CITED: https://www.ruby-lang.org/en/downloads/branches/] |
| Core lanes | Ruby 3.3, 3.4, 4.0 | Proposal only until the same core suite passes each lane. [VERIFIED: STACK.md] |
| Rails context floor | Rails `>= 8.0` | Rails 8.0/8.1 are the target fixture lines; the gem must not depend on Rails at runtime. [CITED: https://guides.rubyonrails.org/maintenance_policy.html] |
| Rails fixture lanes | Ruby 3.3 + Rails 8.0; Ruby 4.0 + Rails 8.1 | Deliberately non-Cartesian proposal; support begins only after synthetic lanes pass. [VERIFIED: STACK.md] |
| Drop policy | Drop an EOL Ruby line in the next documented minor release while pre-1.0 | Project policy recommendation, not an upstream fact. [VERIFIED: STACK.md] |

## Architecture Patterns

### System Architecture Diagram

This phase produces the contracts on the right; it does not implement any runtime box. [VERIFIED: 00-CONTEXT.md]

```text
Approved source brief + locked CONTEXT + current official evidence
                              |
                              v
                Foundation decisions and draft contracts
     +------------------------+-----------------------------+
     |                        |                             |
     v                        v                             v
Identity/legal docs     Product/architecture/ADRs     Schemas/CLI/security
     |                        |                             |
     +------------------------+-----------------------------+
                              |
                              v
                 script/validate-foundation
      schema | links | identity | ADRs | roadmap | language
                       | provenance | no-production
                              |
                              v
               Is publication clearance recorded?
                    /                     \
                  no                       yes
                  |                         |
       keep publication blocked;     publication may proceed
       Phase 0 records the blocker   under the recorded scope

External boundaries:
- official registries and trademark offices provide dated evidence
- a qualified reviewer owns jurisdiction/similarity conclusions
- private provenance patterns stay outside the public repository
```

### Recommended Project Structure

```text
repository/
├── README.md, PROJECT.md, PHILOSOPHY.md, ARCHITECTURE.md
├── LICENSE, NOTICE, TRADEMARKS.md
├── docs/                 # foundation, analyzers, contracts, security, firewall
│   └── adr/              # exactly 15 foundation records
├── schemas/              # two draft 2020-12 schemas
├── examples/             # two synthetic valid instances
├── script/               # one phase-only validator
└── .planning/            # authoritative roadmap and GSD artifacts
```

No runtime tree exists until Phase 1. [VERIFIED: 00-CONTEXT.md]

### Pattern 1: One Source of Truth per Concern

**What:** One canonical public file owns each mutable fact; other documents summarize and link. Identity/legal evidence lives in `docs/foundation.md`, analyzer facts in `docs/analyzers.md`, schema semantics/CLI in `docs/contracts.md`, and requirement allocation in `.planning/ROADMAP.md`.

**When to use:** Any fact that appears in more than one public artifact.

**Rule:** A summary may repeat stable identity tokens, but versions, evidence timestamps, license qualifications, schema field meaning, and roadmap ownership must not be maintained in parallel tables.

[VERIFIED: 00-CONTEXT.md]

### Pattern 2: Decision Status Is Not Implementation Status

**What:** ADRs may be `Accepted`, while every one states `Implementation status: Not started` and points to its owning future phase.

**When to use:** All fifteen Phase 0 ADRs.

**Rule:** Do not use ADR acceptance to claim the safe runner, adapter, AI, GitHub, MCP, or release path exists.

[VERIFIED: 00-CONTEXT.md]

### Pattern 3: Dated Evidence with Explicit Limitations

**What:** Each external check records query, exact endpoint, UTC/date, result, limitation, and reviewer.

**When to use:** Names, domains, licenses, versions, maintenance state, and legal sources.

**Rule:** A 404 means no record was returned at that instant. It does not mean reserved, cleared, or legally safe.

[CITED: https://www.uspto.gov/trademarks/search/federal-trademark-searching]

### Pattern 4: Offline Strict Draft Schemas

**What:** Each schema declares Draft 2020-12 and an absolute versioned `$id`, contains no network-required references, closes every object, and has a valid synthetic example plus an unknown-field rejection check.

**When to use:** Finding and configuration draft contracts.

**Rule:** Use `additionalProperties: false` for simple objects. If composition (`allOf`/conditional subschemas) is introduced later, use `unevaluatedProperties: false` at the correct boundary rather than redeclaring a complex hierarchy. [CITED: https://json-schema.org/understanding-json-schema/reference/object]

### Anti-Patterns to Avoid

- **Public docs as copied planning prose:** rewrite into a stable public contract and link to one canonical source; do not expose GSD process language as product behavior.
- **“Available” from a 404:** record the exact dated response and its limitation.
- **Trademark policy as a license addendum:** keep it separate and never narrow Apache-2.0 software rights.
- **`blocking` in Finding input:** blocking is derived by policy and belongs in policy/gate output.
- **Support from documentation alone:** a proposed version range is not supported until synthetic lanes and fixtures pass.
- **General validator framework:** one focused script is enough; no Rake task system or gem scaffold.
- **Public private-pattern dictionary:** the detection input itself can disclose private identifiers; store it outside the repository.
- **“Safe subprocess” as sandboxing:** argv isolation, timeouts, and limits do not create an OS sandbox.

## Fifteen ADR Mapping

Each ADR uses `Status: Accepted`, `Decision date: 2026-08-16`, and `Implementation status: Not started`, unless a qualified legal checkpoint requires `Proposed`. Each contains Context, Decision, Consequences, Deferred Work, Related Requirements, and Related Documents. [VERIFIED: 00-CONTEXT.md]

| ADR | Decision owned | Primary requirements | Future implementation owner |
|-----|----------------|----------------------|-----------------------------|
| 0001 Deterministic evidence before merge | Objective evidence precedes opinion; equivalent inputs yield equivalent gate | FND-07, CORE-14, AI-01 | Phase 1 core, Phase 6 equivalence |
| 0002 Rails-first scope | Rails context is the product focus; no generic quality platform | FND-07, RAIL-01..04 | Phase 5 |
| 0003 Local-first fully open source | Core works offline without SaaS/accounts/telemetry/AI | FND-04, FND-07, CORE-02, REL-04 | Phase 1 and Phase 9 |
| 0004 External analyzer processes | Target project owns analyzer installation/version; RailVerdict does not bundle/install/reimplement | FND-05, CORE-05..09, EVID-09 | Phases 1–2 |
| 0005 Canonical Finding | Versioned analyzer-independent evidence with provenance | FND-09, CORE-10 | Phase 1 |
| 0006 Policy-owned gate authority | Only policy evaluation creates decisions/GateResult | FND-07, CORE-11, GIT-08 | Phase 1 |
| 0007 Fingerprint baselines and no-new-debt | Stable versioned identity enables incremental adoption | DEBT-01..10 | Phase 3 |
| 0008 Safe subprocess boundary | Argv, bounded I/O, timeout, cleanup, minimal environment, explicit failure | FND-11, CORE-05..08 | Phase 1 |
| 0009 One-gem structure | One gem/process; add structure only with behavior | FND-13 | Phase 1 onward |
| 0010 Apache-2.0 license and trademark separation | Software rights remain broad; brand confusion rules stay separate | FND-04 | Phase 0 legal docs; release re-review |
| 0011 Optional advisory AI | AI cannot change the default deterministic gate | AI-01, AI-05 | Phase 6 |
| 0012 Provider-independent AI boundary | Provider concerns remain outside core; context/response contracts are bounded | AI-02..08 | Phase 6 |
| 0013 GitHub as an adapter | Local Git/core owns truth; GitHub projects results | GIT-04..08 | Phase 4 |
| 0014 MCP after stable contracts | MCP is read-only/thin and follows stable CLI/domain contracts | MCP-01..03 | Phase 8 |
| 0015 Synthetic public provenance and English-only | Public material is synthetic/English and release-scanned | FND-12, REL-02, REL-08 | Phase 0 policy and Phase 9 enforcement |

The locked context names decision topics, not a one-topic-per-file naming rule. The final fifteen-file set intentionally groups related topics without creating a duplicate ADR set: Rails-first scope is explicit in ADR 0002; policy-owned gate authority in ADR 0001 and ADR 0006; safe subprocess execution in ADR 0002; one-gem architecture in ADR 0009; provider-independent AI in ADR 0008; local-first/open-source operation in ADR 0014; and the remaining topic-to-file assignments are listed above. The integrated validator checks these topic anchors. [RECONCILED: 00-CONTEXT.md and final ADR set]

## Draft Schema and CLI Contracts

### Schema Identity

Use:

- Finding: `https://railverdict.dev/schemas/finding/v1.schema.json`
- Configuration: `https://railverdict.dev/schemas/configuration/v1.schema.json`
- Dialect: `https://json-schema.org/draft/2020-12/schema`

The domain-based `$id` values are draft identifiers, not proof the domain is owned or publication is authorized. If name/domain clearance changes before publication, change the draft URI before any compatibility promise. [VERIFIED: 00-CONTEXT.md]

### Finding Schema Obligations

Required top-level fields: `schema_version`, `id`, `fingerprint`, `origin`, `analyzer`, `rule_id`, `category`, `severity`, `confidence`, `state`, `location`, and `message`. Every nested object is strict. Paths are repository-relative with `/` separators. `blocking` is forbidden as input; future rendered blocking information comes from a policy decision/GateResult. [VERIFIED: 00-CONTEXT.md and ARCHITECTURE.md]

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://railverdict.dev/schemas/finding/v1.schema.json",
  "title": "RailVerdict Finding v1 (draft)",
  "type": "object",
  "required": [
    "schema_version", "id", "fingerprint", "origin", "analyzer",
    "rule_id", "category", "severity", "confidence", "state",
    "location", "message"
  ],
  "properties": {
    "schema_version": { "const": "1.0" },
    "id": { "type": "string", "minLength": 1 },
    "fingerprint": { "type": "string", "pattern": "^sha256:[0-9a-f]{64}$" },
    "origin": { "enum": ["deterministic", "runtime", "ai", "custom"] },
    "analyzer": { "type": "string", "minLength": 1 },
    "rule_id": { "type": "string", "minLength": 1 },
    "category": { "type": "string", "minLength": 1 },
    "severity": { "enum": ["info", "low", "medium", "high", "critical"] },
    "confidence": { "enum": ["low", "medium", "high"] },
    "state": {
      "enum": ["introduced", "existing", "resolved", "changed", "moved", "suppressed", "waived"]
    },
    "location": {
      "type": "object",
      "required": ["path"],
      "properties": {
        "path": { "type": "string", "minLength": 1 },
        "start_line": { "type": "integer", "minimum": 1 },
        "end_line": { "type": "integer", "minimum": 1 }
      },
      "additionalProperties": false
    },
    "message": { "type": "string", "minLength": 1 }
  },
  "additionalProperties": false
}
```

This is a planning example, not the final schema payload. The implementation plan should keep validation invariants such as `end_line >= start_line` either in schema where expressible without extensions or in later domain construction; do not hand-roll a partial schema engine in Phase 0. [VERIFIED: 00-CONTEXT.md]

### Valid Synthetic Finding Example

```json
{
  "schema_version": "1.0",
  "id": "RV-SYNTHETIC-001",
  "fingerprint": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "origin": "deterministic",
  "analyzer": "example_analyzer",
  "rule_id": "Example/LongMethod",
  "category": "maintainability",
  "severity": "medium",
  "confidence": "high",
  "state": "introduced",
  "location": {
    "path": "app/services/catalog_importer.rb",
    "start_line": 12,
    "end_line": 28
  },
  "message": "Synthetic method exceeds the example policy limit"
}
```

### Configuration Schema Obligations

The schema validates the parsed data model, even though the eventual user file is YAML. Require integer `version: 1`; policy `mode`; explicit analyzer entries; strict unknown-field rejection at every level; and no executable YAML, ERB, object tags, secret values, or silent policy environment overrides. Keep the Phase 0 example minimal rather than forecasting every option. [VERIFIED: 00-CONTEXT.md and PITFALLS.md]

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://railverdict.dev/schemas/configuration/v1.schema.json",
  "title": "RailVerdict Configuration v1 (draft)",
  "type": "object",
  "required": ["version", "mode", "analyzers"],
  "properties": {
    "version": { "const": 1 },
    "mode": { "enum": ["advisory", "no_new_debt", "strict"] },
    "analyzers": {
      "type": "object",
      "minProperties": 1,
      "properties": {
        "rubocop": {
          "type": "object",
          "required": ["enabled", "required"],
          "properties": {
            "enabled": { "type": "boolean" },
            "required": { "type": "boolean" }
          },
          "additionalProperties": false
        }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}
```

Valid synthetic configuration:

```json
{
  "version": 1,
  "mode": "no_new_debt",
  "analyzers": {
    "rubocop": {
      "enabled": true,
      "required": true
    }
  }
}
```

### Sample Validation

The phase validator should use the installed validator, validate both schemas themselves, validate both examples, then mutate each valid example by adding `_unexpected` at the root and assert rejection. No network resolution is allowed. [VERIFIED: environment audit]

```bash
python3 -c '
import copy, json, pathlib
from jsonschema import Draft202012Validator
for stem in ("finding-v1", "configuration-v1"):
    schema = json.loads(pathlib.Path(f"schemas/{stem}.schema.json").read_text())
    example = json.loads(pathlib.Path(f"examples/{stem}.json").read_text())
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)
    validator.validate(example)
    unexpected_root = copy.deepcopy(example)
    unexpected_root["_unexpected"] = True
    assert list(validator.iter_errors(unexpected_root)), f"{stem} accepted a root unknown field"
    unexpected_nested = copy.deepcopy(example)
    target = unexpected_nested["location"] if stem == "finding-v1" else unexpected_nested["analyzers"]["rubocop"]
    target["_unexpected"] = True
    assert list(validator.iter_errors(unexpected_nested)), f"{stem} accepted a nested unknown field"
'
```

### Minimal Draft CLI Contract

| Command | Phase ownership | Minimal draft options | Side effect boundary |
|---------|-----------------|-----------------------|----------------------|
| `railverdict init` | Phase 1 | `--config PATH`, `--force` only if overwrite semantics are explicitly documented | May create config only after confirmation/force; not implemented now |
| `railverdict doctor` | Phase 1 | `--config PATH`, `--format console|json` | Observe only; never install or mutate tools |
| `railverdict check` | Phase 1; `--changed` production scope in Phase 4 | `--config PATH`, `--format console|json`, `--changed`, `--base REV` | Ordinary check is read-only |
| `railverdict baseline create` | Phase 3 | `--config PATH`, `--output PATH`, `--format console|json` | Explicit baseline write only after complete trusted run |
| `railverdict findings` | Phase 1/3 | `--config PATH`, `--format console|json` | Read-only projection |

Global draft options are `--help` and `--version`. Do not add AI, GitHub, MCP, autofix, or arbitrary analyzer-command flags. Do not allow environment variables to silently override policy. [VERIFIED: 00-CONTEXT.md]

Draft stream and exit contract:

| Exit | Meaning |
|-----:|---------|
| `0` | Completed trustworthy gate with `PASS` or non-blocking `WARN` |
| `1` | Completed trustworthy gate with policy `FAIL` |
| `2` | No trustworthy completed gate: usage, configuration/schema/baseline, required tool, timeout, parser, or internal failure |
| `130` | User interruption after child cleanup |

In JSON mode, stdout is exactly one schema-valid JSON document plus a newline; diagnostics/progress are stderr only; reporters never call `exit`; and the CLI performs the single result-to-exit mapping. Findings and maps are deterministically ordered. Every word above remains **draft** until Phase 1 tests prove it. [VERIFIED: 00-CONTEXT.md and ARCHITECTURE.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Software license | Custom “Apache-like” text | Official Apache-2.0 text | Small wording changes can alter rights and destroy standard-license clarity. [CITED: https://www.apache.org/licenses/LICENSE-2.0.txt] |
| Trademark clearance | A script that declares a name safe | Official offices plus qualified legal review | Similarity, related goods/services, common-law use, and jurisdiction require legal judgment. [CITED: https://www.uspto.gov/trademarks/search/federal-trademark-searching] |
| JSON Schema validation | Partial Ruby key/type checker | Installed Draft 2020-12 validator | A partial validator gives false confidence about a public contract. [CITED: https://json-schema.org/draft/2020-12] |
| Analyzer licensing | One blanket “permissive” label | Dated per-tool registry and source links | Licenses and product-use boundaries differ; Brakeman is the current counterexample. [CITED: https://github.com/presidentbeef/brakeman/blob/main/LICENSE.md] |
| Language/provenance assurance | Accent-only or secret-only scan | Narrow automated scan plus external private pattern corpus and manual review | English violations can be ASCII; private provenance is broader than credentials. [VERIFIED: PITFALLS.md] |
| Documentation system | Site generator, plugin framework, or docs DSL | Markdown and relative links | No Phase 0 requirement needs generation or hosting. [VERIFIED: STACK.md] |
| Roadmap traceability | Manually maintained second mapping | Parse REQUIREMENTS and canonical ROADMAP | Duplicate mappings drift and obscure one-to-one ownership. [VERIFIED: codebase roadmap audit] |

**Key insight:** Phase 0’s hard problems are legal judgment and cross-document consistency. More framework code cannot solve either; use primary evidence, explicit human gates, and one small validator.

## Security Domain

### Threat Model Matrix

| Threat | STRIDE | Required control documented in Phase 0 | Later proof owner |
|--------|--------|-----------------------------------------|-------------------|
| Required analyzer failure becomes zero findings/false PASS | Tampering | Separate completeness from gate status; required evidence must succeed | Phase 1/2 contract tests |
| Repository/config/path causes shell execution | Elevation / Tampering | Fixed executable plus argv, verified working directory, no shell strings | Phase 1 runner tests |
| Child hangs, floods output, or leaves descendants | Denial of Service | Monotonic timeout, bounded concurrent drains, process-group cleanup, reaping | Phase 1 OS matrix |
| Environment/output leaks secrets | Information Disclosure | Minimal environment, closed descriptors, bounded/redacted diagnostics | Phase 1 canary tests |
| Baseline change absorbs new debt | Tampering | Checks read-only; explicit baseline creation from complete run; reviewable diff | Phase 3 |
| Repository text prompt-injects optional AI | Tampering / Spoofing | Deterministic context selection, instruction/data separation, no write tools, strict response schema | Phase 6 |
| Fork code receives privileged token/AI/publisher credentials | Elevation / Information Disclosure | Unprivileged `pull_request`, no secrets, no privileged execution of fork artifacts | Phase 4 |
| Compromised dependency/action or rebuilt artifact is published | Tampering | Reviewed dependencies/action SHAs, protected OIDC, build once, digest chain | Phase 9 |
| Private provenance enters tree/history/gem/media/artifacts | Information Disclosure | Synthetic-only policy; external private-pattern scan across every surface; zero unresolved matches | Phase 0 policy / Phase 9 gate |
| Trademark evidence is overstated | Spoofing | Dated limitations and qualified human approval; publication blocked until signed | Phase 0 external checkpoint |

[VERIFIED: PITFALLS.md]

### Applicable OWASP ASVS 5.0.0 Categories

ASVS is a web-application standard, so use it as a control catalog rather than claiming RailVerdict certification. Version-qualify any individual control reference because ASVS identifiers may change. [CITED: https://owasp.org/www-project-application-security-verification-standard/]

| ASVS 5.0 category | Applies | RailVerdict control |
|-------------------|---------|---------------------|
| V1 Encoding and Sanitization | Yes | Untrusted paths/output; `v5.0.0-1.2.5` specifically supports parameterized OS command execution. [CITED: https://github.com/OWASP/ASVS/tree/v5.0.0] |
| V2 Validation and Business Logic | Yes | Strict config/schema, explicit evidence states, fail-closed policy. |
| V3 Web Frontend Security | No | No web frontend or hosted dashboard. |
| V4 API and Web Service | No in Phase 0 | No service/API; future providers remain adapters. |
| V5 File Handling | Yes | Repository-relative paths, archive/media provenance, safe temp/artifact handling; `v5.0.0-5.3.2` is relevant to path construction. [CITED: https://github.com/OWASP/ASVS/tree/v5.0.0] |
| V6 Authentication | No | No accounts/authentication. |
| V7 Session Management | No | No sessions. |
| V8 Authorization | Yes | Document privileged CI/release boundaries and least privilege; `v5.0.0-8.1.1` requires authorization rules to be documented. [CITED: https://github.com/OWASP/ASVS/tree/v5.0.0] |
| V9 Self-contained Tokens | No | No product token contract. |
| V10 OAuth and OIDC | No | RubyGems OIDC is release infrastructure in Phase 9, not product OAuth. |
| V11 Cryptography | Yes later | Use standard SHA-256/digest/signature mechanisms; never hand-roll cryptography. |
| V12 Secure Communication | Yes later | Remote AI and publication use authenticated TLS/provider boundaries; no Phase 0 implementation. |
| V13 Configuration | Yes | Strict data-only config, explicit precedence, minimal environment, safe defaults. |
| V14 Data Protection | Yes | Classify repository source/secrets and forbid silent remote transmission; `v5.0.0-14.1.1/14.1.2` require classification/protection rules. [CITED: https://github.com/OWASP/ASVS/tree/v5.0.0] |
| V15 Secure Coding and Architecture | Yes | Four layers, dependency direction, trust boundaries, secure-by-design ADRs. |
| V16 Security Logging and Error Handling | Yes | Non-echoing provenance reports, redacted diagnostics, escaped untrusted output; `v5.0.0-16.4.1` addresses log injection. [CITED: https://github.com/OWASP/ASVS/tree/v5.0.0] |
| V17 WebRTC | No | No WebRTC capability. |

### Information-Firewall Policy Shape

The public policy must define:

1. **Allowed provenance:** freshly authored synthetic examples in generic public domains only.
2. **Prohibited provenance:** private source/data/names/identifiers/architecture/fixtures/metrics/screenshots/logs/prompts/paths/branches/infrastructure/operational details.
3. **English scope:** source, docs, schemas, examples, workflows, issue/PR templates, commits, release notes, artifact metadata; only file-level manifest exceptions for explicit i18n fixtures.
4. **Scan surfaces:** tracked tree, full Git history/all refs, generated gem, source archives, release archives, images/media metadata, documentation, release notes, CI caches/artifacts, and installed-artifact manifest.
5. **Private detection input:** maintainer-controlled pattern file outside Git; never print matched values or commit the corpus.
6. **Report shape:** date, revision, scanner/version, surfaces, counts/categories, artifact digests, exception decisions, reviewer; paths may be reported only when they do not reveal a private value.
7. **Failure behavior:** any unresolved match blocks public release; credentials are rotated/revoked before cleanup.
8. **Phase distinction:** Phase 0 creates policy and validates current tree/history scope; Phase 9 enforces package/archive/media/release surfaces when those artifacts exist.

[VERIFIED: 00-CONTEXT.md and PITFALLS.md]

## Common Pitfalls

### Pitfall 1: Treating Name Signals as Clearance
**What goes wrong:** A registry/domain 404 is described as legal availability.
**Why it happens:** Technical identifiers are easy to query; confusing similarity, related goods/services, and common-law use are not.
**How to avoid:** Preserve limitations and require the qualified checkpoint before publication.
**Warning signs:** “available,” “clear,” or “safe” without named jurisdiction/reviewer/date. [CITED: https://www.uspto.gov/trademarks/search/federal-trademark-searching]

### Pitfall 2: Legal Files Quietly Conflict
**What goes wrong:** NOTICE or trademark text imposes a “no resale,” “noncommercial,” or modified-product restriction on software rights.
**Why it happens:** Brand protection is written as a license condition.
**How to avoid:** Keep LICENSE exact, NOTICE factual, and TRADEMARKS limited to brand/source confusion.
**Warning signs:** Trademark text regulates copying, modification, redistribution, price, consulting, or internal use. [CITED: https://www.apache.org/licenses/LICENSE-2.0.txt]

### Pitfall 3: Schema Looks Strict but Nested Objects Stay Open
**What goes wrong:** The root rejects unknown fields while `location` or analyzer configuration silently accepts them.
**Why it happens:** JSON Schema permits additional properties by default.
**How to avoid:** Close each object and mutate valid examples at root and nested levels.
**Warning signs:** Only one `additionalProperties: false` in a schema with multiple object nodes. [CITED: https://json-schema.org/understanding-json-schema/reference/object]

### Pitfall 4: Finding Carries Policy Authority
**What goes wrong:** An adapter can set `blocking`, mixing evidence with the gate decision.
**Why it happens:** The original conceptual example included a convenience field.
**How to avoid:** Forbid `blocking` in Finding input; derive it in policy/GateResult views.
**Warning signs:** Analyzer parser or schema accepts blocking/pass/fail. [VERIFIED: 00-CONTEXT.md]

### Pitfall 5: Documentation Claims Implemented Support
**What goes wrong:** Proposed Ruby/Rails/analyzer ranges are marketed as supported without lanes/fixtures.
**Why it happens:** Research tables are copied into README as promises.
**How to avoid:** Label all Phase 0 surfaces draft/proposed and state the proving phase.
**Warning signs:** Install instructions, release badges, or “supports” without test evidence. [VERIFIED: 00-CONTEXT.md]

### Pitfall 6: Brakeman Slips Back into the Shortlist
**What goes wrong:** Its technical value overrides the explicit license/product hold.
**Why it happens:** Older assumptions described Brakeman as MIT or treated external invocation as automatic approval.
**How to avoid:** Registry disposition is HOLD and all shortlists exclude it until the written decision exists.
**Warning signs:** Brakeman appears in “supported,” “recommended install,” or Phase 2 deliverables without a checkpoint. [CITED: https://github.com/presidentbeef/brakeman/blob/main/LICENSE.md]

### Pitfall 7: Validation Script Becomes a Gem Skeleton
**What goes wrong:** Phase 0 adds Rake, Bundler, Minitest structure, executable product code, or CI workflows.
**Why it happens:** Documentation checks are scaffolded like application tests.
**How to avoid:** One phase-only script, existing runtimes, no dependencies, and an explicit prohibited-path assertion.
**Warning signs:** `lib/`, `exe/`, gemspec, Gemfile, Rakefile, or workflows appear. [VERIFIED: 00-CONTEXT.md]

### Pitfall 8: English/Secret Scan Is Mistaken for Provenance Proof
**What goes wrong:** Accent scanning or generic secret detection misses ASCII non-English prose and non-secret private provenance.
**Why it happens:** Easily automated checks are treated as complete.
**How to avoid:** Layer deterministic checks, an external private corpus, and manual review; preserve only counts/categories.
**Warning signs:** “secret scan passed” is the only public-safety evidence. [VERIFIED: PITFALLS.md]

## Roadmap Validation

The current `.planning/REQUIREMENTS.md` contains 85 unique v1 IDs, and the current `.planning/ROADMAP.md` lists each exactly once across Phases 0–9. The parser check passed on 2026-08-16. [VERIFIED: local Ruby audit]

The roadmap preserves the required order and corrected ownership:

```text
0 foundation
  -> 1 trustworthy core
  -> 2 evidence ecosystem (pure changed-line calculation only)
  -> 3 fingerprints/baselines/policy
  -> 4 Git scope and production changed coverage
  -> 5 bounded Rails context
  -> 6 optional AI
  -> 7 repair packets
  -> 8 MCP
  -> 9 compatibility/release hardening
```

[VERIFIED: .planning/ROADMAP.md]

Preserve these roadmap invariants:

- FND-01..14 belong only to Phase 0.
- Every v1 ID appears in exactly one phase Requirements line.
- Phases are numbered 0 through 9 once and execute in order.
- Every phase has goal, dependency, observable success criteria, exit gate, and non-goals.
- Phase 2 tests changed-line calculations only against injected line sets; Phase 4 owns trustworthy Git scope and production changed coverage.
- Brakeman remains unsupported in Phase 2 until written review.
- Phase 0 records the unresolved trademark checkpoint explicitly; clearance is a publication gate, not a prerequisite for accurately completing the foundation record.

[VERIFIED: 00-CONTEXT.md and .planning/ROADMAP.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Ruby | Link, identity, roadmap, ADR, and no-production checks | ✓ | 3.4.5 | None needed |
| Git | Tree/history scope and exact-file commit | ✓ | 2.43.0 | None needed |
| ripgrep | Fast repository scans | ✓ | 15.2.0 | Ruby file traversal |
| Python 3 | JSON Schema validation host | ✓ | 3.12.3 | Add a human checkpoint; do not install a project dependency silently |
| Python `jsonschema` | Draft 2020-12 validation | ✓ | 4.10.3 | Later `json_schemer` only when runtime validation is implemented |
| `file` | Binary/media/archive classification | ✓ | 5.45 | Extension plus manual review |
| Qualified trademark reviewer | FND-03 / publication clearance | ✗ not evidenced | — | None; blocking human/external publication gate |
| Brazil and launch-jurisdiction search evidence | FND-01/FND-03 | ✗ not captured | — | None; blocking human/external gate |
| Private provenance pattern corpus | Full private-information check | ✗ not supplied to this session | — | Policy and public known-term scan now; final private scan requires maintainer-controlled input |

**Missing dependencies with no fallback:** qualified trademark review and documented jurisdiction results. These block publication, but Phase 0 can complete by recording the unresolved status without claiming clearance. [VERIFIED: 00-CONTEXT.md]

**Missing dependencies with fallback:** the private provenance corpus does not block writing the policy, but it blocks a claim that a complete private-information scan passed. [VERIFIED: 00-CONTEXT.md]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | One repository script using Ruby 3.4 stdlib plus existing Python `jsonschema` 4.10.3 |
| Config file | None — see Wave 0 |
| Quick run command | `script/validate-foundation schemas links identity` |
| Full suite command | `script/validate-foundation` |

The script is validation tooling only. It must not share code with the future RailVerdict CLI or create a product namespace. [VERIFIED: 00-CONTEXT.md]

### Required Subchecks

| Subcheck | Runnable behavior | Pass condition |
|----------|-------------------|----------------|
| `schemas` | Parse both schema/example JSON files; run `Draft202012Validator.check_schema`; validate examples; inject unknown root and nested fields | Valid examples pass and every unknown mutation fails |
| `links` | Scan tracked Markdown inline links; skip `http(s)`, mail, and pure anchors; resolve relative file targets from the source file | Every relative target exists; anchor checking may be deferred until headings become complex |
| `identity` | Assert the seven identity values in `docs/foundation.md`; scan public files for stale uppercase package/CLI/config forms; allow historical `LineClear` only in the named decision-history section; require an explicit provisional/publication-blocked state until qualified clearance is recorded | Required map present, no conflicting public identity, and publication state is accurate |
| `adrs` | Enumerate `docs/adr/*.md`; verify filenames 0001–0015 and required headings/status/implementation marker | Exactly fifteen complete records |
| `roadmap` | Parse v1 IDs before `## v2 Requirements`; parse every Roadmap Requirements line; compare counts/tallies; verify phases 0..9/dependencies | 85 unique IDs, mapped once, no missing/extra/duplicate |
| `language` | Validate UTF-8; scan public prose/source for a narrow reviewed Portuguese marker/diacritic list; allow only explicit file-level i18n manifest entries | No unexplained hit; manual review still required because ASCII prose can evade automation |
| `provenance` | Scan tracked tree and full history with a maintainer-supplied external pattern file; classify any gem/archive/media/artifact surfaces; never echo matched values | Zero unresolved matches; absent artifact classes are reported `not applicable`, not silently skipped |
| `no-production` | Assert no `lib/`, `exe/`, product `bin/`, gemspec, Gemfile, Rakefile, analyzer/Rails fixtures, GitHub workflows, release automation, AI, or MCP implementation | Only approved Phase 0 artifact paths exist outside `.planning`/AGENTS |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FND-01 | Name evidence table has all surfaces, dates, URLs, results, limitations | structure + manual legal | `script/validate-foundation identity links` | ❌ Wave 0 |
| FND-02 | Identity map is unique and consistent | contract | `script/validate-foundation identity` | ❌ Wave 0 |
| FND-03 | Publication blocker and current clearance state are explicit; unresolved status is a valid Phase 0 result | structure + human publication checkpoint | `script/validate-foundation identity`; qualified review remains external | ❌ Wave 0 / publication blocker |
| FND-04 | LICENSE exact; NOTICE informational; trademark terms do not narrow rights | checksum/text + human legal | `script/validate-foundation legal` | ❌ Wave 0 |
| FND-05 | Eleven registry rows include every required field and Brakeman HOLD | structure | `script/validate-foundation analyzers` | ❌ Wave 0 |
| FND-06 | Ruby/Rails proposal cites official status and labels lanes unproven | structure | `script/validate-foundation analyzers links` | ❌ Wave 0 |
| FND-07 | Product/philosophy/architecture/non-goals/dependencies are linked | structure | `script/validate-foundation links identity` | ❌ Wave 0 |
| FND-08 | Exactly fifteen complete ADRs | structure | `script/validate-foundation adrs` | ❌ Wave 0 |
| FND-09 | Two strict schemas and valid examples; unknowns rejected | schema contract | `script/validate-foundation schemas` | ❌ Wave 0 |
| FND-10 | CLI commands/options/streams/order/exits documented as draft | structure | `script/validate-foundation contracts` | ❌ Wave 0 |
| FND-11 | Threat assets/boundaries/actors/control categories complete | structure + security review | `script/validate-foundation security` | ❌ Wave 0 |
| FND-12 | Synthetic/English/provenance rules and all scan surfaces present | automated scope + manual provenance | `script/validate-foundation language provenance` | ❌ Wave 0 |
| FND-13 | One-gem future structure documented; no production implementation exists | negative assertion | `script/validate-foundation no-production` | ❌ Wave 0 |
| FND-14 | All 85 v1 requirements map exactly once in ordered phases | contract | `script/validate-foundation roadmap` | ✅ logic proven inline; script gap remains |

### Sampling Rate

- **Per task commit:** run the relevant subchecks plus `git diff --check`.
- **Per wave merge:** run `script/validate-foundation`.
- **Phase gate:** full validation green, manual legal/security/provenance reviews recorded, and the unresolved publication gate stated consistently before `$gsd-verify-work` can mark Phase 0 complete. Clearance is required before publication, not before recording this foundation.

### Wave 0 Gaps

- [ ] `script/validate-foundation` — one dependency-free phase validator with the subcommands above.
- [ ] `schemas/finding-v1.schema.json` and `schemas/configuration-v1.schema.json` — Draft 2020-12 contracts.
- [ ] `examples/finding-v1.json`, `examples/configuration-v1.yml`, and `examples/result-v1.json` — synthetic valid instances.
- [ ] External private-pattern input path and reviewer procedure — never commit the pattern values.
- [ ] Publication-gate record — initially unresolved; later qualified clearance remains human/external and is not automatable.

## External Blockers and Open Questions

### Blocking Publication

1. **Launch-jurisdiction trademark search and qualified review**
   - What we know: exact technical identifier surfaces returned no current record on the research date. [VERIFIED: official registry/API queries]
   - What is unclear: RailVerdict similarity, phonetic/commercial-impression conflicts, related goods/services, common-law use, Brazil INPI, other intended launch jurisdictions, ownership, and counsel’s conclusion.
   - Recommendation: planner must create the publication-gate record with its current unresolved status and required evidence fields. A later `checkpoint:human-action` records the dated clear/reject/rename outcome before any publication; Phase 0 does not invent that outcome. [CITED: https://www.uspto.gov/trademarks/search/federal-trademark-searching]

2. **Legal identity for NOTICE/trademark ownership**
   - What we know: Apache-2.0 and separate trademark terms are locked. [VERIFIED: 00-CONTEXT.md]
   - What is unclear: the exact copyright/trademark owner/contact text to publish.
   - Recommendation: draft without invented legal ownership; qualified review supplies final factual names before publication.

### Blocking Only Later Work or Publication

3. **Brakeman product-use decision**
   - What we know: RubyGems reports “Brakeman Public Use License,” and official license text defines product/service boundaries. [CITED: https://github.com/presidentbeef/brakeman/blob/main/LICENSE.md]
   - What is unclear: the approved RailVerdict integration/disclosure/commercial boundary.
   - Recommendation: keep HOLD in Phase 0 registry and add no adapter/install promise until a written decision exists.

4. **Private provenance corpus and full release surfaces**
   - What we know: Phase 0 has no gem, archive, media, release, or CI artifact to inspect. [VERIFIED: codebase inventory]
   - What is unclear: the private maintainer pattern corpus and eventual artifact locations.
   - Recommendation: finish the policy now, scan current tree/history with external input when supplied, and require complete artifact scans in Phase 9.

### Non-Blocking Draft Decisions to Record

5. **Configuration schema runtime enforcement point**
   - Current recommendation: Phase 0 validates examples only; Phase 1 decides whether `json_schemer` validates every run or artifact boundaries. [VERIFIED: STACK.md]

6. **CLI `WARN` exit**
   - Current recommendation: draft exit 0 for non-blocking WARN, but label it proposed until CI/agent consumer tests validate it. [VERIFIED: ARCHITECTURE.md]

## State of the Art

| Old / stale approach | Current Phase 0 approach | When changed / observed | Impact |
|----------------------|--------------------------|-------------------------|--------|
| Working identity LineClear | Selected identity RailVerdict, still blocked for publication | 2026-08-16 project decision | Public docs must preserve rename rationale and never publish under the rejected identity. [VERIFIED: PROJECT.md] |
| JSON Schema dialect left implicit | Draft 2020-12 declared in every root schema | Draft published 2022; selected for this project 2026-08-16 | Validator behavior is explicit and strict unknown-field tests are portable. [CITED: https://json-schema.org/draft/2020-12] |
| Unknown object fields accepted by default | `additionalProperties: false` at each simple object; `unevaluatedProperties: false` when composition requires it | Draft 2019-09+ feature, retained in 2020-12 | Typos cannot silently change config or contract meaning. [CITED: https://json-schema.org/understanding-json-schema/reference/object] |
| ASVS 4.0-era category references | ASVS 5.0.0 version-qualified references | ASVS 5.0.0 released 2025-05-30 | Security docs should use current chapter names/IDs and avoid claiming web-app certification. [CITED: https://owasp.org/www-project-application-security-verification-standard/] |
| `rubocop-rails` 2.36.0 in earlier STACK snapshot | 2.37.0 official registry snapshot | Published 2026-08-16 | Phase artifact must use the new dated value and recheck before implementation. [VERIFIED: RubyGems API] |
| Brakeman casually treated as an early security adapter | Explicit HOLD under current Public Use License | Current 8.0.6 registry/license snapshot | Technical value does not override written legal/product review. [CITED: https://github.com/presidentbeef/brakeman/blob/main/LICENSE.md] |

**Deprecated/outdated:**

- Uppercase gem/CLI/config forms from the original brief are superseded by `rail_verdict`, `railverdict`, and `.railverdict.yml`. [VERIFIED: 00-CONTEXT.md]
- The earlier LineClear schema/fingerprint namespace is historical research only and must not appear in public draft contracts. [VERIFIED: codebase grep]
- `rubocop-rails` 2.36.0 is no longer the current registry version. [VERIFIED: RubyGems API]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The preliminary exact current-product web search returned no obvious exact RailVerdict result, but no authoritative absence claim is possible. | Name Evidence Record | An existing product/common-law use may conflict; qualified multi-source review remains mandatory. |

No assumed claim authorizes publication, package reservation, or legal clearance.

## Sources

### Primary (HIGH source authority; MEDIUM session confidence)

- `https://rubygems.org/api/v1/gems/rail_verdict.json`, `rail-verdict.json`, and `railverdict.json` — exact package surface checks.
- `https://api.github.com/orgs/railverdict`, `https://api.github.com/repos/railverdict/railverdict`, and exact-name repository search — organization/repository checks.
- `https://pubapi.registry.google/rdap/domain/railverdict.dev`, `https://rdap.verisign.com/com/v1/domain/railverdict.com`, and `https://rdap.publicinterestregistry.org/rdap/domain/railverdict.org` — domain RDAP checks.
- `https://www.uspto.gov/trademarks/search/federal-trademark-searching` — clearance-search limits, similarity, related goods/services, and legal-review guidance.
- `https://tmsearch.uspto.gov/`, `https://www.wipo.int/en/web/global-brand-database/index`, `https://www.tmdn.org/tmview/`, and `https://www.gov.br/inpi/pt-br/servicos/marcas` — required official trademark search surfaces.
- `https://www.apache.org/licenses/LICENSE-2.0.txt`, `https://www.apache.org/legal/apply-license.html`, and `https://www.apache.org/foundation/marks/` — license, NOTICE, and trademark separation.
- `https://json-schema.org/draft/2020-12` and `https://json-schema.org/understanding-json-schema/reference/object` — dialect and strict object behavior.
- `https://www.ruby-lang.org/en/downloads/branches/`, `https://guides.rubyonrails.org/maintenance_policy.html`, and `https://guides.rubyonrails.org/upgrading_ruby_on_rails.html` — Ruby/Rails proposal evidence.
- Official RubyGems API pages and repositories listed in the analyzer snapshot — versions, dates, licenses, sources, and output contracts.
- `https://owasp.org/www-project-application-security-verification-standard/` and `https://github.com/OWASP/ASVS/tree/v5.0.0` — current ASVS version/categories/controls.

### Project Evidence (HIGH confidence)

- `.planning/phases/00-product-naming-and-legal-foundation/00-CONTEXT.md` — locked Phase 0 decisions and scope.
- `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, and `.planning/STATE.md` — canonical project/requirements/roadmap state.
- `.planning/research/SUMMARY.md`, `STACK.md`, `FEATURES.md`, `ARCHITECTURE.md`, and `PITFALLS.md` — prior official-source synthesis and risks.
- Approved source brief `/home/pedro/.codex/attachments/d21c22a3-b326-4884-b5b4-4a659b07b18d/pasted-text-1.txt` — required foundation artifacts and original product intent.
- `AGENTS.md` — repository constraints and workflow rules.

### Tertiary (LOW confidence)

- Exact general web search for `RailVerdict` / `RAILVERDICT` — discovery only, recorded as assumption A1; not legal evidence.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — no package install; tools were probed locally and standards are official.
- Architecture/artifact map: HIGH — directly constrained by locked context and source brief.
- Naming technical surfaces: MEDIUM — official APIs/RDAP were queried, but status can change immediately.
- Legal/trademark clearance: LOW until the external checkpoint — this research deliberately does not offer legal advice.
- Analyzer registry: MEDIUM — versions/licenses were refreshed from official sources; output/support contracts still require later fixtures.
- Security controls: MEDIUM — grounded in official ASVS/OWASP and project threat research; runtime proofs belong to later phases.
- Roadmap: HIGH — 85 unique v1 requirements currently map exactly once and the parser check passed.

**Research date:** 2026-08-16
**Valid until:** 2026-08-23 for name/version/license snapshots; 2026-09-15 for stable standards and architecture recommendations. Recheck all external facts immediately before reservation, implementation, or publication.
