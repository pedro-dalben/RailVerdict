# Architecture Research

**Project:** LineClear
**Domain:** Local-first Rails verification framework
**Researched:** 2026-08-16
**Confidence:** MEDIUM

## Research Position

LineClear should be one Ruby gem and one local process. It does not need a database, daemon, service mesh, plugin marketplace, hosted control plane, or separate gems. The smallest architecture that preserves the product contract is a deterministic application core surrounded by process, CLI, reporter, AI, GitHub, and future MCP adapters.

This document uses three labels:

- **Standard:** behavior required or described by an external specification or official platform documentation.
- **Recommendation:** the architecture LineClear should adopt.
- **Unresolved decision:** a choice that needs a focused ADR or implementation spike before it becomes a compatibility promise.

## Four-Layer Architecture

### System Overview

```text
Runtime data flows upward; policy authority stops in the verification core.

┌─────────────────────────────────────────────────────────────────────┐
│  4. AGENT CONSUMERS                                                 │
│  CLI users │ CI │ coding agents │ future MCP │ GitHub adapter       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ consumes GateResult / RepairPacket
┌──────────────────────────────▼──────────────────────────────────────┐
│  3. OPTIONAL INTELLIGENCE                                           │
│  ContextBuilder │ Redactor │ AIProvider │ AIAnalysis │ AICache      │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ reads immutable findings; never gates
┌──────────────────────────────▼──────────────────────────────────────┐
│  2. DETERMINISTIC VERIFICATION CORE                                 │
│  Normalize │ Fingerprint │ Baseline │ Waiver │ Policy │ GateResult  │
└──────────────────────────────▲──────────────────────────────────────┘
                               │ AnalyzerResult facts
┌──────────────────────────────┴──────────────────────────────────────┐
│  1. EVIDENCE COLLECTION                                             │
│  RunContext │ ProcessRunner │ analyzer adapters │ Git context       │
└─────────────────────────────────────────────────────────────────────┘
```

**Recommendation — dependency rule:** source dependencies point toward stable contracts, never toward delivery mechanisms. The verification core defines the ports and canonical value objects. Evidence adapters implement `Analyzer` and return `AnalyzerResult`; CLI, reporters, AI, GitHub, and MCP depend on core application services. The core imports none of those concrete adapters. Runtime evidence flows from analyzers into the core, while decisions and read models flow outward.

The practical rules are:

1. Evidence records what a tool did and observed; it does not decide whether a merge is allowed.
2. The core normalizes facts, correlates them with a baseline and waivers, applies policy, and alone creates `GateResult`.
3. Intelligence receives an immutable `GateResult`/`Finding` snapshot and may add advice, but its output is excluded from the default gate.
4. Agent-facing adapters render or transport existing application-service results. They do not reimplement verification.

### Minimal Component Map

| Component | Owns | Must not own |
|---|---|---|
| `Check` application service | End-to-end orchestration and deterministic ordering | CLI rendering, analyzer parsing details, AI calls |
| `Configuration` | Load, schema validation, defaults, provenance of effective values | Arbitrary internal tuning knobs |
| `RunContext` | Repository root, revisions, Ruby/Rails/tool metadata, selected scope | Mutable global state |
| `Analyzer` adapters | Availability/version checks, argv construction, native-output parsing | Policy, baselines, reporter formatting |
| `ProcessRunner` | Safe process lifecycle and bounded capture | Analyzer-specific exit semantics |
| `Normalizer` | Convert successful analyzer evidence to canonical `Finding` values | Gate decisions |
| `FingerprintBuilder` | Canonical identity components and algorithm versions | State classification by itself |
| `BaselineComparator` | Match current and historical fingerprints and classify state | Policy actions |
| `WaiverResolver` | Match valid/expired waivers to findings | Silently suppress evidence |
| `PolicyEvaluator` | Convert classified findings and incomplete evidence into decisions | Analyzer execution or AI interpretation |
| `GateResult` | Immutable completed-run result | Rendering logic |
| `ConsoleReporter` / `JsonReporter` | Pure projection of result values | Mutation, policy, network access |
| `AIService` (later) | Explicitly opted-in advisory analysis | Default gate authority or code editing |
| `RepairPacketBuilder` (later) | Deterministic agent context and verification commands | Applying repairs |
| GitHub/MCP adapters (later) | Transport and platform mapping | A second verification engine |

