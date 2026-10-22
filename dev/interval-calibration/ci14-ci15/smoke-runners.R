## One-replicate CI-14/15 timing smoke runners.
##
## These are executable only when called explicitly after a <=30-minute
## estimate.  Merely sourcing this file performs no fit or simulation.  Each
## runner makes one frozen DGP, calls the public gllvmTMB() and slope_sd_ci()
## route, and returns a canonical outer attempt plus timing/provenance.

if (!exists("ci1415_attempt_manifest", mode = "function")) {
  stop("source ci1415-kernels.R before smoke-runners.R", call. = FALSE)
}

.ci1415_smoke_formula <- function(route) {
  switch(
    route,
    CI14 = paste(
      "gllvmTMB(value ~ 0 + trait + (0 + trait):x +",
      "latent(0 + trait + (0 + trait):x | individual, d = 2, unique = TRUE));",
      "slope_sd_ci(fit)"
    ),
    CI15_PHYLO = paste(
      "gllvmTMB(value ~ 0 + trait + phylo_dep(0 + trait +",
      "(0 + trait):x | species, tree = phy$tree)); slope_sd_ci(fit)"
    ),
    CI15_LOADINGS = paste(
      "gllvmTMB(value ~ 0 + trait + (0 + trait):x +",
      "latent(0 + trait + (0 + trait):x | individual, d = 2, unique = FALSE));",
      "slope_sd_ci(fit)"
    ),
    .ci1415_stop("unknown CI-14/15 smoke route")
  )
}

ci1415_smoke_request <- function(
  packet = c("CI14", "CI15"),
  cell_id,
  rep = 1L,
  source_sha
) {
  packet <- match.arg(packet)
  if (
    !is.character(source_sha) || length(source_sha) != 1L || !nzchar(source_sha)
  ) {
    .ci1415_stop(
      "CI-14/15 timing smoke requires explicit source_sha provenance"
    )
  }
  manifest <- ci1415_attempt_manifest(
    packet,
    cell_ids = as.integer(cell_id),
    rep_ids = as.integer(rep),
    source_sha = source_sha
  )
  expected <- manifest$expected[[1L]]
  runner <- switch(
    expected$route,
    CI14 = ci1415_run_smoke_ci14,
    CI15_PHYLO = ci1415_run_smoke_ci15_phylo,
    CI15_LOADINGS = ci1415_run_smoke_ci15_loadings
  )
  list(
    execution = "not_run",
    packet = packet,
    campaign_id = manifest$campaign_id,
    cell_id = expected$cell_id,
    rep = expected$rep,
    seed = expected$seed,
    route = expected$route,
    source_sha = source_sha,
    truth_fingerprint = expected$truth_fingerprint,
    fit_formula = .ci1415_smoke_formula(expected$route),
    manifest = manifest,
    runner = runner,
    provenance = list(
      schema_version = manifest$schema_version,
      source_sha = source_sha,
      seed = expected$seed,
      truth_fingerprint = expected$truth_fingerprint,
      estimate_required_before_run = TRUE,
      no_remote_or_campaign_authority = TRUE
    )
  )
}

