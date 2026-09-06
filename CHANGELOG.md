# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [1.8.2] — 2026-09-06

### Patch: unsurfaced-path focus pointer

- **Fix:** changed files matching no Rails surface or project area produced an
  empty Review Focus. They now yield one bounded `unmapped` entry (ranked
  last, paths capped at 10) in both JSON and console projections. Risk
  levels unchanged (no signal inflation). G3 MUST item; covered by unit
  tests and a black-box Lab scenario. No contract changes.

## [1.8.1] — 2026-09-06

### Patch: lib test-candidate mapping

- **Fix:** `lib/` changes crashed targeted test selection (`candidate_path`
  called without `kind_dir`), breaking changed-scope verification planning on
  any `lib/` change. Found by the G3 validation campaign on a minitest
  project; covered by a regression test. No contract changes.

## [1.8.0] — 2026-09-06

### Agent Workflow & Review Orchestration

- **Review workflow (ADR 0021):** RailVerdict stays verifier, never actor. New `railverdict review show|observe|complete` over canonical services: `ReviewPacket` (bounded review context with deterministic/review lanes split), `ReviewObservation` validation (fresh binding proof, never approval), and `WorkflowReceipt` closure (`ready`/`blocked_by_gate`/`blocked_by_evidence`/`review_pending`). Readiness exits mirror the policy ladder (0/1/2/3).
- **Repair loop on both interfaces:** repair-packet plan extended with observed analyzers, test scope, requirements, and reasons (existing argv keys unchanged); new thin `repair verify --packet PATH` over the same Verifier (previously MCP-only).
- **MCP parity:** new `get_review_packet`, `verify_review_observation`, `create_workflow_receipt` (16 tools); inline documents normalized through JSON key space. SARIF stays findings-only.
- **Compatibility:** no config changes (1.7 sections drive everything); v1 contracts frozen; repair-packet-v1 extended additively (old packets validate); no new exits.
- **Validation:** ADR 0021, 37 new unit/adversarial/contract/BYOA/exit-ladder tests, 11 external black-box Lab scenarios (`RVLAB-WF-01..11`), exploratory 20-task agent experiment (packet arm 0/10 false successes vs 6/10 control, honestly labeled non-generalizable), foundation validator migrated to twenty-one ADRs.

## [1.7.0] — 2026-09-05

### Engineering Policy & Review Governance

- **Engineering policy (config 1.7, ADR 0020):** optional `engineering_policy` section turns 1.6 change facts into deterministic requirements — forbid new findings by severity, changed-lines coverage minimum, per-surface required analyzers, FULL verification scope, and human-review requirements. Each requirement carries id, trigger, status (`satisfied`/`violated`/`unavailable`/`not_applicable`/`review_required`), evidence, reason codes, and provenance. Decision precedence: `violated` → `FAIL`, `unavailable` → `INCOMPLETE`, pending review → `REVIEW_REQUIRED`, else mirror the gate.
- **Gate authority untouched:** `GateResult` v1, `check`/`pr` exits, and JSON shapes are unchanged; configs 1–1.6 behave identically (every configured rule `not_applicable`). A pending review is exposed as `REVIEW_REQUIRED`, never as silent `PASS`, analyzer `FAIL`, or fabricated approval.
- **CLI:** new `railverdict policy [--receipt PATH] [--handoff PATH]` (console/JSON) with exits 0/1/2/3 (`REVIEW_REQUIRED` is 3; unknown exits fail closed for old consumers). Receipts/handoffs report `policy_drift` by digest without relabeling v1 documents.
- **MCP parity:** new `get_engineering_policy` tool (13 tools) over the same canonical service; SARIF stays findings-only by design.
- **Compatibility:** schemas `configuration-v1.7` and `engineering-policy-v1` (version-dispatched, closed, bounded); v1 contracts frozen; old receipts never satisfy rules that did not exist when produced.
- **Validation:** ADR 0020, 46 new unit/adversarial/contract/exit-ladder tests, 15 external black-box Lab scenarios (`RVLAB-POL-01..15`), foundation validator migrated to twenty ADRs.
## [1.6.0] — 2026-09-05

