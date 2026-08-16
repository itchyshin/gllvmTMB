# predict_missing(se = TRUE): internal-only reconstruction standard errors
# (Design 119 Slice 1, docs/design/119-predict-missing-uncertainty.md).
#
# R1-quad route: se_confidence combines .gllvmTMB_predict_se_link()'s
# fixed-effect block with getLV(se = TRUE)'s latent-score curvature in
# quadrature; se_prediction adds the family noise variance (gaussian:
# sigma_eps^2). EXPERIMENTAL, heuristic_unvalidated -- no coverage evidence,
# no exported interval claim. Gaussian only in this slice.

# Small ordinary-latent (rr_B) gaussian fixture with a real between-site
# loadings term (`latent(..., unique = FALSE)` -- loadings only, no diag_B
# companion, so the SE decomposition here is exactly fixed + rr_B latent,
# with nothing else silently contributing).
.pm_se_data <- function(seed = 501, n_sites = 30, n_traits = 3) {
  simulate_site_trait(
    n_sites = n_sites, n_species = 1, n_traits = n_traits,
    mean_species_per_site = 1,
    Lambda_B = matrix(c(0.9, 0.6, -0.7)[seq_len(n_traits)], n_traits, 1),
    sigma2_eps = 0.4,
    seed = seed
  )$data
}

.pm_se_fit <- function(dat, missing = NULL, ...) {
  args <- list(
    formula = value ~ 0 + trait + (0 + trait):env_1 +
      latent(0 + trait | site, d = 1, unique = FALSE),
    data    = dat,
    family  = gaussian(),
    ...
  )
  if (!is.null(missing)) args$missing <- missing
  suppressMessages(suppressWarnings(do.call(gllvmTMB, args)))
}

# ---- (a) columns exist, finite, positive ----------------------------------

test_that("predict_missing(se = TRUE) returns finite, positive se columns", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm <- predict_missing(fit, se = TRUE)
  expect_true(all(c("se_confidence", "se_prediction") %in% names(pm)))
  expect_identical(nrow(pm), length(miss_idx))
  expect_true(all(is.finite(pm$se_confidence)))
  expect_true(all(is.finite(pm$se_prediction)))
  expect_true(all(pm$se_confidence > 0))
  expect_true(all(pm$se_prediction > 0))
})

# ---- (b) se_prediction > se_confidence strictly (V_family added) ----------

test_that("se_prediction strictly exceeds se_confidence (V_family adds noise variance)", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm <- predict_missing(fit, se = TRUE)
  expect_true(all(pm$se_prediction > pm$se_confidence))
})

# ---- (c) the latent block matters (the R1a defect this slice fixes) -------

test_that("se_confidence at masked rows strictly exceeds the fixed-only se.fit values", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm <- predict_missing(fit, se = TRUE)
  # .gllvmTMB_predict_se_link() is the pre-existing fixed-effect-only route
  # (what predict(se.fit = TRUE) already returns); R1a found it silently
  # under-states masked-cell uncertainty because it holds every random
  # effect at its conditional mode. If the latent block is wired correctly,
  # se_confidence must sit strictly above it at every masked row.
  se_fix_only <- gllvmTMB:::.gllvmTMB_predict_se_link(fit)
  expect_true(all(pm$se_confidence > se_fix_only[pm$model_row]))
  # Sanity: the rr_B term is actually active in this fixture (otherwise the
  # comparison above would be vacuously true-by-equality, not a real test).
  expect_true(isTRUE(fit$use$rr_B))
})

# ---- (d) non-gaussian family + se = TRUE aborts loudly --------------------

test_that("predict_missing(se = TRUE) aborts for a non-gaussian family, naming Design 119 Slice 3", {
  skip_if_not_heavy()
  set.seed(11)
  n <- 40
  dat <- data.frame(
    site = factor(seq_len(n)),
    env_1 = rnorm(n)
  )
  u <- rnorm(n, sd = 0.7)
  dat_wide <- data.frame(
    site = dat$site,
    t1 = rpois(n, exp(0.3 + 0.5 * dat$env_1 + u)),
    t2 = rpois(n, exp(0.1 - 0.3 * dat$env_1 + u)),
    t3 = rpois(n, exp(0.2 + 0.2 * dat$env_1 + u))
  )
  dat_wide$t1[c(2L, 9L)] <- NA_integer_

  fit_pois <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(t1, t2, t3) ~ 1 + latent(1 | site, d = 1, unique = FALSE),
    data    = dat_wide,
    unit    = "site",
    family  = poisson(),
    missing = miss_control(response = "include")
  )))

  err <- expect_error(
    predict_missing(fit_pois, se = TRUE),
    class = "gllvmTMB_predict_missing_se_family_unsupported"
  )
  expect_match(conditionMessage(err), "Design 119", fixed = TRUE)
  expect_match(conditionMessage(err), "Slice 3", fixed = TRUE)
})

