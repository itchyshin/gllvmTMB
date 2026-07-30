## Issue #813, step 2 — IS THE PENALTY ACTUALLY LOOSE?
##
## The stated reason the public nonlinear-profile routes were withdrawn
## (R/extractors.R:264) is that the penalty route "could accept loose
## constraints and unconverged refits". Nobody had measured it, because the
## achieved constraint value was computed inside .fix_and_refit_nll() and then
## discarded. Step 1 (this branch) emits it; this script is the measurement.
##
## Uses the same fit as dev/profile-communality-diagnostic.R (#824) so the two
## are comparable: Gaussian d = 1, n = 120, loading gradient (0.9, 0.7, 0.5, 0.2)
## so c2_hat spans high to low.
##
## Exploratory diagnostic on ONE fit and ONE seed. Not calibration, not
## adjudicative. Run: Rscript dev/profile-communality-constraint-audit.R

suppressMessages(pkgload::load_all(".", quiet = TRUE))

set.seed(42)
n <- 120
tn <- c("t1", "t2", "t3", "t4")
u <- factor(seq_len(n))
z <- rnorm(n, sd = 0.9)
eta <- outer(z, c(0.9, 0.7, 0.5, 0.2))
colnames(eta) <- tn
Y <- eta + matrix(rnorm(length(eta), 0, 0.6), nrow = n)
d <- data.frame(
  unit = rep(u, each = 4),
  trait = factor(rep(tn, times = n), levels = tn),
  value = as.vector(t(Y))
)
fit <- suppressWarnings(gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = d, trait = "trait", unit = "unit",
  family = gaussian(), silent = TRUE
))

all <- suppressWarnings(do.call(rbind, lapply(seq_along(tn), function(ti) {
  profile_communality(fit, tier = "unit", trait_idx = ti, n_grid = 15L)
})))

tol <- .fix_and_refit_constraint_tol
cat("=== grid points:", nrow(all), " accepted tolerance:", tol, "===\n\n")

cat("-- refit_status --\n")
print(table(all$refit_status))
cat("\n-- refit_converged --\n")
print(table(all$refit_converged, useNA = "ifany"))

ae <- abs(all$constraint_error)
cat("\n-- |constraint_error| --\n")
print(summary(ae))
cat("\nmax vs tolerance:", format(max(ae, na.rm = TRUE), scientific = TRUE),
    "vs", tol, "->", round(tol / max(ae, na.rm = TRUE)), "x tighter than accepted\n")

cat("\n-- unconverged refits ACCEPTED onto the curve --\n")
bad <- all[!all$refit_converged, c("target", "profile_value", "constraint_error", "delta_deviance")]
print(bad, digits = 5, row.names = FALSE)

## The chi-square_1 crossing is the only thing here a confidence interval
## actually depends on, so report it directly rather than inferring importance
## from curve-shape statistics.
crit <- qchisq(0.95, 1)
cat("\n-- upper chi-square_1 crossing per trait (the CI-relevant number) --\n")
for (tg in unique(all$target)) {
  s <- all[all$target == tg, ]
  s <- s[order(s$profile_value), ]
  hi <- s[s$profile_value > s$estimate[1], ]
  x <- if (nrow(hi) >= 2 && any(hi$delta_deviance >= crit, na.rm = TRUE) &&
             any(hi$delta_deviance < crit, na.rm = TRUE)) {
    approx(hi$delta_deviance, hi$profile_value, xout = crit)$y
  } else {
    NA_real_
  }
  cat(sprintf("%s: %.5f\n", tg, x))
}

## Finding 3: monotonicity. A profile deviance curve must rise away from the
## MLE. A drop between adjacent grid points on the same side means the two
## refits landed on DIFFERENT local optima -- which the convergence flag does
## not catch, because both converged.
## Report monotonicity at TWO thresholds. 1e-6 is a numerical-noise detector,
## six orders of magnitude below the 3.84 chi-square_1 cutoff -- optimising
## against it measures the algorithm, not the likelihood. 1e-3 deviance is the
## smallest drop that could plausibly move a bound. Always read the second.
for (tol in c(1e-6, 1e-3)) {
cat(sprintf(
  "\n-- non-monotone steps, drop > %g deviance %s --\n",
  tol,
  if (tol <= 1e-6) "(NOISE DETECTOR -- not a quality metric)" else "(CI-relevant)"
))
for (tg in unique(all$target)) {
  s <- all[all$target == tg, ]
  s <- s[order(s$profile_value), ]
  mle <- s$estimate[1]
  for (side in c("left", "right")) {
    ss <- if (side == "left") {
      s[s$profile_value < mle, ][order(-s$profile_value[s$profile_value < mle]), ]
    } else {
      s[s$profile_value > mle, ]
    }
    dd <- ss$delta_deviance
    drops <- which(diff(dd) < -tol)
    for (i in drops) {
      cat(sprintf(
        "%s [%s]: %.4f -> %.4f  (dd %.3f -> %.3f, drop %.3f) converged: %s -> %s\n",
        tg, side, ss$profile_value[i], ss$profile_value[i + 1L],
        dd[i], dd[i + 1L], dd[i] - dd[i + 1L],
        ss$refit_converged[i], ss$refit_converged[i + 1L]
      ))
    }
  }
}}
