# Model 2 gamma-recovery campaign — results

**1,200/1,200 fits, 0 errors, 14 s wall** on Totoro (100 cores, OPENBLAS
single-thread; install 3 min). Grid: `n_sources {2,3,4}` × mix
{all-PO, (n−1)PO+PA} × effort-ratio {1×, 10×} × 100 seeds. Nonspatial,
150 cells, 3 species, reference-coded `gamma[d,j]`. Raw rows:
`campaign-gamma-recovery-results.csv` (committed beside this note).

| n_sources | mix | eff_ratio | gamma_rmse | gamma_bias | pd |
|---|---|---|---|---|---|
| 2 | allpo | 1 | 0.070 | 0.004 | 0.95 |
| 3 | allpo | 1 | 0.073 | 0.007 | 0.98 |
| 4 | allpo | 1 | 0.075 | 0.009 | 0.95 |
| 2 | pa | 1 | 0.129 | 0.023 | 0.94 |
| 3 | pa | 1 | 0.110 | 0.006 | 0.94 |
| 4 | pa | 1 | 0.102 | 0.004 | 0.97 |
| 2 | allpo | 10 | 0.176 | −0.020 | 0.97 |
| 3 | allpo | 10 | 0.187 | −0.012 | 0.97 |
| 4 | allpo | 10 | 0.185 | −0.001 | 0.95 |
| 2 | pa | 10 | 0.186 | −0.013 | 0.90 |
| 3 | pa | 10 | 0.197 | −0.013 | 0.94 |
| 4 | pa | 10 | 0.193 | 0.002 | 0.94 |

Convergence 1199/1200; `pd_hessian` PASS 1140/1200 (95%).

## The three readings that matter

1. **Adding sources does not degrade recovery.** Within every (mix, effort)
   condition the RMSE is flat in `n_sources` — 0.070/0.073/0.075 at the
   easiest cell, 0.186/0.197/0.193 at the hardest. This answers Fisher's
   planning question: at these settings, near-collinear PO arms are a
   conditioning non-problem. More arms even help slightly on the PA mix
   (0.129 → 0.102), consistent with more total information about the shared
   field.
2. **Effort ratio, not source count, drives error.** Dropping the
   non-reference arms to a tenth of the reference effort roughly doubles
   RMSE (~0.07–0.13 → ~0.18–0.20). The practical advice writes itself: a
   weak extra source costs precision on its own gamma, not on the others'.
3. **Bias is negligible everywhere** (|mean bias| ≤ 0.023), so the RMSE is
   variance, not systematic error — reference coding `gamma[1,j] = 0` is
   behaving at every measured n.

## Boundaries (unchanged from the register row)

Nonspatial; one design size (150 cells, 3 species); reference-coded gammas as
the estimand; no intervals; no per-source bias covariates. `pd_hessian` at
90–98% is healthy for this arm but is a *rate*, not a guarantee — the check
stays mandatory on every fit.
