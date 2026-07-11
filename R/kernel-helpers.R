#' Build a cross-lineage relatedness kernel
#'
#' @description
#' `make_cross_kernel()` builds the block relatedness matrix for the C0
#' coevolution prototype. What is covered here is building a correlation-scale
#' positive-semidefinite matrix
#' `K_star = rbind(cbind(A_H, C_HP), cbind(t(C_HP), A_P))`, where `A_H`
#' and `A_P` are within-lineage relatedness matrices and `C_HP` is the
#' cross-lineage bridge induced by the association matrix `W`. What is only
#' partially covered is the prototype path: use `K_star` through the
#' existing `phylo_latent(..., vcv = K_star, unique = TRUE)` engine. The
#' generic `kernel_*()` surface and the
#' validated `extract_Gamma()` coevolution gate are now covered
#' separately; this helper only builds the input kernel.
#'
#' @param A_H,A_P Numeric square correlation matrices for the host and
#'   partner lineages. Both must be symmetric, positive semidefinite, and
#'   have unit diagonal.
#' @param W Numeric association matrix with `nrow(W) == nrow(A_H)` and
#'   `ncol(W) == nrow(A_P)`. If `W` has row or column names, they are
#'   aligned to `A_H` / `A_P` names before the kernel is built.
#' @param rho Scalar bridge strength in `[-1, 1]`. Larger absolute values
#'   put more covariance in the off-diagonal host-partner block.
#' @param eps Positive numerical floor used when taking symmetric square
#'   roots and scaling an all-zero or near-zero `W`.
#'
#' @return A numeric correlation matrix with the host block first and the
#'   partner block second. The matrix carries lightweight metadata for
#'   downstream extractors, including the fixed `rho` used to build the
#'   host-partner bridge.
#'
#' @examples
#' A_H <- matrix(c(
#'   1.0, 0.3, 0.1,
#'   0.3, 1.0, 0.2,
#'   0.1, 0.2, 1.0
#' ), 3, 3, byrow = TRUE)
#' A_P <- matrix(c(1.0, 0.25, 0.25, 1.0), 2, 2)
#' W <- matrix(c(1, 0, 0.5, 0, 1, 0.25), 3, 2, byrow = TRUE)
#' K_star <- make_cross_kernel(A_H, A_P, W, rho = 0.4)
#' min(eigen(K_star, symmetric = TRUE, only.values = TRUE)$values)
#'
#' @export
make_cross_kernel <- function(A_H, A_P, W, rho = 0.5, eps = 1e-8) {
  A_H <- .cross_kernel_as_matrix(A_H, "A_H")
  A_P <- .cross_kernel_as_matrix(A_P, "A_P")
  W <- .cross_kernel_as_matrix(W, "W", square = FALSE)

  if (!is.numeric(rho) || length(rho) != 1L || !is.finite(rho)) {
    cli::cli_abort("{.arg rho} must be one finite number.")
  }
  if (abs(rho) > 1) {
    cli::cli_abort(c(
      "{.arg rho} must lie in [-1, 1].",
      "i" = "The cross block is spectrally scaled, so |rho| <= 1 keeps the block kernel positive semidefinite."
    ))
  }
  if (!is.numeric(eps) || length(eps) != 1L || !is.finite(eps) || eps <= 0) {
    cli::cli_abort("{.arg eps} must be one positive finite number.")
  }

  .cross_kernel_check_correlation(A_H, "A_H", eps = eps)
  .cross_kernel_check_correlation(A_P, "A_P", eps = eps)

  n_H <- nrow(A_H)
  n_P <- nrow(A_P)
  if (nrow(W) != n_H || ncol(W) != n_P) {
    cli::cli_abort(c(
      "{.arg W} has incompatible dimensions.",
      "i" = "{.arg W} must be nrow(A_H) x nrow(A_P); got {nrow(W)} x {ncol(W)} for {n_H} x {n_P}."
    ))
  }

  h_names <- .cross_kernel_names(A_H, "A_H", "H")
  p_names <- .cross_kernel_names(A_P, "A_P", "P")
  if (anyDuplicated(c(h_names, p_names))) {
    cli::cli_abort(c(
      "Host and partner names must be unique after concatenation.",
      "i" = "Prefix one lineage before calling {.fn make_cross_kernel}."
    ))
  }
  W <- .cross_kernel_align_W(W, h_names, p_names)

  L_H <- .cross_kernel_symmetric_sqrt(A_H, eps = eps)
  L_P <- .cross_kernel_symmetric_sqrt(A_P, eps = eps)

  sv <- svd(W, nu = 0L, nv = 0L)$d
  spectral_norm <- if (length(sv)) sv[1L] else 0
  W_scaled <- W / max(spectral_norm, eps)
  C_HP <- rho * L_H %*% W_scaled %*% t(L_P)

  K <- rbind(
    cbind(A_H, C_HP),
    cbind(t(C_HP), A_P)
  )
  K <- (K + t(K)) / 2
  diag(K) <- 1
  dimnames(K) <- list(c(h_names, p_names), c(h_names, p_names))

  eig <- eigen(K, symmetric = TRUE, only.values = TRUE)$values
  min_eig <- min(eig)
  if (!is.finite(min_eig) || min_eig < -1e-6) {
    cli::cli_abort(c(
      "Cross-lineage kernel is not positive semidefinite.",
      "i" = "Minimum eigenvalue is {signif(min_eig, 4)}.",
      ">" = "Lower {.arg rho} or rescale {.arg W} before fitting."
    ))
  }

  attr(K, "gllvmTMB_cross_kernel") <- list(
    rho = rho,
    host_levels = h_names,
    partner_levels = p_names,
    spectral_norm_W = spectral_norm
  )
  K
}

