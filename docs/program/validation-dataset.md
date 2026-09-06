# G3 Validation Dataset (running record, synthetic-safe)

Camera: external projects only. No private source. SHAs pinned per trial.
Candidate: released rail_verdict-1.8.0.gem (SHA de538bc1, GitHub Release).

## P-A propshaft (rails/propshaft @ dc979db) — engine, minitest

- Size: small engine (~50 lib files). Ruby 3.4.5 (env) vs gemfile range (compatible).
- Onboarding: clone ~2s, `bundle install` ~7s exit 0, config write trivial.
  First verdict attempt < 2 min wall. No gem patch.
- Trial 1 (minitest required, default 30s timeout): INCOMPLETE (analyzer
  timed_out). Trial 2 (timeout_seconds 300): minitest succeeded, gate PASS,
  2.27s verification. Lesson: default 30s timeout too short for real suites;
  the knob exists and works.
- Trial 3 (strict + baseline flow): baseline create refused on incomplete run
  (honest), succeeded on complete run (0 entries, clean tree).
- Trial 4 (synthetic low-severity lint offense, strict + findings forbid):
  gate FAIL, decision FAIL via `gate_failed` (strict fails on any introduced
  finding; schema forbids only critical/high, and the offense was low).
  Coherent: the policy section adds severity gates, the mode adds the floor.
- Trial 5 (review packet): risk LOW, **focus EMPTY** on a lib/ offense —
  lib/ paths match no Rails surface. Human priority (the offense) has no
  focus pointer: **focus miss** (important-miss class).
- DoD expressibility (operator judgment as maintainer): tests green ✓,
  lint clean ✓, no new debt ✓ (baseline), human review on risk ✓ → 4/5 (80%).
  Coverage gate N/A (project has none).
- Spontaneous demands observed: none (no history/plugin/server asks).
- Trial 4 (synthetic low-severity lint offense, strict + findings forbid):
  gate FAIL, decision FAIL via `gate_failed` (strict fails on any introduced
  finding; schema forbids only critical/high, and the offense was low).
  Coherent: the policy section adds severity gates, the mode adds the floor.
  failures, all network-dependent** (jspm CDN lookups; offline env). Gate
  FAIL — honest, pre-existing, unrelated to RailVerdict.
- Single-file subset passes (5 runs, 0 failures, 1.5s).
- Verdict: onboarded; first trustworthy verdict = FAIL with documented
  pre-existing cause. TARGETED-vs-FULL not yet measured here.

## P-C turbo-rails (hotwired/turbo-rails @ 37530c0) — engine, minitest — PARTIAL

- Onboarding: clone 2.7MB, `bundle install` exit 0 after retry (initial
  resolver failure misleading; direct bundle works — candidate's minimal env
  vs project bundle interaction noted).
- Minitest required: analyzer timed_out at 30s; suite needs dummy app +
  system tests (browser weight) — full-suite evidence unobservable in this
  env. Rubocop-only trial: INCOMPLETE (reason not yet isolated).
- Status: partial. Counts toward onboarding friction, not toward verdict
  metrics.

## P-D sprockets-rails (rails/sprockets-rails @ 87ee2d2) — engine, minitest

- Onboarding: clone fast, `bundle install` exit 0 (~7s), first verdict PASS
  (minitest, 4.8s). No gem patch. Total < 2 min. Default branch is `master`
  (trial-protocol lesson: never assume `main`).
- Fail-closed proof: rubocop absent from the project bundle + required:true
  → INCOMPLETE (invariant: missing required evidence never passes).
- Strict + baseline flow: baseline create refused on incomplete, succeeded on
  complete; offense trial inconclusive for rubocop findings (tool absent —
  environmental, counted as limitation not product signal).
- DoD expressibility: tests green ✓, baseline delta ✓ → partial (lint N/A:
  project carries no rubocop).
- Spontaneous demands: none.

## P-E tailwindcss-rails (rails/tailwindcss-rails @ 9e32b4e) — engine, minitest

- Onboarding: clone fast, `bundle install` exit 0 (~2s), first verdict PASS
  (minitest, 2.0s). No gem patch. Total < 1 min.
- Synthetic failing test (seeded `assert_equal_broken_xyz`): gate WARN
  (advisory), findings present — advisory honesty holds on external code.
