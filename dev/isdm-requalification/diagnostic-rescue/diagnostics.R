## Pure and in-process diagnostics for the bounded iSDM rescue experiment.
##
## The fitting runner may source this file, but none of these functions starts
## a fit.  Public gllvmTMB prediction is used as the identity oracle; direct
## access to the already-returned TMB object is diagnostic only.

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

.diagnostic_stop <- function(message, class) {
  stop(structure(list(message = message, call = NULL),
                 class = c(class, "error", "condition")))
}

.diagnostic_predict_est <- function(x) {
  if (is.data.frame(x) && "est" %in% names(x)) x <- x$est
  x <- as.numeric(x)
  if (!length(x) || any(!is.finite(x))) {
    .diagnostic_stop("prediction did not return one finite est vector",
                     "isdm_diagnostic_prediction_invalid")
  }
  x
}

#' Reconstruct the three frozen nonspatial truth targets
#'
#' Replays only the structural RNG stream used by `isdm_nonspatial_fixture()`.
#' The returned matrices are cell by trait and are checked against the truth
#' retained in the fixture, so RNG drift fails closed.
#'
#' @param fixture A frozen nonspatial fixture.
#' @return Named list `fixed`, `shared`, and `full`, each a cell-by-trait
#'   matrix; `u` and `e` retain the reconstructed random components.
diagnostic_nonspatial_truth_components <- function(fixture) {
  design <- fixture$design
  truth <- fixture$truth
  n_cells <- as.integer(design$n_cells)
  traits <- names(truth$alpha) %||% rownames(truth$lambda)
  if (length(traits) != 3L || !is.finite(design$structure_seed) ||
      n_cells < 1L) {
    .diagnostic_stop("fixture lacks the frozen nonspatial structural contract",
                     "isdm_diagnostic_truth_contract_invalid")
  }

  set.seed(as.integer(design$structure_seed))
  env <- as.numeric(scale(stats::rnorm(n_cells)))
  u <- stats::rnorm(n_cells)
  psi <- as.numeric(truth$psi[traits])
  e <- matrix(
    stats::rnorm(n_cells * length(traits),
                 sd = rep(sqrt(psi), each = n_cells)),
    nrow = n_cells, ncol = length(traits),
    dimnames = list(levels(fixture$scoring$cell_id), traits)
  )
  fixed <- sweep(outer(env, as.numeric(truth$beta[traits])), 2L,
                 as.numeric(truth$alpha[traits]), "+")
  shared <- fixed + tcrossprod(u, as.numeric(truth$lambda[traits, , drop = FALSE]))
  full <- shared + e
  dimnames(fixed) <- dimnames(shared) <- dimnames(full) <- dimnames(e)

  retained <- as.matrix(truth$eta_ecological)
  if (!identical(dim(retained), dim(full)) ||
      max(abs(retained - full)) > 1e-12) {
    .diagnostic_stop(
      "structural RNG replay does not reproduce the retained ecological truth",
      "isdm_diagnostic_truth_replay_mismatch"
    )
  }
  list(fixed = fixed, shared = shared, full = full, u = u, e = e,
       env = env)
}

.diagnostic_draw_response_stream <- function(fixture, seed) {
  data <- fixture$data
  truth <- diagnostic_nonspatial_truth_components(fixture)$full
  cells <- match(as.character(data$cell_id), rownames(truth))
  traits <- match(as.character(data$trait), colnames(truth))
  sources <- as.character(data$isdm_source)
  eta <- truth[cbind(cells, traits)] + fixture$truth$gamma[sources] +
    fixture$truth$delta[sources] * data$bias_x
  laws <- fixture$design$laws[sources]
  value <- numeric(nrow(data))
  set.seed(as.integer(seed))
  ## Preserve the producer's source-wise draw ordering.  Each arm is one
  ## contiguous block in the frozen fixture, but indexing makes that explicit.
  for (source in levels(data$isdm_source)) {
    idx <- which(sources == source)
    if (!length(idx)) next
    if (identical(unname(fixture$design$laws[[source]]), "poisson")) {
      value[idx] <- stats::rpois(
        length(idx), exp(eta[idx] + data$log_support[idx])
      )
    } else {
      probability <- -expm1(-exp(eta[idx] + data$log_support[idx]))
      value[idx] <- stats::rbinom(length(idx), 1L, probability)
    }
  }
  value
}

