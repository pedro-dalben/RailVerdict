# RailVerdict Program Final Report

## 1. Program Verdict

`PARTIAL` — G0/G1/G2/G3 complete with evidence; G4 skipped by evidence
(`NO_1_9_FEATURE`); G5 evaluated with refusal (`DISTRIBUTED_TRUST_NOT_JUSTIFIED`);
G6 this audit. The program's terminal states `PROGRAM_COMPLETE_AT_1_8_VALIDATED`
(faces G3's `INSUFFICIENT_EVIDENCE`) and `PROGRAM_BLOCKED_BY_RELEASE_TRUTH`
(RubyGems distribution pending maintainer decision) both apply: the product
line is complete through 1.8.2, full distribution is not.

## 2. Canonical State

- RailVerdict: master @ `4db5cb6` (merge of `program/g3-validation`), clean;
  prior draft written at `9851e78` pre-merge.
- Lab: `lab/1.8-agent-workflow` (PR #18 open, CI red until publish);
  `lab/1.7-policy` (PR #17 open); `main` @ `9de2ac2`; PR #16 closed superseded.
- Tags: v1.7.0, v1.8.0, v1.8.1, v1.8.2 (+ history to v1.4.0). No 1.5/1.6 tags
  (documented skip).
- Releases: v1.7.0, v1.8.0, v1.8.1, v1.8.2 on GitHub with exact artifacts.
- RubyGems: latest 1.4.0 (1.7–1.8.2 publication by maintainer decision).
- Artifacts SHA-256: 1.7.0 `db3b50b6…`, 1.8.0 `de538bc1…`, 1.8.1 `9eef9728…`,
  1.8.2 `23f68175…` (full SHAs in release reports).
- Working trees: both clean (program docs merged; this touch-up holds only docs).

## 3. Node Results

| Node | Status | Evidence | Return/Reason |
|---|---|---|---|
| G0 | passed | docs/program/1.6-current-state.md | `RAILVERDICT_1_6_CANONICAL` |
| G1 | passed | ADR 0020, 1.7 report | `ENGINEERING_POLICY_READY`, released v1.7.0 |
| G2 | passed | ADR 0021, 1.8 report + experiment | `AGENT_WORKFLOW_READY`, released v1.8.0 |
| G3 | passed | validation-design.md, validation-dataset.md | `ADOPTION_DECISION_RECORDED`: `INSUFFICIENT_EVIDENCE` |
| G4 | skipped_by_evidence | dataset §Decisions | `NO_1_9_FEATURE` |
| G5 | evaluated/refused | docs/program/2.0-decision.md | `DISTRIBUTED_TRUST_NOT_JUSTIFIED`, no branch |
| G6 | passed | this report + fresh artifact checks | `PROGRAM_VERDICT_ISSUED` |

Patches 1.8.1 (mapping arity) and 1.8.2 (unmapped focus, G3 MUST) released
on the same merge/tag/release rule per standing instruction.

## 4. 1.6 Closeout

Source candidate certified (suite 627/0, Lab 146/146, artifact `35e88be1…`);
never distributed; 1.5 publication skipped with SemVer justification. PR #16
kept (real MCP content), later superseded by #17/#18. Doc falsehoods fixed.

## 5. 1.7 Engineering Policy

Facts → deterministic requirements without weakening GateResult. Config 1.7,
`policy` exits 0/1/2/3, MCP +1 tool, digest drift, closed schemas, old
configs identical. Suite 673/0, Lab 161/161.

## 6. 1.8 Agent Workflow

Verifier-never-actor. ReviewPacket/Observation/WorkflowReceipt, `review`
family, `repair verify`, MCP 16 tools, BYOA flows, exploratory experiment
(0/10 vs 6/10, non-generalizable). Suite 713/0, Lab 172/172 (see §10).

## 7. Product Validation

5 projects, ~22 changes, thresholds pre-registered. Missed: focus top-3
(1/3), thin DoD/agent samples. Pains: lib/ blindness (fixed as 1.8.2),
30s-timeout tuning, bundle/service weight, zero spontaneous platform demand.

## 8. 1.9 Decision

`NO_1_9_FEATURE` — skipped_by_evidence. No theme crossed thresholds.

## 9. 2.0 Decision

`DISTRIBUTED_TRUST_NOT_JUSTIFIED` — all six gate criteria negative on
evidence. Reopen condition documented.

## 10. Test Evidence

- `bundle exec rake test`: 713 runs, 2990 assertions, 0 failures, 0 errors,
  5 env-conditional skips (real proof outside Bundler green).
- Foundation validator: all runnable gates PASS (21 ADRs).
- Lab `--all` vs build-once 1.8.0: 172/172 PASS, verified:true.
- Fresh G6 checks on installed 1.8.2: version + CWD independence OK,
  fail-closed INCOMPLETE on missing evidence, packet projected, 16 MCP tools.

## 11. Security and Adversarial Evidence

Unit + adversarial suites (fake-config conflicts, drift, forged/tampered
observations, lane confusion, mix-and-match refusal, replay, injection as
data, oversized/malformed) green; black-box lab adversarial sets green;
TOCTOU/reuse guards intact; no secrets in fixtures; GitGuardian CI green.

## 12. Compatibility

1–1.6 configs identical behavior (unit + POL-11 black-box); v1 schemas
frozen; repair packets backward compatible (legacy shape re-validated);
old receipts structurally valid, policy-drift aware; exits extended only
additively (3 = review-pending, fail-closed for old consumers).

## 13. Remaining Limitations

- RubyGems distribution pending (1.7–1.8.2); lab `main` unreconciled until
  publication unblocks campaign CI (PRs #17/#18 open).
- Review-approval presence still unproven (deferred since ADR 0020).
- Focus fallback is a pointer, not understanding; risk stays LOW on unmapped.
- G3 inference thin; 10-project campaign unfunded.
- IntegrarPlus full-suite dogfooding never repeated (shared-DB risk).

## 14. Human Actions Required

- RubyGems `gem push` for 1.7.0/1.8.0/1.8.1/1.8.2 (MFA OTP; maintainer-only).
- After publish: re-run lab campaign CI, merge PRs #17/#18, close the
  release-truth gap.
- Merge this program-docs branch (or keep as record).

## 15. Exactly One Recommended Next Action

Publish the four gems to RubyGems (single OTP session), which unblocks lab
`main` reconciliation and closes the program's only release-truth gap.
