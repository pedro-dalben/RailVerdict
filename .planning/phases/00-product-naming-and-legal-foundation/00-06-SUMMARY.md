---
phase: 00-product-naming-and-legal-foundation
plan: "06"
subsystem: documentation
tags: [adr, deterministic-gate, analyzers, ai, github, mcp, licensing, provenance]

requires:
  - phase: 00-product-naming-and-legal-foundation
    provides: Product, architecture, analyzer, contract, security, and legal foundation documents
provides:
  - Exactly fifteen accepted foundation ADRs with explicit not-started implementation status
  - Deterministic gate, evidence, schema, fingerprint, baseline, and no-new-debt decisions
  - Downstream-only AI, GitHub, CLI/JSON, and MCP authority boundaries
  - Third-party licensing, information-firewall, Apache-2.0, and trademark decisions
affects: [trustworthy-core, evidence-ecosystem, baselines-policy, git-pull-requests, optional-ai, mcp, release-hardening]

tech-stack:
  added: []
  patterns: [accepted-decision-not-implementation, phase-owned-deferred-work, downstream-adapters-no-gate-authority]

key-files:
  created:
    - docs/adr/0001-deterministic-pass-fail.md
    - docs/adr/0002-external-analyzer-execution.md
    - docs/adr/0003-canonical-finding.md
    - docs/adr/0004-versioned-schemas.md
    - docs/adr/0005-fingerprint-baseline.md
    - docs/adr/0006-no-new-debt.md
    - docs/adr/0007-advisory-ai.md
    - docs/adr/0008-remote-ai-explicit-opt-in.md
    - docs/adr/0009-github-as-an-adapter.md
    - docs/adr/0010-cli-and-json-canonical.md
    - docs/adr/0011-mcp-as-an-adapter.md
    - docs/adr/0012-third-party-license-review.md
    - docs/adr/0013-information-firewall.md
    - docs/adr/0014-apache-2-license.md
    - docs/adr/0015-separate-trademark-policy.md
  modified: []

key-decisions:
  - "Deterministic policy alone owns PASS/FAIL; incomplete required evidence cannot pass."
  - "External analyzers remain target-project controlled, and Finding remains evidence without policy authority."
  - "Versioned schemas, fingerprints, explicit baselines, and no-new-debt policy are independent contracts with phase-owned implementation."
  - "AI, GitHub, CLI/JSON consumers, and MCP remain downstream and cannot acquire deterministic gate authority."
  - "Dated license review, the non-echoing information firewall, Apache-2.0 rights, and separate trademark policy preserve unresolved publication gates."

patterns-established:
  - "Every ADR uses one fixed metadata and section template and names the future owning phase."
  - "Accepted foundation choices retain Implementation status: Not started until their roadmap phase supplies proof."

requirements-completed:
  - FND-08

duration: 7 min
completed: 2026-08-16
status: complete
---

# Phase 0 Plan 6: Foundation ADRs Summary

**Fifteen independently reviewable ADRs ratify RailVerdict's deterministic, integration, privacy, licensing, and trademark boundaries without claiming implementation or publication clearance**

## Performance

- **Duration:** 7 min
- **Started:** 2026-08-16T07:07:55Z
- **Completed:** 2026-08-16T07:15:00Z
- **Tasks:** 3
- **Files modified:** 15

## Accomplishments

- Created exactly the approved ADR sequence 0001 through 0015 with no ADR index, complete metadata, consequences, related requirements/documents, and explicit future owners.
- Reserved deterministic gate authority for policy while keeping analyzer evidence, AI, GitHub, and MCP unable to weaken or recompute PASS/WARN/FAIL.
- Recorded versioned machine-contract, fingerprint, explicit-baseline, and no-new-debt adoption boundaries before runtime work begins.
- Preserved the Brakeman HOLD, dated third-party review, non-echoing information firewall, unmodified Apache-2.0 rights, separate trademark policy, and unresolved publication gate.

## Task Commits

Each task was committed atomically:

1. **Task 1: Record deterministic gate, analyzer, Finding, schema, and baseline decisions** - `aef8000` (docs)
2. **Task 2: Record no-new-debt, AI, remote opt-in, GitHub, and CLI/JSON decisions** - `529794a` (docs)
3. **Task 3: Record MCP, license review, firewall, Apache-2.0, and trademark decisions** - `0596b57` (docs)

