# Project Research Summary

**Project:** LineClear (working name; not cleared for publication)
**Domain:** Local-first deterministic verification framework and Ruby gem for Rails applications
**Researched:** 2026-08-16
**Confidence:** MEDIUM

## Evidence Convention

- **Verified fact** means the underlying claim was checked against an official registry, specification, project repository, or platform documentation on 2026-08-16.
- **Inference** means the conclusion combines verified facts with the supplied product constraints.
- **Recommendation** means a proposed project decision; it is not yet a compatibility promise until recorded in an ADR and implemented.

Detailed evidence remains in [STACK.md](./STACK.md), [FEATURES.md](./FEATURES.md), [ARCHITECTURE.md](./ARCHITECTURE.md), and [PITFALLS.md](./PITFALLS.md).

## Executive Summary

LineClear is intended to be a fully open-source, Rails-first verification layer rather than a new analyzer, hosted quality platform, or AI reviewer. Experts already rely on specialized tools for tests, lint, coverage, dependency auditing, static security, and runtime diagnostics. The defensible product is the stable layer above those tools: safe external execution, analyzer-independent evidence, deterministic policy, baselines, versioned machine output, and explicit failure semantics. The recommended implementation is one conventional Ruby gem and one local process, with a standard-library-first core and no Rails runtime dependency.

Build bottom-up. Phase 1 should prove one complete vertical path—strict configuration, run context, safe process execution, a narrow RuboCop adapter, canonical findings, deterministic policy, console output, JSON output, and stable exit behavior. Phase 2 can then add Minitest, RSpec, SimpleCov, and bundler-audit behind the same contracts. Fingerprints, baselines, and waivers follow only after real multi-tool evidence exists; Git/CI, Rails enrichment, optional AI, repair packets, and MCP then consume the stable core without becoming alternative sources of truth.

The immediate blocker is identity, not code. **Verified facts:** the exact RubyGems spellings checked were unclaimed on 2026-08-16, but the preferred GitHub organization is occupied, exact-name software products are active, and TMview returned exact `LINECLEAR` records including Class 9. **Inference/recommendation:** keep LineClear only as an unpublished codename, choose a more distinctive name in Phase 0, repeat package/domain/common-law/trademark checks—including Brazil and other intended launch jurisdictions—and obtain qualified trademark review before public packaging or branding. The highest technical risk is a false `PASS`; incomplete, stale, malformed, timed-out, or unsupported evidence must never be normalized to zero findings. The highest release risks are privileged execution of untrusted fork code, leakage of non-public provenance, and publishing a different gem than the artifact CI tested.

## Decision Summary

| Topic | Verified facts | Recommendation |
|---|---|---|
| Product identity | Exact RubyGems names appeared free; the preferred GitHub organization is occupied; active exact-name software and exact trademark records exist. | Rename during Phase 0. Do not publish a gem, public repository, site, logo, or stable schema namespace under the working name. |
| Ruby support | Ruby 3.2 is EOL; 3.3 is in security maintenance; 3.4 and 4.0 are in normal maintenance as observed on 2026-08-16. | Require Ruby `>= 3.3`; test 3.3, 3.4, and 4.0; document pre-1.0 EOL-drop policy. |
| Rails support | Rails 8.0 and 8.1 require Ruby 3.2+ and are the maintained context identified by research. | Declare tested Rails context `>= 8.0`, with Rails 8.0/8.1 fixture lanes; do not depend on Rails, Railties, or ActiveSupport at runtime. |
| Packaging | RubyGems, Bundler, Rake, Minitest, RDoc, and Ruby stdlib cover the initial gem lifecycle. | One gem, one executable, one configuration file, one core process. Add `json_schemer` only when runtime schema enforcement lands. |
| Analyzer execution | Each analyzer has different versions, exit semantics, output stability, and license terms. | Invoke tools from the target bundle as external processes; record exact versions; never vendor or silently install analyzers. |
| Gate authority | Analyzer failure and analyzer findings are distinct; AI is not deterministic evidence. | Only the verification core creates `GateResult`; required incomplete evidence means no trustworthy `PASS`; AI remains advisory and after the gate. |
| Public interfaces | CLI output, JSON, configuration, findings, baselines, waivers, fingerprints, and exit codes create compatibility obligations. | Version contracts independently and freeze only after fixture-backed use; keep pre-1.0 migrations explicit. |

