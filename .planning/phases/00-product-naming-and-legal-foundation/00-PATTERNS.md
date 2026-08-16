# Phase 0: Product, Naming and Legal Foundation - Pattern Map

**Mapped:** 2026-08-16
**Files classified:** 31 public artifacts (16 shared artifacts plus 15 separate ADRs)
**Research analogs found:** 26 / 31
**Scope:** Documentation, legal text, draft contracts, synthetic examples, and validation evidence only

## Boundary

Phase 0 has no production-code analogs. The repository contains only planning and research material, so new public artifacts should copy evidence structure and decisions from `.planning/`, not invent Ruby implementation patterns.

The minimum artifact set below is deliberate. Do not add `lib/`, `exe/`, `spec/`, a gemspec, a Gemfile, CI workflows, analyzer fixtures, application code, or directories reserved for later phases. The context explicitly limits this phase to documentation and draft contracts (`00-CONTEXT.md:8-12, 59-64, 93`) and the roadmap repeats that production behavior is a non-goal (`ROADMAP.md:26-37`).

RailVerdict is selected as the identity, but publication is still blocked. Phase 0 must record the selection and the open launch-jurisdiction/qualified-review gate; it must not describe the name as legally cleared (`00-CONTEXT.md:12, 20-23`; `PROJECT.md:7, 75`).

## File Classification

All data-flow labels below describe document flow, not runtime execution.

| New Public File | Role | Data Flow | Closest Existing Source | Match Quality | Requirements |
|---|---|---|---|---|---|
| `README.md` | product documentation | reference/index | `.planning/PROJECT.md:3-50` | exact-content | FND-07 |
| `LICENSE` | legal text | rights grant | None in repository; decision only at `00-CONTEXT.md:23` | none | FND-04 |
| `NOTICE` | legal notice | attribution | None in repository | none | FND-04 |
| `TRADEMARKS.md` | legal policy | permitted/prohibited use | None in repository; boundary only at `00-CONTEXT.md:23` | none | FND-04 |
| `docs/foundation.md` | evidence record | evidence -> decision -> open gate | `.planning/research/FEATURES.md:16-67`; `.planning/PROJECT.md:7,75` | partial | FND-01, FND-02, FND-03 |
| `docs/analyzers.md` | registry/proposal | dated facts -> disposition | `.planning/research/STACK.md:23-45,95-145` | exact-content | FND-05, FND-06 |
| `ARCHITECTURE.md` | architecture documentation | dependency/reference | `.planning/research/ARCHITECTURE.md:18-103,154-285` | exact-content | FND-07, FND-13 |
| `docs/contracts.md` | public contract documentation | draft request/response | `.planning/research/ARCHITECTURE.md:154-285,382-403` | partial | FND-09, FND-10 |
| `SECURITY.md` | threat model and information-firewall policy | threat -> control -> evidence | `.planning/research/PITFALLS.md:16-110,128-181` | exact-content | FND-11, FND-12 |
| `ROADMAP.md` | public roadmap | requirement -> phase -> exit gate | `.planning/ROADMAP.md:3-157`; `.planning/REQUIREMENTS.md:172-268` | exact-content | FND-14 |
| `schemas/finding-v1.schema.json` | JSON Schema | validation/transform boundary | `.planning/research/ARCHITECTURE.md:156-170,258-285` | partial | FND-09 |
| `schemas/configuration-v1.schema.json` | JSON Schema | validation/config | `.planning/research/ARCHITECTURE.md:200-212,258-285` | partial | FND-09 |
| `examples/finding-v1.json` | synthetic example | validation fixture | No concrete example in repository | none | FND-09 |
| `examples/configuration-v1.yml` | synthetic example | validation fixture | No concrete example in repository | none | FND-09 |
| `docs/adr/0001-deterministic-pass-fail.md` | decision record | evidence -> gate decision | `.planning/PROJECT.md:9-11`; `.planning/research/PITFALLS.md:8-14` | partial | FND-08 |
| `docs/adr/0002-external-analyzer-execution.md` | decision record | Rails-first external process boundary | `.planning/PROJECT.md:3-5,32-38` | partial | FND-08 |
| `docs/adr/0003-canonical-finding.md` | decision record | transform/contract | `.planning/research/ARCHITECTURE.md:154-170` | partial | FND-08 |
| `docs/adr/0004-versioned-schemas.md` | decision record | machine contracts | `.planning/research/ARCHITECTURE.md:156-170` | partial | FND-08 |
| `docs/adr/0005-fingerprint-baseline.md` | decision record | identity/baseline boundary | `.planning/research/ARCHITECTURE.md:214-228,314-359` | partial | FND-08 |
| `docs/adr/0006-no-new-debt.md` | decision record | adoption/policy boundary | `.planning/research/ARCHITECTURE.md:46-53,185-198` | partial | FND-08 |
| `docs/adr/0007-advisory-ai.md` | decision record | advisory intelligence | `.planning/research/ARCHITECTURE.md:405-429` | partial | FND-08 |
| `docs/adr/0008-remote-ai-explicit-opt-in.md` | decision record | provider boundary | `.planning/research/ARCHITECTURE.md:233-243,405-429` | partial | FND-08 |
| `docs/adr/0009-github-as-an-adapter.md` | decision record | downstream adapter/one-gem boundary | `.planning/research/ARCHITECTURE.md:431-441` | partial | FND-08, FND-13 |
| `docs/adr/0010-cli-and-json-canonical.md` | decision record | automation interface | `.planning/research/ARCHITECTURE.md:382-403` | partial | FND-08 |
| `docs/adr/0011-mcp-as-an-adapter.md` | decision record | request-response adapter | `.planning/research/ARCHITECTURE.md:443-447` | partial | FND-08 |
| `docs/adr/0012-third-party-license-review.md` | decision record | license/release review | `.planning/research/STACK.md:95-145` | partial | FND-08 |
| `docs/adr/0013-information-firewall.md` | decision record | provenance/language gate | `.planning/research/PITFALLS.md:104-110,128-145` | partial | FND-08, FND-12 |
| `docs/adr/0014-apache-2-license.md` | decision record | local-first open-source rights | `00-CONTEXT.md:19-23`; `.planning/research/SUMMARY.md:38-49` | partial | FND-08, FND-04 |
| `docs/adr/0015-separate-trademark-policy.md` | decision record | identity/source-confusion policy | `00-CONTEXT.md:19-23` | partial | FND-08, FND-03, FND-04 |

