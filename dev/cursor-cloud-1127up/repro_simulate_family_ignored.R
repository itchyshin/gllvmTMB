## gllvmTMB main @ 1e3662653e4a45907b18255afbe621cd18415720
## Claim tag: cursor-cloud-1127up (text label only)
## seed 271127

.libPaths(c(path.expand("~/R/library"), .libPaths()))
suppressPackageStartupMessages({
  library(gllvmTMB)
})

set.seed(271127)
sim <- simulate_unit_trait(
  n_units = 24, n_obs_per_unit = 1, n_traits = 2,
  Lambda_B = matrix(c(0.45, 0.35), 2, 1),
  psi_B = c(0.1, 0.1),
  seed = 271127
)
sim$data$value <- rpois(nrow(sim$data), lambda = 2)

fit <- gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = sim$data,
  trait = "trait",
  unit = "unit",
  family = poisson(),
  control = gllvmTMBcontrol(warn_runaway = FALSE)
)
stopifnot(fit$fit$convergence == 0L)

## User tries to force Gaussian draws (e.g. glmmTMB-style override) — no error or warning.
default_draw <- simulate(fit, nsim = 10)
override_draw <- simulate(fit, nsim = 10, family = gaussian())

cat("default range:", paste(range(default_draw), collapse = ", "), "\n")
cat("override range:", paste(range(override_draw), collapse = ", "), "\n")
cat("identical draws:", identical(default_draw, override_draw), "\n")
cat("all integers (default):", all(default_draw == floor(default_draw)), "\n")
cat("all integers (family=gaussian):", all(override_draw == floor(override_draw)), "\n")

invisible(list(default = default_draw, override = override_draw))