# ---- (e) refusal set intact (reused from predict(se.fit = TRUE)) ----------

test_that("predict_missing(se = TRUE) refuses REML fits, same as predict(se.fit = TRUE)", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit_reml <- suppressWarnings(.pm_se_fit(
    dat_na,
    missing = miss_control(response = "include"),
    REML = TRUE
  ))

  expect_error(
    predict_missing(fit_reml, se = TRUE),
    class = "gllvmTMB_predict_se_reml_unsupported"
  )
})

test_that("predict_missing(se = FALSE) is unaffected -- no se columns, existing behaviour preserved", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm <- predict_missing(fit)
  expect_false(any(c("se_confidence", "se_prediction") %in% names(pm)))
  pm_explicit <- predict_missing(fit, se = FALSE)
  expect_identical(pm, pm_explicit)
})

# ---- (f) smoke: wide empirical-coverage band -------------------------------
#
# This is a SMOKE test, not a calibration claim: 30 replicates, a
# well-conditioned single-cell mask, and a deliberately wide [0.80, 1.00]
# nominal-95% band. The real gate is the Design 119 sec.4 coverage campaign
# (Totoro, separately approved, >=400 replicates per cell). This only checks
# that se_confidence is not wildly miscalibrated in an easy case.
#
# The DGP is written out here (rather than via simulate_site_trait()) so
# eta_true -- fixed effect PLUS the realised latent-score contribution -- is
# known exactly for the masked cell, not just its fixed-effect part.

test_that("smoke: eta_true empirical coverage under se_confidence lands in a wide band", {
  skip_if_not_heavy()
  n_rep <- 30
  n <- 25
  alpha <- c(0.5, -0.2, 0.3)
  beta  <- c(0.4, -0.3, 0.2)
  lam   <- c(0.9, 0.6, -0.7)
  sigma_eps_true <- 0.5
  covered <- logical(n_rep)

  for (r in seq_len(n_rep)) {
    set.seed(9000 + r)
    env_1 <- rnorm(n)
    u <- rnorm(n)   # d = 1 site-level latent-score draw
    eta_mat <- vapply(
      seq_along(alpha),
      function(t) alpha[t] + beta[t] * env_1 + lam[t] * u,
      numeric(n)
    )
    y_mat <- eta_mat + matrix(rnorm(n * 3, sd = sigma_eps_true), n, 3)

    dat <- data.frame(
      site  = factor(rep(seq_len(n), times = 3)),
      trait = factor(
        rep(paste0("trait_", 1:3), each = n),
        levels = paste0("trait_", 1:3)
      ),
      env_1 = rep(env_1, times = 3),
      value = as.vector(y_mat)
    )
    # Mask the trait-1 cell at site 1 every rep.
    miss_row <- which(dat$site == "1" & dat$trait == "trait_1")
    eta_true <- eta_mat[1L, 1L]
    dat_na <- dat
    dat_na$value[miss_row] <- NA_real_

    fit <- suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + (0 + trait):env_1 +
        latent(0 + trait | site, d = 1, unique = FALSE),
      data    = dat_na,
      family  = gaussian(),
      missing = miss_control(response = "include")
    )))

    pm <- predict_missing(fit, se = TRUE)
    row_i <- which(pm$model_row == miss_row)
    lo <- pm$est[row_i] - 1.96 * pm$se_confidence[row_i]
    hi <- pm$est[row_i] + 1.96 * pm$se_confidence[row_i]
    covered[r] <- eta_true >= lo && eta_true <= hi
  }

  coverage <- mean(covered)
  expect_gte(coverage, 0.80)
  expect_lte(coverage, 1.00)
})

# ---- R1-joint route (Design 119 sec.7 wave-1 route change) ----------------
#
# Wave-1 coverage (dev/cov119/, Totoro, 1,600 gaussian fits) found
# se_confidence under route = "quad" systematically OVER-covers (95% CI
# coverage 0.960-0.966; gap >> 2x MCSE): the diagonal conditional latent
# variance plus the full fixed block double-counts shared information.
# route = "joint" replaces the quadrature approximation with the exact
# w' Q^{-1} w joint-precision variance (Q from
# TMB::sdreport(obj, getJointPrecision = TRUE)).

