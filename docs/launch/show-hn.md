Title: Show HN: RailVerdict – Deterministic verification gates for Rails and coding agents

Body:

We built RailVerdict because "tests pass + linter clean" still leaves open the question "is this change safe to accept?" — especially when AI agents write and auto-verify their own PRs.

RailVerdict is a local, offline, fail-closed verification gate for Rails. It collects evidence from the tools you already run (RSpec/Minitest, RuboCop, SimpleCov, bundler-audit, Git), normalizes to stable findings, applies project policy + historical baselines (no-new-debt), and returns a single machine decision: PASS / WARN / FAIL / INCOMPLETE.

Why not just CI / rubocop+rspec? CI says "jobs ran"; RailVerdict says "given required evidence, repo state, baseline and policy, what's the deterministic decision?" Missing evidence → INCOMPLETE (exit 2), never a silent PASS.

1.2 adds Verification Receipts + Repository State Identity (HEAD + index + worktree delta + config/baseline/waiver digests). `receipt verify` reports `fresh` vs `stale` with a reason; agents must reverify after any edit. One `verify` executes analyzers exactly once; cached receipts/PR intelligence never rerun them.

Offline/no SaaS/no telemetry by default. Known limits: no Brakeman (legal hold), no OS sandbox, no signed attestations (integrity record, not cert).

Open source (MIT): https://github.com/pedro-dalben/RailVerdict
Gem: `gem install rail_verdict` — Ruby >=3.3, Rails >=8.0 bounded

Looking for feedback: Does installation + `railverdict init/doctor/check/baseline` make sense on a real Rails app? Where does INCOMPLETE or baseline confuse? What analyzer is missing?

