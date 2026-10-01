# After Task: auto-d-recovery (rank-recovery simulation for latent(d = "auto"))

**Branch**: `claude/lane-auto-d-recovery` (local only, not pushed, no PR)
**Date**: 2026-09-30
**Roles (engaged)**: Opus conductor (design, verification, verdict); Sonnet 5.5 subagents (scouting, script writing, this draft)

## 1. Goal

Measure how often `gllvmTMB(..., latent(d = "auto"))`, whose default criterion is `bic_sites`, selects the true latent rank on simulated data with known rank, across four families and the sizes a user would meet. Deliver a recovery table with Monte Carlo uncertainty, the scripts and seeds that reproduce it, the pre-run test that sized it, and a per-family verdict on whether the default can be recommended. Test only: no package code changes.

## 2. Implemented

- ADEMP design written before any run (`design.md`), with the verdict rule fixed in advance.
- Simulation scripts (`sim/0_grid.R`, `sim_dgp.R`, `sim_fit.R`, `1_run.R`, `2_summarise.R`) with per-dataset seeds stored in the grid, resumable per-dataset RDS output and a saved `sessionInfo`.
- Pre-run test on Totoro (`prerun.md`): `gllvmTMB(d = "auto")` matched `select_lv()$selected_d` on 4 of 4 datasets; recomputed `bic_sites` matched the package pick on 215 of 215; 0 aborts. It set the phase split.
- Campaign: 13,789 datasets, 282 CPU-hours on Totoro. Phase A (all cells except NB at n = 400) finished 12,998 of 12,998 with 0 errors. Phase B (NB at n = 400) ran at 100 replicates per cell by Shinichi's choice and landed 571 of 582 tasks.
- Diagnostic arm (`ridgeoff.md`): binomial with the loading ridge off (`binary_ridge = Inf`), paired seeds, 756 of 900 datasets.
- Recovery table (`results/recovery-table.md`, `.csv`), `results/grid.rds`, `results/sessionInfo.txt`, and a per-family verdict (`verdict.md`).
- Verdict: Gaussian and Poisson recommended; NB2 recommended with a floor of 16 traits; binomial (Bernoulli) not recommended. No bug found.

## 3a. Decisions and Rejected Alternatives

- Decision: split the campaign into phase A and phase B. Rationale: the pre-run projection (2 to 2.5 h wall) was too close to the 3 h line to commit blind. Rejected: launching all 14,400 tasks at once.
- Decision: NB at n = 400 at 100 replicates per cell (Shinichi chose option a). The design named this as its fallback. Rejected: 200 replicates, which would have exceeded the 3 h line.
- Decision: stop the ridge-off arm and phase B at their pre-set lines (09:45 at 756 of 900; 10:14 at 571 of 582) under the overrun rule. Rejected: extending them; the binomial finding does not depend on the missing 144 datasets.
- Decision: report AIC versus `bic_sites` as a finding and leave the default alone. A family-specific default is a design choice for Shinichi. Confidence in the finding: moderate to high on this DGP; it is conditional on loadings N(0, 1).
- Decision: no reproducer written, because no bug was found. The falling unpenalised log-likelihood on ridged binomial fits is documented behaviour (`R/select-lv.R:571-586`).

## 4. Files Touched

All under `docs/dev-log/lanes/auto-d-recovery/` on this branch:
- `LOOP/GOAL.md`, `LOOP/checkpoint.md`, `LOOP/arcs.md`, `LOOP/ultra-plan.md`
- `design.md`, `prerun.md`, `ridgeoff.md`, `verdict.md`
- `sim/0_grid.R`, `sim/sim_dgp.R`, `sim/sim_fit.R`, `sim/1_run.R`, `sim/2_summarise.R`
- `results/grid.rds`, `results/recovery-table.csv`, `results/recovery-table.md`, `results/sessionInfo.txt`
- `after-task.md`, `handover.md` (this report and the handover, drafted uncommitted)

Nothing was touched in `R/`, `man/`, `NAMESPACE`, `NEWS.md`, `inst/`, `tests/` or `docs/dev-log/check-log.md`. The true-parity lane asked on 2026-09-30 that nothing under `tests/testthat` be edited because the 0.7.1 CRAN release lane owns it; this lane complied.

## 5. Checks Run

- Local smoke on 2 tiny datasets per family before Totoro: passed.
- Pre-run on Totoro: 215 of 220 datasets finished when read; auto equals `select_lv()` 4 of 4; recomputed `bic_sites` equals package pick 215 of 215; 0 aborts, 0 task errors.
- Phase A: 12,998 of 12,998 finished, 0 errors. Phase B: 571 of 582, 11 long NB fits stopped at the overrun line.
- Final table: 13,789 datasets, 0 degenerate redraws, 9 datasets with no eligible fit (3 binomial, 6 NB), counted as not correct. The recomputed pick matched the package's on every dataset.
- `Rscript ~/shinichi-brain/tools/check-after-task.R after-task.md` and `slop_check.py` on both documents; results are in the hand-back report.
- Not run: `devtools::check()`, `test()` and `document()`, because no package file changed.

