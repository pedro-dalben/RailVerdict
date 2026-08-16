# Phase 0: Product, Naming and Legal Foundation - Context

**Gathered:** 2026-08-16
**Status:** Ready for planning
**Source:** PRD Express Path (`/home/pedro/.codex/attachments/d21c22a3-b326-4884-b5b4-4a659b07b18d/pasted-text-1.txt`)

<domain>
## Phase Boundary

Phase 0 delivers the complete research-backed foundation needed to begin implementation: final-name analysis and identity mapping; Apache-2.0, NOTICE, and trademark terms; analyzer licensing and support research; product, philosophy, architecture, ADR, schema, CLI, repository, security, information-firewall, and roadmap contracts. It produces documentation and draft contracts only. It must not add a gem skeleton, runtime code, analyzer execution, CI integration, AI, GitHub integration, MCP, or publication.

The phase can record RailVerdict as the selected identity, but public use remains blocked until launch-jurisdiction searches, including Brazil, and qualified trademark review are explicitly cleared. Phase completion records this unresolved publication gate rather than representing legal clearance.

</domain>

<decisions>
## Implementation Decisions

### Product identity and legal boundary
- Use one identity everywhere: project `RailVerdict`, gem `rail_verdict`, Ruby namespace `RailVerdict`, executable `railverdict`, configuration `.railverdict.yml`, repository identity `railverdict`, and schema namespace rooted in `https://railverdict.dev/schemas/` unless the name-clearance record requires another non-breaking draft URI.
- Preserve dated evidence for RubyGems, GitHub, domain, current-product, and preliminary trademark checks. Distinguish verified availability from inference and legal advice.
- Treat RailVerdict as provisional for publication. Do not create public branding, publish packages, or claim trademark clearance until documented launch-jurisdiction and qualified review gates are cleared.
- License the project under Apache License 2.0. Keep NOTICE and trademark rules separate; trademark terms may restrict misleading official status or endorsement but must not narrow Apache-2.0 software rights.

### Product and architecture
- Define RailVerdict as a local-first, fully open-source Rails verification framework, not a SaaS, hosted dashboard, analyzer, LLM, editor, or autonomous coding agent.
- Make the default merge decision deterministic: identical repository state, configuration, analyzer versions, and baseline produce the same gate regardless of AI.
- Document four one-way layers: evidence collection; deterministic verification core; optional intelligence; and CLI, CI, GitHub, coding-agent, and future MCP consumers.
- Only policy evaluation owns gate authority. Analyzer findings are evidence, reporters are projections, and AI remains optional and advisory.
- Keep external analyzers in target-project processes; do not bundle, silently install, or reimplement them.
- Keep one gem and one process. Defer directories and abstractions without Phase 1 behavior.

### Analyzer and platform research
- Maintain a dated analyzer registry for Minitest, RSpec, RuboCop, rubocop-rails, SimpleCov, Undercover, RubyCritic, Brakeman, Prosopite, bundler-audit, and strong_migrations.
- For each analyzer record homepage, current license, commercial-use considerations, installation, whether it is bundled, proposed version policy, native output, execution cost, and disposition.
- Do not put Brakeman in the committed adapter shortlist until a written legal/product decision addresses its current custom license and product-use boundary.
- Propose Ruby and Rails support from official maintenance status and synthetic compatibility lanes; do not imply support before those lanes pass.

### Foundation decision records
- Create fifteen initial ADRs covering: deterministic evidence before merge; Rails-first scope; local-first fully open source; external analyzer processes; canonical Finding; policy-owned gate authority; fingerprint baselines and no-new-debt; safe subprocess boundary; one-gem structure; Apache-2.0 plus trademark separation; optional advisory AI; provider-independent AI boundary; GitHub as an adapter; MCP after stable contracts; and synthetic-only public provenance with English-only repository content.
- ADRs must identify status, context, decision, consequences, and deferred work. They describe foundation choices, not implemented behavior.

### Draft public contracts
- Publish versioned JSON Schema 2020-12 drafts for canonical Finding and configuration, with valid synthetic examples and explicit rejection of unknown fields.
- Keep evidence separate from policy: `Finding` must not accept analyzer-supplied blocking authority. Any rendered blocking state is derived from a policy decision.
- Document draft CLI commands `init`, `doctor`, `check`, `baseline create`, and `findings`; options; deterministic ordering; exactly one JSON document on stdout in JSON mode; diagnostics on stderr; and proposed stable exits for pass, policy failure, incomplete/tool/configuration failure, and interruption.
- Label every pre-implementation schema, exit, support, and compatibility surface as a draft rather than a proven promise.