- Fixture hygiene note: scratch trial commits landed on a detached flow;
  restored; trial configs live in /tmp only, never upstream.
- Spontaneous demands: none.

## Blocked / excluded (declared, not hidden)

- lobsters/lobsters: requires ruby 4.0.0, env has 3.4.5 only. Blocked.
- stimulus-rails: clone failed (askpass I/O error). Not retried yet.
- gitlabhq/gitlabhq: monorepo weight exceeds budget. Excluded by design.
- chatwoot/chatwoot, diaspora/diaspora, mastodon/mastodon: service
  dependencies (postgres/redis/node) exceed trial budget. Excluded by design.
- discourse/discourse: completed (see P-F above).

## P-F discourse/discourse (@ 5e9779d) — app, rspec/rubocop

- Onboarding: clone 342MB (~9s), full `bundle install` OK (~4 min),
  first verdict PASS (rubocop, 41s). No gem patch. Total < 10 min.
- Synthetic offense (lib/ trailing ws, advisory): WARN with 1 finding.
- Agent micro-tasks: control fixed in 2 iterations, scorekeeper PASS (3
  turns, correct); treatment read packet, fixed, re-verified PASS/PASS
  (2 turns, correct).
- Migration copy (db/migrate duplicate): risk HIGH (`migration_added`),
  focus #1 migration — **focus HIT** on a surfaced path.
- Spontaneous demands: none.

## Aggregate metrics vs pre-registered thresholds

| Threshold | Result | Verdict |
|---|---|---|
| 100% incomplete-evidence → non-PASS | 3/3 (sprockets required-missing, turbo timeout, minitest-missing paths) | HOLD |
| ≥80% first verdict without patch | 5/5 (100%) | HOLD |
| Median onboarding < 30 min | ~7 min (1,2,2,10,15) | HOLD |
| Focus top-3 ≥70% | 1/3 (discourse HIT; propshaft + sprockets lib/ MISS) | **MISS** |
| False-sensitive <10% | 0 observed | HOLD (thin) |
| DoD expressible ≥70% | 80% (single project) | HOLD (thin) |
| Packet reduces false success | 2 micro-tasks, both correct, no discrimination | HOLD (G2.5 carries this: 0/10 vs 6/10) |

Change evaluations: ~22 (propshaft 5, importmap 2, turbo 2, sprockets 4,
tailwind 2, discourse 5, agent tasks 2). Sample minimums met (5 projects,
20 changes); inferential power thin on focus (n=3), DoD (n=1), agent (n=2).

## Top pains (frequency/severity)

1. Unsurfaced-path blindness (lib/): 2 focus misses, same root cause —
   changed files matching no surface yield empty focus and LOW risk even when
   they carry the change's only finding. Bounded, deterministic, patch-sized.
2. Default 30s analyzer timeout too short for real suites (turbo,
   importmap) — config knob exists; default questioned (no change proposed;
   raising defaults has hang-risk tradeoffs).
3. Onboarding bundle/service weight (lobsters ruby, thredded mysql,
   chatwoot-class excluded) — environmental, not product.
4. No spontaneous demand observed for history, plugins, control center,
   remote verification, or signatures (nobody asked, in any trial).

## Decisions

- `MUST`: fix unsurfaced-path focus gap as a bounded patch (generic fallback
  pointer, no signal inflation) — 1.8.2 candidate, not a version theme.
- `SHOULD`: document the 30s-timeout tuning guidance for real suites.
- `COULD`: revisit service-heavy onboarding if a 10-project campaign is funded.
- `REJECT`: history/plugin/marketplace/dashboard/remote-trust — zero demand
  observed; speculation prohibited.
- 1.9: `NO_1_9_FEATURE` (no theme crossed evidence thresholds).
- Distributed trust (preliminary): `DISTRIBUTED_TRUST_NOT_JUSTIFIED` — no
  cross-machine evidence need observed in any trial; receipts/handoffs
  suffice locally everywhere tested.

## Exit

`ADOPTION_DECISION_RECORDED`: `INSUFFICIENT_EVIDENCE` for broad validation
(minimums met, inference thin, one threshold missed), with a directional
maintenance item (1.8.2) and explicit non-demand record. Honest, reproducible,
revisable with a funded 10-project campaign.
