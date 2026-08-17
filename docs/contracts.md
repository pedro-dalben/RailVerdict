# Draft Contracts

> **Status: Phase 01 implemented; compatibility remains provisional.** Phase 01
> proves the local core, strict configuration, RuboCop evidence path, result
> envelope, reporters, ordering, and exits. Baseline persistence remains owned
> by Phase 03; changed scope remains owned by Phase 04; no 1.0 compatibility
> promise exists yet.

RailVerdict's draft contracts separate analyzer evidence from deterministic
policy and from reporter output. The authority boundary is defined in
[ARCHITECTURE.md](../ARCHITECTURE.md): analyzers supply facts, policy alone owns
gate decisions, and reporters are pure projections of an existing result.

## Draft Schema Surface

All three schemas use JSON Schema Draft 2020-12 and are independently
versioned. Their domain-based identifiers are draft identifiers; they do not
prove domain ownership or authorize publication.

| Contract | Draft schema | Draft example | Independent version | Status |
|---|---|---|---|---|
| Finding evidence | [`finding-v1.schema.json`](../schemas/finding-v1.schema.json) | [`finding-v1.json`](../examples/finding-v1.json) | `schema_version: "1.0"` | Implemented in Phase 01 |
| Parsed configuration | [`configuration-v1.schema.json`](../schemas/configuration-v1.schema.json) | [`.railverdict.yml` example](../examples/configuration-v1.yml) | `version: 1` | Implemented in Phase 01 |
| Verification result | [`result-v1.schema.json`](../schemas/result-v1.schema.json) | [`result-v1.json`](../examples/result-v1.json) | `schema_version: "1.0"` | Implemented in Phase 01 |

Each draft schema declares its own `$schema` and absolute, versioned `$id`.
Every `$ref` is an internal `#/...` fragment, so validating any document
requires no mutable remote schema. Every root and nested object rejects unknown
fields. Phase 01 proves this strict behavior; compatibility remains provisional
until the 1.0 release gates.

### Draft Finding semantics

The draft Finding contract describes analyzer-independent evidence. It requires
an origin, analyzer and native rule identity, category, severity, confidence,
lifecycle state, full SHA-256 fingerprint, an opaque native-evidence reference,
message, and repository-relative location. `evidence_ref` links to the
producing `AnalyzerResult` without adding analyzer-specific fields to
`Finding`. Location paths use `/`, cannot be absolute, cannot contain `.` or
`..` segments, and cannot contain backslashes or empty segments. Runtime
validation must reject a line range whose `end_line` precedes `start_line`.

`fingerprint` is an opaque deterministic identity over canonical evidence. The
same semantic evidence must produce the same digest independent of ordering,
display formatting, line numbers, timestamps, process IDs, or absolute paths.
Fingerprint v1 uses payload `https://railverdict.dev/fingerprint-payload/v1`
with `fingerprint_version: 1`, `algorithm: sha256`, and canonical keys
`{payload_schema, fingerprint_version, algorithm, analyzer, rule_id, path, message}`
sorted and SHA-256 digested to `sha256:<64hex>` (`lib/rail_verdict/fingerprint.rb`).
Phase 1 draft `v0.1` remains readable for migration divergence tests; new
baselines must record v1. File rename, path change, or message change produces
a different digest by design; fingerprints provide no AST or semantic identity,
and SHA-256 collisions are not handled beyond intentional sharing of identical
payloads. Incompatible fingerprint versions require explicit migration.

`origin: ai` identifies an advisory observation produced by an AI path. It is
not required evidence, cannot create a deterministic gate decision, and must be
kept distinguishable from deterministic or runtime evidence. A future AI
implementation should prefer a separate `AIAnalysis` attachment when no Finding
is needed.

`state: observed` is the standalone-run state and is the only state Phase 1 may
emit without baseline or diff context. `introduced`, `existing`, `resolved`,
`changed`, and `moved` require comparison context owned by Phase 3. `suppressed`
and `waived` are later derived policy classifications, not analyzer execution
results.

A Finding cannot carry `blocking`, `PASS`, `WARN`, `FAIL`, a policy action, or
another gate-authority field. Analyzer input therefore cannot decide whether a
merge is allowed. Any future blocking presentation must be derived from a
separate policy decision and `GateResult`. Phase 01 proves these semantics for
the deterministic core.

### Draft configuration semantics

