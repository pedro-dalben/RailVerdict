---
status: complete
completed: 2026-08-21
---

# RailVerdict 1.0.1 operational compatibility

Implemented the existing partial 1.0.1 work and completed its regression and
release checks.

## Delivered

- Added configuration schema v1.5 with per-analyzer `timeout_seconds` from 1
  through 3600; old versions retain the 30-second default.
- Propagated the selected timeout through Check probes and runs and Doctor.
- Preserved required timeout failures as `INCOMPLETE` / exit `2`.
- Replaced bundler-audit's pristine-stdout JSON assumption with balanced,
  string-aware JSON boundary extraction and trailing-content rejection.
- Preserved bundler-audit exit `1` as valid vulnerability evidence and treats
  exit `2+` as an operational failure.
- Added synthetic fixtures, compatibility tests, docs, changelog, and version
  1.0.1 metadata.

## Verification

- `bundle exec ruby -Itest test/test_1_0_1_compatibility.rb`: 28 runs, 61 assertions.
- `bundle exec ruby -Itest test/test_bundler_audit_adapter.rb`: 12 runs, 51 assertions.
- `bundle exec rake test`: 423 runs, 1,632 assertions, 0 failures, 0 errors, 7 skips.
- `bundle exec ruby script/validate-foundation`: PASS; provenance remains NOT RUN because no private corpus was supplied.
- CLI `doctor` with `examples/configuration-v1.5.yml`: valid configuration.
- `gem build rail_verdict.gemspec`: built `rail_verdict-1.0.1.gem`.

## Environment note

The normal RuboCop command could not load `rubocop-rails` in this checkout, so
that quality gate remains unverified. No public `railverdict-lab` checkout was
present; the RailVerdict repository's synthetic fixtures provide the available
reproduction coverage.
