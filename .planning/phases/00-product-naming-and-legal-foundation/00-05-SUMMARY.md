---
phase: 00-product-naming-and-legal-foundation
plan: "05"
subsystem: security
tags: [threat-model, stride, asvs-5.0.0, provenance, information-firewall]

requires: []
provides:
  - Severity-aware STRIDE threat register with phase-owned blocking controls and residual limits
  - OWASP ASVS 5.0.0 Level 1 control-catalog mappings without certification claims
  - Synthetic-only, English-only, non-echoing information firewall and publication evidence procedure
affects: [trustworthy-core, evidence-ecosystem, baselines-policy, git-forks, optional-ai, release-hardening]

tech-stack:
  added: []
  patterns: [high-risk-blocking, evidence-owned-security-controls, non-echoing-provenance-review]

key-files:
  created:
    - SECURITY.md
  modified: []

key-decisions:
  - "Block every unresolved HIGH threat at its owning phase or release gate until the required control is evidenced; HIGH risks cannot be accepted."
  - "Treat executable-plus-argv and process lifecycle controls as risk reduction, never as an operating-system sandbox."
  - "Use only applicable ASVS 5.0.0 Level 1 requirements as a control catalog and do not mislabel relevant Level 2 categories as Level 1 evidence."
  - "Keep private detection input outside Git, report only safe metadata, and distinguish passed, failed, not run, and not applicable surfaces."

patterns-established:
  - "Threat -> severity/disposition -> required control -> residual limitation -> verification evidence -> owning phase."
  - "Publication requires zero unresolved provenance matches and complete required surface evidence; absence never becomes a pass."

requirements-completed:
  - FND-11
  - FND-12

duration: 11 min
completed: 2026-08-16
status: complete
---

# Phase 0 Plan 5: Security Model and Information Firewall Summary

**Fail-closed STRIDE controls with ASVS 5.0.0 Level 1 mappings and a synthetic, English-only, non-echoing publication firewall**

## Performance

- **Duration:** 11 min
- **Started:** 2026-08-16T06:53:27Z
- **Completed:** 2026-08-16T07:04:19Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Defined protected assets, adversaries, six operational trust boundaries plus legal assurance, sixteen STRIDE threats, severity/disposition rules, residual limits, proof requirements, and explicit Phase 1–9 owners.
- Made every HIGH threat block its owning gate until evidenced and documented that argv/process isolation is not an operating-system sandbox.
- Added a version-qualified ASVS 5.0.0 Level 1 mapping that uses ASVS as a control catalog without certification or web-application claims.
- Established synthetic-only and English-only public content, exhaustive current/future scan surfaces, external private-pattern input, non-echoing reports, truthful evidence states, and zero-unresolved-match publication behavior.

## Task Commits

Each task was committed atomically:

1. **Task 1: Document assets, trust boundaries, threats, and ASVS L1 controls** - `2692a2c` (docs)
2. **Task 2: Add the synthetic, English-only, non-echoing information firewall** - `03bc78e` (docs)

## Files Created/Modified

- `SECURITY.md` - Canonical threat model, control/evidence register, ASVS mapping, information-firewall policy, scan-state contract, and maintainer publication procedure.

## Requirements Completed

- **FND-11**: The threat model identifies assets, trust boundaries, adversaries, false-PASS risks, subprocess risks, AI risks, fork risks, supply-chain risks, and required controls.
- **FND-12**: A public information-firewall policy requires synthetic fixtures, English-only repository prose, and a provenance scan across tree, history, package, archives, media, and release artifacts.

## Decisions Made

- Gate status and evidence completeness remain separate. Unavailable, unsupported, stale, malformed, partial, truncated, or otherwise incomplete required evidence cannot yield a trustworthy PASS.
- The process boundary requires fixed executable-plus-argv invocation, bounded concurrent output, monotonic timeout, process-tree termination/reaping, minimal environment, and cleanup, while retaining the explicit non-sandbox limitation.
- ASVS controls are individually mapped only when they are Level 1 in the official v5.0.0 source. V13, V14, and V16 remain useful broader categories, but their most relevant data-classification and log-injection controls are Level 2 and are not presented as Level 1 proof.
- Phase 0 may complete the firewall policy while the absent external private corpus remains `not run`. Generated gem, archive, release, CI, and installed-artifact surfaces remain `not applicable` until they exist; Phase 9 owns their enforcement.