#' Profile fixed cross-lineage rho values
#'
#' @description
#' `profile_cross_rho()` formalises the fixed-kernel sensitivity workflow for
#' Design 65 cross-lineage kernels. It rebuilds `K_star` with
#' [make_cross_kernel()] over a user-supplied `rho` grid, calls a caller-supplied
#' `refit(K, rho, ...)` function for each grid value, and returns a tidy
#' likelihood table.
#'
#' What is covered: this is a fixed-kernel profile workflow for
#' comparing defended `rho` values. What is only partially covered: `rho` is still not a TMB parameter,
#' this helper does not estimate `rho`, and it does not produce confidence
#' intervals or null calibration.
#'
#' @param A_H,A_P,W Inputs passed to [make_cross_kernel()].
#' @param rho Numeric vector of fixed `rho` values to evaluate.
#' @param refit Function called as `refit(K = K_rho, rho = rho_i, ...)`. It
#'   should return a fitted object with a `logLik()` method.
#' @param metrics Optional function called as
#'   `metrics(fit = fit_i, K = K_rho, rho = rho_i)`. It may return a named
#'   list or one-row data frame of additional scalar summaries, such as a
#'   `Gamma` correlation or a component norm.
#' @param eps Positive numerical floor passed to [make_cross_kernel()].
#' @param keep_fits Logical; if `TRUE`, fitted objects are attached as a
#'   `"fits"` attribute. Default `FALSE` keeps the returned object light.
#' @param ... Additional arguments passed to `refit`.
#'
#' @return A data frame of class `gllvmTMB_cross_rho_profile` with columns
#'   `rho`, `logLik`, `relative_logLik`, `delta_deviance`, `is_best`,
#'   `convergence`, `pd_hessian`, `status`, and `error`, plus any metric
#'   columns returned by `metrics`.
#'
#' @examples
#' A_H <- diag(2)
#' A_P <- diag(2)
#' rownames(A_H) <- colnames(A_H) <- c("H1", "H2")
#' rownames(A_P) <- colnames(A_P) <- c("P1", "P2")
#' W <- matrix(c(1, 0.2, 0.2, 1), 2, 2)
#' dimnames(W) <- list(rownames(A_H), rownames(A_P))
#' dat <- data.frame(y = c(1, 2, 3, 4), x = c(0, 1, 0, 1))
#' profile_cross_rho(
#'   A_H, A_P, W,
#'   rho = c(0, 0.25),
#'   refit = function(K, rho) stats::lm(y ~ x, data = dat)
#' )
#'
#' @export
profile_cross_rho <- function(A_H, A_P, W, rho, refit, metrics = NULL,
                              eps = 1e-8, keep_fits = FALSE, ...) {
  if (!is.numeric(rho) || length(rho) == 0L || anyNA(rho) ||
      any(!is.finite(rho))) {
    cli::cli_abort("{.arg rho} must be a non-empty finite numeric vector.")
  }
  if (any(abs(rho) > 1)) {
    cli::cli_abort("{.arg rho} values must lie in [-1, 1].")
  }
  if (!is.function(refit)) {
    cli::cli_abort("{.arg refit} must be a function.")
  }
  if (!is.null(metrics) && !is.function(metrics)) {
    cli::cli_abort("{.arg metrics} must be {.code NULL} or a function.")
  }
  if (!is.logical(keep_fits) || length(keep_fits) != 1L || is.na(keep_fits)) {
    cli::cli_abort("{.arg keep_fits} must be {.code TRUE} or {.code FALSE}.")
  }

  rows <- vector("list", length(rho))
  fits <- vector("list", length(rho))
  for (i in seq_along(rho)) {
    rho_i <- as.numeric(rho[[i]])
    K_i <- make_cross_kernel(A_H, A_P, W, rho = rho_i, eps = eps)
    fit_i <- tryCatch(
      refit(K = K_i, rho = rho_i, ...),
      error = function(e) e
    )
    fits[[i]] <- fit_i
    if (inherits(fit_i, "error")) {
      rows[[i]] <- data.frame(
        rho = rho_i,
        logLik = NA_real_,
        convergence = NA_integer_,
        pd_hessian = NA,
        status = "error",
        error = conditionMessage(fit_i),
        stringsAsFactors = FALSE
      )
      next
    }

    logLik_i <- .cross_rho_logLik(fit_i)
    status_i <- if (is.finite(logLik_i)) "ok" else "logLik_error"
    row_i <- data.frame(
      rho = rho_i,
      logLik = logLik_i,
      convergence = .cross_rho_convergence(fit_i),
      pd_hessian = .cross_rho_pd_hessian(fit_i),
      status = status_i,
      error = NA_character_,
      stringsAsFactors = FALSE
    )
    if (!is.null(metrics)) {
      metric_i <- metrics(fit = fit_i, K = K_i, rho = rho_i)
      row_i <- cbind(
        row_i,
        .cross_rho_metric_row(metric_i, names(row_i))
      )
    }
    rows[[i]] <- row_i
  }

  out <- .cross_rho_bind_rows(rows)
  out$relative_logLik <- NA_real_
  out$delta_deviance <- NA_real_
  out$is_best <- FALSE
  ok <- is.finite(out$logLik)
  best_rho <- NA_real_
  if (any(ok)) {
    max_ll <- max(out$logLik[ok])
    out$relative_logLik[ok] <- out$logLik[ok] - max_ll
    out$delta_deviance[ok] <- 2 * (max_ll - out$logLik[ok])
    best <- which(ok)[which.max(out$logLik[ok])]
    out$is_best[best] <- TRUE
    best_rho <- out$rho[best]
  }

  leading <- c(
    "rho",
    "logLik",
    "relative_logLik",
    "delta_deviance",
    "is_best",
    "convergence",
    "pd_hessian",
    "status",
    "error"
  )
  out <- out[, c(leading, setdiff(names(out), leading)), drop = FALSE]
  attr(out, "best_rho") <- best_rho
  if (isTRUE(keep_fits)) {
    attr(out, "fits") <- fits
  }
  class(out) <- c("gllvmTMB_cross_rho_profile", "data.frame")
  out
}

