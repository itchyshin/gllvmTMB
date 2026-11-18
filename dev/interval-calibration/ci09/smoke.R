## CI-09 timing smoke entry point (NOT RUN by this packet).
##
## Before using this file, record a <=30-minute estimate and an immutable
## source SHA in the receipt. A successful smoke measures one realised outer
## identity only; the 5000-replicate campaign remains approval-gated.

.ci09_kernel_path <- "dev/interval-calibration/ci09/ci09-kernels.R"
if (!file.exists(.ci09_kernel_path)) {
  .ci09_kernel_path <- "../../dev/interval-calibration/ci09/ci09-kernels.R"
}
source(.ci09_kernel_path)

ci09_smoke_fit_healthy <- function(fit) {
  inherits(fit, "gllvmTMB_multi") &&
    identical(as.integer(fit$opt$convergence), 0L) &&
    isTRUE(fit$fit_health$converged) &&
    !is.null(fit$sd_report) &&
    isTRUE(fit$sd_report$pdHess)
}

ci09_smoke_plan <- function(source_sha) {
  ci09_attempt_manifest(cell_ids = 1L, rep_ids = 1L, source_sha = source_sha)
}

ci09_smoke_formula <- function() {
  formula <- value ~ 0 + trait + dep(0 + trait | site)
  environment(formula) <- asNamespace("gllvmTMB")
  formula
}

ci09_smoke_n_eff <- function(fit, fit_error, converged) {
  if (!isTRUE(fit_error) && isTRUE(converged) && !is.null(fit$n_sites)) {
    as.integer(fit$n_sites)
  } else {
    NA_integer_
  }
}

## This is intentionally an executable single-replicate end-to-end runner, not
## an auto-executing script. The fitted surface is the public ordinary Gaussian
## direct-covariance route, dep(0 + trait | site). The realised n_eff follows
## extract_correlations() exactly for the unit tier: fit$n_sites.
ci09_smoke_once <- function(cell_id = 1L, rep = 1L, source_sha) {
  manifest <- ci09_attempt_manifest(
    cell_ids = as.integer(cell_id),
    rep_ids = as.integer(rep),
    source_sha = source_sha
  )
  cell <- manifest$spec$cells[
    manifest$spec$cells$cell_id == as.integer(cell_id),
    ,
    drop = FALSE
  ]
  if (nrow(cell) != 1L) {
    stop("CI-09 smoke cell is not in the frozen grid", call. = FALSE)
  }

  set.seed(ci09_rep_seed(cell_id, rep))
  Sigma <- matrix(c(1, cell$rho, cell$rho, 1), nrow = 2L)
  values <- matrix(stats::rnorm(cell$n_units * 2L), ncol = 2L) %*% chol(Sigma)
  data <- data.frame(
    site = rep(seq_len(cell$n_units), each = 2L),
    trait = factor(rep(c("trait_1", "trait_2"), times = cell$n_units)),
    value = as.vector(t(values))
  )

  started <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    gllvmTMB::gllvmTMB(
      ci09_smoke_formula(),
      data = data,
      silent = TRUE
    ),
    error = function(e) e
  )
  elapsed_seconds <- unname(proc.time()[["elapsed"]] - started)
  fit_error <- inherits(fit, "error")
  converged <- !fit_error && ci09_smoke_fit_healthy(fit)
  n_eff <- ci09_smoke_n_eff(fit, fit_error, converged)

  if (!isTRUE(converged)) {
    outcome <- "base_fit_failed"
  } else {
    correlations <- tryCatch(
      gllvmTMB::extract_correlations(fit, tier = "unit", method = "fisher-z"),
      error = function(e) e
    )
    interval_error <- inherits(correlations, "error")
    row <- if (interval_error) {
      correlations
    } else {
      correlations[
        correlations$trait_i == "trait_1" & correlations$trait_j == "trait_2",
        ,
        drop = FALSE
      ]
    }
    interval_available <- !interval_error &&
      nrow(row) == 1L &&
      is.finite(row$lower) &&
      is.finite(row$upper)
    outcome <- if (!interval_available) {
      "interval_unavailable"
    } else if (cell$rho >= row$lower && cell$rho <= row$upper) {
      "covered"
    } else {
      "miss"
    }
  }

  attempt <- ci09_attempt(
    manifest = manifest,
    cell_id = cell_id,
    rep = rep,
    target_id = "rho_1_2",
    outcome = outcome,
    n_eff = n_eff,
    base_fit = if (identical(outcome, "base_fit_failed")) {
      "failed"
    } else {
      "eligible"
    }
  )
  list(
    attempt = attempt,
    elapsed_seconds = elapsed_seconds,
    provenance = list(
      source_sha = source_sha,
      seed = ci09_rep_seed(cell_id, rep),
      cell = cell,
      realised_n_eff = n_eff,
      fit_converged = converged,
      fit_error = if (fit_error) conditionMessage(fit) else NULL,
      interval_error = if (exists("interval_error") && interval_error) {
        conditionMessage(correlations)
      } else {
        NULL
      },
      interval_method = "fisher-z",
      formula = "value ~ 0 + trait + dep(0 + trait | site)"
    )
  )
}