## Pattern Assignments

### `README.md` (product documentation, reference/index)

**Analog:** `.planning/PROJECT.md:3-50`

Copy the short product-definition pattern: definition, deterministic core value, active scope, non-goals, and constraints. Use README as a navigation hub rather than duplicating the detailed foundation documents.

```markdown
# RailVerdict

> Publication status: selected identity; publication blocked pending the
> documented launch-jurisdiction searches and qualified trademark review.

## What RailVerdict Is
## Core Value
## What RailVerdict Is Not
## Foundation Documents
```

Keep these claims verbatim in meaning:

- fully open-source, local-first Rails verification framework;
- same repository/configuration/analyzer versions/baseline produces the same evidence-backed gate regardless of AI;
- not a SaaS, hosted dashboard, analyzer, LLM, editor, or autonomous coding agent;
- external analyzers provide evidence; deterministic policy alone owns the gate.

**Cross-links:** naming/identity, all three legal files, analyzer/support proposal, architecture, contracts/schemas/examples, security/firewall, roadmap, and the ADR directory.

### Legal files: `LICENSE`, `NOTICE`, and `TRADEMARKS.md`

**Analog:** none. The repository records the decision but contains no legal-document pattern.

- `LICENSE` must contain the unmodified canonical Apache License 2.0 text. Do not paraphrase it.
- `NOTICE` must contain only factual project copyright/notice material required by Apache-2.0. Do not add restrictions.
- `TRADEMARKS.md` may prevent misleading claims of official status, sponsorship, or endorsement, but must explicitly preserve every software right granted by Apache-2.0.
- Do not claim trademark registration, clearance, or exclusive rights that the evidence does not establish.

The separation rule comes from `00-CONTEXT.md:23` and `.planning/research/SUMMARY.md:49`; the actual wording needs qualified review because no repository analog exists.

### `docs/foundation.md` (evidence record)

**Analogs:** `.planning/research/FEATURES.md:16-67`, `.planning/PROJECT.md:7,75`, and `00-CONTEXT.md:19-23`

Reuse the research evidence convention and decision-matrix structure, but do not mechanically rename old `LineClear` evidence. The detailed research in `FEATURES.md` proves why `LineClear` was rejected; it does not prove that `RailVerdict` is cleared.

Use this shape for each checked surface:

| Surface | Checked at (UTC date) | Query/scope | Observed result | Evidence link | Classification | Remaining gate |
|---|---|---|---|---|---|---|
| RubyGems | YYYY-MM-DD | exact and spelling variants | factual result | primary source | Verified fact | recheck before publication |