## Key Findings

### Recommended Stack

**Recommendation:** use a conventional, deliberately small Ruby stack.

- **Ruby `>= 3.3`:** stdlib process, JSON/YAML, hashing, filesystem, time, and CLI APIs are sufficient for the core. Test 3.3/3.4/4.0.
- **Rails `>= 8.0` as a tested target context:** test Rails 8.0 and 8.1 through synthetic fixtures, without a Rails runtime dependency.
- **RubyGems + Bundler + Rake:** standard packaging, dependency resolution, build, test, documentation, and release tasks.
- **Minitest 6 for LineClear's own suite:** small and adequate; target-project adapters should support Minitest `>= 5, < 7` and RSpec `>= 3.13, < 4` initially.
- **OptionParser and Ruby stdlib:** prefer `OptionParser`, `Process.spawn`/`Open3`, `JSON`, safe `Psych`, `Digest`, `Pathname`, and `Tempfile`; do not add Thor, ActiveSupport, a job framework, or storage abstractions.
- **JSON Schema 2020-12:** publish independent schemas. Add `json_schemer >= 2.5, < 3` only when actual runtime validation is implemented; until then, keep runtime dependencies at zero.
- **Markdown + RDoc:** enough for initial documentation; no site generator or YARD without a demonstrated requirement.
- **Apache-2.0:** use an ordinary open-source license with separate NOTICE and trademark policy; do not add custom source-availability restrictions.

**Proposed CI lanes:** Ruby 3.3/core, 3.4/core, 4.0/core, Ruby 3.3/Rails 8.0 fixture, and Ruby 4.0/Rails 8.1 fixture. This is a proposal, not a verified support claim; implementation must prove it.

### Analyzer Shortlist and Licensing Constraints

All analyzers remain external to the distributed gem. Version ranges are starting proposals that require stored contract fixtures before they are advertised as supported.

| Priority | Tool/capability | Proposed phase | License/output constraint | Decision |
|---:|---|---:|---|---|
| 1 | RuboCop + optional rubocop-rails capability | 1, then harden in 2 | MIT; documented JSON; rubocop-rails shares the RuboCop process | First vertical adapter; proposed RuboCop `>= 1.72, < 2`, rubocop-rails `>= 2, < 3` |
| 2 | Minitest and RSpec results | 2 | MIT; LineClear-owned Minitest reporter format, fixture-tested RSpec JSON | Required table-stakes evidence; preserve counts, skips, failures, suite identity, and provenance |
| 3 | SimpleCov coverage | 2 | MIT; consume public schema-v1 `coverage.json`, never internal `.resultset.json` | Ingest fresh, complete coverage; gate changed-line coverage only when Git scope is trustworthy |
| 4 | bundler-audit | 2 | GPL-3.0-or-later; JSON not versioned; advisory DB revision matters | External invocation is acceptable; separate explicit DB refresh from offline gate execution |
| Hold | Brakeman | After written license/product decision | Current releases use a custom Brakeman Public Use License; commercial product/component/service use can require a commercial license | Technically valuable but **not approved for the Phase 2 shortlist yet**; never describe the current gem as MIT |
| Defer | Undercover | Later, only if unique value is proven | MIT; unversioned JSON; overlaps SimpleCov + LineClear diff logic | Avoid duplicate changed-line machinery |
| Defer | RubyCritic | Later, only if raw findings justify it | MIT; unversioned aggregate output; overlaps style/complexity signals | Do not adopt its opaque aggregate score as policy |
| Defer | Prosopite | Phase 5/runtime evidence | Apache-2.0; requires Rails boot/DB activity; no stable native JSON | Needs isolation and a LineClear-owned structured logger protocol |
| Defer | strong_migrations | Later research | MIT; useful behavior occurs during potentially mutating migration execution; no JSON contract | Never auto-run migrations; require a disposable/non-mutating strategy first |

