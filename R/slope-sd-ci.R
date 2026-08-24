## Wald (delta-method) confidence intervals on random-slope standard
## deviations, read off `sdreport()` ADREPORT()ed quantities.
##
## SLICE 1 (2026-08-18): the ordinary augmented-diagonal latent()/unique()
## route only (`theta_diag_B_slope`, `src/gllvmTMB.cpp:1606`, a genuine
## univariate log-SD parameter). `exp(theta +/- z * se(theta))` on the raw
## parameter and its `cov.fixed` SE is an exact transformed Wald interval --
## no Jacobian, no hand-indexing.
##
## SLICE 2 (2026-08-19): extends coverage to the two routes slice 1
## deliberately refused (register row CI-15) -- the phylogenetic Cholesky
## augmented-slope route (`theta_dep_chol`, `fit$use$phylo_dep_slope`) and
## the loadings-only augmented random-slope route (`theta_rr_B_slope` with
## no diagonal companion). Both need a MULTIVARIATE delta method: the
## marginal slope variance is a quadratic form in several packed parameters
## (e.g. `Var(slope_t) = L21_t^2 + exp(diag_slope_t)^2` for the phylo
## Cholesky block), not a single log-SD. The robust way to run that delta
## method is `ADREPORT()` inside the C++ template
## (`src/gllvmTMB.cpp`: `sd_b` in the `theta_dep_chol` branch,
## `sd_rr_B_slope` alongside `Sigma_B_slope`, `sd_B_slope_total` alongside
## `Sigma_B_unique_slope`) so `sdreport()` differentiates the exact packed
## expression and this file only reads the named result out of
## `summary(fit$sd_report, "report")` -- never re-deriving positions by
## hand-indexing `cov.fixed` against a copied packing convention. That
## hand-indexing failure mode is not hypothetical: a first attempt at the
## phylo route indexed `theta_dep_chol` entries 2/5/8 instead of the
## correct 2/4/6 and exponentiated a raw off-diagonal entry as if it were a
## log-SD (`dev/slope-interval-feasibility-RESULTS.md`).
##
## When BOTH `theta_diag_B_slope` and `theta_rr_B_slope` are present (the
## default combination for `latent(...)`, which folds in the diagonal Psi
## companion by default), `estimate` for the diagonal route remains the
## per-trait UNIQUE (Psi) component of slope variance only (unchanged from
## slice 1) -- but `total_sd` now ALSO carries an interval
## (`total_lower`/`total_upper`), read from the C++-side
## `sd_B_slope_total = sqrt(diag(Sigma_B_slope) + diag(Sigma_B_unique_slope))`
## ADREPORT, which differentiates through BOTH parameter blocks jointly (an
## R-side sum of two independently-computed SEs could not do this
## correctly, because it would ignore any correlation between
## `theta_rr_B_slope` and `theta_diag_B_slope` in the Hessian).
##
## Reference: `dev/fable-extractor-recommendation.md` (Fable planning
## lens, 2026-08-18), `dev/slope-interval-feasibility-RESULTS.md` (the
## measured facts it rests on) and `dev/S6-slope-sd-ci-review.md` (the
## adversarial review that shaped slice 1 and named the ADREPORT route for
## slice 2) -- all carried in this branch's `dev/` directory so the
## citations below stay resolvable from `main`. Register rows CI-14
## (`partial`, all routes as of slice 2) / CI-15 (unblocked by slice 2;
## see the register for the updated status) in
## `docs/design/35-validation-debt-register.md`.

## ---- Internal helpers shared by every route ------------------------------

#' @noRd
.slope_ci_adreport_lookup <- function(fit, name, n_expected) {
  if (is.null(fit$sd_report) || !inherits(fit$sd_report, "sdreport"))
    return(list(ok = FALSE, reason = "no_sdreport"))
  tab <- tryCatch(summary(fit$sd_report, "report"), error = function(e) NULL)
  if (is.null(tab) || !("Std. Error" %in% colnames(tab)))
    return(list(ok = FALSE, reason = "no_report_summary"))
  rows <- which(rownames(tab) == name)
  if (length(rows) != n_expected)
    return(list(ok = FALSE, reason = "length_mismatch"))
  list(
    ok = TRUE,
    estimate = as.numeric(tab[rows, "Estimate"]),
    se       = as.numeric(tab[rows, "Std. Error"])
  )
}

