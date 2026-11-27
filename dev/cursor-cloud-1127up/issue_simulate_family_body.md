**Claim tag:** `cursor-cloud-1127up` (text label only; not a git tag)

## Expected vs actual

**Expected:** `simulate(fit, family = <other>)` should either (1) draw from the requested family at the fitted linear predictor, or (2) refuse with a clear error that per-call family overrides are unsupported.

**Actual (`gllvmTMB` 0.8.0 built from `main` @ `1e3662653e4a45907b18255afbe621cd18415720`):** `simulate.gllvmTMB_multi()` accepts `family=` in `...` but never uses it. No warning is emitted. In-sample simulation always uses the fit’s own per-row families via `.draw_y_per_family()`. On a converged Poisson `latent()` fit, `simulate(fit, nsim = 10, family = gaussian())` and `simulate(fit, nsim = 10, family = binomial())` both return the same kind of count data as the default call (e.g. values `> 1` when `family = binomial()` is passed).

## Data source

`simulate_unit_trait()` synthetic long-format data (no external file).

## Minimal repro

```r
## main @ 1e3662653e4a45907b18255afbe621cd18415720 — seed 271127
suppressPackageStartupMessages(library(gllvmTMB))
set.seed(271127)
sim <- simulate_unit_trait(
  n_units = 30, n_obs_per_unit = 1, n_traits = 2,
  Lambda_B = matrix(c(0.45, 0.35), 2, 1), psi_B = c(0.1, 0.1), seed = 271127
)
sim$data$value <- rpois(nrow(sim$data), lambda = 5)
fit <- gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = sim$data, trait = "trait", unit = "unit", family = poisson()
)
stopifnot(fit$fit$convergence == 0L)

s_default <- simulate(fit, nsim = 1)
s_binom   <- simulate(fit, nsim = 1, family = binomial()) # no warning

stopifnot(max(s_binom) > 1)  # not 0/1 — binomial override ignored
```

### Inline data (`dput` first rows)

```r
dput(utils::head(sim$data, 6))
```

### Session / package status

```
R version 4.3.3 (2024-02-29), x86_64-pc-linux-gnu
gllvmTMB_0.8.0 (R CMD INSTALL from main @ 1e3662653e4a45907b18255afbe621cd18415720)
TMB_1.9.25
```

Related: `newdata` simulation fallback is tracked in #1975 / #1979; this report is the separate in-sample `family =` footgun (no `newdata`).