Title (r/ruby): RailVerdict — deterministic verification gate for Rails (RSpec/Minitest + RuboCop + Git + receipts)

Post:

Maintainers hit the same problem: fragmented tool output makes "safe to merge?" a judgment call, and agents can claim they verified their own code.

RailVerdict consumes your existing tools (RSpec/Minitest, RuboCop, SimpleCov, bundler-audit, Git), normalizes to stable fingerprints, applies baseline/no-new-debt and returns one deterministic GateResult: PASS/WARN/FAIL/INCOMPLETE (exit 0/1/2). Fail-closed — missing evidence never becomes PASS.

1.2 is the agent-focused release: Verification Receipts bound to the exact observable repo state, `receipt verify` fresh→stale on any edit, PR Intelligence (deterministic signals), MCP `verify`/`get_verification_receipt`/`get_pr_intelligence` (one verify, no reruns).

Gem `rail_verdict` 1.2.0 (Ruby >=3.3). `bundle add rail_verdict` → `railverdict init && railverdict doctor && railverdict baseline create && railverdict check`.

Try on a legacy app: the baseline path is the point — existing debt committed, new debt blocked. Tell us where install/INCOMPLETE confuses.

Repo: https://github.com/pedro-dalben/RailVerdict — looking for honest criticism, not stars.