#' Append two registered independent response streams to a frozen fixture
#'
#' @param fixture A frozen nonspatial fixture.
#' @param native_task_id The immutable production task id.
#' @return The fixture with a three-times-longer `data` table.  Rows from the
#'   original table occur first and are unchanged in every original column.
#'   `replicate_id` identifies streams 1--3 and `design$replicate_seeds`
#'   retains the registered added-stream seeds.
diagnostic_rep3_fixture <- function(fixture, native_task_id) {
  native_task_id <- as.integer(native_task_id)
  if (length(native_task_id) != 1L || is.na(native_task_id) ||
      native_task_id < 1L) {
    .diagnostic_stop("native_task_id must be one positive integer",
                     "isdm_diagnostic_task_id_invalid")
  }
  baseline <- fixture$data
  seeds <- as.integer(203000000 + 2L * native_task_id + 0:1)
  additions <- lapply(seq_along(seeds), function(i) {
    out <- baseline
    out$value <- .diagnostic_draw_response_stream(fixture, seeds[[i]])
    out
  })
  combined <- do.call(rbind, c(list(baseline), additions))
  combined$replicate_id <- rep(1:3, each = nrow(baseline))
  ## Verify the promise before returning: every pre-existing baseline column
  ## is byte-identical, including factor levels and attributes.
  if (!identical(combined[seq_len(nrow(baseline)), names(baseline), drop = FALSE],
                 baseline)) {
    .diagnostic_stop("rep3 construction changed a frozen baseline row",
                     "isdm_diagnostic_rep3_baseline_changed")
  }
  fixture$data <- combined
  fixture$design$replication <- 3L
  fixture$design$replicate_seeds <- seeds
  fixture$design$replicate_seed_rule <-
    "203000000 + 2 * native_task_id, then next integer"
  fixture
}

.diagnostic_surface_vector <- function(matrix, scoring) {
  matrix[cbind(match(as.character(scoring$cell_id), rownames(matrix)),
               match(as.character(scoring$trait), colnames(matrix)))]
}

.diagnostic_random_surfaces <- function(fit, scoring, fixed) {
  n_traits <- length(levels(scoring$trait))
  n_sites <- length(levels(scoring$cell_id))
  tr <- as.integer(scoring$trait)
  site <- as.integer(scoring$cell_id)
  last <- fit$tmb_obj$env$last.par.best
  if (is.null(last)) last <- fit$tmb_obj$env$last.par

  shared_add <- numeric(nrow(scoring))
  if (isTRUE(fit$use$rr_B)) {
    d <- as.integer(fit$d_B %||% ncol(fit$report$Lambda_B))
    lambda <- as.matrix(fit$report$Lambda_B)
    if (nrow(lambda) != n_traits || ncol(lambda) != d) {
      .diagnostic_stop("Lambda_B dimensions do not match the scoring grid",
                       "isdm_diagnostic_loading_shape_invalid")
    }
    scores <- if (isTRUE(fit$use$lv_B) && !is.null(fit$report$U_B_total)) {
      t(matrix(as.numeric(fit$report$U_B_total), nrow = n_sites, ncol = d))
    } else {
      z <- last[names(last) == "z_B"]
      if (length(z) != d * n_sites) {
        .diagnostic_stop("z_B dimensions do not match the scoring grid",
                         "isdm_diagnostic_score_shape_invalid")
      }
      matrix(z, nrow = d, ncol = n_sites)
    }
    shared_add <- rowSums(lambda[tr, , drop = FALSE] *
                            t(scores[, site, drop = FALSE]))
  }

  unique_add <- numeric(nrow(scoring))
  if (isTRUE(fit$use$diag_B)) {
    s <- last[names(last) == "s_B"]
    if (length(s) != n_traits * n_sites) {
      .diagnostic_stop("s_B dimensions do not match the scoring grid",
                       "isdm_diagnostic_unique_shape_invalid")
    }
    s <- matrix(s, nrow = n_traits, ncol = n_sites)
    unique_add <- s[cbind(tr, site)]
  }
  list(shared = fixed + shared_add,
       full = fixed + shared_add + unique_add,
       shared_add = shared_add, unique_add = unique_add)
}

