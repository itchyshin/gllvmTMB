.libPaths(c("~/R/library", .libPaths()))
library(gllvmTMB)
set.seed(99)
dat <- data.frame(unit = rep(1:22, 2), trait = factor(rep(c("tw", "or"), 22)), value = NA)
dat$value[dat$trait == "tw"] <- abs(rgamma(22, 2, 1)) + 0.05
dat$value[dat$trait == "or"] <- factor(sample(1:3, 22, TRUE), ordered = TRUE)
fams <- list(tw = tweedie(p = 1.5), or = ordinal_logit())
attr(fams, "family_var") <- "trait"
out <- tryCatch(
  gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat, trait = "trait", unit = "unit", family = fams,
    control = gllvmTMBcontrol(warn_runaway = FALSE)
  ),
  error = function(e) e
)
if (inherits(out, "error")) {
  cat("ERROR:", conditionMessage(out), "\n")
} else {
  cat("convergence:", out$fit$convergence, "\n")
}