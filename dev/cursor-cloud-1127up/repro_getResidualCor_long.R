.libPaths(c("~/R/library", .libPaths()))
library(gllvmTMB)
set.seed(271127)
sim <- simulate_unit_trait(35, 1, 3, Lambda_B = matrix(0.5, 3, 1), seed = 77)
sim$data$value <- rbinom(nrow(sim$data), 1, 0.4)
fit <- gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = sim$data, trait = "trait", unit = "unit", family = binomial(),
  control = gllvmTMBcontrol(warn_runaway = FALSE)
)
stopifnot(fit$fit$convergence == 0L)
R <- getResidualCor(fit)
print(R)
cat("offdiag unique:", unique(R[lower.tri(R)]), "\n")
ec <- extract_correlations(fit, link_residual = "auto")
print(ec[, c("trait_i", "trait_j", "correlation")])