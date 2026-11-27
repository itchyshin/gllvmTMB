# Refuse duplicate (unit, trait) rows except replicated single-trial binomial cells.
.gllvmTMB_check_unique_observed_cells <- function(
    unit_id, trait_id, family_id_vec, n_trials, is_y_observed, weights_i) {
  obs <- which(is_y_observed == 1L & weights_i > 0)
  if (!length(obs)) {
    return(invisible(NULL))
  }
  cells <- paste(unit_id[obs], trait_id[obs], sep = ":")
  if (!any(duplicated(cells))) {
    return(invisible(NULL))
  }
  dup_keys <- unique(cells[duplicated(cells)])
  for (key in dup_keys) {
    rows <- obs[cells == key]
    bernoulli_rep <- all(family_id_vec[rows] %in% c(1L, 19L)) &&
      all(n_trials[rows] == 1L)
    if (bernoulli_rep) {
      next
    }
    cli::cli_abort(c(
      "Long-format data has more than one row for the same unit-trait cell.",
      "x" = "At least one {.emph (unit, trait)} key appears on {length(rows)} rows (e.g. {.val {key}}).",
      "i" = "Stacked-trait likelihoods expect one row per cell unless single-trial binomial rows are intentionally replicated.",
      ">" = "Deduplicate or aggregate the data, or use {.code cbind(successes, failures)} / {.arg weights} as trial counts for multi-trial binomial traits."
    ), class = "gllvmTMB_duplicate_unit_trait_cell")
  }
  invisible(NULL)
}

# Validate the record index used by the paired-kernel marginal likelihood.
.gllvmTMB_check_unique_marginal_cells <- function(unit_id, trait_id) {
  if (length(unit_id) != length(trait_id)) {
    stop("unit_id and trait_id must have equal length.", call. = FALSE)
  }

  cells <- data.frame(unit_id = unit_id, trait_id = trait_id)
  if (anyDuplicated(cells)) {
    condition <- structure(
      list(
        message = "The exact marginal Gaussian route requires at most one observation per unit-trait cell.",
        call = NULL
      ),
      class = c("gllvmTMB_exact_gaussian_duplicate_cell", "error", "condition")
    )
    stop(condition)
  }

  invisible(NULL)
}

# Prepare a block-Woodbury representation for the exact two-kernel Gaussian
# route. This is deliberately an optional acceleration: unsupported kernel
# geometry and declared known covariance stay on the dense exact likelihood.
.gllvmTMB_exact_pair_woodbury_data <- function(
    kernel_matrices, unit_id, trait_id, n_traits, known_V = NULL,
    loading_ranks = rep(1L, length(kernel_matrices))) {
  n_tier <- length(kernel_matrices)
  n_unit <- if (n_tier) nrow(kernel_matrices[[1L]]) else 1L
  n_obs <- length(unit_id)
  disabled <- list(
    enabled = 0L,
    eigenmode = 0L,
    rotated_kernel_factor = array(
      0.0, dim = c(max(1L, n_tier), max(1L, n_traits), 1L, n_unit)
    ),
    trait_count = rep(0L, max(1L, n_traits)),
    trait_rows = matrix(0L, nrow = max(1L, n_traits), ncol = 1L),
    trait_eigenvalues = matrix(1.0, nrow = max(1L, n_traits), ncol = 1L),
    trait_eigenvectors = array(0.0, dim = c(max(1L, n_traits), 1L, 1L)),
    base_tier = 0L,
    identity_tier = if (n_tier > 1L) 1L else 0L
  )
  if (n_tier != 2L || n_obs < 1L || length(trait_id) != n_obs ||
      length(loading_ranks) != n_tier || !is.null(known_V)) {
    return(disabled)
  }

  trait_rows <- lapply(seq_len(n_traits), function(t) which(trait_id == t - 1L))
  if (any(lengths(trait_rows) == 0L)) return(disabled)
  trait_units <- lapply(trait_rows, function(i) unit_id[i] + 1L)

  # One kernel must be exactly identity on each trait's observed unit set.
  # A tolerance here would substitute I for a distinct raw user kernel and
  # change the likelihood, so near-identity blocks stay on the dense route.
  is_identity_on_mask <- function(K) {
    all(vapply(seq_len(n_traits), function(t) {
      U <- trait_units[[t]]
      block <- K[U, U, drop = FALSE]
      isTRUE(all(block == diag(length(U))))
    }, logical(1L)))
  }
  identity_tier <- which(vapply(kernel_matrices, is_identity_on_mask, logical(1L)))
  if (!length(identity_tier)) return(disabled)
  identity_tier <- identity_tier[[1L]]
  base_tier <- setdiff(seq_len(n_tier), identity_tier)[[1L]]

  factors <- array(0.0, dim = c(n_tier, n_unit, n_unit))
  for (r in seq_len(n_tier)) {
    K <- kernel_matrices[[r]]
    if (!is.matrix(K) || !identical(dim(K), c(n_unit, n_unit)) ||
        any(!is.finite(K)) || max(abs(K - t(K))) > 1e-10) {
      return(disabled)
    }
    R <- tryCatch(chol(K), error = function(e) NULL)
    if (is.null(R)) return(disabled)
    L <- t(R)
    if (max(abs(tcrossprod(L) - K)) > 1e-10 * max(1, max(abs(K)))) {
      return(disabled)
    }
    factors[r, , ] <- L
  }

  max_n <- max(lengths(trait_rows))
  eigenvalues <- matrix(1.0, nrow = n_traits, ncol = max_n)
  eigenvectors <- array(0.0, dim = c(n_traits, max_n, max_n))
  for (t in seq_len(n_traits)) {
    U <- trait_units[[t]]
    A <- kernel_matrices[[base_tier]][U, U, drop = FALSE]
    ee <- tryCatch(eigen((A + t(A)) / 2, symmetric = TRUE),
                   error = function(e) NULL)
    if (is.null(ee) || any(!is.finite(ee$values)) || min(ee$values) <= 0) {
      return(disabled)
    }
    n_t <- length(U)
    eigenvalues[t, seq_len(n_t)] <- ee$values
    eigenvectors[t, seq_len(n_t), seq_len(n_t)] <- ee$vectors
  }

  # Rotate each fixed kernel factor once in R. The resulting Q_t' L_r[U_t, ]
  # is data, so TMB does not build a large AD expression for Q_t' F at every
  # objective evaluation. Loading coefficients remain parameter-dependent.
  rotated_factors <- array(
    0.0, dim = c(n_tier, n_traits, max_n, n_unit)
  )
  for (r in seq_len(n_tier)) {
    for (t in seq_len(n_traits)) {
      n_t <- length(trait_units[[t]])
      Q <- eigenvectors[t, seq_len(n_t), seq_len(n_t), drop = FALSE]
      Q <- matrix(Q, nrow = n_t, ncol = n_t)
      L_observed <- matrix(
        factors[r, trait_units[[t]], , drop = FALSE],
        nrow = n_t, ncol = n_unit
      )
      rotated <- crossprod(Q, L_observed)
      for (j in seq_len(n_t)) rotated_factors[r, t, j, ] <- rotated[j, ]
    }
  }

  n_factor <- sum(vapply(seq_len(n_tier), function(r) {
    n_unit * as.integer(loading_ranks[[r]])
  }, integer(1L)))
  if (n_factor > n_obs) return(disabled)
  complete_shared_mask <- all(vapply(seq_len(n_traits), function(t) {
    identical(trait_units[[1L]], trait_units[[t]])
  }, logical(1L)))
  disabled$enabled <- 1L
  disabled$eigenmode <- as.integer(complete_shared_mask)
  disabled$rotated_kernel_factor <- rotated_factors
  disabled$trait_count <- as.integer(lengths(trait_rows))
  disabled$trait_rows <- matrix(0L, nrow = n_traits, ncol = max_n)
  for (t in seq_len(n_traits)) {
    rows <- trait_rows[[t]]
    disabled$trait_rows[t, seq_along(rows)] <- as.integer(rows - 1L)
  }
  disabled$trait_eigenvalues <- eigenvalues
  disabled$trait_eigenvectors <- eigenvectors
  disabled$base_tier <- as.integer(base_tier - 1L)
  disabled$identity_tier <- as.integer(identity_tier - 1L)
  disabled
}

