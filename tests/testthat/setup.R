# Heavy-test gate for the fast/slow CI split.
#
# `R CMD check` sets NOT_CRAN=true, so `skip_on_cran()` does not fire on CI and
# every TMB fit would run on routine PRs. To keep routine PR CI fast we gate the
# slow recovery/matrix/profile/bootstrap tests behind an explicit env flag.
#
# Routine PR CI (R-CMD-check.yaml) leaves GLLVMTMB_HEAVY_TESTS unset -> the
# heavy tests skip and only the fast suite runs. The nightly / pre-release
# full-check.yaml workflow sets GLLVMTMB_HEAVY_TESTS=1 -> the full suite runs
# across all three OSes.
#
# This file is sourced automatically by testthat before any test file
# (files matching ^setup are run as setup, in addition to helper*.R).
skip_if_not_heavy <- function() {
  testthat::skip_if(
    Sys.getenv("GLLVMTMB_HEAVY_TESTS") == "",
    "Heavy recovery/matrix test -- set GLLVMTMB_HEAVY_TESTS=1 to run"
  )
}

# The unique()/*_unique() soft-deprecation and the bare-latent() "Psi is now the
# default" notice are one-shot fire-on-use warnings for real users (maintainer
# 2026-06-20: loud fire-on-use). Suppress them across the general suite so they do
# not trip the many expect_silent()/expect_no_warning() fits; the dedicated
# test-unique-family-deprecation.R re-enables them (local_options FALSE) and asserts
# they fire. Real users have the option unset -> the warnings surface.
options(gllvmTMB.quiet_grammar_notes = TRUE)

# `fit$opt$convergence` is nlminb's PORT stopping code, NOT a statement about the
# quality of the optimum. On a flat likelihood PORT returns 1 = "false convergence
# (8)": the iterates appear to be converging but the relative-reduction test cannot
# be satisfied. That is a stopping rule, not a bad fit.
#
# Worse, WHICH code it returns can depend on the COLLATION LOCALE. Character factor
# levels (e.g. `site_species` = "10_1", "10_10", "10_100", ...) are ordered by
# collation; that order sets the random-effect indexing, hence the sparse-Cholesky
# fill-in, hence floating-point rounding, hence the optimiser's path. testthat sets
# `LC_COLLATE = "C"` (so does `R CMD check`), so a test can report a different status
# from the same fit run interactively.
#
# Verified 2026-07-08 on `test-phylo-q-decomposition.R` (seed 103, n_species = 100):
#   LC_COLLATE = C      -> convergence 1, "false convergence (8)",    obj 36622.108861,
#                          |grad|_inf 1.95e-02, 198 iterations
#   LC_COLLATE = en_AU  -> convergence 0, "relative convergence (4)", obj 36622.108862,
#                          |grad|_inf 4.69e-02, 206 iterations
# Identical data; the same optimum; the gradient is SMALLER in the "failing" case; and
# sigma2_Q recovers to 12.7% mean relative error under both. Raising the iteration
# budget 10x changes nothing (byte-identical objective and iteration count), so a
# larger `iter.max` is a no-op, not a fix.
#
# Recovery fixtures sometimes need to distinguish a stationary fitted scenario
# from a fully clean public fit. The helper below deliberately checks only the
# objective-scaled stationarity diagnostic; it must not be used as a public
# convergence certificate. Tests that make inference claims must inspect the
# optimiser code, raw gradient, and Hessian/SE health separately.
#
# NOTE: ~377 assertions across ~184 test files still use the bare
# `expect_equal(fit$opt$convergence, 0L)` form and share the locale fragility above.
# Migrating those is a separate mechanical sweep; `expect_stationary_for_recovery_test()` is the target.

# Predicate for recovery-test skip guards only. Never TRUE when the diagnostic
# is unavailable.
.fit_stationary_for_recovery_test <- function(fit) {
  v <- tryCatch(
    fit$fit_health$stationary_by_scaled_gradient,
    error = function(e) NULL
  )
  if (is.logical(v) && length(v) == 1L && !is.na(v)) {
    return(isTRUE(v))
  }
  ## Fallback: recompute the scaled gradient directly (mirrors R/diagnose.R).
  g <- tryCatch(max(abs(fit$tmb_obj$gr(fit$opt$par))), error = function(e) NA_real_)
  obj <- tryCatch(fit$opt$objective, error = function(e) NA_real_)
  if (is.na(g) || is.na(obj)) return(FALSE)
  isTRUE(
    g / (1 + abs(obj)) < gllvmTMB:::.gllvmTMB_converged_gtol
  )
}

# Assertion wrapper for the recovery-test predicate. This does not assert that a
# fit is ready for interpretation or inference.
expect_stationary_for_recovery_test <- function(fit) {
  h <- tryCatch(fit$fit_health, error = function(e) NULL)
  testthat::expect(
    .fit_stationary_for_recovery_test(fit),
    sprintf(
      paste0(
        "Fit did not reach the recovery-test stationarity threshold: converged = %s, scaled_gradient = %s, ",
        "raw convergence code = %s, pd_hessian = %s."
      ),
      isTRUE(h$converged), signif(h$scaled_gradient %||% NA_real_, 3),
      h$convergence %||% NA, isTRUE(h$pd_hessian)
    )
  )
  invisible(fit)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