The configuration schema describes the parsed data value of
`.railverdict.yml`, not YAML source text. The draft input is data-only: no ERB,
object tags, executable values, aliases, permitted classes, permitted symbols,
secret values, or hidden environment precedence. A validator must first use a
safe YAML loader and then validate the resulting strings, integers, booleans,
maps, and arrays against the JSON Schema.

The small draft surface contains only `version`, policy `mode`, and the explicit
strict analyzer map shown in the synthetic example. The initial loader reads one
project `.railverdict.yml` file only; no environment, user, or secondary
configuration source overrides it. UTF-8 is required. Duplicate YAML keys,
aliases, object tags, permitted classes, symbols, and invalid encodings are
rejected. Unknown keys fail with their property path. `enabled: false` with
`required: true` is invalid; disabled analyzers must not be required.

Configuration validation errors report the source path and nested property path
without echoing secret values. A missing file is an explicit configuration
failure, not an implicit default. Phase 1 may use documented defaults only when
they are represented in the effective configuration; Phase 3 owns policy-mode
semantics beyond the minimal Phase 1 fail-closed behavior.

## Baseline, Comparison, and Waiver Contracts (Phase 03 Implemented)

Phase 03 adds `schemas/baseline-v1.schema.json`, `schemas/waiver-v1.schema.json`, `schemas/waivers-v1.schema.json`, and `schemas/configuration-v1.2.schema.json` (optional `baseline.path` / `waivers.path`). See `docs/baselines.md` for creation, discovery, comparison states, policy modes, and waiver expiry/orphan semantics. `railverdict check` is read-only; `railverdict baseline create` is the only baseline writer (atomic, refuse-on-incomplete, `--force` required to overwrite). Fingerprint v1 and baseline readers fail closed on unknown versions with explicit migration to `re-create with railverdict baseline create`.

## Draft Result Contract

`AnalyzerResult` records what an external process did: executable and argv,
tool version when known, execution status, evidence completeness, finding IDs,
and an operational failure when execution did not succeed. `succeeded` with
`complete` means the analyzer returned parseable evidence; `unavailable`,
`unsupported`, `timed_out`, `signaled`, `failed`, `parse_failed`, `truncated`,
and `malformed` are incomplete evidence states. A successful analyzer finding
is not an operational failure, and an operational failure is never normalized
as zero findings.

Its versioned fields are `invocation`, `execution_status`, `evidence_status`,
`finding_ids`, and optional `failure` metadata.

`GateResult` is the top-level `result-v1` envelope. It contains the overall
completion state, deterministic gate state, policy evaluation state, finding
summaries with derived blocking presentation, analyzer results, operational
failures, and decision reasons. `gate: INCOMPLETE` with
`policy_status: not_evaluated` is an explicit fail-closed result, not a fourth
policy outcome; it maps to draft exit `2`. Complete results use `PASS`, `WARN`,
or `FAIL` and policy states `pass`, `warn`, or `fail`. The result schema is
versioned independently from the Finding and configuration schemas.

The top-level fields are `completion_status`, `gate`, `policy_status`,
`findings`, `analyzer_results`, `operational_failures`, and
`decision_reasons`.

The result schema does not grant analyzers, AI, reporters, GitHub, or MCP gate
authority. Only deterministic policy may derive blocking presentation and the
completed gate state.

## Draft CLI Surface

Every command and option below is implemented or explicitly deferred by Phase
01. The table is an exact surface, not a 1.0 compatibility or support claim.

| Command | Exact draft options | Draft read/write boundary | Status |
|---|---|---|---|
| `railverdict init` | `--config PATH`, `--force` | May write the explicitly requested configuration; overwrite requires explicit `--force` | Implemented in Phase 01 |
| `railverdict doctor` | `--config PATH`, `--format console\|json` | Read-only observation; never installs or mutates tools | Implemented in Phase 01 |
| `railverdict check` | `--config PATH`, `--format console\|json`, `--changed`, `--base REV`, `--baseline PATH`, `--waiver PATH` | Read-only verification; never creates or updates a baseline; baseline/waiver discovered via explicit path, config, or default; `--changed` enforces Git changed scope (`--base` > `git.base` > INCOMPLETE), `RunContext` records `git: {head,base,merge_base,changed_files,changed_line_set}` and `changed_line_coverage` via `ChangedLineEvaluator` | Implemented in Phase 04 |
| `railverdict baseline create` | `--config PATH`, `--output PATH`, `--format console\|json`, `--force` | Atomic baseline write from complete trusted run only; refuses incomplete and refuses silent overwrite; interrupted write leaves old baseline intact | Implemented in Phase 03 |
| `railverdict findings` | `--config PATH`, `--format console\|json` | Read-only projection of normalized findings | Implemented in Phase 01 |