### Rails Change Intelligence & Reviewer Focus

- **Change Intelligence (PR Intelligence v1.1):** `railverdict pr` and `get_pr_intelligence` now project the same canonical model extended with Rails change surfaces (19 path-convention surfaces, each with evidence and `detected`/`inferred`/`mixed` tier), explainable review risk (`LOW`/`MEDIUM`/`HIGH`/`CRITICAL` with reason codes), executed verification scope (`FULL` vs `TARGETED` with selected files and fallback reasons), missing-evidence facts (`unknown` stays unknown), and an ordered Review Focus list. Gate authority untouched: intelligence is read-only over the decided `GateResult`.
- **Project review policy (config 1.6):** optional `review.sensitive_paths` (named glob areas, e.g. financial) and `review.risk` per-surface level overrides; 1.5 configs keep working.
- **CLI UX:** `pr` console output adds Review risk, Sensitive surfaces, Verification scope, Missing evidence, and Reviewer focus sections (evidence-bounded: titles only, full paths stay in JSON); `check --changed` console appends a compact risk/surfaces/focus summary.
- **MCP parity:** no new tools; `get_pr_intelligence` returns the same canonical 1.1 document as the CLI.
- **Validation:** 17 new unit tests, in-repo black-box lab (`lab/change_intelligence.rb`, 6 scenarios incl. 2 adversarial), 10 external lab scenarios (`RVLAB-CI-01..10`, all PASS), 6 IntegrarPlus dogfood cases, and a coding-agent A/B experiment.

## [1.5.0] — 2026-08-27

### Rails-Native Adoption & CI Efficiency

- **Native Brakeman Analyzer:** Built-in `brakeman` adapter (`RailVerdict::Analyzers::Brakeman`) supporting Brakeman 8.x JSON output, exit code reconciliation (0 clean, 3 warnings, fail-closed on crashes/timeouts), severity/confidence mappings, doctor hints, init scaffolding, and `.railverdict.yml` configuration schema 1.5.
- **Targeted Test Verification (`RailVerdict::TestSelection`):** Intelligent Rails-aware test candidate resolution for RSpec and Minitest; isolates and executes only the tests covering modified models, controllers, services, policies, components, jobs, mailers, and helpers; explicit `test_scope: "targeted"` vs `test_scope: "full"` reporting.
- **Conservative Safe Fallback Rules:** Automatically falls back to full test suite verification when changes touch shared infrastructure (`spec_helper`, `rails_helper`, `test_helper`, `support/**`, `Gemfile`, `config/**`, `db/schema.rb`, migrations, base classes, or unmapped source code).
- **Per-Analyzer Tiered Evidence Reuse (`RailVerdict::VerificationPlan`):** Reuses valid static analysis evidence (RuboCop, Brakeman, BundlerAudit) from verified handoffs while allowing dynamic test suites (RSpec, Minitest) to execute freshly, newly synthesizing the combined `GateResult` with zero trust degradation.
- **Finding ID & Rule ID Normalization:** Normalized finding rule IDs across RSpec (`example:...`), Minitest (`test:...`), and BundlerAudit (`advisory:...`), preventing redundant double-prefixed IDs in console, SARIF, and GitHub annotations reporters while maintaining 100% backward compatibility with legacy baseline fingerprints.
- **Database Consistency Deferral:** Rigorous discovery and deferral of `database_consistency` due to lack of a stable machine JSON contract and runtime DB mutations, strictly upholding the invariant: `NO STRUCTURED CONTRACT = NO FAKE STRUCTURED ANALYZER`.
- **Validation Lab 5.0 Catalog:** Expanded external test catalog with 18 new scenarios covering Brakeman, targeted test scopes, safe fallbacks, and tiered reuse (136 total scenarios, 100% PASS).
- **Real-World Dogfooding:** Verified against IntegrarPlus (3,900+ specs), demonstrating a 99.4% RSpec runtime reduction (from ~146.8s down to 0.80s) on isolated model changes.

## [1.4.0] — 2026-08-26

### Agent Handoff & Evidence Reuse

