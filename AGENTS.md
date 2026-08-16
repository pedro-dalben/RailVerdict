<!-- GSD:project-start source:PROJECT.md -->

## Project

**RailVerdict**

RailVerdict is a fully open-source, local-first verification framework for Ruby on Rails applications. It collects evidence from established quality tools, normalizes that evidence into stable findings, applies project policy and historical baselines, and returns a deterministic merge gate that humans, CI systems, and coding agents can consume.

Phase 0 rejected the working name LineClear after finding avoidable software, GitHub, and trademark collision risk. The selected identity is RailVerdict: gem `rail_verdict`, Ruby namespace `RailVerdict`, CLI `railverdict`, and configuration `.railverdict.yml`. Publication remains blocked until the documented jurisdictional and qualified trademark review is complete. The product is not a SaaS and does not depend on accounts, telemetry, hosted services, or AI.

**Core Value:** Given the same repository state, configuration, analyzer versions, and baseline, RailVerdict must produce the same evidence-backed PASS, WARN, or FAIL decision regardless of whether AI is configured.

### Constraints

- **Language**: Repository content is English-only except explicit internationalization fixtures — public contracts and collaboration must not mix languages.
- **License**: Apache License 2.0 with separate NOTICE and trademark policy — no custom source-availability restrictions.
- **Architecture**: Deterministic evidence and policy own the default gate — AI cannot reinterpret objective failures.
- **Adoption**: Existing debt can enter a versioned baseline; new changes cannot silently worsen it — no-new-debt is the recommended mode.
- **Execution**: Core behavior works offline and invokes external tools with argument arrays, bounded I/O, timeouts, and explicit failures.
- **Privacy**: Remote AI is explicit opt-in, context-minimized, inspectable, secret-scanned, and fail-closed.
- **Security**: Repository text and fork contributions are untrusted; privileged credentials cannot be exposed to untrusted code.
- **Contracts**: Findings, configuration, JSON results, baselines, fingerprints, analyzer APIs, reporters, exit codes, and future AI/MCP adapters are versioned before 1.0 stability promises.
- **Scope**: One Ruby gem until a demonstrated need justifies separation; no full semantic code graph in the MVP.
- **Provenance**: Only synthetic public examples; a repository-wide private-information scan blocks the first public release.

<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->

## Technology Stack

## Evidence Convention

- **Verified fact — MEDIUM:** confirmed against a current official project, RubyGems, Ruby, Rails, or GitHub source. The confidence is MEDIUM because the research provider's confidence classifier caps cross-checked web findings at that level.
- **Recommendation — MEDIUM:** an implementation choice derived from the verified facts and RailVerdict's stated product constraints.
- Versions in this document are the versions observed on 2026-08-16, not unbounded promises of future compatibility.

## Executive Recommendation

## Supported Ruby and Rails Policy

### Proposed Baseline

