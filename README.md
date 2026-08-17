# RailVerdict

**Evidence before merge.**

RailVerdict is a fully open-source, local-first verification framework for Ruby on Rails applications. Its intended contract is to collect evidence from established tools, normalize that evidence, apply repository-owned policy and baselines, and return a deterministic merge gate for humans, CI systems, and coding agents.

## Current Status

RailVerdict is in **Phase 02 — Evidence Ecosystem** (offline, deterministic, fail-closed). Publication is still blocked pending documented searches in every launch jurisdiction, including Brazil, and qualified trademark review; the exact unresolved record is in [the foundation record](docs/foundation.md).

Phase 01 (Trustworthy Core) is complete: one deterministic `railverdict check` through `AnalyzerResult` → `Finding` → `Policy` → `GateResult` → `Console`/`JSON` → exit 0/1/2/130. Phase 02 adds independent evidence adapters (Minitest, RSpec, SimpleCov global coverage, bundler-audit) on top of the proven RuboCop path via `configuration-v1.1.schema.json`; changed-line coverage is a pure injected-line-set calculation and production Git scope remains deferred to Phase 04. Brakeman remains on HOLD. There is no SaaS, no telemetry, no network refresh at verification time, and no AI/MCP/GitHub integration in this phase.

## Foundation

- [Product definition and competitive position](PROJECT.md)
- [Operating philosophy](PHILOSOPHY.md)
- [Architecture contract](ARCHITECTURE.md)
- [Name, identity, and publication status](docs/foundation.md)
- [Analyzer and support proposal](docs/analyzers.md)
- [Draft public contracts](docs/contracts.md)
- [Security and information-firewall policy](SECURITY.md)
- [Public roadmap](ROADMAP.md)
- [Architecture decision records](docs/adr/)

## Evidence Adapters (Phase 02)

Implemented via external target-project processes; RailVerdict never bundles or installs any of them:

| Adapter | Schema / contract | Supported versions | Docs |
|---|---:|---:|---|
| Minitest | `schemas/minitest-reporter-v1.schema.json` (reporter: `exe/railverdict-minitest-reporter.rb`) | `>= 5, < 7` | `docs/analyzers.md` |
| RSpec | Documented JSON formatter (`--format json`) | `>= 3.13, < 4` | `docs/analyzers.md` |
| SimpleCov | Public `coverage/coverage.json` v1 (`schemas/coverage-v1.schema.json`) | `>= 1, < 2` | `docs/analyzers.md` |
| bundler-audit | `check --format json`; `version` for DB revision; never invokes `update` | `>= 0.9.3, < 1` | `docs/analyzers.md` |
| RuboCop + rubocop-rails | JSON formatter; config digest + lockfile plugin recorded | RuboCop `>= 1.72, < 2`; rubocop-rails `>= 2, < 3` | `docs/analyzers.md` |

Changed-line coverage is the pure `RailVerdict::Coverage::ChangedLineEvaluator` over an injected `LineSet`; production `--changed` belongs to Phase 04. Brakeman is on HOLD. Network advisory-database refresh (`bundle exec bundler-audit update`) is an explicit, separate operation.

## Schemas and Synthetic Examples

- [Finding schema](schemas/finding-v1.schema.json) and [Finding example](examples/finding-v1.json)
- [Configuration schema v1.0](schemas/configuration-v1.schema.json) and [configuration example v1.0](examples/configuration-v1.yml)
- [Configuration schema v1.1](schemas/configuration-v1.1.schema.json) — adds `minitest`/`rspec`/`simplecov`/`bundler_audit` selections
- [Minitest reporter schema v1](schemas/minitest-reporter-v1.schema.json)
- [SimpleCov coverage ingestion schema v1](schemas/coverage-v1.schema.json)
- [Verification result schema](schemas/result-v1.schema.json) and [result example](examples/result-v1.json)

## Legal

- [Apache License 2.0](LICENSE)
- [NOTICE](NOTICE)
- [Trademark policy](TRADEMARKS.md)

The software license and trademark policy are separate. Nothing in the current identity decision authorizes publication or claims trademark clearance.
