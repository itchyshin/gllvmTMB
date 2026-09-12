args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) == 1L) args[[1L]] else ""
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) {
  stop("Run temporal programme verification from the repository root.", call. = FALSE)
}
allowed <- c("plan", "simulation", "lifecycle", "remote", "phylo", "dep-kernel", "dep-kernel-retained-failure", "dep-kernel-oracle", "dep-kernel-curvature", "dep-phylo", "dep-animal", "dep-animal-retained-failure", "dep-spatial", "dep-spatial-corrected", "latent-kernel", "latent-phylo", "latent-animal", "latent-spatial", "latent-phylo-endpoint", "publication", "combinations", "closeout", "self-test")
if (!mode %in% allowed) {
  stop("usage: Rscript --vanilla dev/temporal-program/verify.R {plan|simulation|lifecycle|remote|phylo|dep-kernel|dep-kernel-retained-failure|dep-kernel-oracle|dep-kernel-curvature|dep-phylo|dep-animal|dep-animal-retained-failure|dep-spatial|dep-spatial-corrected|latent-kernel|latent-phylo|latent-animal|latent-spatial|latent-phylo-endpoint|publication|combinations|closeout|self-test}", call. = FALSE)
}

.temporal_program_verify_dep_kernel_oracle <- function(root) {
  evidence_dir <- file.path(root, "dev", "temporal-program", "results",
    "diagnostics", "dep-kernel-retained-oracle-20260911")
  seeds <- 2609221:2609223
  points <- c("fitted", "kernel_1_plus_0.075", "kernel_2_plus_0.075")
  oracle_script <- file.path(root, "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R")
  if (!file.exists(oracle_script)) {
    stop("missing retained temporal dep-kernel oracle implementation", call. = FALSE)
  }
  oracle_env <- new.env(parent = globalenv())
  sys.source(oracle_script, envir = oracle_env)
  make_table <- get(".temporal_dep_kernel_retained_oracle_table", envir = oracle_env)
  if (!dir.exists(evidence_dir)) {
    stop("missing retained temporal dep-kernel oracle evidence directory", call. = FALSE)
  }
  reports <- lapply(seeds, function(seed) {
    stem <- paste0("dep-kernel-retained-oracle-v1-", seed)
    csv_path <- file.path(evidence_dir, paste0(stem, ".csv"))
    rds_path <- file.path(evidence_dir, paste0(stem, ".rds"))
    if (!file.exists(csv_path) || !file.exists(rds_path)) {
      stop("missing paired retained temporal dep-kernel oracle receipt for seed ", seed,
        call. = FALSE)
    }
    csv <- utils::read.csv(csv_path, stringsAsFactors = FALSE)
    report <- readRDS(rds_path)
    runtime <- if (is.list(report$receipt)) report$receipt$runtime else NULL
    runtime_values <- if (is.list(runtime)) {
      unlist(runtime[c("frozen_elapsed_seconds", "rehydrated_elapsed_seconds")], use.names = FALSE)
    } else numeric()
    if (!is.list(report) ||
        !identical(report$schema_version, "temporal-dep-kernel-retained-oracle-v1") ||
        !identical(as.integer(report$seed), as.integer(seed)) ||
        !identical(as.numeric(report$phi), .6) ||
        !identical(as.integer(report$n_series), 80L) ||
        !identical(as.integer(report$n_time), 16L) ||
        !identical(as.integer(report$n_observation), 7680L) ||
        !is.list(report$receipt) || !is.data.frame(report$receipt$expected) ||
        !is.data.frame(report$receipt$observed) || nrow(report$receipt$expected) != 1L ||
        nrow(report$receipt$observed) != 1L || !is.list(runtime) ||
        !identical(runtime$comparable, FALSE) || length(runtime_values) != 2L ||
        any(!is.finite(runtime_values)) || any(runtime_values < 0) ||
        !is.numeric(report$outer_parameter) || length(report$outer_parameter) != 14L ||
        !identical(names(report$records), points)) {
      stop("invalid retained temporal dep-kernel oracle RDS receipt for seed ", seed,
        call. = FALSE)
    }
    expected_csv <- make_table(report)
    if (!isTRUE(all.equal(csv, expected_csv, check.attributes = FALSE, tolerance = 1e-12)) ||
        !all(c("schema_version", "seed", "phi", "point", "kind", "coordinate",
        "native", "oracle", "absolute_error", "elapsed_seconds") %in% names(csv)) ||
        nrow(csv) != 45L || !all(csv$schema_version == report$schema_version) ||
        !all(csv$seed == seed) || !all(csv$phi == .6) ||
        !setequal(csv$point, points) || sum(csv$kind == "nll") != 3L ||
        sum(csv$kind == "gradient") != 42L || any(!is.finite(csv$absolute_error)) ||
        any(!is.finite(csv$elapsed_seconds)) || any(csv$elapsed_seconds < 0) ||
        any(csv$absolute_error[csv$kind == "nll"] > 1e-6) ||
        any(csv$absolute_error[csv$kind == "gradient"] > 5e-5)) {
      stop("invalid retained temporal dep-kernel oracle CSV receipt for seed ", seed,
        call. = FALSE)
    }
    report
  })
  invisible(reports)
}

.temporal_program_verify_dep_kernel_curvature <- function(root) {
  evidence_dir <- file.path(root, "dev", "temporal-program", "results",
    "diagnostics", "dep-kernel-retained-curvature-final-20260911")
  seeds <- 2609221:2609223
  coordinate <- c(paste0("kernel_", 1:3), "theta_temporal_time",
    paste0("theta_temporal_rr_", 1:6))
  receipt_path <- file.path(root, "dev", "temporal-program", "results",
    "dep-kernel-recovery-20260911.csv")
  receipt_required <- c("phi", "seed", "terminal", "convergence", "pass_1_convergence",
    "pass_2_convergence", "pass_2_accepted", "max_gradient", "objective",
    "hessian_status", "phi_estimate", "temporal_frobenius_relative_error",
    "kernel_1", "kernel_2", "kernel_3", "beta_1", "beta_2", "beta_3",
    "kernel_relative_error_1", "kernel_relative_error_2", "kernel_relative_error_3",
    "phi_absolute_error", "fixed_effect_mean_absolute_error", "elapsed_seconds")
  frozen_receipt <- if (file.exists(receipt_path)) {
    utils::read.csv(receipt_path, stringsAsFactors = FALSE)
  } else NULL
  oracle_script <- file.path(root, "dev", "temporal-program",
    "verify-dep-kernel-retained-oracle.R")
  curvature_script <- file.path(root, "dev", "temporal-program",
    "diagnose-dep-kernel-retained-curvature.R")
  if (!file.exists(oracle_script) || !file.exists(curvature_script) || !dir.exists(evidence_dir)) {
    stop("missing retained temporal dep-kernel curvature implementation or evidence", call. = FALSE)
  }
  lapply(seeds, function(seed) {
    path <- file.path(evidence_dir,
      paste0("dep-kernel-retained-curvature-v1-", seed, ".rds"))
    if (!file.exists(path)) {
      stop("missing retained temporal dep-kernel curvature receipt for seed ", seed,
        call. = FALSE)
    }
    output <- readRDS(path)
    identity <- output$receipt_identity
    one <- output$report
    receipt <- if (is.list(one)) one$receipt else NULL
    runtime <- if (is.list(receipt)) receipt$runtime else NULL
    runtime_values <- if (is.list(runtime)) {
      unlist(runtime[c("frozen_elapsed_seconds", "rehydrated_elapsed_seconds")], use.names = FALSE)
    } else numeric()
    frozen_row <- if (is.data.frame(frozen_receipt) &&
      all(receipt_required %in% names(frozen_receipt))) {
      frozen_receipt[frozen_receipt$phi == .6 & frozen_receipt$seed == seed,
        receipt_required, drop = FALSE]
    } else data.frame()
    exact_receipt <- c("phi", "seed", "terminal", "convergence", "pass_1_convergence",
      "pass_2_convergence", "pass_2_accepted", "hessian_status")
    numeric_receipt <- setdiff(receipt_required, c(exact_receipt, "elapsed_seconds"))
    receipt_matches <- is.data.frame(receipt$expected) && is.data.frame(receipt$observed) &&
      nrow(frozen_row) == 1L && nrow(receipt$expected) == 1L &&
      nrow(receipt$observed) == 1L &&
      isTRUE(all.equal(receipt$expected[, receipt_required, drop = FALSE], frozen_row,
        check.attributes = FALSE, tolerance = 0)) &&
      identical(as.character(unlist(receipt$observed[exact_receipt], use.names = FALSE)),
        as.character(unlist(frozen_row[exact_receipt], use.names = FALSE))) &&
      all(abs(as.numeric(receipt$observed[numeric_receipt]) -
        as.numeric(frozen_row[numeric_receipt])) <= 2e-5)
    if (!is.list(output) ||
        !identical(output$schema_version, "temporal-dep-kernel-retained-curvature-v1") ||
        !identical(as.integer(output$seed), as.integer(seed)) ||
        !identical(as.integer(output$n_series), 80L) ||
        !identical(as.integer(output$n_time), 16L) ||
        !identical(as.integer(output$n_observation), 7680L) ||
        !is.list(identity) || !identical(as.integer(identity$frozen_seed), as.integer(seed)) ||
        !identical(as.integer(identity$rehydrated_seed), as.integer(seed)) ||
        !identical(as.numeric(identity$frozen_phi), .6) ||
        !identical(as.numeric(identity$rehydrated_phi), .6) ||
        !identical(identity$terminal, "success") ||
        !is.list(one) || !identical(as.integer(one$seed), as.integer(seed)) ||
        !is.list(receipt) || !receipt_matches || !is.list(runtime) ||
        !identical(output$contract, paste("Curvature/conditioning diagnostic only; no optimiser intervention,",
          "recovery, calibration, or numerical-remedy claim.")) ||
        !identical(runtime$comparable, FALSE) || length(runtime_values) != 2L ||
        any(!is.finite(runtime_values)) || any(runtime_values < 0) ||
        !identical(as.integer(receipt$expected$seed[[1L]]), as.integer(seed)) ||
        !identical(as.integer(receipt$observed$seed[[1L]]), as.integer(seed)) ||
        !identical(as.numeric(receipt$expected$phi[[1L]]), .6) ||
        !identical(as.numeric(receipt$observed$phi[[1L]]), .6) ||
        !identical(as.character(receipt$expected$terminal[[1L]]), "success") ||
        !identical(as.character(receipt$observed$terminal[[1L]]), "success")) {
      stop("invalid retained temporal dep-kernel curvature identity for seed ", seed,
        call. = FALSE)
    }
    for (point_name in c("truth", "rehydrated")) {
      point <- one[[point_name]]
      if (!is.list(point) || !identical(point$point, point_name) ||
          !identical(names(point$coordinate), coordinate) ||
          !identical(names(point$curvature), coordinate) ||
          !identical(dim(point$observed_information), c(10L, 10L)) ||
          !identical(dimnames(point$observed_information), list(coordinate, coordinate)) ||
          any(!is.finite(point$gradient)) || any(!is.finite(point$curvature)) ||
          any(!is.finite(point$observed_information)) ||
          !isTRUE(all.equal(point$observed_information,
            t(point$observed_information), tolerance = 1e-10)) ||
          !isTRUE(point$information_positive_definite) ||
          !is.finite(point$information_condition) || point$information_condition <= 0 ||
          !identical(point$correlation_status, "observed_information_inverse") ||
          !identical(dim(point$parameter_correlation), c(10L, 10L)) ||
          !identical(dimnames(point$parameter_correlation), list(coordinate, coordinate)) ||
          any(!is.finite(point$parameter_correlation)) ||
          !isTRUE(all.equal(point$parameter_correlation, t(point$parameter_correlation), tolerance = 1e-10)) ||
          !isTRUE(all.equal(unname(diag(point$parameter_correlation)), rep(1, 10), tolerance = 1e-10))) {
        stop("invalid retained temporal dep-kernel curvature point ", point_name,
          " for seed ", seed, call. = FALSE)
      }
    }
    if (max(abs(one$rehydrated$gradient)) > 1e-3) {
      stop("rehydrated temporal dep-kernel curvature gradient exceeds frozen fit tolerance for seed ",
        seed, call. = FALSE)
    }
    output
  })
  invisible(TRUE)
}

