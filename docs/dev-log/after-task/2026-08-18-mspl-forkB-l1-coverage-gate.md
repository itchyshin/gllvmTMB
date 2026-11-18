# After-task — L1 coverage-gate harness + local 50-rep receipt (rescue PR)

**Date:** 2026-08-18
**Lane:** `cursor/mspl-forkB-l1-coverage-pr-20260818` (rescued from local-only `cursor/mspl-forkB-l1-coverage-gate-20260818`)
**Platform:** cursor. **Base:** `origin/main` @ `12808d1b` (#1129).
**Design:** `docs/design/125-mspl-profile-led-intervals.md`
**Pre-registration:** `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` (ADEMP P1–P3, P5 L1)

## Headline

A `main`-based PR lands the Design 125 fork-B **L1 coverage-gate** library, runner, arithmetic tests, and one local 50-rep anchor receipt. The L0 `R/mspl.R` unlock that produced the receipt is **not** in this PR — that door is [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130). Against current `main` the harness reports `NOT-RUN`. The receipt is a local smoke, not a Totoro `covered` claim.

## Why a separate PR (not folded into #1128)

[#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) is the ADEMP harness (`dev/mspl-forkB-l1-ademp.R` + E1-only smoke). This PR is the coverage-gate runner (`dev/mspl-forkB-l1-lib.R`, `dev/mspl-forkB-l1-coverage-smoke.R`) plus an 800-row table that also measures E2. Different files and a different estimand set. #1128 is also `CONFLICTING` with `main`; folding would fight.

The original local branch also carried two L0 commits that unlock `Q_0` on `R/mspl.R`. Those were dropped so this PR does not fight #1130.

## What landed

| File | Role |
|---|---|
| `dev/mspl-forkB-l1-lib.R` | Frozen cells/seeds, DGP, refusal-priced coverage, Wilson, L1 gate, mock door, replicate-cluster bootstrap |
| `dev/mspl-forkB-l1-coverage-smoke.R` | Door resolver + campaign loop. Consumes L0; does not build a door |
| `tests/testthat/test-zz-mspl-forkB-l1-gate.R` | Gate arithmetic + cluster bootstrap on synthetic tables (no fitting) |
| `docs/dev-log/research/2026-08-18-mspl-forkB-l1-coverage-smoke.{tsv,rds,md}` | Local 50-rep receipt |
| `docs/dev-log/after-task/2026-08-18-mspl-forkB-l1-coverage-smoke-scaffold.md` | Earlier scaffold note (gate was `NOT-RUN` that morning) |

Nothing in `R/`, `src/`, `NAMESPACE`, `NEWS.md`, or the validation register.

## Local 50-rep result (not `main`-reproducible yet)

Measured on the L0 worktree against `.gllvmTMB_mspl_profile_feasibility(tape = "Q_0")`, fork B, unpenalized tape, 2026-08-18 06:50.

- **anchor / E1:** 374/400 covered, `cov_eff = 0.9350`, Wilson [0.9065, 0.9553], availability 1, refusal 0 → L1 **PASS**. Cluster bootstrap mean 0.9353, boot [0.9124, 0.9575], design effect 0.991.
- **anchor / E2:** 400/400 `R-ENV` → **NOT-EVALUABLE**. The door still refuses `theta_rr_B`. This is not a pass.

## Fences held

- `#1077` stays draft (verified `isDraft: true` at rescue).
- No public `se` / `vcov` / `confint`; `calibrated` is never `TRUE`.
- MSPL-04 stays `blocked`.
- No Totoro, no T\* freeze, no NEWS `covered`.
- Local compute only (D-50). The runner has no `sbatch` / `srun` path.

## Checks

```sh
NOT_CRAN=true Rscript --vanilla -e \
  'pkgload::load_all(".", compile=FALSE, quiet=TRUE); testthat::test_file("tests/testthat/test-zz-mspl-forkB-l1-gate.R")'

OMP_NUM_THREADS=1 NOT_CRAN=true Rscript --vanilla \
  dev/mspl-forkB-l1-coverage-smoke.R --cells=anchor --n-rep=50
# On current main: L1_STATUS: NOT-RUN (no fork-B selector on the landed probe)
```

Deliberately not run: `devtools::check()`, `pkgdown::check_pkgdown()` — no package surface. The 50-rep walk itself was not re-run on this `main` checkout; the table is the L0-worktree receipt.

## Follow-up

1. Re-run the smoke after #1130 merges so the receipt is `main`-reproducible.
2. E2 stays unevaluable until the fork-B door admits loadings — that is L0's call, not this harness's.
3. Not owed here: T\*, Totoro, register/NEWS movement, undraft of #1077.