#' Profile sensitivity interval for the cross-lineage `rho`
#'
#' @description
#' Turns a [profile_cross_rho()] grid into a profile-likelihood sensitivity
#' interval for the fixed cross-lineage correlation `rho`. The interval is the
#' set of `rho` values whose deviance excess `2 * (logLik_max - logLik)` stays
#' below `qchisq(level, df = 1)`; the bounds are located by linear interpolation
#' of the profiled `delta_deviance` curve between the two grid points that
#' bracket each crossing. Use a `rho` grid dense enough to bracket the crossings
#' (a coarse 3-4 point sensitivity grid is usually too sparse for a calibrated
#' interval). When the profiled curve does not rise above the threshold on one
#' side within the supplied grid, that bound is reported as the grid edge and
#' flagged unbounded (`lower_bounded` / `upper_bounded` `FALSE`) -- widen the grid.
#'
#' This is screening-grade profile/sensitivity interval evidence on a
#' *fixed*-`rho` refit grid, not in-engine `rho` estimation (Design 65 C3.3;
#' this remains only partially covered by validation). Its coverage has
#' **not** been calibrated, so do not report it as a validated confidence
#' interval.
#'
#' @param profile A `gllvmTMB_cross_rho_profile` data frame from
#'   [profile_cross_rho()] (needs the `rho` and `delta_deviance` columns).
#' @param level Confidence level in `(0, 1)`; default `0.95`.
#'
#' @return A list with `estimate` (the grid `rho` with the highest `logLik`),
#'   `lower`, `upper`, `level`, `lower_bounded`, `upper_bounded`, and the
#'   deviance `threshold`. Bounds are clamped to the `rho` domain `[-1, 1]`.
#'
#' @seealso [profile_cross_rho()], [make_cross_kernel()]
#' @export
profile_cross_rho_ci <- function(profile, level = 0.95) {
  if (!is.data.frame(profile) ||
      !all(c("rho", "delta_deviance") %in% names(profile))) {
    cli::cli_abort(c(
      "{.arg profile} must be a data frame from {.fn profile_cross_rho}.",
      "i" = "It needs the {.field rho} and {.field delta_deviance} columns."
    ))
  }
  if (!is.numeric(level) || length(level) != 1L || is.na(level) ||
      level <= 0 || level >= 1) {
    cli::cli_abort("{.arg level} must be a single number in (0, 1).")
  }
  ok <- is.finite(profile$rho) & is.finite(profile$delta_deviance)
  d <- profile[ok, c("rho", "delta_deviance"), drop = FALSE]
  d <- d[order(d$rho), , drop = FALSE]
  if (nrow(d) < 2L) {
    cli::cli_abort(
      "Need at least two finite profile points to form an interval; got {nrow(d)}."
    )
  }
  crit <- stats::qchisq(level, df = 1)
  best_i <- which.min(d$delta_deviance)
  est <- d$rho[best_i]
  dd <- d$delta_deviance
  rr <- d$rho

  interp <- function(r1, d1, r2, d2) {
    if (!is.finite(d2 - d1) || d2 == d1) return(r1)
    r1 + (crit - d1) * (r2 - r1) / (d2 - d1)
  }

  ## Lower bound: nearest threshold crossing below the best grid point.
  lower <- rr[1]
  lower_bounded <- FALSE
  if (best_i > 1L) {
    for (j in best_i:2L) {
      if (dd[j - 1L] >= crit && dd[j] <= crit) {
        lower <- interp(rr[j - 1L], dd[j - 1L], rr[j], dd[j])
        lower_bounded <- TRUE
        break
      }
    }
  }
  ## Upper bound: nearest threshold crossing above the best grid point.
  upper <- rr[nrow(d)]
  upper_bounded <- FALSE
  if (best_i < nrow(d)) {
    for (j in best_i:(nrow(d) - 1L)) {
      if (dd[j] <= crit && dd[j + 1L] >= crit) {
        upper <- interp(rr[j], dd[j], rr[j + 1L], dd[j + 1L])
        upper_bounded <- TRUE
        break
      }
    }
  }

  list(
    estimate = est,
    lower = max(-1, min(1, lower)),
    upper = max(-1, min(1, upper)),
    level = level,
    lower_bounded = lower_bounded,
    upper_bounded = upper_bounded,
    threshold = crit
  )
}