**Conflict resolved:** FEATURES.md proposes Brakeman in Phase 2 because of its Rails security value, while STACK.md identifies a current custom-license constraint. Licensing wins: Brakeman remains out of the committed early-release shortlist until a written legal/product decision defines permitted external use, disclosure language, and commercial boundaries.

### Expected Features

**Must have by the relevant phase:**

- Local offline `check` command with stable `PASS` / `WARN` / `FAIL`, trustworthy/incomplete distinction, and documented exits.
- Strict, versioned, data-only configuration with unknown-key errors and inspectable effective values.
- Versioned `RunContext`, `Finding`, `AnalyzerResult`, and `GateResult` contracts.
- Safe subprocess execution with argv arrays, bounded concurrent output, monotonic deadlines, process-tree cleanup, minimal environment, and explicit terminal states.
- Human console and clean JSON reporters with logs only on stderr in machine mode.
- Analyzer-specific version, exit-code, and parser contracts; missing or malformed required evidence cannot pass.
- Minitest/RSpec normalization, complete/fresh SimpleCov ingestion, and later trustworthy changed-code coverage.
- Stable fingerprints, baselines, no-new-debt policy, strict/advisory modes, and exact expiring waivers.
- Local Git merge-base/diff semantics, SARIF, and least-privilege GitHub Actions.
- Diagnostics/doctor behavior that observes but never installs or mutates target dependencies.

**Differentiators after the core is proven:**

- One analyzer-independent evidence contract with raw provenance retained.
- Cross-tool no-new-debt classification and explainable policy rather than an opaque quality score.
- Narrow Rails-aware enrichment for routes, tests, models, policies, jobs, and schema context.
- Versioned deterministic repair packets for coding agents.
- Explicitly opted-in, provider-neutral AI explanation that cannot weaken the gate.
- Thin provider adapters—including future MCP—over the same application services.

**Defer beyond the initial trustworthy product:**

- Hosted dashboard, accounts, billing, telemetry, or mandatory network access.
- Broad plugin marketplace, universal-language scope, custom analyzers, or a proprietary quality score.
- Autonomous editing inside the verifier, custom GitHub App, MCP before schemas stabilize, or a full semantic code graph.
- Automatic dependency installation, wildcard waivers, hidden uploads, or mandatory AI.

### Architecture Approach

Use four one-way layers: evidence collection feeds the deterministic verification core; optional intelligence reads immutable results; CLI, CI, GitHub, coding agents, and future MCP consume those results. Source dependencies point toward core contracts, never toward reporters, platforms, or providers. Runtime evidence flows upward, but policy authority ends at `GateResult`.

**Major components:**

1. **Configuration + RunContext** — validate repository-owned policy and resolve reproducible repository/tool context.
2. **ProcessRunner** — own argv execution, environment isolation, bounded I/O, timeout, signals, cleanup, and structured diagnostics.
3. **Analyzer adapters** — detect supported versions, build commands, interpret tool-specific exit semantics, and parse native output into `AnalyzerResult`.
4. **Normalizer + canonical contracts** — create analyzer-independent findings while retaining origin and native provenance.
5. **Fingerprint/Baseline/Waiver services** — correlate current and historical evidence without line-number identity or silent suppression.
6. **PolicyEvaluator** — alone decides complete/incomplete and `PASS` / `WARN` / `FAIL`.
7. **Console/JSON/SARIF reporters** — pure projections of `GateResult`; no execution or policy.
8. **Optional AI, repair-packet, GitHub, and MCP adapters** — downstream consumers with no second verification engine.