#' @noRd
.slope_ci_natural_to_log <- function(estimate, se) {
  bad <- !is.finite(estimate) | estimate <= 0
  theta <- ifelse(bad, NA_real_, log(estimate))
  se_theta <- ifelse(bad | !is.finite(se), NA_real_, se / estimate)
  list(theta = theta, se_theta = se_theta)
}

#' @noRd
.slope_ci_rows <- function(theta, se_theta, pd_ok, level, scale) {
  n <- length(theta)
  sd_hat <- exp(theta) # NA propagates

  se_blowup <- is.finite(se_theta) & se_theta > 10
  near_zero_relative <- rep(FALSE, n)
  if (n > 1L) {
    for (t in seq_len(n)) {
      others_max <- suppressWarnings(max(sd_hat[-t], na.rm = TRUE))
      if (is.finite(others_max) && others_max > 0 && is.finite(sd_hat[t]))
        near_zero_relative[t] <- (sd_hat[t] / others_max) <= 0.01
    }
  }

  if (!pd_ok) {
    status <- rep("no_pd_hessian", n)
  } else {
    status <- ifelse(
      !is.finite(theta) | !is.finite(se_theta), "se_nonfinite",
      ifelse(se_blowup, "se_blowup",
      ifelse(near_zero_relative, "near_zero_relative", "ok"))
    )
  }

  z <- stats::qnorm(0.5 + level / 2)
  estimate <- if (identical(scale, "variance")) sd_hat^2 else sd_hat

  lower <- rep(NA_real_, n)
  upper <- rep(NA_real_, n)
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

  list(estimate = estimate, lower = lower, upper = upper, status = status)
}

#' @noRd
.slope_ci_emit_guard_warnings <- function(status, pd_ok, n) {
  if (!pd_ok) {
    cli::cli_warn(c(
      "Fit's Hessian is not positive-definite at the optimum.",
      "i" = "Returning point estimates only; {.code lower} / {.code upper} are NA for every slope -- Wald inference is unavailable for this fit."
    ))
    return(invisible())
  }
  n_nonfinite <- sum(status == "se_nonfinite")
  if (n_nonfinite > 0L)
    cli::cli_warn(c(
      "{.code se_theta} is non-finite for {n_nonfinite} of {n} slope(s).",
      "i" = "Returning point estimates only for those rows; {.code lower} / {.code upper} are NA."
    ))
  n_blowup <- sum(status == "se_blowup")
  if (n_blowup > 0L)
    cli::cli_warn(c(
      "{.code se_theta} exceeds 10 on the log scale for {n_blowup} of {n} slope(s) -- essentially information-free.",
      "i" = "Returning point estimates only for those rows; {.code lower} / {.code upper} are NA."
    ))
  n_near_zero <- sum(status == "near_zero_relative")
  if (n_near_zero > 0L)
    cli::cli_warn(c(
      "{n_near_zero} of {n} slope(s) have an SD at most 1% of this fit's largest slope SD -- a likely boundary/Heywood collapse.",
      "i" = "Returning point estimates only for those rows; {.code lower} / {.code upper} are NA."
    ))
  invisible()
}