#' Extract fixed, shared, and full fitted surfaces
#'
#' @param fit A fit returned by public `gllvmTMB()`.
#' @param fixture Its frozen nonspatial fixture.
#' @param tolerance Maximum allowed direct-vs-public full prediction error.
#' @return Named list of fitted vectors plus `public_full`, `identity_error`,
#'   and a rank-one sign-invariance check.
diagnostic_extract_nonspatial <- function(fit, fixture, tolerance = 1e-10,
                                          .predict = stats::predict) {
  scoring <- fixture$scoring
  fixed <- .diagnostic_predict_est(suppressMessages(
    .predict(fit, newdata = scoring, type = "link", re_form = ~0)
  ))
  random <- .diagnostic_random_surfaces(fit, scoring, fixed)
  public_full <- .diagnostic_predict_est(suppressMessages(
    .predict(fit, newdata = scoring, type = "link")
  ))
  identity_error <- max(abs(random$full - public_full))
  if (!is.finite(identity_error) || identity_error > tolerance) {
    .diagnostic_stop(
      sprintf("direct full surface differs from public predict by %.17g",
              identity_error),
      "isdm_diagnostic_public_prediction_mismatch"
    )
  }
  sign_check <- list(available = FALSE, max_error = NA_real_)
  if (isTRUE(fit$use$rr_B) && ncol(as.matrix(fit$report$Lambda_B)) == 1L) {
    lambda <- as.matrix(fit$report$Lambda_B)
    contribution <- random$shared_add
    ## Multiplying both rank-one factors by -1 must preserve their product.
    sign_check <- list(
      available = TRUE,
      max_error = max(abs(contribution - ((-1) * contribution * (-1))))
    )
  }
  list(fixed = fixed, shared = random$shared, full = random$full,
       public_full = public_full, identity_error = identity_error,
       sign_invariance = sign_check)
}