.cross_kernel_metadata <- function(K) {
  meta <- attr(K, "gllvmTMB_cross_kernel", exact = TRUE)
  if (!is.list(meta)) {
    return(NULL)
  }
  meta
}

.cross_kernel_rho <- function(K) {
  meta <- .cross_kernel_metadata(K)
  if (is.null(meta) ||
      is.null(meta$rho) ||
      length(meta$rho) != 1L ||
      !is.finite(meta$rho)) {
    return(NA_real_)
  }
  as.numeric(meta$rho)
}

.cross_kernel_metadata_for_levels <- function(meta, levels) {
  if (is.null(meta)) {
    return(NULL)
  }
  out <- meta
  if (!is.null(out$host_levels)) {
    out$host_levels <- levels[levels %in% out$host_levels]
  }
  if (!is.null(out$partner_levels)) {
    out$partner_levels <- levels[levels %in% out$partner_levels]
  }
  out
}

.cross_kernel_as_matrix <- function(x, arg, square = TRUE) {
  if (inherits(x, "Matrix")) {
    x <- as.matrix(x)
  }
  if (!is.matrix(x) || !is.numeric(x)) {
    cli::cli_abort("{.arg {arg}} must be a numeric matrix.")
  }
  if (anyNA(x) || any(!is.finite(x))) {
    cli::cli_abort("{.arg {arg}} must contain only finite, non-missing values.")
  }
  if (square && nrow(x) != ncol(x)) {
    cli::cli_abort("{.arg {arg}} must be square.")
  }
  storage.mode(x) <- "double"
  x
}