## Files Created/Modified

- `docs/adr/0001-deterministic-pass-fail.md` through `docs/adr/0005-fingerprint-baseline.md` - Deterministic gate, external analyzer, Finding, schema, and baseline decisions.
- `docs/adr/0006-no-new-debt.md` through `docs/adr/0010-cli-and-json-canonical.md` - Adoption policy, AI, remote transmission, GitHub, and automation-interface decisions.
- `docs/adr/0011-mcp-as-an-adapter.md` through `docs/adr/0015-separate-trademark-policy.md` - MCP, third-party review, firewall, software-license, and trademark decisions.

## Requirements Completed

- **FND-08**: Initial ADRs record the fifteen product, architecture, licensing, AI, GitHub, MCP, and information-firewall decisions required by the foundation brief.

## Decisions Made

- Every decision is accepted as foundation direction while remaining explicitly unimplemented and assigned to its roadmap owner.
- Executable-plus-argv execution reduces injection risk but is not an OS sandbox; target projects continue to control external analyzers.
- Required incomplete evidence cannot pass, and no analyzer, AI provider, reporter, GitHub adapter, or MCP adapter can gain gate authority.
- Third-party and trademark facts remain dated, reviewable, and unresolved where evidence is absent; no legal owner, contact, reviewer, registration, or clearance outcome was invented.

## Validation Evidence

- The symmetric before/after no-production guards found no runtime, package, analyzer/Rails fixture, workflow/action, release/publication automation, AI, or MCP implementation path.
- Each five-file task passed its fixed-template parser, decision-specific assertions, ownership checks, acceptance criteria, and whitespace verification before the next batch began.
- The final exact-set parser confirmed the approved fifteen filenames, all required metadata and sections, FND-08 coverage, phase-owned deferred work, and no `README.md` or `index.md` under `docs/adr/`.
- Authority checks confirmed that AI, GitHub, and MCP cannot own, weaken, alter, or recompute the deterministic gate.
- Legal/security checks confirmed the Brakeman HOLD, unresolved owner/contact/reviewer facts, blocked publication, private patterns outside Git, and non-echoing firewall reports.
- `git diff --check HEAD~3..HEAD -- docs/adr`, the ASCII English scan, and the stub-pattern scan passed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reconciled stale persisted progress fields**

- **Found during:** Plan close-out state tracking
- **Issue:** `state.update-progress` correctly reported six of seven plans and `86%` but persisted frontmatter as `0%` and left the rendered progress bar at `71%`.
- **Fix:** Reconciled both persisted fields to the handler's reported six-of-seven result.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter and the rendered progress bar both read `86%`; plan position is 7 of 7.
- **Committed in:** Plan metadata commit

**Total deviations:** 1 auto-fixed (1 blocking tracking issue). **Impact on plan:** Tracking-only correction; no ADR content or public decision boundary changed.

## Issues Encountered

- Earlier research carried a superseded ADR grouping. The approved source brief and executable Plan 00-06 agreed on the exact current 0001-0015 topics, so those current authorities were followed without adding a parallel or index ADR set.

## Known Stubs

None - the ADRs intentionally record accepted decisions with `Implementation status: Not started` and concrete future owners; they do not substitute placeholders for the plan goal.

## Authentication Gates

None.

## User Setup Required

None - no package, analyzer, credential, remote service, workflow, AI provider, MCP server, or publication action was installed or configured.

## Next Phase Readiness

- Plan 00-07 can validate the integrated public links, ADR set, roadmap, language, provenance, and no-production contract.
- Publication remains blocked on launch-jurisdiction evidence and qualified trademark review, and Brakeman remains unsupported pending its written legal/product decision.

## Self-Check: PASSED

- All fifteen ADR files and this summary exist.
- Task commits `aef8000`, `529794a`, and `0596b57` exist in repository history.
- All task acceptance criteria, exact verifiers, scope guards, whitespace checks, authority checks, stub scan, and English-only scan passed.
- Summary status is `complete`, and `requirements-completed` contains FND-08 verbatim from the plan frontmatter.

---
*Phase: 00-product-naming-and-legal-foundation*
*Completed: 2026-08-16*
