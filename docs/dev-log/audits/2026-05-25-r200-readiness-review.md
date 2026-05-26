# r200 readiness review - Grace with Curie/Fisher lens

**Date:** 2026-05-25
**Author:** Grace, with Curie/Fisher lenses.
**Status:** Readiness review only. No GitHub Actions workflow was
dispatched, no r200 or long simulation was run, and no check-log,
ROADMAP, pkgdown, article, random-effects, or open-PR-owned file was
edited.

## Failures / blocking conditions

1. **Current workflow timeout is the concrete dispatch blocker.** The
   workflow job timeout is 120 minutes per cell. The completed r10
   postpatch run 26412130690 spent the following time in the `Run M3
   cell` step:

   | Cell | r10 M3 step | Linear r200 projection |
   |---|---:|---:|
   | binomial d=1 | 7m12s | ~144 min |
   | binomial d=2 | 10m30s | ~210 min |
   | binomial d=3 | 13m24s | ~268 min |
   | mixed d=2 | 14m21s | ~287 min |

   Linear scaling is imperfect, but the margin is too large to ignore.
   Even the narrow two-cell scope contains binomial d=2 and mixed d=2,
   so it is not ready for dispatch under the current per-job timeout.
   Before any r200 run, either shard replicates per cell, raise the
   timeout with explicit maintainer approval, or reduce per-cell work
   after a separate design decision.

2. **Reduced scopes require a workflow matrix subset patch.** The
   current workflow matrix is the full 5-family x 3-rank grid. Options
   A and B are not selectable by current workflow inputs; they require a
   temporary matrix-subset branch or equivalent selector. Option C can
   dispatch with the current matrix, but it has the largest timeout and
   review burden.

3. **No validation-debt row can move on r10 evidence.** Design 50
   requires target-explicit total `Sigma_unit[tt]` coverage >= 0.94 at
   R = 200, plus clean failure-rate and miss-side gates. The postpatch
   r10 run is useful admission evidence only; CI-08 and CI-10 remain
   `partial`.

## Scope options

| Option | Cells | Evidence value | Runtime / CI risk | Artifact review burden | CI-08 / CI-10 effect if r200 clears |
|---|---|---|---|---|---|
| A - narrow 2-cell | binomial d=2; mixed d=2 | High for the two r10 `PASS_TO_SCALE` surfaces; weak for rank-general binomial claims | High under current workflow because both cells project beyond 120 min; needs subset patch plus timeout/sharding fix | 4 RDS files; smallest review | CI-08 can only cite a binomial d=2 slice unless the register row is deliberately narrowed. CI-10 can only cite mixed d=2. |
| B - binomial-focused 4-cell | binomial d=1,2,3; mixed d=2 | Best decision value: tests whether the corrected binary DGP is stable across rank, while retaining the one mixed cell that passed admission | High under current timeout; needs subset patch and timeout/sharding fix. Lower waste than full grid once the timeout problem is fixed | 8 RDS files; manageable but needs per-cell review, not only aggregate review | If all three binomial cells clear, CI-08 can move for the binomial-family r200 slice with explicit scope. If mixed d=2 clears, CI-10 can move for mixed d=2 only. No claim for nbinom2, ordinal-probit, or mixed d=1/d=3. |
| C - full 15-cell | all 5 families x d=1,2,3 | Highest comparability to r10 and strongest failure map; low marginal promotion value because nbinom2 and ordinal-probit already have known target/compute failures | Highest. Multiple cells project beyond timeout; ordinal-probit remains a Design 50 no-go for bootstrap support; full run risks wasting CI and artifact retention | 30 RDS files; highest review and provenance burden | Could update CI-08/CI-10 only cell-by-cell. Failed nbinom2 / ordinal / mixed cells would keep broad rows partial and require a larger failure memo. |

## Recommendation

**Choose Option B as the statistical scope, but do not dispatch until
the workflow timeout/sharding issue is solved.**

Curie/Fisher reason: Option A is too narrow to support a family-wide
binomial readiness claim, while Option C spends most compute on cells
that r10 and Design 50 already identify as non-promotable. Option B is
the smallest scope that answers the useful question: whether the
corrected binomial DGP supports target-explicit `Sigma_unit[tt]`
coverage across ranks, with one mixed-family d=2 bridge for CI-10.

Grace reason: with the current workflow, none of A/B/C is dispatch-safe
at r200 because the selected cells likely exceed the 120-minute job
timeout. The scope decision and the CI plumbing decision should be
separated: approve Option B as scope, then prepare a small dispatch
branch that shards or extends timeout before launching.

## PR-stack dependency check

Open PRs at review time:

- **#261** touches README, ROADMAP, check-log, one after-task report,
  and two vignettes. It does not touch `.github/workflows/m3-production-grid.yaml`,
  `dev/m3-grid.R`, or `dev/precompute-m3-grid.R`. No r200 dependency.
