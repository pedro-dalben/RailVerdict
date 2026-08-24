# RailVerdict — Positioning

Source of truth for public messaging. All launch posts, README phrasing, and gem metadata derive from this file.

## Canonical description (long)

RailVerdict is a deterministic, offline, fail-closed verification gate for Rails repositories. It collects evidence from the quality tools you already run — RSpec or Minitest, RuboCop, SimpleCov, bundler-audit, and Git — normalizes that evidence into stable findings, applies your project policy and historical baselines, and returns a single machine-readable decision: `PASS`, `WARN`, `FAIL`, or `INCOMPLETE`. Humans, CI, and coding agents consume the same gate.

## Short description (RubyGems / GitHub description)

Deterministic, offline, fail-closed merge verification for Ruby on Rails projects.

## One-line description

RailVerdict turns evidence from your existing Rails tools into a trustworthy `PASS / WARN / FAIL / INCOMPLETE` — deterministically and offline.

## AI-agent description (secondary)

AI agents can write the code. RailVerdict verifies the repository state they leave behind. The agent proposes; the verification system decides. Every guarded verification can produce a bounded Verification Receipt bound to the exact observable state (HEAD + index + worktree delta + config/baseline/waiver digests), so `fresh` means the current state is identical to what was verified and `stale` tells agents they must reverify.

## CI description

RailVerdict complements CI. CI answers “did these jobs execute?” RailVerdict answers “given the required evidence, repository state, baseline and policy, what is the deterministic verification decision for this change?” Exit codes are CI-native: `0` PASS/WARN, `1` FAIL, `2` INCOMPLETE, `130` interrupt. JSON on stdout (one doc), diagnostics on stderr, SARIF 2.1.0 for code scanning.

## Problem statement

- Fragmented tool formats make “is this change safe to accept?” a judgment call.
- Test/lint/coverage runs alone don’t give a single policy decision.
- AI coding agents can run tools and declare themselves finished but should not be the authority deciding whether their own work is acceptable.
- Legacy Rails apps need incremental adoption (baseline existing debt, block new debt) not “fix everything first.”

## Target users

| Audience | Need | Primary message |
|---|:---|---|
| **PRIMARY: AI-assisted Rails teams** (Maintainers + legacy apps + agent users) | Objective completion boundary, no-new-debt, receipts | Agent writes, RailVerdict verifies — deterministic and offline |
| SECONDARY: Maintainers of active Rails apps | Confidence in PRs, CI enforcement | One gate over existing tools |
| SECONDARY: CI/platform engineers | Deterministic, fail-closed, SARIF/JSON, exit codes | Complements CI, never hides missing evidence |
| SECONDARY: Coding-agent builders | JSON/MCP/repair/receipt contracts | One verify, cached receipts + PR intelligence |

Primary launch audience is AI-assisted Rails teams because the trust boundary (agent proposes / verifier decides) is the sharpest differentiator and drives the receipt narrative. Other audiences are served by the same core without audience-specific forks.

## How it works (conceptual model)

```
RSpec / Minitest
RuboCop (+ rubocop-rails)
SimpleCov
bundler-audit
Git
      |
      v
RailVerdict (evidence → findings → policy → deterministic gate)
      |
      +--> PASS (complete, policy allows merge)
      +--> WARN (complete, non-blocking advisory)
      +--> FAIL (complete, policy blocks — new debt/tests failed)
      +--> INCOMPLETE (evidence missing/untrustworthy — no gate)
```

AI may explain findings (`explain`/`investigate`) or propose repairs (`RepairPacket v1`) but **never changes GateResult**. Policy owns the decision; reporters (console/JSON/SARIF) are projections.

## What RailVerdict is NOT

- Not another linter / test runner / static analyzer (it consumes them)
- Not an AI code reviewer (AI is advisory only, off by default, `trust: redacted`)
- Not a replacement for CI (it runs inside CI and is complementary)
- Not a security scanner (bundler-audit evidence is advised, but no completeness guarantee)
- Not a SaaS / hosted service / account / telemetry system (core is offline by default)

## Claims we intentionally avoid

- “Guarantees safe/bug-free/secure code”
- “AI-proof” / “eliminates bad merges” / “proves correctness” / “perfect verification”
- “Cryptographically signed attestation” for receipts (receipts are integrity records with `receipt_id = sha256:` — not signed; forged receipt can be self-consistent if whole file recomputed; trusted CI is the trust anchor when forgery is in scope)
- “Brakeman support” (on HOLD pending legal/product; correctly disclosed)

## Tone

Technical, precise, trade-off-aware. Prefer “deterministic, offline, fail-closed, evidence-backed, policy decision” over marketing superlatives. Docs explain; verification decides.

## Provenance for launch copy

- Canonical description → README first screen, Show HN first paragraph, LinkedIn first line, RubyGems long description.
- One-line → GitHub repo description fallback, r/ruby title complement.
- AI-agent line → agent guide and AGENTS.md snippet.
