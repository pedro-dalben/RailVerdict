# RailVerdict

**Evidence before merge. Deterministic, offline, fail-closed verification for Ruby on Rails.**

[![Gem Version](https://badge.fury.io/rb/rail_verdict.svg)](https://rubygems.org/gems/rail_verdict)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3-CC342D.svg)](https://www.ruby-lang.org)

RailVerdict collects evidence from established Ruby/Rails quality tools, normalizes it into versioned canonical findings, applies repository-owned policy and baselines, and returns a deterministic merge gate for **humans, CI, and coding agents**.

> **One command. One gate.** No SaaS, no accounts, no telemetry, no hosted service. Core verification is fully offline.

---

## Why RailVerdict?

Existing tools give fragmented signals — lint, tests, coverage, dependencies. RailVerdict's value is the **stable verification model** that makes those signals *comparable, policy-addressable, and machine-readable* with one deterministic `PASS / WARN / FAIL / INCOMPLETE`.

| Problem | How RailVerdict helps |
|---|---|
| "Passing" CI that hid incomplete evidence | Incomplete required analyzers can never become `PASS` (`INCOMPLETE` / exit 2) |
| Legacy debt blocks adoption | Versioned fingerprints + baselines + `no_new_debt` — existing debt retained, only regressions block |
| Untrusted PR code near secrets | `--changed` from trustworthy local Git facts; safe GitHub Actions example with minimum permissions |
| Agents scraping terminal output | Versioned JSON (`result-v1`) + stable exit codes + canonical ordering |
| "Where is this finding related?" | Bounded Rails-aware context (models, routes, views, policies, schema, associations) without booting Rails |

---

## Quick Start

```bash
gem install rail_verdict

# In a Rails (or synthetic) repository:
railverdict init                          # writes .railverdict.yml
railverdict doctor                        # validates config, probes analyzers
railverdict check                         # full verification → console
railverdict check --format json           # versioned JSON on stdout, diagnostics on stderr
railverdict check --changed --base main   # changed-scope gate from deterministic Git diff
railverdict baseline create               # atomic baseline from a complete run
railverdict findings --format json        # projection of normalized findings
```

**Exit codes:** `0` PASS/WARN · `1` FAIL · `2` INCOMPLETE/config/tool error · `130` interrupted.

---

## What Runs

All analyzers are **external and target-project-owned** — RailVerdict never installs or bundles them.

| Adapter | What it consumes | Supported versions |
|---|---|---|
| **RuboCop** (+ `rubocop-rails` provenance) | `bundle exec rubocop --format json` | RuboCop `>= 1.72, < 2` · `rubocop-rails >= 2, < 3` |
| **Minitest** | RailVerdict-owned reporter → `minitest-reporter-v1` JSON | `>= 5, < 7` |
| **RSpec** | `--format json` | `>= 3.13, < 4` |
| **SimpleCov** | Public `coverage/coverage.json` v1 (never `.resultset.json`/HTML) | `>= 1, < 2` |
| **bundler-audit** | `check --format json` (never `update`) | `>= 0.9.3, < 1` |

Each adapter maps the full failure corpus (`unavailable`, `unsupported`, `timed_out`, `signaled`, `failed`, `parse_failed`, `truncated`, `malformed`) and records tool provenance.

---

## Core Concepts

```
AnalyzerResult (what a tool did)
      │
      ▼
   Finding (analyzer-independent, fingerprinted, versioned)
      │
      ▼
  Comparison (introduced / existing / resolved / changed / moved · rename-aware)
      │
      ▼
    Policy (advisory · no_new_debt · strict) ──► GateResult (immutable)
      │                                              │
      ▼                                              ▼
  Console / JSON / SARIF / GitHub Annotations    exit code
```

- **Fingerprint v1** — canonical payload `sha256:<64hex>` over `{analyzer, rule_id, path, message}` (line/timestamp/path-order agnostic).
- **Baselines** — versioned, atomic (`fsync` + `rename`), read-only checks never mutate them.
- **Waivers** — exact-fingerprint, with `owner`, `reason`, `created_at`, UTC `expires_at`, optional `issue_ref`.
- **Comparison** — `moved` = same rule+message, different path (rename-aware); `changed` = same path+rule, different message; `introduced`/`resolved` are fallback.
- **Policy** — the *only* gate authority; adapters/reporters/AI can never change it. `required: true` incomplete → `INCOMPLETE`, not `PASS`.

---

## Changed Scope & GitHub

```bash
railverdict check --changed --base origin/main              # PR-like
railverdict check --changed --base HEAD~1 --format json     # local diff
```

- Resolves `HEAD`, `base` (`--base` > `git.base` in `.railverdict.yml`), `merge-base`, NUL-safe changed files/lines, renames, binaries, conflicts.
- Missing base or shallow/incomplete history → `INCOMPLETE` (`git_scope_failed`) — never guesses.
- Production changed-line coverage uses the same `changed_line_set` recorded in `RunContext`.

**GitHub Actions** — see [`docs/github-actions.md`](docs/github-actions.md) and [`examples/github/railverdict.yml`](examples/github/railverdict.yml): `pull_request` (never `pull_request_target`), `contents: read`, `fetch-depth: 0` at `head.sha`, same local gate invoked as `bundle exec railverdict check --changed --base ${{ github.event.pull_request.base.sha }}`. SARIF and annotation projections are pure `GateResult` projections.

---

## Rails-Aware Context (Phase 05)

When `--changed` is used, RailVerdict enriches the result with **bounded, deterministic Rails relationships** — without booting the app, loading ActiveRecord, executing `routes.rb`/`schema.rb`, or building a code graph.

For each **changed** file, it classifies `kind` + `constant` and resolves:

- **Related tests** — `test/**/…_test.rb` / `spec/**/…_spec.rb` that physically exist (candidates, not "affected" guarantees).
- **Policies** — `app/policies/<model>_policy.rb`.
- **Views** — `app/views/<controller>/…` (bounded, deterministic).
- **Routes** — literal `resources` / `get … to: '…#…'` mappings from `config/routes.rb` (`draw`/`mount`/`concerns` → `unresolved`).
- **Schema** — `db/schema.rb` table fragments (`db/structure.sql` → `unresolved`).
- **Associations** — literal `belongs_to` / `has_one` / `has_many` / `has_and_belongs_to_many`.

Every related item carries `confidence` in `{exact, conventional, inferred, unresolved}` and a `provenance` string. Failures degrade to partial context, never to `INCOMPLETE`. Full details: [`docs/rails-context.md`](docs/rails-context.md).

```json
"rails_context": {
  "detected": { "rails_version": "8.0.1", "test_framework": "rspec", "database_adapter": "postgresql" },
  "scope": "changed",
  "entries": [{ "source_path": "app/models/user.rb", "kind": "model", "constant": "User", "related": […] }]
}
```

---

## Configuration

```yaml
# .railverdict.yml (v1.3)
version: 1.3
mode: no_new_debt          # advisory | no_new_debt | strict
analyzers:
  rubocop:       { enabled: true, required: true }
  minitest:      { enabled: true, required: true }
  rspec:         { enabled: true, required: false }
  simplecov:     { enabled: true, required: false, coverage_path: coverage/coverage.json, freshness_window_seconds: 86400 }
  bundler_audit: { enabled: true, required: false }
git:
  base: main               # fallback for --changed when --base is not passed
```

Strict, versioned schemas: `configuration-v1` … `v1.3`, `finding-v1`, `result-v1`, `baseline-v1`, `waivers-v1`, `coverage-v1`. Unknown fields fail with a property path. See [`docs/contracts.md`](docs/contracts.md).

---

## Documentation

| Topic | File |
|---|---|
| Product, philosophy, architecture | [`PROJECT.md`](PROJECT.md) · [`PHILOSOPHY.md`](PHILOSOPHY.md) · [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| Public contracts & CLI surface | [`docs/contracts.md`](docs/contracts.md) |
| Analyzers & support proposal | [`docs/analyzers.md`](docs/analyzers.md) |
| Baselines, comparison, waivers | [`docs/baselines.md`](docs/baselines.md) |
| GitHub Actions & SARIF | [`docs/github-actions.md`](docs/github-actions.md) |
| Rails-aware context | [`docs/rails-context.md`](docs/rails-context.md) |
| Security & information firewall | [`SECURITY.md`](SECURITY.md) |
| Roadmap (Phase 0–9) | [`ROADMAP.md`](ROADMAP.md) |
| ADRs | [`docs/adr/`](docs/adr/) |

---

## Development

```bash
bundle install
bundle exec rake test          # synthetic fixtures only, deterministic
bundle exec rubocop
```

- Ruby `>= 3.3`, one gem, one process, `json_schemer` as sole runtime dependency.
- External execution via `executable + argv` (no shell interpolation), bounded I/O, monotonic timeout, process-group cleanup, minimal env, NFC-normalized paths.

---

## Legal

- **License:** [Apache-2.0](LICENSE) — see [NOTICE](NOTICE)
- **Trademarks:** [TRADEMARKS.md](TRADEMARKS.md) (software rights and trademark policy are separate)
- Publication / package reservation remains blocked pending documented launch-jurisdiction searches (including Brazil) and qualified trademark review — see [foundation record](docs/foundation.md).