Keep the project horizontal and boring: one gem, no database, no daemon, no Rails engine, no plugin framework, and no class for every noun before behavior requires it.

### Critical Pitfalls

1. **False `PASS` from incomplete evidence** — model unavailable, unsupported, timed-out, failed, truncated, malformed, stale, or partial states explicitly; required evidence must be `succeeded` before a trustworthy pass.
2. **Unsafe subprocesses and hostile output** — never invoke a shell; bound and concurrently drain stdout/stderr; terminate the process group; constrain environment, files, paths, encodings, field sizes, and terminal controls; state plainly that this is not an OS sandbox.
3. **Fingerprint/baseline bypass** — use versioned full-SHA-256 canonical identities, detect duplicates, treat Git rename as correlation only, make `check` read-only, and allow baseline changes only from complete runs with auditable diffs.
4. **Privileged untrusted CI** — execute fork code only in unprivileged `pull_request` workflows with read-only tokens and no secrets; never combine fork artifacts/code with privileged triggers or remote-AI credentials.
5. **Publication leakage or artifact substitution** — use synthetic fixtures, scan tree/history/package/artifacts without printing matched sensitive values, enforce English-only public material, build once, test that exact gem, and publish it through protected OIDC trusted publishing.

## Implications for the Supplied Phase 0–9 Roadmap

The supplied sequence is fundamentally sound and should be retained, with two corrections: identity clearance is a hard Phase 0 exit gate, and production changed-line coverage belongs with trustworthy Git scope in Phase 4 rather than being claimed complete in Phase 2.

### Phase 0 — Product, Naming, and Legal Foundation

**Rationale:** every package, command, config filename, schema URI, repository path, and trademark asset depends on identity; trust and license boundaries constrain all implementation.
**Delivers:** cleared replacement identity; lowercase gem/executable/config convention plus CamelCase Ruby namespace; Apache-2.0/NOTICE/trademark policy; analyzer license registry; Ruby/Rails support ADR; threat model; contract and exit-code drafts; synthetic-fixture, provenance-firewall, and English-only policies.
**Avoids:** premature publication, private-information leakage, misleading sandbox/security claims, and unreviewed license coupling.
**Research flag:** **required.** Repeat registry, fuzzy/phonetic/common-law/domain and official trademark searches for the replacement shortlist; complete Brazil and launch-jurisdiction checks; obtain qualified counsel before material public use.

### Phase 1 — Trustworthy Core

**Rationale:** one end-to-end path proves contracts and failure semantics before adapter breadth freezes weak abstractions.
**Delivers:** strict config, `RunContext`, safe `ProcessRunner`, explicit analyzer states, narrow RuboCop JSON adapter, canonical `Finding`/`AnalyzerResult`/`GateResult`, minimal deterministic policy, console/JSON reporters, and exits `0`/`1`/`2`/`130` if ratified.
**Avoids:** false passes, shell injection, unbounded output, orphan processes, executable YAML, mixed JSON/log output, and nondeterministic ordering.
**Research flag:** **required spike**, not broad market research: Bundler environment allowlist, output/time limits, process-tree cleanup, and supported operating systems.

### Phase 2 — Evidence Ecosystem

**Rationale:** real test and coverage evidence is needed before fingerprint and policy behavior can be validated across tool types.
**Delivers:** hardened RuboCop, Minitest and RSpec normalization, fresh/complete SimpleCov ingestion, bundler-audit, exact versions/config/artifact digests, and per-adapter failure corpora.
**Avoids:** treating nonzero exits alike, zero/filtered test suites as green, parsing internal coverage state, or accepting stale/partial worker output.
**Roadmap correction:** Phase 2 may define and fixture-test changed-line coverage against an injected line set, but it must not advertise a production `--changed` gate until Phase 4 supplies a trustworthy merge base and diff. Brakeman is excluded pending the license decision.
**Research flag:** **required per adapter** because output schemas, exit codes, and version boundaries vary; ordinary Minitest/RSpec/RuboCop mechanics are otherwise well documented.