.temporal_program_assert_test_results <- function(result, fixture) {
  summary <- as.data.frame(result)
  required <- c("failed", "error", "warning", "skipped")
  if (!all(required %in% names(summary)) || nrow(summary) == 0L) {
    stop("temporal programme verifier ran zero assertions: ", fixture, call. = FALSE)
  }
  if (any(summary$failed > 0L | summary$error > 0L |
          summary$warning > 0L | summary$skipped)) {
    stop("temporal programme verifier found a failed, errored, warned, or skipped assertion: ", fixture, call. = FALSE)
  }
  invisible(summary)
}

.temporal_program_expect_reject <- function(expr, label) {
  rejected <- inherits(try(force(expr), silent = TRUE), "try-error")
  if (!rejected) stop("temporal programme verifier did not reject ", label, call. = FALSE)
  invisible(TRUE)
}

.temporal_program_kernel_summary <- function(results) {
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609151:2609153
  required <- c(
    "phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "temporal_relative_error_1",
    "temporal_relative_error_2", "temporal_relative_error_3",
    "kernel_relative_error_1", "kernel_relative_error_2",
    "kernel_relative_error_3", "phi_absolute_error",
    "fixed_effect_mean_absolute_error"
  )
  if (!all(required %in% names(results)) || nrow(results) != 9L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal-kernel recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  if (!all(strict)) {
    stop("temporal-kernel recovery has a retained terminal or final-pass failure", call. = FALSE)
  }
  do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]
    data.frame(
      phi = phi, attempts = nrow(x), strict_successes = sum(strict[results$phi == phi]),
      mean_phi_absolute_error = mean(x$phi_absolute_error),
      median_phi_absolute_error = stats::median(x$phi_absolute_error),
      median_temporal_1_relative_error = stats::median(x$temporal_relative_error_1),
      median_temporal_2_relative_error = stats::median(x$temporal_relative_error_2),
      median_temporal_3_relative_error = stats::median(x$temporal_relative_error_3),
      median_kernel_1_relative_error = stats::median(x$kernel_relative_error_1),
      median_kernel_2_relative_error = stats::median(x$kernel_relative_error_2),
      median_kernel_3_relative_error = stats::median(x$kernel_relative_error_3),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error),
      stringsAsFactors = FALSE
    )
  }))
}

.temporal_program_validate_kernel_summary <- function(results, summary) {
  recomputed <- .temporal_program_kernel_summary(results)
  required <- names(recomputed)
  if (!all(required %in% names(summary)) || nrow(summary) != nrow(recomputed) ||
      !setequal(summary$phi, recomputed$phi)) {
    stop("temporal-kernel recovery summary has an invalid schema or phi labels", call. = FALSE)
  }
  summary <- summary[match(recomputed$phi, summary$phi), required, drop = FALSE]
  for (nm in setdiff(required, "phi")) {
    if (any(!is.finite(summary[[nm]])) ||
        !isTRUE(all.equal(summary[[nm]], recomputed[[nm]], tolerance = 1e-10))) {
      stop("temporal-kernel recovery summary is stale or disagrees with retained attempts: ", nm,
        call. = FALSE)
    }
  }
  invisible(recomputed)
}

.temporal_program_dep_kernel_summary <- function(results) {
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609221:2609223
  required <- c("phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "objective", "hessian_status", "temporal_frobenius_relative_error",
    "kernel_relative_error_1", "kernel_relative_error_2", "kernel_relative_error_3",
    "phi_absolute_error", "fixed_effect_mean_absolute_error")
  if (!all(required %in% names(results)) || nrow(results) != 9L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal dep-kernel recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$objective) & is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]
    keep <- strict[results$phi == phi]
    data.frame(phi = phi, attempts = nrow(x), strict_successes = sum(keep),
      mean_phi_absolute_error = mean(x$phi_absolute_error[keep]),
      median_phi_absolute_error = stats::median(x$phi_absolute_error[keep]),
      median_temporal_frobenius_relative_error = stats::median(x$temporal_frobenius_relative_error[keep]),
      median_kernel_1_relative_error = stats::median(x$kernel_relative_error_1[keep]),
      median_kernel_2_relative_error = stats::median(x$kernel_relative_error_2[keep]),
      median_kernel_3_relative_error = stats::median(x$kernel_relative_error_3[keep]),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[keep]),
      stringsAsFactors = FALSE)
  }))
}

.temporal_program_validate_dep_kernel_summary <- function(results, summary) {
  recomputed <- .temporal_program_dep_kernel_summary(results)
  required <- names(recomputed)
  if (!all(required %in% names(summary)) || nrow(summary) != nrow(recomputed) ||
      !setequal(summary$phi, recomputed$phi)) {
    stop("temporal dep-kernel recovery summary has an invalid schema or phi labels", call. = FALSE)
  }
  summary <- summary[match(recomputed$phi, summary$phi), required, drop = FALSE]
  for (nm in setdiff(required, "phi")) {
    if (any(!is.finite(summary[[nm]])) ||
        !isTRUE(all.equal(summary[[nm]], recomputed[[nm]], tolerance = 1e-10))) {
      stop("temporal dep-kernel recovery summary is stale or disagrees with retained attempts: ", nm,
        call. = FALSE)
    }
  }
  invisible(recomputed)
}


.temporal_program_dep_phylo_summary <- function(results) {
  expected_phi <- c(-.4, 0, .6); expected_seed <- 2609291:2609293
  required <- c("phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "objective", "hessian_status", "temporal_frobenius_relative_error",
    "phylo_relative_error_1", "phylo_relative_error_2", "phylo_relative_error_3",
    "phi_absolute_error", "fixed_effect_mean_absolute_error")
  if (!all(required %in% names(results)) || nrow(results) != 9L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1))))
    stop("temporal dep-phylo recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$objective) & is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]; keep <- strict[results$phi == phi]
    data.frame(phi = phi, attempts = nrow(x), strict_successes = sum(keep),
      mean_phi_absolute_error = mean(x$phi_absolute_error[keep]),
      median_phi_absolute_error = stats::median(x$phi_absolute_error[keep]),
      median_temporal_frobenius_relative_error = stats::median(x$temporal_frobenius_relative_error[keep]),
      median_phylo_1_relative_error = stats::median(x$phylo_relative_error_1[keep]),
      median_phylo_2_relative_error = stats::median(x$phylo_relative_error_2[keep]),
      median_phylo_3_relative_error = stats::median(x$phylo_relative_error_3[keep]),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[keep]), stringsAsFactors = FALSE)
  }))
}

.temporal_program_validate_dep_phylo_summary <- function(results, summary) {
  recomputed <- .temporal_program_dep_phylo_summary(results); required <- names(recomputed)
  if (!all(required %in% names(summary)) || nrow(summary) != nrow(recomputed) || !setequal(summary$phi, recomputed$phi))
    stop("temporal dep-phylo recovery summary has an invalid schema or phi labels", call. = FALSE)
  summary <- summary[match(recomputed$phi, summary$phi), required, drop = FALSE]
  for (nm in setdiff(required, "phi")) if (any(!is.finite(summary[[nm]])) ||
      !isTRUE(all.equal(summary[[nm]], recomputed[[nm]], tolerance = 1e-10)))
    stop("temporal dep-phylo recovery summary is stale or disagrees with retained attempts: ", nm, call. = FALSE)
  invisible(recomputed)
}

