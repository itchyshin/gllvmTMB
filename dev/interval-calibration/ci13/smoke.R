#!/usr/bin/env Rscript
## CI-13 smoke helper. Deliberately unexecuted: a fit needs a written <=30-minute
## estimate and its retained receipt before this helper is called.

.ci13_kernel_path <- "dev/interval-calibration/ci13/ci13-kernels.R"
if (!file.exists(.ci13_kernel_path)) {
  .ci13_kernel_path <- "../../dev/interval-calibration/ci13/ci13-kernels.R"
}
source(.ci13_kernel_path)

ci13_extract_native_pinned_loadings <- function(fit) {
  lambda <- fit$report$Lambda_B
  if (
    !is.matrix(lambda) ||
      nrow(lambda) != 3L ||
      ncol(lambda) < 1L ||
      any(!is.finite(lambda))
  ) {
    stop(
      "CI-13 smoke requires native fit$report$Lambda_B with three traits",
      call. = FALSE
    )
  }
  constrained <- lambda[outer(
    seq_len(nrow(lambda)),
    seq_len(ncol(lambda)),
    `<`
  )]
  if (
    length(constrained) && any(abs(constrained) > sqrt(.Machine$double.eps))
  ) {
    stop(
      "CI-13 smoke refuses rotated or non-pinned Lambda_B loadings",
      call. = FALSE
    )
  }
  lambda
}

ci13_smoke_truth <- function(d) {
  d <- as.integer(d)
  if (!d %in% c(1L, 2L)) {
    stop("CI-13 smoke only supports the frozen d=1 or d=2 cells", call. = FALSE)
  }
  lambda <- matrix(0, nrow = 3L, ncol = d)
  lambda[, 1L] <- c(0.80, 0.45, -0.35)
  if (d == 2L) {
    lambda[2L, 2L] <- 0.70
    lambda[3L, 2L] <- 0.40
  }
  list(
    lambda = lambda,
    psi = c(0.70, 0.80, 0.90),
    intercept = c(-0.2, 0.1, 0.25)
  )
}

ci13_smoke_fit_healthy <- function(fit) {
  inherits(fit, "gllvmTMB_multi") &&
    identical(as.integer(fit$opt$convergence), 0L) &&
    isTRUE(fit$fit_health$converged) &&
    !is.null(fit$sd_report) &&
    isTRUE(fit$sd_report$pdHess)
}

ci13_smoke_ci_failure_attempt <- function(manifest, cell_id, rep) {
  targets <- ci13_cell_targets(manifest$spec, cell_id)
  outcomes <- stats::setNames(
    rep("ci_failed", nrow(targets)),
    targets$target_id
  )
  ci13_outer_attempt(
    manifest,
    cell_id,
    rep,
    "eligible",
    ci13_target_results(manifest, cell_id, outcomes)
  )
}

