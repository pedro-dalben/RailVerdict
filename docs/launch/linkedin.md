RailVerdict 1.2.0 — open source deterministic verification for Rails

We open-sourced the verification layer we needed while maintaining a real Rails platform (IntegrarPlus): offline, fail-closed, agent-aware.

RailVerdict turns RSpec/Minitest + RuboCop + SimpleCov + bundler-audit + Git into one deterministic gate (PASS/WARN/FAIL/INCOMPLETE), with baseline/no-new-debt for legacy apps and — new in 1.2 — Verification Receipts bound to the exact repo state. No SaaS, no telemetry.

Ruby >=3.3, Rails >=8.0 (bounded), gem `rail_verdict`.

Repo: https://github.com/pedro-dalben/RailVerdict — feedback on real Rails adoption is the next evidence.