.temporal_program_latent_kernel_summary <- function(results) {
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609231:2609233
  required <- c("phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "objective", "hessian_status", "temporal_frobenius_relative_error",
    "kernel_relative_error_1", "kernel_relative_error_2", "kernel_relative_error_3",
    "phi_absolute_error", "fixed_effect_mean_absolute_error")
  if (!all(required %in% names(results)) || nrow(results) != 9L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal latent-kernel recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$objective) & is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]
    keep <- strict[results$phi == phi]
    data.frame(phi = phi, attempts = nrow(x), strict_successes = sum(keep),
      mean_phi_absolute_error = mean(x$phi_absolute_error[keep]),
      median_phi_absolute_error = stats::median(x$phi_absolute_error[keep]),
      median_temporal_frobenius_relative_error = stats::median(x$temporal_frobenius_relative_error[keep]),
      median_kernel_1_relative_error = stats::median(x$kernel_relative_error_1[keep]),
      median_kernel_2_relative_error = stats::median(x$kernel_relative_error_2[keep]),
      median_kernel_3_relative_error = stats::median(x$kernel_relative_error_3[keep]),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[keep]), stringsAsFactors = FALSE)
  }))
}

.temporal_program_validate_latent_kernel_summary <- function(results, summary) {
  recomputed <- .temporal_program_latent_kernel_summary(results)
  required <- names(recomputed)
  if (!all(required %in% names(summary)) || nrow(summary) != nrow(recomputed) ||
      !setequal(summary$phi, recomputed$phi)) {
    stop("temporal latent-kernel recovery summary has an invalid schema or phi labels", call. = FALSE)
  }
  summary <- summary[match(recomputed$phi, summary$phi), required, drop = FALSE]
  for (nm in setdiff(required, "phi")) {
    if (any(!is.finite(summary[[nm]])) ||
        !isTRUE(all.equal(summary[[nm]], recomputed[[nm]], tolerance = 1e-10))) {
      stop("temporal latent-kernel recovery summary is stale or disagrees with retained attempts: ", nm,
        call. = FALSE)
    }
  }
  invisible(recomputed)
}

.temporal_program_latent_phylo_summary <- function(results) {
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609241:2609243
  required <- c("phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "objective", "hessian_status", "temporal_frobenius_relative_error",
    "phylo_relative_error_1", "phylo_relative_error_2", "phylo_relative_error_3",
    "phi_absolute_error", "fixed_effect_mean_absolute_error")
  if (!all(required %in% names(results)) || nrow(results) != 9L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal latent-phylo recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$objective) & is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]
    keep <- strict[results$phi == phi]
    data.frame(phi = phi, attempts = nrow(x), strict_successes = sum(keep),
      mean_phi_absolute_error = mean(x$phi_absolute_error[keep]),
      median_phi_absolute_error = stats::median(x$phi_absolute_error[keep]),
      median_temporal_frobenius_relative_error = stats::median(x$temporal_frobenius_relative_error[keep]),
      median_phylo_1_relative_error = stats::median(x$phylo_relative_error_1[keep]),
      median_phylo_2_relative_error = stats::median(x$phylo_relative_error_2[keep]),
      median_phylo_3_relative_error = stats::median(x$phylo_relative_error_3[keep]),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[keep]), stringsAsFactors = FALSE)
  }))
}

.temporal_program_validate_latent_phylo_summary <- function(results, summary) {
  recomputed <- .temporal_program_latent_phylo_summary(results)
  required <- names(recomputed)
  if (!all(required %in% names(summary)) || nrow(summary) != nrow(recomputed) ||
      !setequal(summary$phi, recomputed$phi)) {
    stop("temporal latent-phylo recovery summary has an invalid schema or phi labels", call. = FALSE)
  }
  summary <- summary[match(recomputed$phi, summary$phi), required, drop = FALSE]
  for (nm in setdiff(required, "phi")) {
    if (any(!is.finite(summary[[nm]])) ||
        !isTRUE(all.equal(summary[[nm]], recomputed[[nm]], tolerance = 1e-10))) {
      stop("temporal latent-phylo recovery summary is stale or disagrees with retained attempts: ", nm,
        call. = FALSE)
    }
  }
  invisible(recomputed)
}

.temporal_program_latent_animal_summary <- function(results) {
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609251:2609253
  required <- c("phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "objective", "hessian_status", "temporal_frobenius_relative_error",
    "animal_relative_error_1", "animal_relative_error_2", "animal_relative_error_3",
    "phi_absolute_error", "fixed_effect_mean_absolute_error")
  if (!all(required %in% names(results)) || nrow(results) != 9L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal latent-animal recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$objective) & is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]
    keep <- strict[results$phi == phi]
    data.frame(phi = phi, attempts = nrow(x), strict_successes = sum(keep),
      mean_phi_absolute_error = mean(x$phi_absolute_error[keep]),
      median_phi_absolute_error = stats::median(x$phi_absolute_error[keep]),
      median_temporal_frobenius_relative_error = stats::median(x$temporal_frobenius_relative_error[keep]),
      median_animal_1_relative_error = stats::median(x$animal_relative_error_1[keep]),
      median_animal_2_relative_error = stats::median(x$animal_relative_error_2[keep]),
      median_animal_3_relative_error = stats::median(x$animal_relative_error_3[keep]),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[keep]), stringsAsFactors = FALSE)
  }))
}

.temporal_program_validate_latent_animal_summary <- function(results, summary) {
  recomputed <- .temporal_program_latent_animal_summary(results)
  required <- names(recomputed)
  if (!all(required %in% names(summary)) || nrow(summary) != nrow(recomputed) ||
      !setequal(summary$phi, recomputed$phi)) {
    stop("temporal latent-animal recovery summary has an invalid schema or phi labels", call. = FALSE)
  }
  summary <- summary[match(recomputed$phi, summary$phi), required, drop = FALSE]
  for (nm in setdiff(required, "phi")) {
    if (any(!is.finite(summary[[nm]])) ||
        !isTRUE(all.equal(summary[[nm]], recomputed[[nm]], tolerance = 1e-10))) {
      stop("temporal latent-animal recovery summary is stale or disagrees with retained attempts: ", nm,
        call. = FALSE)
    }
  }
  invisible(recomputed)
}


.temporal_program_latent_spatial_summary <- function(results) {
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609261:2609263
  required <- c("phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "objective", "temporal_frobenius_relative_error",
    "tau_relative_error_1", "tau_relative_error_2", "tau_relative_error_3", "kappa_relative_error",
    "phi_absolute_error", "fixed_effect_mean_absolute_error")
  if (!all(required %in% names(results)) || nrow(results) != 9L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal latent-spatial recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$objective) & is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]
    keep <- strict[results$phi == phi]
    data.frame(phi = phi, attempts = nrow(x), strict_successes = sum(keep),
      mean_phi_absolute_error = mean(x$phi_absolute_error[keep]),
      median_phi_absolute_error = stats::median(x$phi_absolute_error[keep]),
      median_temporal_frobenius_relative_error = stats::median(x$temporal_frobenius_relative_error[keep]),
      median_tau_1_relative_error = stats::median(x$tau_relative_error_1[keep]),
      median_tau_2_relative_error = stats::median(x$tau_relative_error_2[keep]),
      median_tau_3_relative_error = stats::median(x$tau_relative_error_3[keep]),
      median_kappa_relative_error = stats::median(x$kappa_relative_error[keep]),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[keep]), stringsAsFactors = FALSE)
  }))
}

.temporal_program_validate_latent_spatial_summary <- function(results, summary) {
  recomputed <- .temporal_program_latent_spatial_summary(results)
  required <- names(recomputed)
  if (!all(required %in% names(summary)) || nrow(summary) != nrow(recomputed) ||
      !setequal(summary$phi, recomputed$phi)) {
    stop("temporal latent-spatial recovery summary has an invalid schema or phi labels", call. = FALSE)
  }
  summary <- summary[match(recomputed$phi, summary$phi), required, drop = FALSE]
  for (nm in setdiff(required, "phi")) {
    if (any(!is.finite(summary[[nm]])) ||
        !isTRUE(all.equal(summary[[nm]], recomputed[[nm]], tolerance = 1e-10))) {
      stop("temporal latent-spatial recovery summary is stale or disagrees with retained attempts: ", nm,
        call. = FALSE)
    }
  }
  invisible(recomputed)
}

.temporal_program_dep_spatial_summary <- function(results) {
  expected_phi <- c(-.4, 0, .6); expected_seed <- 2609331:2609333
  required <- c("phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "objective", "temporal_frobenius_relative_error",
    "tau_relative_error_1", "tau_relative_error_2", "tau_relative_error_3", "kappa_relative_error",
    "phi_absolute_error", "fixed_effect_mean_absolute_error")
  if (!all(required %in% names(results)) || nrow(results) != 9L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal dep-spatial recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$objective) & is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]; keep <- strict[results$phi == phi]
    data.frame(phi = phi, attempts = nrow(x), strict_successes = sum(keep),
      mean_phi_absolute_error = mean(x$phi_absolute_error[keep]),
      median_phi_absolute_error = stats::median(x$phi_absolute_error[keep]),
      median_temporal_frobenius_relative_error = stats::median(x$temporal_frobenius_relative_error[keep]),
      median_tau_1_relative_error = stats::median(x$tau_relative_error_1[keep]),
      median_tau_2_relative_error = stats::median(x$tau_relative_error_2[keep]),
      median_tau_3_relative_error = stats::median(x$tau_relative_error_3[keep]),
      median_kappa_relative_error = stats::median(x$kappa_relative_error[keep]),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[keep]), stringsAsFactors = FALSE)
  }))
}

