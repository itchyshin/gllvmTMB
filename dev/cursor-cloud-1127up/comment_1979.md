**Claim tag:** `cursor-cloud-1127up`

Additional repro on **ordinary** (non-spatial) `latent()` Poisson, `main` @ `1e3662653e4a45907b18255afbe621cd18415720`, seed `5`.

`simulate(fit, newdata = nd, nsim = 1)` triggers `gllvmTMB_simulate_newdata_gaussian_fallback` and returns **non-integer** values including **positives below 1** on a Poisson fit (e.g. `0.052`, `0.585`, `1.065` for four held-out `(unit, trait)` rows).

```r
sim <- simulate_unit_trait(30, 1, 3, Lambda_B = matrix(0.4, 3, 1), seed = 5)
sim$data$value <- rpois(nrow(sim$data), lambda = 2)
fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = sim$data, trait = "trait", unit = "unit", family = poisson())
nd <- unique(sim$data[, c("unit", "trait")])[1:4, ]
nd$value <- NA
simulate(fit, newdata = nd, nsim = 1)
```