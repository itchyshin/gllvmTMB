## B3 (Design 79 §3-5) -- the bare unprefixed `||` uncorrelated random-slope
## spelling for the ordinary (none-source) unit tier.
##
## `indep(1 + x || g)` is the per-trait FULLY DIAGONAL augmented slope: each
## trait gets an independent intercept variance and an independent slope
## variance, with NO intercept-slope covariance (Design 79 §4, `indep ||` cell
## = 2T params). It routes to the same `use_diag_B_slope` engine that the
## soft-deprecated `unique(1 + x | g)` drives -- standalone `indep` and `unique`
## are the mathematically identical diagonal covstruct -- so the parser rewrites
## `indep(1 + x || g)` to the `diag(..., .unique_augmented = TRUE)` marker.
##
## SYMBOLIC ALIGNMENT (Noether gate): the reported `sd_B_slope` is length
## C = 2T, interleaved (intercept_t0, slope_t0, intercept_t1, slope_t1, ...)
## exactly as Z_B_slope packs its columns (base = 2 * trait_id; +1 intercept,
## +2 slope). So per trait t (0-indexed): intercept SD = sd_B_slope[2t+1],
## slope SD = sd_B_slope[2t+2]. The C++ builds a purely diagonal
## Sigma_B_unique_slope(j,j) = sd_B_slope(j)^2, so the intercept-slope
## covariance is STRUCTURALLY zero (no cor_b for this path) -- the `||`
## contract by construction.
##
## Ordinary `latent(1 + x || g)` is a DIFFERENT cell: it needs a block-diagonal
## Lambda constraint that is a pending engine deliverable (Design 79, "still to
## build"). The shipped ordinary `latent(1 + x | g)` fits the CORRELATED
## joint-Lambda slope, so the parser must fail loud on `latent(1 + x || g)`
## rather than silently fit the correlated model. Both are asserted below.

## ---------------------------------------------------------------------------
## 1. Parse-only (no fit): the bare `||` rewrite produces the right covstruct.
## ---------------------------------------------------------------------------

test_that("indep(1 + x || g) desugars to the diagonal augmented-slope covstruct", {
  withr::local_options(lifecycle_verbosity = "quiet")

  wide_formula <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + indep(1 + temperature || individual)
  )
  wide <- gllvmTMB:::parse_multi_formula(wide_formula)$covstructs[[1L]]
  expect_identical(wide$kind, "diag")
  expect_true(isTRUE(wide$extra$.unique_augmented))
  expect_identical(wide$extra$lhs_form, "wide_intercept_slope")
  expect_identical(wide$extra$slope_col, "temperature")

  long_formula <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 +
      trait +
      indep(0 + trait + (0 + trait):temperature || individual)
  )
  long <- gllvmTMB:::parse_multi_formula(long_formula)$covstructs[[1L]]
  expect_identical(long$kind, "diag")
  expect_true(isTRUE(long$extra$.unique_augmented))
  expect_identical(long$extra$lhs_form, "long_intercept_slope")
  expect_identical(long$extra$slope_col, "temperature")

  ## The `||` spelling is byte-identical to the compatibility `unique(1 + x | g)`
  ## covstruct it routes through.
  unique_formula <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + unique(1 + temperature | individual)
  )
  uniq <- gllvmTMB:::parse_multi_formula(unique_formula)$covstructs[[1L]]
  expect_identical(wide$kind, uniq$kind)
  expect_identical(wide$extra$.unique_augmented, uniq$extra$.unique_augmented)
  expect_identical(wide$extra$lhs_form, uniq$extra$lhs_form)
  expect_identical(wide$extra$slope_col, uniq$extra$slope_col)
})

test_that("indep(1 + x || g) requires an intercept-and-slope LHS", {
  withr::local_options(lifecycle_verbosity = "quiet")
  ## No slope on the LHS: `||` has nothing to decorrelate.
  expect_error(
    gllvmTMB:::desugar_brms_sugar(value ~ 0 + trait + indep(0 + trait || individual)),
    "intercept-and-slope"
  )
})