.temporal_program_validate_dep_spatial_summary <- function(results, summary) {
  recomputed <- .temporal_program_dep_spatial_summary(results); required <- names(recomputed)
  if (!all(required %in% names(summary)) || nrow(summary) != nrow(recomputed) || !setequal(summary$phi, recomputed$phi))
    stop("temporal dep-spatial recovery summary has an invalid schema or phi labels", call. = FALSE)
  summary <- summary[match(recomputed$phi, summary$phi), required, drop = FALSE]
  for (nm in setdiff(required, "phi")) if (any(!is.finite(summary[[nm]])) ||
      !isTRUE(all.equal(summary[[nm]], recomputed[[nm]], tolerance = 1e-10)))
    stop("temporal dep-spatial recovery summary is stale or disagrees with retained attempts: ", nm, call. = FALSE)
  invisible(recomputed)
}

.temporal_program_phylo_summary <- function(results) {
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609181:2609190
  required <- c(
    "phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "phi_estimate",
    paste0("temporal_", 1:3), paste0("phylo_", 1:3), paste0("beta_", 1:3)
  )
  if (!all(required %in% names(results)) || nrow(results) != 30L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal-phylo recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  if (!all(strict)) {
    stop("temporal-phylo recovery has a retained terminal or final-pass failure", call. = FALSE)
  }
  truth <- list(beta = c(.2, -.3, .1), temporal = c(.55, .42, .63)^2,
    phylo = c(.35, .28, .40)^2)
  for (j in 1:3) {
    results[[paste0("temporal_relative_error_", j)]] <-
      abs(results[[paste0("temporal_", j)]] - truth$temporal[[j]]) / truth$temporal[[j]]
    results[[paste0("phylo_relative_error_", j)]] <-
      abs(results[[paste0("phylo_", j)]] - truth$phylo[[j]]) / truth$phylo[[j]]
  }
  results$phi_absolute_error <- abs(results$phi_estimate - results$phi)
  results$fixed_effect_mean_absolute_error <- vapply(seq_len(nrow(results)), function(i) {
    mean(abs(as.numeric(results[i, paste0("beta_", 1:3)]) - truth$beta))
  }, numeric(1))
  summary <- do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]
    data.frame(
      phi = phi, attempts = nrow(x), strict_successes = sum(strict[results$phi == phi]),
      mean_phi_absolute_error = mean(x$phi_absolute_error),
      median_phi_absolute_error = stats::median(x$phi_absolute_error),
      median_temporal_1_relative_error = stats::median(x$temporal_relative_error_1),
      median_temporal_2_relative_error = stats::median(x$temporal_relative_error_2),
      median_temporal_3_relative_error = stats::median(x$temporal_relative_error_3),
      median_phylo_1_relative_error = stats::median(x$phylo_relative_error_1),
      median_phylo_2_relative_error = stats::median(x$phylo_relative_error_2),
      median_phylo_3_relative_error = stats::median(x$phylo_relative_error_3),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error),
      stringsAsFactors = FALSE
    )
  }))
  summary$passes <- with(summary,
    strict_successes == 10L & mean_phi_absolute_error <= .15 &
      median_phi_absolute_error <= .20 &
      median_temporal_1_relative_error <= .35 & median_temporal_2_relative_error <= .35 &
      median_temporal_3_relative_error <= .35 & median_phylo_1_relative_error <= .35 &
      median_phylo_2_relative_error <= .35 & median_phylo_3_relative_error <= .35 &
      mean_fixed_effect_error <= .25)
  summary
}

.temporal_program_validate_phylo_summary <- function(results, summary) {
  recomputed <- .temporal_program_phylo_summary(results)
  required <- names(recomputed)
  if (!all(required %in% names(summary)) || nrow(summary) != nrow(recomputed) ||
      !setequal(summary$phi, recomputed$phi)) {
    stop("temporal-phylo recovery summary has an invalid schema or phi labels", call. = FALSE)
  }
  summary <- summary[match(recomputed$phi, summary$phi), required, drop = FALSE]
  for (nm in setdiff(required, "phi")) {
    if (any(is.na(summary[[nm]])) ||
        !isTRUE(all.equal(summary[[nm]], recomputed[[nm]], tolerance = 1e-10))) {
      stop("temporal-phylo recovery summary is stale or disagrees with retained attempts: ", nm,
        call. = FALSE)
    }
  }
  invisible(recomputed)
}

.temporal_program_verify_phylo <- function(root) {
  fixture <- "tests/testthat/test-temporal-program-phylo-replicated.R"
  result_path <- paste0(
    "dev/temporal-program/results/failed/",
    "phylo-recovery-160-fir-59096255-20260910/",
    "phylo-recovery-160-20260909.csv"
  )
  summary_path <- paste0(
    "dev/temporal-program/results/failed/",
    "phylo-recovery-160-fir-59096255-20260910/",
    "phylo-recovery-160-summary-20260909.csv"
  )
  required <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing temporal-phylo evidence: ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  recomputed <- .temporal_program_validate_phylo_summary(results, summary)
  if (!all(recomputed$passes)) {
    stop("temporal-phylo recovery exceeds a frozen summary threshold", call. = FALSE)
  }
  invisible(recomputed)
}

