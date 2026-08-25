# External Adoption Report Template

Copy this file for each meaningful adoption attempt: `docs/adoption/<slug>.md` (voluntary, no private source required).

```yaml
project: # anonymous or public identifier
public_repository_url: # when applicable (or empty for private)
ruby_version: # e.g., 3.4.5
rails_version: # e.g., 8.1.3
test_framework: # rspec | minitest | both | other
enabled_analyzers: [rubocop, rspec, minitest, simplecov, bundler-audit]
installation_method: gem | bundler | other
```

| Step | Result | Notes |
|---|:---:|---|
| Install (`gem install rail_verdict` / `bundle add`) | pass/fail |  |
| `railverdict init` | pass/fail |  |
| `railverdict doctor` | pass/fail/incomplete | paste doctor summary (no secrets) |
| `railverdict baseline create` | pass/fail | |
| First `railverdict check` | pass/warn/fail/incomplete | gate + exit code |
| Time to first result (minutes) |  | wall time from init to first gate |
| Confusing steps | | free text |

**Bugs discovered:** (link to issues)

**Feature requests:** (link to issues)

**Unexpected behavior:**

**Final adoption status:** `DISCOVERED | INSTALL_ATTEMPTED | INSTALLED | FIRST_CHECK | ACTIVE_TRIAL | ADOPTED | ABANDONED | BLOCKED` (see `docs/adoption/first-10.md` definitions)

**Blocker (if any):**

**Outcome summary (one paragraph):**

**Environment (redacted config snippet, no secrets):**

```yaml
# paste .railverdict.yml with secrets removed
```

**Do not include:** private source code, absolute paths with user names, credentials, tokens, `.env` contents, advisory DB output with private URLs.