.ci1415_ordinary_augmented_data <- function(truth, n_ind, unique_psi) {
  n_traits <- length(truth$traits)
  n_rep <- 6L
  ids <- paste0("id", seq_len(n_ind))
  df <- expand.grid(
    individual = factor(ids, levels = ids),
    rep = seq_len(n_rep),
    trait = factor(truth$traits, levels = truth$traits),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  df$session_id <- factor(paste(df$individual, df$rep, sep = "_"))
  x_by_session <- stats::rnorm(nlevels(df$session_id))
  df$x <- x_by_session[as.integer(df$session_id)]

  lambda_intercept <- rbind(c(0.35, 0.00), c(0.12, 0.28), c(-0.14, 0.21))
  lambda_intercept <- lambda_intercept[seq_len(n_traits), , drop = FALSE]
  lambda_aug <- matrix(0, nrow = 2L * n_traits, ncol = 2L)
  lambda_aug[seq(1L, 2L * n_traits, by = 2L), ] <- lambda_intercept
  lambda_aug[seq(2L, 2L * n_traits, by = 2L), ] <- truth$lambda_slope
  z <- matrix(stats::rnorm(2L * n_ind), nrow = 2L)
  coeff <- lambda_aug %*% z
  if (isTRUE(unique_psi)) {
    psi_aug <- numeric(2L * n_traits)
    psi_aug[seq(1L, 2L * n_traits, by = 2L)] <- c(0.30, 0.27, 0.25)[seq_len(
      n_traits
    )]
    psi_aug[seq(2L, 2L * n_traits, by = 2L)] <- truth$psi_slope
    coeff <- coeff +
      matrix(
        stats::rnorm(length(psi_aug) * n_ind, sd = rep(psi_aug, n_ind)),
        nrow = length(psi_aug),
        ncol = n_ind
      )
  }
  ti <- as.integer(df$trait)
  ii <- as.integer(df$individual)
  pos <- 2L * (ti - 1L)
  df$value <- c(0.20, -0.10, 0.05)[ti] +
    c(0.30, -0.20, 0.10)[ti] * df$x +
    coeff[cbind(pos + 1L, ii)] +
    coeff[cbind(pos + 2L, ii)] * df$x +
    stats::rnorm(nrow(df), sd = 0.35)
  df
}

.ci1415_phylo_data <- function(truth, n_sp) {
  if (!requireNamespace("ape", quietly = TRUE)) {
    .ci1415_stop("CI-15 phylogenetic timing smoke requires the ape package")
  }
  n_rep <- 6L
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(Cphy + diag(1e-8, n_sp)))
  B <- (LA %*% matrix(stats::rnorm(n_sp * 4L), n_sp, 4L)) %*%
    chol(truth$L %*% t(truth$L))
  rownames(B) <- tree$tip.label
  df <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep),
    trait = factor(truth$traits, levels = truth$traits),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  x_by_sp_rep <- stats::rnorm(n_sp * n_rep)
  df$x <- x_by_sp_rep[(as.integer(df$species) - 1L) * n_rep + df$rep]
  ti <- as.integer(df$trait)
  si <- as.integer(df$species)
  pos <- 2L * (ti - 1L)
  df$value <- c(1.0, 0.5)[ti] +
    B[cbind(si, pos + 1L)] +
    B[cbind(si, pos + 2L)] * df$x +
    stats::rnorm(nrow(df), sd = 0.30)
  list(data = df, tree = tree)
}

.ci1415_fit_smoke <- function(request) {
  spec <- request$manifest$spec
  cell <- spec$cells[spec$cells$cell_id == request$cell_id, , drop = FALSE]
  route <- request$route
  if (identical(route, "CI14")) {
    truth <- spec$truth
    data <- .ci1415_ordinary_augmented_data(
      truth,
      cell$n_ind,
      unique_psi = TRUE
    )
    fit <- gllvmTMB::gllvmTMB(
      value ~ 0 +
        trait +
        (0 + trait):x +
        latent(0 + trait + (0 + trait):x | individual, d = 2, unique = TRUE),
      data = data,
      trait = "trait",
      unit = "individual",
      control = gllvmTMB::gllvmTMBcontrol(
        se = TRUE,
        optimizer = "optim",
        optArgs = list(method = "BFGS")
      )
    )
  } else if (identical(route, "CI15_LOADINGS")) {
    truth <- spec$truth$CI15_LOADINGS
    data <- .ci1415_ordinary_augmented_data(
      truth,
      cell$n_ind,
      unique_psi = FALSE
    )
    fit <- gllvmTMB::gllvmTMB(
      value ~ 0 +
        trait +
        (0 + trait):x +
        latent(0 + trait + (0 + trait):x | individual, d = 2, unique = FALSE),
      data = data,
      trait = "trait",
      unit = "individual",
      control = gllvmTMB::gllvmTMBcontrol(
        se = TRUE,
        optimizer = "optim",
        optArgs = list(method = "BFGS")
      )
    )
  } else {
    truth <- spec$truth$CI15_PHYLO
    phy <- .ci1415_phylo_data(truth, cell$n_sp)
    fit <- gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        phylo_dep(0 + trait + (0 + trait):x | species, tree = phy$tree),
      data = phy$data,
      unit = "species",
      control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
    )
  }
  list(fit = fit, truth = truth)
}

.ci1415_fit_is_healthy <- function(fit) {
  inherits(fit, "gllvmTMB_multi") &&
    identical(as.integer(fit$opt$convergence), 0L) &&
    isTRUE(fit$fit_health$converged) &&
    !is.null(fit$sd_report) &&
    isTRUE(fit$sd_report$pdHess)
}

.ci1415_truth_value <- function(request, target) {
  truth <- .ci1415_truth_for_route(request$manifest$spec, request$route)
  index <- match(target$trait, truth$traits)
  if (is.na(index)) {
    .ci1415_stop("timing smoke target trait does not match frozen truth")
  }
  if (identical(request$route, "CI14")) {
    if (identical(target$component, "unique_psi")) {
      truth$unique_slope_sd[[index]]
    } else {
      truth$total_slope_sd[[index]]
    }
  } else {
    truth$marginal_slope_sd[[index]]
  }
}

