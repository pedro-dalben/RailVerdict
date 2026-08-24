# First-10 External Adoption Tracker

Milestone: **10 genuine external adoption attempts** (secondary ≥5 `FIRST_CHECK`, aspirational ≥3 `ADOPTED`). No synthetic/maintainer-seeded rows. IntegrarPlus and railverdict-lab do not count (internal dogfooding).

## Adoption states

- **DISCOVERED:** external party learned of RailVerdict (issue/discussion/social).
- **INSTALL_ATTEMPTED:** tried gem/bundle installation.
- **INSTALLED:** `railverdict` executable runs from project bundle (`doctor` executable).
- **FIRST_CHECK:** at least one real `railverdict check` completed (any gate), not a synthetic repo created by maintainer.
- **ACTIVE_TRIAL:** repeated local or CI use across days.
- **ADOPTED:** integrated into normal local or CI workflow (e.g., PR workflow uses `check --changed --base`, or team policy requires PASS before merge).
- **ABANDONED:** tried then stopped; record reason.
- **BLOCKED:** cannot proceed due to reported RailVerdict bug; link issue.

*Stars do not count; only installation/check/adoption evidence counts.*

## Tracker

| # | Project | Public/private | Ruby | Rails | Status | Blocker / Issue | Outcome |
|---|:---:|---|---|---|:---:|---|---|
| _ | _ | _ | _ | _ | _ | _ | _ |
| 1 |  |  |  |  | DISCOVERED |  |  |
| 2 |  |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |  |
| 6 |  |  |  |  |  |  |  |
| 7 |  |  |  |  |  |  |  |
| 8 |  |  |  |  |  |  |  |
| 9 |  |  |  |  |  |  |  |
| 10 |  |  |  |  |  |  |  |

Fill via `docs/adoption/external-adoption-template.md` per attempt (voluntary, no telemetry, no private source).

## Current counts (maintainer updates)

- Attempts: **0**
- FIRST_CHECK: **0**
- ADOPTED: **0**
- BLOCKED: **0**

_Target: 10 / ≥5 / ≥3. Progress is an ongoing post-goal metric; engineering goal completes at `PUBLIC_LAUNCH_COMPLETE / EXTERNAL_ADOPTION_READY` infrastructure readiness._

## External vs internal (firewall)

External means **not RailVerdict itself, not railverdict-lab, not synthetic repos created solely by maintainer**. Lab remains the regression oracle; IntegrarPlus remains internal dogfooding.
