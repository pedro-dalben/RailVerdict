---
phase: 0
slug: product-naming-and-legal-foundation
status: ready-for-verification
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-16
updated: 2026-08-16
---

# Phase 0 — Validation Strategy

> Per-phase validation contract for the documentation, legal boundaries, draft schemas, and roadmap foundation. This validates repository claims and structure; it does not provide legal clearance or complete private-provenance evidence.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | One repository validation script using installed Ruby/Python standard tooling and the environment-provided Python `jsonschema` validator |
| **Config file** | none — Wave 0 adds only `script/validate-foundation` |
| **Quick run command** | `script/validate-foundation <relevant-subcheck> && git diff --check` |
| **Full suite command** | `script/validate-foundation whitespace && script/validate-foundation && git diff --check` |
| **Estimated runtime** | under 10 seconds, excluding manual legal, security, and provenance review |

The validator is Phase 0 documentation tooling, not the RailVerdict product CLI. It shares no product namespace, installs no package, accesses no network, and creates no gem or application scaffold.

---

## Sampling Rate

- **After every task commit:** Run the subcheck named by the task plus `git diff --check`.
- **After every plan wave:** Run `script/validate-foundation whitespace && script/validate-foundation && git diff --check`.
- **Before independent phase verification:** The full automated suite must be green and unresolved manual publication gates must be recorded accurately.
- **Max feedback latency:** 10 seconds for automated checks.

---

## Per-Task Verification Map

These are the sixteen task IDs actually executed by the seven Phase 0 plans.

| Task ID | Plan | Wave | Requirement owner | Threat Ref | Secure behavior | Test type | Automated command | File exists | Status |
|---------|------|------|-------------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 00-01-01 | 01 | 1 | FND-01, FND-02, FND-03 | T-15 | Fourteen dated name surfaces, one identity map, and unresolved review without clearance claims | structure + manual legal | `script/validate-foundation identity links` | ✅ | ✅ automated; publication review pending |
| 00-01-02 | 01 | 1 | FND-04 | T-15 | Canonical Apache-2.0, factual NOTICE, and separate non-restrictive trademark policy | checksum + text + manual legal | `script/validate-foundation legal links` | ✅ | ✅ automated; publication review pending |
| 00-02-01 | 02 | 1 | FND-07 | T-15 | `README.md` owns public navigation; product and philosophy make no implementation or clearance claim | structure + links | `script/validate-foundation identity links language` | ✅ | ✅ green |
| 00-02-02 | 02 | 1 | FND-07, FND-13 | T-16 | Four one-way layers and proposed-not-present one-gem structure retain authority boundaries | structure + negative assertion | `script/validate-foundation links no-production` | ✅ | ✅ green |
| 00-03-01 | 03 | 1 | FND-05 | T-12, T-15 | Eleven external analyzer rows expose license, output, failure, disposition, and blockers | exact table parser | `script/validate-foundation analyzers links` | ✅ | ✅ automated; Brakeman HOLD pending |
| 00-03-02 | 03 | 1 | FND-06 | T-15 | Ruby/Rails lanes remain proposals until future fixtures pass | structure | `script/validate-foundation analyzers links` | ✅ | ✅ green |
| 00-04-01 | 04 | 1 | FND-09 | T-02, T-03 | Draft 2020-12 schemas validate safe synthetic JSON/YAML and reject root/nested unknowns and gate authority | schema contract | `script/validate-foundation schemas` | ✅ | ✅ green |
| 00-04-02 | 04 | 1 | FND-10 | T-01, T-04 | Five exact draft CLI surfaces preserve ordering, stream separation, reporter purity, and exits | exact table parser | `script/validate-foundation contracts links` | ✅ | ✅ green |
| 00-05-01 | 05 | 1 | FND-11 | T-01–T-16 | `SECURITY.md` keeps assets, adversaries, boundaries, HIGH controls, residual limits, ASVS mapping, and owners explicit | structure + manual security | `script/validate-foundation security links` | ✅ | ✅ automated; manual sufficiency review pending |
| 00-05-02 | 05 | 1 | FND-12 | T-14 | Synthetic/English scope, external private corpus, non-echoing reports, and truthful surface states | automated scope + manual provenance | `script/validate-foundation language provenance security` | ✅ | ✅ automated; private corpus not run |
| 00-06-01 | 06 | 1 | FND-08 | T-01, T-08 | ADRs 0001–0005 preserve deterministic authority, external execution, Finding, schemas, and fingerprints | exact ADR parser | `script/validate-foundation adrs links` | ✅ | ✅ green |
| 00-06-02 | 06 | 1 | FND-08 | T-08, T-09, T-11 | ADRs 0006–0010 preserve no-new-debt, advisory AI, remote opt-in, GitHub, and CLI/JSON boundaries | exact ADR parser | `script/validate-foundation adrs links` | ✅ | ✅ green |
| 00-06-03 | 06 | 1 | FND-08 | T-12, T-14, T-15 | ADRs 0011–0015 preserve MCP, license review, firewall, Apache-2.0, and trademark boundaries | exact ADR parser + manual legal | `script/validate-foundation adrs legal links` | ✅ | ✅ automated; publication review pending |
| 00-07-01 | 07 | 2 | FND-14 | T-00-22, T-15 | All 85 v1 IDs map once across ordered Phases 0–9; foundation completion and publication remain distinct | exact roadmap parser | `script/validate-foundation roadmap links` | ✅ | ✅ green |
| 00-07-02 | 07 | 2 | FND-01–FND-14 | T-00-23, T-00-24 | One fixed-argv offline validator owns every named subcheck, non-echoing provenance, and no-production enforcement | integration | `script/validate-foundation` | ✅ | ✅ green |
| 00-07-03 | 07 | 2 | FND-01–FND-14 | T-00-25 | Nyquist map, validator-owned whitespace, planning state, and unresolved human gates converge truthfully | phase gate | `script/validate-foundation whitespace && script/validate-foundation && git diff --check` | ✅ | ✅ green; independent phase verification pending |

