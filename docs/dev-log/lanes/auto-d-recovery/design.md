# auto-d-recovery: simulation design (ADEMP)

Lane: `claude/lane-auto-d-recovery`. Frameworks: ADEMP (Morris, White and Crowther 2019, *Stat Med* 38:2074-2102) and the 11 reporting items of Williams et al. (2024, *Methods Ecol Evol* 15:1926-1939). Written 2026-09-30, before any code or run.

## A. Aims

- **Primary.** Estimate how often `gllvmTMB(..., latent(0 + trait | unit, d = "auto"))`, whose default criterion is `bic_sites`, selects the true latent rank, by family, number of units, number of traits and true rank.
- **Secondary 1.** Compare `bic_sites` with `bic`, `aic` and `aicc` on the same sweeps, to judge whether the default can be recommended per family.
- **Secondary 2.** Report how often the guard rejects fits (status other than `ok` / `warm_start`) and how often no fit is eligible, since a failure to select is a usability outcome, not a missing value.

Prior evidence this extends, not repeats: the Julia twin (GLLVModels.jl, 17,569 datasets: Gaussian 0.948, Poisson 0.999, binomial weak; NB 0.934 on 4,794 corrected-kernel datasets) and one R-side Bernoulli ridge check (10 datasets per arm). The R side has no repeated-sampling recovery study; this is it.

## D. Data-generating mechanism

Long format, units i = 1..n, traits j = 1..p, true rank d.

- Latent scores: z_i ~ N_d(0, I_d), independent across units.
- Loadings: Λ (p x d), entries iid N(0, 1). Lower-triangular constraints are the fitter's business, not the DGP's; any Λ is identifiable up to rotation, and the estimand is the rank only.
- Intercepts: β_j ~ U(-0.5, 0.5) for Gaussian and binomial; β_j ~ U(0, 1) for Poisson and NB (mean counts around 2 to 5, so few all-zero traits).
- Linear predictor: η_ij = β_j + z_i' Λ_j.
- Response:
  - Gaussian: y_ij = η_ij + ε_ij, ε_ij ~ N(0, 0.5²).
  - Poisson: y_ij ~ Poisson(exp(η_ij)).
  - Binomial (Bernoulli, 1 trial): y_ij ~ Bernoulli(plogis(η_ij)).
  - NB2: y_ij ~ NB(mean = exp(η_ij), size = 2).
- Degenerate draws: a Bernoulli trait that is all 0 or all 1, or a count trait that is all 0, is redrawn from the same seed stream (up to 20 tries; the count is recorded). This matches what a user would drop before fitting.

Conditions (full factorial, 72 cells):

| factor | levels |
|---|---|
| family | gaussian, poisson, binomial (Bernoulli), nbinom2 |
| n_units | 50, 150, 400 |
| n_traits | 8, 16 |
| true d | 1, 2, 3 |

Candidate set: d = 1..d_max, d_max = min(5, p - 1) = 5 for both p, the value `d = "auto"` uses. d = 0 is never a candidate, so it is not a DGP level.

Replicates per cell: 200. The headline measure is a proportion; the worst-case MCSE is sqrt(0.25 / 200) = 0.035, and at the proportions near 0.9 to 1 the prior evidence suggests, it is 0.021 or smaller. That separates a family near 0.95 from one near 0.80 by more than 3 MCSE, which is the distinction the verdict needs. 72 x 200 = 14,400 datasets. If the pre-run test shows the budget exceeds 3 hours, cut n_units = 400 to 100 replicates before anything else, and say so.

Seeds: master seed 20260930; per-dataset seeds from `sample.int(.Machine$integer.max, 14400)` drawn once from the master and stored in the design grid, so any single dataset can be regenerated alone.

## E. Estimands

- True value: d (per cell, fixed).
- Estimator output: the selected rank d̂ per criterion, the argmin of that criterion over eligible rows of `select_lv()$table`, which is exactly the rule in `R/select-lv.R` (eligible = status in `ok`, `warm_start`). For `bic_sites` this equals `fit$select_lv$selected_d` from `gllvmTMB(d = "auto")`; the pre-run test checks this equality on a handful of datasets rather than assuming it.

## M. Methods

One call per dataset:

```r
select_lv(value ~ 0 + trait + latent(0 + trait | unit, unique = FALSE),
          data = dat, family = <family>, unit = "unit", trait = "trait",
          control = gllvmTMBcontrol(optimizer = "optim",
                                    optArgs = list(method = "BFGS"), se = FALSE),
          d_max = min(5L, p - 1L))
```

All other arguments at their defaults (`warm_start = TRUE`, `require_converged = FALSE`, `binary_ridge = 2` for Bernoulli), because the aim is the behaviour a user gets from `d = "auto"`. `unique = FALSE` matches the DGP, which has no per-trait unit-level term beyond the family's own noise (for Gaussian, the family residual carries ε). Criteria compared: `bic_sites` (default), `bic`, `aic`, `aicc`. No other rank-selection methods: the question is whether the package default can be recommended, not a methods zoo.

Recorded per dataset: seed, cell, the whole `$table` (d, logLik, df, each criterion, status, seconds), d̂ per criterion, whether `select_lv` aborted (and its condition class), warnings count, redraw count, wall time.

## P. Performance measures (per cell x criterion)

- P(correct) = mean(d̂ = d); P(under) = mean(d̂ < d); P(over) = mean(d̂ > d). MCSE sqrt(p(1-p)/n_ok) for each.
- No-selection rate = mean(select_lv aborted). Datasets that abort count as not correct in the headline P(correct) (intention-to-select), and the table also shows P(correct | selected).
- Guard rejection rate = mean over fits of status not in {ok, warm_start}, by d.
- Wall time per dataset: median and 90th percentile.

## Verdict rule (stated before the results)

Per family, `bic_sites` is "recommended" if P(correct) ≥ 0.90 in every cell with n_units ≥ 150, "recommended with a stated size floor" if that holds only at n_units = 400 or only for p = 16, and "not recommended" otherwise. Any cell where another criterion beats `bic_sites` by more than 3 combined MCSE is reported. These words are a lane verdict for Shinichi, not a public claim.

## Williams et al. (2024) self-audit

| item | covered where |
|---|---|
| 1 aims | A |
| 2 DGP | D |
| 3 estimands | E |
| 4 methods | M |
| 5 performance measures (+ formulas) | P |
| 6 software / sessionInfo | saved next to results by the runner |
| 7 code availability | scripts under `docs/dev-log/lanes/auto-d-recovery/sim/` on this branch |
| 8 seeds / reproducibility | D (seeds stored in the grid) |
| 9 worked example | not in scope: this is a validation study, not a paper; noted as NOT covered |
| 10 full results + failures | P (no-selection and guard-rejection rates are in the table) |
| 11 MCSE | P |
