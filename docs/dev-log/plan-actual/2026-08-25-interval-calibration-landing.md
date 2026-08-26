# Melissa reconciliation: interval-calibration landing

Date: 2026-08-25
Branch: `codex/interval-calibration-landing`
Exact base: `1bacee9a808b4106ce681502463baa317dcb9d9b`
Completed source tip: `4ba533949d7dae264268ae55f3c7fc801ee87da5`

## Plan versus actual on six axes

| Axis | Planned | Actual | Assessment |
| --- | --- | --- | --- |
| Scope | Land the completed CI-08--CI-15 programme on current main without new science, API, C++, LV, or random-slope work. | All 34 source commits and 103 paths were accounted. No new estimator, campaign, API, C++, workflow, LV, or random-slope work was added. | On scope. |
| Evidence and verification | Preserve all evidence, denominators, hashes, and exact route states. | The 150,019-row all-attempt ledger and 18-row target table retain their exact hashes. The 19-route census and exactly three CI-13 certificates pass the claim oracle and focused tests. | Exact preservation demonstrated. |
| Model and review routing | Use Rose for claim boundaries, Grace for reproducibility, and Fisher for statistical invariance. | Each perspective reviewed the exact reconciliation candidate. Final verdicts are recorded in the closure gate and handover. | On plan. |
| Safety and coordination | Preserve active random-slope/LV lanes with exact leases and no public action. | A frozen two-lane global snapshot plus a fail-closed 110-path final delta oracle passed. The old-base negative control failed as intended. No push, PR, merge, release, workflow action, or remote compute occurred. | On plan, with documented sandbox fallback. |
| Public claims | Do not strengthen or weaken the terminal programme ledger during landing. | CI-08 remains route-only; only three exact CI-13 regimes remain certified; all other terminal states are unchanged. | Exact claim invariance. |
| Landing and handoff | Fresh local branch, audited replay, Unlazy `--reverify`, narrow commits, after-task, handover, and importable bundle. | The linked worktree metadata was read-only, so a real ignored nested clone was used. Replay and evidence gates pass; closure documents and bundle complete the same local-only outcome. | Adaptive implementation, no scope drift. |

## Material deviations

The planned desktop worktree could not create its linked Git `index.lock`, and
app-level worktree creation did not complete. The landing therefore used an
isolated nested clone whose first parent is the exact current-main snapshot.
This changes storage location, not ancestry or scope. It also makes the final
branch portable through a verified Git bundle.

The global lease registry was not writable from the sandbox. The replacement
control combined an exact workspace-local lane lease, four disjoint Unlazy
ownership locks, a frozen global foreign-lease snapshot, and a fail-closed
path-delta verifier. The limitation is retained in the handover.

## Melissa verdict

**ON PLAN, WITH A TRANSPARENT SANDBOX ADAPTATION.** The landing reproduced the
completed programme on current main, preserved active foreign lanes and every
scientific boundary, and added only auditable landing and closure receipts.