*Status: ✅ green/automated · publication or manual-review text records evidence that automation cannot supply.*

---

## Exact ADR Set

The `adrs` subcheck parses the exact fifteen final filenames, verifies each
Decision and Deferred Work owner, and checks the grouped topic anchors required
by `00-CONTEXT.md`. The locked context names decision topics rather than
requiring one topic per file; related topics may be grouped when the mapping is
explicit and no duplicate ADR set is created:

- `0001-deterministic-pass-fail.md`
- `0002-external-analyzer-execution.md`
- `0003-canonical-finding.md`
- `0004-versioned-schemas.md`
- `0005-fingerprint-baseline.md`
- `0006-no-new-debt.md`
- `0007-advisory-ai.md`
- `0008-remote-ai-explicit-opt-in.md`
- `0009-github-as-an-adapter.md`
- `0010-cli-and-json-canonical.md`
- `0011-mcp-as-an-adapter.md`
- `0012-third-party-license-review.md`
- `0013-information-firewall.md`
- `0014-apache-2-license.md`
- `0015-separate-trademark-policy.md`

---

## Wave 0 Requirements

- [x] `script/validate-foundation` — one offline repository validator with `schemas`, `links`, `identity`, `legal`, `analyzers`, `contracts`, `adrs`, `security`, `roadmap`, `language`, `provenance`, `whitespace`, and `no-production` subchecks.
- [x] `schemas/finding-v1.schema.json` and `schemas/configuration-v1.schema.json` — strict JSON Schema Draft 2020-12 contract drafts.
- [x] `examples/finding-v1.json` and `examples/configuration-v1.yml` — small synthetic examples validated from JSON and safely loaded YAML.
- [x] `schemas/result-v1.schema.json` and `examples/result-v1.json` — versioned AnalyzerResult/GateResult envelope with explicit incomplete evidence states.
- [x] External private-pattern input procedure — `FOUNDATION_PRIVATE_PATTERNS` points to a maintainer-controlled path outside Git; pattern values and matches are never printed.
- [x] Publication-gate record — qualified review, factual owner/contact details, and the external private corpus remain unresolved without being misreported as passed.
- [x] Validator-owned whitespace manifest — exact Phase 0 public artifacts reject trailing spaces/tabs and missing final newlines independently of Git state.