.ci1415_payload_from_ci <- function(request, ci) {
  payload <- ci1415_target_results(
    request$manifest,
    request$route,
    outcome = "covered"
  )
  if (!is.data.frame(ci)) {
    for (i in seq_along(payload)) {
      payload[[i]]$outcome <- "ci_failed"
    }
    return(payload)
  }
  for (i in seq_along(payload)) {
    target <- payload[[i]]
    row <- ci[as.character(ci$trait) == target$trait, , drop = FALSE]
    healthy <- nrow(row) == 1L
    if (
      healthy &&
        identical(request$route, "CI14") &&
        identical(target$component, "unique_psi")
    ) {
      healthy <- identical(as.character(row$component), "unique_psi") &&
        identical(as.character(row$status), "ok") &&
        is.finite(row$lower) &&
        is.finite(row$upper)
      lower <- row$lower
      upper <- row$upper
    } else if (healthy && identical(request$route, "CI14")) {
      healthy <- identical(as.character(row$component), "unique_psi") &&
        identical(as.character(row$total_status), "ok") &&
        is.finite(row$total_lower) &&
        is.finite(row$total_upper)
      lower <- row$total_lower
      upper <- row$total_upper
    } else if (healthy) {
      healthy <- identical(as.character(row$component), "total") &&
        identical(as.character(row$status), "ok") &&
        is.finite(row$lower) &&
        is.finite(row$upper)
      lower <- row$lower
      upper <- row$upper
    }
    if (!isTRUE(healthy)) {
      payload[[i]]$outcome <- "ci_failed"
    } else {
      truth <- .ci1415_truth_value(request, target)
      payload[[i]]$outcome <- if (lower <= truth && truth <= upper) {
        "covered"
      } else {
        "miss"
      }
    }
  }
  payload
}

.ci1415_smoke_result <- function(
  request,
  outer_attempt,
  runtime_seconds,
  fit_health,
  failure = NULL
) {
  provenance <- request$provenance
  provenance$fit_formula <- request$fit_formula
  list(
    outer_attempt = outer_attempt,
    runtime_seconds = as.numeric(runtime_seconds),
    source_sha = request$source_sha,
    seed = request$seed,
    truth_fingerprint = request$truth_fingerprint,
    fit_formula = request$fit_formula,
    fit_health = fit_health,
    failure = failure,
    provenance = provenance
  )
}

.ci1415_run_timing_smoke <- function(packet, cell_id, rep = 1L, source_sha) {
  request <- ci1415_smoke_request(
    packet,
    cell_id = cell_id,
    rep = rep,
    source_sha = source_sha
  )
  set.seed(request$seed)
  started <- proc.time()[["elapsed"]]
  fitted <- tryCatch(.ci1415_fit_smoke(request), error = function(e) e)
  runtime_seconds <- proc.time()[["elapsed"]] - started
  if (inherits(fitted, "error")) {
    return(.ci1415_smoke_result(
      request,
      ci1415_outer_attempt(
        request$manifest,
        request$cell_id,
        request$rep,
        "base_fit_failed"
      ),
      runtime_seconds,
      fit_health = FALSE,
      failure = conditionMessage(fitted)
    ))
  }
  if (!.ci1415_fit_is_healthy(fitted$fit)) {
    return(.ci1415_smoke_result(
      request,
      ci1415_outer_attempt(
        request$manifest,
        request$cell_id,
        request$rep,
        "base_fit_failed"
      ),
      runtime_seconds,
      fit_health = FALSE,
      failure = "fit failed the base-health gate"
    ))
  }
  ci <- tryCatch(
    suppressWarnings(gllvmTMB::slope_sd_ci(fitted$fit)),
    error = function(e) e
  )
  payload <- if (inherits(ci, "error")) {
    ci1415_target_results(
      request$manifest,
      request$route,
      outcome = "ci_failed"
    )
  } else {
    .ci1415_payload_from_ci(request, ci)
  }
  .ci1415_smoke_result(
    request,
    ci1415_outer_attempt(
      request$manifest,
      request$cell_id,
      request$rep,
      "eligible",
      payload
    ),
    runtime_seconds,
    fit_health = TRUE,
    failure = if (inherits(ci, "error")) conditionMessage(ci) else NULL
  )
}

ci1415_run_smoke_ci14 <- function(cell_id = 1L, rep = 1L, source_sha) {
  .ci1415_run_timing_smoke(
    "CI14",
    cell_id = cell_id,
    rep = rep,
    source_sha = source_sha
  )
}

ci1415_run_smoke_ci15_phylo <- function(cell_id = 1L, rep = 1L, source_sha) {
  .ci1415_run_timing_smoke(
    "CI15",
    cell_id = cell_id,
    rep = rep,
    source_sha = source_sha
  )
}

ci1415_run_smoke_ci15_loadings <- function(cell_id = 3L, rep = 1L, source_sha) {
  .ci1415_run_timing_smoke(
    "CI15",
    cell_id = cell_id,
    rep = rep,
    source_sha = source_sha
  )
}