### Phase 3 — Fingerprints, Baselines, Policies, and Waivers

**Rationale:** baselines require stable evidence from Phase 2 and become long-lived compatibility/security inputs.
**Delivers:** `lineclear/v1`-style fingerprint contract, partial fingerprints, duplicate/collision handling, explicit atomic baseline creation/migration, introduced/existing/resolved/changed/moved states, advisory/no-new-debt/strict policy, and exact expiring waivers.
**Avoids:** line-number churn, silent collisions, poisoned baselines, wildcard/permanent waivers, and automatic baseline mutation during `check`.
**Research flag:** **required empirical phase research** using mutation, duplicate, rename, move, and algorithm-migration corpora; do not add AST identity unless fixtures prove adapter scopes inadequate.

### Phase 4 — Git Diff and Pull Request Readiness

**Rationale:** changed-code policy depends on deterministic local Git facts; CI publication must consume rather than redefine them.
**Delivers:** repository/base/merge-base resolution, NUL-safe paths, changed-line ranges, explicit add/delete/rename/binary/conflict states, production changed-line coverage, SARIF, and an unprivileged GitHub Actions example.
**Avoids:** guessed/fetched bases, trusting rename heuristics as identity, shell/path injection, `pull_request_target` execution of fork code, broad tokens, and moving Action tags in release paths.
**Research flag:** **required spike** for no-config base discovery, shallow clones, unusual filenames, fork workflow/artifact boundaries, and permissions snapshots.

### Phase 5 — Rails-Aware Intelligence

**Rationale:** Rails context should enrich proven evidence, not create a speculative semantic platform.
**Delivers:** small deterministic resolvers for related tests, routes, associations, policies, jobs, and schema fragments; optionally selected runtime/architecture evidence after lifecycle contracts are proven.
**Avoids:** full code graph, analyzer replacement, framework coupling in core, or implying semantic certainty where context is inferred.
**Research flag:** **selective.** Standard Rails conventions need little research; Prosopite/Packwerk or application-boot integrations need dedicated lifecycle/isolation research.

### Phase 6 — Optional AI Intelligence

**Rationale:** AI can safely explain only after deterministic evidence, policy, and bounded context selection exist.
**Delivers:** provider port, deterministic context manifest, redaction/secret scanning, explicit remote consent, budgets, cache, strict response schema, and advisory explain/investigate modes.
**Avoids:** silent source transmission, prompt injection gaining tools/context, model output changing the gate, cross-repository cache leaks, fork-paid requests, and denial of wallet.
**Research flag:** **required** for provider retention terms, consent granularity, cache encryption/TTL/purge, local-model support, and threat-model validation.

### Phase 7 — Agent Repair Workflow

**Rationale:** stable findings, policy decisions, Git scope, and Rails context can now form a deterministic agent contract.
**Delivers:** versioned repair packets, bounded evidence/context, argv verification commands, audit-friendly retry state, and machine-friendly errors.
**Avoids:** terminal scraping, AI-specific truth, verifier-owned source mutation, or granting external agents new permissions.
**Research flag:** **mostly standard patterns**; validate packet usefulness with real agent-consumer fixtures before freezing the schema.

### Phase 8 — MCP

**Rationale:** protocol transport should follow stable CLI/application contracts, not drive them.
**Delivers:** a thin, initially read-only MCP adapter for checks, findings, policies, and repair packets using the same services as the CLI.
**Avoids:** duplicated verification logic, MCP-only functionality, code-editing tools, or alternate policy authority.
**Research flag:** **required at planning time** because the protocol may evolve; verify the then-current official MCP specification and SDK before implementation.

### Phase 9 — 1.0 Hardening and Release

