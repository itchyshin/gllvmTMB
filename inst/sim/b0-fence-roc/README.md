# Design 118 B0 -- fence-ROC harness

`docs/design/118-mspl-interval-calibration-protocol.md` s1.2, s1.6, s5.3, s5.4.
Measures the penalty-sensitivity probe (Route A: two extra outer refits at
`c_n/2` and `2c_n` via the `mspl_c_n_multiplier` hook, s7.1) against the
analytic count-attractor labels (A1b Task 1.2) on fresh seeds, across the 12
published DGP cells (C001-C012, the same regime x link grid as the
2026-08-14 archive's `run-mspl-coverage-calibration.R`).

## Files

- `lib-b0-fence-roc.R` -- pure functions: the DGP, the analytic attractor
  root, the L1/L2 labels, the probe statistic and its tiering, the
  penalised-Hessian `se_penalised`, the Route B surrogate, and
  `b0_run_outer()` (one simulated dataset -> a 3-row result). No side
  effects at source time; this is what the tests exercise directly.
- `run-b0-shard.R` -- CLI shard runner. One shard = a contiguous block of
  outer datasets for one cell; writes one CSV to
  `<out>/shards/<case_id>-shard-<NNN>.csv`.
- `consolidate-b0.R` -- reads every shard CSV and reports the probe gate
  (detection on C011 target-3 / false-refusal on the anchors), the Route
  A/B agreement, P2, P5, and per-cell mean seconds/outer-dataset.

## Local smoke

```sh
export GLLVM_TMB_PILOT_SOURCE=true   # this checkout, not the installed library
OUT=/path/outside/repo/b0-fence-roc-smoke
/usr/local/bin/Rscript inst/sim/b0-fence-roc/run-b0-shard.R \
  --case-id C011 --shard-id 1 --outer-per-shard 5 --out "$OUT"
/usr/local/bin/Rscript inst/sim/b0-fence-roc/consolidate-b0.R --out "$OUT"
```

C011 (cloglog x high_prevalence) is the recommended smoke cell: target 3
(truth 2.05) saturates ~93% of the time (diseased), target 1 (truth 1.00)
almost never does (healthy), so a 5-dataset smoke reliably exercises both
labels.

## Full B0 (orchestrator's step, NOT run by this harness alone)

12 cells x 200 datasets x 3 fits/dataset = 7,200 fits (Design 118 s5.3
item 5). Shard with `--outer-per-shard 10` (20 shards/cell x 12 cells =
240 shards), on Totoro, <= 150 cores, `OPENBLAS_NUM_THREADS=1` (D-143,
D-50 -- never GitHub Actions).

## Fresh-seeds discipline

The 2026-08-14 archive's own README forbids reusing its seeds to validate
or tune a method. B0 uses `seed_base = 118,000,000 + case_number *
1,000,000` (range ~1.19e8-1.30e8), disjoint from the archive's
`1,900,000,000 + case_number * 10,000,000` (range ~1.91e9-2.02e9). Same DGP
mechanism, fresh draws.

## Spec vs structure -- where this harness had to choose

Design 118 s1.2 defines `s_j = |S_hat_j| / sqrt((H^-1)_jj)`, where `H` is
the Hessian of the ACTIVE PENALISED objective at the MSPL estimate. The
matching private helper,
`.gllvmTMB_mspl_penalized_hessian_diagnostic()`, exists on branch
`codex/lane-b-mspl-interval-feasibility` (`R/mspl.R`) but is **not** one of
this worktree's two committed prerequisites (`a16e1f26` the c_n multiplier
hook, `0d6de305` the profile bracket-search fix). Rather than adding a third
package-internal function outside the assigned scope, `b0_penalised_se()`
computes the identical quantity itself, directly off `fit$tmb_obj$fn`/`gr`
via `stats::optimHess()` + Cholesky inversion -- the same technique the
ported profile-feasibility probe already uses on the same object. Route B's
surrogate (`b0_route_b_surrogate()`) is a from-scratch implementation of the
`S_hat^surr = -H^-1 grad(l_LA)(theta_hat)` identity in s1.2, using the same
Hessian and `fit$mspl$unpenalized_tmb_obj$gr()` (already present in this
worktree, unrelated to the two committed prerequisites). If the orchestrator
would rather this be a formal package prerequisite (ported into `R/mspl.R`
under its own gate, matching s7's pattern), flag it back -- nothing here
depends on it being one or the other, but the maintainer may want the
canonical implementation in one place.
