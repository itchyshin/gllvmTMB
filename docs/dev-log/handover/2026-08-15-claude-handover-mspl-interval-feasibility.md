# Session Handoff: private LA-MSPL binary interval-feasibility adjudication

**Date:** 2026-08-15

**From:** Codex

**To:** Claude

**Working directory:** `/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB`
**Branch / exact HEAD:** `codex/lane-b-mspl-interval-feasibility` @ `701821219f73c3373ce97a19cb2492a3f94cf546`

## Mission and claim boundary

This lane asked whether the selected ordinary q=1 LA-MSPL fixed-effect
interval routes could be made *calibrated and public* across the 36-cell
matrix (four deterministic regimes x logit/probit/cloglog x three resolved
`b_fix` coordinates). The answer now earned by the completed private campaign
is **no, not with the present estimator and proven method class**.

This is not a claim that no future MSPL uncertainty theory can work. It is a
decision not to promote `vcov()`, `confint()`, `profile_targets()`,
`tmbprofile_wrapper()`, or public bootstrap for MSPL from these results. Keep
every existing MSPL public refusal fail-closed.

The active profile objective is always penalised `fit$tmb_obj`
(`estimator_id = 1`); the penalty-off tape is provenance / paper-style
likelihood-curvature diagnostic material only. Do not substitute it for the
profile objective.

## What is DONE

1. Private endpoint feasibility was established for the selected deterministic
   q=1 fixtures: finite penalised-objective profile endpoints and bootstrap
   endpoints exist. This is feasibility, not calibrated confidence-interval
   evidence.
2. The full direct coverage calibration campaign completed and is immutable
   outside Git. It used 1,200 shards, 12,000 outer fits, 6,000,000
   unconditional bootstrap refits, 108,000 endpoint rows, and 1,159,993
   profile-trace rows.
3. The all-36 public-promotion gate failed:

   | Route | Jointly passing cells (availability + coverage) |
   | --- | ---: |
   | Penalised nuisance-reoptimised profile | 24 / 36 |
   | Unconditional percentile bootstrap | 20 / 36 |
   | Paper-style likelihood-curvature Wald | 9 / 36 |

   The direct campaign had 106/108 route-target availability gates pass,
   54/108 coverage gates pass, and only 53/108 joint passes. The two profile
   availability failures were `C003` target 3 (945/1,000) and `C010` target 1
   (928/1,000), both below the predeclared 95% floor.
4. Bootstrap re-expressions do not repair the result. Private reanalysis of the
   same 6M refits gave 20/36 percentile, 14/36 basic, 15/36 normal, 17/36
   bias-corrected-normal, and 2/36 non-accelerated BC passes.
5. Wider constrained-inversion diagnostics are not a solution: at fixed
   centred ranges of +/-2 and +/-4, only 6/36 and 9/36 target sides respectively
   rejected both boundaries; a centred-pivot reanalysis yielded 1/36 at either
   range. The frozen +/-1 pre-run had no finite two-sided intervals. Do not
   spend the planned 2,102 core hours / 52.6 wall hours on that production run.
6. The current active LA-MSPL objective has no per-unit active-score
   decomposition. A standard Godambe/sandwich route is consequently not
   available without defining a new estimator-level construction. A
   delete-one-site construction would be a new jackknife candidate; it is not
   in the original MSPL paper and Shinichi explicitly rejected adding it here.
7. Commit `70182121` centres the private constrained-inversion grid on the
   observed MSPL `b_fix`, not the simulated truth. Its focused test passed with
   43 expectations. It changes only:

   - `inst/sim/lane-b-uncertainty/run-mspl-constrained-inversion-calibration.R`
   - `tests/testthat/test-mspl-constrained-inversion-calibration.R`

## Authoritative evidence and immutable artefacts

Read these before proposing another method or campaign:

- `docs/dev-log/after-task/2026-08-14-lane-b-mspl-coverage-calibration-production.md`
- `docs/dev-log/plan-actual/2026-08-13-lane-b-mspl-interval-feasibility-arc.md`
- `docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production/README.md`
- `docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production/gate-map-108.tsv`
- `docs/dev-log/recovery-checkpoints/2026-08-15-codex-mspl-inversion-checkpoint.md`

The final retrieved direct-campaign root is
`/tmp/mspl-coverage-production-8b23cfd2-eqLdNa` (local, not Git). Its exact
receipt hashes are:

- production receipt: `8232f1a847e6bfeb4626e6b55d033496743aa0e373284ad30a6432aeac277ea1`
- summary: `64b2776010b0f5af4b41d0f764d412853bd43a918fd758c4727ea854af991564`
- 1,200-shard ledger: `1cb6c667f9018784545646dcdda2183766758272e265848e80d1e27691f15fd1`

Temporary, non-claim-bearing diagnostics live under `/private/tmp` and DRAC
`/project`; they are **not versioned and must not be staged**:

- `/private/tmp/mspl-basic-bootstrap-reanalysis.R`
- `/private/tmp/mspl-basic-bootstrap-reanalysis.tsv`
- `/private/tmp/mspl-inversion-centred-pivot-reanalysis.R`
- `/private/tmp/mspl-inversion-r9-bracket-retrieval/`

## OWED next work — a new, separate arc only

There is no remaining safe numerical extension of this binary arc. If Shinichi
wants work to continue, create a **new theory/design lane**, not an extension
of this branch's calibration campaign. Its narrow first task is read-only:

1. determine whether a non-jackknife, estimator-defined pivot or influence
   construction exists for LA-MSPL across logit, probit, and cloglog;
2. distinguish a defensible new estimator/theory from a post-hoc interval
   transformation; and
3. return a precise proposal or a permanent `MSPL-04` block.

Do not launch a new simulation, invoke a bootstrap transformation, widen a
grid, or activate a public method before a maintainer chooses that new route.
Claude is appropriate for the theory, literature-grounding, source review, and
design packet. Codex must own any later live R/TMB or DRAC fit campaign.

The primary paper is Sterzinger & Kosmidis (2023),
<https://link.springer.com/article/10.1007/s11222-023-10217-3>. It supports the
historical paper-style logistic curvature diagnostic, not public profile or
bootstrap inference for this package extension.

## Protected boundaries and gotchas

- No calibrated-SE, nominal-95%, or public interval claim has been earned.
- No q=2, spatial, phylogenetic, weighted, missing-data, loading, covariance,
  latent-effect, or derived-quantity MSPL inference is in scope.
- Never optimise the penalty-off provenance tape or treat the MSPL point as an
  ML estimate.
- Retain failures; no replacement draws, pseudoinverses, eigenvalue repair,
  automatic Wald substitution, or adaptive grid enlargement.
- The sibling Cursor MSPL programme is an independent lane. Do not edit its
  files. The conventional snapshot pointer is intentionally unchanged; use
  `docs/dev-log/handover/2026-07-25-active-lane-split.md` and
  `docs/dev-log/coordination-board.md` for cross-lane context.

## Landing state

| Item | State | Resume / restriction |
| --- | --- | --- |
| Private binary interval-feasibility source and evidence | `DONE` locally | Already committed through `70182121`; public fence remains closed. |
| Full coverage campaign | `DONE` | Artefacts retained locally/DRAC; results reject promotion. |
| Public MSPL intervals or SEs | `RETRACTED` | Do not enable any public dispatch from this campaign. |
| New estimator/theory route | `OWED` | Requires a separate maintainer-approved arc; jackknife is rejected unless Shinichi changes that decision. |
| Branch transfer | `CARRIED-OVER` | The branch is 46 unpushed commits at the handoff-gate check; GitHub API was unreachable, so no push or PR was attempted. |

`gh pr list --state open` could not connect to `api.github.com` during this
handoff. The worktree was clean before this handover file. Reconcile all git
facts on receipt; do not assume origin has these commits.

## Claude rehydration recipe

```sh
cd /Users/z3437171/.codex/worktrees/8e9d/gllvmTMB
git status --short --branch
git log --oneline -12
/Users/z3437171/shinichi-brain/tools/lane_preflight.sh "$PWD"
sed -n '1,240p' docs/dev-log/handover/2026-08-15-claude-handover-mspl-interval-feasibility.md
sed -n '1,260p' docs/dev-log/after-task/2026-08-14-lane-b-mspl-coverage-calibration-production.md
```

Then classify each handover item as `OWED`, `DONE`, `RETRACTED`, or
`PROTECTED` against current Git before doing anything. Do not update the
multi-lane snapshot pointer or stage any `/tmp`, DRAC, or sibling-lane file.

Read AGENTS.md and docs/dev-log/handover/2026-08-15-claude-handover-mspl-interval-feasibility.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
