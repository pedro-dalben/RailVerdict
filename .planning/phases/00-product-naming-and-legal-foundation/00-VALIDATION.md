---
phase: 0
slug: product-naming-and-legal-foundation
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-16
---

# Phase 0 — Validation Strategy

> Per-phase validation contract for the documentation, legal boundaries, draft schemas, and roadmap foundation. This validates repository claims and structure; it does not provide legal clearance.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | One repository validation script using installed Ruby/Python standard tooling and the environment-provided Python `jsonschema` validator |
| **Config file** | none — Wave 0 creates only `script/validate-foundation` |
| **Quick run command** | `script/validate-foundation <relevant-subcheck> && git diff --check` |
| **Full suite command** | `script/validate-foundation && git diff --check` |
| **Estimated runtime** | under 10 seconds, excluding manual legal and provenance review |

The validator is Phase 0 documentation tooling, not the RailVerdict product CLI. It must not share a product namespace, install packages, access the network, or create a gem/application scaffold.

---

## Sampling Rate

- **After every task commit:** Run the subcheck named by the task plus `git diff --check`.
- **After every plan wave:** Run `script/validate-foundation && git diff --check`.
- **Before `$gsd-verify-work`:** The full automated suite must be green and manual review results must be recorded.
- **Max feedback latency:** 10 seconds for automated checks.

---

## Per-Task Verification Map

The planner may refine task numbers, but each requirement must retain at least the verification shown here.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 00-01-01 | 01 | 1 | FND-01 | T-NAME-01 | Search evidence remains dated and does not claim clearance | structure + manual legal | `script/validate-foundation identity links` | ❌ W0 | ⬜ pending |
| 00-01-02 | 01 | 1 | FND-02 | Every public identity surface has one value | contract | `script/validate-foundation identity` | ❌ W0 | ⬜ pending |
| 00-01-03 | 01 | 1 | FND-03 | Unresolved review blocks publication without inventing a legal outcome | structure + human checkpoint | `script/validate-foundation identity` | ❌ W0 | ⬜ pending |
| 00-01-04 | 01 | 1 | FND-04 | Trademark policy cannot narrow Apache-2.0 software rights | checksum/text + manual legal | `script/validate-foundation legal links` | ❌ W0 | ⬜ pending |
| 00-01-05 | 01 | 1 | FND-07 | Product, philosophy, non-goals, and competitive position agree | structure | `script/validate-foundation identity links` | ❌ W0 | ⬜ pending |
| 00-02-01 | 02 | 1 | FND-05 | Registry rows expose licenses, bundling, output, and HOLD decisions | structure | `script/validate-foundation analyzers links` | ❌ W0 | ⬜ pending |
| 00-02-02 | 02 | 1 | FND-06 | Ruby/Rails lanes are proposals, not unsupported compatibility claims | structure | `script/validate-foundation analyzers links` | ❌ W0 | ⬜ pending |
| 00-02-03 | 02 | 1 | FND-11 | Every high-risk trust boundary maps to a control and owning phase | structure + security review | `script/validate-foundation security links` | ❌ W0 | ⬜ pending |
| 00-02-04 | 02 | 1 | FND-12 | Public material is synthetic/English-only and scans never echo secrets | automated scope + manual provenance | `script/validate-foundation language provenance` | ❌ W0 | ⬜ pending |
| 00-02-05 | 02 | 1 | FND-13 | Proposed one-gem structure is documented but absent from the tree | negative assertion | `script/validate-foundation no-production links` | ❌ W0 | ⬜ pending |
| 00-02-06 | 02 | 1 | FND-14 | All 85 v1 requirements map once in dependency order | contract | `script/validate-foundation roadmap links` | ❌ W0 | ⬜ pending |
| 00-03-01 | 03 | 1 | FND-09 | Valid examples pass strict Draft 2020-12 schemas; unknown fields fail | schema contract | `script/validate-foundation schemas` | ❌ W0 | ⬜ pending |
| 00-03-02 | 03 | 1 | FND-10 | CLI commands, streams, ordering, and proposed exits are explicit drafts | structure | `script/validate-foundation contracts links` | ❌ W0 | ⬜ pending |
| 00-04-01 | 04 | 2 | FND-08 | Exactly fifteen ADRs contain complete decisions and deferred work | structure | `script/validate-foundation adrs links` | ❌ W0 | ⬜ pending |
| 00-04-02 | 04 | 2 | FND-01–FND-14 | Cross-artifact identities, links, claims, and scope remain consistent | integration | `script/validate-foundation && git diff --check` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `script/validate-foundation` — one offline, dependency-free repository validator with `schemas`, `links`, `identity`, `legal`, `analyzers`, `contracts`, `adrs`, `security`, `roadmap`, `language`, `provenance`, and `no-production` subchecks.
- [ ] `schemas/finding-v1.schema.json` and `schemas/configuration-v1.schema.json` — strict JSON Schema Draft 2020-12 contract drafts.
- [ ] `examples/finding-v1.json` and `examples/configuration-v1.yml` — small, synthetic valid examples.
- [ ] External private-pattern input procedure — pattern values stay outside the repository and matched values are never printed.
- [ ] Publication-gate record — initially unresolved; later qualified review remains a human action and publication blocker.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Launch-jurisdiction and qualified trademark conclusion | FND-01, FND-03 | Search similarity, goods/services, ownership, and legal conclusions cannot be automated reliably | Confirm the dated evidence record lists Brazil and every intended launch jurisdiction, current status, reviewer, evidence, and outcome; leave publication blocked until qualified review records clearance or a rename decision. |
| Legal-file boundary review | FND-04 | NOTICE ownership facts and trademark wording require a known legal identity and qualified judgment | Compare `LICENSE` with the official Apache-2.0 text; confirm NOTICE is factual; confirm trademark terms do not restrict software exercise, redistribution, sale, services, forks, or modification. |
| Threat-model review | FND-11 | Automated structure checks cannot judge control sufficiency | Review every high-severity threat, required control, residual limitation, and owning roadmap phase; reject any claim that process isolation is an OS sandbox. |
| Private provenance review | FND-12 | The sensitive pattern corpus must not be committed and future gem/archive/media surfaces do not yet exist | Supply the private pattern file out of band, run the non-echoing scan over current tree and history, review path/category-only results, and record absent future surfaces as not applicable until Phase 9. |

---

## Validation Sign-Off

- [x] All planned requirement groups have an automated verification or explicit Wave 0 dependency.
- [x] Sampling continuity: no three consecutive tasks lack automated feedback.
- [x] Wave 0 identifies every missing validator, schema, example, and external-input procedure.
- [x] No watch-mode flags are used.
- [x] Expected automated feedback latency is below 10 seconds.
- [x] `nyquist_compliant: true` is set in frontmatter.

**Approval:** approved 2026-08-16 for planning; execution evidence remains pending.
