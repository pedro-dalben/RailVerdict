---
phase: 00-product-naming-and-legal-foundation
plan: "01"
subsystem: documentation
tags: [identity, licensing, trademark, apache-2.0]

requires: []
provides:
  - Dated RailVerdict name-evidence matrix and canonical identity mapping
  - Explicit unresolved publication-gate record
  - Canonical Apache-2.0 license, factual NOTICE, and separate trademark policy
affects: [foundation-docs, contracts, release-hardening, publication]

tech-stack:
  added: []
  patterns: [dated-evidence-with-limitations, legal-document-separation]

key-files:
  created:
    - docs/foundation.md
    - LICENSE
    - NOTICE
    - TRADEMARKS.md
  modified: []

key-decisions:
  - "Use RailVerdict, rail_verdict, RailVerdict, railverdict, .railverdict.yml, railverdict, and the draft railverdict.dev schema root as one internal identity mapping."
  - "Treat technical identifier observations as dated evidence only; publication remains blocked on launch-jurisdiction searches and qualified trademark review."
  - "Keep Apache-2.0 software rights, factual NOTICE content, and source-confusion trademark rules separate."

patterns-established:
  - "External name observations record exact date, query, source, result, classification, and limitation."
  - "Unknown owner, contact, registration, reviewer, and legal conclusions remain explicit unresolved fields."

requirements-completed:
  - FND-01
  - FND-02
  - FND-03
  - FND-04

duration: 5 min
completed: 2026-08-16
status: complete
---

# Phase 0 Plan 1: Identity and Legal Foundation Summary

**Dated RailVerdict identity evidence with an explicit publication blocker, canonical Apache-2.0 text, and a separate non-restrictive trademark policy**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-16T06:10:21Z
- **Completed:** 2026-08-16T06:15:57Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Recorded fourteen required technical, web, and trademark surfaces without turning absent or unavailable results into availability or clearance claims.
- Established one seven-surface RailVerdict identity mapping while keeping package, repository, domain, branding, and release publication blocked.
- Added the byte-for-byte canonical Apache License 2.0 text, a factual NOTICE, and trademark rules limited to source confusion and false endorsement.

## Task Commits

Each task was committed atomically:

1. **Task 1: Publish the dated name, identity, and publication-gate record** - `d141142`
2. **Task 2: Establish Apache-2.0, NOTICE, and trademark separation** - `8ee5389`

## Files Created/Modified

- `docs/foundation.md` - Dated evidence matrix, identity decision, rejected-name history, and unresolved publication gate.
- `LICENSE` - Unmodified canonical Apache License 2.0 text.
- `NOTICE` - Current factual notice boundary without invented attribution.
- `TRADEMARKS.md` - Nominative-use and source-confusion policy that preserves Apache-2.0 software rights.

## Decisions Made

- Technical-name responses are dated observations, not reservations or legal conclusions.
- Phase 0 documentation can complete while publication remains blocked; any later clearance record must name scope, evidence, reviewer, date, and conclusion.
- Trademark presentation rules cannot condition or narrow personal, commercial, proprietary, open-source, modification, fork, redistribution, consulting, integration, or resale rights granted by Apache-2.0.

## Validation Evidence

- Before and after scope guards passed with no production, packaging, workflow, release, AI, or MCP surfaces.
- The exact task parser confirmed fourteen required matrix rows, seven non-empty cells per row, dated durable sources, and unresolved legal results.
- The identity check confirmed exactly seven canonical surfaces and confined the rejected working name to its historical section.
- `LICENSE` matched SHA-256 `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`.
- NOTICE/trademark assertions confirmed no invented attribution, preserved software rights, permitted accurate nominative references, and kept ownership/contact/review unresolved.
- Cross-document links and `git diff --check -- docs/foundation.md LICENSE NOTICE TRADEMARKS.md` passed.
- Stub scan found no TODO, FIXME, placeholder, empty-value, or unwired-data patterns.
- Threat-surface scan found only the planned external legal-evidence links; no endpoint, authentication, file-access, or schema trust boundary was introduced.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first self-check loop reused zsh's special `path` parameter and temporarily hid command lookup inside that shell; rerunning with a neutral variable name passed without changing repository files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The internal identity and legal-document boundary are ready for the remaining Phase 0 public contracts.
- Publication remains blocked on Brazil and all intended launch-jurisdiction evidence, similarity and related-goods/common-law analysis, ownership/contact facts, and a qualified reviewer conclusion.

## Self-Check: PASSED

- All four public artifacts and this summary exist.
- Task commits `d141142` and `8ee5389` exist in repository history.
- Summary status and the verbatim FND-01 through FND-04 requirement list are present.

---
*Phase: 00-product-naming-and-legal-foundation*
*Completed: 2026-08-16*
