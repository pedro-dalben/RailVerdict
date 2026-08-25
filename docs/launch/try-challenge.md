# Try RailVerdict Challenge (5–7 minutes)

1. `bundle add rail_verdict --group development,test --require false && bundle install`
2. `bundle exec railverdict init` → creates `.railverdict.yml`
3. `bundle exec railverdict doctor` → explains missing analyzers (install required ones, e.g., `bundle add rubocop --group development --require false`)
4. `bundle exec railverdict baseline create` → commit `.railverdict-baseline.json` (or skip baseline for strict)
5. `bundle exec railverdict check` → first gate (`PASS / FAIL / INCOMPLETE` is all valid evidence)
6. Controlled defect: add `unused = "oops"` (RuboCop Lint/UselessAssignment), rerun → expect `FAIL` (introduced), then fix → `PASS`
7. Tell us: what confused (install, INCOMPLETE vs FAIL, baseline)? Would you use locally / CI / with agents? Which analyzer is missing? Was it slow?

Report via `docs/adoption/external-adoption-template.md` or a GitHub issue.