Required sections:

1. Evidence convention: `Verified fact`, `Inference`, `Decision`, and `Unresolved gate`.
2. Rejected working-name record with the historical `LineClear` evidence unchanged in substance.
3. Dated `RailVerdict` checks for RubyGems, GitHub, domains, current-product/common-law collisions, and preliminary trademark signals.
4. One canonical identity table:

   | Surface | Value |
   |---|---|
   | Project | `RailVerdict` |
   | Gem / require path | `rail_verdict` |
   | Ruby namespace | `RailVerdict` |
   | Executable | `railverdict` |
   | Configuration | `.railverdict.yml` |
   | Repository identity | `railverdict` |
   | Schema namespace | `https://railverdict.dev/schemas/` |

5. A prominent publication blocker naming Brazil and every intended launch jurisdiction still unchecked, plus qualified trademark review.
6. Explicit language that preliminary search is not legal advice or clearance.

**Cross-links:** `TRADEMARKS.md`, ADR 0010, README publication status, and the Phase 9 revalidation gate in `ROADMAP.md`.

### `docs/analyzers.md` (registry/proposal)

**Analog:** `.planning/research/STACK.md:23-45,95-145`

Copy the existing table shape and evidence labels. One row is required for Minitest, RSpec, RuboCop, rubocop-rails, SimpleCov, Undercover, RubyCritic, Brakeman, Prosopite, bundler-audit, and strong_migrations.

| Analyzer | Homepage / observed version | License | Commercial-use considerations | Target-project installation | Bundled? | Proposed version policy | Native output | Execution cost | Disposition | Checked |
|---|---|---|---|---|---|---|---|---|---|---|

Rules to copy:

- every analyzer remains external to the distributed gem;
- proposed version ranges are drafts until fixture lanes pass;
- Ruby `>= 3.3` with core lanes 3.3/3.4/4.0 and Rails context lanes 8.0/8.1 is a proposal, not proven support;
- Brakeman stays out of the committed adapter shortlist until a written legal/product decision addresses its current custom license (`STACK.md:106,130`; `SUMMARY.md:63,69`);
- distinguish a version observed on 2026-08-16 from an open-ended compatibility promise.

**Cross-links:** ADR 0004, ADR 0010, `ARCHITECTURE.md`, `SECURITY.md`, and Phase 1/2 ownership in `ROADMAP.md`.

### `ARCHITECTURE.md` (architecture and repository contract)

**Analog:** `.planning/research/ARCHITECTURE.md:18-103,154-285`

Copy the four-layer diagram and one-way dependency rule, replacing the working name only where the statement is product-generic:

```text
Evidence collection
        -> deterministic verification core
        -> optional intelligence (read-only, never gates)
        -> CLI / CI / GitHub / coding-agent / future MCP consumers
```

Document these ownership rules:

- evidence records facts;
- policy alone creates gate authority and `GateResult`;
- reporters and platform adapters only project results;
- AI reads immutable results and remains advisory;
- external analyzers execute in target-project processes;
- source dependencies point toward stable core contracts.

The proposed repository tree must show only the one-gem shape that later phases may create. Label it **proposed, not present**. Do not create any path from that diagram in Phase 0. Explicitly defer `intelligence/`, MCP, GitHub-specific core types, a plugin framework, separate gems, a database, a daemon, and any abstraction without Phase 1 behavior (`ARCHITECTURE.md:75-103`; `SUMMARY.md:117`).

**Cross-links:** all architecture ADRs, `docs/contracts.md`, `SECURITY.md`, and phase ownership in `ROADMAP.md`.

### Contract set: `docs/contracts.md`, schemas, and examples

**Analogs:** `.planning/research/ARCHITECTURE.md:154-285,382-403` and `00-CONTEXT.md:43-47`

`docs/contracts.md` is the single prose contract guide. It should link the two schemas and two examples and contain the CLI draft; do not split command and schema prose into more documents yet.

Every pre-implementation surface must be labeled **Draft; not implemented and not a compatibility promise**.

