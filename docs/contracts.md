# Draft Contracts

> **Status: Draft / unimplemented.** Every schema, command, option, stream,
> ordering rule, exit meaning, support statement, and compatibility statement in
> this document is a pre-implementation proposal. None is available, supported,
> or a compatibility promise until its owning roadmap phase proves it.

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
| Finding evidence | [`finding-v1.schema.json`](../schemas/finding-v1.schema.json) | [`finding-v1.json`](../examples/finding-v1.json) | `schema_version: "1.0"` | Draft / unimplemented |
| Parsed configuration | [`configuration-v1.schema.json`](../schemas/configuration-v1.schema.json) | [`.railverdict.yml` example](../examples/configuration-v1.yml) | `version: 1` | Draft / unimplemented |
| Verification result | [`result-v1.schema.json`](../schemas/result-v1.schema.json) | [`result-v1.json`](../examples/result-v1.json) | `schema_version: "1.0"` | Draft / unimplemented |

Each draft schema declares its own `$schema` and absolute, versioned `$id`.
Every `$ref` is an internal `#/...` fragment, so validating any document
requires no mutable remote schema. Every root and nested object rejects unknown
fields. This strict behavior is draft / unimplemented and will become a
compatibility rule only after its owning implementation phase proves it.

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
display formatting, timestamps, process IDs, or absolute paths. Phase 1 may use
a documented draft payload; Phase 3 owns the final payload, algorithm migration,
collision vectors, and baseline compatibility rules.

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
separate policy decision and `GateResult`. These semantics remain draft /
unimplemented until the trustworthy core proves them.

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

Every command and option below is Draft / unimplemented. The table is an exact
pre-implementation surface, not an installation, availability, or support
claim.

| Command | Exact draft options | Draft read/write boundary | Status |
|---|---|---|---|
| `railverdict init` | `--config PATH`, `--force` | May write the explicitly requested configuration; overwrite requires explicit `--force` | Draft / unimplemented |
| `railverdict doctor` | `--config PATH`, `--format console\|json` | Read-only observation; never installs or mutates tools | Draft / unimplemented |
| `railverdict check` | `--config PATH`, `--format console\|json`, `--changed`, `--base REV` | Read-only verification; never creates or updates a baseline | Draft / unimplemented |
| `railverdict baseline create` | `--config PATH`, `--output PATH`, `--format console\|json` | Phase 1 exposes the boundary and rejects or defers the operation explicitly; Phase 3 owns the actual atomic baseline write | Draft / unimplemented |
| `railverdict findings` | `--config PATH`, `--format console\|json` | Read-only projection of normalized findings | Draft / unimplemented |

The global options `--help` and `--version` are also Draft / unimplemented.
Production ownership of `railverdict check --changed` and `--base REV` belongs
to Phase 4; their appearance here does not claim working Git scope in Phase 1.
No draft command or option authorizes arbitrary command execution or adds an
autofix, hosted-platform, or optional-intelligence implementation.

### Draft deterministic ordering

Draft / unimplemented ordering is stable and deterministic. Analyzer results
are ordered by normalized analyzer identifier. Findings are ordered by
normalized repository-relative path, start line, end line, analyzer, rule ID,
fingerprint, and finding ID; absent optional location values sort before present
values. Emitted maps use stable key order. Process completion order, filesystem
enumeration order, locale, timezone, and temporary paths cannot change the
canonical ordering. The owning implementation phases must prove these rules
before they become compatibility promises.

### Draft stdout and stderr contract

In draft / unimplemented JSON mode, stdout contains exactly one JSON document
followed by one newline; nothing else is written to stdout. Diagnostics and
progress are written only to stderr. Banners, ANSI escapes, logs, warnings, and
human prose cannot contaminate JSON stdout.

In draft / unimplemented console mode, the human report may use stdout while
diagnostics remain on stderr. Reporters are pure deterministic projections:
they do not execute analyzers, apply policy, mutate results, or choose process
exit status. The CLI performs the single result-to-exit mapping. Agent consumers
must use the versioned JSON fields together with the exit status, never parse
human prose.

### Draft exit contract

| Proposed exit | Exact draft meaning | Status |
|---:|---|---|
| Exit `0` | A completed trustworthy gate produced `PASS` or a non-blocking `WARN` | Draft / unimplemented |
| Exit `1` | A completed trustworthy gate produced policy `FAIL` | Draft / unimplemented |
| Exit `2` | No trustworthy gate completed because of usage, configuration, tool, parser, or internal failure | Draft / unimplemented |
| Exit `130` | The user interrupted execution after child-process cleanup | Draft / unimplemented |

These four proposed exits are Draft / unimplemented. Phase 1 must prove the
core mappings, while later owning phases must preserve or explicitly migrate
the contract before any support or compatibility claim.

## Draft Compatibility Boundary

The schema documents, examples, command names, options, ordering, streams, and
exits are executable design constraints for future tests, not current product
behavior. Phase 1 owns the first trustworthy core proof; Phase 4 owns production
changed-scope proof; later schema changes remain independent from gem versions.
Until those proofs exist, every surface in this guide is Draft / unimplemented.
