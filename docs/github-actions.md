# GitHub Actions — RailVerdict

RailVerdict exposes its verification gate to GitHub Actions through a thin
workflow adapter. The gate itself stays local: analyzers, policy evaluation,
baselines and fingerprints run inside the workflow job without a custom GitHub
App, hosted service, account, or telemetry.

## Workflow

The canonical example is `examples/github/railverdict.yml`:

* **Trigger:** `on: pull_request` — never `pull_request_target`.
* **Permissions:** `contents: read` at both the workflow and the job.
* **Checkout:** `actions/checkout@v4` at `github.event.pull_request.head.sha`
  with `fetch-depth: 0` (full history so `merge-base` can resolve).
* **Gate:** `bundle exec railverdict check --changed --base ${{ github.event.pull_request.base.sha }}`
  The base SHA comes from the GitHub event, not from a guessed
  `origin/main`. The core never calls `git fetch` or guesses a base branch.

To adopt it, copy `examples/github/railverdict.yml` to
`.github/workflows/railverdict.yml`.

## Exit handling

* `railverdict check --changed` exits `0` for `PASS/WARN`, `1` for `FAIL`,
  `2` for `INCOMPLETE`, and `130` for interruption.
* The `verify` step's non-zero exit fails the check, so the PR cannot merge
  when the required status check is enforced.

## Artifacts

* `result.json` — the versioned machine result (`result-v1`) for agents.
* A future `--format sarif` reporter can emit `result.sarif` for
  `github/codeql-action/upload-sarif` without duplicating verification.

Both artifacts are projections of the same `GateResult`; no second gate engine
is introduced.

## Fork security model (GIT-06 / GIT-07)

The fork security boundary is documented in `SECURITY.md`. Summary of the
guarantees this workflow provides:

* The `verify` job runs PR code from forks **unprivileged**: it receives only a
  read-only `GITHUB_TOKEN` and never interpolates `secrets.*` into a shell
  command.
* No `pull_request_target` workflow executes or trusts fork-contributed
  scripts, caches, or artifacts in a privileged context.
* No long-lived `GEM_HOST_API_KEY`, publisher identity, or remote-AI
  credentials are exposed in the `verify` job.
* If a privileged follow-up job (e.g., to post a PR comment) is added, it
  must run on `workflow_run`, only `actions/download-artifact` the
  `result.json` produced by `verify`, validate it against
  `result-v1.schema.json`, and render a summary — it must never `checkout`
  the fork SHA or `run:` fork-owned scripts.

Any privileged handoff must be an explicitly reviewed safe boundary. The
unprivileged job is the only one that checks out the PR head.

## Local parity

A developer reproduces the same gate locally:

```bash
bundle exec railverdict check --changed --base <merge-base-sha>
bundle exec railverdict check --changed --base origin/main  # if fetched explicitly
```

The workflow uses the explicit base SHA from the event to avoid the
non-deterministic guess of `origin/main` that the core refuses to perform.

## SARIF and annotations (GIT-04 / GIT-08)

`lib/rail_verdict/reporters/sarif.rb` and
`lib/rail_verdict/reporters/github_annotations.rb` are pure projections of
`GateResult` and canonical findings. The core imports no `Octokit`/GitHub
types. SARIF (`version: 2.1.0`, `tool.driver.name: RailVerdict`) maps
`severity → level` (`critical/high → error`, `medium → warning`,
`low/info → note`) and stable fingerprints remain deterministic.

## Requirements trace

* `GIT-05` — documented workflow, minimum permissions, no custom App.
* `GIT-06` — unprivileged fork execution, no secrets/remote-AI in verify job.
* `GIT-07` — no privileged trust of fork code, caches, or artifacts; safe
  `download-artifact` handoff if needed.
* `GIT-08` — annotations/summary are `GateResult` projections, no GitHub
  import in `lib/rail_verdict/verification` or `lib/rail_verdict/contracts`.