# Route objective and curvature evaluations through the regular Woodbury
# tape, constructing the exact dense tape lazily near a joint-zero Psi
# boundary. The wider near-boundary band keeps finite-difference Hessians and
# profile evaluations on one numerically stable likelihood route.
.gllvmTMB_route_exact_pair_objective <- function(
    fast_obj, make_dense_obj, n_traits, n_tiers,
    boundary_safe = FALSE) {
  stopifnot(is.list(fast_obj), is.function(fast_obj$fn), is.function(fast_obj$gr))
  router <- new.env(parent = emptyenv())
  router$fast <- fast_obj
  router$dense <- NULL
  router$last_par <- fast_obj$par
  router$sync_state <- function(backend) {
    for (nm in c("last.par", "last.par.best")) {
      value <- backend$env[[nm]]
      if (!is.null(value)) router$fast$env[[nm]] <- value
    }
    invisible(NULL)
  }
  router$backend <- function(par) {
    psi_idx <- grep("^psi_kernel_variance", names(par))
    if (length(psi_idx) != n_traits * n_tiers) {
      stop("Exact paired-kernel Psi parameters are missing from the optimizer vector.",
           call. = FALSE)
    }
    psi <- matrix(par[psi_idx], nrow = n_tiers, ncol = n_traits, byrow = TRUE)
    if (!isTRUE(boundary_safe) && any(colSums(psi) <= 1e-3)) {
      if (is.null(router$dense)) router$dense <- make_dense_obj()
      router$dense
    } else {
      router$fast
    }
  }

  routed <- fast_obj
  routed$fn <- function(par) {
    router$last_par <- par
    backend <- router$backend(par)
    value <- backend$fn(par)
    router$sync_state(backend)
    value
  }
  routed$gr <- function(par) {
    router$last_par <- par
    backend <- router$backend(par)
    value <- backend$gr(par)
    router$sync_state(backend)
    value
  }
  if (is.function(fast_obj$he)) {
    routed$he <- function(par) {
      router$last_par <- par
      backend <- router$backend(par)
      if (!is.function(backend$he)) {
        stop("Exact paired-kernel backend does not provide curvature.",
             call. = FALSE)
      }
      value <- backend$he(par)
      router$sync_state(backend)
      value
    }
  }
  routed$report <- function(par = NULL) {
    p <- par %||% router$last_par
    backend <- router$backend(p)
    if (!is.null(par)) {
      backend$fn(par)
      router$sync_state(backend)
    }
    backend$report()
  }
  attr(routed, "gllvmTMB_exact_pair_router") <- router
  routed
}

.gllvmTMB_exact_pair_backend <- function(obj, par) {
  router <- attr(obj, "gllvmTMB_exact_pair_router")
  if (is.null(router)) return(obj)
  obj$fn(par)
  obj
}
