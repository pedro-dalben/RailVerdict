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
- discourse/discourse: clone 342MB OK (@ 5e9779d); full bundle in progress at time of writing (heavy dependency tree + services). Outcome pending.