- **Verification Handoff v1:** deterministic bounded `256 KiB` transport envelope (`handoff-v1`, `handoff_id = sha256(canonical_json)`) carrying `receipt` + normalized `evidence_set` + `evidence_provenance` + `source_scope`; portable, offline, file/process/clone/CI-job usable, fail-closed, no signatures/PKI/Sigstore (per 1.x trust model, see ADR 0019).
- **Canonical Evidence Reuse Evaluator:** single `Reuse.evaluate(handoff, current_identity, current_contract)` used by CLI, MCP, and CI; `RECEIPT_FRESH != EVIDENCE_REUSABLE`; whole-set reuse only (`PER_ANALYZER_REUSE_DEFERRED`); per-analyzer predicates (RuboCop reusable, RSpec/Minitest not, SimpleCov coupled, bundler-audit DB-dependent); `REUSABLE` reconstructs `Finding`/`AnalyzerResult` and re-derives `GateResult` via current `baseline`/`waivers`/`policy` (same canonical pipeline).
- **CLI:** `railverdict handoff create|inspect|verify` and `railverdict check --handoff PATH` (execution avoidance proven: `rubocop` reuses without `rspec` execution, `VERIFICATION_REQUIRED` falls back to full verification); machine JSON exposes `handoff_valid`, `receipt_fresh`, `decision`, `reasons`.
- **MCP:** `create_handoff`, `inspect_handoff`, `verify_handoff` delegate to same services; CLI/MCP parity, `TOCTOU` guard (`identity_before == identity_after`), bounded parsing, no path escape.
- **Trust invariants 1-25 frozen** (`docs/release/1.4-trust-invariants.md`) and ADR 0019; `docs/agent-handoff.md` documents three questions (Receipt vs Evidence vs Gate).

## [1.3.0] — 2026-08-25

### Verification Freshness & Trust Completion

- **Verification Environment Identity v1:** canonical `VerificationEnvironment` over `railverdict_version`, `ruby_engine`, `ruby_version`, and relevant enabled analyzer versions (sorted, `unknown`-excluded) with deterministic `environment_digest`. Excluded: hostname, PID, time, absolute path, machine ID, platform – preserves clone portability ([ADR 0018](docs/adr/0018-verification-environment-identity.md)).
- **Canonical Freshness Evaluator:** single `Receipt.validate_freshness` / `Receipt.evaluate` that independently re-observes repository state and environment via `VerificationIdentity`; CLI and MCP delegate to it. Trust Invariant Zero enforced – receipt-provided values are never used as current observation.
- **Complete Public Receipt Verification:** `railverdict receipt verify` and MCP `get_verification_receipt` / `get_pr_intelligence` now automatically observe all freshness dimensions (ruby engine/version, analyzer versions via bounded version probes, 5s timeout, no suite execution) and fail-closed on `analyzer_version_unobservable`.
- **MCP Cache Hardening:** cache now stores `state_digest` + `environment_digest`; `fresh_entry` and `verification_state` re-observe environment with lightweight probes; custom `config`/`baseline`/`waivers` paths use the same `Check.effective_input_paths` as CLI; analyzer execution count remains one per `verify`.
- **Repair Boundary Hardening (closes RVLAB-16):** `Repair::Verifier` keeps `gate` honest but `overall_status` is `boundary_changed` whenever `verification_boundary_changed` is non-empty; waiver/baseline/config cheating can never be `successful` even if `gate` is `PASS`. `gate` remains the current policy evaluation, not falsified.
- **Portable Verification:** equivalent clones (same HEAD, index, worktree, config, baseline, waivers, relevant environment) validate the same receipt as `fresh` regardless of absolute path or process; `receipt_id` and digests are deterministic and clone-independent.
- **Receipt Schema:** `verification-receipt-v1` now allows optional `environment.ruby_engine`; `sorted_analyzer_versions` excludes `unknown` so receipts are not polluted; `1.2` receipts without `ruby_engine` remain valid but are `stale` under the stronger check (prefer `stale` over `invalid`).
- **Lab 1.3 Expansion:** 37 new external scenarios (freshness, environment, portability, MCP, repair, receipt) – total 118 scenarios, all PASS. `RVLAB-16` now PASS (waiver cheat exposed as `boundary_changed` with `gate: PASS`).