The global options `--help` and `--version` are implemented in Phase 01.
Phase 04 owns production `railverdict check --changed` and `--base REV` with
deterministic Git scope, fail-closed base resolution, and reporters in
`docs/github-actions.md`. No command authorizes arbitrary execution or
autofix.

### Draft deterministic ordering

Implemented Phase 01 ordering is stable and deterministic. Analyzer results
are ordered by normalized analyzer identifier. Findings are ordered by
normalized repository-relative path, start line, end line, analyzer, rule ID,
fingerprint, and finding ID; absent optional location values sort before present
values. Emitted maps use stable key order. Process completion order, filesystem
enumeration order, locale, timezone, and temporary paths cannot change the
canonical ordering. Later phases must preserve these rules before they become
1.0 compatibility promises.

### Draft stdout and stderr contract

In implemented JSON mode, stdout contains exactly one JSON document
followed by one newline; nothing else is written to stdout. Diagnostics and
progress are written only to stderr. Banners, ANSI escapes, logs, warnings, and
human prose cannot contaminate JSON stdout.

In implemented console mode, the human report may use stdout while
diagnostics remain on stderr. Reporters are pure deterministic projections:
they do not execute analyzers, apply policy, mutate results, or choose process
exit status. The CLI performs the single result-to-exit mapping. Agent consumers
must use the versioned JSON fields together with the exit status, never parse
human prose.

### Draft exit contract

| Proposed exit | Exact draft meaning | Status |
|---:|---|---|
| Exit `0` | A completed trustworthy gate produced `PASS` or a non-blocking `WARN` | Implemented in Phase 01 |
| Exit `1` | A completed trustworthy gate produced policy `FAIL` | Implemented in Phase 01 |
| Exit `2` | No trustworthy gate completed because of usage, configuration, tool, parser, or internal failure | Implemented in Phase 01 |
| Exit `130` | The user interrupted execution after child-process cleanup | Implemented in Phase 01 |

These four exits are implemented by Phase 01. Later owning phases must preserve
or explicitly migrate the contract before any 1.0 compatibility claim.

## AIAnalysis Contract (Phase 06)

`schemas/ai-analysis-v1.schema.json` v1.0 defines advisory `AIAnalysis` with `schema_version`, `finding_id`, `fingerprint`, `assessment` (`likely_cause`/`needs_investigation`/`uncertain`), `confidence` (`low`/`medium`/`high`), `summary`, optional `root_cause`, `suggested_fix`, `recommended_tests` (≤20), `evidence_notes` (≤10), and `provenance` (`provider`, `model`, `prompt_version`, `created_at`). `RailVerdict::Intelligence::AIFailure` codes include `disabled`, `provider_unavailable`, `authentication_failed`, `rate_limited`, `timed_out`, `budget_exhausted`, `context_rejected`, `secret_detected`, `response_invalid`, `schema_invalid`. Intelligence is advisory only and never changes `GateResult.gate`/`policy_status`.

Configuration `schemas/configuration-v1.4.schema.json` adds optional top-level `ai` (`enabled`, `mode` `off`/`explain`/`investigate`, `provider`, `model`, `remote` {`enabled`, `trust` `redacted`/`full`}, `budgets` {`max_findings`, `max_requests`, `max_context_bytes`}, `cache` {`enabled`, `max_bytes`}). AI is off by default; remote requires explicit opt-in; `remote trust redacted` is default.

CLI additions: `railverdict explain <finding-id|fingerprint> [--preview-context] [--config PATH] [--format console|json]` and `railverdict investigate [--limit N] [--preview-context]`. `--preview-context` prints the bounded manifest without network.

## Draft Compatibility Boundary

The schema documents, examples, command names, options, ordering, streams, and
exits are executable design constraints for future tests, not current product
behavior. Phase 1 owns the first trustworthy core proof; Phase 4 owns production
changed-scope proof; later schema changes remain independent from gem versions.
Phase 01 proves the local surfaces described here; later phases own their
remaining boundaries and 1.0 compatibility policy.