## ---- Route: phylogenetic Cholesky augmented slope (theta_dep_chol) ------
## `phylo_dep(1 + x1 + ... + xs | species)` / `phylo_indep(1 + x | species)`.
## Sigma_b_dep = Lb Lb' is a FULL (1+s)*T x (1+s)*T unstructured covariance
## over interleaved (intercept, slope_1, ..., slope_s) x trait coordinates
## (`src/gllvmTMB.cpp` ~1909-1944; stride = 1 + s per trait,
## `R/fit-multi.R:4008-4014`). `sd_b(j) = sqrt(Sigma_b_dep(j,j))` is already
## `REPORT()`ed and, as of slice 2, `ADREPORT()`ed, so the marginal slope
## SD's delta-method SE comes directly from `sdreport()`.
#' @noRd
.slope_sd_ci_phylo_dep <- function(fit, level, scale, pd_ok) {
  trait_names <- levels(fit$data[[fit$trait_col]])
  n_traits <- length(trait_names)
  slope_cols <- fit$use$phylo_dep_slope_cols
  n_phy_slope <- length(slope_cols)
  if (n_phy_slope < 1L)
    cli::cli_abort(
      "Internal: {.code fit$use$phylo_dep_slope} is TRUE but {.code phylo_dep_slope_cols} is empty."
    )
  stride <- 1L + n_phy_slope
  C <- stride * n_traits

  report_sd_b <- as.numeric(fit$report$sd_b)
  if (length(report_sd_b) != C)
    cli::cli_abort(
      "Internal: {.code fit$report$sd_b} has length {length(report_sd_b)}; expected {C} (= (1 + n_slope) * n_traits) for the phylo_dep/indep slope route."
    )

  adr <- .slope_ci_adreport_lookup(fit, "sd_b", C)
  if (!isTRUE(adr$ok))
    cli::cli_abort(c(
      "Internal: ADREPORTed {.code sd_b} is unavailable or has an unexpected length ({.code {adr$reason}}).",
      "i" = "This should never happen for a fit whose {.code sd_report} is present with {.code fit$use$phylo_dep_slope} TRUE."
    ))
  ## Cross-check: the ADREPORT point estimate must equal the already-
  ## REPORT()ed report$sd_b (same forward computation) -- this is the test
  ## shape that would have caught the 2/5/8-vs-2/4/6 packing bug on day one.
  if (!isTRUE(all.equal(adr$estimate, report_sd_b, tolerance = 1e-6)))
    cli::cli_abort(
      "Internal: ADREPORTed {.code sd_b} does not match {.code fit$report$sd_b}; packing mismatch between ADREPORT and REPORT of the same quantity."
    )

  trait_idx <- rep(seq_len(n_traits), each = n_phy_slope)
  slope_j <- rep(seq_len(n_phy_slope), times = n_traits)
  full_pos <- (trait_idx - 1L) * stride + 1L + slope_j
  term <- slope_cols[slope_j]

  log_se <- .slope_ci_natural_to_log(adr$estimate[full_pos], adr$se[full_pos])
  rows <- .slope_ci_rows(log_se$theta, log_se$se_theta, pd_ok, level, scale)
  .slope_ci_emit_guard_warnings(rows$status, pd_ok, length(full_pos))

  out <- data.frame(
    trait           = factor(trait_names[trait_idx], levels = trait_names),
    term            = term,
    estimate        = rows$estimate,
    lower           = rows$lower,
    upper           = rows$upper,
    component       = "total",
    total_sd        = rows$estimate,
    total_lower     = rows$lower,
    total_upper     = rows$upper,
    total_status    = rows$status,
    theta           = log_se$theta,
    se_theta        = log_se$se_theta,
    method          = "wald_log_scale_adreport",
    interval_status = "wald_uncalibrated",
    status          = rows$status,
    scale           = scale,
    stringsAsFactors = FALSE
  )
  attr(out, "calibrated") <- FALSE
  attr(out, "level") <- level
  attr(out, "rr_B_slope_present") <- FALSE
  class(out) <- c("gllvmTMB_slope_ci", class(out))
  out
}

