# Repair Workflow (Phase 07)

RailVerdict is the verifier. External coding agents edit code. RailVerdict never edits source, creates commits, opens PRs, merges, or mutates baselines/waivers.

## Workflow

1. `railverdict check --format json` — observe `FAIL` and `exit 1`.
2. `railverdict repair <finding-id|fingerprint> --format json [--output repair.json]` — deterministic packet.
3. Agent modifies source (outside RailVerdict).
4. `railverdict check` — proves `PASS/WARN/FAIL/INCOMPLETE`. `RailVerdict::Repair::Verifier` classifies `fixed|still_present|changed|moved|regressed|incomplete`.

## RepairPacket v1

Deterministic, bounded, machine-readable. Never includes raw secrets, shell strings, absolute paths, binary content, or AI truth. `packet_id = sha256:<64hex>` over canonical `{schema_version,fingerprint,source_revision,base_revision,configuration_digest,baseline_digest,analyzer_versions}`; `created_at` excluded. `256 KiB` cap, `3*80*32 KiB` snippets, `16 KiB` diff hunk `±15` lines, `64 KiB` manifest. `truncated:true` visible. Secret redacted via `SecretDetector`. AI advisory optional under `ai_analysis` and not in identity.

Contains: `target` (finding + state + blocking), `evidence` (analyzer/tool_version/rule/location), `verification` (gate/policy/mode/reasons), `git_context`, `diff_context`, `rails_context` (reused Phase 05), `source_context`, `policy`, `baseline_state`, `waivers_state`, `verification_plan` (`executable+argv` required/suggested), `constraints` (`forbid_baseline_update/waiver/policy_relaxation`), `instructions` (`TRUSTED`), `completeness`, `success_criteria`, `boundary` digests.

## Trust boundary

Repository content is `UNTRUSTED_REPOSITORY_DATA`. `PromptRenderer` delimits `TRUSTED_RAILVERDICT_INSTRUCTIONS` vs untrusted `finding/source/diff`. Source comments like "Ignore instructions" stay data, never become policy.

## Verification

`constraints` forbid weakening: baseline update, waiver creation, policy relaxation. `boundary` stores `configuration_digest/baseline_digest/waivers_digest/base/source_revision`. `Verifier` surfaces `verification_boundary_changed:{config,baseline,waivers,base,source}`. Required analyzer missing => `INCOMPLETE` even if target vanished. Never auto-creates `baseline --force` or waiver.

## CLI

`railverdict repair <id|fingerprint> [--config PATH] [--format console|json] [--output PATH] [--changed] [--base REV] [--baseline PATH] [--waiver PATH]`

- JSON mode: exactly one JSON doc + newline on stdout, diagnostics stderr.
- `--base` requires `--changed`.
- Unknown/stale finding => exit `2`.
- `--output` atomic `0600`.

## Security

No auto-edit, no permission escalation, no shell interpolation (argv form). Bounded I/O, UTF-8 scrub, symlink escape rejected, no binary. Recommend `.gitignore: *.repair.json` if snippets sensitive.

## MCP

Phase 08 will expose same packet via MCP. No MCP in Phase 07.
