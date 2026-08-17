# Baselines, Comparison, and Waivers

Phase 03 implements the baseline and waiver contracts described in ADRs 0005 and 0006.

## Baseline

`railverdict baseline create` runs a complete trusted verification, then writes `.railverdict-baseline.json` atomically.

Options: `--config PATH`, `--output PATH`, `--format console|json`, `--force`.
Discovery: `--output` absolute or relative to repository root, else `configuration.baseline.path` from `.railverdict.yml` (`version: 1.2`), else `.railverdict-baseline.json` in the repository root.

Requirements:
- Required analyzer evidence must be complete; incomplete runs are refused and no file is created.
- An existing baseline is not overwritten without `--force`.
- Writes are atomic (same-directory tempfile + `fsync` + `rename`) and never leave a partial file.

Stored artifact: `schemas/baseline-v1.schema.json` v1.0 with `fingerprint_version: 1`, `algorithm: sha256`, `payload_schema: https://railverdict.dev/fingerprint-payload/v1`. Entries are sorted by fingerprint and contain only `{fingerprint, analyzer, rule_id, path, message, first_seen}` plus reproducibility metadata `{created_at, created_by, configuration_digest, analyzer_versions}`. No source code, credentials, full logs, prompts, diffs, or environment is stored.

Reader fails closed on unknown `schema_version`, unknown `fingerprint_version`, invalid structure, duplicate fingerprints, or corrupted JSON with message requiring `re-create with railverdict baseline create`.

## Fingerprint v1

Payload: `{payload_schema, fingerprint_version, algorithm, analyzer, rule_id, path, message}` sorted keys, JSON, SHA-256 to `sha256:<64hex>` (`lib/rail_verdict/fingerprint.rb`). Line numbers, timestamps, and absolute paths are excluded. File rename or message change intentionally produces a different fingerprint; no AST or semantic identity is claimed.

## Comparison

`railverdict check` is read-only. When a baseline exists it classifies findings via fingerprint equality into `existing` (intersection), `introduced` (current-only), `resolved` (baseline-only), plus best-effort `moved` (same analyzer+rule+message, different path, single candidate) and `changed` (same path+analyzer+rule, different message, single candidate). Ambiguous multi-matches stay `introduced`/`resolved` deterministically.

## Policy modes

- `advisory`: all non-blocking; `PASS` empty else `WARN`.
- `no_new_debt`: `existing` non-blocking; `introduced`/`changed`/`moved` blocking (default any severity). Only existing → `PASS`.
- `strict`: all current findings blocking.

Incomplete required evidence always produces `INCOMPLETE`/`not_evaluated` (exit 2), even with a baseline.

## Waivers

Exact-fingerprint waivers only (`schemas/waiver-v1.schema.json`, `schemas/waivers-v1.schema.json`). Each waiver requires `{fingerprint: sha256:..., reason, owner, created_at: UTC Z, expires_at: UTC Z, issue_ref?}` with `expires_at > created_at`. Store: `.railverdict-waivers.json` (`{schema_version: "1.0", waivers: [...]}`) discovered via `--waiver PATH`, `configuration.waivers.path`, or default. No wildcards or blanket disables.

Active waivers ( `created_at <= clock < expires_at`, injected UTC clock) restate matching findings as `waived` (visible, non-blocking). Expired waivers no longer suppress; orphaned waivers (fingerprint in neither current nor baseline) are reported as `comparison.orphaned_waivers` and remain observable. Malformed or incompatible waiver data fails closed and never silently suppresses.

## Console and JSON

Console adds `Baseline:` and `Comparison: Introduced:/Existing:/Resolved:/Changed:/Moved:/Waived:` lines. JSON adds `baseline: {loaded, path, schema_version, fingerprint_version, compatible}` and `comparison: {counts, introduced, existing, resolved, changed, moved, waived, orphaned_waivers, waivers?}` for machine consumers.

## Limitations

- No AST; file moves, renames, or copy-paste create new fingerprints.
- `changed`/`moved` heuristics require a single unambiguous candidate.
- Baseline/waiver discovery is explicit path or default, not a repo-wide search.
