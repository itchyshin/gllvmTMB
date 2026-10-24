## Phase 1b validation milestone 2026-05-15 (item 2 of 3):
## gllvmTMB_check_consistency(fit, n_sim) -- thin wrapper around
## TMB::checkConsistency() that simulates from the fitted model
## and tests whether the approximate marginal score is centred. A
## non-centred score is a sign that the Laplace approximation is
## unreliable for that fit (the random-effects posterior is far
## from Gaussian, or the data don't constrain the random effects
## well).
##
## TMB report recommendation 2026-05-15:
##   "`TMB::checkConsistency(fit$tmb_obj, n = 100)` -- simulates
##    from the fitted model and checks whether the approximate
##    marginal score is centred. A non-centred score is a sign
##    that the Laplace approximation is unreliable for that fit.
##    Use it during development; it's slower than sanity_multi()
##    but gives a complementary signal."
##
## Companion to:
##   - sanity_multi()        -- structural / convergence checks
##   - gllvmTMB_diagnose()   -- holistic fit health summary
##   - check_auto_residual() -- mixed-family / ordinal-probit
##                              safeguard
##   - check_identifiability()-- Procrustes-based loadings check
##   - confint_inspect()     -- visual profile-curve verification

#' Run an advanced Laplace-consistency check
#'
#' `gllvmTMB_check_consistency()` is an advanced validation helper for
#' the Laplace approximation, not a first-use diagnostic. Start with
#' [check_gllvmTMB()] or [gllvmTMB_diagnose()]. Use this function when
#' a fit looks numerically acceptable but you need a direct check of
#' whether the approximate marginal score is centred.
#'
#' It simulates `n_sim` datasets from the fitted model under the joint
#' parameter vector at the MLE, then tests whether the approximate
#' marginal score function is centred at zero across the simulations.
#' This needs the TMB template to simulate new responses (a `SIMULATE`
#' block). The `gllvmTMB` template does not have one yet (#1582), so
#' every "simulated" dataset would be the observed data and every score
#' vector identical. The function detects this and stops with a
#' "simulation not available" error rather than report a verdict it
#' cannot compute. A
#' non-centred score is a sign that the Laplace approximation is
#' **unreliable** for this fit -- typically because the random-effects
#' posterior is far from Gaussian (saturated binomial / Beta, sparse
#' counts, weakly identified random effects) or the data don't constrain
#' the random effects well.
#'
#' Scope: local Laplace-consistency diagnostics for a fitted
#' model. This is a diagnostic signal rather than a substitute for
#' bootstrap, profile, or external Bayesian calibration. Broader
#' calibration evidence is not yet available.
#'
#' This is a complementary signal to [sanity_multi()] (which checks
#' Hessian definiteness, gradient magnitude, convergence flags) and
#' to a target-explicit known-DGP study of rank-selection behaviour. Slower
#' than the first-line checks -- `n_sim` likelihood evaluations -- but the only diagnostic
#' that targets the **Laplace approximation itself** rather than
#' the optimisation outcome or the parameter identification.
#'
#' A large marginal-score p-value is an absence of evidence against
#' centring in this finite simulation; it is not a certificate that the
#' Laplace approximation is accurate. If the result is small
#' (`p_value <= 0.05`) or the flagged-parameter list is large, consider:
#'
#' * Refitting with a richer random-effects structure (so the
#'   conditional posterior is more Gaussian).
#' * Switching to a parametric bootstrap CI (which does not
#'   depend on the Laplace approximation being a good fit).
#' * Validating against `tmbstan::tmbstan(fit$tmb_obj)` (the
#'   audit's recommended Bayesian-comparison path).
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param n_sim Integer number of simulate-evaluate replicates.
#'   Default `100L`. Must be larger than the number of fixed parameters
#'   of the fit (`length(fit$tmb_obj$par)`): the covariance of the
#'   score vector from `n_sim` replicates has rank at most `n_sim - 1`,
#'   so a smaller `n_sim` cannot be inverted. The function stops with an
#'   error naming the parameter count otherwise. Cost is roughly
#'   `n_sim` joint likelihood evaluations; budget 5-30 seconds on a
#'   Tier-1 fixture and proportionally longer for larger fits.
#' @param seed Optional integer seed for the simulation RNG. NULL
#'   (default) draws a random seed.
#' @param estimate Logical. When `TRUE`, also refits the model on
#'   each simulated dataset (passed to `TMB::checkConsistency()`). The
#'   refits are kept in `$raw`; TMB's deviance test of them is
#'   `summary(cc$raw)$estimate$deviance.p.value`. The wrapper does not
#'   report it separately. Default `FALSE` (much faster).
#'
#' @return An object of class `gllvmTMB_check_consistency` with
#'   components:
#'   \describe{
#'     \item{`$marginal_p_value`}{Joint chi-squared p-value across
#'       all marginal-score components. `NA` if TMB's information
#'       matrix could not be inverted (often the case on tiny
#'       fixtures).}
#'     \item{`$marginal_bias`}{Named numeric vector: estimated bias of
#'       each parameter, from TMB's
#'       `-solve(var(score)) %*% mean(score)`. It is in each
#'       parameter's own units, not a z-score, so the fixed
#'       `|bias| > 0.5` flag threshold is a heuristic that depends on
#'       the parameter's scale.}
#'     \item{`$joint_p_value`}{p-value of TMB's joint-score test. This
#'       test checks that the simulation itself is correct; it uses the
#'       joint gradient and so needs simulated random effects as well as
#'       simulated data. `NA` when the template does not simulate the
#'       random effects. It does not depend on `estimate`.}
#'     \item{`$flagged_parameters`}{Character names of parameters
#'       whose marginal bias exceeds `|bias| > 0.5` (a heuristic;
#'       finite-`n_sim` noise can produce small spurious biases,
#'       but |0.5| is generally beyond noise for `n_sim = 100`).}
#'     \item{`$n_sim`}{The `n_sim` actually run.}
#'     \item{`$threshold`}{The marginal-bias threshold used.}
#'     \item{`$diagnostics`}{Character vector of one or more of:
#'       `"no_centring_warning"` (the finite simulation did not detect
#'       non-centring; this is not an accuracy certificate),
#'       `"marginal_score_non_centred"`,
#'       `"joint_score_non_centred"`,
#'       `"information_matrix_singular"` (TMB couldn't invert it;
#'       interpret with caution), `"marginal_p_value_unavailable"`
#'       (TMB returned NA without a captured warning; any other error
#'       from TMB's `summary()` is listed in `$warnings`).}
#'     \item{`$raw`}{The full `TMB::checkConsistency()` return value
#'       in case the user wants the per-replicate gradient matrix.}
#'     \item{`$call`}{`match.call()` of the invocation.}
#'   }
#'
#' @seealso [sanity_multi()] (structural / convergence checks),
#'   [check_auto_residual()] (mixed-family safeguard),
#'   [gllvmTMB_diagnose()] (holistic fit summary),
#'   [TMB::checkConsistency()] (the underlying TMB call).
#'
#' @examples
#' set.seed(1)
#' # Counts of four species at 100 sites, driven by one shared latent axis.
#' # The check matters most for non-Gaussian responses like these, where
#' # the Laplace approximation is not exact.
#' n_sites <- 100
#' z <- rnorm(n_sites)
#' loadings <- c(0.8, 0.6, 0.5, 0.3)
#' dat <- expand.grid(site = factor(seq_len(n_sites)),
#'                    trait = factor(paste0("sp", 1:4)))
#' mu <- exp(0.5 + loadings[as.integer(dat$trait)] * z[as.integer(dat$site)])
#' dat$count <- rpois(nrow(dat), mu)
#' fit <- gllvmTMB(
#'   count ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
#'   data = dat, family = poisson(), trait = "trait", unit = "site"
#' )
#'
#' # n_sim must be larger than the number of fitted parameters (8 here);
#' # a smaller value stops with an error that names the count.
#' tryCatch(
#'   gllvmTMB_check_consistency(fit, n_sim = 5, seed = 1),
#'   error = function(e) cat(conditionMessage(e), "\n")
#' )
#'
#' # The template cannot yet simulate new responses (#1582), so with a
#' # valid n_sim the check stops with a "simulation not available" error.
#' # Once simulation is available, `cc$diagnostics` gives the overall
#' # verdict and `cc$flagged_parameters` the parameters whose estimated
#' # bias exceeds the threshold.
#' tryCatch(
#'   gllvmTMB_check_consistency(fit, n_sim = 50, seed = 1),
#'   error = function(e) cat(conditionMessage(e), "\n")
#' )
#'
#' @export
gllvmTMB_check_consistency <- function(
  fit,
  n_sim = 100L,
  seed = NULL,
  estimate = FALSE
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    .gllvmTMB_abort_not_multi_fit(fit)
  }
  .gllvmTMB_mspl_assert_inference(fit, "gllvmTMB_check_consistency")
  n_sim <- as.integer(n_sim)
  if (length(n_sim) != 1L || is.na(n_sim) || n_sim < 2L) {
    cli::cli_abort("{.arg n_sim} must be an integer >= 2.")
  }
  ## The score covariance from n_sim replicates has rank at most
  ## n_sim - 1, so it can only be inverted when n_sim exceeds the number of
  ## fixed parameters (TMB's own check, `nsim < npar`, is one short).
  n_par <- length(fit$tmb_obj$par)
  if (n_sim <= n_par) {
    cli::cli_abort(
      c(
        "{.arg n_sim} = {n_sim} is too small for this fit, which has {n_par} fixed parameters.",
        "i" = "Use {.arg n_sim} of at least {n_par + 1L}; more replicates give a steadier test."
      ),
      class = "gllvmTMB_check_consistency_n_sim_too_small"
    )
  }
  .gllvmTMB_local_seed(seed)

  ## A template without a SIMULATE block returns the observed data from
  ## simulate(), so every replicate would re-score the same y (#1582).
  if (!.gllvmTMB_cc_simulation_available(fit)) {
    .gllvmTMB_cc_abort_no_simulation()
  }

  ## TMB::checkConsistency emits a `Failed to invert information
  ## matrix` warning on tiny fixtures (small n, weakly identified
  ## random effects). The warning is often fired during summary()
  ## rather than during the call itself; capture both.
  raw <- NULL
  smry <- NULL
  cap <- character(0)
  withCallingHandlers(
    {
      raw <- .gllvmTMB_cc_raw(fit$tmb_obj, n_sim, isTRUE(estimate))
      ## summary() is where TMB actually computes the p-values and the
      ## per-parameter bias (and where the information-matrix inversion
      ## runs); the raw object does not carry them. Capture the summary
      ## rather than only triggering it for its warning channel.
      ## A summary() error is reported in $warnings, not hidden: it is not
      ## a singular matrix.
      smry <- tryCatch(
        summary(raw),
        error = function(e) {
          cap <<- c(cap, paste0("summary() failed: ", conditionMessage(e)))
          NULL
        }
      )
    },
    warning = function(w) {
      cap <<- c(cap, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  ## Identical score vectors across replicates (zero SD) mean the replicates
  ## were not simulated; the covariance is exactly singular for that reason.
  score <- tryCatch(
    do.call(cbind, lapply(raw, function(r) as.vector(r$gradient))),
    error = function(e) NULL
  )
  if (is.matrix(score) && ncol(score) > 1L) {
    score_sd <- apply(score, 1L, stats::sd)
    if (all(is.finite(score_sd)) && max(score_sd) == 0) {
      .gllvmTMB_cc_abort_no_simulation()
    }
  }

  ## Extract the marginal-score check result. Defensive against NULL
  ## or zero-length p-value entries (TMB returns NA when the
  ## information matrix is singular, but on some fixtures even the
  ## NA isn't populated and the slot is empty).
  marginal_p <- smry$marginal$p.value
  if (is.null(marginal_p) || length(marginal_p) == 0L) {
    marginal_p <- NA_real_
  }
  marginal_b <- smry$marginal$bias
  if (is.null(marginal_b)) {
    marginal_b <- numeric(0L)
  }
  joint_p <- smry$joint$p.value
  if (is.null(joint_p) || length(joint_p) == 0L) {
    joint_p <- NA_real_
  }

  threshold <- 0.5
  flagged <- character(0L)
  if (!is.null(marginal_b)) {
    finite_bias <- marginal_b[is.finite(marginal_b)]
    if (length(finite_bias) > 0L) {
      hits <- abs(finite_bias) > threshold
      if (any(hits)) flagged <- names(finite_bias)[hits]
    }
  }

  flags <- character(0L)
  if (any(grepl("invert information matrix", cap))) {
    flags <- c(flags, "information_matrix_singular")
  }
  if (!is.na(marginal_p) && marginal_p <= 0.05) {
    flags <- c(flags, "marginal_score_non_centred")
  }
  if (!is.na(joint_p) && joint_p <= 0.05) {
    flags <- c(flags, "joint_score_non_centred")
  }
  if (length(flagged) > 0L && !"marginal_score_non_centred" %in% flags) {
    flags <- c(flags, "marginal_score_non_centred")
  }
  ## When the marginal p-value is NA AND no other flag fires (no
  ## singular-matrix warning, no per-parameter bias > threshold),
  ## the test is inconclusive: report that explicitly rather than
  ## falsely claiming that the score is proved centred.
  if (is.na(marginal_p) && length(flags) == 0L) {
    flags <- "marginal_p_value_unavailable"
  }
  if (length(flags) == 0L) {
    flags <- "no_centring_warning"
  }

  out <- list(
    marginal_p_value = marginal_p,
    marginal_bias = marginal_b,
    joint_p_value = joint_p,
    flagged_parameters = flagged,
    n_sim = n_sim,
    threshold = threshold,
    diagnostics = flags,
    raw = raw,
    warnings = cap,
    call = match.call()
  )
  class(out) <- "gllvmTMB_check_consistency"
  out
}

## The TMB::checkConsistency() call, isolated so tests can supply synthetic
## replicates (the template has no SIMULATE block, #1582).
.gllvmTMB_cc_raw <- function(obj, n, estimate) {
  TMB::checkConsistency(obj, n = n, estimate = estimate)
}

## TRUE when the fitted template's simulate() returns new responses; FALSE
## when it hands back the observed data (no SIMULATE block) or cannot run.
.gllvmTMB_cc_simulation_available <- function(fit) {
  td <- fit$tmb_data
  sim <- tryCatch(
    fit$tmb_obj$simulate(complete = TRUE),
    error = function(e) NULL
  )
  if (is.null(sim) || is.null(td) || is.null(td$y) || is.null(sim$y)) {
    return(FALSE)
  }
  !identical(sim$y, td$y)
}

.gllvmTMB_cc_abort_no_simulation <- function(call = rlang::caller_env()) {
  cli::cli_abort(
    c(
      "The consistency check cannot run: simulation not available for this template.",
      "x" = "{.fn TMB::checkConsistency} needs the template to simulate new responses, but the {.pkg gllvmTMB} template has no {.code SIMULATE} block: every replicate would re-score the observed data and the score covariance is exactly zero.",
      "i" = "This is a limitation of the tool, not a property of your data (#1582)."
    ),
    class = "gllvmTMB_check_consistency_simulation_unavailable",
    call = call
  )
}

#' @export
#' @keywords internal
print.gllvmTMB_check_consistency <- function(x, ...) {
  cli::cli_h1("gllvmTMB Laplace-consistency check")
  cli::cli_bullets(c(
    "*" = "n_sim: {x$n_sim}",
    "*" = "Marginal-score p-value: {if (!is.na(x$marginal_p_value)) signif(x$marginal_p_value, 3) else if ('information_matrix_singular' %in% x$diagnostics) 'NA (information matrix singular)' else 'NA (unavailable; see $warnings)'}",
    "*" = "Joint-score p-value:    {if (is.na(x$joint_p_value)) 'NA (needs simulated random effects)' else signif(x$joint_p_value, 3)}"
  ))
  if (identical(x$diagnostics, "no_centring_warning")) {
    cli::cli_alert_info(
      "This finite simulation did not detect score non-centring. It does not certify Laplace accuracy or interval calibration."
    )
  } else {
    cli::cli_alert_warning(
      "Diagnostics: {.val {x$diagnostics}}"
    )
    if (length(x$flagged_parameters) > 0L) {
      cli::cli_text(
        "Parameters with {.field |bias| > {x$threshold}}: {.val {x$flagged_parameters}}"
      )
    }
    if ("information_matrix_singular" %in% x$diagnostics) {
      cli::cli_text(
        "The information matrix could not be inverted. This is common on tiny / weakly-identified fixtures; interpret the marginal p-value with caution and consider increasing {.arg n_sim} or fitting on a richer dataset."
      )
    }
  }
  if (length(x$marginal_bias) > 0L) {
    cli::cli_h2("Marginal bias per parameter")
    print(round(x$marginal_bias, 4L))
  }
  invisible(x)
}
