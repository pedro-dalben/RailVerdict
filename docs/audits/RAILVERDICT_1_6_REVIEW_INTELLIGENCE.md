# RAILVERDICT 1.6 — IntegrarPlus Review Intelligence Audit

Candidate: `rail_verdict 1.6.0` (source tree, before gem packaging; gem
`rail_verdict-1.6.0.gem` built from the same tree and installed for lab runs).
Consumer: IntegrarPlus at `73371729` (plus 5 historical scenario commits).
Runs below use an advisory no-analyzer config for speed, so gates here reflect
surface/scope behavior, not consumer policy. One native-config full run was
attempted; RSpec at consumer scale exceeds the dogfood timebox (see §8).

## Cases

### 1. Model + migration (`78deec73`, beneficiary relationships)
- Risk HIGH — reasons `database_surface_changed`, `migration_added`.
- Focus: 1 migration, 2 database, 3 models. Correct order.
- Scope recomputed FULL (analyzers disabled, `executed: false`).
- Useful: YES. Migration-first focus matches reviewer priority.

### 2. Authentication hardening (`8abbaca5`, sessions/rate-limit/controllers)
- Risk HIGH — `authentication_surface_changed` first, plus configuration,
  database, public_api, routes, shared_infrastructure.
- Focus rank 1: authentication (5 files). No `authorization_surface_changed`
  (no Pundit files touched) — correct authorization/authentication split.
- Useful: YES. `public_api_changed` (inferred, `app/controllers/api/**`) is
  honest heuristic with evidence.

### 3. Changelog feature + migration + policy (`65ef6f6a`)
- Risk HIGH — incl. `authorization_surface_changed` from the newly added
  `app/policies/changelog_entry_policy.rb`. TRUE POSITIVE (verified in diff).
- Missing evidence correctly adds
  `authorization_changed_verification_not_established`.
- Useful: YES.

### 4. Dependency remediation (`5d8f4dc4`)
- Risk MEDIUM — `dependency_changed` only. Focus: dependencies (2 files).
- Useful: YES. Minimal, precise.

### 5. Shared CSRF/export hardening (`1f4c8132`, application_controller + 1 line)
- Risk MEDIUM — `shared_infrastructure_changed`, `configuration_changed`,
  `database_surface_changed`. No inflated HIGH.
- Useful: YES. Shared-infra flag on a 1-line base-class change is the point.

### 6. Multi-surface HEAD (`73371729`)
- Risk MEDIUM — configuration + database. Focus database/controllers/models.
- Useful: PARTIALLY. Correct but unsurprising; large diffs dilute focus by
  design (evidence-bounded lists, capped counts).

## False positives: none observed
Every sensitive signal traced to a real file in the commit diff. `database`
fires on any `app/models/**` change and `configuration` on any `config/**`
change — broad by design, documented as detected path association, not
semantic blast radius.

## Important misses: none observed
Policy renames, session controllers, API controllers, migrations, Gemfile,
initializers, and shared base classes were all detected on real history.

## Full-verification run
A native-config `pr` (rubocop+rspec+simplecov+bundler_audit, advisory) was
started on the auth scenario; fixture-scale RSpec (~3,900 specs) exceeds a
reasonable dogfood timebox, so executed-scope evidence for the consumer suite
is NOT established here. The scope machinery itself is proven by unit tests
(executed `test_scope`/`target_files` passthrough) and lab CI-02/CI-05
fallback assertions.

## Real-consumer static run (HEAD `73371729`, static analyzers executed)
- Gate PASS, completion complete; rubocop + bundler_audit `succeeded`.
- Quality delta from the real committed baseline: introduced 0, resolved 7.
- Risk MEDIUM (`configuration_changed`, `database_surface_changed`); focus
  database → configuration → controllers (redundant models/initializers
  entries suppressed by evidence-coverage dedup).
- Verification scope honestly FULL-recomputed with `executed: false` and the
  exact fallback reason (initializer change); missing evidence lists only
  coverage (correct — simplecov disabled in this run).

## Verdict: USEFUL
Change Intelligence put the right surface first in 6/6 cases with zero false
sensitive signals. Reviewer search space reduced to a ranked, evidence-backed
list in every case.
