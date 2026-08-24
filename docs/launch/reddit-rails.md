Title (r/rails): Try RailVerdict on a real Rails app — baseline + receipts for PR confidence

Post:

Rails teams with legacy debt know the adoption trap: "fix everything before we can gate." RailVerdict's `no_new_debt` baseline is the opposite: `baseline create` snapshots current findings; next PRs fail only on introduced debt.

It wraps your existing suite (RSpec or Minitest), RuboCop, SimpleCov coverage.json, bundler-audit, and Git changed-scope. Deterministic, offline, fail-closed. PR mode via `railverdict pr --base origin/main`. CI: `fetch-depth: 0` + `bundle exec railverdict check --changed --base ${{ github.event.pull_request.base.sha }}`.

For AI-assisted teams: agent proposes, RailVerdict decides; receipts prove fresh vs stale after any repo mutation.

Open source/MIT, gem `rail_verdict`. What breaks on your app (setup, Ruby compat, analyzer)? What would make you adopt in CI vs locally vs with agents?

