## Diagnostic: why does VA-Wald fail the 3-start-agreement health gate at
## production scale (T=8, q=2, N=150)? Companion to 40-step0-pilot.R.
args <- commandArgs(trailingOnly = TRUE)
N0 <- as.integer(args[[1]] %||% "150")
SEED <- as.integer(args[[2]] %||% "20260801")
N_STARTS <- as.integer(args[[3]] %||% "4")

`%||%` <- function(a, b) if (is.null(a)) b else a
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll())

T0 <- 8L; Q0 <- 2L; PSI_LO <- 0.3; PSI_HI <- 0.5

set.seed(SEED)
Lambda <- matrix(0, T0, Q0)
for (k in seq_len(Q0)) Lambda[k, k] <- stats::runif(1, 0.7, 1.3)
for (k in 1:(Q0 - 1)) for (kk in (k + 1):Q0) Lambda[kk, k] <- stats::runif(1, -0.5, 0.5)
for (t in (Q0 + 1):T0) Lambda[t, ] <- stats::rnorm(Q0, 0, 0.7)
psi_true <- stats::runif(T0, PSI_LO, PSI_HI)
beta_true <- stats::rnorm(T0, 0, 0.5)
z <- matrix(stats::rnorm(N0 * Q0), N0, Q0)
x <- stats::rnorm(N0)
eta <- outer(x, beta_true) + z %*% t(Lambda)
y <- eta + matrix(stats::rnorm(N0 * T0, 0, sqrt(rep(psi_true, each = N0))), N0, T0)
d <- data.frame(y = as.numeric(t(y)), trait = factor(rep(seq_len(T0), times = N0)),
                unit = factor(rep(seq_len(N0), each = T0)), x = rep(x, each = T0))
Xva <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = d))

t0 <- Sys.time()
fit <- do.call(gllvmTMB:::.va_r3_fit, list(
  y = d$y, n_trials = rep(1L, nrow(d)), X = Xva,
  unit_id = as.integer(d$unit), trait_id = as.integer(d$trait),
  q = Q0, family = "gaussian_anchor", link = "identity",
  unique = FALSE, psi = FALSE, estimate_gaussian_sd = TRUE,
  n_starts = N_STARTS,
  control = list(eval.max = 2000L, iter.max = 2000L)
))
cat(sprintf("fit took %.2fs\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
cat("status:", fit$status, "\n")
cat("n_starts:", N_STARTS, "\n")
for (k in seq_along(fit$starts)) {
  fk <- fit$starts[[k]]
  cat(sprintf("  start %d: healthy=%s convergence=%s obj=%.6f max|grad|=%.4g msg=%s\n",
              k, fk$healthy, fk$convergence, fk$objective, fk$max_abs_gradient, fk$message))
}
cat("healthy count:", sum(vapply(fit$starts, `[[`, logical(1), "healthy")), "\n")
objs <- vapply(fit$starts, `[[`, numeric(1), "objective")
cat("objectives:", paste(sprintf("%.6f", objs), collapse=", "), "\n")
cat("\nhealth summary:\n")
print(fit$health)
