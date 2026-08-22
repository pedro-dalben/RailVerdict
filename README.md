# RailVerdict

**Deterministic, offline, fail-closed merge verification for Ruby on Rails.**

[![Gem Version](https://badge.fury.io/rb/rail_verdict.svg)](https://rubygems.org/gems/rail_verdict)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3-CC342D.svg)](https://www.ruby-lang.org)

RailVerdict is a deterministic verification framework for Ruby on Rails applications. It collects evidence from existing quality tools, normalizes it into stable findings, applies project policy and historical baselines, and produces a machine-readable `PASS` / `WARN` / `FAIL` decision that humans, CI systems, and AI coding agents can trust.

```
Evidence discovers.
Verification decides.
Intelligence explains.
Agents act.
```

> **One command. One gate.** No SaaS, no accounts, no telemetry, no hosted service. Core verification is 100% local and offline.

---

## Why RailVerdict Exists

In modern Rails development, source code is written and modified across multiple surfaces:

- **Software engineers** crafting features, migrations, and bug fixes;
- **Automated refactoring tools** updating syntax and framework deprecations;
- **AI coding agents** generating code, tests, and pull requests;
- **CI automation** running checks and test suites.

Running test suites alone is not enough to answer a fundamental question:

> **"Is this change safe to accept?"**

Existing tools produce fragmented formats and disparate semantics:

- **RuboCop** reports style and lint offenses;
- **RSpec** and **Minitest** report test outcomes and failures;
- **SimpleCov** reports line coverage metrics;
- **bundler-audit** reports gem dependency advisories;
- **Git** tracks what actually changed.

When AI coding agents enter this workflow, a new challenge appears: an AI model can explain findings and propose code changes, but **an AI model should not be the authority deciding whether code is safe to merge**.

RailVerdict solves this by establishing a **deterministic verification layer** between raw tooling and human engineers or coding agents. Given identical repository state, configuration, analyzer state, and baseline, RailVerdict produces the exact same evidence-backed `PASS`, `WARN`, or `FAIL` gate result — regardless of whether AI is enabled.

---

## Born from a Real Rails Application

RailVerdict was not created as an isolated demo or synthetic experiment. It originated from real-world engineering needs encountered while maintaining **IntegrarPlus**.

IntegrarPlus is a private Ruby on Rails platform developed for the operational needs of a multidisciplinary healthcare organization. It has grown continuously over time and contains multiple interconnected business modules and workflows. Development involves both traditional engineering and AI-assisted coding.

As the application grew, maintaining confidence across tests, authorization, security, regressions, code quality, and automated changes became increasingly important. RailVerdict emerged from the need for a reusable verification layer capable of giving both humans and coding agents a deterministic answer about the state of a change.

> **Information Firewall:** No IntegrarPlus private source code, database schemas, business rules, clinical workflows, or private data are included in RailVerdict. All public examples, tests, and validation fixtures are strictly synthetic. RailVerdict is a completely standalone, open-source verification framework reusable by any Rails application.

---

## Tested Beyond Unit Tests: RailVerdict Lab

Validation repository: [pedro-dalben/railverdict-lab](https://github.com/pedro-dalben/railverdict-lab)

To ensure RailVerdict works reliably in real-world conditions, it is continuously tested against **RailVerdict Lab** — an independent, public Rails application designed to exercise RailVerdict as an external consumer rather than testing only internal classes.

### Validation Scope

The Lab exercises RailVerdict across realistic operational scenarios:

- Installing and running RailVerdict as an external gem dependency in a real Rails codebase;
- Introducing controlled regressions to verify expected `PASS`, `FAIL`, and `INCOMPLETE` gate behavior;
- Validating Git-aware changed-scope verification (`--changed --base`);
- Testing analyzer availability, timeout, and failure modes;
- Validating CLI commands, structured JSON, and SARIF output;
- Validating Model Context Protocol (MCP) tool execution;
- Validating repair packet generation and repair verification;
- Exercising fail-closed behavior on missing or malformed analyzer output;
- Testing release artifact installation from clean environments.

### 21 / 21 External Validation Campaign

The 1.0 release closeout validated **21 out of 21** external scenarios:

| Category | Scenarios | Result |
|---|---:|:---:|
| **Core Verification** | 12 / 12 | PASS |
| **Operational & CI** | 6 / 6 | PASS |
| **Release Closeout** | 3 / 3 | PASS |
| **Total** | **21 / 21** | **PASS** |

These controlled validation scenarios represent rigorous external regression verification rather than a claim of mathematically bug-free software. During development, the Lab uncovered real defects — such as test failure scoping edge cases — which were fixed before the 1.0 release.

---

## The Verification Pipeline

```
+-------------------------------------------------------------+
|                      Rails Project                          |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|               1. Evidence Layer (Analyzers)                 |
|  RuboCop · Minitest · RSpec · SimpleCov · bundler-audit     |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|                  Normalized Findings (v1)                   |
|       Analyzer-independent · Fingerprinted · Stable         |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|               2. Verification Core (Policy)                 |
|     Baseline (no-new-debt) · Waivers · Policy Evaluation    |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|           Deterministic Gate: PASS / WARN / FAIL            |
|                  (or INCOMPLETE / exit 2)                   |
+-------------------------------------------------------------+
        |                     |                     |
        v                     v                     v
+---------------+     +---------------+     +---------------+
|   Outputs     |     | 3. Advisory AI|     | 4. Agent Loop |
| Console, JSON,|     | Explain &     |     | RepairPackets,|
| SARIF, CI exit|     | Investigate   |     | MCP server,   |
|   (0, 1, 2)   |     |  (opt-in only)|     | coding agents |
+---------------+     +---------------+     +---------------+
```

- **Analyzers provide evidence.**
- **Policy owns the decision.**
- **AI never controls the deterministic GateResult.**

---

## Installation

Install the gem directly:

```bash
gem install rail_verdict
```

Or add it to your application's `Gemfile`:

```ruby
group :development, :test do
  gem "rail_verdict", require: false
end
```

Then install dependencies:

```bash
bundle install
```

---

## Quick Start

You can verify your Rails repository with RailVerdict in under five minutes:

```bash
# 1. Initialize default configuration (.railverdict.yml)
railverdict init

# 2. Check configuration and analyzer readiness
railverdict doctor

# 3. Create an initial baseline for existing technical debt
railverdict baseline create

# 4. Run verification
railverdict check

# 5. Inspect normalized findings
railverdict findings
```

### Example: A Passing Gate

When all required analyzers succeed and no new debt is introduced:

```
RailVerdict Verification: PASS
Policy: no_new_debt (complete)
Analyzers: 5 run (5 complete)
Findings: 0 introduced, 14 existing (baseline), 0 blocking
Exit: 0
```

### Example: A Policy Failure

When a change introduces a new offense or test failure:

```
RailVerdict Verification: FAIL
Policy: no_new_debt (failed)
Analyzers: 5 run (5 complete)
Findings: 1 introduced (blocking), 14 existing (baseline)
  - [rubocop] Lint/UselessAssignment in app/models/user.rb:42 (introduced)
Exit: 1
```

### Analyzer timeouts

Analyzer processes have a 30-second timeout by default. For a legitimately
long-running analyzer, use configuration schema `version: 1.5` and set the
timeout on that analyzer only:

```yaml
version: 1.5
mode: strict
analyzers:
  rubocop:
    enabled: true
    required: true
  rspec:
    enabled: true
    required: true
    timeout_seconds: 600
```

`timeout_seconds` must be an integer from 1 through 3600. An analyzer without
an explicit value, including every analyzer in older configuration versions,
continues to use 30 seconds. A timeout is incomplete evidence, never a normal
finding: a required timeout produces `INCOMPLETE` and exit code `2`.

RailVerdict 1.0.1 has no CLI timeout override; the versioned configuration is
the supported public surface. SimpleCov accepts the same setting for a uniform
configuration contract, but reads a local coverage artifact rather than
starting an analyzer process.

---

## The Default Policy Model: No New Debt

RailVerdict supports three policy modes: `no_new_debt` (default), `strict`, and `advisory`.

### Why "No New Debt" Matters

Large, mature Rails applications often contain existing technical debt: legacy style offenses, pending test skips, or partial test coverage. Requiring teams to fix all historical issues before adopting verification creates an impossible barrier.

RailVerdict's `no_new_debt` mode solves this by separating **historical debt** from **new changes**:

> **"Existing debt is known and recorded. New debt is blocked."**

### How Baselines Work

1. **Atomic Creation:** `railverdict baseline create` runs a complete verification and atomically records SHA-256 fingerprints of current findings into `.railverdict-baseline.json`.
2. **Comparison:** Subsequent runs classify findings into `introduced`, `existing`, `resolved`, `changed`, or `moved`.
3. **Selective Enforcement:** Only `introduced` (new) findings block the merge gate in `no_new_debt` mode.
4. **Read-Only Verification:** `railverdict check` is strictly read-only and never mutates baselines.
5. **Waivers:** Time-bounded, exact-fingerprint exemptions can be documented with owners and UTC expiration dates without silencing evidence.

---

## Changed-Scope Verification

For pull requests, CI builds, and coding agents, RailVerdict supports incremental, Git-aware verification:

```bash
# Verify only changes against the main branch
railverdict check --changed --base origin/main

# Verify against a local Git revision
railverdict check --changed --base HEAD~1

# Output versioned JSON for machine consumers
railverdict check --changed --base origin/main --format json
```

### Key Capabilities

- **Merge-Base Resolution:** Computes the exact `merge-base` between `HEAD` and the target branch;
- **NUL-Safe Diff Parsing:** Accurately handles renames, deletions, and binary files;
- **Changed-Line Coverage:** Evaluates whether newly added or modified executable lines are covered by tests;
- **Fail-Closed Git Boundary:** If the base revision is missing or repository history is shallow, RailVerdict returns `INCOMPLETE` (exit code 2) rather than guessing or silently passing.

---

## Supported Analyzers

All analyzers in RailVerdict are **external and owned by the target project**. RailVerdict invokes existing executables via argument arrays (`argv`) without shell interpolation and never silently installs or vendors third-party packages.

| Analyzer | Purpose | Supported Versions | How RailVerdict Consumes It |
|---|---|---|---|
| **RuboCop** (+ `rubocop-rails`) | Style, linting, Rails conventions | RuboCop `>= 1.72, < 2`<br>`rubocop-rails >= 2, < 3` | Runs `bundle exec rubocop --format json`; captures plugin versions and configuration digest. |
| **Minitest** | Unit and integration tests | `>= 5, < 7` | Consumes test results via RailVerdict's owned JSON reporter (`minitest-reporter-v1`). |
| **RSpec** | Unit and integration specs | `>= 3.13, < 4` | Consumes test results via standard `--format json`. |
| **SimpleCov** | Code and changed-line coverage | `>= 1, < 2` | Ingests versioned public `coverage/coverage.json` v1 (never parses internal `.resultset.json`). |
| **bundler-audit** | Gem dependency vulnerabilities | `>= 0.9.3, < 1` | Runs `bundle exec bundler-audit check --format json` (never runs automatic updates). Robustly extracts JSON when advisory-DB download notices precede the payload. |

> **Brakeman Status:** Brakeman support is **not included** in 1.0 (on HOLD pending legal and licensing review). Third-party analyzers retain their respective upstream licenses.

---

## Outputs, CI, and Exit Codes

RailVerdict produces structured output for both human developers and automated systems.

### Output Formats

- **Console (`--format console`):** Human-readable terminal output (default);
- **JSON (`--format json`):** Single-document, canonical JSON complying with [`result-v1.schema.json`](schemas/result-v1.schema.json) on `stdout`, diagnostics on `stderr`;
- **SARIF (`--format sarif`):** Standard SARIF 2.1.0 projection for GitHub Code Scanning and IDEs.

### Exit Code Contract

| Exit Code | Meaning | Gate Status |
|---:|---|---|
| **`0`** | Verification succeeded without blocking issues. | `PASS` or non-blocking `WARN` |
| **`1`** | Policy violation detected (new offenses, failing tests, etc.). | `FAIL` |
| **`2`** | Incomplete evidence, tool failure, missing base, or configuration error. | `INCOMPLETE` |
| **`130`** | Execution interrupted by user (`SIGINT`). | `INTERRUPTED` |

### Why Exit Code 2 is Vital

If a required analyzer is missing, times out, crashes, or produces malformed output, that run must **never** be interpreted as "zero offenses" or a `PASS`. RailVerdict fails closed: incomplete required evidence produces `INCOMPLETE` and exits with code `2`, preventing broken pipelines from silently passing.

### GitHub Actions Integration

```yaml
name: Verification
on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read

jobs:
  railverdict:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Run RailVerdict
        run: bundle exec railverdict check --changed --base ${{ github.event.pull_request.base.sha }}
```

See [`docs/github-actions.md`](docs/github-actions.md) for full CI configuration examples.

---

## Optional AI Intelligence (Advisory Only)

RailVerdict includes an optional intelligence layer designed to assist with finding explanations and triage:

```bash
# Explain a specific finding
railverdict explain <finding-id|fingerprint>

# Preview context that would be sent (no network)
railverdict explain <finding-id> --preview-context

# Investigate top blocking findings
railverdict investigate --limit 3
```

### Strict Advisory Boundaries

- **Opt-in Only:** AI is disabled by default. Enabling remote AI requires explicit configuration (`ai.enabled: true` and `ai.remote.enabled: true`).
- **Zero Gate Authority:** AI **never** controls `GateResult`. It cannot change a `FAIL` to a `PASS`, override project policy, or bypass checks.
- **Privacy & Redaction:** Sensitive tokens, credentials, and private patterns are automatically scrubbed (`trust: redacted` by default).
- **Offline Core:** All deterministic verification functions work 100% offline without network access or AI configuration.

See [`docs/ai.md`](docs/ai.md) and [`docs/privacy.md`](docs/privacy.md) for details.

---

## Coding Agents & The Repair Loop

RailVerdict provides a structured verification loop for AI coding agents (such as Claude, Codex, or custom agents):

```
Agent modifies code
        │
        ▼
railverdict check (returns FAIL / exit 1)
        │
        ▼
railverdict repair <finding-ref>
        │
        ▼
RepairPacket (bounded, structured context)
        │
        ▼
Agent applies fix
        │
        ▼
railverdict check (Verifier classifies outcome)
```

### RepairPacket v1

When an agent needs to fix a finding, `railverdict repair <finding-ref>` generates a deterministic `RepairPacket v1`:

- **Bounded Context:** Capped at 256 KiB with strict snippet and diff limits;
- **Trust Boundary:** Delimits `TRUSTED_RAILVERDICT_INSTRUCTIONS` from untrusted repository text;
- **Secret Redacted:** Scans and removes sensitive values before emission;
- **Outcome Classification:** `RailVerdict::Repair::Verifier` classifies repair outcomes as `fixed`, `still_present`, `changed`, `moved`, `regressed`, or `incomplete`.

RailVerdict never directly mutates application code; it provides the verifiable contract that allows external agents to repair code safely. See [`docs/repair-workflow.md`](docs/repair-workflow.md).

---

## Model Context Protocol (MCP)

RailVerdict includes a native [Model Context Protocol (MCP)](https://modelcontextprotocol.io) stdio server, allowing coding agents to interact with verification as structured tools:

```bash
railverdict mcp serve
```

### Implemented MCP Tools

| Tool | Purpose |
|---|---|
| `verify` | Executes verification (`full` or `changed`) and returns canonical `GateResult`. |
| `list_findings` | Lists, filters, and paginates normalized findings. |
| `get_finding` | Retrieves detailed finding data, evidence references, and context. |
| `build_repair_packet` | Builds a bounded `RepairPacket v1` for a specific finding. |
| `verify_repair` | Reruns verification and classifies whether a repair succeeded or regressed. |
| `explain` | Generates an advisory AI explanation for a finding. |
| `investigate` | Investigates top blocking findings across the codebase. |

### MCP Security Properties

- **Stdio Transport:** Operates over standard I/O with no open ports or background daemons;
- **Repository Containment:** Paths are verified and strictly contained within the repository root;
- **Read-Only Tools:** All tools are marked `readOnlyHint: true`; RailVerdict verifies while external agents edit;
- **Mutex Serialization:** Verification runs are serialized to prevent concurrent execution conflicts.

See [`docs/mcp.md`](docs/mcp.md) for configuration examples.

---

## Rails-Aware Context (Without Booting Rails)

When verifying changes (`--changed`), RailVerdict enriches results with **bounded Rails-aware context** without booting the Rails application, loading ActiveRecord, or executing `routes.rb` and `schema.rb`:

- **Related Tests:** Identifies candidate test and spec files for modified models and controllers;
- **Policies:** Locates corresponding Pundit/ActionPolicy authorization policies;
- **Views:** Identifies associated view templates;
- **Routes & Schema:** Extracts literal route definitions and schema table fragments.

Each context element includes an explicit confidence rating (`exact`, `conventional`, `inferred`, `unresolved`) and provenance. Context extraction failures degrade gracefully without causing gate failures. See [`docs/rails-context.md`](docs/rails-context.md).

---

## Security & Fail-Closed Architecture

RailVerdict is engineered around a comprehensive threat model documented in [`SECURITY.md`](SECURITY.md):

- **Fail-Closed Gate:** Incomplete, missing, or malformed evidence cannot produce a `PASS`;
- **Safe Subprocess Execution:** Invokes executables exclusively via argument arrays (`argv`), eliminating shell-injection vulnerabilities;
- **Resource Bounds:** Monotonic timeouts, output limits, and process-group signal termination (`SIGTERM`/`SIGKILL`) prevent resource exhaustion;
- **Path Containment:** Normalizes paths and rejects directory traversal or symlink escapes;
- **Information Firewall:** Strict public provenance controls prevent internal data or private patterns from entering artifacts;
- **Subprocess Limitation:** Subprocess containment provides argument and resource isolation; it is not an operating system kernel sandbox.

---

## Architecture Overview

RailVerdict is structured into four distinct conceptual layers:

1. **Evidence Layer:** Executes external quality tools safely and captures facts;
2. **Verification Core:** Normalizes findings, manages fingerprints and baselines, and evaluates policy to produce an immutable `GateResult`;
3. **Intelligence Layer:** Provides optional, advisory explanations without gate authority;
4. **Agent Layer:** Exposes deterministic interfaces (CLI, JSON, SARIF, RepairPackets, MCP) for human engineers and coding agents.

```
Evidence discovers.
Verification decides.
Intelligence explains.
Agents act.
```

For detailed architectural principles and component designs, see [`ARCHITECTURE.md`](ARCHITECTURE.md), [`PROJECT.md`](PROJECT.md), and [`PHILOSOPHY.md`](PHILOSOPHY.md).

---

## What RailVerdict Is NOT

To maintain clear technical boundaries, RailVerdict is explicitly **NOT**:

- **NOT a replacement for test frameworks or linters:** It does not replace RSpec, Minitest, or RuboCop; it normalizes and verifies their evidence.
- **NOT an AI code reviewer that decides safety:** AI cannot override or determine the gate decision.
- **NOT a hosted SaaS or cloud dashboard:** There are no user accounts, billing, hosted control planes, or telemetry.
- **NOT an auto-fixing bot:** It does not autonomously commit or rewrite application source code.
- **NOT a full semantic code graph:** Rails relationships are bounded, heuristic, and labeled with confidence rather than deep AST graphs.

---

## Project Status

- **Release Version:** `1.0.1`
- **License:** [MIT](LICENSE) (see [NOTICE](NOTICE))
- **Trademarks:** [TRADEMARKS.md](TRADEMARKS.md)
- **Foundation & Legal:** [docs/foundation.md](docs/foundation.md) — preliminary screen found no obvious software/tool conflict; NOT LEGAL CLEARANCE; qualified trademark review NOT PERFORMED — NON-BLOCKING BY MAINTAINER DECISION 2026-08-19 (Pedro Dalben).
- **Ruby Compatibility:** `>= 3.3` (tested on Ruby 3.3, 3.4, and 4.0)
- **Target Rails Context:** `>= 8.0`
- **Supply Chain:** Released via RubyGems Trusted Publishing and GitHub OIDC.

---

## Documentation Index

| Topic | Primary Documents |
|---|---|
| **Product & Philosophy** | [`PROJECT.md`](PROJECT.md) · [`PHILOSOPHY.md`](PHILOSOPHY.md) · [`ARCHITECTURE.md`](ARCHITECTURE.md) · [`ROADMAP.md`](ROADMAP.md) |
| **Contracts & Schemas** | [`docs/contracts.md`](docs/contracts.md) · [`schemas/finding-v1.schema.json`](schemas/finding-v1.schema.json) · [`schemas/configuration-v1.schema.json`](schemas/configuration-v1.schema.json) · [`schemas/result-v1.schema.json`](schemas/result-v1.schema.json) |
| **Examples** | [`examples/finding-v1.json`](examples/finding-v1.json) · [`examples/configuration-v1.yml`](examples/configuration-v1.yml) · [`examples/configuration-v1.5.yml`](examples/configuration-v1.5.yml) · [`examples/result-v1.json`](examples/result-v1.json) |
| **Analyzers & Baselines** | [`docs/analyzers.md`](docs/analyzers.md) · [`docs/baselines.md`](docs/baselines.md) |
| **CI, SARIF & Git Scope** | [`docs/github-actions.md`](docs/github-actions.md) |
| **Rails-Aware Context** | [`docs/rails-context.md`](docs/rails-context.md) |
| **Agent Protocols & Repair** | [`docs/mcp.md`](docs/mcp.md) · [`docs/repair-workflow.md`](docs/repair-workflow.md) |
| **AI & Privacy** | [`docs/ai.md`](docs/ai.md) · [`docs/privacy.md`](docs/privacy.md) |
| **Security & Firewall** | [`SECURITY.md`](SECURITY.md) · [`docs/foundation.md`](docs/foundation.md) |
| **Architecture Decisions** | [`ADRs`](docs/adr/) |
| **Legal & Trademarks** | [`LICENSE`](LICENSE) · [`NOTICE`](NOTICE) · [`TRADEMARKS.md`](TRADEMARKS.md) |
| **Changelog** | [`CHANGELOG.md`](CHANGELOG.md) |
| **Public Validation Lab** | [pedro-dalben/railverdict-lab](https://github.com/pedro-dalben/railverdict-lab) |

---

## Contributing & Issues

Contributions and issue reports are welcome. Please open an issue on GitHub for:

- Analyzer compatibility and version range feedback;
- False positives or false negatives in evidence normalization;
- Rails version or convention compatibility;
- CLI and MCP ergonomics and developer experience.

GitHub Repository: [https://github.com/pedro-dalben/RailVerdict](https://github.com/pedro-dalben/RailVerdict)
Issues: [https://github.com/pedro-dalben/RailVerdict/issues](https://github.com/pedro-dalben/RailVerdict/issues)
