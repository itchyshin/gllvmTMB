## Wald (delta-method) confidence intervals on random-slope standard
## deviations from the ordinary augmented-diagonal latent()/indep() route.
##
## SLICE 1 ONLY (2026-08-18). Scope: `theta_diag_B_slope`, the per-trait
## unique (Psi) diagonal companion of an ordinary augmented random-slope
## term -- `latent(0 + trait + (0 + trait):x | unit, d = K)` or
## `indep(0 + trait + (0 + trait):x | unit)`. `src/gllvmTMB.cpp:1606`
## parameterises this block as `sd_B_slope = exp(theta_diag_B_slope)`, a
## genuine univariate log-SD per augmented coordinate, so the interval
## `exp(theta +/- z * se(theta))` is an exact transformed Wald interval --
## no Jacobian, no hand-indexing, nothing beyond reading the right names
## out of `sdreport()`.
##
## Explicitly OUT OF SCOPE and refused loudly, never approximated:
##  * `theta_dep_chol` (the `phylo_dep()` / `phylo_indep(1 + x | species)`
##    augmented Cholesky slope engine, `fit$use$phylo_dep_slope`). Its
##    slope diagonal shares a 2x2 Cholesky block with a free within-trait
##    off-diagonal entry, so Var(slope_t) = L21_t^2 + exp(diag_slope_t)^2
##    -- a MULTIVARIATE delta method over a 2x2 `cov.fixed` submatrix, not
##    a univariate one. A hand-indexed R-side Jacobian against this
##    packing is exactly the bug caught and fixed in
##    `dev/slope-interval-feasibility-RESULTS.md` (wrong entries 2/5/8 vs
##    correct 2/4/6, and an exponentiated raw off-diagonal entry).
##  * `theta_rr_B_slope` alone (the augmented reduced-rank loadings, when
##    there is no `theta_diag_B_slope` companion at all, e.g.
##    `latent(..., unique = FALSE)`). The marginal slope variance from
##    loadings is a quadratic form in MULTIPLE loading entries
##    (`Lambda_B_slope %*% t(Lambda_B_slope)`), again needing a
##    multivariate delta method.
## Both are deferred to a slice-2 ADREPORT() route (see the design doc
## cited below) rather than solved with a hand-rolled Jacobian here.
##
## When BOTH `theta_diag_B_slope` and `theta_rr_B_slope` are present (the
## default combination for `latent(...)`, which folds in the diagonal Psi
## companion by default), `slope_sd_ci()` still computes the interval --
## but `estimate` is then only the per-trait UNIQUE (Psi) component of
## slope variance, not the total marginal Var(Lambda_B_slope z + psi).
## The print method and roxygen both flag this; see the scope-boundary
## section in `?slope_sd_ci`.
##
## Reference: `dev/fable-extractor-recommendation.md` (Fable planning
## lens, 2026-08-18) and `dev/slope-interval-feasibility-RESULTS.md` (the
## measured facts it rests on). Register rows CI-14 (`partial`, this
## diagonal route) / CI-15 (`blocked`, the deferred Cholesky/loadings
## routes) in `docs/design/35-validation-debt-register.md`.

