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
