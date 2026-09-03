## Per-unit joint covariance of ordination scores (issue #1243, D-204 parity
## with GLLVM.jl's `ordination_uncertainty()`).
##
## `getLV(se = TRUE)` (R/output-methods.R) already exposes the MARGINAL
## standard error of every unit-level (or within-unit) latent score, read
## from `fit$sd_report$diag.cov.random` -- one number per (unit, axis) cell,
## already verified (`dev/getlv-score-se-RESULTS.md`) against an independent
## joint-precision-inversion route to machine precision. What it does not
## give is the CROSS-AXIS covariance within one unit's own score vector --
## the off-diagonal entries needed to draw an ellipse (rather than an
## axis-aligned error bar) around a site in a biplot. That needs the
## fit's joint (fixed + random) precision matrix
## (`TMB::sdreport(obj, getJointPrecision = TRUE)`) so fixed-effect
## estimation uncertainty is correctly propagated into the random-effect
## block, not just its own conditional-at-theta-hat curvature -- the same
## route already used for predictive score covariance elsewhere in the
## package (`R/methods-gllvmTMB.R`'s `.gllvmTMB_predict_missing_var_eta_joint`
## / `.gllvmTMB_predict_missing_sim`, and `.getLV_se()` itself, whose header
## comment notes the two routes agree to machine precision for the diagonal).
## `ordination_uncertainty()` is the natural generalisation of that existing
## machinery to the full per-unit covariance block, not a new statistical
## idea.
##
## THE ESTIMAND. `u_s | y` for site s: the CONDITIONAL (posterior) covariance
## of the latent score random effect given the observed data, at the fit's
## MLE/MAP for the fixed parameters -- a prediction-uncertainty statement
## about a random effect, not a sampling-distribution standard error of a
## fixed quantity. See the roxygen "Estimand" section below for the reader
## -facing version of this paragraph.
##
## ROTATION / IDENTIFIABILITY. gllvmTMB's `latent()` unit- and
## within-unit-tier loading matrices (`Lambda_B` / `Lambda_W`) are packed by
## `gll_unpack_rr_loadings()` (`src/gllvmTMB.cpp`) into a matrix whose upper
## triangle is STRUCTURALLY zero -- not a free parameter at all, never
## estimated -- with a free-SIGNED diagonal (see
## `.gllvmTMB_rr_loading_theta_positions()`, `R/methods-gllvmTMB.R`, and the
## header comment of `R/rotate-loadings.R`: "Its diagonal is free-SIGNED (not
## pinned positive at fit time), so the raw loadings still carry sign /
## rotation indeterminacy"). This is the classical lower-triangular
## reduced-rank identifiability device (the same one `gllvm`'s own default
## uses): by the uniqueness of a QR-style decomposition, an orthogonal
## transform R that keeps a generic invertible lower-triangular matrix lower
## -triangular must itself be a diagonal signature matrix (entries in
## {-1, +1}) -- so the ONLY residual ambiguity left in `rotate = "none"`
## scores is a discrete per-axis SIGN FLIP, never a continuous rotation.
## `getLoadings()`'s "identified only up to rotation" advisory
## (R/output-methods.R) is using "rotation" loosely to name that same
## discrete sign group, consistent with the phrasing in `rotate-loadings.R`.
##
## Consequence for THIS function: a per-axis VARIANCE (the diagonal of the
## per-unit covariance block) is invariant to a sign flip of that axis, so
## `se` needs no caveat. A CROSS-AXIS covariance entry (site s, axis k1 vs
## k2) changes sign if axis k1 or k2's sign convention flips, but scores and
## covariance are read from the SAME converged fit under the SAME (fixed,
## if arbitrary) sign convention, so the returned covariance is exactly the
## one that belongs with the returned `scores` -- an ellipse drawn from
## `(scores[s, ], cov[, , s])` is correctly oriented for THIS fit's own
## biplot. What is NOT licensed: comparing the SIGN of a cross-axis
## covariance entry, or of an axis itself, across independent (re)fits --
## that sign is this fit's own arbitrary choice, exactly as in ordinary PCA
## or factor analysis. `rotate = "varimax"` / `"promax"` (`getLV()`,
## `rotate_loadings()`) apply a FURTHER linear transform after fitting whose
## effect on this covariance is not implemented (matching `getLV(se = TRUE)`,
## which already refuses `rotate != "none"` for the identical reason); this
## function therefore only ever reports uncertainty in the native
## (`rotate = "none"`) orientation.
##
## SCOPE. Mirrors `getLV(se = TRUE)`'s existing boundary, not a new one:
## native TMB Laplace fits only (`estimator = "ml"`, `integration = "laplace"`
## the default); `level = "unit"` fits with a predictor-informed score mean
## (`latent(..., lv = ~ x)`, `fit$use$lv_B`) are refused because the mean
## term's own uncertainty is not propagated (identical reasoning and refusal
## as `.getLV_se()`); `estimator = "mspl"` and likelihood-weighted fits are
## refused via the existing `.gllvmTMB_mspl_assert_inference()` /
## `.gllvmTMB_require_unweighted_inference()` gates; `engine = "julia"`
## bridge fits and `integration = "va"` fits are refused because neither
## carries the joint-precision object this route reads.