Schema root pattern:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://railverdict.dev/schemas/finding-v1.schema.json",
  "title": "RailVerdict Finding v1 (Draft)",
  "type": "object",
  "additionalProperties": false,
  "required": [],
  "properties": {}
}
```

Apply unknown-field rejection to every object level, not only the root. Version each contract independently. Use `schema_version: "1.0"` for Finding and `version: 1` for configuration, matching `.planning/research/ARCHITECTURE.md:258-285`.

Finding rules:

- analyzer-independent evidence with origin/provenance and repository-relative locations;
- no analyzer-supplied `blocking` field;
- no policy action, waiver state, or `PASS`/`WARN`/`FAIL` authority in input evidence;
- any future rendered blocking state is derived from `PolicyDecision`, never accepted from analyzers (`ARCHITECTURE.md:156-170`).

Configuration rules:

- data-only YAML represented by a strict schema;
- no ERB, object tags, executable values, or silent environment policy overrides;
- unknown keys reject with useful paths;
- defaults and precedence are documented as draft rather than invented as implemented behavior.

CLI table:

| Command | Draft purpose | Mutation boundary |
|---|---|---|
| `railverdict init` | create explicit initial configuration | only after user invocation |
| `railverdict doctor` | report environment/tool readiness | observes; never installs |
| `railverdict check` | collect evidence and apply policy | read-only for baselines |
| `railverdict baseline create` | explicitly create baseline from a complete run | explicit, atomic future operation |
| `railverdict findings` | render normalized findings | read-only |

Proposed exits copy `.planning/research/ARCHITECTURE.md:382-403`: `0` trustworthy PASS/non-blocking WARN, `1` trustworthy policy FAIL, `2` incomplete/usage/tool/configuration failure, and `130` interruption. JSON mode emits exactly one JSON document plus newline to stdout; diagnostics go only to stderr. Reporters do not decide the exit.

Examples must be small, English-only, internally consistent, and invented from scratch. The Finding example must validate against the Finding schema; the YAML example must parse to a value that validates against the configuration schema. Parsing JSON/YAML is not sufficient proof of schema validity.

**Cross-links:** ADR 0005, ADR 0006, README, architecture policy ownership, and Phase 1 implementation ownership in `ROADMAP.md`.

### `SECURITY.md` (threat model and information firewall)

**Analog:** `.planning/research/PITFALLS.md:16-110,128-181`

Use one public security document with two major parts instead of creating separate threat-model and provenance-policy files.

Threat-model structure:

1. Assets to protect.
2. Trust boundaries: repository, analyzer, host, remote AI, CI, and release.
3. Threat actors.
4. Risk register: false PASS, hostile output, subprocesses, baselines/waivers, AI transmission/injection, forks, dependencies/actions, and artifact substitution.
5. Required controls.
6. Verification evidence and owning phase.
7. Explicit limits: executable-plus-argv isolation is **not** an OS sandbox (`PITFALLS.md:81`).

Information-firewall structure:

- public examples and fixtures are synthetic and created from scratch;
- public repository prose is English-only except narrow manifest-listed future i18n fixtures;
- scan scopes include current tree, full history, generated gem, archives, images/media metadata, documentation, release notes, and CI artifacts;
- secret scanning is defense in depth, not a substitute for provenance scanning;
- reports expose only counts/categories/paths safe for review, never matched private values;
- unresolved matches block publication (`PITFALLS.md:104-110,128-145`).

Do not include private detection terms, customer names, private paths, real logs, screenshots, metrics, identifiers, or derived operational details in this public policy.

**Cross-links:** ADRs 0008, 0011, 0012, 0013, and 0015; naming publication blocker; Phase 4 fork controls and Phase 9 release gates in `ROADMAP.md`.

### `ROADMAP.md` (public roadmap and traceability)

**Analogs:** `.planning/ROADMAP.md:3-157` and `.planning/REQUIREMENTS.md:172-268`

Copy the fixed Phase 0 -> 9 dependency order, each phase's goal, requirement IDs, observable success criteria, exit gate, and non-goals. Every one of the 85 v1 requirement IDs must appear in exactly one phase assignment.

Preserve two boundary corrections already resolved by research:

- Phase 2 may define and fixture-test changed-line coverage against injected line sets; production Git-scoped changed coverage belongs to Phase 4.
- Brakeman is not a supported Phase 2 adapter until a written license/product decision exists.

For Phase 0, reconcile completion wording with the locked context: the identity choice and open clearance record can be complete while **publication remains blocked**. Do not turn the open legal gate into a claim of clearance.

**Cross-links:** README, foundation documents, architecture, contracts, security, and the relevant ADRs. The public roadmap must stand alone; do not require readers to understand `.planning/` internals.

### Fifteen ADRs (decision records)

There is no ADR-file precedent in the repository. Use one small template for all fifteen, with no ADR index file; README or `ARCHITECTURE.md` can carry the link table.

```markdown
# ADR NNNN: Decision title