### Recommended Project Structure

Keep the public shape horizontal and boring. Split only where contracts or multiple implementations justify it.

```text
exe/
└── LineClear
lib/
├── LineClear.rb
└── LineClear/
    ├── version.rb
    ├── cli.rb
    ├── check.rb
    ├── contracts/          # Finding, AnalyzerResult, GateResult, decisions
    ├── configuration.rb
    ├── run_context.rb
    ├── process_runner.rb
    ├── git_context.rb
    ├── analyzers/          # one file per external tool adapter
    ├── verification/       # normalize, fingerprint, baseline, waiver, policy
    ├── reporters/          # console and JSON first
    └── intelligence/       # absent until the optional-AI phase
schemas/                    # canonical published JSON Schemas
spec/
fixtures/                   # synthetic tool outputs and tiny synthetic apps
docs/adr/
```

Do not create a class for every noun on day one. Immutable structs/data objects plus small modules are sufficient until behavior appears. In particular, `Evidence`, `Fingerprint`, and `PolicyDecision` may begin as nested values inside their owning result contracts rather than as framework-like base classes.

## End-to-End `LineClear check` Flow

```text
argv
  │
  ▼
CLI parses command ──► Configuration loads and validates
  │                              │
  └──────────────┬───────────────┘
                 ▼
          RunContext resolves repository and requested scope
                 │
                 ▼
          Check selects ordered analyzers
                 │
                 ▼
    ProcessRunner executes each argv array safely
                 │
                 ▼
    Analyzer parses bounded native output → AnalyzerResult
                 │
                 ▼
    Normalizer → Finding[] → FingerprintBuilder
                 │
                 ▼
    BaselineComparator → state classifications
                 │
                 ▼
    WaiverResolver → active / expired / unmatched waiver facts
                 │
                 ▼
    PolicyEvaluator → PolicyDecision[] → GateResult
                 │
        ┌────────┴─────────┐
        ▼                  ▼
 ConsoleReporter      JsonReporter
        │                  │
      stdout        one JSON document on stdout
        └────────┬─────────┘
                 ▼
           stable exit status

Optional, after GateResult exists:
GateResult + selected context → AIService → AIAnalysis
GateResult + deterministic context (+ optional AIAnalysis) → RepairPacket
```

Determinism requires a stable analyzer order, finding sort order, path normalization, canonical serialization, fixed defaults, explicit tool versions in run metadata, and no timestamps or random identifiers in equality-sensitive output. A run identifier may exist for tracing, but it must not affect fingerprints, decisions, or deterministic comparison.

## Canonical Contracts and Responsibilities

### `Finding`

`Finding` is immutable, analyzer-independent normalized evidence. It should contain:

- `schema_version`;
- stable run-local `id` for references, separate from identity;
- versioned fingerprint(s);
- `origin` (`deterministic`, `runtime`, `ai`, or `custom`);
- analyzer name, analyzer version, and native rule identifier;
- normalized category, severity, and evidence confidence;
- repository-relative location with optional range;
- normalized message and optional structured evidence references;
- lifecycle state assigned by comparison (`introduced`, `existing`, `resolved`, `changed`, `moved`, `suppressed`, or `waived`).

**Recommendation:** do not store `blocking` on `Finding`. Blocking is a policy decision, not evidence. If the schema draft retains it for presentation convenience, it must be a derived field copied from a `PolicyDecision`, never analyzer input.

### `AnalyzerResult`

`AnalyzerResult` is the complete fact record for one analyzer invocation:

- analyzer identity, detected version, capabilities, and supported/unsupported state;
- normalized execution outcome: `succeeded`, `unavailable`, `unsupported`, `timed_out`, `signaled`, `failed`, or `parse_failed`;
- exit status, terminating signal, duration, and timeout/truncation flags;
- bounded stdout/stderr captures or content references, with byte counts;
- parsed native findings/evidence when parsing succeeded;
- safe diagnostics that never contain the child environment or secrets.

An unavailable, timed-out, malformed, or unsupported required analyzer is not an empty successful result. It must reach policy as incomplete evidence so LineClear cannot report a trustworthy pass.

### `GateResult`

`GateResult` is the only deterministic gate output. It contains:

- result schema version and LineClear version;
- `PASS`, `WARN`, or `FAIL` plus an outcome kind (`complete` or `incomplete`);
- normalized run context and effective policy identifiers;
- analyzer results and evidence completeness;
- findings in deterministic order;
- baseline states, waiver states, and explicit policy decisions;
- blocking findings and stable summary counts;
- duration breakdown that does not affect equality.

`GateResult` never embeds provider credentials, raw environment values, or authoritative AI conclusions.

### Configuration

Configuration expresses user policy and integration selection, not object wiring. It owns:

- format version;
- policy mode and thresholds;
- enabled/required analyzers;
- changed-scope base settings;
- baseline and waiver paths;
- fixed execution limits where exposure is genuinely useful;
- explicit AI mode and remote-transmission consent when AI exists.

Unknown keys are errors with a JSON Pointer-like path and suggested valid keys. Defaults are materialized into an inspectable effective configuration. Environment variables may select secrets and CI context, but must not silently change gate policy.

### Baseline

The baseline stores only what comparison needs:

- baseline schema version and creation metadata;
- LineClear and fingerprint algorithm versions;
- normalized fingerprints/partial fingerprints;
- minimum analyzer/rule/path/category metadata needed for explanation and migration.

It does not store source files, full analyzer logs, AI prompts, or credentials. Baseline creation is explicit and atomic: write a temporary file in the destination directory, validate it, then rename it.

### Waiver

A waiver is explicit policy input keyed by fingerprint, never by ephemeral finding ID. It contains reason, owner, creation date, expiry, and optional issue reference. The resolver preserves the finding and attaches waiver state; reporters must show active and expired waivers. Expired waivers do not disappear and are evaluated by policy.

### Reporter

A reporter is a pure function over `GateResult` and optional advisory attachments. It does not execute analyzers, read Git, apply policy, or call AI. `JsonReporter` validates its own output against the published CLI-result schema before writing in development/contract tests; production may use construction by validated domain objects to avoid redundant cost.

### `AIAnalysis`

`AIAnalysis` is an explicitly advisory, schema-validated attachment containing:

- referenced finding fingerprint and analysis schema version;
- provider, model, prompt version, and context hash;
- assessment, confidence, explanation, suggested remediation, and tests;
- unavailable/refused/redacted status;
- a manifest of files/fragments considered, without hidden context.

It never mutates `Finding`, `PolicyDecision`, or `GateResult`. Invalid model output degrades to `AI analysis unavailable`.

### `RepairPacket`

The repair packet is deterministic and useful without AI. It owns:

- the canonical finding and policy decision;
- bounded evidence and relevant diff;
- explicitly selected related files/tests/Rails context;
- suggested verification commands as argument arrays;
- schema/version metadata and context provenance;
- optional, clearly labeled `AIAnalysis`.

It does not edit files, execute suggested repairs, or grant an agent new permissions.

## Contract Versioning Strategy

