---
status: complete
completed: 2026-08-22
---

# RailVerdict 1.1 PR Intelligence

Implemented `railverdict pr` as a single-run deterministic projection over `Check.execute(changed: true, base: ...)`.

- Added PRIntelligence v1 JSON/console output with provenance, Git metrics, six path signals, canonical quality delta, analyzer status, normalized test metrics, and SimpleCov coverage.
- Preserved GateResult and existing exit semantics; no MCP, AI, GitHub, readiness, or babysitter logic was added.
- Preserved deleted Git entries and numstat additions/removals for the new metrics.
- Added synthetic contract/CLI/determinism/fail-closed coverage and external disposable Lab runs for route signals, regression/fix delta, and incomplete evidence.
- `bundle exec rake test` had one pre-existing order-dependent `TestRCFollowup#test_verify_repair_runs_fresh_check` failure when run under seed 56571; focused tests, foundation validation, and gem build passed.