**Rationale:** public compatibility and irreversible package publication require evidence across every earlier contract and boundary.
**Delivers:** supported-version/OS matrix, historical schema readers and migrations, performance/cancellation/cross-platform proof, security review, documentation, release policy, clean-install smoke, and a build-once digest chain through RubyGems Trusted Publishing.
**Avoids:** untested SemVer promises, mutable/rebuilt release artifacts, long-lived publishing keys, unverified provenance, non-public information leakage, and incomplete language checks.
**Research flag:** **required release refresh** for current Ruby/Rails/analyzer versions and licenses, official release action SHAs, OIDC policy, attestation expectations, and registry identity.

### Phase Ordering Rationale

- Identity and trust decisions precede compatibility-bearing code.
- Safe execution and canonical results precede adapter breadth.
- Multiple real evidence sources precede fingerprint and baseline design.
- Fingerprints and policy precede Git/CI publication and downstream agent interfaces.
- Rails context precedes bounded AI context and useful repair packets.
- MCP follows stable application contracts.
- Public release follows build, security, privacy, language, and compatibility proof.

## Conflicts Resolved

1. **Uppercase identity vs Ruby conventions:** the supplied brief uses `LineClear`, `LineClear` executable, and `.LineClear.yml`; RubyGems guidance and ecosystem expectations favor lowercase gem/executable/config names with a CamelCase Ruby constant. The replacement identity should use lowercase packaging surfaces and one documented CamelCase namespace. No compatibility promise should be made under the provisional spelling.
2. **Brakeman timing:** feature research values Brakeman as an early Rails security source, but current license research identifies a custom license and possible commercial-use boundaries. The integration is held until written review; technical usefulness does not override distribution/product risk.
3. **Changed-code coverage timing:** Phase 2 requests changed-code coverage, but the architecture correctly places trustworthy merge-base/diff semantics in Phase 4. Phase 2 owns coverage ingestion and pure calculation contracts; Phase 4 activates the production changed-code gate.
4. **`blocking` on `Finding`:** the conceptual input schema includes it, but architecture separates evidence from policy. Blocking belongs in `PolicyDecision`; if rendered on a finding view, it must be derived and never accepted from analyzer input.
5. **Phase 2 RuboCop listing:** Phase 1 uses one deliberately narrow RuboCop adapter to validate the vertical slice; Phase 2 hardens its supported-version range and adds broader evidence. This is staged work, not duplication.

## Decisions Required Before Phase 1

- Select and clear the replacement name; define lowercase gem/executable/config names, Ruby namespace, repository owner/path, and schema namespace together.
- Ratify Ruby `>= 3.3`, tested Rails `>= 8.0`, the deliberate CI matrix, and the pre-1.0 EOL-drop policy.
- Ratify fail-closed analyzer states, complete/incomplete gate semantics, and whether `WARN` exits `0`.
- Define supported operating systems and degraded guarantees, especially Windows process-tree termination.
- Define the minimal child-environment allowlist, Bundler behavior, output/artifact limits, timeouts, signal grace periods, and safe diagnostic redaction.
- Freeze configuration format/loading/precedence: one data-only YAML file, no ERB/object tags, unknown keys fail, and policy-changing environment overrides are either forbidden or explicit.
- Decide whether canonical schema validation occurs on every CLI run or only at boundaries; this determines when `json_schemer` becomes a runtime dependency.
- Approve initial RuboCop/rubocop-rails version ranges with real fixture bundles.
- Approve the information-firewall, synthetic-fixture, English-only, third-party license, and threat-model ADRs.

## Decisions Required Before First Public Release