- Status: Accepted
- Date: 2026-08-16

## Context
## Decision
## Consequences
## Deferred Work
## Related Contracts
```

`Accepted` means the foundation decision is ratified, not that later-phase behavior exists. Each ADR must say which behavior is deferred and link its owning roadmap phase. Avoid speculative alternatives sections unless a real rejected alternative from research matters to the decision.

| ADR | Decision sentence to preserve | Primary source |
|---|---|---|
| 0001 | Objective deterministic evidence precedes merge opinion; incomplete required evidence cannot produce a trustworthy PASS. | `PITFALLS.md:8-14` |
| 0002 | Scope is Rails-first rather than a universal-language quality platform. | `PROJECT.md:3-5,32-38` |
| 0003 | The complete core is local-first and fully open source, with no required SaaS/account/network/AI. | `PROJECT.md:3-7,48-59` |
| 0004 | Mature analyzers remain external target-project processes and are never bundled or silently installed. | `STACK.md:95-145` |
| 0005 | `Finding` is the canonical analyzer-independent evidence contract and retains origin/provenance. | `ARCHITECTURE.md:154-170` |
| 0006 | Only deterministic policy creates gate authority; adapters, reporters, AI, GitHub, and MCP cannot. | `ARCHITECTURE.md:46-53,185-198,472-474` |
| 0007 | Versioned fingerprints and baselines enable no-new-debt adoption without silent baseline mutation. | `ARCHITECTURE.md:214-228,314-359` |
| 0008 | All external execution crosses one executable-plus-argv, bounded, timeout-aware, cleanup-owning boundary; this is not sandboxing. | `ARCHITECTURE.md:288-312`; `PITFALLS.md:71-81` |
| 0009 | Use one gem and one process; create directories/abstractions only when an owning phase has behavior. | `ARCHITECTURE.md:8-10,75-103` |
| 0010 | Apache-2.0 software rights and trademark rules are separate; trademark terms cannot narrow the license. | `00-CONTEXT.md:19-23` |
| 0011 | AI is optional, advisory, and unable to change deterministic gate results. | `ARCHITECTURE.md:405-429` |
| 0012 | AI providers remain adapters behind a provider-independent boundary with explicit consent and validated output. | `ARCHITECTURE.md:233-243,405-429` |
| 0013 | GitHub is a downstream adapter over local application services and `GateResult`, not a second verification engine. | `ARCHITECTURE.md:431-441` |
| 0014 | MCP follows stable CLI/Finding/GateResult/repair-packet contracts and begins read-only. | `ARCHITECTURE.md:443-447` |
| 0015 | Public material is synthetic-only and English-only, with release-wide provenance scanning. | `PITFALLS.md:104-110,128-145` |

## Shared Patterns

### Terminology and Naming

- Public product name: `RailVerdict`.
- Gem and require path: `rail_verdict`.
- Ruby namespace: `RailVerdict`.
- Executable: `railverdict`.
- Configuration file: `.railverdict.yml`.
- Repository identity: `railverdict`.
- Draft schema root: `https://railverdict.dev/schemas/`.
- JSON/YAML fields: lowercase `snake_case`.
- Contract type: capitalized `Finding`; gate values: uppercase `PASS`, `WARN`, `FAIL`.
- `LineClear` appears only in the dated rejected-name history or when accurately identifying a historical research source. Do not silently relabel old queries as RailVerdict evidence.

### Evidence and Claim Status

Copy the research convention from `.planning/research/SUMMARY.md:8-14`:

- **Verified fact:** dated observation backed by a primary source.
- **Inference:** conclusion derived from verified facts.
- **Decision:** project choice ratified by an ADR.
- **Draft:** pre-implementation contract or support proposal.
- **Unresolved gate:** action that still blocks publication or a later feature.

Never write “supported,” “safe,” “compatible,” “cleared,” or “validated” where the repository has only a proposal. In particular, argument-array subprocess handling is not an OS sandbox, proposed Ruby/Rails lanes are not passing support evidence, and name availability is not trademark clearance.

### Cross-Link Obligations

