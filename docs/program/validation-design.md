# G3 Product Validation — Campaign Design (pre-registered)

Status: thresholds frozen before observation. No code changes in this node.

## Question

Does RailVerdict 1.7/1.8 solve a pain outside IntegrarPlus, or only sophisticate
our own system?

## Sample (min 5 projects, 20 changes; target 10/50)

Public Rails projects only, no forks counted twice, IntegrarPlus as dogfood
(not external evidence). Candidates: rails/rails (framework, minitest),
discourse/discourse (app, rspec), mastodon/mastodon (app, rspec),
chatwoot/chatwoot (app, rspec), diaspora/diaspora (app, rspec),
hotwired/turbo-rails (engine, minitest), thredded/thredded (app, minitest),
lobsters/lobsters (app, minitest). GitLab is excluded (monorepo weight exceeds
this campaign's budget; recorded, not hidden).

Per project record: approximate size, Rails/Ruby, test framework, analyzers
present, policy used, setup time, verdict time, limitations.

## Protocol per project

1. Clone at a pinned SHA (record it). No writes to the project except a
   scratch 1.7 config when the project has none (never committed upstream).
2. First trustworthy verdict: time from clone to first gate with required
   evidence complete (or honest INCOMPLETE with reasons).
3. Synthetic changes (2+ per project, committed on a scratch branch, never
   pushed): lint offense, failing test, migration, dependency touch, clean
   change. Record gate/decision per change plus TARGETED-vs-FULL and fallback.
4. Reviewer check (maintainer = operator): top-3 Review Focus vs own priority
   judgment; DoD expressibility count (how many of the project's real merge
   rules map to policy requirements without ad-hoc scripts).
5. Agent check (2 tasks per project where feasible): control vs packet arms on
   a seeded defect; false-success and turns.

## Metrics (same 12 as program §8)

Onboarding time, install/config completion, TARGETED/FULL frequency + fallback
reasons, verification + reuse time, non-PASS rate on incomplete evidence,
false-sensitive signals, important misses, Focus top-3 hit rate, DoD
expressibility %, ad-hoc-script requirements, agent false-success with/without
packets, reviewer effort (time/files/returns), spontaneous demands (history,
plugin, control center, remote verification, signatures).

## Pre-registered thresholds (from program §8 baseline)

- 100% of incomplete-required-evidence cases end non-PASS.
- ≥80% of projects reach first verdict without gem patch.
- Median onboarding < 30 min for compatible projects.
- Focus top-3 hits human priority in ≥70% of evaluable cases.
- False-sensitive signals < 10%.
- ≥70% of real DoD rules expressible without ad-hoc script.
- Packet arm reduces agent false successes without hiding deterministic misses.

## Outputs

- `docs/program/validation-dataset.md`: anonymized/synthetic-safe dataset.
- Methodology (this file), raw results, analysis with limitations.
- Top pains by frequency/severity; MUST/SHOULD/COULD/REJECT decisions.
- Exactly one 1.9 choice or `NO_1_9_FEATURE`.
- Preliminary distributed-trust decision.
- Exit: `ADOPTION_DECISION_RECORDED` (`VALIDATED` | `NOT_VALIDATED` |
  `INSUFFICIENT_EVIDENCE`).

## Non-goals

No gem code, no schema changes, no Lab catalog changes for validation (Lab
stays the product's black-box suite; G3 evidence lives in program docs).
