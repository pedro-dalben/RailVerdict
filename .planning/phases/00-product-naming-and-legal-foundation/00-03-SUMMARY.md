---
phase: 00-product-naming-and-legal-foundation
plan: "03"
subsystem: documentation
tags: [analyzers, licensing, ruby, rails, compatibility-proposals]

requires: []
provides:
  - Dated eleven-analyzer license, output, cost, failure, and disposition registry
  - Proposed five-lane Ruby and Rails compatibility matrix with future proof gates
  - Roadmap-owned technical shortlist, deferrals, and Brakeman legal/product HOLD
affects: [trustworthy-core, evidence-ecosystem, git-scope, rails-context, release-hardening]

tech-stack:
  added: []
  patterns: [dated-external-evidence, proposal-until-fixture-proof, roadmap-owned-dispositions]

key-files:
  created:
    - docs/analyzers.md
  modified: []

key-decisions:
  - "Keep every analyzer external and target-project controlled; the registry authorizes neither installation nor support."
  - "Treat Ruby >= 3.3, Rails >= 8.0, and the five synthetic lanes as proposals until named lane and lower/current adapter fixtures pass."
  - "Keep Brakeman on HOLD and outside the technical shortlist until written legal/product review resolves its current license and product-use boundary."

patterns-established:
  - "Analyzer facts carry an evidence date, official source, limitation, disposition owner, blocker, and refresh event."
  - "Platform ranges and adapter ranges remain proposals until the exact synthetic lanes and fixtures establish compatibility."

requirements-completed:
  - FND-05
  - FND-06

duration: 7 min
completed: 2026-08-16
status: complete
---

# Phase 0 Plan 3: Analyzer Registry and Support Proposal Summary

**Eleven dated external-analyzer records, a fixture-gated Ruby/Rails lane proposal, and an explicit Brakeman legal/product HOLD**

## Performance

- **Duration:** 7 min
- **Started:** 2026-08-16T06:31:24Z
- **Completed:** 2026-08-16T06:39:19Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Recorded exactly one complete row for each of the eleven researched analyzers, separating homepage, observed version, license, screening note, install boundary, native output, cost, failure semantics, disposition, owner, review date, and official evidence.
- Established a proposed Ruby `>= 3.3` and Rails-context `>= 8.0` policy with three core Ruby lanes and two deliberate synthetic Rails boundary lanes, without claiming current support.
- Ordered the proposed adapter shortlist as RuboCop with rubocop-rails capability metadata, Minitest/RSpec, SimpleCov, and bundler-audit while preserving all deferrals and the Brakeman HOLD.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build the dated eleven-analyzer license and contract registry** - `2b92c32` (docs)
2. **Task 2: Define proposed Ruby, Rails, and adapter support lanes** - `6db9eef` (docs)

## Files Created/Modified

- `docs/analyzers.md` - Dated analyzer registry, evidence notes, technical shortlist, Ruby/Rails proposal, synthetic lanes, and roadmap ownership.

## Decisions Made

- An analyzer remains external even when shortlisted; target projects control installation and versions, and RailVerdict documentation cannot silently authorize either.
- RuboCop is the proposed Phase 1 vertical adapter, with rubocop-rails modeled as capability metadata in the same process; the remaining shortlisted evidence belongs to Phase 2.
- Ruby and Rails maintenance state is a dated upstream fact, while floors, lane selection, EOL-drop policy, and adapter ranges are RailVerdict proposals requiring exact future proof.
- Brakeman 8.0.6 remains recorded under the current Brakeman Public Use License with disposition `HOLD`; technical value does not override the written legal/product decision gate.

## Validation Evidence

- Symmetric before/after scope guards passed with no runtime, packaging, analyzer/Rails fixture, GitHub workflow/action, release/publication, AI, or MCP implementation surfaces.
- The exact registry parser confirmed the fifteen required columns, the approved eleven-row order, non-empty fields, durable homepage/source URLs, `External` in every bundled-status cell, rubocop-rails 2.37.0, and Brakeman's current license plus exact `HOLD` disposition.
- The exact shortlist parser confirmed RuboCop/rubocop-rails, Minitest/RSpec Core, SimpleCov, and bundler-audit in the required order and confirmed that Brakeman is absent from that section.
- The support parser confirmed Ruby 3.3, 3.4, and 4.0; Rails 8.0 and 8.1; proposed floors `>= 3.3` and `>= 8.0`; exactly five named synthetic lanes; fixture-before-support qualification; and no Rails runtime dependency.
- Disposition checks confirmed roadmap ownership for every analyzer and the documented reasons for Undercover, RubyCritic, Prosopite, and strong_migrations deferrals plus the Brakeman HOLD.
- `git diff --check 2b92c32^..6db9eef -- docs/analyzers.md` passed.
- Stub scan found no TODO, FIXME, coming-soon, placeholder, unavailable-data, empty-rendering, or unwired-data patterns.
- Threat-surface scan found only the planned documentary third-party metadata and external-process links; no endpoint, authentication path, file-access behavior, schema trust boundary, dependency, or runtime implementation was introduced.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no packages, analyzers, credentials, or external services were installed or configured.

## Next Phase Readiness

- Phase 1 and Phase 2 can use the dated registry and explicit proof gates when their implementation plans begin.
- Plan 00-07 still owns integrated analyzer/link validation after the remaining Wave 1 artifacts exist.
- Brakeman remains externally blocked; no adapter, install instruction, support statement, or advertising claim is authorized without the written legal/product decision.

## Self-Check: PASSED

- `docs/analyzers.md` and this summary exist.
- Task commits `2b92c32` and `6db9eef` exist in repository history.
- Both plan verifiers, every acceptance criterion, the pre/post no-production guards, whitespace checks, stub scan, and threat-surface review passed.
- Summary status is `complete`, and the requirements-completed list contains FND-05 and FND-06 verbatim from the plan frontmatter.

---
*Phase: 00-product-naming-and-legal-foundation*
*Completed: 2026-08-16*