.cross_kernel_names <- function(A, arg, prefix) {
  rn <- rownames(A)
  cn <- colnames(A)
  if (!is.null(rn) && !is.null(cn) && !identical(rn, cn)) {
    cli::cli_abort("Row names and column names of {.arg {arg}} must match.")
  }
  if (is.null(rn)) {
    rn <- paste0(prefix, seq_len(nrow(A)))
  }
  rn
}

.cross_kernel_check_correlation <- function(A, arg, eps) {
  if (max(abs(A - t(A))) > sqrt(eps)) {
    cli::cli_abort("{.arg {arg}} must be symmetric.")
  }
  if (max(abs(diag(A) - 1)) > sqrt(eps)) {
    cli::cli_abort(c(
      "{.arg {arg}} must be correlation-scaled with unit diagonal.",
      "i" = "Scale the relatedness matrix before calling {.fn make_cross_kernel}."
    ))
  }
  eig <- eigen((A + t(A)) / 2, symmetric = TRUE, only.values = TRUE)$values
  min_eig <- min(eig)
  if (!is.finite(min_eig) || min_eig < -1e-6) {
    cli::cli_abort(c(
      "{.arg {arg}} must be positive semidefinite.",
      "i" = "Minimum eigenvalue is {signif(min_eig, 4)}."
    ))
  }
  invisible(TRUE)
}

.cross_kernel_symmetric_sqrt <- function(A, eps) {
  eig <- eigen((A + t(A)) / 2, symmetric = TRUE)
  vals <- pmax(eig$values, eps)
  sweep(eig$vectors, 2L, sqrt(vals), `*`) %*% t(eig$vectors)
}

