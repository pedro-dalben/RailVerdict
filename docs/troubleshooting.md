# Troubleshooting

For every entry: **Symptom → Likely cause → Diagnose → Fix**. RailVerdict is fail-closed: `INCOMPLETE` means evidence missing/untrustworthy, not “retry until PASS.”

### `railverdict: command not found`

- **Cause:** gem not installed or not on PATH.
- **Diagnose:** `gem list rail_verdict`, `which railverdict`, `bundle exec railverdict --version`.
- **Fix:** `gem install rail_verdict` or `bundle add rail_verdict --group development,test --require false && bundle install`; use `bundle exec railverdict`.

### `wrong Ruby` / `required_ruby_version >= 3.3`

- **Cause:** Ruby < 3.3.
- **Diagnose:** `ruby -v`, `gem spec rail_verdict required_ruby_version`.
- **Fix:** upgrade Ruby (3.3+; 3.4+ recommended). See `docs/release/1.2-compatibility-matrix.md`.

### `bundle executable missing` / analyzer `unavailable`

- **Cause:** required analyzer not in bundle.
- **Diagnose:** `bundle exec railverdict doctor --format json | python3 -m json.tool`; check `operational_failures`.
- **Fix:** add target-owned analyzers: `bundle add rubocop --group development --require false`, `rspec`/`minitest`, `simplecov`, `bundler-audit` as needed; `bundle install`. Set `enabled: false` only if `required: false`.

### RSpec / Minitest timeout (`timed_out` → INCOMPLETE exit 2)

- **Cause:** suite exceeds 30s default.
- **Diagnose:** `check --format json` shows `analyzer_results[].status: timed_out`.
- **Fix:** use `version: 1.5` with per-analyzer `timeout_seconds: 1..3600` (e.g., `rspec: {timeout_seconds: 600}`). No CLI override. Documented in `README.md` + `docs/contracts.md`.

### RuboCop unavailable

- **Diagnose:** `doctor` reports rubric; `bundle exec rubocop --version` fails.
- **Fix:** `bundle add rubocop --group development --require false` (+ `rubocop-rails` if Rails cops desired) and `bundle install`.

### SimpleCov artifact missing (`simplecov: no coverage artifact`)

- **Cause:** `coverage/coverage.json` (public schema) not produced, or `.resultset.json` used by mistake.
- **Diagnose:** `ls coverage/coverage.json`; `doctor` hint.
- **Fix:** configure `simplecov` with `SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter` (or `simplecov_json_formatter`), run tests to produce `coverage/coverage.json`. RailVerdict never parses `.resultset.json`.

### bundler-audit failure / advisory DB download noise

- **Cause:** `bundler-audit` not installed or DB stale; stdout may contain `Downloading ruby-advisory-db ...`.
- **Fix:** `bundle add bundler-audit --group development --require false`; run `bundle exec bundler-audit update` explicitly (offline verify keeps network separate). RailVerdict robustly extracts JSON even with download prefix.

### `invalid Git base` / `missing Git base` → INCOMPLETE

- **Cause:** `pr --base ...` or `check --changed --base` given non-existent SHA, or shallow clone missing history.
- **Diagnose:** `git cat-file -p <base>` fails; CI shallow fetch.
- **Fix:** use a reachable base; in CI set `fetch-depth: 0` (`docs/github-actions.md`); ensure `origin/main` fetched for merge-base.

### `shallow checkout` / `shallow/missing history`

- **Fix:** `actions/checkout@v4 with fetch-depth: 0` or explicit `git fetch origin main`.

### `baseline missing` / `baseline_required` → INCOMPLETE in `no_new_debt`

- **Diagnose:** `doctor` says `baseline missing for no_new_debt`.
- **Fix:** `bundle exec railverdict baseline create` → commit `.railverdict-baseline.json`; `check` is read-only and never mutates it.

### `baseline corrupt` / `incompatible baseline`

- **Diagnose:** `baseline create` refuses; error cites `Baseline::IncompatibleError`.
- **Fix:** `rm .railverdict-baseline.json && bundle exec railverdict baseline create --force` (after verifying gate is trustworthy).

### `waiver invalid` / expired / orphan

- **Diagnose:** `check --format json` shows `waivers` path but `operational_failures` about waiver schema/version/expiry.
- **Fix:** ensure waivers file validates `waivers-v1.schema.json`, correct `fingerprint` (exact `sha256:`), UTC `expires_at`, owner/reason present.

### `receipt stale` (`worktree_changed`, `index_changed`, `head_changed`, `configuration_changed`, etc.)

- **Cause:** repository mutated after receipt was issued — state identity diverged.
- **Diagnose:** `bundle exec railverdict receipt verify receipt.json --format json` → `status: stale`, `reasons: [...]`, exit 2.
- **Fix:** do not edit after receipt creation; re-run `check` + `receipt create` after intentional changes.

### `receipt malformed` / `receipt_integrity_failed`

- **Cause:** hand-edited receipt or truncated file.
- **Fix:** `receipt verify` (CN) shows `invalid`; re-create via `receipt create`.

### `INCOMPLETE` result — general

- **Meaning:** required evidence missing/untrustworthy; **not a PASS**. Policy not evaluated.
- **Diagnose:** `check --format json` → `operational_failures[].code` (`unavailable`, `unsupported`, `timed_out`, `truncated`, `malformed`, `configuration`, `repository_state_unavailable`).
- **Fix:** address the listed failure (install analyzer, fix config, provide base/history, handle timeout), then re-verify. Do not hide with broad rescue.

For path escape / NUL / control char errors: fix filename/config inputs; RailVerdict contains via `PathSafety` realpath and bounded hashing.