**Standard:** JSON Schema uses `$schema` to declare a dialect and `$id` as a schema URI. Each referenced schema must declare its own dialect. The official documentation recommends root declarations rather than relying on validator defaults ([JSON Schema dialect declaration](https://json-schema.org/understanding-json-schema/reference/schema), accessed 2026-08-16; [JSON Schema getting started](https://json-schema.org/learn/getting-started-step-by-step), accessed 2026-08-16).

**Recommendation:** use JSON Schema draft 2020-12 for every published document contract. Version each contract independently; do not equate a document version with the gem version.

| Contract | Version field / identity | Compatibility rule |
|---|---|---|
| Finding JSON | `schema_version: "1.0"`; versioned `$id` | Major for removals/meaning changes; minor for additive optional fields |
| `AnalyzerResult` JSON | Independent `schema_version` | Same rule; native output never becomes public contract |
| `GateResult` / CLI JSON | `schema_version: "1.0"` at document root | One JSON document; additive minor changes only within a major |
| Configuration | `version: 1` | Major-only migration boundary; unknown keys remain errors |
| Baseline | `version: 1` plus fingerprint algorithm versions | Reader supports documented historical major(s); explicit migration before removal |
| Waiver file | `version: 1` | Same migration policy as configuration |
| Fingerprint | algorithm name such as `lineclear/v1` | Never silently change inputs under an existing name |
| Reporter API | Internal until declared public | Version with gem SemVer once public |
| Analyzer API | Internal until declared public | Contract tests first; 1.0 public commitment only after proven |

Every schema fixture set needs:

1. valid current examples;
2. invalid boundary examples;
3. every historical supported version;
4. a reader test proving old documents still load or produce an explicit migration error;
5. golden JSON proving deterministic key/value content (object key order itself is not a JSON compatibility contract).

**Standard:** SemVer 2.0.0 says `0.y.z` is initial development, `1.0.0` defines the public API, and incompatible public API changes after 1.0 require a major release ([Semantic Versioning 2.0.0](https://semver.org/), accessed 2026-08-16).

**Recommendation:** before 1.0, LineClear may break contracts only with changelog entries, migration instructions, and fixture updates. After 1.0, the public API includes schemas, exit statuses, config/baseline/waiver formats, documented Ruby extension APIs, and deterministic behavioral semantics. A gem major release does not automatically require every document schema to bump; bump only the contract that breaks.

## Safe Ruby Subprocess Boundary

**Standard:** Ruby distinguishes command-line strings that may invoke a shell from executable-plus-argument forms; `Process.spawn` supports environment hashes, `unsetenv_others`, process groups, descriptor closing, signals, waiting, and a monotonic clock. Ruby's `Open3.popen3` passes arguments/options to `Process.spawn` and warns that stdout and stderr must be drained concurrently ([Ruby 3.4.1 `Process`](https://ruby-doc.org/3.4.1/Process.html), accessed 2026-08-16; [Ruby `Open3`](https://ruby-doc.org/3.2/stdlibs/open3/Open3.html), accessed 2026-08-16). Ruby also explicitly warns that command-executing APIs must not receive unknown or unsanitized commands ([Ruby command injection documentation](https://ruby-doc.org/3.4.1/command_injection_rdoc.html), accessed 2026-08-16).

**Recommendation:** all external execution goes through one `ProcessRunner` with a request resembling:

```ruby
Command = Data.define(:env, :executable, :argv, :chdir, :timeout_seconds)
```

The adapter supplies a trusted executable and separate argument strings. Neither configuration nor repository text may supply an interpolated shell command. The runner should:

1. call `Process.spawn`/`Open3.popen3` with `executable, *argv`, never a joined string;
2. use a verified repository directory for `chdir`, close stdin, set `close_others: true`, and create a child process group;
3. construct a minimal environment with `unsetenv_others: true`, adding only documented Ruby/Bundler/tool variables needed by that adapter; never pass the parent `ENV` wholesale;
4. read stdout and stderr concurrently with `IO.select` or dedicated reader threads;
5. cap retained stdout, retained stderr, and total bytes independently; continue draining and discarding after a cap so the child cannot deadlock, while recording truncation and actual byte counts;
6. measure deadlines with `Process.clock_gettime(Process::CLOCK_MONOTONIC)`;
7. on timeout or parent interruption, signal the process group with `TERM`, wait a short fixed grace period, then `KILL` the group if necessary;
8. always close pipes, reap the child, and delete adapter-owned temporary files in `ensure`;
9. return structured diagnostics instead of raising ordinary analyzer failures through the orchestration stack.

Diagnostics must include safe command identity, analyzer/tool version, repository-relative working directory, start/duration, exit status or signal, timeout, truncation, captured byte counts, and parse status. They must exclude the full environment and redact secret-like values from captured output before persistence or remote transmission.

**Unresolved decision:** exact environment allowlist, byte caps, timeout defaults, Windows process-tree termination, and interaction with Bundler need a Phase 1 spike across supported platforms. These values should start as internal constants. Expose configuration only when a real supported analyzer needs it.

## Fingerprint Design

### Options and Trade-offs

| Option | Stability | Cost | Decision |
|---|---|---|---|
| Native analyzer fingerprint | Excellent when present, but tool-specific and inconsistent across adapters | Low | Preserve as a partial fingerprint, not the sole LineClear identity |
| `analyzer + rule + path + line` | Cheap | Poor under inserted lines and renames | Reject |
| Canonical semantic composite | Good under unrelated line movement; explainable | Moderate normalization work | Use for `lineclear/v1` |
| Full Ruby AST/subtree identity | Better across moves, but parser/version and ambiguity costs are high | High | Defer until evidence shows v1 is inadequate |
| Fuzzy message/snippet matching | Helps relocation but can merge distinct findings | Moderate and heuristic | Use only as a conservative secondary correlation signal |

**Standard:** SARIF requires fingerprint property names to be versioned, recommends comparing the newest version common to both results, supports partial fingerprints, and warns against absolute line numbers and nondeterministic absolute URIs in identity ([OASIS SARIF 2.1.0 Errata 01, sections 3.27.16–17 and Appendix B](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html), accessed 2026-08-16).

**Recommendation — `lineclear/v1`:** hash canonical JSON containing:

- normalized analyzer namespace and rule identifier;
- normalized repository-relative path with `/` separators;
- semantic scope supplied reliably by the adapter (class/module/method), when present;
- a normalized evidence key or native partial fingerprint;
- a normalized local code/snippet hash only when needed to disambiguate duplicate rule/path/scope findings.

Use SHA-256 and prefix the published value with the algorithm name. Do not include absolute paths, line numbers, timestamps, run IDs, policy action, state, waiver, severity, full human prose, or analyzer version. Analyzer and normalizer version changes live in run metadata; if they change logical identity, create `lineclear/v2`.

Store documented partials (`native/...`, `scope/...`, `snippet/...`) beside the composite. During an algorithm migration, write old and new fingerprints, match using the newest common algorithm, migrate the baseline explicitly, and remove an old algorithm only under the baseline compatibility policy.

Git rename data may rewrite the old path as a candidate during correlation. A secondary match is accepted only when it is unique and supported by rule plus scope/evidence partials. Ambiguity fails closed as one introduced and one resolved finding rather than silently merging unrelated debt.

### Compatibility Test Matrix

Golden fingerprint vectors must prove expected behavior for:

| Change | Expected identity |
|---|---|
| Insert unrelated lines above finding | Same |
| Line-ending or path-separator normalization | Same |
| Message punctuation or volatile numeric detail | Same if evidence meaning is unchanged |
| File rename reported by Git | Correlated as moved, with auditable old/new paths |
| Method moved unchanged within one file | Same only when semantic evidence is unambiguous |
| Rule identifier changes | Different unless an explicit adapter migration maps it |
| Material offending code change | Changed or introduced/resolved, not silently existing |
| Two identical violations in one scope | Distinct; snippet/ordinal disambiguation must be deterministic |
| Analyzer upgrade with identical logical finding | Same |
| Fingerprint algorithm upgrade | New value plus successful old/new overlap migration |

**Unresolved decision:** whether the first version uses Ruby AST scope extraction or only adapter-provided scopes. Choose the latter for Phase 3 unless regression fixtures show unacceptable churn; Phase 5 is the correct place for Rails/Ruby semantic enrichment.

## Git and Changed-Code Boundary

**Standard:** Git defines `git diff A...B` as the diff from `git merge-base A B` to `B`; `--name-status` exposes add/modify/delete/rename state, and `-z` NUL-terminates paths without quoting ([Git `diff` documentation](https://git-scm.com/docs/git-diff.html), accessed 2026-08-16).

**Recommendation:** `GitContext` uses only local Git commands through `ProcessRunner` and returns structured repository facts. GitHub is never the source of truth for the diff.

For `LineClear check --changed`:

1. resolve repository root with Git and reject paths outside it;
2. resolve base precedence as CLI `--base`, then project config, then an explicit platform-adapter input;
3. require the base object to exist locally; do not fetch or silently guess a different base;
4. compute `merge_base = git merge-base(base_revision, HEAD)`;
5. compare `merge_base` to the current working tree so committed, staged, and unstaged tracked changes are visible;
6. enumerate untracked non-ignored files separately and treat them as added;
7. parse `--name-status -z --find-renames` and zero-context patches for changed-line ranges;
8. preserve adds, deletes, renames, binary files, submodules, and conflicts as explicit states.

Deleted files can resolve baseline findings but cannot produce current locations. Renames feed correlation but never prove identity alone. Shallow clones or missing base history produce an operationally incomplete result with a corrective diagnostic; LineClear must not fetch from the network implicitly.

**Unresolved decision:** the friendly local default when no base is configured. Do not silently choose `HEAD`, because that omits committed branch changes. Phase 4 should test upstream-branch and remote-default-branch discovery, then either document a deterministic default or require `--base`.

## Reporter and CLI Process Contract

**Standard:** POSIX utility conventions use zero for successful completion, greater than zero for errors, and standard error for diagnostics ([POSIX.1-2017 utility conventions](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap01.html), accessed 2026-08-16).

**Recommendation:** freeze this small exit-code contract before agents depend on it:

| Exit | Meaning |
|---:|---|
| `0` | Completed trustworthy gate with `PASS` or non-blocking `WARN` |
| `1` | Completed trustworthy gate with policy `FAIL` |
| `2` | Gate could not complete trustworthily: usage/config/schema/baseline error or required analyzer failure |
| `130` | Interrupted by user; children were cleaned up |

In `--format json` mode:

- stdout contains exactly one schema-valid JSON document followed by a newline;
- stderr contains progress and diagnostics only;
- no banners, ANSI escapes, logs, warnings, or AI prose appear on stdout;
- when enough context exists, exits `1` and `2` still emit a machine-readable result/error document on stdout;
- reporters never call `exit`; the CLI maps `GateResult`/application errors to status once.

Console mode may use stdout for the human report and stderr for diagnostics. Reporter ordering and summaries remain deterministic. Machine consumers key off schema fields and exit status, never human text.

## Optional AI Security Boundary

**Standard:** OWASP identifies direct and indirect prompt injection, recommends clear instruction/data separation, validation of inputs and outputs, least privilege, and additional controls for untrusted external content ([OWASP LLM Prompt Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html), accessed 2026-08-16). OWASP specifically says repository content such as issues, pull requests, comments, and READMEs must be treated as untrusted input to coding agents ([OWASP Secure Coding with AI Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secure_Coding_with_AI_Cheat_Sheet.html), accessed 2026-08-16).

**Recommendation:** AI remains after the gate and outside the core:

```text
Finding/GateResult snapshot
        ↓
deterministic ContextBuilder → manifest and byte/token budget
        ↓
denylist + secret scanning + Redactor (fail closed)
        ↓ explicit local/remote consent
structured prompt: trusted instructions + delimited untrusted data
        ↓
provider adapter with no write tools
        ↓
schema validation + output limits
        ↓
AIAnalysis (advisory attachment only)
```

Repository text, diffs, commit messages, issue text, analyzer messages, and tool output are data, never instructions. The initial AI provider receives no executable tools. Remote mode requires explicit configuration, a previewable context manifest, secret scanning, redaction, request/context budgets, and cache keys containing fingerprint, context hash, provider, model, prompt version, and response schema version.

AI failures cannot alter the deterministic exit status. The deterministic repair packet exists before AI; model suggestions are a labeled optional field.

### Untrusted Forks

**Standard:** GitHub documents that fork `pull_request` workflows receive read-only tokens and no secrets, while `pull_request_target` runs with elevated trust and becomes unsafe when it checks out and executes fork code ([GitHub secure `pull_request_target` guidance](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target), accessed 2026-08-16; [GitHub Actions secure-use reference](https://docs.github.com/en/actions/reference/security/secure-use), accessed 2026-08-16).

**Recommendation:** the default GitHub Actions example runs deterministic checks on `pull_request` with read-only permissions and no LineClear/AI secrets. Remote AI is skipped for fork PRs. No workflow may combine privileged secrets with checkout/execution of untrusted fork code. A later privileged reporting workflow may consume a strictly validated artifact as untrusted data, but it must not execute its contents.

## Future Adapter Boundaries

### GitHub

GitHub Actions, PR summaries, annotations, and SARIF are delivery adapters over `Check` and `GateResult`. GitHub identifiers live in the adapter mapping, not in `Finding`. The adapter may translate repository-relative locations and policy decisions, but it cannot recalculate the gate or define changed files.

### MCP

**Standard:** MCP defines a host/client/server architecture with capability negotiation; servers expose focused tools, resources, and prompts over the protocol ([MCP architecture, protocol revision 2025-06-18](https://modelcontextprotocol.io/specification/2025-06-18/architecture), accessed 2026-08-16; [MCP server primitives](https://modelcontextprotocol.io/specification/2025-06-18/server/index), accessed 2026-08-16).

**Recommendation:** after CLI JSON contracts stabilize, an MCP server exposes thin tools such as `check`, `findings`, `get_finding`, and `repair_packet`. Each calls the same application services as the CLI and returns the same versioned contracts. The MCP server owns protocol lifecycle, capability declarations, consent, and serialization—not analyzers, fingerprinting, baselines, or policy. Start read-only; do not expose code-editing tools.

## Failure Semantics

| Failure | Domain representation | Gate/exit behavior |
|---|---|---|
| Optional analyzer unavailable | `AnalyzerResult.unavailable` | Policy-controlled warning; trustworthy only if not required |
| Required analyzer unavailable/timeout | Incomplete evidence | `FAIL`, outcome `incomplete`, exit `2` |
| Native tool returns findings via nonzero status | Adapter-normalized success with findings | Policy decides; do not confuse with runner failure |
| Parser rejects output | `parse_failed` with bounded diagnostics | Required: exit `2`; optional: explicit warning |
| Invalid config/baseline/waiver schema | Structured application error | No gate claim; exit `2` |
| Expired waiver | Finding remains plus expired waiver state | Policy decides, never silently suppressed |
| AI unavailable/invalid output | `AIAnalysis.unavailable` | No change to gate or exit |
| Missing Git base/history | Incomplete Git context | `--changed` cannot pass; exit `2` |

## Anti-Patterns to Reject

### Analyzer-Specific Core Fields

Do not add RuboCop/Brakeman-specific properties to `Finding`. Preserve native detail under namespaced evidence and normalize only stable cross-tool concepts.

### Shell Strings and Unbounded Capture

Do not use backticks, interpolated `system`, or `Open3.capture3` without bounded concurrent draining. A timeout around an unbounded capture does not solve process-tree cleanup or memory exhaustion.

### Policy in Reporters or Adapters

Do not let reporters, GitHub, MCP, or AI change blocking state. They consume `GateResult`.

### One Global Version

Do not bump every schema whenever the gem releases. Independent contracts need independent compatibility histories.

### Line-Only Baselines

Do not use absolute line numbers as identity. Keep line numbers as current evidence locations only.

### Premature Semantic Graph

Do not build a Rails knowledge graph in the core. Add explicit context resolvers in Phase 5 only where repair/context evidence proves value.

## Build Order Mapped to Supplied Phases

| Phase | Architecture work | Explicit boundary |
|---|---|---|
| **0 — Product, Naming, Legal Foundation** | Ratify layer/dependency ADRs, threat model, contract drafts, version policy, exit-code draft, schema examples, and third-party execution/licensing policy | Documentation and decisions only; no production core implementation |
| **1 — Trustworthy Core** | Build one vertical `check` path: config → context → one adapter through `ProcessRunner` → `AnalyzerResult` → `Finding` → minimal policy → `GateResult` → console/JSON | No AI, baseline engine, GitHub, MCP, or abstraction for hypothetical adapters |
| **2 — Evidence Ecosystem** | Add only selected adapters behind the proven contract, each with native-output fixtures and runner/parser failure tests | No analyzer-specific policy logic |
| **3 — Fingerprints, Baselines, Policies** | Freeze `lineclear/v1`, baseline/waiver schemas, comparator, policy modes, migrations, and golden compatibility vectors | No AST system unless fixtures prove it necessary |
| **4 — Git Diff and PR Readiness** | Add local merge-base/diff scope, rename correlation, SARIF reporter, and unprivileged GitHub Actions example | GitHub remains an adapter; no hosted app |
| **5 — Rails-Aware Intelligence** | Add small deterministic context resolvers that improve evidence/fingerprint/repair context | No general semantic graph |
| **6 — Optional AI Intelligence** | Add provider port, context manifest, redaction/secret controls, budgets/cache, validated `AIAnalysis` | AI stays advisory and after the gate |
| **7 — Agent Repair Workflow** | Stabilize deterministic `RepairPacket`, verification commands, and agent-facing errors | LineClear verifies; external agents edit |
| **8 — MCP** | Map stable application services/contracts to an MCP server | No duplicated verification implementation |
| **9 — 1.0 Hardening** | Compatibility matrix, migration policy, supported historical readers, security review, public API declaration | Only then promise post-1.0 SemVer stability |

The ordering is dependency-driven: safe execution and canonical results precede integrations; integrations produce the evidence needed to test fingerprint stability; stable fingerprints enable baselines/policy; stable core contracts enable GitHub, AI, repair packets, and MCP without duplicating authority.

## Open Decisions Requiring Focused ADRs or Spikes

1. Supported operating systems and process-group cleanup behavior, especially Windows.
2. Exact environment allowlist needed for Bundler and supported analyzers without leaking credentials.
3. Internal output/time limits and timeout defaults for the first adapter set.
4. Local `--changed` base discovery when no base is configured.
5. Whether adapter-provided semantic scope is sufficient for `lineclear/v1`.
6. How many historical config/baseline/schema majors each release must read before 1.0.
7. Whether `WARN` remains exit `0`; this recommendation should be tested with CI and agent consumers before freezing.

## Confidence Assessment

| Area | Confidence | Reason |
|---|---|---|
| Four-layer boundaries and component ownership | HIGH | Directly constrained by the supplied project contract and minimized to one gem/process |
| Ruby subprocess primitives | MEDIUM | Verified against official Ruby documentation; platform-specific cleanup still needs a spike |
| Schema and SemVer strategy | MEDIUM | Based on official standards; support-window policy remains a project choice |
| Fingerprint strategy | MEDIUM | Aligned with OASIS SARIF guidance; empirical Rails fixture results are not yet available |
| Git changed-scope boundary | MEDIUM | Core semantics verified in official Git documentation; local default-base UX remains open |
| AI/fork boundaries | MEDIUM | Cross-checked against OWASP and GitHub official guidance; provider implementation is deferred |
| MCP boundary | MEDIUM | Based on the official protocol architecture; no adapter should be designed before Phase 8 |

---
*Architecture research for LineClear; all examples and paths are synthetic.*
