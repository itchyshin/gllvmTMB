# Retained point-recovery evidence for spatial response-column intercepts and
# slopes. Run from the package root with:
#   Rscript --vanilla data-raw/spatial-coef-recovery.R
#
# This bounded deterministic campaign is not run during R CMD check. It covers
# one claim-bearing ordinary cell plus coefficient-correlation, spatial-range,
# and variance edge regimes. It is not interval, coverage, calibration, or
# new-location prediction evidence.

devtools::load_all(quiet = TRUE)

run_spatial_coef_cell <- function(seed, range_truth = 2.5,
                                  corr_truth = 0.375,
                                  variances = c(0.16, 0.09),
                                  noise_sd = 0.05) {
  set.seed(seed)
  locations <- expand.grid(
    east_km = 0:4, north_km = 0:4, KEEP.OUT.ATTRS = FALSE
  )
  locations$trait <- paste0("plant_", sprintf("%02d", seq_len(nrow(locations))))
  locations$pathway <- factor(
    rep(c("C3", "C4"), length.out = nrow(locations)),
    levels = c("C3", "C4")
  )
  locations <- locations[c("trait", "pathway", "east_km", "north_km")]
  column_mesh <- make_mesh(
    locations, c("east_km", "north_km"), cutoff = 0.18,
    id_col = "trait"
  )
  kappa_truth <- sqrt(8) / range_truth
  A <- as.matrix(column_mesh$A_st)
  Q <- kappa_truth^4 * as.matrix(column_mesh$spde$c0) +
    2 * kappa_truth^2 * as.matrix(column_mesh$spde$g1) +
    as.matrix(column_mesh$spde$g2)
  C_raw <- A %*% solve(Q, t(A))
  inv_sd <- 1 / sqrt(diag(C_raw))
  K_truth <- C_raw * tcrossprod(inv_sd)
  diag(K_truth) <- 1

  covariance <- corr_truth * sqrt(prod(variances))
  Sigma_truth <- matrix(
    c(variances[[1L]], covariance, covariance, variances[[2L]]),
    2L, 2L
  )
  B <- t(chol(K_truth)) %*%
    matrix(stats::rnorm(nrow(locations) * 2L), nrow(locations), 2L) %*%
    chol(Sigma_truth)
  alpha <- c(C3 = 0.35, C4 = 0.75)
  beta <- c(C3 = -0.25, C4 = 0.30)
  wide <- data.frame(
    unit = factor(paste0("u", seq_len(36L))),
    moisture = seq(-1.5, 1.5, length.out = 36L)
  )
  for (j in seq_len(nrow(locations))) {
    pathway <- as.character(locations$pathway[[j]])
    wide[[locations$trait[[j]]]] <-
      alpha[[pathway]] + B[j, 1L] +
      (beta[[pathway]] + B[j, 2L]) * wide$moisture +
      stats::rnorm(nrow(wide), sd = noise_sd)
  }
  long <- tidyr::pivot_longer(
    wide, cols = tidyselect::all_of(locations$trait),
    names_to = "trait", values_to = "value"
  )
  long <- as.data.frame(long)
  long$trait <- factor(long$trait, levels = locations$trait)
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + pathway + moisture:pathway +
      spatial_coef(1 + moisture | trait, mesh = column_mesh),
    data = long, column_data = locations[c("trait", "pathway")],
    trait = "trait", unit = "unit", family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
  got <- extract_Sigma(fit, level = "column_coef")
  fixed <- coef(fit)
  gradient <- fit$tmb_obj$gr(fit$opt$par)
  data.frame(
    seed = seed,
    convergence = fit$opt$convergence,
    max_gradient = max(abs(gradient)),
    fixed_max_error = max(abs(
      fixed[c("pathwayC3", "pathwayC4", "pathwayC3:moisture",
              "pathwayC4:moisture")] - c(alpha, beta)
    )),
    variance_1_ratio = got$Sigma[1L, 1L] / Sigma_truth[1L, 1L],
    variance_2_ratio = got$Sigma[2L, 2L] / Sigma_truth[2L, 2L],
    correlation_truth = corr_truth,
    correlation_fit = got$R[1L, 2L],
    range_truth = range_truth,
    range_fit = got$source$practical_range,
    K_rmse = sqrt(mean((got$K_rho - K_truth)^2))
  )
}

specs <- list(
  ordinary = list(seed = 13315L),
  correlation_zero = list(seed = 13321L, corr_truth = 0),
  correlation_positive = list(seed = 13322L, corr_truth = 0.8),
  correlation_negative = list(seed = 13323L, corr_truth = -0.8),
  correlation_boundary = list(seed = 13328L, corr_truth = 0.98),
  range_low = list(seed = 13324L, range_truth = 0.8),
  range_extent_limited = list(seed = 13325L, range_truth = 7.5),
  variance_small = list(
    seed = 13326L, variances = c(0.01, 0.015), noise_sd = 0.025
  ),
  variance_large = list(seed = 13327L, variances = c(25, 16))
)
results <- lapply(specs, function(x) do.call(run_spatial_coef_cell, x))
results <- do.call(rbind, results)
results$cell <- rownames(results)
rownames(results) <- NULL
results <- results[c("cell", setdiff(names(results), "cell"))]
print(results, row.names = FALSE)

ordinary <- results[results$cell == "ordinary", ]
checks <- c(
  every_fit_converged = all(results$convergence == 0L),
  every_gradient_small = all(results$max_gradient < 5e-3),
  ordinary_fixed_effects = ordinary$fixed_max_error < 0.25,
  ordinary_variances = all(
    ordinary[c("variance_1_ratio", "variance_2_ratio")] > 0.4 &
      ordinary[c("variance_1_ratio", "variance_2_ratio")] < 1.5
  ),
  ordinary_correlation = abs(
    ordinary$correlation_fit - ordinary$correlation_truth
  ) < 0.2,
  ordinary_range = ordinary$range_fit / ordinary$range_truth > 0.6 &&
    ordinary$range_fit / ordinary$range_truth < 1.4,
  ordinary_K = ordinary$K_rmse < 0.08,
  near_zero_correlation = abs(
    results$correlation_fit[results$cell == "correlation_zero"]
  ) < 0.25,
  positive_correlation = abs(
    results$correlation_fit[results$cell == "correlation_positive"] - 0.8
  ) < 0.2,
  negative_correlation = abs(
    results$correlation_fit[results$cell == "correlation_negative"] + 0.8
  ) < 0.2,
  boundary_correlation = abs(
    results$correlation_fit[results$cell == "correlation_boundary"] - 0.98
  ) < 0.1,
  low_range = with(
    results[results$cell == "range_low", ],
    range_fit / range_truth > 0.6 && range_fit / range_truth < 1.5 &&
      K_rmse < 0.1
  ),
  extent_limited_range_is_larger =
    results$range_fit[results$cell == "range_extent_limited"] >
      results$range_fit[results$cell == "range_low"],
  small_variance = all(
    results[results$cell == "variance_small",
            c("variance_1_ratio", "variance_2_ratio")] > 0.4 &
      results[results$cell == "variance_small",
              c("variance_1_ratio", "variance_2_ratio")] < 1.5
  ),
  large_variance = all(
    results[results$cell == "variance_large",
            c("variance_1_ratio", "variance_2_ratio")] > 0.7 &
      results[results$cell == "variance_large",
              c("variance_1_ratio", "variance_2_ratio")] < 1.5
  )
)
print(checks)
stopifnot(all(checks))
