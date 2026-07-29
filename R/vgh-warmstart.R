## Map a VGH variational solution onto the Laplace engine's start values.
##
## VGH returns a dense, unconstrained Lambda (T x q) and variational means
## amean (n x q). The TMB template wants theta_rr_* packed lower-triangular
## (diag first, then strict lower column-major) and z_* as a q x n matrix.
## The likelihood is flat along the rotation orbit, so any orthogonal Q that
## lands Lambda in the packed form sits at the same objective: this is a
## packing transform, not a choice of rotation.
##
## Four ways this can fail silently, each asserted below rather than trusted:
##   1. rotating Lambda without rotating amean changes the linear predictor;
##   2. z_* is q x n, the transpose of amean;
##   3. the packed vector has length p*q - q*(q-1)/2, not the dense p*q;
##   4. .gllvmTMB_pack_rr_theta() drops the strict upper triangle without
##      checking it is zero.
##
## Boundary worth knowing: the eta check below compares before and after THIS
## function's own rotation, so it proves this step is faithful -- it cannot
## prove the pair was faithful on arrival. Hand it a Lambda that something
## upstream already rotated without its scores and it will preserve that
## corruption exactly. The protection there is not calling
## .va_r3_rotate_to_lower_triangular() first: that helper rotates Lambda alone
## and moves eta by O(1) (measured: 5.55 on a unit-scale fixture).

.vgh_to_laplace_start <- function(fit, tol = 1e-8) {
  if (!inherits(fit, "vgh_fit")) {
    stop("`fit` must be a <vgh_fit> object.", call. = FALSE)
  }

  lambda <- fit$Lambda
  amean <- fit$amean
  if (!is.matrix(lambda) || !is.matrix(amean)) {
    stop("`fit$Lambda` and `fit$amean` must both be matrices.", call. = FALSE)
  }

  n_traits <- nrow(lambda)
  rank <- ncol(lambda)
  n_units <- nrow(amean)

  if (ncol(amean) != rank) {
    stop(sprintf(
      "Rank mismatch: Lambda has %d columns but amean has %d.",
      rank, ncol(amean)
    ), call. = FALSE)
  }
  if (rank > n_traits) {
    stop(sprintf(
      "Rank %d exceeds the number of traits (%d).", rank, n_traits
    ), call. = FALSE)
  }
  if (!all(is.finite(lambda)) || !all(is.finite(amean))) {
    stop("VGH returned non-finite Lambda or amean; refusing to warm-start.",
         call. = FALSE)
  }

  ## The invariants, measured before the transform.
  eta_before <- tcrossprod(amean, lambda)
  g_before <- tcrossprod(lambda)

  rot <- .gllvmTMB_lower_triangular_rotation(lambda, amean)

  ## (1) The linear predictor must be untouched. This is the assertion that a
  ## Lambda-only rotation would fail.
  eta_after <- tcrossprod(rot$scores, rot$loadings)
  eta_scale <- max(1, max(abs(eta_before)))
  eta_dev <- max(abs(eta_after - eta_before)) / eta_scale
  if (!is.finite(eta_dev) || eta_dev > tol) {
    stop(sprintf(
      paste0("Rotation changed the linear predictor (relative deviation %.3e ",
             "> tol %.3e). The loadings and scores must rotate together."),
      eta_dev, tol
    ), call. = FALSE)
  }

  ## G = Lambda Lambda' is the rotation-invariant estimand; it must also hold.
  g_after <- tcrossprod(rot$loadings)
  g_scale <- max(1, max(abs(g_before)))
  g_dev <- max(abs(g_after - g_before)) / g_scale
  if (!is.finite(g_dev) || g_dev > tol) {
    stop(sprintf(
      "Rotation changed G = Lambda Lambda' (relative deviation %.3e > tol %.3e).",
      g_dev, tol
    ), call. = FALSE)
  }

  ## (4) Packing silently discards the strict upper triangle, so check the
  ## rotation actually triangularised the leading block before packing.
  block <- rot$loadings[seq_len(rank), seq_len(rank), drop = FALSE]
  upper <- row(block) < col(block)
  upper_dev <- if (any(upper)) max(abs(block[upper])) else 0
  if (!is.finite(upper_dev) || upper_dev > tol) {
    stop(sprintf(
      paste0("Leading %dx%d block is not lower-triangular after rotation ",
             "(max strict-upper entry %.3e > tol %.3e); packing would drop it."),
      rank, rank, upper_dev, tol
    ), call. = FALSE)
  }

  theta_rr <- .gllvmTMB_pack_rr_theta(rot$loadings)

  ## (3) Packed length is the reduced form, not the dense p*q.
  expected_len <- n_traits * rank - rank * (rank - 1L) / 2L
  if (length(theta_rr) != expected_len) {
    stop(sprintf(
      "Packed theta_rr has length %d; expected %d for %d traits at rank %d.",
      length(theta_rr), expected_len, n_traits, rank
    ), call. = FALSE)
  }

  ## (2) z_* is rank x units -- the transpose of amean.
  z <- t(rot$scores)
  if (!identical(dim(z), c(rank, n_units))) {
    stop(sprintf(
      "z has dimensions %s; expected %d x %d (rank x units).",
      paste(dim(z), collapse = " x "), rank, n_units
    ), call. = FALSE)
  }

  list(
    theta_rr = theta_rr,
    z = z,
    loadings = rot$loadings,
    scores = rot$scores,
    diagnostics = list(
      eta_rel_dev = eta_dev,
      g_rel_dev = g_dev,
      upper_tri_max = upper_dev,
      n_traits = n_traits,
      rank = rank,
      n_units = n_units,
      packed_length = length(theta_rr)
    )
  )
}