test_that("latent(1 + x || g) fails loud: block-diagonal Lambda engine is pending", {
  withr::local_options(lifecycle_verbosity = "quiet")
  ## Ordinary `latent` fits the CORRELATED joint-Lambda slope; the `||` form
  ## must NOT silently route there. Fail loud until the constraint lands.
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + latent(1 + temperature || individual, d = 2)
    ),
    "not yet available"
  )
})

## ---------------------------------------------------------------------------
## 2. Recovery (heavy): indep(1 + x || g) recovers the diagonal Sigma_b.
## ---------------------------------------------------------------------------

test_that("indep(1 + x || g) Gaussian recovers per-trait diagonal (intercept, slope) SDs", {
  skip_if_not_heavy()
  skip_on_cran()

  set.seed(7903L)
  n_traits <- 2L
  n_site   <- 160L   # many sites -> intercept + slope variances estimable
  n_rep    <- 12L    # many x values per site -> slope variance well identified
  true_sd_int   <- c(0.60, 0.50)   # per-trait unit-tier INTERCEPT sd
  true_sd_slope <- c(0.45, 0.70)   # per-trait unit-tier SLOPE sd
  alpha    <- 1.0
  sd_resid <- 0.4

  traits <- letters[seq_len(n_traits)]
  grid <- expand.grid(
    rep = seq_len(n_rep), site = seq_len(n_site), trait_idx = seq_len(n_traits)
  )
  grid$trait <- factor(traits[grid$trait_idx], levels = traits)
  grid$x <- stats::rnorm(nrow(grid))

  ## Independent per-(site, trait) intercept and slope random effects -> the
  ## truth is a fully diagonal Sigma_b (no intercept-slope covariance).
  b_int <- vapply(seq_len(n_traits),
                  function(t) stats::rnorm(n_site, 0, true_sd_int[t]), numeric(n_site))
  b_slope <- vapply(seq_len(n_traits),
                    function(t) stats::rnorm(n_site, 0, true_sd_slope[t]), numeric(n_site))
  ij <- cbind(grid$site, grid$trait_idx)
  eta <- alpha + b_int[ij] + grid$x * b_slope[ij]
  grid$value <- eta + stats::rnorm(nrow(grid), 0, sd_resid)

  grid$site <- factor(grid$site)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + indep(1 + x || site),
      data = grid, family = gaussian(),
      unit = "site"
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    testthat::fail(sprintf(
      "indep(1 + x || site) aborted at construction: %s", conditionMessage(fit)
    ))
    return(invisible(NULL))
  }

  healthy <- isTRUE(fit$opt$convergence == 0L) &&
    is.finite(fit$opt$objective) &&
    (isTRUE(fit$fit_health$pd_hessian) || isTRUE(fit$sd_report$pdHess))
  if (!healthy) {
    skip("indep(1 + x || site) gaussian fixture did not converge / Hessian not PD")
  }

  expect_s3_class(fit, "gllvmTMB_multi")
  ## The bare `||` routed to the unit-tier diagonal augmented-slope engine.
  expect_true(isTRUE(fit$use$diag_B_slope))
  expect_identical(fit$use$diag_B_slope_col, "x")

  sd_slope_vec <- as.numeric(fit$report$sd_B_slope)
  expect_length(sd_slope_vec, 2L * n_traits)
  expect_true(all(is.finite(sd_slope_vec)))

  int_hat   <- sd_slope_vec[seq(1L, 2L * n_traits, by = 2L)]  # intercept SDs
  slope_hat <- sd_slope_vec[seq(2L, 2L * n_traits, by = 2L)]  # slope SDs

  for (t in seq_len(n_traits)) {
    expect_equal(int_hat[t], true_sd_int[t], tolerance = 0.20,
                 label = paste0("intercept sd_B_slope trait ", t))
    expect_equal(slope_hat[t], true_sd_slope[t], tolerance = 0.20,
                 label = paste0("slope sd_B_slope trait ", t))
  }

  ## The intercept-slope covariance is STRUCTURALLY zero on this path -- the
  ## diagonal engine reports no `cor_b`. That absence IS the `||` contract.
  expect_null(fit$report$cor_b)
})
