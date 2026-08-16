---
phase: 00-product-naming-and-legal-foundation
plan: "02"
subsystem: documentation
tags: [product, philosophy, architecture, competitive-landscape]

requires: []
provides:
  - Public evidence-before-merge entry point and complete foundation navigation
  - Product definition with dated competitive evidence and labeled project inference
  - Deterministic, local-first operating invariants with practical boundaries
  - Four-layer authority contract and proposed-not-present one-gem structure
affects: [foundation-docs, trustworthy-core, optional-ai, platform-adapters]

tech-stack:
  added: []
  patterns: [one-public-owner-per-concern, policy-only-gate-authority, proposed-not-present-runtime-tree]

key-files:
  created:
    - README.md
    - PROJECT.md
    - PHILOSOPHY.md
    - ARCHITECTURE.md
  modified: []

key-decisions:
  - "Keep the README as a concise public index that states the publication blocker and makes no runtime implementation claims."
  - "Describe competitor capabilities as dated sourced observations and RailVerdict differentiation as project inference rather than superiority."
  - "Reserve gate authority for deterministic policy while evidence, intelligence, reporters, and platforms retain one-way responsibilities."
  - "Document the Phase 1 one-gem/one-process tree as proposed and absent, adding paths only when behavior owns them."

patterns-established:
  - "Public product, philosophy, architecture, and foundation records own distinct concerns and cross-link instead of duplicating mutable facts."
  - "Runtime data flows into and out of core contracts while concrete source dependencies point toward those contracts."

requirements-completed:
  - FND-07
  - FND-13

duration: 5 min
completed: 2026-08-16
status: complete
---

# Phase 0 Plan 2: Product and Architecture Foundation Summary

**Evidence-before-merge product definition with deterministic local-first invariants, dated competitive boundaries, and a proposed-not-present one-gem architecture**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-16T06:21:13Z
- **Completed:** 2026-08-16T06:26:42Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added a concise public index that links every planned foundation artifact while preserving the unresolved publication gate and explicit implementation non-claims.
- Separated the authoritative product definition from practical operating invariants and documented all requested competitors with dated primary-source links.
- Established four one-way layers, policy-only gate authority, downstream advisory intelligence/platforms, and a minimal Phase 1 tree that remains absent in Phase 0.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the product definition, competitive landscape, and philosophy** - `ab36e7a` (docs)
2. **Task 2: Document the four-layer dependency rule and proposed one-gem structure** - `365e234` (docs)

## Files Created/Modified

- `README.md` - Public status, non-claims, legal links, and complete foundation navigation.
- `PROJECT.md` - Product definition, users, scope, non-goals, and dated competitive positioning.
- `PHILOSOPHY.md` - Evidence-first, deterministic, no-new-debt, Rails-first, local-first, open-source, advisory-AI, agent-native, and privacy invariants.
- `ARCHITECTURE.md` - Layer ownership, dependency direction, future responsibility map, process boundary, and proposed Phase 1 tree.

## Decisions Made

- The public index repeats only stable status and navigation; detailed identity, analyzer, contract, and security facts remain in their owning documents.
- Competitive capabilities are dated observations from primary sources. RailVerdict's offline Rails-focused normalization, incompleteness, no-new-debt, and agent-contract position is labeled as project inference.
- Evidence owns facts, deterministic policy alone creates `GateResult`, and optional intelligence plus platform consumers cannot weaken or duplicate the gate.
- Executable-plus-argv isolation is a required risk reduction but is not an operating-system sandbox.

## Validation Evidence

- Symmetric before/after scope guards found no runtime, packaging, fixture, workflow, release, AI, or MCP implementation paths.
- README checks confirmed evidence-before-merge positioning, the publication blocker, all required foundation/schema/example/ADR links, and the absence of SaaS, gem, CLI, analyzer, adapter, AI, or runtime claims.
- Product checks confirmed dated primary-source competitive links, explicit project-inference labeling, and coverage of Qlty/Code Climate, SonarQube, Codacy, Semgrep, GitHub code scanning, MegaLinter, reviewdog, Pronto, Danger, and Rails specialists.
- Philosophy checks confirmed every required invariant and exact ADR/document ownership link.
- Architecture checks confirmed four layers, source dependency direction, policy-only `GateResult` authority, the proposed-not-present one-gem/one-process tree, explicit exclusions, and the OS-sandbox disclaimer.
- `git diff --check -- README.md PROJECT.md PHILOSOPHY.md ARCHITECTURE.md` passed.
- Stub scan found no TODO, FIXME, placeholder, coming-soon, or unavailable markers.
- Threat-surface scan found no new endpoint, authentication path, file-access behavior, schema boundary, dependency, or runtime implementation.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Initial content verification required the exact hyphenated tokens `local-first` and `one-process`; both wording fixes were applied and the full criteria reran successfully before their task commits.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The product, philosophy, and architecture boundaries are ready for the remaining Phase 0 analyzer, contract, security, ADR, and roadmap artifacts.
- Cross-links intentionally target parallel Wave 1 outputs; Plan 00-07 owns repository-wide target validation after the wave converges.
- Publication remains blocked exactly as recorded in `docs/foundation.md`.

## Self-Check: PASSED

- `README.md`, `PROJECT.md`, `PHILOSOPHY.md`, `ARCHITECTURE.md`, and this summary exist.
- Task commits `ab36e7a` and `365e234` exist in repository history.
- Summary status is `complete`, and the verbatim requirement list contains only FND-07 and FND-13.

---
*Phase: 00-product-naming-and-legal-foundation*
*Completed: 2026-08-16*