test_that("se_route = 'joint' returns finite, positive se columns", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm <- predict_missing(fit, se = TRUE, se_route = "joint")
  expect_true(all(c("se_confidence", "se_prediction") %in% names(pm)))
  expect_identical(nrow(pm), length(miss_idx))
  expect_true(all(is.finite(pm$se_confidence)))
  expect_true(all(is.finite(pm$se_prediction)))
  expect_true(all(pm$se_confidence > 0))
  expect_true(all(pm$se_prediction > 0))
})

test_that("route = 'joint' one-cell numeric cross-check against a dense jointPrecision solve", {
  skip_if_not_heavy()
  # Tiny fixture, hand-written DGP (mirrors the smoke test above) so the
  # gradient-vector construction can be brute-forced independently.
  set.seed(1)
  n <- 12
  alpha <- c(0.5, -0.2, 0.3); beta <- c(0.4, -0.3, 0.2); lam <- c(0.9, 0.6, -0.7)
  env_1 <- rnorm(n); u <- rnorm(n)
  eta_mat <- vapply(
    seq_along(alpha),
    function(t) alpha[t] + beta[t] * env_1 + lam[t] * u,
    numeric(n)
  )
  y_mat <- eta_mat + matrix(rnorm(n * 3, sd = 0.5), n, 3)
  dat <- data.frame(
    site  = factor(rep(seq_len(n), times = 3)),
    trait = factor(
      rep(paste0("trait_", 1:3), each = n),
      levels = paste0("trait_", 1:3)
    ),
    env_1 = rep(env_1, times = 3),
    value = as.vector(y_mat)
  )
  dat$value[c(1L, 5L)] <- NA_real_

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
      latent(0 + trait | site, d = 1, unique = FALSE),
    data    = dat,
    family  = gaussian(),
    missing = miss_control(response = "include")
  )))

  masked_rows <- which(fit$tmb_data$is_y_observed == 0L)
  expect_length(masked_rows, 2L)

  # The package's sparse-solve route.
  var_sparse <- gllvmTMB:::.gllvmTMB_predict_missing_var_eta_joint(
    fit, masked_rows, length(fit$report$eta)
  )[masked_rows]

  # Independent brute-force: build the same w vectors and solve against a
  # DENSE inverse of the joint precision (the "never a dense inverse in
  # production code" rule applies only to the package's own implementation
  # -- this test is explicitly allowed a dense solve to cross-check it).
  sdr <- TMB::sdreport(fit$tmb_obj, getJointPrecision = TRUE)
  Q <- sdr$jointPrecision
  Qinv_dense <- solve(as.matrix(Q))
  par_names <- rownames(Q)
  status <- gllvmTMB:::.gllvmTMB_xcoef_status(fit)
  free <- status != "fixed"
  Xf <- fit$X_fix[, free, drop = FALSE]
  bfix_pos <- which(par_names == "b_fix")
  zB_pos_mat <- matrix(
    which(par_names == "z_B"), nrow = fit$d_B, ncol = fit$n_sites
  )
  Lambda <- fit$report$Lambda_B
  trait_id <- as.integer(fit$data[[fit$trait_col]])
  unit_id  <- as.integer(fit$data[[fit$unit_col]])

  var_dense <- vapply(masked_rows, function(i) {
    w <- rep(0, nrow(Qinv_dense))
    w[bfix_pos] <- Xf[i, ]
    w[zB_pos_mat[, unit_id[i]]] <- Lambda[trait_id[i], ]
    as.numeric(t(w) %*% Qinv_dense %*% w)
  }, numeric(1))

  expect_equal(var_sparse, var_dense, tolerance = 1e-6)
})

test_that("mean se under 'joint' is smaller than under 'quad' (the double-count is removed)", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm_quad  <- predict_missing(fit, se = TRUE, se_route = "quad")
  pm_joint <- predict_missing(fit, se = TRUE, se_route = "joint")
  expect_lt(mean(pm_joint$se_confidence), mean(pm_quad$se_confidence))
})

test_that("route = 'quad' is unchanged by the joint-route addition (regression guard)", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm_default <- predict_missing(fit, se = TRUE)
  pm_quad    <- predict_missing(fit, se = TRUE, se_route = "quad")
  expect_identical(pm_default, pm_quad)

  # Pinned values (computed once, on this seeded fixture, from the R1-quad
  # implementation the joint-route addition left untouched). A future change
  # to the quad math should show up here, not just as "still finite".
  expect_equal(
    pm_quad$se_confidence,
    c(0.317298536777259, 0.223280793541261, 0.251703705707742, 0.207706175508292),
    tolerance = 1e-9
  )
  expect_equal(
    pm_quad$se_prediction,
    c(0.775704356618387, 0.742221799868591, 0.75126136790252, 0.737686073326613),
    tolerance = 1e-9
  )
})