### Compatibility

- Ruby `>= 3.3`; `receipt verify` now automatically checks environment – 1.2 receipts are still structurally valid but will be `stale` or `unavailable` when the stronger environment check applies, which is intentional.

## [1.2.0] — 2026-08-24

### Hardening (dogfooding — 2026-08-24)

- **Native SimpleCov support:** `simplecov` now accepts genuine SimpleCov JSON (`simplecov_json_formatter` shape: `meta.simplecov_version`, `coverage: { "path": { "lines": [...] } }` with `ignored` → `nil`, absolute-to-relative path normalization, deterministic ordering) and normalizes it to the internal canonical coverage representation. Existing `coverage-v1` (`version`/`timestamp`/`files`) remains fully supported; no consumer conversion required. Malformed / unsupported / oversized / stale semantics are preserved (`truncated`/`malformed`/`unsupported`/`parse_failed`), and `changed_line_coverage` works on normalized native evidence.
- **Finding message safety:** every `Finding` now carries a deterministic bounded valid non-empty UTF-8 `message` via a single canonical `Shared.normalize_finding_message` path (nil/empty/whitespace/ANSI/control/null-byte/invalid-UTF-8/oversized all map to `"<analyzer> reported a finding without a message"` or a sanitized truncated value). Analyzer adapters (RuboCop, RSpec, Minitest, bundler-audit) use the shared path; `Check` guards the analyzer→GateResult boundary so malformed messages never bypass `GateResult` JSON serialization (no raw stack trace).
- **Unknown tool version canonicalization:** `AnalyzerResult` `tool_version` remains optional, but baseline/receipt/MCP identity now canonicalize `nil`/empty to `"unknown"` (`Shared.canonical_tool_version`). `Baseline.create` writes deterministic `"unknown"` entries, `Baseline.read` of older `"unknown"` baselines remains compatible,Receipt `sorted_analyzer_versions` and `MCP::Cache` use the same canonicalization; digests stay deterministic and fingerprints unchanged.
- **Large analyzer output:** `ProcessRunner` now clamps `max_stdout_bytes` to `MAX_SAFE_STDOUT_BYTES` (64 MiB) and raises the RSpec default to 16 MiB (RuboCop 8 MiB) via analyzer-specific limits. Truncation is still bounded but now large legitimate RSpec JSON (e.g. 8k examples) succeeds where safe; exceeding the bound yields a controlled `truncated` `AnalyzerResult` → `INCOMPLETE` exit 2, never a truncated-JSON parse-as-success or crash. `Check` additionally fail-closes any unexpected analyzer exception to a `malformed` result.

### Highlights

- **Agent Verification Protocol:** deterministic contracts that bind verification evidence to the exact observable repository state that was verified, consumable by humans, CI, and coding agents.
- **Repository State Identity v1:** one canonical `sha256:` identity over HEAD, the Git index snapshot (`ls-files -s`), the worktree-vs-index content delta (porcelain v2 + per-path content hashes), and resolved configuration/baseline/waiver digests; bounded, path-independent, mtime-insensitive, fail-closed on unavailable state ([ADR 0016](docs/adr/0016-canonical-repository-state-identity.md)).
- **Verification Receipt v1:** closed versioned schema with deterministic `receipt_id = sha256:<64hex>` over canonical identity fields (environment, state components, mode/changed scope, stable GateResult projection, PR Intelligence stable-projection digest, optional repair packet linkage); volatile data excluded by design; receipts exist for PASS/WARN/FAIL/INCOMPLETE ([ADR 0017](docs/adr/0017-verification-receipts.md)).
- **Snapshot guard:** guarded executions capture pre/post repository state; mutation during verification fails receipt issuance closed (`repository_changed_during_verification`).
- **Freshness CLI:** `railverdict receipt create|verify` with `fresh/stale/invalid/unavailable` verdicts, deterministic stale reasons, and gate-mirroring exit semantics (0 PASS/WARN fresh, 1 FAIL fresh, 2 otherwise, 130 interrupt).
- **MCP integration:** two new read-only tools `get_verification_receipt` / `get_pr_intelligence`; cache refactored onto the shared Repository State Identity; one verify executes analyzers exactly once and derived tools never rerun them; stale cached evidence is refused explicitly (`verification_required`).
- **Repair lifecycle:** RepairPacket v1 stays immutable; receipts link via optional `repair.packet_id`; baseline/waiver/config manipulation after a FAIL receipt turns it stale and surfaces as a repair boundary change.