## Validation Evidence

- Both exact plan verifiers passed for required threat/security terms, HIGH blocking behavior, the sandbox disclaimer, information-firewall terms, all named scan surfaces, non-echoing behavior, and the secret-scan limitation.
- A structural audit confirmed sixteen threat rows, a severity and mitigate/accept/transfer disposition on every row, no accepted HIGH threat, a named phase owner, residual limitation, and verification evidence.
- Official OWASP ASVS v5.0.0 source confirmed the mapped Level 1 identifiers: `1.2.5`, `2.1.1`, `2.2.1`, `2.2.2`, `5.2.1`, `5.2.2`, `5.3.2`, `8.1.1`, `8.2.1`, `8.2.2`, `8.3.1`, `15.1.1`, `15.2.1`, and `15.3.1`.
- Firewall checks confirmed every required prohibited category, English-only scope, individual manifest exception rule, all-refs history scope, gem/archive/media/docs/release/CI/install surfaces, external input, safe report fields, four evidence states, credential rotation-first response, and publication blocking.
- Symmetric before/after scope guards found no runtime, package, analyzer/Rails fixture, workflow/action, release/publication automation, AI, or MCP implementation paths.
- `git diff --check 2692a2c^..03bc78e -- SECURITY.md` passed.
- Stub scan found no TODO, FIXME, coming-soon, placeholder, unavailable-data, empty-rendering, or unwired-data patterns.
- Threat-surface review found only the planned documentary threat model and future control obligations; no endpoint, authentication path, executable file access, schema, dependency, workflow, or runtime behavior was introduced.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reconciled stale persisted progress fields**

- **Found during:** Plan close-out state tracking
- **Issue:** `state.update-progress` calculated five of seven plans and reported `71%`, but persisted frontmatter as `0%` and left the rendered bar at `57%`.
- **Fix:** Reconciled both persisted fields to the handler's reported five-of-seven result.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter and the rendered progress bar both read `71%`; plan position is 6 of 7.
- **Committed in:** Plan metadata commit

**Total deviations:** 1 auto-fixed (1 blocking tracking issue). **Impact on plan:** Tracking-only correction; the public security contract did not change.

## Issues Encountered

- The direct verifier required contiguous literal tokens for `false PASS`, `subprocess`, `supply-chain`, and the HIGH blocking rule. Wording was tightened before the Task 1 commit, then the complete acceptance loop passed.
- The installed state handlers require named flags although the executor prompt showed positional examples. The rejected calls made no metric or decision change; rerunning with the installed handler signatures recorded the metric, decisions, and session successfully.

## Known Stubs

None - the document records future control owners and honest `not run`/`not applicable` states, not implementation placeholders.

## Authentication Gates

None.

## User Setup Required

None - no package, scanner, credential, private corpus, workflow, or external service was configured. The maintainer-controlled private corpus remains intentionally outside Git and is required before a complete provenance pass can be claimed.

## Next Phase Readiness

- Plan 00-06 can record the corresponding subprocess, AI, GitHub, and information-firewall decisions without inventing runtime evidence.
- Plan 00-07 can validate integrated security, language, provenance, links, and no-production behavior while preserving `not run` and `not applicable` distinctions.
- Publication remains blocked by the separate qualified identity/legal gate and by missing complete private-corpus and future release-surface evidence.

## Self-Check: PASSED

- `SECURITY.md` and this summary exist.
- Task commits `2692a2c` and `03bc78e` exist in repository history.
- Both task verifiers, all acceptance criteria, the symmetric scope guards, whitespace check, stub scan, and threat-surface review passed.
- Summary status is `complete`, and FND-11/FND-12 appear verbatim in both frontmatter and requirement evidence.

---
*Phase: 00-product-naming-and-legal-foundation*
*Completed: 2026-08-16*
