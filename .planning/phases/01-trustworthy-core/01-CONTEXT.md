---
phase: 01-trustworthy-core
created: 2026-08-16
updated: 2026-08-16
---

# Phase 01 Context

Phase 00 is independently verified. Its documents are the architectural source of
truth for this phase: `PROJECT.md`, `PHILOSOPHY.md`, `ARCHITECTURE.md`,
`ROADMAP.md`, `SECURITY.md`, `docs/contracts.md`, `docs/adr/`, `schemas/`, and
`examples/`. Phase 01 implements the smallest trustworthy vertical slice:
`railverdict check` over a synthetic Rails project, producing a deterministic,
fail-closed, offline gate from RuboCop evidence.

## Confirmed contracts to implement

- Five exact CLI surfaces: `init`, `doctor`, `check`, `baseline create`,
  `findings`; global `--help`/`--version` (docs/contracts.md Draft CLI Surface).
- Exits: `0` completed PASS/non-blocking WARN, `1` completed policy FAIL,
  `2` no trustworthy gate (usage/configuration/tool/parser/internal),
  `130` user interruption after child cleanup.
- `result-v1.schema.json` envelope: `schema_version`, `completion_status`,
  `gate`, `policy_status`, `findings`, `analyzer_results`,
  `operational_failures`, `decision_reasons`; incomplete/interrupted forces
  `gate: INCOMPLETE`, `policy_status: not_evaluated`, and at least one
  operational failure.
- `finding-v1.schema.json`: analyzer-independent evidence, full
  `sha256:` fingerprint, repository-relative location, no gate authority fields.
- `configuration-v1.schema.json`: integer `version: 1`, policy `mode`, strict
  `analyzers.rubocop` selection; `enabled: false` with `required: true` invalid.
- Ordering: analyzer results by analyzer id; findings by normalized path,
  start line (absent before present), end line, analyzer, rule id,
  fingerprint, finding id. Maps emit stable key order.
- JSON mode: exactly one JSON document plus one newline on stdout; diagnostics
  only on stderr.

## Phase 01 engineering decisions

These are the smallest reasonable engineering interpretations where the draft
contracts leave implementation latitude. Each is recorded here instead of
reopening Phase 00 decisions.

1. **Runtime schema validation dependency.** `json_schemer` (`>= 2.5, < 3`) is
   added as the single intentional third-party runtime dependency, per
   STACK.md: canonical configuration is validated after parsing and the
   result envelope is validated immediately before JSON mode prints it.
   Validation failure fails closed (exit `2`, diagnostics on stderr, no stdout
   document).
2. **Ruby/Rails detection.** `RunContext` records the runtime Ruby version
   (`RUBY_VERSION`) plus target Ruby/Rails versions parsed read-only from
   `Gemfile.lock` when present (`RUBY VERSION` section and `rails (x.y.z)`
   spec). No process other than `git rev-parse HEAD` is executed for context.
3. **Phase 1 policy semantics.** `advisory`: findings are non-blocking;
   gate `PASS` without findings, `WARN` with findings. `strict`: every
   finding blocks; `PASS` without findings, `FAIL` with findings.
   `no_new_debt` is evaluated exactly as `strict` in Phase 1 because baseline
   comparison belongs to Phase 3; the decision reason states this explicitly.
4. **RuboCop severity mapping.** `info→info`, `refactor→low`,
   `convention→low`, `warning→medium`, `error→high`, `fatal→critical`.
   Any other severity value is malformed evidence. Category is the lowercase
   cop department (text before `/`); a cop without a department is malformed.
5. **RuboCop exit interpretation.** Exit `0` or `1` with parseable JSON is
   `succeeded` (RuboCop exits `1` when offenses exist). Exit `2` or other
   nonzero is `failed`. Version support range is `>= 1.72, < 2` per STACK.md.
6. **Draft fingerprint payload.** Phase 1 uses the documented draft payload
   `{"payload_schema":"https://railverdict.dev/fingerprint-payload/v0.1",
   "analyzer":...,"message":...,"path":...,"rule_id":...}` serialized with
   sorted keys, SHA-256 digested to `sha256:<hex>`. Line numbers, timestamps,
   ordering, and display formatting are excluded. Phase 3 owns the final
   payload, migration, and collision vectors.
7. **Finding identity.** Deterministic finding id
   `rv:<first 20 hex chars of the fingerprint digest>`; identical fingerprints
   deduplicate since they are the same semantic evidence.
8. **Minimal child environment.** Analyzer children receive only an allowlist
   (`PATH`, `HOME`, `GEM_HOME`, `GEM_PATH`, `RUBYLIB`, `RUBYOPT`, `LANG`) plus
   forced `LC_ALL=C.UTF-8` and `TZ=UTC` for deterministic execution inputs.
   Every other parent variable is explicitly deleted before spawn. `BUNDLE_*`
   variables are deliberately excluded: a target project's `bundle exec` must
   derive from its own Gemfile, never from RailVerdict's bundler context. A
   child Ruby boot may still re-add bundler variables through an inherited
   `RUBYOPT`; that is a property of the child interpreter boot, not of the
   spawn environment.
9. **Deferred boundaries.** `baseline create` parses its draft options and
   exits `2` with an explicit Phase 3 deferral message. `check --changed` and
   `--base` parse and exit `2` with an explicit Phase 4 ownership message.
   Neither implements behavior.
10. **Doctor JSON.** Doctor is an observation report outside the result
    contract: `{"doctor":"1.0","ruby_version","target_ruby_version",
    "rails_version","configuration","analyzers"}` with deterministic key
    order; invalid configuration exits `2`.
11. **Findings JSON.** `findings` emits `{"schema_version":"1.0",
    "findings":[<finding-v1 documents>]}` after the same evidence collection;
    incomplete required evidence exits `2`.
12. **Phase 00 validator.** `script/validate-foundation no-production` was a
    Phase 0 boundary. It retires itself (prints a retirement note and passes)
    once `lib/rail_verdict.rb` exists; all other subchecks remain enforced.
    Phase 0 public documents keep their validator-enforced
    Draft/unimplemented labels; implementation status is recorded in this
    phase's artifacts instead.
13. **Interrupt handling.** `check` installs an INT trap that kills any
    registered child process group, waits for reaping, renders an
    `interrupted` result, and exits `130`.

## Forbidden in Phase 01

Baselines/fingerprints beyond the draft payload, no-new-debt evaluation,
`--changed` scope, GitHub/SARIF/annotations, AI placeholders or provider
abstractions, MCP, additional analyzers, network access at runtime, telemetry,
and any fixture derived from private projects.