### Trust model

Verification Receipts are deterministic integrity records — NOT signed attestations. `receipt_id` proves content identity, never authorship; an actor able to modify the whole receipt and recompute its SHA-256 can fabricate a self-consistent document. When adversarial forgery is in scope, a trusted CI/orchestrator remains the trust anchor and must independently execute RailVerdict.

### Compatibility

- Ruby `>= 3.3`; existing commands (`init`, `doctor`, `check`, `pr`, `baseline create`, `findings`, `explain`, `investigate`, `repair`, `mcp serve`), GateResult/Finding/baseline/waiver/RepairPacket-v1/PR-Intelligence-v1 schemas, configuration versions 1–1.5, stdout/stderr discipline and exits unchanged.
- New public contracts: `schemas/verification-receipt-v1.schema.json`, `schemas/receipt-validation-v1.schema.json`.

## [1.0.0] — 2026-08-19

### Highlights

- **Deterministic verification:** `railverdict check` (console / JSON / SARIF 2.1.0), `findings`, `doctor`, `init`, `baseline create`, `repair`; exits 0 PASS/WARN / 1 FAIL / 2 INCOMPLETE / 130 interrupt; stdout single-doc JSON, diagnostics on stderr.
- **Fail-closed evidence:** required incomplete evidence never becomes PASS (unavailable, unsupported, timed_out, signaled, failed, parse_failed, truncated, malformed).
- **Five analyzers (external, target-owned):** RuboCop `>= 1.72, < 2` (+ `rubocop-rails >= 2, < 3` provenance), Minitest `>= 5, < 7` (owned reporter `minitest-reporter-v1`), RSpec `>= 3.13, < 4`, SimpleCov public `coverage.json` v1, bundler-audit `>= 0.9.3, < 1`.
- **Baselines & no-new-debt:** fingerprint v1 `sha256:` over `{analyzer, rule_id, path, message}`, atomic versioned baselines, comparison (`introduced`/`existing`/`resolved`/`changed`/`moved`), policy `advisory` / `no_new_debt` / `strict`, exact-fingerprint waivers with UTC expiry.
- **Git changed scope:** `check --changed --base REV` with merge-base, NUL-safe diffs, rename awareness; shallow/missing base → INCOMPLETE.
- **SARIF / JSON / annotations:** SARIF 2.1.0 and annotation projections are pure `GateResult` projections.
- **Rails context (bounded, no boot):** bounded `rails_context` with confidence + provenance.
- **Optional AI (advisory, off by default):** dual-gate `ai.enabled && ai.remote.enabled`, `trust: redacted` default, secret detection/redaction fail-closed, budgets, cache; AI never changes gate.
- **RepairPacket v1:** deterministic, bounded 256 KiB, `packet_id sha256:`, `Verifier` classification `fixed|still_present|changed|moved|regressed|incomplete`.
- **MCP stdio 2025-11-25:** `mcp ~> 1.2.0`, 7 read-only tools (`verify`, `list_findings`, `get_finding`, `build_repair_packet`, `verify_repair`, `explain`, `investigate`); mutex-serialized verification; same `GateResult`/`Finding`/`RepairPacket` contracts.
- **Security/privacy:** argv-only exec, minimal env, bounded I/O, monotonic timeout, pgroup cleanup, secret isolation, English-only fixtures, information firewall.

### Compatibility

- Ruby `>= 3.3`; Rails target context `>= 8.0`; schemas Draft 2020-12 independent versioning; unknown versions → explicit migration.
- Supported analyzer ranges per `docs/analyzers.md`; fixture-verified at 2026-08-16/17 versions.

### Known limitations