## Confirm a start value actually reached the TMB parameter list.
##
## .gllvmTMB_apply_start_from() copies only where names and shapes match
## exactly, and skips everything else in silence -- so a wrong-shaped start is
## indistinguishable from no start at all except by its (absent) effect on
## timing. Never believe a warm-start speedup number without this.

.vgh_assert_start_landed <- function(tmb_params, start, name_theta, name_z) {
  missing <- setdiff(c(name_theta, name_z), names(tmb_params))
  if (length(missing)) {
    stop(sprintf(
      "TMB parameter list has no entry named %s.",
      paste(sQuote(missing), collapse = ", ")
    ), call. = FALSE)
  }

  got_theta <- tmb_params[[name_theta]]
  if (length(got_theta) != length(start$theta_rr) ||
      !isTRUE(all.equal(as.numeric(got_theta), as.numeric(start$theta_rr)))) {
    stop(sprintf(
      paste0("Warm start did not land in `%s`: it still holds the default ",
             "(length %d vs %d supplied). The shapes must match exactly or ",
             "the copy is skipped silently."),
      name_theta, length(got_theta), length(start$theta_rr)
    ), call. = FALSE)
  }

  got_z <- tmb_params[[name_z]]
  if (!identical(dim(got_z), dim(start$z)) ||
      !isTRUE(all.equal(as.numeric(got_z), as.numeric(start$z)))) {
    stop(sprintf(
      "Warm start did not land in `%s`: dimensions %s vs %s supplied.",
      name_z,
      paste(dim(got_z), collapse = " x "),
      paste(dim(start$z), collapse = " x ")
    ), call. = FALSE)
  }

  invisible(TRUE)
}

## Decide whether a VGH warm start applies to THIS model, and if so produce it.
##
## Fail-closed. VGH solves Sigma = Lambda Lambda' with no diagonal tier, three
## families, a complete balanced unit x trait grid, and no missing data. Where
## the target model differs, there is no warm start to give and we say so rather
## than seeding a mismatched start -- see
## docs/dev-log/2026-07-29-vgh-phase2-psi-scope.md for why a free diagonal tier
## in particular must decline (VGH's Lambda has absorbed the covariance a
## diagonal tier would otherwise explain, so seeding it alongside the template
## default inflates every trait's starting variance by exactly 1.0).
##
## Returns NULL when ineligible; otherwise a list(theta_rr, z, ...) from
## .vgh_to_laplace_start() plus the reason string.

