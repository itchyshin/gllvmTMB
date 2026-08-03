## SMOKE, not a measurement. Proves, on whatever machine it runs on:
##   (1) the package loads and BOTH TMB templates compile;
##   (2) the cold GH route and the warm AC->GH route each return a FINITE
##       objective and a non-degenerate loadings estimate;
##   (3) the two routes agree on the optimum -- the precondition without which
##       a speed ratio between them is meaningless.
## No timing is claimed here. Timing is 23-warm-route-confirm.R.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat("== smoke starting", format(Sys.time(), "%H:%M:%S"), "in", getwd(), "==\n"); flush.console()
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
cat("== load_all done", format(Sys.time(), "%H:%M:%S"), "==\n"); flush.console()

N0 <- 60L; T0 <- 8L; q0 <- 1L; NTR <- 6L; PSI <- 0.6
rf <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))
set.seed(1)
lam <- matrix(rnorm(T0 * q0, 0, .8), T0, q0); lam[upper.tri(lam)] <- 0
a <- matrix(rnorm(N0 * q0), N0, q0); u <- matrix(rnorm(N0 * T0, 0, PSI), N0, T0)
eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, .3), "+") + u
d <- data.frame(y = rbinom(N0 * T0, NTR, pnorm(as.vector(eta))),
                unit = rep(1:N0, times = T0), trait = rep(1:T0, each = N0))
A <- list(y = d$y, n_trials = rep(NTR, nrow(d)),
          X = unname(model.matrix(~ 0 + factor(d$trait, levels = 1:T0))),
          unit_id = d$unit, trait_id = d$trait, q = q0,
          family = "binomial_probit", link = "probit",
          unique = TRUE, profile_variational = TRUE)

one <- function(tag, f) {
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(f(), error = function(e) {cat("  ", tag, "ERROR:", conditionMessage(e), "\n"); NULL})
  if (is.null(fit)) return(NULL)
  L <- gllvmTMB:::.va_r3_unpack_theta_rr(fit$best$par[names(fit$best$par) == "theta_rr"], T0, q0)
  out <- list(obj = fit$best$objective, rf = rf(L %*% t(L), lam %*% t(lam)),
              psi = median(exp(fit$best$par[names(fit$best$par) == "log_sd_tier"])),
              secs = proc.time()[["elapsed"]] - t0)
  cat(sprintf("  %-5s obj=%.4f  rel_frob=%.5f  psi=%.4f  (%.1fs, untimed)\n",
              tag, out$obj, out$rf, out$psi, out$secs)); flush.console()
  out
}
cold <- one("cold", function() do.call(gllvmTMB:::.va_r3_fit,
  c(A, list(eval_method = "gh", n_starts = 1L, H = 15L,
            control = list(eval.max = 800L, iter.max = 400L)))))
warm <- one("warm", function() do.call(gllvmTMB:::.va_r3_fit_warm,
  c(A, list(H = 15L, control = list(eval.max = 800L, iter.max = 400L)))))

ok <- !is.null(cold) && !is.null(warm) &&
      is.finite(cold$obj) && is.finite(warm$obj) &&
      is.finite(cold$rf) && is.finite(warm$rf) &&
      cold$rf > 0 && cold$rf < 1 && warm$rf > 0 && warm$rf < 1
agree <- if (ok) abs(cold$obj - warm$obj) / abs(cold$obj) < 1e-3 else NA
cat(sprintf("\nfinite & non-degenerate: %s\n", ok))
cat(sprintf("same optimum (rel diff < 1e-3): %s", if (isTRUE(agree)) "YES" else "NO"))
if (ok) cat(sprintf("  [rel diff %.2e]", abs(cold$obj - warm$obj) / abs(cold$obj)))
cat("\n")
## rel_frob == 1 exactly means COLLAPSE to zero, not a mediocre fit -- the arc
## has been bitten by a degeneracy rule that scored total collapse as best.
cat(sprintf("collapse check (rel_frob==1?): cold %s  warm %s\n",
            if (ok && abs(cold$rf - 1) < 1e-6) "COLLAPSED" else "ok",
            if (ok && abs(warm$rf - 1) < 1e-6) "COLLAPSED" else "ok"))
cat(sprintf("\nSMOKE %s\n", if (isTRUE(ok) && isTRUE(agree)) "PASS" else "FAIL"))