Wave 0 was marked complete only after `script/validate-foundation whitespace` and the full default validator passed on 2026-08-16.

---

## Manual-Only Verifications

| Behavior | Requirement | Why manual | Current state and instructions |
|----------|-------------|------------|-------------------------------|
| Launch-jurisdiction and qualified trademark conclusion | FND-01, FND-03 | Similarity, goods/services, ownership, and legal conclusions cannot be automated reliably | **Unresolved publication gate.** Confirm Brazil and every intended jurisdiction, reviewer, evidence, date, scope, and actual clear/reject/rename conclusion before publication. |
| Legal-file ownership/contact boundary | FND-04 | NOTICE ownership facts and trademark contact require known factual identity and qualified judgment | **Unresolved publication gate.** Do not invent owner/contact facts; compare the canonical license and confirm trademark terms do not narrow software rights. |
| Threat-model sufficiency review | FND-11 | Structural checks cannot judge whether every control and residual limitation is sufficient for future runtime use | **Pending independent review.** Review every HIGH threat and reject any sandbox or certification overstatement. Runtime threats remain owned by their later phases. |
| Private provenance review | FND-12 | Sensitive patterns must remain outside Git, and future gem/archive/media/CI/install surfaces do not exist | **Not run for publication.** Supply `FOUNDATION_PRIVATE_PATTERNS` out of band, review non-echoing tree/all-ref results, and leave absent future surfaces `not applicable` until Phase 9. |

Qualified trademark review, factual owner/contact evidence, and the external private corpus remain publication gates. Their unresolved state does not invalidate an accurately documented Phase 0 foundation, and automated success does not clear them.

---

## Validation Sign-Off

- [x] All sixteen actual tasks and both waves have current automated evidence.
- [x] Every FND-01 through FND-14 owner maps to its sole owning plan and current public artifact.
- [x] `script/validate-foundation whitespace` passed against the exact public Phase 0 manifest.
- [x] The full default `script/validate-foundation` suite passed all thirteen subchecks offline.
- [x] Focused subchecks preserve requested order, and unknown subchecks fail.
- [x] `git diff --check` passed as supplemental working-tree evidence only.
- [x] Wave 0 tooling is complete and `nyquist_compliant: true` remains set.
- [ ] Qualified trademark/legal publication review is unresolved.
- [ ] The external private-pattern scan required for publication has not run.
- [ ] Independent phase verification is pending.

**Execution evidence:** automated Phase 0 convergence passed on 2026-08-16. The documented foundation is ready for independent verification; publication remains blocked.

## Remediation Evidence

- Phase 1 ownership now exposes `baseline create` as a deferred command boundary; Phase 3 owns actual baseline writes.
- `result-v1.schema.json` defines versioned analyzer execution, completeness, operational failure, finding summary, deterministic gate, and decision-reason contracts.
- Finding semantics now distinguish standalone `observed` state, later baseline states, opaque native evidence references, advisory AI origin, and runtime line-range validation.
- Configuration semantics reject duplicate/unsafe YAML forms, unknown paths, invalid required/disabled combinations, and ambiguous precedence.
- The final fifteen ADRs explicitly cover Rails-first scope, local-first operation, policy-owned authority, safe subprocesses, one-gem structure, and provider-independent AI through grouped topic mapping.
- The validator reports `NOT RUN provenance` when `FOUNDATION_PRIVATE_PATTERNS` is absent; this is a publication blocker and not a successful provenance pass. Supplied synthetic patterns fail on matches and clean patterns complete without matches.
- The literal name `IntegrarPlus` is permitted only for authorized high-level historical attribution or provenance-policy documentation; all technical/private material remains prohibited and examples remain synthetic.
