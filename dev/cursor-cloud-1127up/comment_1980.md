**Claim tag:** `cursor-cloud-1127up`

Independent confirmation on **long-format** `latent()` (not `traits()`), `main` @ `1e3662653e4a45907b18255afbe621cd18415720`, seed `77`.

`getResidualCor(fit)` returns a **3×3 matrix of all `1`** (off-diagonals included). `extract_correlations(fit, link_residual = "auto")` on the same converged binomial fit reports modest off-diagonal correlations (~0.05–0.09).

```r
sim <- simulate_unit_trait(35, 1, 3, Lambda_B = matrix(0.5, 3, 1), seed = 77)
sim$data$value <- rbinom(nrow(sim$data), 1, 0.4)
fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = sim$data, trait = "trait", unit = "unit", family = binomial(),
  control = gllvmTMBcontrol(warn_runaway = FALSE))
print(getResidualCor(fit))          # all 1s
print(extract_correlations(fit, link_residual = "auto"))
```