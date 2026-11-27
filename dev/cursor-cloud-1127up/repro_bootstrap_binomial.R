.libPaths(c("~/R/library", .libPaths()))
library(gllvmTMB)
SHA <- system2("git", c("-C", "/agent/repos/gllvmTMB", "rev-parse", "HEAD"), stdout = TRUE)
set.seed(77)
sim <- simulate_unit_trait(
  n_units = 35, n_obs_per_unit = 1, n_traits = 3,
  Lambda_B = matrix(0.5, 3, 1), seed = 77
)
sim$data$value <- rbinom(nrow(sim$data), 1, 0.4)

fit <- gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = sim$data,
  trait = "trait",
  unit = "unit",
  family = binomial(),
  control = gllvmTMBcontrol(warn_runaway = FALSE)
)
stopifnot(fit$fit$convergence == 0L)

cat("SHA:", SHA, "\n")
cat("Calling bootstrap_Sigma...\n")
tryCatch(
  bootstrap_Sigma(fit, n_boot = 8, seed = 2),
  error = function(e) {
    cat("ERROR:", conditionMessage(e), "\n")
    traceback()
  }
)