| Surface | Verified upstream state | RailVerdict policy | Confidence |
|---|---|---|---|
| Ruby | Ruby 4.0 and 3.4 are in normal maintenance; Ruby 3.3 is in security maintenance with expected EOL on 2027-03-31; Ruby 3.2 reached EOL on 2026-04-01. [Ruby branch status](https://www.ruby-lang.org/en/downloads/branches/) | `required_ruby_version = ">= 3.3"`; CI on 3.3, 3.4, and 4.0. Drop an EOL series in the next documented minor release while pre-1.0. | Verified fact / recommendation — MEDIUM |
| Rails | Rails 8.0 and 8.1 require Ruby 3.2 or newer; Rails 7.2 requires Ruby 3.1 or newer. Rails bug-fix support lasts one year and security support two years after a minor release. [Rails upgrade guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html), [maintenance policy](https://guides.rubyonrails.org/maintenance_policy.html) | Support Rails `>= 8.0`; run adapter/fixture tests against the maintained 8.0 and 8.1 lines. Do not depend on Rails at runtime. | Verified fact / recommendation — MEDIUM |
| Analyzer tools | Each analyzer has its own release cadence and output contract. | Support version **ranges by upstream major**, test a current fixture inside each range, capture the actual executable version in every report, and fail with an actionable unsupported-version result rather than guessing. | Recommendation — MEDIUM |

### CI Matrix

| Lane | Ruby | Rails | Purpose |
|---|---:|---:|---|
| Core minimum | 3.3 | none | Enforce the gem's Ruby floor and stdlib-only behavior |
| Core current | 3.4 | none | Main development lane |
| Core newest | 4.0 | none | Catch forward-compatibility regressions |
| Rails lower boundary | 3.3 | 8.0 | Verify the minimum supported Rails context |
| Rails current boundary | 4.0 | 8.1 | Verify the newest supported context |

## Recommended Stack

### Core Distribution and Development

| Technology | Observed version | Purpose | Decision and rationale | Confidence |
|---|---:|---|---|---|
| Ruby | 3.3 minimum; test 3.3/3.4/4.0 | Runtime | Native process, JSON, YAML, hashing, filesystem, and CLI APIs are sufficient for the core. | Recommendation — MEDIUM |
| RubyGems | shipped with supported Ruby; current client policy follows Ruby | Build/install metadata | Use one `.gemspec`, one executable, and standard gem artifacts. The official guide documents the conventional layout and build flow. [RubyGems gem guide](https://guides.rubygems.org/make-your-own-gem/) | Verified fact / recommendation — MEDIUM |
| Bundler | 4.0.18 | Dependency resolution and development lock | Bundler 4.0.18 requires Ruby >= 3.2 and is MIT licensed. Commit the development `Gemfile.lock`; do not force a precise Bundler version on gem consumers. [RubyGems: Bundler](https://rubygems.org/gems/bundler) | Verified fact / recommendation — MEDIUM |
| Rake | 13.4.2 | Build, test, documentation, and release checks | Keep tasks thin wrappers around standard commands; no custom task framework. [RubyGems: Rake](https://rubygems.org/gems/rake) | Verified fact / recommendation — MEDIUM |
| Minitest | 6.0.6 for RailVerdict's suite | Unit/integration testing | MIT licensed, Ruby >= 3.2, small, and adequate for a gem. Target-project Minitest compatibility remains `>= 5, < 7`. [RubyGems: Minitest](https://rubygems.org/gems/minitest) | Verified fact / recommendation — MEDIUM |
| RDoc + Markdown | RDoc 8.0.0 | API and user documentation | Maintain README, configuration/schema reference, and examples as Markdown; use RDoc for public Ruby APIs. RDoc is dual-licensed Ruby/GPL-2.0-only. Do not add YARD until an actual documentation requirement exceeds RDoc. [RubyGems: RDoc](https://rubygems.org/gems/rdoc) | Verified fact / recommendation — MEDIUM |

### Runtime Dependency Budget

| Library | Version policy | Purpose | When to add | Confidence |
|---|---|---|---|---|
| `json_schemer` | `>= 2.5, < 3` | JSON Schema 2020-12 validation | Add as the single intentional third-party runtime dependency when RailVerdict validates its canonical report before writing it. Version 2.5.0 is MIT licensed, supports JSON Schema 2020-12, and requires Ruby >= 2.7. [RubyGems: json_schemer](https://rubygems.org/gems/json_schemer), [official repository](https://github.com/davishmcclurg/json_schemer) | Verified fact / recommendation — MEDIUM |

### Standard-Library Choices

| Need | Use | Explicitly avoid initially |
|---|---|---|
| CLI parsing | `OptionParser` | Thor or another command framework |
| Process execution | argument-array `Process.spawn` or `Open3`, with `IO.select` where needed | shell-string interpolation and implicit `/bin/sh` |
| JSON/YAML | `JSON`, safe `Psych` loading | ActiveSupport serialization |
| Identity/hash | `Digest`, `SecureRandom` | UUID or hashing gems |
| Paths/files | `Pathname`, `File`, `Tempfile`, atomic rename | storage abstraction layers |
| Timeouts/signals | `Timeout` only around bounded operations; explicit process-group termination | background job frameworks |

# rail_verdict.gemspec (policy excerpt)

# Add only when canonical report validation is implemented.

## Analyzer and License Registry

| Analyzer | Homepage / observed version | License and commercial-use consideration | Target-project install | Bundling decision | Supported-version approach | Machine output contract | Confidence |
|---|---|---|---|---|---|---|---|
| RuboCop | [Official repository](https://github.com/rubocop/rubocop), [RubyGems 1.89.0](https://rubygems.org/gems/rubocop) | MIT (`MIT`); permissive commercial use with notice obligations | `bundle add --group development rubocop --require false` | External; invoke through the target bundle | `>= 1.72, < 2`; fixture current 1.x and follow major-version compatibility policy. The floor aligns with the modern plugin API needed by Rails plugins. | Documented `--format json`; treat fields as an adapter contract and fixture-test them. [Formatter docs](https://docs.rubocop.org/rubocop/latest/formatters.html), [versioning](https://docs.rubocop.org/rubocop/latest/versioning.html) | Verified fact / recommendation — MEDIUM |
| rubocop-rails | [Official repository](https://github.com/rubocop/rubocop-rails), [RubyGems 2.36.0](https://rubygems.org/gems/rubocop-rails) | MIT (`MIT`); permissive commercial use with notice obligations | `bundle add --group development rubocop-rails --require false` | External RuboCop plugin; model as a RuboCop capability, not a second process adapter | `>= 2, < 3`, paired with compatible RuboCop `>= 1.72, < 2` | Uses RuboCop's JSON formatter; plugin identity and versions must be recorded. [Usage docs](https://docs.rubocop.org/rubocop-rails/latest/usage.html) | Verified fact / recommendation — MEDIUM |
| SimpleCov | [Official repository](https://github.com/simplecov-ruby/simplecov), [RubyGems 1.1.1](https://rubygems.org/gems/simplecov) | MIT (`MIT`); permissive commercial use with notice obligations | `bundle add --group test simplecov --require false` | External and loaded by the target test process | `>= 1, < 2`; require declared coverage schema v1; fixture current 1.x | Public `coverage.json` with versioned JSON Schema v1.0. Never parse `.resultset.json`, which the project documents as internal. | Verified fact / recommendation — MEDIUM |
| Undercover | [Official repository](https://github.com/grodowski/undercover), [RubyGems 0.8.5](https://rubygems.org/gems/undercover) | MIT (`MIT`); permissive commercial use with notice obligations | `bundle add --group test undercover --require false` | External; never a RailVerdict runtime dependency | If later adopted: `>= 0.8, < 1` with syntax-version and output fixtures | `--format json` exists, but no versioned public schema was found; it consumes SimpleCov data and overlaps RailVerdict's changed-line coverage calculation. | Verified fact / recommendation — MEDIUM |
| RubyCritic | [Official repository](https://github.com/whitesmith/rubycritic), [RubyGems 5.0.0](https://rubygems.org/gems/rubycritic) | MIT (`MIT`); permissive commercial use with notice obligations | `bundle add --group development rubycritic --require false` | External; never bundle its analyzer suite | If later adopted: `>= 5, < 6` with JSON fixtures | `--format json` exists, but no versioned schema was found. Output aggregates Reek, Flay, and Flog and overlaps style/complexity checks. | Verified fact / recommendation — MEDIUM |
| Brakeman | [Official repository](https://github.com/presidentbeef/brakeman), [RubyGems 8.0.6](https://rubygems.org/gems/brakeman) | Current distribution uses the custom [Brakeman Public Use License](https://github.com/presidentbeef/brakeman/blob/main/LICENSE.md), represented here as `LicenseRef-Brakeman-Public-Use`. The license permits analysis of the licensee's own software outside its definition of Commercial Use, but distribution as a commercial product/component or value-added service can require a commercial license. Older code has separate MIT terms described in [COPYING](https://github.com/presidentbeef/brakeman/blob/main/COPYING.md). Require explicit legal/product review; do not describe the current gem as MIT. | `bundle add --group development brakeman --require false` after explicit opt-in | Strictly external; never vendor or redistribute | If approved later: `>= 8, < 9`; retain exact version and license acknowledgement | JSON, JUnit, and SARIF are supported. Prefer SARIF or fixture-tested JSON for translation. [Options](https://brakemanscanner.org/docs/options/) | Verified fact / recommendation — MEDIUM |
| Prosopite | [Official repository](https://github.com/charkost/prosopite), [RubyGems 2.2.0](https://rubygems.org/gems/prosopite) | Apache-2.0 (`Apache-2.0`); commercial use allowed subject to license/notice terms | `bundle add --group development,test prosopite --require false` | External runtime instrumentation inside the target Rails process | If later adopted: `>= 2, < 3`; test against supported Rails/ActiveRecord pairs | No documented native versioned JSON format; findings are raised, logged, or sent to a custom logger through ActiveSupport SQL instrumentation. | Verified fact / recommendation — MEDIUM |
| bundler-audit | [Official repository](https://github.com/rubysec/bundler-audit), [RubyGems 0.9.3](https://rubygems.org/gems/bundler-audit) | GPL-3.0-or-later (`GPL-3.0-or-later`); commercial use is permitted by the GPL, while redistribution/modification carries copyleft and source obligations. External invocation avoids making it part of RailVerdict's distributed code. | `bundle add --group development bundler-audit --require false` | External executable and advisory database | `>= 0.9.3, < 1`; record tool version and advisory DB revision; refresh the DB explicitly, then run gates offline | `check --format json`; fixture-test because no versioned schema was found. | Verified fact / recommendation — MEDIUM |
| strong_migrations | [Official repository](https://github.com/ankane/strong_migrations), [RubyGems 2.8.0](https://rubygems.org/gems/strong_migrations) | MIT (`MIT`); permissive commercial use with notice obligations | `bundle add strong_migrations` in the target Rails application | External target-app integration; never run target migrations implicitly | If later adopted: `>= 2.8, < 3`; current gem requires Ruby >= 3.3 and ActiveRecord >= 7.2. [Gemspec](https://github.com/ankane/strong_migrations/blob/master/strong_migrations.gemspec) | No documented JSON contract; raises human-readable migration safety errors while migrations execute. | Verified fact / recommendation — MEDIUM |
| Minitest | [Official repository](https://github.com/minitest/minitest), [RubyGems 6.0.6](https://rubygems.org/gems/minitest) | MIT (`MIT`); permissive commercial use with notice obligations | Usually already present through the target test bundle; otherwise `bundle add --group test minitest` | External framework; RailVerdict may ship a tiny reporter/plugin in its own gem | `>= 5, < 7`; fixture latest 5.x and 6.x | No built-in JSON formatter contract. Use documented `AbstractReporter` callbacks to emit a RailVerdict-owned format. | Verified fact / recommendation — MEDIUM |
| RSpec | [Official monorepo](https://github.com/rspec/rspec), [RubyGems rspec-core 3.13.6](https://rubygems.org/gems/rspec-core) | MIT (`MIT`); permissive commercial use with notice obligations | `bundle add --group test rspec` or the target project's existing RSpec bundle | External framework | `>= 3.13, < 4`; RSpec 4 is still represented by prerelease artifacts, so add it only after a stable release and fixtures | Built-in `--format json --out <file>`; documented but not versioned as a JSON Schema, so fixture-test it. [JSON formatter docs](https://rspec.info/features/3-13/rspec-core/formatters/json-formatter/) | Verified fact / recommendation — MEDIUM |

## Phase 2 Analyzer Selection

### Strong Candidates

| Priority | Capability | Why now | Contract strategy | Confidence |
|---:|---|---|---|---|
| 1 | Minitest + RSpec test results | Test pass/fail and failure details are table stakes. Both are common Rails test frameworks and add no analyzer runtime to RailVerdict. | Own the Minitest reporter format; translate RSpec's documented JSON with version fixtures. | Recommendation — MEDIUM |
| 2 | RuboCop + optional rubocop-rails | Fast, maintained, high Rails value, documented JSON, and stable major-version policy. Treat rubocop-rails as capability metadata on the RuboCop run to avoid duplicate execution. | Invoke once through `bundle exec rubocop --format json`; capture loaded plugin versions and configuration digest. | Recommendation — MEDIUM |
| 3 | SimpleCov | Provides the stable raw coverage artifact needed for RailVerdict's “changed executable line” gate. Its public `coverage.json` schema is substantially safer than parsing internal state. | Accept schema v1 `coverage.json`; compute diff-line coverage inside RailVerdict; never parse `.resultset.json`. | Recommendation — MEDIUM |
| 4 | bundler-audit | Adds unique dependency-vulnerability signal with low application runtime cost and JSON output. | Separate explicit advisory DB refresh from offline evaluation; snapshot tool and DB revisions. | Recommendation — MEDIUM |

### Defer or Research

| Analyzer | Decision | Reason | Required research gate before adoption | Confidence |
|---|---|---|---|---|
| Undercover | Defer | Duplicates SimpleCov plus git-diff logic already central to RailVerdict; current syntax choices documented by the tool lag the newest Ruby lines. | Demonstrate unique detection value, Ruby 3.4/4.0 syntax coverage, and a fixture-stable JSON contract. | Recommendation — MEDIUM |
| RubyCritic | Defer | Composite score and bundled analyzers duplicate RuboCop/complexity signals and conflict with explicit policy-level evidence. | Define which raw findings are actionable without adopting the opaque aggregate score; fixture JSON across releases. | Recommendation — MEDIUM |
| Brakeman | Defer pending license/product decision | Technically strong Rails security coverage and structured output, but its current custom license is incompatible with an unqualified “permissive commercial-use analyzer registry” promise. | Written decision on allowed external use, disclosure text, and commercial distribution/service boundaries; then SARIF/JSON fixtures. | Recommendation — MEDIUM |
| Prosopite | Defer to runtime-evidence phase | Requires application boot, database activity, and SQL event instrumentation; lacks a native stable machine format. | Safe test command, isolation guarantees, timeout behavior, and a RailVerdict-owned logger protocol. | Recommendation — MEDIUM |
| strong_migrations | Defer; never auto-run | Its useful signal occurs during actual migration execution, which can mutate a database; output is human-oriented. | Disposable database strategy or an upstream non-mutating check mode plus a structured evidence contract. | Recommendation — MEDIUM |

## Adapter Contract Rules

## Publishing and Supply Chain

### Recommended Release Path

### Workflow Security Requirements

| Requirement | Rationale |
|---|---|
| No long-lived `GEM_HOST_API_KEY` | Trusted Publishing provides short-lived scoped credentials. |
| No publish job on pull requests or forks | Untrusted code must not reach an OIDC-capable release context. |
| Avoid `pull_request_target` for build/test of PR code | It can combine privileged base-repository context with untrusted changes. |
| Minimal `GITHUB_TOKEN` permissions | A release job needs no broad repository administration permissions. |
| `persist-credentials: false` when checking out for build-only jobs | Prevent accidental credential reuse by later steps. |
| Protected release environment | Adds approval and binds the trusted-publisher identity to the intended job. |
| Review action SHA updates | A moving tag is convenient but is not immutable; release workflows deserve explicit review. |
| Verify RubyGems provenance and checksum | RubyGems gem pages expose provenance for trusted-published releases; retain the release run URL in release evidence. |

## Alternatives Explicitly Rejected for the Initial Stack

| Category | Recommended | Rejected initially | Why |
|---|---|---|---|
| CLI | `OptionParser` | Thor | One executable with bounded commands does not justify a framework dependency. |
| Framework integration | Rails-free core and optional fixtures | Rails/ActiveSupport runtime dependency | RailVerdict analyzes repositories; it does not need to become a Rails engine. |
| Schema validation | `json_schemer` only when enforcement lands | Hand-rolled partial validator | Canonical JSON Schema 2020-12 is a real contract; partial validation creates false confidence. |
| Documentation | Markdown + RDoc | YARD/site generator | No identified requirement needs another tool or hosted documentation pipeline. |
| Analyzer installation | Target bundle, external processes | Vendored analyzers or a RailVerdict analyzer bundle | Avoids license coupling, version conflicts, large install footprint, and hidden behavior. |
| Coverage | SimpleCov public `coverage.json` + RailVerdict diff logic | SimpleCov `.resultset.json` or Undercover in Phase 2 | The public schema is versioned; internal result storage is not. |
| Release authentication | RubyGems Trusted Publishing | Stored API key or hand-managed signing certificate | Short-lived scoped OIDC credentials reduce secret management and match current RubyGems guidance. |
| Release automation | Narrow protected workflow | Automatic release from every merged version change | Publishing is irreversible enough to require a deliberate tag and approval boundary. |

## Installation Skeleton

# Runtime/development setup

# Standard project checks

# Build and test the distributable artifact before release

## Confidence and Open Questions

| Area | Confidence | Notes |
|---|---|---|
| Ruby/Rails support | MEDIUM | Official maintenance and upgrade guides support the baseline; the exact drop cadence is a project policy recommendation. |
| Packaging/development stack | MEDIUM | Based on current official RubyGems pages and guides; dependency versions must still be locked and tested when implementation starts. |
| Analyzer versions/licenses | MEDIUM | Cross-checked against current official repositories and RubyGems. Brakeman's custom license needs qualified legal review before product claims or distribution decisions. |
| Machine output | MEDIUM | Strongest for SimpleCov's versioned coverage schema and documented RuboCop/RSpec formats. Other JSON outputs require stored fixtures because no versioned schema was found. |
| Supply chain | MEDIUM | Current official RubyGems and GitHub guidance supports OIDC and immutable action references; the exact workflow must be reviewed against the then-current official action before first publication. |

- Confirm the final gem name and RubyGems namespace before configuring Trusted Publishing.
- Decide whether canonical-schema validation is mandatory in every CLI run or only at artifact boundaries; that determines when `json_schemer` becomes a runtime dependency.
- Validate the minimum supported RuboCop/plugin combination with real fixture bundles before publishing the adapter range.
- Obtain an explicit Brakeman license/product decision before listing it as a supported commercial integration.
- Recheck all current versions, license texts, and action SHAs at implementation and release time; this document is a dated snapshot.

## Sources

### Ruby, Rails, and Packaging

- [Ruby maintenance branches](https://www.ruby-lang.org/en/downloads/branches/)
- [Ruby releases](https://www.ruby-lang.org/en/downloads/releases/)
- [Rails maintenance policy](https://guides.rubyonrails.org/maintenance_policy.html)
- [Rails upgrade guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
- [RubyGems: Make your own gem](https://guides.rubygems.org/make-your-own-gem/)
- [RubyGems specification reference](https://guides.rubygems.org/specification-reference/)
- [RubyGems: Bundler 4.0.18](https://rubygems.org/gems/bundler)
- [RubyGems: Rake 13.4.2](https://rubygems.org/gems/rake)
- [RubyGems: RDoc 8.0.0](https://rubygems.org/gems/rdoc)
- [RubyGems: YARD 0.9.45](https://rubygems.org/gems/yard)
- [RubyGems: json_schemer 2.5.0](https://rubygems.org/gems/json_schemer)
- [json_schemer official repository](https://github.com/davishmcclurg/json_schemer)

### Analyzer Registry

- [RuboCop repository](https://github.com/rubocop/rubocop), [RubyGems](https://rubygems.org/gems/rubocop), [formatter docs](https://docs.rubocop.org/rubocop/latest/formatters.html), [versioning](https://docs.rubocop.org/rubocop/latest/versioning.html), [compatibility](https://docs.rubocop.org/rubocop/latest/compatibility.html)
- [rubocop-rails repository](https://github.com/rubocop/rubocop-rails), [RubyGems](https://rubygems.org/gems/rubocop-rails), [usage docs](https://docs.rubocop.org/rubocop-rails/latest/usage.html)
- [SimpleCov repository](https://github.com/simplecov-ruby/simplecov), [RubyGems](https://rubygems.org/gems/simplecov)
- [Undercover repository](https://github.com/grodowski/undercover), [RubyGems](https://rubygems.org/gems/undercover)
- [RubyCritic repository](https://github.com/whitesmith/rubycritic), [RubyGems](https://rubygems.org/gems/rubycritic)
- [Brakeman repository](https://github.com/presidentbeef/brakeman), [RubyGems](https://rubygems.org/gems/brakeman), [license](https://github.com/presidentbeef/brakeman/blob/main/LICENSE.md), [COPYING](https://github.com/presidentbeef/brakeman/blob/main/COPYING.md), [output options](https://brakemanscanner.org/docs/options/)
- [Prosopite repository](https://github.com/charkost/prosopite), [RubyGems](https://rubygems.org/gems/prosopite)
- [bundler-audit repository](https://github.com/rubysec/bundler-audit), [RubyGems](https://rubygems.org/gems/bundler-audit)
- [strong_migrations repository](https://github.com/ankane/strong_migrations), [RubyGems](https://rubygems.org/gems/strong_migrations), [gemspec](https://github.com/ankane/strong_migrations/blob/master/strong_migrations.gemspec)
- [Minitest repository](https://github.com/minitest/minitest), [RubyGems](https://rubygems.org/gems/minitest)
- [RSpec repository](https://github.com/rspec/rspec), [rspec-core RubyGems](https://rubygems.org/gems/rspec-core), [JSON formatter docs](https://rspec.info/features/3-13/rspec-core/formatters/json-formatter/), [formatter API](https://rspec.info/documentation/3.13/rspec-core/RSpec/Core/Formatters.html)

### Publishing and Supply Chain

- [RubyGems Trusted Publishing](https://guides.rubygems.org/trusted-publishing/)
- [Official rubygems/release-gem action](https://github.com/rubygems/release-gem)
- [RubyGems MFA requirement opt-in](https://guides.rubygems.org/mfa-requirement-opt-in/)
- [GitHub Actions secure-use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [GitHub artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)
- [ruby/setup-ruby official action](https://github.com/ruby/setup-ruby)

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