### Security, privacy, and provenance
- Threat-model false PASS, hostile repositories and output, subprocess handling, AI transmission and prompt injection, fork workflows, dependency and release supply chain, baseline poisoning, and artifact substitution.
- Require executable-plus-argv process boundaries, bounded I/O, timeouts, process-tree cleanup, minimal environment, explicit incomplete evidence, least-privilege CI, build-once publication, and opt-in remote AI with inspection and redaction.
- Treat source repositories, analyzer output, Git metadata, pull requests, model input, and model output as untrusted data.
- Permit only synthetic public fixtures and examples. Require English-only repository prose and release-time provenance scanning across tree, history, gem, archives, media metadata, documentation, release notes, and CI artifacts.
- Never copy private IntegrarPlus code, data, names, identifiers, architecture, fixtures, metrics, screenshots, logs, or operational details into the project.

### Roadmap and phase gate
- Preserve the approved Phase 0 through Phase 9 order and map every v1 requirement to exactly one phase with observable success and exit criteria.
- Phase 2 may define and fixture-test changed-line coverage calculations against injected line sets; production Git-scoped changed coverage belongs to Phase 4.
- Phase 0 ends only when its artifacts are mutually consistent, every FND requirement is evidenced, the identity decision and remaining publication blocker are explicit, and no production core implementation exists.

### the agent's Discretion
- Group closely related requirements into the fewest clear public documents without omitting any requested artifact or ADR.
- Choose filenames, document cross-links, table layouts, schema `$id` suffixes, and synthetic example values.
- Add only small validation scripts or standard commands needed to prove JSON, schema examples, link targets, requirement coverage, English-only scope, and the absence of production code. Prefer existing or standard tools and do not add dependencies for documentation-only checks.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product scope and requirements
- `.planning/PROJECT.md` — Product definition, identity, constraints, active scope, and publication blocker.
- `.planning/REQUIREMENTS.md` — Canonical v1 requirements; Phase 0 owns FND-01 through FND-14.
- `.planning/ROADMAP.md` — Fixed Phase 0 boundary, success criteria, exit gate, dependencies, and later-phase ownership.
- `/home/pedro/.codex/attachments/d21c22a3-b326-4884-b5b4-4a659b07b18d/pasted-text-1.txt` — Approved source brief and required Phase 0 artifacts.

### Research evidence
- `.planning/research/SUMMARY.md` — Synthesized recommendations, conflicts, phase implications, and decisions required before Phase 1.
- `.planning/research/FEATURES.md` — Competitive landscape, naming collision evidence, and product differentiation.
- `.planning/research/STACK.md` — Ruby/Rails support, analyzer licenses and outputs, packaging, and toolchain recommendations.
- `.planning/research/ARCHITECTURE.md` — Layering, contract, dependency, CLI, schema, and repository guidance.
- `.planning/research/PITFALLS.md` — False-PASS, subprocess, AI, fork, supply-chain, and provenance risks and controls.

</canonical_refs>

<specifics>
## Specific Ideas

- Keep the public foundation terse and operational: every claim should be either dated evidence, an explicit decision, a draft contract, or a clearly labeled unresolved gate.
- A reader should be able to trace name → package/namespace/CLI/config/schema, analyzer → license/output/disposition, requirement → roadmap phase, and threat → required control without searching outside the repository.
- The minimum useful repository at Phase 0 is documentation, license text, draft schemas, synthetic schema examples, and validation evidence—nothing executable as a product.

</specifics>

<deferred>
## Deferred Ideas

- Phase 1: strict configuration loading, `RunContext`, safe process execution, narrow RuboCop adapter, canonical runtime objects, deterministic policy, reporters, and CLI behavior.
- Phases 2–5: analyzer breadth, coverage, fingerprints, baselines, waivers, Git/CI, and bounded Rails context.
- Phases 6–8: opt-in AI, deterministic repair packets, and MCP.
- Phase 9: compatibility freeze, release hardening, provenance enforcement, and public publication.
- v2: broader analyzer ecosystem, local model providers, trend reporting, repair observability, and a generalized extension API.

</deferred>

---

*Phase: 00-product-naming-and-legal-foundation*
*Context gathered: 2026-08-16 via PRD Express Path*