#' Per-unit covariance of ordination (latent) scores
#'
#' `getLV(se = TRUE)` reports a standard error for every latent-score cell,
#' one axis at a time. `ordination_uncertainty()` reports the full covariance
#' of a unit's score VECTOR across its axes -- the object needed to draw an
#' uncertainty ellipse (rather than an axis-aligned error bar) around a site
#' in an ordination biplot.
#'
#' @section Estimand (read this before using the output):
#' Latent scores are random effects, not fixed parameters. What this
#' function returns is the model's best guess at how far each site's score
#' could plausibly have landed given (a) the data actually observed at that
#' site and (b) the package's uncertainty about the fitted parameters
#' (loadings, dispersion, etc.) -- **not** a sampling-distribution standard
#' error of a fixed number, the way `std.error` on a regression coefficient
#' is. Two model fits refit on two different datasets would not be expected
#' to recover this quantity "on average" the way a coefficient SE is; it is
#' closer to a prediction interval than a confidence interval. Practically:
#' it answers "how sure is the model about THIS site's position on the
#' ordination plot," not "how much would the whole ordination move if I
#' recollected the data."
#'
#' Concretely, it is the covariance of \eqn{\mathbf u_s} (site \eqn{s}'s
#' latent score vector) given the data and the fitted model, read off the
#' fit's joint (fixed effects + random effects) precision matrix
#' (`TMB::sdreport(getJointPrecision = TRUE)`), so it propagates the
#' package's uncertainty about the loadings and other fixed parameters into
#' the score covariance, not just the Laplace curvature at the fixed-effect
#' point estimate.
#'
#' @section Rotation / identifiability:
#' Scores are reported in gllvmTMB's native fitting orientation
#' (`rotate = "none"`) only. That orientation is pinned by a structural
#' lower-triangular constraint on the loading matrix, which fixes the axes
#' up to a per-axis SIGN FLIP (a discrete choice), not a continuous
#' rotation. Per-axis variance (`se`) is unaffected by that sign choice.
#' The cross-axis covariance in `cov` is the one that belongs with the
#' returned `scores` from THIS fit, so an ellipse built from them is
#' correctly oriented for this fit's own biplot -- but do not compare the
#' *sign* of a cross-axis entry, or of an axis, across independent (re)fits;
#' that sign is this fit's own arbitrary convention, exactly as in ordinary
#' PCA or factor analysis. Rotated scores (`getLV(..., rotate = "varimax")`
#' / `"promax"`) are not supported -- the covariance's transform under a
#' post-hoc rotation is not implemented, matching `getLV(se = TRUE)`'s
#' existing `rotate = "none"`-only restriction.
#'
#' @section What this is not:
#' A Wald quantity read from asymptotic (delta-method / Laplace) theory, not
#' a resampled, profiled, or simulation-based interval. Its repeated
#' -sampling coverage has not been measured for this function; `se` and
#' `cov` are reported as-is, with no `lower`/`upper` bound, so that no
#' unmeasured coverage claim is implied by the return shape (the same
#' choice `getLV(se = TRUE)` already makes). A confidence ellipse built from
#' `cov` at some nominal level (e.g. via `stats::qchisq(level, df = 2)`) is
#' a standard asymptotic-normal construction, not a certified interval.
#'
#' @param fit A fitted multivariate model returned by [gllvmTMB()]. Must be
#'   a native TMB fit with `gllvmTMBcontrol(se = TRUE)` (the default);
#'   `engine = "julia"` bridge fits, `integration = "va"` fits, and
#'   `estimator = "mspl"` fits are refused (see Details).
#' @param level `"unit"` (between-unit, `z_B`) or `"unit_obs"` (within-unit,
#'   `z_W`). Deprecated aliases `"B"` and `"W"` are still accepted with a
#'   warning.
#'
#' @return `NULL` if the fit has no `latent()` term at the requested level
#'   (matching [extract_ordination()]). Otherwise a list of class
#'   `"gllvmTMB_ordination_uncertainty"`:
#'   \itemize{
#'     \item `scores` -- the `n x K` score matrix (identical to
#'       `getLV(fit, level)`, native `rotate = "none"` orientation).
#'     \item `se` -- an `n x K` matrix of per-(unit, axis) standard
#'       deviations; `sqrt(diag(cov[, , s]))` for row `s`, and numerically
#'       identical to `getLV(fit, level, se = TRUE)$se`.
#'     \item `cov` -- a `K x K x n` array; `cov[, , s]` is unit `s`'s
#'       latent-score covariance matrix, dimnamed by axis on the first two
#'       margins and by unit on the third.
#'     \item `level` -- the canonical level name (`"unit"` / `"unit_obs"`).
#'   }
#'   `se` and `cov` are filled with `NA` (with a warning) when the fit's
#'   Hessian is not positive-definite, matching `getLV(se = TRUE)`.
#'
#' @seealso [getLV()] for the marginal per-cell standard error this
#'   function generalises to a full per-unit covariance;
#'   [ordiplot()]'s `ellipse` argument, which draws the covariance this
#'   function returns.
#' @export
#' @examples
#' \dontrun{
#' u <- ordination_uncertainty(fit, level = "unit")
#' u$se           # same numbers as getLV(fit, "unit", se = TRUE)$se
#' u$cov[, , 1]   # site 1's 2x2 (or dxd) score covariance
#' }
ordination_uncertainty <- function(fit, level = "unit") {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  canonical_level <- .canonical_level_name(level)

  if (inherits(fit, "gllvmTMB_julia")) {
    cli::cli_abort(c(
      "{.fn ordination_uncertainty} is not available for {.code engine = \"julia\"} bridge fits.",
      "i" = "Bridge fits do not carry a native TMB {.fn sdreport} or joint precision matrix.",
      ">" = "Refit with {.code engine = \"tmb\"} (the default) to get score uncertainty."
    ), class = "gllvmTMB_ordination_uncertainty_julia_unsupported")
  }
  if (inherits(fit, "gllvmTMB_va")) {
    cli::cli_abort(c(
      "{.fn ordination_uncertainty} is not available for a variational ({.code integration = \"va\"}) fit.",
      "i" = "This route reads the joint precision of a Laplace-approximated marginal likelihood; a VA fit's own approximate posterior is a different, unvalidated object here.",
      ">" = "Use {.fn getLV} with {.code se = TRUE} for that fit's own per-unit variational posterior SD, or refit with {.code integration = \"laplace\"} (the default) for joint-precision score covariance."
    ), class = "gllvmTMB_ordination_uncertainty_va_unsupported")
  }
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort(c(
      "{.arg fit} must be a {.cls gllvmTMB_multi} fit (as returned by {.fn gllvmTMB}).",
      ">" = "Pass a fit returned by {.fn gllvmTMB}."
    ), class = "gllvmTMB_ordination_uncertainty_bad_fit")
  }
  .gllvmTMB_mspl_assert_inference(fit, "ordination_uncertainty")
  .gllvmTMB_require_unweighted_inference(fit, "ordination_uncertainty")

  ord <- extract_ordination(fit, level = canonical_level)
  if (is.null(ord)) {
    return(NULL)
  }

  if (level == "B" && isTRUE(fit$use$lv_B)) {
    cli::cli_abort(c(
      "{.fn ordination_uncertainty} is not yet supported for predictor-informed {.code latent(..., lv = ~ x)} fits.",
      "i" = "The unit-level score mean depends on the fitted {.field alpha_lv_B} coefficients, whose uncertainty is not yet propagated into the score covariance.",
      ">" = "Use {.fn getLV} (point estimates only) or {.fn extract_lv_effects} for the mean-structure coefficients' own SE."
    ), class = "gllvmTMB_ordination_uncertainty_lv_predictor_unsupported")
  }

  sd_rep <- fit$sd_report
  if (is.null(sd_rep)) {
    cli::cli_abort(c(
      "{.fn ordination_uncertainty} requires the fit's TMB {.fn sdreport}.",
      "i" = "This fit has no {.field sd_report} ({.code gllvmTMBcontrol(se = FALSE)}, or {.fn sdreport} failed at fitting time).",
      ">" = "Refit with {.code control = gllvmTMBcontrol(se = TRUE)} (the default)."
    ), class = "gllvmTMB_ordination_uncertainty_no_sdreport")
  }

  d <- if (level == "B") fit$d_B else fit$d_W
  n <- if (level == "B") fit$n_sites else fit$n_site_species
  z_name <- if (level == "B") "z_B" else "z_W"

  if (!isTRUE(sd_rep$pdHess)) {
    cli::cli_warn(c(
      "Fit's Hessian is not positive-definite at the optimum.",
      "i" = "Returning {.code NA} score covariance -- Wald inference is unavailable for this fit."
    ))
    se_mat <- matrix(NA_real_, nrow = n, ncol = d, dimnames = dimnames(ord$scores))
    cov_arr <- array(
      NA_real_, dim = c(d, d, n),
      dimnames = list(colnames(ord$scores), colnames(ord$scores), rownames(ord$scores))
    )
    return(structure(
      list(scores = ord$scores, se = se_mat, cov = cov_arr, level = canonical_level),
      class = "gllvmTMB_ordination_uncertainty"
    ))
  }

  ## One additional sdreport() call at the EXISTING optimum -- no
  ## re-optimisation, no refit -- to attach the joint precision block that
  ## the fit's production sdreport() (getJointPrecision = FALSE) does not
  ## carry. Same route as `.gllvmTMB_predict_missing_var_eta_joint()` /
  ## `.gllvmTMB_predict_missing_sim()` (R/methods-gllvmTMB.R).
  sdr_joint <- TMB::sdreport(fit$tmb_obj, getJointPrecision = TRUE)
  Q <- sdr_joint$jointPrecision
  if (is.null(Q)) {
    cli::cli_abort(c(
      "{.fn ordination_uncertainty} requires a joint precision matrix from {.fn sdreport}.",
      "i" = "{.fn TMB::sdreport} did not return a {.field jointPrecision} block for this fit.",
      ">" = "Refit and retry; this should not happen for a fit with a positive-definite Hessian."
    ), class = "gllvmTMB_ordination_uncertainty_joint_precision_unavailable")
  }

  par_names <- rownames(Q)
  zpos <- which(par_names == z_name)
  if (length(zpos) != d * n) {
    cli::cli_abort(c(
      "Could not locate the {.field {z_name}} random-effect block in the joint precision matrix.",
      "i" = "Expected {d * n} entries (d = {d}, n = {n}); found {length(zpos)}.",
      ">" = "Refit and retry; this usually means the fit's {.field tmb_obj} is stale."
    ), class = "gllvmTMB_ordination_uncertainty_block_mismatch")
  }

  ## Sparse solve for exactly the z-block columns of Q^{-1} -- never a dense
  ## inverse of the full joint precision. `zpos` is a contiguous run (one
  ## PARAMETER_MATRIX declared once in the TMB template) ordered site-major,
  ## axis-fastest within each site (verified in `dev/getlv-score-se-RESULTS.md`
  ## from both the C++ declaration and the existing `matrix(nrow = d, ncol =
  ## n)` reshape convention `extract_ordination()` / `.getLV_se()` use), so
  ## column block ((s-1)*d+1):(s*d) of the extracted (d*n) x (d*n) matrix IS
  ## unit s's own d x d covariance -- no further permutation needed.
  n_par <- nrow(Q)
  W <- Matrix::sparseMatrix(
    i = zpos, j = seq_along(zpos), x = 1, dims = c(n_par, length(zpos))
  )
  V <- Matrix::solve(Q, W)
  cov_block <- as.matrix(V[zpos, , drop = FALSE])

  se_mat <- matrix(NA_real_, nrow = n, ncol = d)
  cov_arr <- array(NA_real_, dim = c(d, d, n))
  for (s in seq_len(n)) {
    idx <- ((s - 1L) * d + 1L):(s * d)
    block <- cov_block[idx, idx, drop = FALSE]
    block <- (block + t(block)) / 2 ## symmetrise away sparse-solve rounding noise
    cov_arr[, , s] <- block
    se_mat[s, ] <- sqrt(pmax(diag(block), 0))
  }
  dimnames(se_mat) <- dimnames(ord$scores)
  dimnames(cov_arr) <- list(
    colnames(ord$scores), colnames(ord$scores), rownames(ord$scores)
  )

  structure(
    list(scores = ord$scores, se = se_mat, cov = cov_arr, level = canonical_level),
    class = "gllvmTMB_ordination_uncertainty"
  )
}

