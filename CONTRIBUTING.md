# Contributing

## Reporting a bug

Include: RailVerdict version (`railverdict --version`), Ruby version (`ruby -v`), Rails version, OS, command (`check`/`pr`/`receipt` …) with `--format json` snippet, redacted `.railverdict.yml` (remove tokens), expected vs actual, minimal reproduction (synthetic fixture preferred), `railverdict doctor` output. Open an issue using the Bug template.

Where: https://github.com/pedro-dalben/RailVerdict/issues

What to include checklist is also in `.github/ISSUE_TEMPLATE/bug_report.md`.

## Running tests

```bash
bundle install
bundle exec rake test            # 512 runs, ~2120 assertions
bundle exec ruby script/validate-foundation
gem build rail_verdict.gemspec
gem install ./rail_verdict-*.gem --no-document
railverdict --help
```

Add regression tests under `test/test_*.rb` (Minitest). Follow existing `RepositoryState`/`Check`/`CLI` patterns; prefer real Git/filesystem fixtures over heavy mocks for correctness surfaces (gate, baseline, receipts, merge-base).

## Proposing a feature

Open a **Feature request** issue first. Do not implement major new verifiers (new analyzer, SaaS, dashboard) without discussion — the backlog is evidence-driven (`docs/roadmap/1.3-evidence-backlog.md`). Small docs/UX fixes may go directly to PR.

## Pull requests

- One logical commit per PR; keep `lib/` runtime changes separate from docs.
- Run `rake test` + relevant Lab `scripts/lab_run` if touching verification contracts.
- Update `CHANGELOG.md` under `Unreleased`.

## Security / private data

Do not post secrets, credentials, or private source. For exploitable vulnerabilities, see `SECURITY.md` (private disclosure). For provenance concerns, see `docs/foundation.md` firewall.

## First-contributor path

`docs/troubleshooting.md` + `docs/agent-verification.md` are good orientation. `CONTRIBUTING.md` answers “where to report, what to include, how to test, how to add regression.”