- No Brakeman support (HOLD pending legal/product decision).
- No OS sandbox; subprocess containment is argv/env/bounds/pgroup only.
- No full semantic code graph; Rails context is bounded + provenance-labeled.
- AI does not control GateResult; no autonomous source mutation.
- Qualified trademark/name review (including Brazil INPI) NOT PERFORMED — NON-BLOCKING BY MAINTAINER DECISION 2026-08-19 (Pedro Dalben) for initial open-source publication; recommended but not mandatory; preliminary screen 2026-08-19 found no obvious conflict — NOT LEGAL CLEARANCE; no registration or clearance claimed.
- Private-pattern corpus scan requires external maintainer input (`FOUNDATION_PRIVATE_PATTERNS`).

### Artifact

- Gem `rail_verdict` 1.0.0 built once from the `v1.0.0` tag; SHA-256 recorded in release workflow; installed/tested artifact is the published artifact (Trusted Publishing / OIDC, no long-lived key).

## [1.0.1] — 2026-08-21

### Compatibility hardening

- **Configurable analyzer execution timeout:** per-analyzer `timeout_seconds` (1..3600) on `rubocop`, `minitest`, `rspec`, `simplecov`, and `bundler_audit` via `.railverdict.yml` `version: 1.5` (new compatible schema version). Default remains 30 seconds; existing `version: 1`..`1.4` configs continue to load. Invalid `timeout_seconds` (non-integer, zero, negative, >3600) fails configuration validation. Timeout remains fail-closed operational failure / `INCOMPLETE` (`timed_out`, exit 2 when required).
- **Robust bundler-audit JSON parsing:** `bundler_audit` now robustly extracts the JSON document when informational/download notices precede the payload on stdout (e.g. `Downloading ruby-advisory-db ...`), without depending on pristine JSON. Exit-code handling, `parse_failed`/`malformed`/missing-JSON distinctions, trailing-garbage rejection, and deterministic parsing are preserved; malformed output still fails closed.

## [1.1.0] — 2026-08-23

### Added
- Deterministic PR Intelligence v1 via `railverdict pr` (console/JSON), using one changed-scope verification run and preserving `GateResult` authority.
- SARIF output via `railverdict check --format sarif` (pure `GateResult` projection, `version: 2.1.0`).
- MCP stdio adapter: `railverdict mcp serve` with 7 read-only tools (`verify`, `list_findings`, `get_finding`, `build_repair_packet`, `verify_repair`, `explain`, `investigate`).

### Changed
- Gem packaging: `spec.files` discovered via gemspec directory with gem-relative normalization; includes `exe/railverdict-minitest-reporter.rb`. CWD-independent build.
- License: project license is **MIT** (see `LICENSE`); historical Apache-2.0 ADR marked superseded.

## [0.1.0] - 2026-08-17

### Added
- Deterministic core: `railverdict check` (console/json), `findings`, `doctor`, `init`, `baseline create`; exits 0/1/2/130; stdout single-doc JSON, diagnostics on stderr.
- Analyzers (external, target-controlled): RuboCop (+ rubocop-rails provenance), Minitest (owned reporter), RSpec, SimpleCov (public `coverage.json` v1), bundler-audit.
- Fingerprint v1 (`sha256:` over `{analyzer, rule_id, path, message}`), versioned baseline (atomic write), no-new-debt comparison, exact-fingerprint waivers.
- Git changed scope: `check --changed --base REV` with deterministic `merge-base` / NUL-safe diffs; `INCOMPLETE` on missing/shallow base.
- Rails-aware context: bounded `rails_context` (`detected`/`scope`/`entries`) with confidence + provenance.
- Optional AI: dual-gate opt-in (`ai.enabled && ai.remote.enabled`), secret detection/redaction (fail-closed), bounded context, budgets, cache.
- Repair: deterministic `RepairPacket v1` (`packet_id sha256:`, bounded 256 KiB), `repair` CLI, `Verifier` classification.

### Security
- Fail-closed: required incomplete evidence never becomes `PASS` (CLI, `check --changed`, baseline, repair, MCP).
- Process boundary: argv-exec only, minimal env, bounded I/O, monotonic timeout, pgroup termination.
- Information firewall: synthetic-only fixtures, English-only policy; external private-pattern corpus scan surfaces enumerated (`NOT RUN` until supplied — publication blocker).