#' @export
print.gllvmTMB_ordination_uncertainty <- function(x, ...) {
  n <- nrow(x$scores)
  K <- ncol(x$scores)
  cat(sprintf(
    "<gllvmTMB ordination score uncertainty: level = \"%s\", %d units, %d axes>\n",
    x$level, n, K
  ))
  cat(
    "Estimand: conditional (posterior) covariance of each unit's latent",
    "score given the data and the fitted parameters -- a random-effect",
    "prediction uncertainty, NOT a sampling-distribution SE of a fixed",
    "quantity. Native (rotate = \"none\") orientation; per-axis SD is",
    "sign-invariant, cross-axis covariance sign is this fit's own",
    "convention. Coverage is unmeasured for any interval built from this.",
    fill = TRUE
  )
  cat("$scores, $se: n x K matrices. $cov: K x K x n array.\n")
  invisible(x)
}

## Build the (x, y) outline of a level-`conf` asymptotic-normal confidence
## ellipse for a 2-D mean `mu` and covariance `Sigma2`, via the standard
## eigendecomposition parametrisation. Used only by
## `ordiplot(..., ellipse = TRUE)`.
.gllvmTMB_ellipse_xy <- function(mu, Sigma2, conf = 0.95, n_points = 72L) {
  ev <- eigen(Sigma2, symmetric = TRUE)
  radius <- sqrt(pmax(ev$values, 0) * stats::qchisq(conf, df = 2))
  theta <- seq(0, 2 * pi, length.out = n_points)
  circle <- rbind(cos(theta), sin(theta))
  pts <- ev$vectors %*% (radius * circle)
  cbind(x = mu[1L] + pts[1L, ], y = mu[2L] + pts[2L, ])
}