- **#265** touches diagnostic-table code/docs, `_pkgdown.yml`, the
  validation-debt register, ROADMAP, check-log, and tests. It does not
  touch the M3 workflow or M3 simulation drivers. No r200 dispatch
  dependency. Its register edits may create review sequencing after
  r200 results, but they do not block dispatch.
- **#267** owns the r200 dispatch plan and Set C audit docs. It is
  useful planning context but docs-only. Dispatch does not technically
  depend on it being merged, although merging it first would reduce
  duplicate planning prose.

Conclusion: the current PR stack does **not** technically block r200
dispatch. The real blocker is workflow runtime/timeout readiness.

## Post-run artifact review checklist

Before any register promotion, review all downloaded artifacts, not only
the summary tables:

1. Confirm each artifact meta block records `n_reps = 200`,
   `targets = psi,Sigma_unit_diag`, `n_boot = 25`, `seed_base`,
   `ci_level`, `init_strategy`, `start_method`, `optimizer`, `n_init`,
   `n_units`, `n_traits`, and package/R versions.
2. Confirm the long grid has the Design 50 columns: `target`,
   `ci_method`, `ci_level`, `fit_phi_mode`, `link_residual` or declared
   equivalent, `n_boot`, `n_cores_boot`, `seed_base`, and scenario/cell
   identifiers.
3. For `target == "Sigma_unit_diag"` only, compute coverage by cell and
   trait rows. `psi` profile rows are diagnostic and must not be used
   as the promotion target.
4. Check fit-failure rate <= 20% for binomial and <= 30% for mixed;
   CI-missing rate <= 10%; bootstrap-failure rate within the same
   family-specific limit; no one-sided miss pattern with >= 80% misses
   on one side.
5. Confirm failed fits and missing intervals remain in the long grid and
   are not dropped from summaries.
6. Check median estimate/truth ratios by trait for target-scale bias,
   especially binomial d=1/d=3 and mixed d=2.
7. Confirm artifact names and run URL are stable enough for the register
   evidence field and that retention is long enough for review.
8. Promote CI-08 / CI-10 only with explicit scope text. No broad
   non-Gaussian or all-rank claim should be inferred from unrun or failed
   cells.

## Commands run

Read-only shell and GitHub queries only:

- `git status --short --branch`
- `git log --all --oneline --since="6 hours ago"`
- `gh pr list --state open --json number,title,headRefName,baseRefName,author,updatedAt,isDraft --limit 30`
- `gh pr diff 261 --name-only`
- `gh pr diff 265 --name-only`
- `gh pr diff 267 --name-only`
- `gh pr view 261 --json number,title,headRefName,mergeStateStatus,isDraft,statusCheckRollup,commits,files`
- `gh pr view 265 --json number,title,headRefName,mergeStateStatus,isDraft,statusCheckRollup,commits,files`
- `gh pr view 267 --json number,title,headRefName,mergeStateStatus,isDraft,statusCheckRollup,commits,files`
- `gh run view 26412130690 --json jobs,conclusion,status,createdAt,updatedAt,url`
- `gh run view 26412130690 --json jobs --jq '.jobs[] | {name, m3: (.steps[] | select(.name=="Run M3 cell") | {startedAt, completedAt})}'`
- `rg --files docs/dev-log/audits docs/design . | rg "(m3|M3|r200|50-m3-3b|42-m3|AGENTS.md)$|postpatch|dispatch-plan|readiness"`
- `rg -n "r200|CI-08|CI-10|postpatch|#267|261|265" /Users/z3437171/.codex/memories/MEMORY.md`
- `nl -ba AGENTS.md | sed -n '1,260p'`
- `nl -ba docs/design/50-m3-3b-surface-admission.md | sed -n '1,260p'`
- `nl -ba docs/design/42-m3-dgp-grid.md | sed -n '1,320p'`
- `nl -ba docs/design/35-validation-debt-register.md | sed -n '286,306p'`
- `nl -ba docs/dev-log/audits/2026-05-25-m3-postpatch-rerun.md | sed -n '1,260p'`
- `git show agent/set-c-r200-prep:docs/dev-log/audits/2026-05-25-m3-r200-dispatch-plan.md | nl -ba | sed -n '1,320p'`
- `git show agent/set-c-r200-prep:docs/dev-log/audits/2026-05-25-set-c-joint-sdm-gate-matrix.md | nl -ba | sed -n '1,260p'`
- `nl -ba .github/workflows/m3-production-grid.yaml | sed -n '1,260p'`
- `nl -ba dev/precompute-m3-grid.R | sed -n '1,620p'`
- `nl -ba dev/m3-grid.R | sed -n '1,1760p'`
- `git diff --stat`
- `git diff --name-only`

## Stop conditions

Do not dispatch r200 until:

- the maintainer approves the r200 scope;
- the dispatch branch has either a subset matrix plus sharding, or a
  maintainer-approved timeout change;
- the branch is based on current `origin/main` and does not reuse this
  dirty joint-SDM worktree;
- a fresh seed base is chosen;
- retention is long enough for artifact review;
- the reviewer agrees that CI-08/CI-10 promotion will be cell-scoped,
  not generalized beyond the r200 evidence.