## ---- Route: loadings-only augmented random slope (theta_rr_B_slope,
## no diagonal companion) --------------------------------------------------
## E.g. `latent(0 + trait + (0 + trait):x | unit, d = K, unique = FALSE)`.
## Sigma_B_slope = Lambda_B_slope Lambda_B_slope' over the same 2*n_traits
## interleaved (intercept, slope) x trait coordinates as the diagonal route
## (`src/gllvmTMB.cpp` ~1555-1591). `sd_rr_B_slope(j) = sqrt(Sigma_B_slope(j,j))`
## is a quadratic form in several `theta_rr_B_slope` loading entries, so its
## SE needs the same ADREPORT delta method as the phylo route above.
#' @noRd
.slope_sd_ci_loadings_only <- function(fit, level, scale, pd_ok) {
  trait_names <- levels(fit$data[[fit$trait_col]])
  n_traits <- length(trait_names)
  n_lhs <- 2L * n_traits

  report_val <- as.numeric(fit$report$sd_rr_B_slope)
  if (length(report_val) != n_lhs)
    cli::cli_abort(
      "Internal: {.code fit$report$sd_rr_B_slope} has length {length(report_val)}; expected {n_lhs} (= 2 * n_traits) for the loadings-only augmented slope route."
    )

  adr <- .slope_ci_adreport_lookup(fit, "sd_rr_B_slope", n_lhs)
  if (!isTRUE(adr$ok))
    cli::cli_abort(c(
      "Internal: ADREPORTed {.code sd_rr_B_slope} is unavailable or has an unexpected length ({.code {adr$reason}}).",
      "i" = "This should never happen for a fit whose {.code sd_report} is present with {.code fit$use$rr_B_slope} TRUE and no diagonal companion."
    ))
  if (!isTRUE(all.equal(adr$estimate, report_val, tolerance = 1e-6)))
    cli::cli_abort(
      "Internal: ADREPORTed {.code sd_rr_B_slope} does not match {.code fit$report$sd_rr_B_slope}; packing mismatch between ADREPORT and REPORT of the same quantity."
    )

  slope_pos <- seq(2L, n_lhs, by = 2L)
  slope_col <- fit$use$rr_B_slope_col %||% fit$use$diag_B_slope_col
  if (is.null(slope_col))
    cli::cli_abort(
      "Could not determine the slope covariate name ({.code fit$use$rr_B_slope_col} / {.code diag_B_slope_col} are both missing)."
    )

  log_se <- .slope_ci_natural_to_log(adr$estimate[slope_pos], adr$se[slope_pos])
  rows <- .slope_ci_rows(log_se$theta, log_se$se_theta, pd_ok, level, scale)
  .slope_ci_emit_guard_warnings(rows$status, pd_ok, n_traits)

  out <- data.frame(
    trait           = factor(trait_names, levels = trait_names),
    term            = slope_col,
    estimate        = rows$estimate,
    lower           = rows$lower,
    upper           = rows$upper,
    component       = "total",
    total_sd        = rows$estimate,
    total_lower     = rows$lower,
    total_upper     = rows$upper,
    total_status    = rows$status,
    theta           = log_se$theta,
    se_theta        = log_se$se_theta,
    method          = "wald_log_scale_adreport",
    interval_status = "wald_uncalibrated",
    status          = rows$status,
    scale           = scale,
    stringsAsFactors = FALSE
  )
  attr(out, "calibrated") <- FALSE
  attr(out, "level") <- level
  attr(out, "rr_B_slope_present") <- TRUE
  class(out) <- c("gllvmTMB_slope_ci", class(out))
  out
}