| Artifact | Must Link To |
|---|---|
| `README.md` | every public foundation artifact and ADR location |
| Naming/identity | `TRADEMARKS.md`, ADR 0010, roadmap publication revalidation |
| Analyzer/support | ADR 0004, architecture boundary, security controls, Phase 1/2 roadmap |
| Architecture | contract guide, security model, ADRs 0001-0009 and 0011-0014, roadmap |
| Contract guide | both schemas, both examples, ADRs 0005/0006, CLI-owning Phase 1 |
| Each schema | its example and contract-guide versioning section |
| Each example | its schema `$id` or an adjacent explicit schema reference |
| Security | ADRs 0008/0011/0012/0013/0015 and Phase 4/9 gates |
| Roadmap | public foundation docs and relevant ADRs; all 85 requirement IDs exactly once |
| Each ADR | related public contract(s) and the roadmap phase that owns implementation/evidence |

Public documents should link public documents. `.planning/` paths are source citations for planning and review, not dependencies that public users must follow.

### Validation Evidence

Use existing or standard commands; add no runtime or documentation-only dependency and no persistent validation framework in Phase 0.

Minimum evidence for the phase plan:

1. JSON syntax parses for both schemas and the Finding example.
2. YAML syntax safely parses for the configuration example.
3. A real JSON Schema Draft 2020-12 validator proves both examples valid and proves at least one unknown-field mutation invalid for each schema. JSON/YAML parsing alone is not schema validation.
4. Markdown relative-link targets exist.
5. Requirement-ID comparison proves all 85 v1 IDs occur in exactly one public roadmap phase assignment.
6. Repository scan finds no production/gem scaffold paths.
7. English-only and provenance checks cover every new public artifact without printing sensitive matches.
8. `git diff --check` passes.

If no suitable Draft 2020-12 validator is already available in the execution environment, record that as a validation blocker rather than adding a hand-written partial validator or runtime dependency (`STACK.md:62-68,178-187`).

## Requirement Coverage by Minimal Artifact Set

| Requirement | Evidence Artifact(s) |
|---|---|
| FND-01 | `docs/foundation.md` dated evidence tables |
| FND-02 | `docs/foundation.md` canonical mapping |
| FND-03 | naming document, README status, and roadmap publication gate |
| FND-04 | `LICENSE`, `NOTICE`, `TRADEMARKS.md`, ADR 0010 |
| FND-05 | analyzer registry in `docs/analyzers.md` |
| FND-06 | Ruby/Rails proposal and synthetic lanes in the same document |
| FND-07 | `README.md`, `ARCHITECTURE.md`, ADRs 0001-0003 |
| FND-08 | fifteen separate ADR files listed above |
| FND-09 | contract guide, two schemas, and two valid synthetic examples |
| FND-10 | CLI section of `docs/contracts.md` |
| FND-11 | threat-model section of `SECURITY.md` |
| FND-12 | information-firewall section of `SECURITY.md` and ADR 0015 |
| FND-13 | proposed-not-present repository section in `ARCHITECTURE.md` and ADR 0009 |
| FND-14 | standalone public `ROADMAP.md` with one-time requirement mapping and exit gates |

## No Analog Found

| File / Concern | Reason | Planner Guidance |
|---|---|---|
| `LICENSE` | License choice exists; canonical legal text is absent. | Use unmodified official Apache-2.0 text. |
| `NOTICE` | No project notice exists. | Add only factual required notice material; no restrictions. |
| `TRADEMARKS.md` | No policy wording exists. | Preserve Apache rights and avoid clearance claims; obtain qualified review. |
| RailVerdict-specific clearance record | Research files contain detailed `LineClear` rejection evidence, while only `PROJECT.md` records the RailVerdict selection. | Perform and preserve dated RailVerdict checks; do not relabel historical queries. |
| Concrete schemas | Architecture defines fields/versioning but no JSON Schema files exist. | Implement the minimum strict Draft 2020-12 documents; reject unknown fields recursively. |
| Concrete examples | No synthetic Finding/config examples exist. | Invent minimal English-only examples from scratch and validate them. |
| ADR formatting precedent | No ADR files exist. | Use the one template above for all fifteen; do not add an index file. |
| Schema validation tooling | No validator or dependency is present. | Use an environment-provided standards-compliant validator or record a blocker; do not hand-roll one. |
| Production code patterns | There is no production code, test suite, or gem scaffold. | Do not create or infer implementation analogs in Phase 0. |

## Metadata

**Sources read:** `AGENTS.md`, `00-CONTEXT.md`, `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `SUMMARY.md`, `STACK.md`, `FEATURES.md`, `ARCHITECTURE.md`, `PITFALLS.md`

**Search scope:** Entire tracked repository excluding research cache payloads; no production source files exist.

**Pattern extraction date:** 2026-08-16

**Coverage:** 5 exact-content analogs, 19 partial-content analogs, 5 files with no repository analog.
