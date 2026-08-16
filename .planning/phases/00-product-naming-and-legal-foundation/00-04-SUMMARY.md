---
phase: 00-product-naming-and-legal-foundation
plan: "04"
subsystem: contracts
tags: [json-schema, yaml, cli, deterministic-output, offline-validation]

requires: []
provides:
  - Strict offline Draft 2020-12 Finding and parsed-configuration contracts
  - Synthetic JSON and safely parsed YAML examples with mutation evidence
  - Exact draft CLI command, option, ordering, stream, and exit contract
affects: [trustworthy-core, evidence-ecosystem, git-scope, agent-consumers]

tech-stack:
  added: []
  patterns: [independent-contract-versioning, recursively-closed-schemas, policy-owned-gate-authority]

key-files:
  created:
    - docs/contracts.md
    - schemas/finding-v1.schema.json
    - schemas/configuration-v1.schema.json
    - examples/finding-v1.json
    - examples/configuration-v1.yml
  modified: []

key-decisions:
  - "Close every schema object and keep all references as local fragments so validation remains strict and offline."
  - "Keep Finding as analyzer-independent evidence; blocking and PASS/WARN/FAIL authority belong only to future deterministic policy output."
  - "Limit the draft CLI to five exact command surfaces with one JSON stdout document, diagnostic-only stderr, deterministic ordering, and exits 0/1/2/130."

patterns-established:
  - "Configuration examples are safe-loaded as data and validate through an unpredictable Tempfile path passed as an argv element."
  - "Every pre-implementation command, option, stream, ordering, exit, support, and compatibility statement is labeled Draft / unimplemented."

requirements-completed:
  - FND-09
  - FND-10

duration: 7 min
completed: 2026-08-16
status: complete
---

# Phase 0 Plan 4: Draft Schemas and CLI Contract Summary

**Strict offline Finding/configuration schemas with synthetic JSON/YAML examples and an exact unimplemented CLI, stream, ordering, and exit contract**

## Performance

- **Duration:** 7 min
- **Started:** 2026-08-16T06:42:31Z
- **Completed:** 2026-08-16T06:49:28Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added independently versioned Draft 2020-12 schemas whose root and nested objects reject unknown data and whose references never leave the document.
- Proved a synthetic Finding and safely parsed `.railverdict.yml` value valid while rejecting gate-authority, unknown-field, absolute-path, traversal, backslash, and empty-segment mutations.
- Defined the exact five-command draft CLI surface, Phase 4 ownership of production changed scope, deterministic ordering, JSON stdout isolation, diagnostic stderr, and proposed exits `0`, `1`, `2`, and `130`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Define strict offline schemas and validate synthetic JSON/YAML examples** - `657de3c` (feat)
2. **Task 2: Document schema semantics and the draft CLI contract** - `ae7a056` (docs)

## Files Created/Modified

- `schemas/finding-v1.schema.json` - Strict draft analyzer-independent Finding evidence contract with a repository-relative location definition.
- `schemas/configuration-v1.schema.json` - Strict draft parsed-configuration contract with one explicit RuboCop selection map.
- `examples/finding-v1.json` - Synthetic valid Finding instance without policy or gate authority.
- `examples/configuration-v1.yml` - Synthetic data-only configuration validated after safe YAML parsing.
- `docs/contracts.md` - Draft schema semantics plus exact CLI, ordering, stream, read/write, reporter, and exit boundaries.

## Requirements Completed

- **FND-09**: Finding and configuration contracts have versioned JSON Schema drafts, valid examples, and explicit unknown-field behavior.
- **FND-10**: The CLI contract documents commands, options, stdout/stderr separation, deterministic output, and stable proposed exit semantics before implementation.

## Decisions Made

- Used `additionalProperties: false` and `unevaluatedProperties: false` at every object boundary; local `$defs` keep reuse offline without weakening closure.
- Kept configuration intentionally small: integer `version`, policy `mode`, and one explicit strict analyzer selection. Runtime defaults, precedence, secrets, and internal tuning remain deferred.
- Kept Finding free of `blocking`, policy action, and gate status so analyzer evidence cannot acquire deterministic policy authority.
- Specified stable finding ordering using normalized path, location, analyzer, rule, fingerprint, and ID, with reporters remaining pure projections.

## Validation Evidence

- Both exact task verifiers passed, including `Draft202012Validator.check_schema`, valid JSON/YAML examples, internal-reference inspection, required mutations, and whitespace checks.
- YAML was parsed with `YAML.safe_load` using no permitted classes, symbols, or aliases; its JSON value was flushed to a block-scoped `Tempfile` and passed to Python as an argv element.
- A recursive schema audit confirmed every object is closed, exact `$id` and independent version fields are present, and every `$ref` begins with `#/`.
- Validation still passed after socket connection attempts were replaced with a failure, proving the examples require no network resolution.
- Finding mutations for `blocking`, `gate`, `policy_decision`, and `status`, plus nested unknown and invalid repository-path variants, were rejected.
- The CLI audit confirmed exactly five command rows, their required option sets, global `--help`/`--version`, Phase 4 changed-scope ownership, deterministic ordering, stream separation, reporter purity, exit meanings, links, and draft labels.
- Symmetric pre/post/final scope guards found no runtime, package, fixture, workflow, release/publication, AI, or MCP implementation surface.
- Stub scan found no TODO, FIXME, placeholder, coming-soon, unavailable-data, empty-rendering, or unwired-data patterns.
- Threat-surface review found only the three schema boundaries already registered in the plan: structured input, local references, and analyzer evidence versus policy authority.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reconciled stale persisted progress fields**

- **Found during:** Plan close-out state tracking
- **Issue:** `state.update-progress` calculated and reported `57%` for four of seven plans but left the frontmatter percentage and rendered progress bar at earlier values.
- **Fix:** Reconciled both persisted fields to the handler's reported four-of-seven result.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter and rendered progress both read `57%`; plan position is 5 of 7.
- **Committed in:** Plan metadata commit

**Total deviations:** 1 auto-fixed (1 blocking issue). **Impact on plan:** Tracking-only correction; no public contract scope changed.

## Issues Encountered

- The first CLI table verification required the word `Exit` in each exit row for the plan's direct assertion; the labels were corrected before the task commit and the full verifier reran successfully.

## User Setup Required

None - no runtime dependency, analyzer, credential, network service, or product scaffold was added.

## Next Phase Readiness

- Phase 1 can implement against explicit draft Finding, configuration, CLI, stream, ordering, and exit constraints without inventing public interfaces in code.
- Phase 4 retains production ownership of `--changed` and `--base`; the document makes no current support or compatibility claim.
- Plan 00-07 still owns integrated link/schema/foundation validation after all Wave 1 artifacts exist.

## Self-Check: PASSED

- All five public artifacts and this summary exist.
- Task commits `657de3c` and `ae7a056` exist in repository history.
- Summary status is `complete`, and FND-09/FND-10 appear verbatim in the requirements-completed list and requirement evidence.

---
*Phase: 00-product-naming-and-legal-foundation*
*Completed: 2026-08-16*