.cross_kernel_align_W <- function(W, h_names, p_names) {
  if (!is.null(rownames(W))) {
    if (!all(h_names %in% rownames(W))) {
      cli::cli_abort("{.arg W} row names must cover row names of {.arg A_H}.")
    }
    W <- W[h_names, , drop = FALSE]
  }
  if (!is.null(colnames(W))) {
    if (!all(p_names %in% colnames(W))) {
      cli::cli_abort("{.arg W} column names must cover row names of {.arg A_P}.")
    }
    W <- W[, p_names, drop = FALSE]
  }
  W
}

.cross_rho_logLik <- function(fit) {
  value <- tryCatch(
    as.numeric(stats::logLik(fit)),
    error = function(e) NA_real_
  )
  if (!length(value) || !is.finite(value[[1L]])) {
    return(NA_real_)
  }
  value[[1L]]
}

.cross_rho_convergence <- function(fit) {
  conv <- fit$opt$convergence
  if (is.null(conv) || !length(conv) || is.na(conv[[1L]])) {
    return(NA_integer_)
  }
  as.integer(conv[[1L]])
}

.cross_rho_pd_hessian <- function(fit) {
  pd <- fit$fit_health$pd_hessian
  if (is.null(pd) || !length(pd) || is.na(pd[[1L]])) {
    return(NA)
  }
  isTRUE(pd[[1L]])
}

.cross_rho_metric_row <- function(x, reserved) {
  if (is.null(x)) {
    return(data.frame())
  }
  if (is.data.frame(x)) {
    if (nrow(x) != 1L) {
      cli::cli_abort("{.arg metrics} must return a one-row data frame.")
    }
    out <- x
  } else if (is.list(x) && !is.null(names(x))) {
    out <- as.data.frame(x, stringsAsFactors = FALSE, optional = TRUE)
    if (nrow(out) != 1L) {
      cli::cli_abort("{.arg metrics} list values must be scalar.")
    }
  } else {
    cli::cli_abort(
      "{.arg metrics} must return {.code NULL}, a named list, or a one-row data frame."
    )
  }
  overlap <- intersect(names(out), reserved)
  if (length(overlap)) {
    cli::cli_abort(
      "{.arg metrics} returned reserved column name{?s}: {.val {overlap}}."
    )
  }
  out
}

.cross_rho_bind_rows <- function(rows) {
  all_names <- unique(unlist(lapply(rows, names), use.names = FALSE))
  filled <- lapply(rows, function(x) {
    missing <- setdiff(all_names, names(x))
    for (nm in missing) {
      x[[nm]] <- NA
    }
    x[, all_names, drop = FALSE]
  })
  do.call(rbind, filled)
}

