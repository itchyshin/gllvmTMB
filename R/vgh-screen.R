## VGH as a degenerate-fit SCREEN.
##
## This does not ask VGH to be a good estimator of Lambda -- it asks whether
## VGH's own KL-to-prior term (R/va-vgh.R:181) reports the same data as
## unhealthy that Laplace silently mishandles. Design note:
## p3-health-statistic-design.md picks H1 (mean per-unit, per-axis posterior
## log-contraction) as the recommended statistic; the reasoning is repeated
## here only where it constrains the code.
##
## Rotation-invariance is the hard constraint (Lambda is identified only up to
## an orthogonal rotation and the likelihood is EXACTLY flat along that orbit,
## R/va-vgh.R:207): raw Lambda, its columns, or per-axis entries of Svec/amean
## must never be compared. Everything below is built from tr(S_i), logdet(S_i)
## and ||a_i||^2, which ARE rotation-invariant (see the design note section 4).

## H1: h = -(1/(N*q)) * sum_i logdet(S_i) = mean_ik log(1 + mu_ik), where mu_ik
## are the eigenvalues of Lambda' W_i Lambda (loading magnitude in Fisher-
## information units, R/va-vgh.R:212-215). Computed from fit$Svec ALONE --
## fit$Svec/fit$amean are the variational fixed point for the PRE-update
## Lambda (R/va-vgh.R:518-527, ":600"), half a sweep stale relative to the
## returned Lambda; a statistic that also used the returned Lambda would
## inherit that mismatch, one built on Svec alone does not.
##
## h >= 0 EXACTLY: P_i = S_i^{-1} >= I_q for every accepted iterate (B2 >= 0
## for all three admitted families, the damped update is a convex combination
## starting from P = I, R/va-vgh.R:201-224), so every eigenvalue of every
## returned S_i lies in (0, 1]. h ~ 0 means "posterior equals prior on every
## axis for every unit" (collapse); h far above the healthy band means loading
## explosion. Both failure directions live on ONE scale-free, dimensionless
## number -- hence the two-sided band below, not a one-sided cutoff.
.vgh_health_stat <- function(fit) {
  if (!inherits(fit, "vgh_fit")) {
    stop("`fit` must be a <vgh_fit> object.", call. = FALSE)
  }
  q <- fit$q
  Svec <- fit$Svec
  n <- nrow(Svec)
  logdetS <- if (q == 1L) {
    log(Svec[, 1L])
  } else {
    vapply(seq_len(n), function(i) {
      S <- matrix(Svec[i, ], q, q)
      determinant(S, logarithm = TRUE)$modulus[[1L]]
    }, numeric(1L))
  }
  list(h = -mean(logdetS) / q, logdetS = logdetS, per_unit_h = -logdetS / q)
}

## Apply the two-sided band to an ALREADY-FITTED object and return the
## verdict. Split out from .vgh_screen_fit() so the flagging logic itself can
## be exercised on a constructed <vgh_fit> fixture (a contrived Svec) without
## needing a real, converged fit -- the same fixture-based-oracle pattern as
## R/vgh-warmstart.R's .vgh_to_laplace_start() tests (test-vgh-oracle.R).
##
## `threshold` is the two-sided healthy band on h, c(lo, hi): h < lo reads as
## axis collapse, h > hi as loading explosion. There is no universal default;
## the band is a property of the design cell (it drifts like log(T), design
## note section 3, H1). Calibrate it on known-healthy fits before relying on
## the default here for anything other than the design cell it was set from
## (see p3-screen-performance.md) -- shipping an untuned default would silently
## misrepresent the calibration this function's own docstring warns about.
.vgh_screen_verdict <- function(fit, threshold = c(0.05, 6)) {
  if (length(threshold) != 2L || !is.numeric(threshold) ||
      !all(is.finite(threshold)) || threshold[1L] >= threshold[2L]) {
    stop("`threshold` must be c(lo, hi) with lo < hi.", call. = FALSE)
  }
  stat <- .vgh_health_stat(fit)
  h <- stat$h
  degenerate <- (h < threshold[1L]) || (h > threshold[2L])
  structure(list(
    fit = fit,
    h = h,
    degenerate = degenerate,
    threshold = threshold,
    logdetS = stat$logdetS,
    per_unit_h = stat$per_unit_h
  ), class = "vgh_screen")
}

## Run VGH on the same data (same y/X/unit_id/trait_id/N/T/q/family/link the
## Laplace fit used -- see R/vgh-warmstart.R:252-261 for the identical flat
## contract) and return a health verdict rather than a point estimate.
.vgh_screen_fit <- function(..., threshold = c(0.05, 6)) {
  fit <- .vgh_fit(...)
  .vgh_screen_verdict(fit, threshold)
}
