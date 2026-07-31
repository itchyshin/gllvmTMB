## Issue #856 -- degenerate-case probe (design question, not a test).
##
## `src/gllvmTMB.cpp:582` declares `PARAMETER(log_sigma_eps)` as one scalar
## residual log-SD shared across gaussian/lognormal rows. We are about to
## promote it to per-trait. Open design question: with exactly ONE row per
## (unit, trait) cell and a per-trait unit-level random intercept, a
## per-trait sigma_eps_t would be EXACTLY confounded with the per-trait
## unit variance psi_t (both explain the same single residual per cell).
## Today's scalar is only WEAKLY confounded (it pools information across
## traits). Question: on current main, what actually happens to the
## SCALAR sigma_eps when the data are degenerate this way -- does the
## engine already guard against it (Q7 auto-suppression), or does it let
## the scalar float into a meaningless/boundary estimate? The answer tells
## us whether the per-trait promotion needs its own guard-with-fallback or
## can fail loud.
##
## Same model as test-sigma-eps-per-trait.R, but n_rep = 1 (no replicate
## rows per (unit, trait) cell) instead of n_rep = 3.

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

set.seed(8560L)
n_unit   <- 120L
n_rep    <- 1L                 # <-- the degenerate case: R_rep = 1
n_traits <- 2L
true_sigma_eps <- c(0.2, 2.0)
true_sd_unit   <- c(1.0, 1.0)
trait_names    <- c("t1", "t2")

grid <- expand.grid(rep = seq_len(n_rep), unit = seq_len(n_unit))
long <- do.call(rbind, lapply(seq_len(n_traits), function(t) {
  data.frame(unit = grid$unit, rep = grid$rep, trait_idx = t)
}))
b_unit <- vapply(seq_len(n_traits), function(t) {
  stats::rnorm(n_unit, 0, true_sd_unit[t])
}, numeric(n_unit))
eta <- b_unit[cbind(long$unit, long$trait_idx)]
long$value <- stats::rnorm(nrow(long), mean = eta,
                            sd = true_sigma_eps[long$trait_idx])
long$unit  <- factor(long$unit)
long$trait <- factor(trait_names[long$trait_idx], levels = trait_names)

cat("n rows:", nrow(long), " (n_unit =", n_unit, "x n_traits =", n_traits,
    "x n_rep =", n_rep, ")\n")
cat("Rows per (unit, trait) cell:",
    paste(unique(table(paste(long$unit, long$trait))), collapse = ", "), "\n\n")

cat("---- fitting (messages NOT suppressed, to see any Q7 auto-suppress notice) ----\n")
fit <- suppressWarnings(gllvmTMB(
  value ~ 0 + trait + indep(0 + trait | unit),
  data = long, unit = "unit", trait = "trait"
))

cat("\n---- results ----\n")
cat("opt$convergence:", fit$opt$convergence, " (", fit$opt$message, ")\n")
cat("sd_report$pdHess:", fit$sd_report$pdHess, "\n")
cat("fit_health$converged:", fit$fit_health$converged, "\n")
cat("fit_health$scaled_gradient:", fit$fit_health$scaled_gradient, "\n")

map_has_entry <- "log_sigma_eps" %in% names(fit$tmb_obj$env$map)
mapped_off <- map_has_entry && is.na(fit$tmb_obj$env$map$log_sigma_eps[1])
cat("\nlog_sigma_eps in tmb_obj$env$map:", map_has_entry, "\n")
cat("log_sigma_eps mapped off (Q7 auto-suppressed):", mapped_off, "\n")

cat("\nreport$sigma_eps (scalar):", fit$report$sigma_eps, "\n")
cat("length(report$sigma_eps):", length(fit$report$sigma_eps), "\n")
cat("data sd(y):", stats::sd(long$value), "\n")
cat("true per-trait sigma_eps: ", paste(true_sigma_eps, collapse = ", "), "\n")
cat("RMS of true sigma_eps:", sqrt(mean(true_sigma_eps^2)), "\n")

cat("\n---- check_gllvmTMB(fit) ----\n")
print(check_gllvmTMB(fit))

cat("\n---- unit-level per-trait variance recovery (extract_Sigma) ----\n")
s_unit <- suppressMessages(extract_Sigma(fit, level = "unit", part = "unique")$s)
cat("extract_Sigma unit-level variances:", s_unit, " -> SD:", sqrt(s_unit),
    " (true SD = 1.0, 1.0)\n")