## This is an intentionally unexecuted, one-replicate end-to-end rehearsal.
## Calling it requires a recorded <=30-minute estimate; a 5000-replicate run is
## a separate approval-gated campaign.  It uses the public loading_ci() joint
## delta machinery and records a canonical outer attempt rather than retaining
## only a favourable interval.
ci13_smoke_one_replicate <- function(cell_id = 2L, rep = 1L, source_sha) {
  if (
    missing(source_sha) ||
      !is.character(source_sha) ||
      length(source_sha) != 1L ||
      !nzchar(source_sha)
  ) {
    stop("CI-13 smoke requires an explicit source SHA", call. = FALSE)
  }
  started <- proc.time()[["elapsed"]]
  spec <- ci13_campaign_spec()
  cell <- spec$cells[spec$cells$cell_id == as.integer(cell_id), , drop = FALSE]
  if (nrow(cell) != 1L) {
    stop("CI-13 smoke cell is outside the frozen campaign", call. = FALSE)
  }
  manifest <- ci13_attempt_manifest(
    spec = spec,
    cell_ids = cell$cell_id,
    rep_ids = as.integer(rep),
    source_sha = source_sha
  )
  set.seed(ci13_rep_seed(cell$cell_id, rep))
  truth <- ci13_smoke_truth(cell$d)
  latent_scores <- matrix(
    stats::rnorm(cell$n_units * cell$d),
    nrow = cell$n_units,
    ncol = cell$d
  )
  mean_matrix <- matrix(
    truth$intercept,
    nrow = cell$n_units,
    ncol = 3L,
    byrow = TRUE
  )
  y <- mean_matrix +
    latent_scores %*% t(truth$lambda) +
    matrix(stats::rnorm(cell$n_units * 3L), nrow = cell$n_units, ncol = 3L) %*%
      diag(truth$psi, nrow = 3L)
  trait_names <- paste0("trait_", seq_len(3L))
  data_long <- data.frame(
    unit = factor(rep(seq_len(cell$n_units), times = 3L)),
    trait = factor(rep(trait_names, each = cell$n_units), levels = trait_names),
    value = as.numeric(y)
  )
  ## Diagonal anchors use the DGP sign/scale, pinning the native engine's
  ## lower-triangular orientation without applying Varimax or any post-hoc
  ## rotation.  The interval payload still records every engine-free entry.
  constraint <- ci13_native_confirmatory_constraint(
    diag(truth$lambda)[seq_len(cell$d)],
    n_traits = 3L,
    d = cell$d
  )
  dimnames(constraint) <- list(trait_names, paste0("LV", seq_len(cell$d)))
  fitted <- tryCatch(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = cell$d, unique = TRUE),
      data = data_long,
      family = stats::gaussian(),
      lambda_constraint = list(unit = constraint)
    ),
    error = identity
  )
  if (inherits(fitted, "error")) {
    return(list(
      attempt = ci13_outer_attempt(
        manifest,
        cell$cell_id,
        rep,
        "scientific_base_failure"
      ),
      runtime_seconds = proc.time()[["elapsed"]] - started,
      provenance = list(
        seed = ci13_rep_seed(cell$cell_id, rep),
        source_sha = source_sha,
        error = conditionMessage(fitted),
        stage = "native-fit"
      )
    ))
  }
  if (!ci13_smoke_fit_healthy(fitted)) {
    return(list(
      attempt = ci13_outer_attempt(
        manifest,
        cell$cell_id,
        rep,
        "base_fit_failed"
      ),
      runtime_seconds = proc.time()[["elapsed"]] - started,
      provenance = list(
        seed = ci13_rep_seed(cell$cell_id, rep),
        source_sha = source_sha,
        stage = "base-health",
        convergence = fitted$opt$convergence,
        fit_health = fitted$fit_health,
        pd_hessian = isTRUE(fitted$sd_report$pdHess)
      )
    ))
  }
  lambda_hat <- ci13_extract_native_pinned_loadings(fitted)
  ci <- tryCatch(
    gllvmTMB::loading_ci(
      fitted,
      level = "unit",
      method = "wald",
      loading_scale = "standardized"
    ),
    error = identity
  )
  if (inherits(ci, "error")) {
    return(list(
      attempt = ci13_smoke_ci_failure_attempt(manifest, cell$cell_id, rep),
      runtime_seconds = proc.time()[["elapsed"]] - started,
      provenance = list(
        seed = ci13_rep_seed(cell$cell_id, rep),
        source_sha = source_sha,
        error = conditionMessage(ci),
        stage = "loading_ci",
        lambda_hat = lambda_hat
      )
    ))
  }
  targets <- ci13_cell_targets(spec, cell$cell_id)
  diagnostics <- ci13_pinned_diagnostic_targets(spec$n_traits, cell$d)
  truth_sigma <- ci13_sigma(truth$lambda, log(truth$psi))
  outcomes <- vapply(
    seq_len(nrow(targets)),
    function(i) {
      hit <- which(
        as.character(ci$trait) == trait_names[targets$trait[i]] &
          as.character(ci$axis) == paste0("LV", targets$factor[i])
      )
      if (
        length(hit) != 1L ||
          !is.finite(ci$lower[hit]) ||
          !is.finite(ci$upper[hit])
      ) {
        return("ci_failed")
      }
      target_truth <- truth$lambda[targets$trait[i], targets$factor[i]] /
        sqrt(truth_sigma[targets$trait[i], targets$trait[i]])
      if (target_truth >= ci$lower[hit] && target_truth <= ci$upper[hit]) {
        "covered"
      } else {
        "miss"
      }
    },
    character(1)
  )
  names(outcomes) <- targets$target_id
  pinned_diagnostics <- do.call(
    rbind,
    lapply(seq_len(nrow(diagnostics)), function(i) {
      hit <- which(
        as.character(ci$trait) == trait_names[diagnostics$trait[i]] &
          as.character(ci$axis) == paste0("LV", diagnostics$factor[i])
      )
      data.frame(
        target_id = diagnostics$target_id[i],
        trait = diagnostics$trait[i],
        factor = diagnostics$factor[i],
        status = "pinned-diagnostic",
        estimate = if (length(hit) == 1L) ci$estimate[hit] else NA_real_,
        se = if (length(hit) == 1L) ci$se[hit] else NA_real_,
        lower = if (length(hit) == 1L) ci$lower[hit] else NA_real_,
        upper = if (length(hit) == 1L) ci$upper[hit] else NA_real_,
        stringsAsFactors = FALSE
      )
    })
  )
  list(
    attempt = ci13_outer_attempt(
      manifest,
      cell$cell_id,
      rep,
      "eligible",
      ci13_target_results(manifest, cell$cell_id, outcomes)
    ),
    runtime_seconds = proc.time()[["elapsed"]] - started,
    provenance = list(
      seed = ci13_rep_seed(cell$cell_id, rep),
      source_sha = source_sha,
      cell = cell,
      truth = truth,
      lambda_hat = lambda_hat,
      interval_method = "loading_ci(method = 'wald', loading_scale = 'standardized')",
      pinned_diagnostics = pinned_diagnostics
    )
  )
}