if (identical(mode, "self-test")) {
  base <- data.frame(failed = 0L, error = 0L, warning = 0L, skipped = FALSE)
  .temporal_program_expect_reject(
    .temporal_program_assert_test_results(base[FALSE, , drop = FALSE], "self-test"),
    "zero assertions"
  )
  for (field in names(base)) {
    bad <- base
    bad[[field]] <- if (identical(field, "skipped")) TRUE else 1L
    .temporal_program_expect_reject(
      .temporal_program_assert_test_results(bad, "self-test"),
      paste0("a ", field, " result")
    )
  }
  synthetic <- expand.grid(phi = c(-.4, 0, .6), seed = 2609151:2609153)
  synthetic$terminal <- "success"; synthetic$convergence <- 0L
  synthetic$pass_2_convergence <- 0L; synthetic$pass_2_accepted <- TRUE
  synthetic$max_gradient <- 0
  for (nm in c("temporal_relative_error_1", "temporal_relative_error_2",
               "temporal_relative_error_3", "kernel_relative_error_1",
               "kernel_relative_error_2", "kernel_relative_error_3",
               "phi_absolute_error", "fixed_effect_mean_absolute_error")) {
    synthetic[[nm]] <- .1
  }
  synthetic_summary <- .temporal_program_kernel_summary(synthetic)
  .temporal_program_validate_kernel_summary(synthetic, synthetic_summary)
  stale_summary <- synthetic_summary
  stale_summary$mean_phi_absolute_error[[1L]] <- .2
  .temporal_program_expect_reject(
    .temporal_program_validate_kernel_summary(synthetic, stale_summary),
    "a stale kernel-recovery summary"
  )
  dep_synthetic <- expand.grid(phi = c(-.4, 0, .6), seed = 2609221:2609223)
  dep_synthetic$terminal <- "success"; dep_synthetic$convergence <- 0L
  dep_synthetic$pass_2_convergence <- 0L; dep_synthetic$pass_2_accepted <- TRUE
  dep_synthetic$max_gradient <- 0; dep_synthetic$objective <- 1
  dep_synthetic$hessian_status <- "positive_definite"
  for (nm in c("temporal_frobenius_relative_error", "kernel_relative_error_1",
    "kernel_relative_error_2", "kernel_relative_error_3", "phi_absolute_error",
    "fixed_effect_mean_absolute_error")) dep_synthetic[[nm]] <- .1
  dep_summary <- .temporal_program_dep_kernel_summary(dep_synthetic)
  .temporal_program_validate_dep_kernel_summary(dep_synthetic, dep_summary)
  .temporal_program_expect_reject(
    .temporal_program_dep_kernel_summary(dep_synthetic[-1L, , drop = FALSE]),
    "an incomplete temporal dep-kernel recovery receipt"
  )
  dep_phylo_synthetic <- expand.grid(phi = c(-.4, 0, .6), seed = 2609291:2609293)
  dep_phylo_synthetic$terminal <- "success"; dep_phylo_synthetic$convergence <- 0L
  dep_phylo_synthetic$pass_2_convergence <- 0L; dep_phylo_synthetic$pass_2_accepted <- TRUE
  dep_phylo_synthetic$max_gradient <- 0; dep_phylo_synthetic$objective <- 1
  dep_phylo_synthetic$hessian_status <- "positive_definite"
  for (nm in c("temporal_frobenius_relative_error", "phylo_relative_error_1",
    "phylo_relative_error_2", "phylo_relative_error_3", "phi_absolute_error",
    "fixed_effect_mean_absolute_error")) dep_phylo_synthetic[[nm]] <- .1
  dep_phylo_summary <- .temporal_program_dep_phylo_summary(dep_phylo_synthetic)
  .temporal_program_validate_dep_phylo_summary(dep_phylo_synthetic, dep_phylo_summary)
  .temporal_program_expect_reject(.temporal_program_dep_phylo_summary(dep_phylo_synthetic[-1L, , drop = FALSE]),
    "an incomplete temporal dep-phylo recovery receipt")
  latent_synthetic <- expand.grid(phi = c(-.4, 0, .6), seed = 2609231:2609233)
  latent_synthetic$terminal <- "success"; latent_synthetic$convergence <- 0L
  latent_synthetic$pass_2_convergence <- 0L; latent_synthetic$pass_2_accepted <- TRUE
  latent_synthetic$max_gradient <- 0; latent_synthetic$objective <- 1
  latent_synthetic$hessian_status <- "positive_definite"
  for (nm in c("temporal_frobenius_relative_error", "kernel_relative_error_1",
    "kernel_relative_error_2", "kernel_relative_error_3", "phi_absolute_error",
    "fixed_effect_mean_absolute_error")) latent_synthetic[[nm]] <- .1
  latent_summary <- .temporal_program_latent_kernel_summary(latent_synthetic)
  .temporal_program_validate_latent_kernel_summary(latent_synthetic, latent_summary)
  .temporal_program_expect_reject(
    .temporal_program_latent_kernel_summary(latent_synthetic[-1L, , drop = FALSE]),
    "an incomplete temporal latent-kernel recovery receipt"
  )
  latent_phylo_synthetic <- expand.grid(phi = c(-.4, 0, .6), seed = 2609241:2609243)
  latent_phylo_synthetic$terminal <- "success"; latent_phylo_synthetic$convergence <- 0L
  latent_phylo_synthetic$pass_2_convergence <- 0L; latent_phylo_synthetic$pass_2_accepted <- TRUE
  latent_phylo_synthetic$max_gradient <- 0; latent_phylo_synthetic$objective <- 1
  latent_phylo_synthetic$hessian_status <- "positive_definite"
  for (nm in c("temporal_frobenius_relative_error", "phylo_relative_error_1",
    "phylo_relative_error_2", "phylo_relative_error_3", "phi_absolute_error",
    "fixed_effect_mean_absolute_error")) latent_phylo_synthetic[[nm]] <- .1
  latent_phylo_summary <- .temporal_program_latent_phylo_summary(latent_phylo_synthetic)
  .temporal_program_validate_latent_phylo_summary(latent_phylo_synthetic, latent_phylo_summary)
  .temporal_program_expect_reject(
    .temporal_program_latent_phylo_summary(latent_phylo_synthetic[-1L, , drop = FALSE]),
    "an incomplete temporal latent-phylo recovery receipt"
  )
  latent_animal_synthetic <- expand.grid(phi = c(-.4, 0, .6), seed = 2609251:2609253)
  latent_animal_synthetic$terminal <- "success"; latent_animal_synthetic$convergence <- 0L
  latent_animal_synthetic$pass_2_convergence <- 0L; latent_animal_synthetic$pass_2_accepted <- TRUE
  latent_animal_synthetic$max_gradient <- 0; latent_animal_synthetic$objective <- 1
  latent_animal_synthetic$hessian_status <- "positive_definite"
  for (nm in c("temporal_frobenius_relative_error", "animal_relative_error_1",
    "animal_relative_error_2", "animal_relative_error_3", "phi_absolute_error",
    "fixed_effect_mean_absolute_error")) latent_animal_synthetic[[nm]] <- .1
  latent_animal_summary <- .temporal_program_latent_animal_summary(latent_animal_synthetic)
  .temporal_program_validate_latent_animal_summary(latent_animal_synthetic, latent_animal_summary)
  .temporal_program_expect_reject(
    .temporal_program_latent_animal_summary(latent_animal_synthetic[-1L, , drop = FALSE]),
    "an incomplete temporal latent-animal recovery receipt"
  )
  latent_spatial_synthetic <- expand.grid(phi = c(-.4, 0, .6), seed = 2609261:2609263)
  latent_spatial_synthetic$terminal <- "success"; latent_spatial_synthetic$convergence <- 0L
  latent_spatial_synthetic$pass_2_convergence <- 0L; latent_spatial_synthetic$pass_2_accepted <- TRUE
  latent_spatial_synthetic$max_gradient <- 0; latent_spatial_synthetic$objective <- 1
  for (nm in c("temporal_frobenius_relative_error", "tau_relative_error_1",
    "tau_relative_error_2", "tau_relative_error_3", "kappa_relative_error", "phi_absolute_error",
    "fixed_effect_mean_absolute_error")) latent_spatial_synthetic[[nm]] <- .1
  latent_spatial_summary <- .temporal_program_latent_spatial_summary(latent_spatial_synthetic)
  .temporal_program_validate_latent_spatial_summary(latent_spatial_synthetic, latent_spatial_summary)
  .temporal_program_expect_reject(
    .temporal_program_latent_spatial_summary(latent_spatial_synthetic[-1L, , drop = FALSE]),
    "an incomplete temporal latent-spatial recovery receipt"
  )
  phylo_synthetic <- expand.grid(phi = c(-.4, 0, .6), seed = 2609181:2609190)
  phylo_synthetic$terminal <- "success"; phylo_synthetic$convergence <- 0L
  phylo_synthetic$pass_2_convergence <- 0L; phylo_synthetic$pass_2_accepted <- TRUE
  phylo_synthetic$max_gradient <- 0; phylo_synthetic$phi_estimate <- phylo_synthetic$phi
  for (j in 1:3) {
    phylo_synthetic[[paste0("temporal_", j)]] <- c(.55, .42, .63)[[j]]^2
    phylo_synthetic[[paste0("phylo_", j)]] <- c(.35, .28, .40)[[j]]^2
    phylo_synthetic[[paste0("beta_", j)]] <- c(.2, -.3, .1)[[j]]
  }
  phylo_summary <- .temporal_program_phylo_summary(phylo_synthetic)
  .temporal_program_validate_phylo_summary(phylo_synthetic, phylo_summary)
  .temporal_program_expect_reject(
    .temporal_program_phylo_summary(phylo_synthetic[-1L, , drop = FALSE]),
    "an incomplete phylogenetic recovery receipt"
  )
  stale_phylo_summary <- phylo_summary
  stale_phylo_summary$median_phylo_1_relative_error[[1L]] <- .1
  .temporal_program_expect_reject(
    .temporal_program_validate_phylo_summary(phylo_synthetic, stale_phylo_summary),
    "a stale phylogenetic-recovery summary"
  )
  cat("TEMPORAL_PROGRAM_SELF_TEST_PASS\n")
  quit(save = "no", status = 0L)
}

if (identical(mode, "plan")) {
  required <- c("dev/temporal-program/PLAN.md", ".unlazy/temporal-program/GATES.md")
  missing <- required[!file.exists(file.path(root, required))]
  if (length(missing)) stop("missing programme artifact(s): ", paste(missing, collapse = ", "), call. = FALSE)
  plan <- readLines(file.path(root, "dev/temporal-program/PLAN.md"), warn = FALSE)
  need <- c("## GOAL", "## Frozen model meaning", "## Prior-work sweep receipt", "## Slices and dependencies", "## Acceptance gates", "## Compute")
  if (!all(need %in% plan)) stop("programme plan is missing a required section", call. = FALSE)
  cat("TEMPORAL_PROGRAM_PLAN_PASS\n")
  quit(save = "no", status = 0L)
}

