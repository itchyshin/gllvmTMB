## B4 (Design 81) -- Tier-3 augmented DIAGONAL random SLOPE on the cluster2
## grouping: unique(1 + x | c2). The uncorrelated (indep / ||) intercept+slope
## form. A renamed copy of the unit-tier use_diag_B_slope engine keyed on
## cluster2_id.
##
## SYMBOLIC ALIGNMENT (Noether gate): the reported sd_c2_slope is length
## C = 2T, interleaved (intercept_t0, slope_t0, intercept_t1, slope_t1, ...)
## exactly as Z_c2_slope packs its columns (base = 2 * trait_id; +1 intercept,
## +2 slope). So per trait t (0-indexed): intercept SD = sd_c2_slope[2t+1],
## slope SD = sd_c2_slope[2t+2]. The DGP draws b_int_t ~ N(0, sd_int[t]) and
## b_slope_t ~ N(0, sd_slope[t]) INDEPENDENTLY per (c2 level, trait), so the
## truth is a fully diagonal Sigma_c2_slope = diag(sd_int, sd_slope interleaved).
##
## Fit shape mirrors test-cluster2-families.R: unit / unit_obs point at
## throwaway per-row id columns (no diag term) so the cluster2 slope cannot
## collide with those slots. Gaussian-only (the engine guards non-Gaussian).
## Honest-skip on non-convergence / non-PD.

test_that("cluster2 x gaussian augmented slope unique(1 + x | c2): sd_c2_slope (intercept + slope) recovers", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(4181L)
  n_traits <- 2L
  n_c2     <- 120L   # many cluster2 levels -> slope variance estimable
  n_unit   <- 6L
  n_rep    <- 1L
  true_sd_int   <- c(0.60, 0.50)   # per-trait cluster2 INTERCEPT sd
  true_sd_slope <- c(0.45, 0.70)   # per-trait cluster2 SLOPE sd
  alpha    <- 1.0
  sd_resid <- 0.4

  traits <- letters[seq_len(n_traits)]
  grid <- expand.grid(
    rep = seq_len(n_rep), unit = seq_len(n_unit),
    c2 = seq_len(n_c2), trait_idx = seq_len(n_traits)
  )
  grid$trait <- factor(traits[grid$trait_idx], levels = traits)
  grid$x <- stats::rnorm(nrow(grid))

  ## Independent per-(c2, trait) intercept and slope random effects.
  b_int <- vapply(seq_len(n_traits),
                  function(t) stats::rnorm(n_c2, 0, true_sd_int[t]), numeric(n_c2))
  b_slope <- vapply(seq_len(n_traits),
                    function(t) stats::rnorm(n_c2, 0, true_sd_slope[t]), numeric(n_c2))
  ij <- cbind(grid$c2, grid$trait_idx)
  eta <- alpha + b_int[ij] + grid$x * b_slope[ij]
  grid$value <- eta + stats::rnorm(nrow(grid), 0, sd_resid)

  grid$c2   <- factor(grid$c2)
  grid$obs  <- factor(seq_len(nrow(grid)))
  grid$obs2 <- factor(seq_len(nrow(grid)))

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + unique(1 + x | c2),
      data = grid, family = gaussian(),
      unit = "obs", unit_obs = "obs2", cluster2 = "c2"
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    testthat::fail(sprintf(
      "cluster2 augmented slope aborted at construction: %s", conditionMessage(fit)
    ))
    return(invisible(NULL))
  }

  healthy <- isTRUE(fit$opt$convergence == 0L) &&
    is.finite(fit$opt$objective) &&
    (isTRUE(fit$fit_health$pd_hessian) || isTRUE(fit$sd_report$pdHess))
  if (!healthy) {
    skip("cluster2 augmented-slope gaussian fixture did not converge / Hessian not PD")
  }

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$use$diag_cluster2_slope))
  expect_identical(fit$use$diag_cluster2_slope_col, "x")

  sd_slope_vec <- as.numeric(fit$report$sd_c2_slope)
  expect_length(sd_slope_vec, 2L * n_traits)
  expect_true(all(is.finite(sd_slope_vec)))

  int_hat   <- sd_slope_vec[seq(1L, 2L * n_traits, by = 2L)]  # intercept SDs
  slope_hat <- sd_slope_vec[seq(2L, 2L * n_traits, by = 2L)]  # slope SDs

  for (t in seq_len(n_traits)) {
    expect_equal(int_hat[t], true_sd_int[t], tolerance = 0.20,
                 label = paste0("intercept sd_c2_slope trait ", t))
    expect_equal(slope_hat[t], true_sd_slope[t], tolerance = 0.20,
                 label = paste0("slope sd_c2_slope trait ", t))
  }

  ## Existing cluster2 diagonal + unit-tier slope paths must be untouched.
  expect_false(isTRUE(fit$use$diag_cluster2))
})