- Complete trademark/common-law/package/domain checks for the final name in Brazil and all intended launch jurisdictions; obtain qualified legal clearance and recheck availability immediately before reservation/publication.
- Resolve Brakeman's permitted-use and disclosure policy before listing it as supported; recheck every analyzer version and license at release time.
- Define fingerprint/baseline migration support, waiver expiry/max lifetime, baseline review authority, and compatibility support windows.
- Prove the supported-OS containment matrix, offline behavior, deterministic replay, malicious-output handling, and adapter failure corpora.
- Ratify safe GitHub trusted/untrusted workflow separation and prohibit privileged execution of fork code or artifacts.
- Define RubyGems Trusted Publishing bootstrap/recovery, protected release environment, exact workflow/action SHAs, checksum/provenance verification, and build-once artifact handling.
- Run private provenance and secret scans over tracked files, history, generated gem, archives, metadata, docs, release notes, and CI artifacts without exposing matched values; require zero unresolved matches.
- Enforce English-only public content with narrow manifest-listed internationalization fixtures.
- Declare the public API and SemVer surface only after schemas, config, exits, fingerprints, analyzer/reporter APIs, migrations, and documentation are tested.

## Confidence Assessment

| Area | Confidence | Notes |
|---|---|---|
| Stack | MEDIUM | Current official Ruby, Rails, RubyGems, and project sources support the proposal; actual OS/tool matrices and dependency versions remain untested. |
| Features | MEDIUM | Competitor and specialist capabilities are well documented, but differentiation and adoption value remain product inferences until user validation. |
| Architecture | MEDIUM | The one-gem, layered design follows strong constraints and standards; subprocess, Git, fingerprint, and platform behavior require spikes and fixture evidence. |
| Pitfalls | MEDIUM | Risks are grounded in official Ruby, GitHub, OWASP, Git, JSON/SARIF, and RubyGems guidance; exact policies and cross-platform containment remain project decisions. |
| Naming/legal | MEDIUM | Registry and collision evidence is strong enough to block publication, but it is preliminary knockout research, not legal clearance; WIPO/INPI and similarity searches remain incomplete. |

**Overall confidence:** MEDIUM. The product direction and phase dependency order are well supported; name clearance, platform containment, analyzer contracts, fingerprint behavior, and release policy still require decisions or implementation evidence.

### Gaps to Address

- No user/adoption study yet validates defaults, diagnostic ergonomics, or repair-packet usefulness.
- Windows and other non-POSIX subprocess containment are unresolved.
- The first fingerprint algorithm lacks empirical mutation/collision data from synthetic Rails fixtures.
- Local default-base discovery for `--changed` remains unresolved.
- Several analyzer JSON formats are documented but not versioned schemas; lower/current version fixtures are required.
- Provider retention, consent granularity, cache security, and local-model behavior are intentionally deferred to Phase 6.
- Exact release action SHAs, versions, licenses, registry availability, and trademark status are time-sensitive and must be refreshed.

## Sources

All linked sources below were accessed on **2026-08-16**. Official/primary sources support factual claims; LineClear-specific design choices remain recommendations.

### Identity, Trademark, and Market