#' Diagnose fixed-kernel separability before fitting
#'
#' @description
#' `diagnose_kernel_separability()` compares two or more dense fixed kernels on
#' the same levels before they are used in a multi-kernel coevolution model. It
#' is a pre-fit claim-boundary helper for Design 65 (only partially covered by
#' validation): when candidate
#' kernels are highly overlapping, component-specific `Gamma` blocks are weak
#' evidence and should be treated as descriptive unless simulations justify the
#' split.
#'
#' What is covered (partially): use this helper to screen candidate `K_phy` and
#' `K_tip` definitions, including raw-network and residualized-network choices,
#' before fitting `kernel_latent(..., name = ...)` tiers. What is not covered:
#' this is a diagnostic, not recovery evidence, interval calibration, or an
#' in-engine identifiability proof.
#'
#' @param ... Two or more named numeric square kernel matrices with the same
#'   dimensions and level order.
#' @param thresholds Named numeric vector with entries `near_orthogonal` and
#'   `high`. Similarity below `near_orthogonal` is labelled
#'   `"near_orthogonal"`; similarity below `high` is `"moderate"`; similarity
#'   at or above `high` is `"high"`.
#'
#' @return A list of class `gllvmTMB_kernel_separability` with:
#' \describe{
#'   \item{similarity}{A symmetric matrix of off-diagonal Frobenius-style
#'     similarities between kernels.}
#'   \item{pairs}{A data frame with pair labels, similarity, overlap class, and
#'     a conservative recommendation.}
#'   \item{thresholds}{The thresholds used for the classes.}
#'   \item{note}{A short claim-boundary note.}
#' }
#'
#' @examples
#' A_H <- diag(2)
#' A_P <- diag(2)
#' rownames(A_H) <- colnames(A_H) <- c("H1", "H2")
#' rownames(A_P) <- colnames(A_P) <- c("P1", "P2")
#' W_phy <- matrix(c(1, 0.2, 0.2, 1), 2, 2,
#'   dimnames = list(rownames(A_H), rownames(A_P)))
#' W_tip <- matrix(c(0.2, 1, 1, 0.2), 2, 2,
#'   dimnames = list(rownames(A_H), rownames(A_P)))
#' K_phy <- make_cross_kernel(A_H, A_P, W_phy, rho = 0.5)
#' K_tip <- make_cross_kernel(A_H, A_P, W_tip, rho = 0.5)
#' diagnose_kernel_separability(phy = K_phy, tip = K_tip)
#'
#' @export
diagnose_kernel_separability <- function(...,
                                         thresholds = c(
                                           near_orthogonal = 0.25,
                                           high = 0.70
                                         )) {
  kernels <- list(...)
  if (length(kernels) < 2L) {
    cli::cli_abort("Provide at least two kernel matrices in {.arg ...}.")
  }
  names(kernels) <- .kernel_separability_names(kernels)
  thresholds <- .kernel_separability_thresholds(thresholds)
  kernels <- stats::setNames(lapply(
    seq_along(kernels),
    function(i) .kernel_separability_matrix(kernels[[i]], names(kernels)[[i]])
  ), names(kernels))

  kernels <- .kernel_separability_align(kernels)

  n_tiers <- length(kernels)
  sim <- diag(1, n_tiers)
  dimnames(sim) <- list(names(kernels), names(kernels))
  rows <- list()
  k <- 1L
  for (i in seq_len(n_tiers - 1L)) {
    for (j in seq.int(i + 1L, n_tiers)) {
      value <- .kernel_pair_similarity(kernels[[i]], kernels[[j]])
      overlap_class <- .kernel_separability_class(value, thresholds)
      sim[i, j] <- sim[j, i] <- value
      rows[[k]] <- data.frame(
        level_1 = names(kernels)[[i]],
        level_2 = names(kernels)[[j]],
        similarity = value,
        overlap_class = overlap_class,
        recommendation = .kernel_separability_recommendation(overlap_class),
        stringsAsFactors = FALSE
      )
      k <- k + 1L
    }
  }

  out <- list(
    similarity = sim,
    pairs = do.call(rbind, rows),
    thresholds = thresholds,
    note = paste(
      "Off-diagonal Frobenius-style similarity between fixed kernel tiers.",
      "High overlap means component-specific Gamma_shape separation is weak evidence;",
      "report one network-conditioned covariance unless simulations justify the split."
    )
  )
  class(out) <- "gllvmTMB_kernel_separability"
  out
}

.kernel_separability_names <- function(kernels) {
  nms <- names(kernels)
  if (is.null(nms)) {
    nms <- rep("", length(kernels))
  }
  missing <- !nzchar(nms)
  nms[missing] <- paste0("K", which(missing))
  if (anyDuplicated(nms)) {
    cli::cli_abort("Kernel names in {.arg ...} must be unique.")
  }
  nms
}

