# B_lv profile-interval coverage campaign (orthogonal Model A, Gaussian)

Production ADEMP coverage evidence for the **profile confidence interval** of the
predictor-informed latent-score effect `B_lv = Λ_B·α^T`, under the **orthogonal
Model A**:

```r
value ~ 0 + trait + latent(0 + trait | species, d = K_B, lv = ~x) +
        phylo_latent(0 + trait | species, d = K_phy, tree = tree)
```

The estimand is the **ordinary** predictor-informed latent effect, recovered **with an
orthogonal `phylo_latent(tree=)` term present**. This is **not** the interacting `LV-08`
estimand (predictor-informed phylo innovations); `LV-08` stays `blocked`.

## Result — production gate PASSED (rank-1 Gaussian)

Ran on Totoro (`dev/lv-effects-ci-coverage.R`), one seed per task, ≥500 reps/cell,
audit band 0.92–0.98, nominal 0.95.

| Cell | S | T | K_B | K_phy | Coverage | MCSE | Reps | Mean width |
|---|---|---|---|---|---|---|---|---|
| gauss-S60-K1-smalln | 60 | 4 | 1 | 1 | **0.952** | 0.0096 | 500/500 | 0.249 |
| gauss-S100-K1 | 100 | 5 | 1 | 1 | **0.950** | 0.0097 | 500/500 | 0.289 |
| gauss-S200-K1 | 200 | 5 | 1 | 1 | **0.962** | 0.0086 | 500/500 | 0.159 |

All three sit on nominal 0.95 (within MCSE), inside the band, at production denominator.
The rank-2 hard cell (`gauss-S200-K2-hard`) uses the slower report-based profile and was
still running at close — to be appended.

## Files

- `SUMMARY.txt` — the `summarise` output (per-cell coverage / MCSE / width / convergence).
- `gauss-*.all.csv` — per-rep rows aggregated across array tasks (per-cell), if present.
- `gauss-*/task-*.csv` — raw per-task per-rep outputs (attempted / converged / covered / width).

## Method

- **Profile is the hero** (`profile_ci_lv_effects()`): inverts the LR test per `B_lv` entry via
  constrained refit, with a **t reference** (`df = n_units − d − 1`) and an analytic-gradient
  fast path. Wald is `NA` here (non-PD Hessian from the ordinary-vs-phylo latent-variance
  trade-off on the shared `species` grouping) — the "pdHess≠failure → route through profile"
  case. Variance components are **REML** (unbiased).
- Coverage = fraction of reps whose profile CI for `B_lv[t1]` contains the known truth.