#' Wald confidence intervals on augmented random-slope standard deviations
#'
#' Per-trait confidence intervals on the standard deviation of an ordinary
#' augmented random-slope term -- a `latent(0 + trait + (0 + trait):x |
#' unit, d = K)` or `indep(0 + trait + (0 + trait):x | unit)` covariance
#' structure. The interval is a delta-method Wald interval on the log-SD
#' scale: `theta_diag_B_slope` is a genuine univariate log-SD
#' (`sd = exp(theta)`), so `se(sd) = exp(theta) * se(theta)` and the bounds
#' are `exp(theta +/- z * se(theta))`.
#'
#' @section Scope boundary -- what this interval IS and IS NOT:
#' This is a **transformed Wald interval read off `sdreport()`**, exactly
#' the same inferential instrument as [loading_ci()] and
#' [confint_inspect()]: it uses the asymptotic normal approximation for
#' `theta` and propagates it through the monotone transform `exp()`. It is
#' **not a calibrated coverage statement** -- no repeated-sampling coverage
#' campaign has been run for this estimand, and `interval_status =
#' "wald_uncalibrated"` marks every row as such. See register row CI-14
#' (`partial`) in `docs/design/35-validation-debt-register.md`.
#'
#' Slice 1 covers only the ordinary augmented **diagonal** route
#' (`theta_diag_B_slope`). It does **not** cover, and will error rather
#' than silently approximate, the phylogenetic Cholesky augmented-slope
#' route (`phylo_dep()` / `phylo_indep(1 + x | species)`, `theta_dep_chol`)
#' or a loadings-only augmented random slope with no diagonal companion
#' (`theta_rr_B_slope` alone, e.g. `latent(..., unique = FALSE)`). Both
#' need a multivariate delta method against the TMB Cholesky/loadings
#' packing and are deferred to a slice-2 `ADREPORT()` route (register row
#' CI-15, `blocked`).
#'
#' When the fit's random-slope term also carries a shared loadings
#' component (`theta_rr_B_slope`, the default alongside
#' `theta_diag_B_slope` for ordinary `latent()`), `estimate` here is the
#' per-trait **unique (Psi) diagonal component of slope variance only** --
#' it excludes the shared loadings contribution to the marginal slope
#' variance. The print method flags this explicitly.
#'
#' @param fit A multivariate `gllvmTMB()` fit with an augmented ordinary
#'   random-slope diagonal companion (`theta_diag_B_slope`).
#' @param level Confidence level. Defaults to 0.95.
#' @param scale `"sd"` (default) returns the standard deviation scale;
#'   `"variance"` returns the variance scale (`estimate^2`, bounds
#'   `exp(2 * (theta +/- z * se(theta)))`). Both scales are computed from
#'   the identical `theta` / `se_theta`, so they agree by construction.
#'
#' @return A data frame of class `gllvmTMB_slope_ci`, one row per trait,
#'   with columns:
#'   \describe{
#'     \item{`trait`}{Trait factor level.}
#'     \item{`term`}{The slope covariate name (the `x` in `(0 + trait):x`).}
#'     \item{`estimate`, `lower`, `upper`}{On the requested `scale`. `lower`
#'       / `upper` are `NA` whenever `status != "ok"`.}
#'     \item{`theta`, `se_theta`}{The raw log-SD estimate and its
#'       `sdreport()` standard error, for auditability.}
#'     \item{`method`}{Always `"wald_log_scale"`.}
#'     \item{`interval_status`}{Always `"wald_uncalibrated"` -- the
#'       claim-boundary marker used elsewhere in the package (see
#'       `extract_correlations()`).}
#'     \item{`status`}{`"ok"`, `"no_pd_hessian"`, `"se_nonfinite"`, or
#'       `"boundary"` -- see Kill-switch guard below.}
#'     \item{`scale`}{The requested scale, `"sd"` or `"variance"`.}
#'   }
#'   The returned object also carries a hard-coded attribute
#'   `calibrated = FALSE` (never an argument; only a future coverage
#'   certificate can flip this in the source).
#'
#' @section Kill-switch guard -- point estimates always, intervals never from a fit that cannot support one:
#' `lower`/`upper` are set to `NA` (with `status` explaining why and a
#' `cli::cli_warn()`) whenever any of:
#' \itemize{
#'   \item `fit$sd_report$pdHess` is `FALSE` (`status = "no_pd_hessian"`,
#'     applies to every row);
#'   \item `se_theta` is non-finite (`status = "se_nonfinite"`);
#'   \item `se_theta > 10` on the log scale -- a boundary/Heywood collapse;
#'     an SE of 10 on the log scale means the interval would span
#'     \eqn{e^{40}}, i.e. no information (`status = "boundary"`).
#' }
#' The point estimate (`estimate`, `theta`) is always returned, following
#' the house line that a non-PD Hessian disqualifies standard errors but
#' not point estimates (`R/bootstrap-sigma.R`, `R/cv-internal.R`).
#'
#' @seealso [loading_ci()] for the equivalent interval on Lambda entries;
#'   [extract_Sigma()] with `level = "unit_slope"` for the full augmented
#'   `2T x 2T` covariance (point estimates only).
#'
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + (0 + trait):x +
#'     latent(0 + trait + (0 + trait):x | individual, d = 2L),
#'   data = df_long,
#'   trait = "trait",
#'   unit  = "individual"
#' )
#' slope_sd_ci(fit)
#' slope_sd_ci(fit, level = 0.90, scale = "variance")
#' }
#'
#' @export
slope_sd_ci <- function(fit, level = 0.95, scale = c("sd", "variance")) {

  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("{.arg fit} must be a multi-trait {.fun gllvmTMB} fit.")
  .gllvmTMB_mspl_assert_inference(fit, "slope_sd_ci")
  .gllvmTMB_require_unweighted_inference(fit, "slope_sd_ci")

  if (!is.numeric(level) || length(level) != 1L ||
      level <= 0 || level >= 1)
    cli::cli_abort("{.arg level} must be a single number in (0, 1).")
  scale <- match.arg(scale)

  ## ---- Guard: refuse structures this slice cannot honestly cover ----
  if (isTRUE(fit$use$phylo_dep_slope))
    cli::cli_abort(c(
      "{.fn slope_sd_ci} does not cover the phylogenetic Cholesky random-slope route ({.code theta_dep_chol}).",
      "i" = "The slope diagonal shares its 2x2 Cholesky block with a free within-trait off-diagonal entry, so Var(slope) = L21^2 + exp(diag_slope)^2 needs a multivariate delta method, not a univariate one.",
      "i" = "This route is deliberately deferred (register row CI-15, {.file docs/design/35-validation-debt-register.md}) pending an {.code ADREPORT()}-based slice-2 implementation."
    ), class = "gllvmTMB_slope_sd_ci_unsupported_route")

  if (!isTRUE(fit$use$diag_B_slope)) {
    if (isTRUE(fit$use$rr_B_slope))
      cli::cli_abort(c(
        "{.fn slope_sd_ci} does not cover a loadings-only augmented random-slope term ({.code theta_rr_B_slope} with no diagonal companion).",
        "i" = "The marginal slope variance from loadings alone is a quadratic form in multiple loading entries ({.code Lambda_B_slope \\%*\\% t(Lambda_B_slope)}), which needs a multivariate delta method.",
        "i" = "This route is deliberately deferred (register row CI-15) pending an {.code ADREPORT()}-based slice-2 implementation.",
        ">" = "Refit with the default {.fn latent} Psi companion (do not pass {.code unique = FALSE}) so {.code theta_diag_B_slope} exists."
      ), class = "gllvmTMB_slope_sd_ci_unsupported_route")
    cli::cli_abort(c(
      "Fit has no augmented ordinary random-slope diagonal companion ({.code theta_diag_B_slope}) to summarise.",
      "i" = "Refit with a {.fn latent} or {.fn indep} term of the form {.code (0 + trait + (0 + trait):x | unit, d = K)}."
    ))
  }

  if (is.null(fit$sd_report) || !inherits(fit$sd_report, "sdreport"))
    cli::cli_abort(c(
      "Fit does not carry a TMB {.code sdreport}.",
      "i" = "Refit so {.code fit$sd_report} is populated (default {.code se = TRUE})."
    ))

  trait_names <- levels(fit$data[[fit$trait_col]])
  n_traits <- length(trait_names)

  par_names <- names(fit$opt$par)
  ix_diag <- which(par_names == "theta_diag_B_slope")
  if (length(ix_diag) != 2L * n_traits)
    cli::cli_abort(c(
      "Unexpected {.code theta_diag_B_slope} length.",
      "x" = "Found {length(ix_diag)} entries; expected {2L * n_traits} (2 per trait: intercept, slope)."
    ))

  slope_col <- fit$use$diag_B_slope_col %||% fit$use$rr_B_slope_col %||% "x"

  ## `theta_diag_B_slope` interleaves (intercept, slope) per trait
  ## (`R/fit-multi.R` ~4116-4121: `base = 2 * trait_id`, intercept at
  ## `base + 1`, slope at `base + 2`), matching `extract_Sigma()`'s
  ## `aug_names` ordering. Keep the slope entries only (even positions).
  slope_pos <- seq(2L, 2L * n_traits, by = 2L)
  ix_slope <- ix_diag[slope_pos]

  theta <- as.numeric(fit$opt$par[ix_slope])

  pd_ok <- isTRUE(fit$sd_report$pdHess)
  se_theta <- tryCatch(
    as.numeric(sqrt(diag(fit$sd_report$cov.fixed))[ix_slope]),
    error = function(e) rep(NA_real_, length(ix_slope))
  )

  if (!pd_ok) {
    status <- rep("no_pd_hessian", n_traits)
  } else {
    status <- ifelse(
      !is.finite(se_theta), "se_nonfinite",
      ifelse(se_theta > 10, "boundary", "ok")
    )
  }

  z <- stats::qnorm(0.5 + level / 2)
  sd_hat <- exp(theta)
  estimate <- if (identical(scale, "variance")) sd_hat^2 else sd_hat

  lower <- rep(NA_real_, n_traits)
  upper <- rep(NA_real_, n_traits)
  ok_rows <- status == "ok"
  if (any(ok_rows)) {
    lo_log <- theta[ok_rows] - z * se_theta[ok_rows]
    hi_log <- theta[ok_rows] + z * se_theta[ok_rows]
    if (identical(scale, "variance")) {
      lower[ok_rows] <- exp(2 * lo_log)
      upper[ok_rows] <- exp(2 * hi_log)
    } else {
      lower[ok_rows] <- exp(lo_log)
      upper[ok_rows] <- exp(hi_log)
    }
  }

  if (!pd_ok) {
    cli::cli_warn(c(
      "Fit's Hessian is not positive-definite at the optimum.",
      "i" = "Returning point estimates only; {.code lower} / {.code upper} are NA for every slope -- Wald inference is unavailable for this fit."
    ))
  } else {
    n_nonfinite <- sum(status == "se_nonfinite")
    if (n_nonfinite > 0L)
      cli::cli_warn(c(
        "{.code se_theta} is non-finite for {n_nonfinite} of {n_traits} slope(s).",
        "i" = "Returning point estimates only for those rows; {.code lower} / {.code upper} are NA."
      ))
    n_boundary <- sum(status == "boundary")
    if (n_boundary > 0L)
      cli::cli_warn(c(
        "{.code se_theta} exceeds 10 on the log scale for {n_boundary} of {n_traits} slope(s) -- a boundary/Heywood collapse.",
        "i" = "Returning point estimates only for those rows; {.code lower} / {.code upper} are NA."
      ))
  }

  out <- data.frame(
    trait           = factor(trait_names, levels = trait_names),
    term            = slope_col,
    estimate        = estimate,
    lower           = lower,
    upper           = upper,
    theta           = theta,
    se_theta        = se_theta,
    method          = "wald_log_scale",
    interval_status = "wald_uncalibrated",
    status          = status,
    scale           = scale,
    stringsAsFactors = FALSE
  )
  attr(out, "calibrated") <- FALSE
  attr(out, "level") <- level
  attr(out, "rr_B_slope_present") <- isTRUE(fit$use$rr_B_slope)
  class(out) <- c("gllvmTMB_slope_ci", class(out))
  out
}

#' @export
print.gllvmTMB_slope_ci <- function(x, ...) {
  cat(
    "Wald (log-SD-scale) intervals on augmented random-slope standard",
    "deviations; recovery-only (D-112). Coverage is NOT certified for any",
    "family (CI-08/CI-10, docs/design/35-validation-debt-register.md).",
    sep = "\n"
  )
  if (isTRUE(attr(x, "rr_B_slope_present"))) {
    cat(
      "This fit also has a shared random-slope loadings component",
      "(theta_rr_B_slope); `estimate` is the per-trait UNIQUE (Psi)",
      "diagonal component of slope variance only, not the total marginal",
      "slope SD -- see ?slope_sd_ci.",
      sep = "\n"
    )
  }
  cat("\n")
  print.data.frame(x, ...)
  invisible(x)
}