## 6. Tests of the Tests

- The equality checks (auto versus `select_lv()`, recomputed `bic_sites` versus package) would fail if the runner mis-transcribed the selection rule or the criterion column; they passed on every dataset.
- The ridge-off arm used the same seeds as the main run, so the comparison is paired and a difference cannot come from different draws.
- Not tested: whether the scripts recover a deliberately broken selector. No negative control was run. Gaussian and Poisson near 1.0 give a positive control for the DGP and fit path; the Julia twin agrees on those families.

## 7a. Issue Ledger

No GitHub issue inspected or created. No bug found. Leads (candidate causes, not tested):
- NB with few traits over-selects at large n (n 400, p 8, d 3: 21% over). Possible cause: the size-2 NB variance is absorbed by an extra factor when p is small.
- Binomial under-selection reflects low information in binary data at these sizes; the ridge is ruled out as the cause.
- 11 NB n = 400 datasets and 144 ridge-off datasets are unfinished.

## 8. Consistency Audit

- Patterns checked: any change under `R/`, `man/`, `NAMESPACE`, `NEWS.md`, `inst/`, `tests/`, `check-log.md` (none; `git diff` scoped to this folder).
- Sibling failure class: every family and cell was summarised under the same rule, so a binomial-style shortfall would show in any other family. NB p = 8 at d = 3 is the second such case and is reported in `verdict.md`.
- Verdict figures in `verdict.md` were compared against `results/recovery-table.md` by the conductor when written; they were not re-derived in this drafting pass.

## 9. What Did Not Go Smoothly

- The R library copies in `~/R/lib` on Totoro fail under R 4.6.1 with an undefined symbol `SETLENGTH`. The lane built its own library at `~/autod-recovery/lib` (gllvmTMB 0.8.0.9000 from `e68391469`, plus rebuilt rlang, vctrs, lifecycle, pillar, tibble, tidyselect, dplyr). fmesher failed to rebuild and was not needed.
- Two runs overran their estimates: the ridge-off arm (estimate 20 to 40 min, stopped at 756 of 900) and phase B (stopped at 571 of 582). The ridge-off cost was about 21 s per dataset against 3.7 s with the ridge on, which the estimate did not anticipate.
- The pre-run projection was an underestimate because the slowest NB n = 400, p = 16 datasets had not finished when it was read.

## 10. Known Residuals

- 11 NB n = 400 datasets and 144 ridge-off datasets (n = 400, p = 16) were not run to completion.
- All results are conditional on one signal strength (loadings N(0, 1)), NB size 2, Gaussian sd 0.5, single-trial binomial.
- The NB over-selection cause is a lead, untested.
- The raw per-dataset RDS files are not committed. They live on Totoro (`~/autod-recovery/`, 13,789 task files in `out/res`, 756 in `ridgeoff/out/res`) and in `/private/tmp/claude-503/autod-pull` on the Mac, which is scratch and will be purged.
- Branch is committed locally only. Push, PR, merge and any public claim about recovery are gates for Shinichi.
- The lane lease is still held; see `handover.md` for the release command.
- This drafting pass has not been committed.


## 11. Team Learning

- Estimate from the slowest cells; the median hides the cost. NB at n = 400 dominates cost; the finished-datasets projection understated it.
- A pre-run test that checks the recomputed criterion against the package pick catches transcription errors cheaply.
- A guard being green does not make a selector good: the binomial result is an information limit, and only the ridge-off arm ruled out the guard and the ridge.
- Routed guards: the GOAL fences (release-owned files, no push, 3 h line, no Actions for the campaign) shaped the work. The `route.py` LOAD-FIRST manifest was not run in this lane. Golden Set (`memory_regression.py`) was not run; no known-mistake class was in scope. The earlier auto-d after-task and the Julia twin PR were used as prior evidence.
- Candidate for `WHAT-WORKS`: split a campaign at the costliest cell, run the cheap part first, then decide the rest with Shinichi.

## 12. Cross-Product Coverage

Cross-cutting axes touched: family, n_units, n_traits, true d, criterion, ridge (binomial only).

Covers: Gaussian, Poisson, NB2, Bernoulli; n_units 50, 150, 400; n_traits 8, 16; true d 1, 2, 3; criteria `bic_sites`, `bic`, `aic`, `aicc`; ridge scale 2 (default) and Inf (binomial, n <= 400 except 144 datasets).

This lane does NOT cover: true d = 0 or d > 3; other signal strengths, NB sizes or Gaussian noise levels; multi-trial binomial; models with covariates, row effects, `unique = TRUE` or structured latent terms (`d = "auto"` refuses them); `require_converged = TRUE`; ridge scales other than 2 and Inf; other families (Gamma, Beta, ordinal, Tweedie, zero-inflated); the 11 stopped NB datasets and the 144 ridge-off datasets at n = 400, p = 16; optimizers other than BFGS.