.vgh_warm_start_eligible <- function(tmb_data, family_name) {
  if (!isTRUE(as.integer(tmb_data$use_rr_B) == 1L)) {
    return("no between-unit reduced-rank tier")
  }
  if (isTRUE(as.integer(tmb_data$use_diag_B) == 1L)) {
    return("a free between-unit diagonal tier is present (Psi scope, see dev-log)")
  }
  if (isTRUE(as.integer(tmb_data$use_rr_W %||% 0L) == 1L) ||
      isTRUE(as.integer(tmb_data$use_diag_W %||% 0L) == 1L)) {
    return("a within-unit tier is present; VGH covers the between-unit tier only")
  }
  if (!identical(family_name, "gaussian") &&
      !identical(family_name, "binomial") &&
      !identical(family_name, "poisson")) {
    return(sprintf("family '%s' is not one VGH admits", family_name))
  }
  if (any(as.integer(tmb_data$is_y_observed) != 1L)) {
    return("missing responses; VGH requires a complete grid")
  }
  n_expected <- as.integer(tmb_data$n_sites) * as.integer(tmb_data$n_traits)
  if (length(tmb_data$y) != n_expected) {
    return("unbalanced unit x trait grid; VGH requires a complete rectangle")
  }
  TRUE
}

.vgh_build_warm_start <- function(tmb_data, family_name, maxit = 50L,
                                  verbose = FALSE) {
  ok <- .vgh_warm_start_eligible(tmb_data, family_name)
  if (!isTRUE(ok)) {
    if (isTRUE(verbose)) message("VGH warm start declined: ", ok)
    return(NULL)
  }

  ## TMB indices are 0-based; VGH wants 1-based.
  bump <- function(ix) {
    ix <- as.integer(ix)
    if (length(ix) && min(ix) == 0L) ix + 1L else ix
  }

  n_units <- as.integer(tmb_data$n_sites)
  n_traits <- as.integer(tmb_data$n_traits)

  ## gaussian_anchor FIXES the residual sd rather than estimating it, so a plug-in
  ## is required here. This is an ESTIMATE from the data, never a true value: the
  ## per-trait residual sd after removing trait means, pooled. It only has to be
  ## good enough to start Laplace from -- Laplace re-estimates dispersion itself,
  ## and the reported estimate is Laplace's.
  gaussian_sd <- 1
  if (identical(family_name, "gaussian")) {
    tid <- bump(tmb_data$trait_id)
    resid <- as.numeric(tmb_data$y) - ave(as.numeric(tmb_data$y), tid)
    gaussian_sd <- stats::sd(resid)
    if (!is.finite(gaussian_sd) || gaussian_sd <= 0) gaussian_sd <- 1
  }

  fam <- if (identical(family_name, "gaussian")) "gaussian_anchor" else family_name
  link <- if (identical(family_name, "gaussian")) "identity" else
    if (identical(family_name, "binomial")) "logit" else "log"

  fit <- tryCatch(
    .vgh_fit(
      y = as.numeric(tmb_data$y),
      n_trials = as.integer(tmb_data$n_trials),
      X = matrix(1, length(tmb_data$y), 1),
      unit_id = bump(tmb_data$site_id),
      trait_id = bump(tmb_data$trait_id),
      N = n_units, T = n_traits, q = as.integer(tmb_data$d_B),
      family = fam, link = link, gaussian_sd = gaussian_sd,
      maxit = maxit
    ),
    error = function(e) {
      if (isTRUE(verbose)) message("VGH warm start failed: ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(fit)) return(NULL)

  start <- tryCatch(.vgh_to_laplace_start(fit), error = function(e) {
    if (isTRUE(verbose)) message("VGH packing transform failed: ", conditionMessage(e))
    NULL
  })
  if (is.null(start)) return(NULL)

  ## The template's z_B is d_B x n_sites. Anything else means the transform and
  ## the template disagree, and .gllvmTMB_apply_start_from()-style silent
  ## shape-skipping would hide it -- so check here rather than trust it.
  if (!identical(dim(start$z), c(as.integer(tmb_data$d_B), n_units))) {
    stop(sprintf(
      "VGH warm start produced z of %s; template expects %d x %d.",
      paste(dim(start$z), collapse = " x "), as.integer(tmb_data$d_B), n_units
    ), call. = FALSE)
  }
  start$vgh_seconds <- fit$seconds
  start$vgh_elbo <- fit$elbo
  start
}
