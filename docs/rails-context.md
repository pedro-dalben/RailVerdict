# Rails Context

RailVerdict collects bounded, deterministic Rails context without booting the application, without executing `config/routes.rb` or `db/schema.rb`, and without a semantic code graph.

## Source

- `Ruby/Rails` versions from `Gemfile.lock` (`rails (...)` / `ruby ...`).
- `Test framework` from `test/`/`spec/` directory presence plus `Gemfile.lock` hints (`rspec-rails`, `rspec-core`, `minitest`).
- `Database adapter` from `config/database.yml` literal `adapter` string (safe YAML, no ERB) or `Gemfile.lock` hints (`pg`, `mysql2`, `sqlite3`, `trilogy`).
- `Structure` counts from filesystem inventory (capped 500 files viewed).

## Related Context (only when `--changed` is used)

For each changed file whose path matches a Rails kind (`app/models`, `app/controllers`, `app/jobs`, `app/mailers`, `app/helpers`, `app/services`, `app/policies`, `app/components`, `app/views`, `config/routes.rb`, `db/schema.rb`), RailVerdict infers:

- `kind` and `constant` (e.g. `app/models/admin/user.rb` → `Admin::User`) without loading code.
- Related tests (`test/models/..._test.rb`, `spec/models/..._spec.rb`, `test/controllers/...`, `spec/requests/...`) — candidates that physically exist, not guarantees of affected tests.
- Policies (`app/policies/..._policy.rb`), views (`app/views/<controller>/...`), routes (`config/routes.rb`), schema tables, and model associations (`belongs_to`, `has_one`, `has_many`, `has_and_belongs_to_many` with literal first arg).

All relationships are bounded (`MAX_RELATED 20`, `MAX_FILES 500`, file caps 1 MiB) and ordered deterministically.

## Confidence

Every related item carries `confidence` in `{exact, conventional, inferred, unresolved}` and a `provenance` string:

- `exact` — literal declaration or physically verified exact content (`self.table_name = "accounts"`).
- `conventional` — filesystem convention that exists (`test/models/user_test.rb`).
- `inferred` — guess without filesystem proof (`User` → `users` table name).
- `unresolved` — dynamic/unparseable (`draw` routes, `self.table_name = variable`, `structure.sql`).

No numeric probabilities.

## Routes

Only literal controller mappings are extracted: `resources :users`, `resource :account`, `get 'x', to: 'controller#action'`. Dynamic constructs (`draw`, `mount`, `concern`, `constraints` with procs, `resources` inside blocks) are marked `unresolved`. No `bundle exec rails routes` invocation.

## Schema

`db/schema.rb` is parsed boundedly (100 tables max, 500 columns). `db/structure.sql` is explicitly marked `unresolved` (`structure_sql_not_parsed`) — no SQL parser is built in this phase. Custom table names only when a literal string is present; dynamic names are `unresolved`.

## Result Surface

`rails_context` is an additive permissive object under `result-v1` (like `git`). It never changes `GateResult` policy or findings; it enriches understanding. Policy ignores it.

## Non-Goals in this Phase

- No Rails boot, no ActiveSupport dependency, no database activity.
- No Prosopite, strong_migrations, or migration execution.
- No vector/embedding search, no MCP, no whole-repo graph.

## Security Bounds

Repository files are untrusted data. All reads are capped (1 MiB per file, 500 files), UTF-8 validated, symlink-to-outside rejected via `File.realpath` containment, binary/NUL rejected, oversized skipped. Parser failures degrade to `unresolved`, never crash or make the gate `INCOMPLETE`.