- [RubyGems exact-name API](https://rubygems.org/api/v1/gems/lineclear.json), [RubyGems naming guidance](https://guides.rubygems.org/name-your-gem/), and [RubyGems patterns](https://guides.rubygems.org/patterns/) — registry result and package conventions.
- [GitHub organization `lineclear`](https://github.com/lineclear) and [GitHub exact-name repository search API](https://api.github.com/search/repositories?q=lineclear+in:name&per_page=100) — occupied organization and repository-name signal.
- [USPTO Trademark Search](https://tmsearch.uspto.gov/), [USPTO search guidance](https://www.uspto.gov/trademarks/search/federal-trademark-searching), [TMview exact-name query](https://www.tmdn.org/tmview/#/tmview/results?page=1&pageSize=30&criteria=I&basicSearch=LINECLEAR), [WIPO Global Brand Database](https://www.wipo.int/en/web/global-brand-database/index), and [Brazil INPI portal](https://www.gov.br/inpi/pt-br/servicos/marcas) — preliminary trademark evidence and unresolved jurisdictions.
- [lineclear.app](https://lineclear.app/), [Agile Cookies LineClear](https://www.agilecookies.com/apps/lineclear/), [Line Clear OMS](https://apps.apple.com/us/app/line-clear-oms/id1555210200), and [Line Clear integration](https://anchanto.com/integration/line-clear/) — active exact/similar product uses.

### Ruby, Rails, Packaging, and Analyzers

- [Ruby branch status](https://www.ruby-lang.org/en/downloads/branches/), [Rails maintenance policy](https://guides.rubyonrails.org/maintenance_policy.html), and [Rails upgrade guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html) — proposed support floor.
- [RubyGems gem guide](https://guides.rubygems.org/make-your-own-gem/), [RubyGems specification reference](https://guides.rubygems.org/specification-reference/), and [json_schemer](https://github.com/davishmcclurg/json_schemer) — packaging and schema-validation approach.
- [RuboCop](https://github.com/rubocop/rubocop), [RuboCop formatter docs](https://docs.rubocop.org/rubocop/latest/formatters.html), [rubocop-rails](https://github.com/rubocop/rubocop-rails), [Minitest](https://github.com/minitest/minitest), [RSpec JSON formatter](https://rspec.info/features/3-13/rspec-core/formatters/json-formatter/), and [SimpleCov](https://github.com/simplecov-ruby/simplecov) — first-tranche contracts.
- [bundler-audit](https://github.com/rubysec/bundler-audit), [Brakeman license](https://github.com/presidentbeef/brakeman/blob/main/LICENSE.md), [Brakeman COPYING](https://github.com/presidentbeef/brakeman/blob/main/COPYING.md), [Prosopite](https://github.com/charkost/prosopite), [RubyCritic](https://github.com/whitesmith/rubycritic), [Undercover](https://github.com/grodowski/undercover), and [strong_migrations](https://github.com/ankane/strong_migrations) — deferred-tool licensing and contract constraints.

### Contracts, Execution, Security, and Release

- [Ruby Process](https://docs.ruby-lang.org/en/3.4/Process.html), [Ruby Open3](https://docs.ruby-lang.org/en/3.4/Open3.html), [Ruby Timeout](https://docs.ruby-lang.org/en/master/Timeout.html), and [Ruby Tempfile](https://docs.ruby-lang.org/en/3.4/Tempfile.html) — subprocess and temporary-file boundary.
- [JSON Schema dialect declaration](https://json-schema.org/understanding-json-schema/reference/schema), [RFC 8259](https://www.rfc-editor.org/info/rfc8259/), [SARIF 2.1.0](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html), and [SemVer 2.0.0](https://semver.org/) — versioned documents, fingerprints, and compatibility.
- [Git diff](https://git-scm.com/docs/git-diff.html), [Git directory rename detection](https://git-scm.com/docs/directory-rename-detection.html), and [Reproducible Builds](https://reproducible-builds.org/docs/) — changed-scope and determinism constraints.
- [OWASP prompt injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/), [OWASP sensitive information disclosure](https://genai.owasp.org/llmrisk/llm022025-sensitive-information-disclosure/), [OWASP improper output handling](https://genai.owasp.org/llmrisk/llm052025-improper-output-handling/), and [OWASP unbounded consumption](https://genai.owasp.org/llmrisk/llm102025-unbounded-consumption/) — optional-AI boundary.
- [GitHub secure `pull_request_target`](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target), [GitHub secure use](https://docs.github.com/en/actions/reference/security/secure-use), [RubyGems Trusted Publishing](https://guides.rubygems.org/trusted-publishing/), and [RubyGems MFA](https://guides.rubygems.org/setting-up-multi-factor-authentication/) — CI and publication controls.
- [MCP architecture](https://modelcontextprotocol.io/specification/2025-06-18/architecture) and [MCP server primitives](https://modelcontextprotocol.io/specification/2025-06-18/server/index) — future adapter boundary.

---
*Research completed: 2026-08-16*
*Ready for roadmap: yes, subject to the Phase 0 name/publication blocker*