#' Calculate trait-aware surface correlation and normalized RMSE
#'
#' @param estimate,truth Numeric vectors of equal length.
#' @param trait Trait labels aligned to the vectors.
#' @return Overall metrics and a per-trait data frame.  Normalization uses the
#'   truth SD within trait, then averages squared standardized errors.
diagnostic_surface_metrics <- function(estimate, truth, trait) {
  estimate <- as.numeric(estimate)
  truth <- as.numeric(truth)
  trait <- as.character(trait)
  if (!length(estimate) || length(estimate) != length(truth) ||
      length(trait) != length(truth) || any(!is.finite(c(estimate, truth)))) {
    .diagnostic_stop("surface vectors must be aligned, nonempty, and finite",
                     "isdm_diagnostic_surface_invalid")
  }
  levels <- unique(trait)
  per_trait <- do.call(rbind, lapply(levels, function(level) {
    idx <- trait == level
    scale <- stats::sd(truth[idx])
    data.frame(
      trait = level,
      n = sum(idx),
      correlation = if (sum(idx) > 1L) stats::cor(estimate[idx], truth[idx]) else NA_real_,
      rmse = sqrt(mean((estimate[idx] - truth[idx])^2)),
      normalized_rmse = if (is.finite(scale) && scale > 0)
        sqrt(mean(((estimate[idx] - truth[idx]) / scale)^2)) else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  scales <- stats::setNames(vapply(levels, function(level) {
    stats::sd(truth[trait == level])
  }, numeric(1L)), levels)
  standardized <- (estimate - truth) / scales[trait]
  list(
    correlation = stats::cor(estimate, truth),
    rmse = sqrt(mean((estimate - truth)^2)),
    normalized_rmse = sqrt(mean(standardized^2)),
    per_trait = per_trait
  )
}

.diagnostic_matrix_summary <- function(H, dimension_cap = 500L,
                                       vectors = FALSE) {
  if (is.null(H)) return(list(available = FALSE, reason = "matrix_missing"))
  H <- tryCatch(as.matrix(H), error = function(e) e)
  if (inherits(H, "condition")) {
    return(list(available = FALSE, reason = conditionMessage(H)))
  }
  if (nrow(H) != ncol(H) || !nrow(H) || any(!is.finite(H))) {
    return(list(available = FALSE, reason = "matrix_not_finite_square"))
  }
  H <- (H + t(H)) / 2
  pd <- !inherits(try(chol(H), silent = TRUE), "try-error")
  out <- list(available = TRUE, dimension = nrow(H), pd = pd,
              eigen_available = nrow(H) <= dimension_cap)
  if (!out$eigen_available) {
    out$reason <- sprintf("dimension_%d_exceeds_cap_%d", nrow(H), dimension_cap)
    return(out)
  }
  eig <- eigen(H, symmetric = TRUE, only.values = !vectors)
  ord <- order(eig$values)
  out$eigenvalues <- eig$values[ord]
  out$smallest_five <- head(out$eigenvalues, 5L)
  out$minimum_eigenvalue <- out$eigenvalues[[1L]]
  if (vectors) out$vectors <- eig$vectors[, ord, drop = FALSE]
  out
}

.diagnostic_block_map <- function(par) {
  nm <- names(par)
  if (is.null(nm) || length(nm) != length(par)) nm <- rep("unnamed", length(par))
  ids <- unique(nm)
  stats::setNames(lapply(ids, function(id) which(nm == id)), ids)
}

.diagnostic_block_mass <- function(vector, blocks) {
  rows <- lapply(names(blocks), function(block) {
    idx <- blocks[[block]]
    M <- sum(vector[idx]^2)
    data.frame(block = block, n = length(idx), M = M, A = M / length(idx),
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  denom <- sum(out$A)
  out$N <- if (denom > 0) out$A / denom else NA_real_
  out[order(out$N, decreasing = TRUE), , drop = FALSE]
}

.diagnostic_eigen_attribution <- function(summary, par) {
  if (!isTRUE(summary$available) || !isTRUE(summary$eigen_available) ||
      is.null(summary$vectors)) return(NULL)
  blocks <- .diagnostic_block_map(par)
  values <- summary$eigenvalues
  targets <- c(smallest_algebraic = 1L,
               closest_to_zero = which.min(abs(values)))
  lapply(targets, function(column) {
    vector <- summary$vectors[, column]
    ord <- order(vector^2, decreasing = TRUE)
    list(
      eigenvalue = values[[column]],
      block_mass = .diagnostic_block_mass(vector, blocks),
      top_coordinates = data.frame(
        position = head(ord, 10L),
        parameter = names(par)[head(ord, 10L)],
        loading = vector[head(ord, 10L)],
        squared_mass = vector[head(ord, 10L)]^2,
        stringsAsFactors = FALSE
      )
    )
  })
}

.diagnostic_align_adfun <- function(obj, par) {
  value <- obj$fn(par)
  obj$env$last.par.best <- obj$env$last.par
  as.numeric(value)
}

#' Extract same-process marginal, conditional, and joint curvature
#'
#' @param fit A returned public-route fit.
#' @param dimension_cap Largest matrix to densify for eigendecomposition.
#' @return Named list containing fresh objective replay, marginal fixed
#'   curvature, conditional-random curvature, joint precision, exact block
#'   maps, and native/D-relative M/A/N weak-direction attribution.
diagnostic_curvature <- function(fit, dimension_cap = 500L,
                                 .optim_hess = stats::optimHess,
                                 .sdreport = NULL) {
  dimension_cap <- as.integer(dimension_cap)
  if (length(dimension_cap) != 1L || is.na(dimension_cap) || dimension_cap < 1L) {
    .diagnostic_stop("dimension_cap must be one positive integer",
                     "isdm_diagnostic_dimension_cap_invalid")
  }
  obj <- fit$tmb_obj
  par <- fit$opt$par
  if (is.null(obj) || !is.numeric(par) || !length(par) || any(!is.finite(par))) {
    .diagnostic_stop("fit lacks a finite optimized TMB parameter vector",
                     "isdm_diagnostic_curvature_fit_invalid")
  }
  if (is.null(names(par))) names(par) <- rep("unnamed", length(par))
  fresh_objective <- tryCatch(.diagnostic_align_adfun(obj, par), error = function(e) e)
  if (inherits(fresh_objective, "condition")) {
    return(list(available = FALSE, reason = conditionMessage(fresh_objective)))
  }

  Hf <- tryCatch(.optim_hess(par, obj$fn, obj$gr), error = function(e) e)
  if (inherits(Hf, "condition")) {
    return(list(available = FALSE, fresh_objective = fresh_objective,
                objective_difference = fresh_objective - fit$opt$objective,
                reason = conditionMessage(Hf)))
  }
  marginal_native <- .diagnostic_matrix_summary(Hf, dimension_cap, vectors = TRUE)
  fitted_pd <- fit$sd_report$pdHess %||% NA
  pd_agreement <- is.logical(fitted_pd) && length(fitted_pd) == 1L &&
    !is.na(fitted_pd) && identical(isTRUE(marginal_native$pd), isTRUE(fitted_pd))
  if (!pd_agreement) {
    marginal_native$available <- FALSE
    marginal_native$reason <- "direct_cholesky_disagrees_with_fit_sd_report"
  }

  D <- pmax(1, abs(par))
  H_relative <- Hf * tcrossprod(D)
  marginal_relative <- .diagnostic_matrix_summary(
    H_relative, dimension_cap, vectors = TRUE
  )

  ## ADFun state is mutable: replay and align again before spHess/sdreport.
  replay_before_random <- tryCatch(.diagnostic_align_adfun(obj, par),
                                   error = function(e) e)
  conditional_matrix <- if (inherits(replay_before_random, "condition")) {
    replay_before_random
  } else {
    tryCatch(obj$env$spHess(obj$env$last.par, random = TRUE),
             error = function(e) e)
  }
  conditional <- if (inherits(conditional_matrix, "condition")) {
    list(available = FALSE, reason = conditionMessage(conditional_matrix))
  } else .diagnostic_matrix_summary(conditional_matrix, dimension_cap)

  sdreport_fn <- .sdreport
  if (is.null(sdreport_fn)) {
    sdreport_fn <- function(...) TMB::sdreport(...)
  }
  joint_call <- if (inherits(replay_before_random, "condition")) {
    replay_before_random
  } else tryCatch(
    sdreport_fn(obj, par.fixed = par, hessian.fixed = Hf,
                getJointPrecision = TRUE, skip.delta.method = TRUE),
    error = function(e) e
  )
  joint <- if (inherits(joint_call, "condition")) {
    list(available = FALSE, reason = conditionMessage(joint_call))
  } else if (is.null(joint_call$jointPrecision)) {
    list(available = FALSE, reason = "joint_precision_missing")
  } else .diagnostic_matrix_summary(joint_call$jointPrecision, dimension_cap)

  native_attr <- if (pd_agreement) {
    .diagnostic_eigen_attribution(marginal_native, par)
  } else NULL
  relative_attr <- .diagnostic_eigen_attribution(marginal_relative, par)
  native_top <- native_attr$smallest_algebraic$block_mass$block[[1L]] %||% NA_character_
  relative_top <- relative_attr$smallest_algebraic$block_mass$block[[1L]] %||% NA_character_

  list(
    available = pd_agreement,
    fresh_objective = fresh_objective,
    optimizer_objective = as.numeric(fit$opt$objective),
    objective_difference = fresh_objective - as.numeric(fit$opt$objective),
    parameter_index_map = .diagnostic_block_map(par),
    marginal_native = marginal_native,
    marginal_relative = marginal_relative,
    conditional_random = conditional,
    joint_precision = joint,
    fit_pd_hessian = fitted_pd,
    direct_pd_agreement = pd_agreement,
    attribution = list(native = native_attr, relative = relative_attr,
                       ranking_agrees = identical(native_top, relative_top),
                       native_top = native_top, relative_top = relative_top)
  )
}