if (identical(mode, "publication")) {
  receipt_path <- path.expand(Sys.getenv("TEMPORAL_PROGRAM_CI_RECEIPT", unset = ""))
  if (!nzchar(receipt_path) || !file.exists(receipt_path)) {
    stop("Publication verification requires TEMPORAL_PROGRAM_CI_RECEIPT pointing to a retained three-OS CI receipt.", call. = FALSE)
  }
  receipt <- readRDS(receipt_path)
  head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]]
  if (!is.list(receipt) ||
      !identical(receipt$schema, "temporal-program-publication-ci-receipt-v1") ||
      !identical(receipt$workflow_name, "R-CMD-check") ||
      !identical(receipt$event, "workflow_dispatch") ||
      !identical(receipt$head_sha, head) ||
      !identical(sort(names(receipt$platforms)), c("macos", "ubuntu", "windows")) ||
      any(receipt$platforms != "success")) {
    stop("retained three-OS CI receipt differs from final branch HEAD", call. = FALSE)
  }
  fresh_path <- tempfile(fileext = ".rds")
  status <- system2(file.path(R.home("bin"), "Rscript"), c(
    "--vanilla", "dev/temporal-program/make-publication-ci-receipt.R",
    format(receipt$run_id, scientific = FALSE), shQuote(fresh_path)
  ))
  if (status != 0L || !file.exists(fresh_path)) {
    stop("live three-OS CI receipt query failed", call. = FALSE)
  }
  fresh <- readRDS(fresh_path)
  unlink(fresh_path)
  receipt$created_at <- fresh$created_at <- NULL
  if (!identical(receipt, fresh)) {
    stop("live CI state differs from retained receipt", call. = FALSE)
  }
  cat("TEMPORAL_PROGRAM_PUBLICATION_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "phylo")) {
  .temporal_program_verify_phylo(root)
  cat("TEMPORAL_PROGRAM_PHYLO_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "dep-kernel")) {
  fixture <- "tests/testthat/test-temporal-program-dep-kernel.R"
  result_path <- "dev/temporal-program/results/dep-kernel-recovery-20260911.csv"
  summary_path <- "dev/temporal-program/results/dep-kernel-recovery-summary-20260911.csv"
  required <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing temporal dep-kernel evidence: ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  recomputed <- .temporal_program_validate_dep_kernel_summary(results, summary)
  thresholds <- c(mean_phi_absolute_error = .15, median_phi_absolute_error = .20,
    median_temporal_frobenius_relative_error = .30,
    median_kernel_1_relative_error = .35, median_kernel_2_relative_error = .35,
    median_kernel_3_relative_error = .35, mean_fixed_effect_error = .25)
  if (any(recomputed$strict_successes != 3L) ||
      any(vapply(names(thresholds), function(nm) any(recomputed[[nm]] > thresholds[[nm]]), logical(1)))) {
    stop("temporal dep-kernel recovery fails its frozen threshold gate", call. = FALSE)
  }
  cat("TEMPORAL_DEP_KERNEL_RECOVERY_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "dep-kernel-retained-failure")) {
  fixture <- "tests/testthat/test-temporal-program-dep-kernel.R"
  result_path <- "dev/temporal-program/results/dep-kernel-recovery-20260911.csv"
  summary_path <- "dev/temporal-program/results/dep-kernel-recovery-summary-20260911.csv"
  required <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing retained temporal dep-kernel failure evidence: ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  recomputed <- .temporal_program_validate_dep_kernel_summary(results, summary)
  row <- recomputed[recomputed$phi == .6, , drop = FALSE]
  if (nrow(row) != 1L || any(recomputed$strict_successes != 3L) ||
      !isTRUE(row$median_kernel_1_relative_error > .35) ||
      !isTRUE(row$median_kernel_2_relative_error > .35) ||
      !isTRUE(row$median_kernel_3_relative_error <= .35)) {
    stop("retained temporal dep-kernel failure is absent or differs from the frozen variance-threshold breach", call. = FALSE)
  }
  cat("TEMPORAL_DEP_KERNEL_RETAINED_FAILURE_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "dep-kernel-oracle")) {
  .temporal_program_verify_dep_kernel_oracle(root)
  cat("TEMPORAL_DEP_KERNEL_RETAINED_ORACLE_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "dep-kernel-curvature")) {
  .temporal_program_verify_dep_kernel_curvature(root)
  cat("TEMPORAL_DEP_KERNEL_RETAINED_CURVATURE_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "dep-phylo")) {
  fixture <- "tests/testthat/test-temporal-program-dep-phylo.R"
  result_path <- "dev/temporal-program/results/dep-phylo-recovery-20260911.csv"
  summary_path <- "dev/temporal-program/results/dep-phylo-recovery-summary-20260911.csv"
  required <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required)))) stop("missing temporal dep-phylo evidence: ",
    paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture)
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  recomputed <- .temporal_program_validate_dep_phylo_summary(results, summary)
  thresholds <- c(mean_phi_absolute_error = .15, median_phi_absolute_error = .20,
    median_temporal_frobenius_relative_error = .30, median_phylo_1_relative_error = .35,
    median_phylo_2_relative_error = .35, median_phylo_3_relative_error = .35,
    mean_fixed_effect_error = .25)
  if (any(recomputed$strict_successes != 3L) ||
      any(vapply(names(thresholds), function(nm) any(recomputed[[nm]] > thresholds[[nm]]), logical(1))))
    stop("temporal dep-phylo recovery fails its frozen threshold gate", call. = FALSE)
  cat("TEMPORAL_DEP_PHYLO_RECOVERY_PASS\n"); quit(save = "no", status = 0L)
}
if (identical(mode, "dep-animal")) {
  fixture <- "tests/testthat/test-temporal-program-dep-animal.R"
  result_path <- "dev/temporal-program/results/dep-animal-recovery-20260911.csv"
  summary_path <- "dev/temporal-program/results/dep-animal-recovery-summary-20260911.csv"
  required <- c(fixture, result_path, summary_path, vapply(1:9, function(i)
    sprintf("dev/temporal-program/results/dep-animal-recovery-attempt-%02d-20260911.csv", i), character(1)))
  if (any(!file.exists(file.path(root, required)))) stop("missing temporal dep-animal evidence: ",
    paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture)
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  expected_phi <- c(-.4, 0, .6); expected_seed <- 2609311:2609313
  required_columns <- c("phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "objective", "temporal_frobenius_relative_error",
    "animal_1", "animal_2", "animal_3", "phi_absolute_error", "fixed_effect_mean_absolute_error")
  if (!all(required_columns %in% names(results)) || nrow(results) != 9L ||
      !setequal(results$phi, expected_phi) || any(vapply(split(results$seed, results$phi),
        function(x) !setequal(x, expected_seed), logical(1))))
    stop("temporal dep-animal receipt does not retain every frozen attempt", call. = FALSE)
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$objective) & is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  recomputed <- do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]; keep <- strict[results$phi == phi]
    data.frame(phi = phi, attempts = nrow(x), strict_successes = sum(keep),
      mean_phi_absolute_error = mean(x$phi_absolute_error[keep]),
      median_phi_absolute_error = stats::median(x$phi_absolute_error[keep]),
      median_temporal_frobenius_relative_error = stats::median(x$temporal_frobenius_relative_error[keep]),
      median_animal_1_relative_error = stats::median(abs(x$animal_1[keep] - .35^2) / .35^2),
      median_animal_2_relative_error = stats::median(abs(x$animal_2[keep] - .28^2) / .28^2),
      median_animal_3_relative_error = stats::median(abs(x$animal_3[keep] - .40^2) / .40^2),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[keep]), stringsAsFactors = FALSE)
  }))
  columns <- names(recomputed)
  if (!all(columns %in% names(summary)) || nrow(summary) != 3L || !setequal(summary$phi, recomputed$phi))
    stop("temporal dep-animal summary has an invalid schema", call. = FALSE)
  summary <- summary[match(recomputed$phi, summary$phi), columns, drop = FALSE]
  if (!isTRUE(all.equal(summary, recomputed, tolerance = 1e-10)))
    stop("temporal dep-animal summary disagrees with retained attempts", call. = FALSE)
  thresholds <- c(mean_phi_absolute_error = .15, median_phi_absolute_error = .20,
    median_temporal_frobenius_relative_error = .30, median_animal_1_relative_error = .35,
    median_animal_2_relative_error = .35, median_animal_3_relative_error = .35,
    mean_fixed_effect_error = .25)
  if (any(recomputed$strict_successes != 3L) ||
      any(vapply(names(thresholds), function(nm) any(recomputed[[nm]] > thresholds[[nm]]), logical(1))))
    stop("temporal dep-animal recovery fails its frozen threshold gate", call. = FALSE)
  cat("TEMPORAL_DEP_ANIMAL_RECOVERY_PASS\n"); quit(save = "no", status = 0L)
}
if (identical(mode, "dep-animal-retained-failure")) {
  fixture <- "tests/testthat/test-temporal-program-dep-animal.R"
  result_path <- "dev/temporal-program/results/dep-animal-recovery-20260911.csv"
  summary_path <- "dev/temporal-program/results/dep-animal-recovery-summary-20260911.csv"
  required <- c(fixture, result_path, summary_path, vapply(1:9, function(i)
    sprintf("dev/temporal-program/results/dep-animal-recovery-attempt-%02d-20260911.csv", i), character(1)))
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing retained temporal dep-animal failure evidence: ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609311:2609313
  required_columns <- c("phi", "seed", "terminal", "convergence", "pass_2_convergence",
    "pass_2_accepted", "max_gradient", "objective", "temporal_frobenius_relative_error",
    "animal_1", "animal_2", "animal_3", "phi_absolute_error", "fixed_effect_mean_absolute_error")
  if (!all(required_columns %in% names(results)) || nrow(results) != 9L ||
      !setequal(results$phi, expected_phi) || any(vapply(split(results$seed, results$phi),
        function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("retained temporal dep-animal receipt does not retain every frozen attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$objective) & is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  recomputed <- do.call(rbind, lapply(expected_phi, function(phi) {
    x <- results[results$phi == phi, , drop = FALSE]
    keep <- strict[results$phi == phi]
    data.frame(phi = phi, attempts = nrow(x), strict_successes = sum(keep),
      mean_phi_absolute_error = mean(x$phi_absolute_error[keep]),
      median_phi_absolute_error = stats::median(x$phi_absolute_error[keep]),
      median_temporal_frobenius_relative_error = stats::median(x$temporal_frobenius_relative_error[keep]),
      median_animal_1_relative_error = stats::median(abs(x$animal_1[keep] - .35^2) / .35^2),
      median_animal_2_relative_error = stats::median(abs(x$animal_2[keep] - .28^2) / .28^2),
      median_animal_3_relative_error = stats::median(abs(x$animal_3[keep] - .40^2) / .40^2),
      mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error[keep]), stringsAsFactors = FALSE)
  }))
  columns <- names(recomputed)
  if (!all(columns %in% names(summary)) || nrow(summary) != 3L ||
      !setequal(summary$phi, expected_phi) ||
      !isTRUE(all.equal(summary[match(expected_phi, summary$phi), columns, drop = FALSE], recomputed,
        tolerance = 1e-10))) {
    stop("retained temporal dep-animal summary disagrees with fixed attempts", call. = FALSE)
  }
  row <- recomputed[recomputed$phi == .6, , drop = FALSE]
  if (nrow(row) != 1L || !all(recomputed$strict_successes == 3L) ||
      !isTRUE(row$median_animal_2_relative_error > .35) ||
      !isTRUE(row$median_animal_1_relative_error <= .35) ||
      !isTRUE(row$median_animal_3_relative_error <= .35)) {
    stop("retained temporal dep-animal failure is absent or differs from the frozen variance-threshold breach", call. = FALSE)
  }
  cat("TEMPORAL_DEP_ANIMAL_RETAINED_FAILURE_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "latent-kernel")) {
  fixture <- "tests/testthat/test-temporal-program-latent-kernel.R"
  result_path <- "dev/temporal-program/results/latent-kernel-recovery-20260911.csv"
  summary_path <- "dev/temporal-program/results/latent-kernel-recovery-summary-20260911.csv"
  required <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing temporal latent-kernel evidence: ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  recomputed <- .temporal_program_validate_latent_kernel_summary(results, summary)
  thresholds <- c(mean_phi_absolute_error = .15, median_phi_absolute_error = .20,
    median_temporal_frobenius_relative_error = .30,
    median_kernel_1_relative_error = .35, median_kernel_2_relative_error = .35,
    median_kernel_3_relative_error = .35, mean_fixed_effect_error = .25)
  if (any(recomputed$strict_successes != 3L) ||
      any(vapply(names(thresholds), function(nm) any(recomputed[[nm]] > thresholds[[nm]]), logical(1)))) {
    stop("temporal latent-kernel recovery fails its frozen threshold gate", call. = FALSE)
  }
  cat("TEMPORAL_LATENT_KERNEL_RECOVERY_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "latent-phylo")) {
  fixture <- "tests/testthat/test-temporal-program-latent-phylo.R"
  result_path <- "dev/temporal-program/results/latent-phylo-recovery-20260911.csv"
  summary_path <- "dev/temporal-program/results/latent-phylo-recovery-summary-20260911.csv"
  required <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing temporal latent-phylo evidence: ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  recomputed <- .temporal_program_validate_latent_phylo_summary(results, summary)
  thresholds <- c(mean_phi_absolute_error = .15, median_phi_absolute_error = .20,
    median_temporal_frobenius_relative_error = .30,
    median_phylo_1_relative_error = .35, median_phylo_2_relative_error = .35,
    median_phylo_3_relative_error = .35, mean_fixed_effect_error = .25)
  if (any(recomputed$strict_successes != 3L) ||
      any(vapply(names(thresholds), function(nm) any(recomputed[[nm]] > thresholds[[nm]]), logical(1)))) {
    stop("temporal latent-phylo recovery fails its frozen threshold gate", call. = FALSE)
  }
  cat("TEMPORAL_LATENT_PHYLO_RECOVERY_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "latent-animal")) {
  fixture <- "tests/testthat/test-temporal-program-latent-animal.R"
  result_path <- "dev/temporal-program/results/latent-animal-recovery-20260911.csv"
  summary_path <- "dev/temporal-program/results/latent-animal-recovery-summary-20260911.csv"
  required <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing temporal latent-animal evidence: ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  recomputed <- .temporal_program_validate_latent_animal_summary(results, summary)
  thresholds <- c(mean_phi_absolute_error = .15, median_phi_absolute_error = .20,
    median_temporal_frobenius_relative_error = .30,
    median_animal_1_relative_error = .35, median_animal_2_relative_error = .35,
    median_animal_3_relative_error = .35, mean_fixed_effect_error = .25)
  if (any(recomputed$strict_successes != 3L) ||
      any(vapply(names(thresholds), function(nm) any(recomputed[[nm]] > thresholds[[nm]]), logical(1)))) {
    stop("temporal latent-animal recovery fails its frozen threshold gate", call. = FALSE)
  }
  cat("TEMPORAL_LATENT_ANIMAL_RECOVERY_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "latent-spatial")) {
  fixture <- "tests/testthat/test-temporal-program-latent-spatial.R"
  result_path <- "dev/temporal-program/results/latent-spatial-recovery-20260911.csv"
  summary_path <- "dev/temporal-program/results/latent-spatial-recovery-summary-20260911.csv"
  required <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing temporal latent-spatial evidence: ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  recomputed <- .temporal_program_validate_latent_spatial_summary(results, summary)
  thresholds <- c(mean_phi_absolute_error = .15, median_phi_absolute_error = .20,
    median_temporal_frobenius_relative_error = .30,
    median_tau_1_relative_error = .35, median_tau_2_relative_error = .35,
    median_tau_3_relative_error = .35, median_kappa_relative_error = .50,
    mean_fixed_effect_error = .25)
  if (any(recomputed$strict_successes != 3L) ||
      any(vapply(names(thresholds), function(nm) any(recomputed[[nm]] > thresholds[[nm]]), logical(1)))) {
    stop("temporal latent-spatial recovery fails its frozen threshold gate", call. = FALSE)
  }
  cat("TEMPORAL_LATENT_SPATIAL_RECOVERY_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "dep-spatial")) {
  fixture <- "tests/testthat/test-temporal-program-dep-spatial.R"
  result_path <- "dev/temporal-program/results/dep-spatial-recovery-20260911.csv"
  summary_path <- "dev/temporal-program/results/dep-spatial-recovery-summary-20260911.csv"
  required <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing temporal dep-spatial evidence: ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  recomputed <- .temporal_program_validate_dep_spatial_summary(results, summary)
  thresholds <- c(mean_phi_absolute_error = .15, median_phi_absolute_error = .20,
    median_temporal_frobenius_relative_error = .30,
    median_tau_1_relative_error = .35, median_tau_2_relative_error = .35,
    median_tau_3_relative_error = .35, median_kappa_relative_error = .50,
    mean_fixed_effect_error = .25)
  if (any(recomputed$strict_successes != 3L) ||
      any(vapply(names(thresholds), function(nm) any(recomputed[[nm]] > thresholds[[nm]]), logical(1)))) {
    stop("temporal dep-spatial recovery fails its frozen threshold gate", call. = FALSE)
  }
  cat("TEMPORAL_DEP_SPATIAL_RECOVERY_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "dep-spatial-corrected")) {
  fixture <- "tests/testthat/test-temporal-program-dep-spatial-runner.R"
  receipt_dir <- "dev/temporal-program/results/corrected-scale-20260911"
  attempt_paths <- file.path(receipt_dir, sprintf("dep-spatial-corrected-scale-attempt-%02d.csv", 1:9))
  phase_paths <- sub("\\.csv$", "-phase.csv", attempt_paths)
  result_path <- file.path(receipt_dir, "dep-spatial-corrected-scale-recovery.csv")
  summary_path <- file.path(receipt_dir, "dep-spatial-corrected-scale-summary.csv")
  required <- c(fixture, attempt_paths, phase_paths, result_path, summary_path,
    file.path(receipt_dir, "totoro-finalize.log"))
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing corrected-scale temporal dep-spatial evidence: ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  attempts <- do.call(rbind, lapply(file.path(root, attempt_paths), utils::read.csv, check.names = FALSE))
  combined <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  if (!all(names(attempts) %in% names(combined)) ||
      !isTRUE(all.equal(attempts, combined[, names(attempts), drop = FALSE], tolerance = 1e-12,
        check.attributes = FALSE)))
    stop("corrected-scale combined receipt disagrees with the nine retained attempts", call. = FALSE)
  results <- combined
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  recomputed <- .temporal_program_validate_dep_spatial_summary(results, summary)
  thresholds <- c(mean_phi_absolute_error = .15, median_phi_absolute_error = .20,
    median_temporal_frobenius_relative_error = .30,
    median_tau_1_relative_error = .35, median_tau_2_relative_error = .35,
    median_tau_3_relative_error = .35, median_kappa_relative_error = .50,
    mean_fixed_effect_error = .25)
  passes <- recomputed$strict_successes == 3L & !vapply(seq_len(nrow(recomputed)), function(i)
    any(vapply(names(thresholds), function(nm) recomputed[[nm]][[i]] > thresholds[[nm]], logical(1))), logical(1))
  if (!identical(as.logical(summary$passes[match(recomputed$phi, summary$phi)]), passes))
    stop("corrected-scale temporal dep-spatial summary has stale pass labels", call. = FALSE)
  if (all(passes)) stop("corrected-scale temporal dep-spatial campaign unexpectedly passes; update its evidence gate", call. = FALSE)
  phase <- lapply(file.path(root, phase_paths), utils::read.csv, check.names = FALSE)
  if (!all(vapply(phase, function(x) nrow(x) == 1L && x$phase[[1L]] %in% c("gradient_finished", "error"), logical(1))))
    stop("corrected-scale temporal dep-spatial phase receipts are not terminal", call. = FALSE)
  cat("TEMPORAL_DEP_SPATIAL_CORRECTED_SCALE_RETAINED_FAILURE\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "combinations")) {
  fixture <- "tests/testthat/test-temporal-program-kernel-replicated.R"
  result_path <- "dev/temporal-program/results/kernel-recovery-20260909.csv"
  summary_path <- "dev/temporal-program/results/kernel-recovery-summary-20260909.csv"
  required_paths <- c(fixture, result_path, summary_path)
  if (any(!file.exists(file.path(root, required_paths)))) {
    stop("missing temporal-kernel evidence: ",
      paste(required_paths[!file.exists(file.path(root, required_paths))], collapse = ", "),
      call. = FALSE)
  }
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, fixture), reporter = "silent"), fixture
  )
  results <- utils::read.csv(file.path(root, result_path), check.names = FALSE)
  summary <- utils::read.csv(file.path(root, summary_path), check.names = FALSE)
  need_results <- c(
    "phi", "seed", "terminal", "convergence", "pass_1_convergence",
    "pass_2_convergence", "pass_2_accepted", "max_gradient",
    "temporal_relative_error_1", "temporal_relative_error_2",
    "temporal_relative_error_3", "kernel_relative_error_1",
    "kernel_relative_error_2", "kernel_relative_error_3",
    "phi_absolute_error", "fixed_effect_mean_absolute_error"
  )
  need_summary <- c(
    "phi", "attempts", "strict_successes", "mean_phi_absolute_error",
    "median_phi_absolute_error", "median_temporal_1_relative_error",
    "median_temporal_2_relative_error", "median_temporal_3_relative_error",
    "median_kernel_1_relative_error", "median_kernel_2_relative_error",
    "median_kernel_3_relative_error", "mean_fixed_effect_error", "passes"
  )
  if (!all(need_results %in% names(results)) || !all(need_summary %in% names(summary))) {
    stop("temporal-kernel evidence schema is incomplete", call. = FALSE)
  }
  expected_phi <- c(-.4, 0, .6)
  expected_seed <- 2609151:2609153
  if (nrow(results) != 9L || nrow(summary) != 3L ||
      !setequal(results$phi, expected_phi) || !setequal(results$seed, expected_seed) ||
      any(vapply(split(results$seed, results$phi), function(x) !setequal(x, expected_seed), logical(1)))) {
    stop("temporal-kernel recovery does not retain every fixed phi/seed attempt", call. = FALSE)
  }
  strict <- results$terminal == "success" & results$convergence == 0L &
    results$pass_2_convergence == 0L & results$pass_2_accepted &
    is.finite(results$max_gradient) & results$max_gradient <= 1e-3
  if (!all(strict) || !all(summary$attempts == 3L) ||
      !all(summary$strict_successes == 3L) || !all(summary$passes)) {
    stop("temporal-kernel recovery has a retained terminal or final-pass failure", call. = FALSE)
  }
  recomputed_summary <- .temporal_program_validate_kernel_summary(results, summary)
  threshold_columns <- c(
    mean_phi_absolute_error = .15,
    median_phi_absolute_error = .20,
    median_temporal_1_relative_error = .35,
    median_temporal_2_relative_error = .35,
    median_temporal_3_relative_error = .35,
    median_kernel_1_relative_error = .35,
    median_kernel_2_relative_error = .35,
    median_kernel_3_relative_error = .35,
    mean_fixed_effect_error = .25
  )
  if (any(!is.finite(as.matrix(recomputed_summary[names(threshold_columns)]))) ||
      any(vapply(names(threshold_columns), function(nm) {
        any(recomputed_summary[[nm]] > threshold_columns[[nm]])
      }, logical(1)))) {
    stop("temporal-kernel recovery exceeds a frozen summary threshold", call. = FALSE)
  }
  .temporal_program_verify_phylo(root)
  cat("TEMPORAL_PROGRAM_COMBINATIONS_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "latent-phylo-endpoint")) {
  evidence_dir <- file.path(root, "dev", "temporal-program", "results", "diagnostics")
  script <- file.path(root, "dev", "temporal-program", "diagnose-latent-phylo-endpoint.R")
  contract <- file.path(root, "dev", "temporal-program",
    "TEMPORAL-LATENT-PHYLO-ENDPOINT-DIAGNOSTIC-CONTRACT.md")
  paths <- file.path(evidence_dir,
    sprintf("latent-phylo-endpoint-20260912-coordinate-%02d.rds", 1:11))
  if (!file.exists(script) || !file.exists(contract) || any(!file.exists(paths))) {
    stop("missing temporal latent-phylo endpoint diagnostic artifacts", call. = FALSE)
  }
  receipts <- lapply(paths, readRDS)
  coordinate <- vapply(receipts, function(x) x$coordinate$index, integer(1))
  if (!identical(coordinate, 1:11) || any(!vapply(receipts, function(x) {
    identical(x$contract, "TEMPORAL-LATENT-PHYLO-ENDPOINT-DIAGNOSTIC-v1") &&
      identical(x$endpoint, list(phi = .6, seed = 2609243L)) &&
      is.finite(x$native$objective) && is.finite(x$fresh$objective) &&
      is.finite(x$dense$objective) && is.finite(x$coordinate$error)
  }, logical(1)))) {
    stop("temporal latent-phylo endpoint receipts have an invalid identity or schema", call. = FALSE)
  }
  reference <- receipts[[1L]]
  if (abs(reference$fresh$objective_error) > 1e-8 ||
      reference$fresh$gradient_error_max > 1e-7 ||
      abs(reference$dense$objective_error) > 1e-6 ||
      max(abs(vapply(receipts, function(x) x$coordinate$error, numeric(1)))) > 2e-5) {
    stop("temporal latent-phylo endpoint native/dense agreement exceeds its diagnostic tolerance", call. = FALSE)
  }
  boundary <- receipts[[10L]]$phylo_second_loading
  if (!is.numeric(boundary$objective_change) || length(boundary$objective_change) != 3L ||
      any(!is.finite(boundary$objective_change)) || any(boundary$objective_change <= 0) ||
      !identical(reference$hessian$status, "error") ||
      !nzchar(reference$hessian$message)) {
    stop("temporal latent-phylo endpoint boundary or Hessian diagnostic is incomplete", call. = FALSE)
  }
  cat("TEMPORAL_LATENT_PHYLO_ENDPOINT_DIAGNOSTIC_PASS\n")
  quit(save = "no", status = 0L)
}
if (identical(mode, "closeout")) {
  stop("Closeout requires a retained three-OS publication receipt and completion of the remaining temporal source-pair programme gates.", call. = FALSE)
}
if (identical(mode, "remote")) {
  task <- "dev/temporal-program/remote/phylo-recovery-task.R"
  collector <- "dev/temporal-program/remote/collect-phylo-recovery.R"
  launcher <- "dev/temporal-program/remote/phylo-recovery-drac.sh"
  runtime <- "dev/temporal-program/remote/prepare-phylo-recovery-runtime.sh"
  required <- c(task, collector, launcher, runtime,
    "dev/temporal-program/remote/phylo-recovery-common.R",
    "dev/temporal-program/results/phylo-recovery-160-tasks-20260909.csv")
  if (any(!file.exists(file.path(root, required)))) {
    stop("missing temporal phylogenetic remote artifact(s): ",
      paste(required[!file.exists(file.path(root, required))], collapse = ", "), call. = FALSE)
  }
  task_out <- system2("Rscript", c("--vanilla", task, "--mode=plan"), stdout = TRUE, stderr = TRUE)
  if (!identical(attr(task_out, "status"), NULL) || !any(grepl("TEMPORAL_PHYLO_TASK_PLAN_PASS tasks=22", task_out, fixed = TRUE))) {
    stop("phylogenetic DRAC task manifest does not verify.", call. = FALSE)
  }
  shell_status <- system2("bash", c("-n", launcher))
  runtime_status <- system2("bash", c("-n", runtime))
  if (!identical(shell_status, 0L) || !identical(runtime_status, 0L)) {
    stop("phylogenetic DRAC launcher or runtime-preflight script has invalid shell syntax.", call. = FALSE)
  }
  envelope_dir <- tempfile("temporal-phylo-drac-envelope-")
  launcher_out <- system2("bash", launcher,
    env = c(paste0("RESULTS_DIR=", envelope_dir), "SLURM_ACTION=write"), stdout = TRUE, stderr = TRUE)
  sbatch <- file.path(envelope_dir, "_slurm", "phylo-recovery-160.sbatch")
  manifest <- file.path(envelope_dir, "_slurm", "manifest.tsv")
  if (!identical(attr(launcher_out, "status"), NULL) ||
      !any(grepl("TEMPORAL_PHYLO_DRAC_WRITE_PASS", launcher_out, fixed = TRUE)) ||
      !file.exists(sbatch) || !file.exists(manifest)) {
    stop("phylogenetic DRAC launcher did not create a write-only envelope.", call. = FALSE)
  }
  manifest_data <- utils::read.delim(manifest, header = FALSE, sep = "\t", stringsAsFactors = FALSE)
  sbatch_text <- readLines(sbatch, warn = FALSE)
  if (nrow(manifest_data) != 7L || any(lengths(strsplit(readLines(manifest), "\t", fixed = TRUE)) != 2L) ||
      !all(c("#SBATCH --array=1-22%6", "#SBATCH --cpus-per-task=1", "export OPENBLAS_NUM_THREADS=1", "export GLLVMTMB_TEMPORAL_LOAD=\"pkgload\"") %in% sbatch_text)) {
    stop("phylogenetic DRAC envelope has an invalid manifest or task shape.", call. = FALSE)
  }
  denied_dir <- tempfile("temporal-phylo-drac-denied-")
  denied_out <- suppressWarnings(system2("bash", launcher,
    env = c(paste0("RESULTS_DIR=", denied_dir), "SLURM_ACTION=submit"), stdout = TRUE, stderr = TRUE))
  if (is.null(attr(denied_out, "status")) ||
      !any(grepl("Refusing submission without TEMPORAL_PHYLO_DRAC_APPROVED=YES", denied_out, fixed = TRUE))) {
    stop("phylogenetic DRAC launcher did not fence an unapproved submission.", call. = FALSE)
  }
  collector_out <- suppressWarnings(system2("Rscript", c("--vanilla", collector,
      paste0("--attempt-dir=", envelope_dir), paste0("--output-dir=", tempfile("temporal-phylo-collect-"))),
    stdout = TRUE, stderr = TRUE))
  if (is.null(attr(collector_out, "status")) ||
      !any(grepl("Missing DRAC task receipts", collector_out, fixed = TRUE))) {
    stop("phylogenetic collector did not reject an incomplete task set.", call. = FALSE)
  }
  retained_error_dir <- tempfile("temporal-phylo-retained-error-")
  retained_error_out <- suppressWarnings(system2("Rscript", c("--vanilla", task, "--mode=task",
      "--task-id=1", paste0("--results-dir=", retained_error_dir)),
    env = "GLLVMTMB_TEMPORAL_LOAD=invalid", stdout = TRUE, stderr = TRUE))
  retained_error_path <- file.path(retained_error_dir, "phylo-recovery-attempt-01.csv")
  if (!identical(attr(retained_error_out, "status"), NULL) || !file.exists(retained_error_path)) {
    stop("phylogenetic task did not retain a pre-fit package-load error receipt.", call. = FALSE)
  }
  retained_error <- utils::read.csv(retained_error_path, check.names = FALSE)
  if (nrow(retained_error) != 1L || !identical(retained_error$terminal[[1L]], "error") ||
      !grepl("GLLVMTMB_TEMPORAL_LOAD", retained_error$error_message[[1L]], fixed = TRUE)) {
    stop("phylogenetic task pre-fit package-load receipt is malformed.", call. = FALSE)
  }
  cat("TEMPORAL_PROGRAM_REMOTE_PASS\n")
  quit(save = "no", status = 0L)
}

fixture <- switch(mode,
  simulation = c(
    "tests/testthat/test-temporal-program-simulation.R",
    "tests/testthat/test-temporal-program-composed-simulation.R"
  ),
  lifecycle = c(
    "tests/testthat/test-temporal-program-forecast.R",
    "tests/testthat/test-temporal-program-forecast-kernel.R",
    "tests/testthat/test-temporal-program-profile.R",
    "tests/testthat/test-temporal-program-bootstrap.R",
    "tests/testthat/test-temporal-program-selection.R",
    "tests/testthat/test-temporal-program-ou-kernel.R"
  )
)
if (any(!file.exists(file.path(root, fixture)))) {
  stop("missing temporal programme fixture: ",
    paste(fixture[!file.exists(file.path(root, fixture))], collapse = ", "), call. = FALSE)
}
pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
for (path in fixture) {
  .temporal_program_assert_test_results(
    testthat::test_file(file.path(root, path), reporter = "silent"), path
  )
}
cat(sprintf("TEMPORAL_PROGRAM_%s_PASS\n", toupper(mode)))