#' Wald confidence intervals on augmented random-slope standard deviations
#'
#' Per-trait confidence intervals on the standard deviation of an augmented
#' random-slope term. All intervals are delta-method Wald intervals built on
#' the log-SD scale so the bounds stay positive by construction. Three
#' underlying routes are covered, dispatched automatically from the fit's
#' structure:
#' \itemize{
#'   \item The ordinary augmented **diagonal** (Psi) route
#'     (`theta_diag_B_slope`, from `latent(0 + trait + (0 + trait):x |
#'     unit, d = K)` or `unique(...)`). `theta_diag_B_slope` is a genuine
#'     univariate log-SD (`sd = exp(theta)`), so the interval is read
#'     directly off `sdreport()`'s `cov.fixed` -- no Jacobian.
#'   \item The **phylogenetic Cholesky** augmented-slope route
#'     (`theta_dep_chol`, from `phylo_dep(1 + x1 + ... + xs | species)` /
#'     `phylo_indep(1 + x | species)`). The marginal slope SD is a
#'     nonlinear function of several packed Cholesky entries (
#'     `Var(slope_t) = L21_t^2 + exp(diag_slope_t)^2` for a single slope),
#'     so its standard error comes from an `ADREPORT()`ed quantity in the
#'     C++ template (`sd_b`), letting `sdreport()` run the multivariate
#'     delta method against the authoritative packing.
#'   \item The **loadings-only** augmented random-slope route
#'     (`theta_rr_B_slope` with no diagonal companion, e.g.
#'     `latent(..., unique = FALSE)`). The marginal slope variance is a
#'     quadratic form in several loading entries
#'     (`Lambda_B_slope \%*\% t(Lambda_B_slope)`), again handled via an
#'     `ADREPORT()`ed quantity (`sd_rr_B_slope`).
#' }
#'
#' @section Scope boundary -- what this interval IS and IS NOT:
#' Every interval returned by this function is a **transformed Wald
#' interval read off `sdreport()`**, the same inferential instrument as
#' [loading_ci()] and [confint_inspect()]: it uses the asymptotic normal
#' approximation and propagates it through a monotone log/exp transform.
#' It is **not a calibrated coverage statement** -- no repeated-sampling
#' coverage campaign has been run for any of these estimands, and
#' `interval_status = "wald_uncalibrated"` marks every row as such. The
#' package's validation-debt ledger records this as tested-but-not-
#' coverage-certified (see the ledger for the current status).
#'
#' When the fit's random-slope term carries BOTH a diagonal Psi companion
#' and a shared loadings component (`theta_rr_B_slope`, the default
#' alongside `theta_diag_B_slope` for ordinary `latent()`), `estimate` for
#' that route is the per-trait UNIQUE (Psi) component of slope variance
#' only -- it excludes the shared loadings contribution to the marginal
#' slope variance, and can understate the total marginal slope SD
#' substantially (measured up to ~45% on a recovery fixture). This
#' restriction travels with the **data**, not only the print method: the
#' `component` column reads `"unique_psi"` in that case (`"total"`
#' otherwise -- including for the phylogenetic and loadings-only routes,
#' where the reported quantity already IS the total marginal slope SD).
#' `total_sd` always reports the total marginal slope SD as a point
#' estimate. `total_lower` / `total_upper` report a genuine interval on
#' that total wherever the C++ template `ADREPORT()`s the combined
#' expression directly (both routes as of this version); `total_status`
#' names the same kill-switch statuses as `status` when that support is
#' present, or `"unavailable"` when it is not (e.g. a fit refit under an
#' older package version whose ADREPORT does not yet exist). A
#' `cli::cli_warn()` fires on the call itself whenever the shared loadings
#' block is present alongside the diagonal route, not only when the result
#' is printed.
#'
#' @param fit A multi-trait `gllvmTMB()` fit with at least one augmented
#'   random-slope structure covered above.
#' @param level Confidence level. Defaults to 0.95.
#' @param scale `"sd"` (default) returns the standard deviation scale;
#'   `"variance"` returns the variance scale (`estimate^2`, bounds
#'   `exp(2 * (theta +/- z * se(theta)))`). Both scales are computed from
#'   the identical `theta` / `se_theta`, so they agree by construction.
#'   `total_sd` is always reported on the SD scale regardless of `scale`;
#'   `total_lower` / `total_upper` follow `scale` like `lower` / `upper`.
#'
#' @return A data frame of class `gllvmTMB_slope_ci`, one row per slope SD
#'   (trait x slope term), with columns:
#'   \describe{
#'     \item{`trait`}{Trait factor level.}
#'     \item{`term`}{The slope covariate name.}
#'     \item{`estimate`, `lower`, `upper`}{On the requested `scale`. `lower`
#'       / `upper` are `NA` whenever `status != "ok"`.}
#'     \item{`component`}{`"unique_psi"` when the diagonal route's fit also
#'       carries a shared loadings block, so `estimate` is only part of the
#'       marginal slope SD; `"total"` otherwise, meaning `estimate` already
#'       is the total marginal slope SD.}
#'     \item{`total_sd`}{Point estimate of the TOTAL marginal slope SD, on
#'       the SD scale regardless of `scale`. Equal to `estimate` when
#'       `component == "total"`.}
#'     \item{`total_lower`, `total_upper`}{Interval on `total_sd`, on the
#'       requested `scale`. `NA` whenever `total_status != "ok"` or the
#'       supporting ADREPORT is unavailable.}
#'     \item{`total_status`}{Kill-switch status for the `total_sd`
#'       interval; see below. `"unavailable"` when no supporting ADREPORT
#'       exists (only possible for the diagonal route on a stale cached
#'       fit).}
#'     \item{`theta`, `se_theta`}{The log-SD estimate and its standard
#'       error, for auditability. For the diagonal route these are the raw
#'       fixed-effect parameter and its `cov.fixed` SE (unchanged from
#'       slice 1); for the phylogenetic and loadings-only routes these are
#'       derived from an ADREPORTed natural-scale quantity via the delta
#'       method `se(log(X)) = se(X) / X`.}
#'     \item{`method`}{`"wald_log_scale"` for the diagonal route (direct
#'       parameter read), `"wald_log_scale_adreport"` for the phylogenetic
#'       and loadings-only routes (ADREPORT delta method).}
#'     \item{`interval_status`}{Always `"wald_uncalibrated"`.}
#'     \item{`status`}{`"ok"`, `"no_pd_hessian"`, `"se_nonfinite"`,
#'       `"se_blowup"`, or `"near_zero_relative"` -- see Kill-switch guard
#'       below.}
#'     \item{`scale`}{The requested scale, `"sd"` or `"variance"`.}
#'   }
#'   The returned object also carries a hard-coded attribute
#'   `calibrated = FALSE` (never an argument; only a future coverage
#'   certificate can flip this in the source), and the requested `level`.
#'
#' @section Kill-switch guard -- point estimates always, intervals never from a fit that cannot support one:
#' Applied identically to every route. `lower`/`upper` (and, where
#' supported, `total_lower`/`total_upper`) are set to `NA` (with `status`
#' explaining why and a `cli::cli_warn()`) whenever any of:
#' \itemize{
#'   \item `fit$sd_report$pdHess` is `FALSE` (`status = "no_pd_hessian"`,
#'     applies to every row);
#'   \item the log-SD estimate or its standard error is non-finite
#'     (`status = "se_nonfinite"`) -- for the ADREPORT-based routes this
#'     also covers a non-positive natural-scale estimate, which cannot be
#'     logged;
#'   \item `se_theta > 10` on the log scale -- essentially information-free
#'     (an SE of 10 on the log scale means the interval would span
#'     \eqn{e^{40}}); `status = "se_blowup"`;
#'   \item `sd_hat` is at most 1% of the largest `sd_hat` among this fit's
#'     OTHER slope coordinates on the SAME route (only evaluated when there
#'     is more than one to compare against); `status = "near_zero_relative"`,
#'     mirroring the package's relative-to-siblings convention for a
#'     collapsed variance component (`psi_rel_thresh` / `near_zero_psi_*`,
#'     `R/diagnose.R`).
#' }
#' The point estimate (`estimate`, `theta`) is always returned, following
#' the house line that a non-PD Hessian disqualifies standard errors but
#' not point estimates (`R/bootstrap-sigma.R`, `R/cv-internal.R`).
#'
#' @seealso [loading_ci()] for the equivalent interval on Lambda entries;
#'   [extract_Sigma()] with `level = "unit_slope"` or `level = "phy"` for
#'   the full augmented covariance (point estimates only).
#'
#' @examples
#' \dontrun{
#' set.seed(1)
#' n_ind <- 30L
#' n_traits <- 2L
#' trait_levels <- paste0("t", seq_len(n_traits))
#' individuals <- paste0("id", seq_len(n_ind))
#' df <- expand.grid(
#'   individual = factor(individuals, levels = individuals),
#'   rep = 1:5,
#'   trait = factor(trait_levels, levels = trait_levels)
#' )
#' df$x <- stats::rnorm(nrow(df))
#' alpha <- c(0.2, -0.1)
#' beta <- c(0.3, -0.2)
#' psi_noise <- matrix(stats::rnorm(4L * n_ind, sd = 0.25), nrow = 4L)
#' eta <- numeric(nrow(df))
#' for (o in seq_len(nrow(df))) {
#'   tt <- as.integer(df$trait[o])
#'   ii <- as.integer(df$individual[o])
#'   base <- 2L * (tt - 1L)
#'   eta[o] <- alpha[tt] + beta[tt] * df$x[o] +
#'     psi_noise[base + 1L, ii] + psi_noise[base + 2L, ii] * df$x[o]
#' }
#' df$value <- eta + stats::rnorm(nrow(df), sd = 0.3)
#'
#' options(gllvmTMB.quiet_grammar_notes = TRUE)
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + (0 + trait):x +
#'     unique(0 + trait + (0 + trait):x | individual),
#'   data = df,
#'   trait = "trait",
#'   unit  = "individual",
#'   control = gllvmTMBcontrol(se = TRUE, optimizer = "optim",
#'                              optArgs = list(method = "BFGS"))
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

  ## This route has a predictor-basis covariance but no interval contract yet;
  ## redirect before asking for an irrelevant sdreport payload.
  if (isTRUE(fit$use$phylo_column_slope)) {
    cli::cli_abort(c(
      "{.fun slope_sd_ci} does not yet provide intervals for slope-only response-column covariance.",
      "i" = "Use {.code extract_Sigma(fit, level = \"column_slope\")} for the Gaussian point-estimate predictor covariance.",
      ">" = "Interval support for this parameterisation is deferred until a dedicated ADREPORT recovery slice."
    ))
  }

  if (is.null(fit$sd_report) || !inherits(fit$sd_report, "sdreport"))
    cli::cli_abort(c(
      "Fit does not carry a TMB {.code sdreport}.",
      "i" = "Refit so {.code fit$sd_report} is populated (default {.code se = TRUE})."
    ))
  pd_ok <- isTRUE(fit$sd_report$pdHess)

  ## ---- Route dispatch ---------------------------------------------------
  if (isTRUE(fit$use$phylo_dep_slope))
    return(.slope_sd_ci_phylo_dep(fit, level, scale, pd_ok))

  if (!isTRUE(fit$use$diag_B_slope)) {
    if (isTRUE(fit$use$rr_B_slope))
      return(.slope_sd_ci_loadings_only(fit, level, scale, pd_ok))
    cli::cli_abort(c(
      "Fit has no augmented random-slope structure ({.code theta_diag_B_slope}, {.code theta_rr_B_slope}, or {.code theta_dep_chol}) to summarise.",
      "i" = "Refit with a {.fn latent} or {.fn indep} term of the form {.code (0 + trait + (0 + trait):x | unit, d = K)}, or a {.fn phylo_dep} / {.fn phylo_indep} random-regression term."
    ))
  }

  ## ---- Ordinary augmented diagonal (Psi) route (slice 1, unchanged) ----
  trait_names <- levels(fit$data[[fit$trait_col]])
  n_traits <- length(trait_names)

  par_names <- names(fit$opt$par)
  ix_diag <- which(par_names == "theta_diag_B_slope")
  if (length(ix_diag) != 2L * n_traits)
    cli::cli_abort(c(
      "Unexpected {.code theta_diag_B_slope} length.",
      "x" = "Found {length(ix_diag)} entries; expected {2L * n_traits} (2 per trait: intercept, slope)."
    ))

  slope_col <- fit$use$diag_B_slope_col %||% fit$use$rr_B_slope_col
  if (is.null(slope_col))
    cli::cli_abort(
      "Could not determine the slope covariate name ({.code fit$use$diag_B_slope_col} / {.code rr_B_slope_col} are both missing)."
    )

  ## `theta_diag_B_slope` interleaves (intercept, slope) per trait
  ## (`R/fit-multi.R` ~4116-4121: `base = 2 * trait_id`, intercept at
  ## `base + 1`, slope at `base + 2`), matching `extract_Sigma()`'s
  ## `aug_names` ordering. Keep the slope entries only (even positions).
  slope_pos <- seq(2L, 2L * n_traits, by = 2L)
  ix_slope <- ix_diag[slope_pos]

  ## `cov.fixed`'s rows/columns are ordered identically to `fit$opt$par`
  ## (both come from the same `sdreport()` call against the same fixed
  ## vector) -- assert it rather than assume it, so a future engine change
  ## (e.g. a `map`/profile route with a different fixed-parameter order)
  ## fails loudly here instead of silently misindexing.
  cov_names <- rownames(fit$sd_report$cov.fixed)
  if (!is.null(cov_names) && !identical(cov_names, par_names))
    cli::cli_abort(
      "{.code fit$sd_report$cov.fixed} row names do not match {.code names(fit$opt$par)}; cannot align {.code theta_diag_B_slope} positions safely."
    )

  theta <- as.numeric(fit$opt$par[ix_slope])
  se_theta <- tryCatch(
    suppressWarnings(as.numeric(sqrt(diag(fit$sd_report$cov.fixed))[ix_slope])),
    error = function(e) rep(NA_real_, length(ix_slope))
  )

  rows <- .slope_ci_rows(theta, se_theta, pd_ok, level, scale)
  .slope_ci_emit_guard_warnings(rows$status, pd_ok, n_traits)

  ## ---- Total marginal slope SD: point estimate (as slice 1), now with
  ## an interval wherever the C++ ADREPORT of the combined expression
  ## supports it (sd_B_slope_total, additive over this slice). ----------
  rr_present <- isTRUE(fit$use$rr_B_slope)
  total_sd <- rows$estimate
  total_lower <- rows$lower
  total_upper <- rows$upper
  total_status <- rows$status

  if (rr_present) {
    n_lhs <- 2L * n_traits
    report_tot <- fit$report$sd_B_slope_total
    if (is.null(report_tot)) {
      ## Stale cached fit predating this slice's C++ change, or the
      ## legacy `fit$report$Sigma_B_slope`-only path. Fall back to the
      ## slice-1 point-estimate-only formula; no interval is available.
      Sigma_B_slope <- fit$report$Sigma_B_slope
      if (is.null(Sigma_B_slope)) {
        cli::cli_warn(c(
          "Fit has {.code use$rr_B_slope = TRUE} but no {.code report$Sigma_B_slope}.",
          "i" = "{.code total_sd} cannot be computed; reporting the unique (Psi) component only."
        ))
        shared_var_slope <- rep(0, n_traits)
      } else {
        shared_var_slope <- as.numeric(diag(as.matrix(Sigma_B_slope)))[slope_pos]
      }
      total_sd <- sqrt(shared_var_slope + rows$estimate^2)
      total_lower <- rep(NA_real_, n_traits)
      total_upper <- rep(NA_real_, n_traits)
      total_status <- rep("unavailable", n_traits)
    } else {
      report_tot <- as.numeric(report_tot)
      if (length(report_tot) != n_lhs)
        cli::cli_abort(
          "Internal: {.code fit$report$sd_B_slope_total} has length {length(report_tot)}; expected {n_lhs} (= 2 * n_traits)."
        )
      adr_tot <- .slope_ci_adreport_lookup(fit, "sd_B_slope_total", n_lhs)
      if (!isTRUE(adr_tot$ok)) {
        total_sd <- report_tot[slope_pos]
        total_lower <- rep(NA_real_, n_traits)
        total_upper <- rep(NA_real_, n_traits)
        total_status <- rep("unavailable", n_traits)
      } else {
        if (!isTRUE(all.equal(adr_tot$estimate, report_tot, tolerance = 1e-6)))
          cli::cli_abort(
            "Internal: ADREPORTed {.code sd_B_slope_total} does not match {.code fit$report$sd_B_slope_total}; packing mismatch between ADREPORT and REPORT of the same quantity."
          )
        log_se_tot <- .slope_ci_natural_to_log(
          adr_tot$estimate[slope_pos], adr_tot$se[slope_pos]
        )
        rows_tot <- .slope_ci_rows(log_se_tot$theta, log_se_tot$se_theta, pd_ok, level, scale)
        total_sd <- report_tot[slope_pos]
        total_lower <- rows_tot$lower
        total_upper <- rows_tot$upper
        total_status <- rows_tot$status
      }
    }
  }

  component <- if (rr_present) "unique_psi" else "total"

  if (rr_present)
    cli::cli_warn(c(
      "This fit also has a shared random-slope loadings component ({.code theta_rr_B_slope}).",
      "i" = "{.code estimate} is the per-trait UNIQUE (Psi) component of slope variance only; see the {.code component} / {.code total_sd} / {.code total_lower} / {.code total_upper} columns and {.code ?slope_sd_ci}."
    ))

  out <- data.frame(
    trait           = factor(trait_names, levels = trait_names),
    term            = slope_col,
    estimate        = rows$estimate,
    lower           = rows$lower,
    upper           = rows$upper,
    component       = component,
    total_sd        = total_sd,
    total_lower     = total_lower,
    total_upper     = total_upper,
    total_status    = total_status,
    theta           = theta,
    se_theta        = se_theta,
    method          = "wald_log_scale",
    interval_status = "wald_uncalibrated",
    status          = rows$status,
    scale           = scale,
    stringsAsFactors = FALSE
  )
  attr(out, "calibrated") <- FALSE
  attr(out, "level") <- level
  attr(out, "rr_B_slope_present") <- rr_present
  class(out) <- c("gllvmTMB_slope_ci", class(out))
  out
}

#' @export
print.gllvmTMB_slope_ci <- function(x, ...) {
  cat(
    "Wald (log-SD-scale) intervals on augmented random-slope standard",
    "deviations. These are recovery-only, UNCALIBRATED intervals --",
    "repeated-sampling coverage has not been measured for this estimand,",
    "for any family. Consult the package's current limitations for",
    "the applicable validation boundary.",
    sep = "\n"
  )
  if (isTRUE(attr(x, "rr_B_slope_present"))) {
    cat(
      "This fit also has a shared random-slope loadings component",
      "(theta_rr_B_slope); `estimate` is the per-trait UNIQUE (Psi)",
      "diagonal component of slope variance only -- see the `component`",
      "and `total_sd` / `total_lower` / `total_upper` columns for the",
      "total marginal slope SD.",
      sep = "\n"
    )
  }
  cat("\n")
  print.data.frame(x, ...)
  invisible(x)
}