.kernel_separability_thresholds <- function(thresholds) {
  if (!is.numeric(thresholds) ||
      !all(c("near_orthogonal", "high") %in% names(thresholds))) {
    cli::cli_abort(
      "{.arg thresholds} must be a named numeric vector with {.val near_orthogonal} and {.val high}."
    )
  }
  thresholds <- thresholds[c("near_orthogonal", "high")]
  if (anyNA(thresholds) || any(!is.finite(thresholds)) ||
      thresholds[[1L]] <= 0 || thresholds[[2L]] <= thresholds[[1L]] ||
      thresholds[[2L]] >= 1) {
    cli::cli_abort(
      "{.arg thresholds} must satisfy 0 < near_orthogonal < high < 1."
    )
  }
  thresholds
}

.kernel_separability_matrix <- function(x, name) {
  if (inherits(x, "Matrix")) {
    x <- as.matrix(x)
  }
  if (!is.matrix(x) || !is.numeric(x) || nrow(x) != ncol(x)) {
    cli::cli_abort("Kernel {.val {name}} must be a numeric square matrix.")
  }
  if (anyNA(x) || any(!is.finite(x))) {
    cli::cli_abort("Kernel {.val {name}} must contain only finite values.")
  }
  storage.mode(x) <- "double"
  (x + t(x)) / 2
}

.kernel_separability_level_names <- function(K, name) {
  rn <- rownames(K)
  cn <- colnames(K)
  if (is.null(rn) && is.null(cn)) {
    return(NULL)
  }
  if (is.null(rn) || is.null(cn) || !identical(rn, cn)) {
    cli::cli_abort(
      "Row names and column names of kernel {.val {name}} must match."
    )
  }
  if (anyNA(rn) || any(!nzchar(rn))) {
    cli::cli_abort("Kernel {.val {name}} has empty or missing level names.")
  }
  if (anyDuplicated(rn)) {
    cli::cli_abort("Kernel {.val {name}} has duplicated level names.")
  }
  rn
}

.kernel_separability_align <- function(kernels) {
  dims <- lapply(kernels, dim)
  if (!all(vapply(dims, identical, logical(1), dims[[1L]]))) {
    cli::cli_abort("All kernels must have the same dimensions.")
  }

  level_names <- Map(
    .kernel_separability_level_names,
    kernels,
    names(kernels)
  )
  has_names <- vapply(level_names, Negate(is.null), logical(1))
  if (!any(has_names)) {
    return(kernels)
  }
  if (!all(has_names)) {
    cli::cli_abort(
      "All kernels must either carry matching dimnames or all be unnamed."
    )
  }

  reference <- level_names[[1L]]
  aligned <- vector("list", length(kernels))
  for (i in seq_along(kernels)) {
    current <- level_names[[i]]
    if (!setequal(current, reference)) {
      cli::cli_abort(
        "Kernel {.val {names(kernels)[[i]]}} must have the same level set as kernel {.val {names(kernels)[[1L]]}}."
      )
    }
    aligned[[i]] <- kernels[[i]][reference, reference, drop = FALSE]
  }
  stats::setNames(aligned, names(kernels))
}

.kernel_pair_similarity <- function(K_1, K_2) {
  off_diag <- row(K_1) != col(K_1)
  x <- K_1[off_diag]
  y <- K_2[off_diag]
  denom <- sqrt(sum(x^2) * sum(y^2))
  if (is.finite(denom) && denom > 0) {
    return(sum(x * y) / denom)
  }
  if (all(abs(x) < 1e-12) && all(abs(y) < 1e-12)) {
    return(1)
  }
  0
}

.kernel_separability_class <- function(similarity, thresholds) {
  if (similarity < thresholds[["near_orthogonal"]]) {
    "near_orthogonal"
  } else if (similarity < thresholds[["high"]]) {
    "moderate"
  } else {
    "high"
  }
}

.kernel_separability_recommendation <- function(overlap_class) {
  switch(
    overlap_class,
    near_orthogonal = "separable_candidate",
    moderate = "sensitivity_required",
    high = "collapse_or_single_covariance"
  )
}
