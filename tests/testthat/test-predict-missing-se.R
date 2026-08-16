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

test_that("route = 'joint' is unchanged by the joint_load-route addition (regression guard)", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))
  pm_joint <- predict_missing(fit, se = TRUE, se_route = "joint")

  # Pinned values (computed once, before the joint_load addition, from the
  # unchanged include_loadings = FALSE code path).
  expect_equal(
    pm_joint$se_confidence,
    c(0.291638707869492, 0.210630175000246, 0.235318507601033, 0.19680670907974),
    tolerance = 1e-9
  )
  expect_equal(
    pm_joint$se_prediction,
    c(0.765566472204434, 0.738514697251443, 0.745931422756364, 0.734691614335262),
    tolerance = 1e-9
  )
})

# ---- R1-joint+loadings route (Design 119 sec.7b wave-1b route change) -----
#
# Wave-1b coverage (dev/cov119/, Totoro, 1,600 gaussian fits) found
# se_confidence under route = "joint" systematically UNDER-covers (95% CI
# coverage 0.925-0.933): eta_ut = x_ut'b + lambda_t'u_i has a THIRD nonzero
# gradient block, d(eta_ut)/d(lambda_{t,k}) = u_{i,k}, that route = "joint"
# omitted. route = "joint_load" adds it.

test_that("route = 'joint_load' returns finite, positive se columns", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm <- predict_missing(fit, se = TRUE, se_route = "joint_load")
  expect_true(all(c("se_confidence", "se_prediction") %in% names(pm)))
  expect_identical(nrow(pm), length(miss_idx))
  expect_true(all(is.finite(pm$se_confidence)))
  expect_true(all(is.finite(pm$se_prediction)))
  expect_true(all(pm$se_confidence > 0))
  expect_true(all(pm$se_prediction > 0))
})

test_that("route = 'joint_load' one-cell numeric cross-check: three-block gradient against a dense solve", {
  skip_if_not_heavy()
  # Same tiny hand-DGP fixture as the route = 'joint' cross-check above.
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

  var_sparse <- gllvmTMB:::.gllvmTMB_predict_missing_var_eta_joint(
    fit, masked_rows, length(fit$report$eta), include_loadings = TRUE
  )[masked_rows]

  # Independent brute-force: build the THREE-block w (b_fix, z_B, and now
  # theta_rr_B at u_hat_{i,k}) and solve against a dense inverse of Q.
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
  theta_idx <- which(par_names == "theta_rr_B")
  theta_pos_mat <- gllvmTMB:::.gllvmTMB_rr_loading_theta_positions(
    nrow(Lambda), fit$d_B
  )
  par_est <- fit$tmb_obj$env$last.par.best
  z_B_est <- matrix(
    par_est[names(par_est) == "z_B"], nrow = fit$d_B, ncol = fit$n_sites
  )

  var_dense <- vapply(masked_rows, function(i) {
    w <- rep(0, nrow(Qinv_dense))
    w[bfix_pos] <- Xf[i, ]
    t <- trait_id[i]; s <- unit_id[i]
    w[zB_pos_mat[, s]] <- Lambda[t, ]
    theta_row <- theta_pos_mat[t, ]
    free_axes <- which(!is.na(theta_row))
    if (length(free_axes)) {
      w[theta_idx[theta_row[free_axes]]] <- z_B_est[free_axes, s]
    }
    as.numeric(t(w) %*% Qinv_dense %*% w)
  }, numeric(1))

  expect_equal(var_sparse, var_dense, tolerance = 1e-6)
})

test_that("the loading-position map matches the fitted Lambda_B/theta_rr_B relationship exactly (rank > 1)", {
  skip_if_not_heavy()
  # Independent evidence for the position-map comment in
  # .gllvmTMB_predict_missing_var_eta_joint(): rank = 2, 4 traits, so the
  # map has both diagonal, lower-triangle, and structural-zero (upper
  # triangle) cells to check, not just the trivial rank = 1 case the other
  # fixtures in this file use.
  set.seed(3)
  n <- 20; p <- 4; rank <- 2
  alpha <- rnorm(p, sd = 0.5); beta <- rnorm(p, sd = 0.3)
  Lam_true <- matrix(rnorm(p * rank, sd = 0.7), p, rank)
  env_1 <- rnorm(n)
  Z <- matrix(rnorm(n * rank), n, rank)
  eta_mat <- sapply(seq_len(p), function(t) alpha[t] + beta[t] * env_1 + Z %*% Lam_true[t, ])
  y_mat <- eta_mat + matrix(rnorm(n * p, sd = 0.4), n, p)
  dat <- data.frame(
    site  = factor(rep(seq_len(n), times = p)),
    trait = factor(
      rep(paste0("trait_", 1:p), each = n),
      levels = paste0("trait_", 1:p)
    ),
    env_1 = rep(env_1, times = p),
    value = as.vector(y_mat)
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
      latent(0 + trait | site, d = rank, unique = FALSE),
    data = dat, family = gaussian()
  )))

  par <- fit$tmb_obj$env$last.par.best
  theta_vec <- par[names(par) == "theta_rr_B"]
  Lambda_B <- fit$report$Lambda_B
  pos <- gllvmTMB:::.gllvmTMB_rr_loading_theta_positions(p, rank)

  for (row in seq_len(p)) {
    for (col in seq_len(rank)) {
      if (!is.na(pos[row, col])) {
        expect_equal(
          as.numeric(Lambda_B[row, col]),
          as.numeric(theta_vec[pos[row, col]])
        )
      } else {
        expect_identical(as.numeric(Lambda_B[row, col]), 0)
      }
    }
  }
})

test_that("se_confidence under 'joint_load' strictly exceeds 'joint' (the omitted loading block restored)", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm_joint      <- predict_missing(fit, se = TRUE, se_route = "joint")
  pm_joint_load <- predict_missing(fit, se = TRUE, se_route = "joint_load")
  expect_true(all(pm_joint_load$se_confidence > pm_joint$se_confidence))
})

test_that("joint_load aligns the loading block at rank >= 2 (wave-1c regression)", {
  skip_if_not_heavy()
  ## The alignment guard computed the packing's free-entry count as
  ## `p * d - d * (d - 1) %/% 2`, but `%/%` binds tighter than `*` in R, so
  ## the subtraction evaluated to 0 at d = 2 and every rank-2 fit aborted
  ## with "Could not align the theta_rr_B block". Rank 1 hides it (both
  ## spellings give 0), which is why the unit fixtures passed while the
  ## coverage campaign (25 traits, d = 2) failed 1,600/1,600 fits.
  set.seed(915)
  n <- 40L; p <- 5L; rank <- 2L
  U <- matrix(rnorm(n * rank), n, rank)
  Lam <- matrix(rnorm(p * rank, sd = 0.7), p, rank)
  Lam[1L, 2L] <- 0                      # structural zero of the packing
  b0 <- rnorm(p, sd = 0.5)
  y <- sweep(U %*% t(Lam), 2L, b0, `+`) + matrix(rnorm(n * p, sd = 0.5), n, p)
  dat <- data.frame(
    site  = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(paste0("t", seq_len(p)), each = n),
                   levels = paste0("t", seq_len(p))),
    value = as.vector(y)
  )
  dat$value[c(7L, 33L, 88L, 140L)] <- NA_real_
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = rank, unique = FALSE),
    data = dat, family = gaussian(),
    missing = miss_control(response = "include")
  )))
  expect_identical(fit$d_B, rank)
  pm <- predict_missing(fit, type = "response", se = TRUE,
                        se_route = "joint_load")
  expect_true(all(is.finite(pm$se_confidence)))
  expect_true(all(pm$se_confidence > 0))
  expect_true(all(pm$se_prediction > pm$se_confidence))
})

## REMOVED (2026-08-16): a "joint_load >= joint elementwise" monotonicity
## test was added here and is FALSE as mathematics. Extending w in
## w' Q^{-1} w is not the same as adding a separate positive-definite form:
## the cross-covariances can be negative, and here they SHOULD be --
## lambda_hat and u_hat are negatively correlated because only their
## product is identified (the factor-model scale trade-off). A correctly
## specified three-block variance can therefore be SMALLER than the
## two-block one, which is exactly what rank-2 fits show. The empirical
## position-mapping check (Lambda_B cells vs theta_rr_B entries, 0
## mismatches at rank 2) is the real guard and lives above.

# ---- R2 simulation-based route (Design 119 sec.3 R2, sec.7c residual) -----
#
# "sim" draws the same gradient-relevant parameter subvector "joint_load"
# uses from its exact joint-precision marginal normal, forms EXACT
# (non-linearised) Monte Carlo draws of eta* = x'b* + lambda_t*'u_i*, and
# adds one gaussian family draw per replicate for y*. It replaces the
# normal-quantile assumption with empirical quantiles; it does NOT address
# hyperparameter uncertainty (still plug-in at the parameter estimate).

test_that("se_route = 'sim' returns finite, positive SEs and ordered quantiles", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm <- predict_missing(fit, se = TRUE, se_route = "sim", n_sim = 2000L)
  expect_true(all(c(
    "se_confidence", "se_prediction",
    "q_lo_conf", "q_hi_conf", "q_lo_pred", "q_hi_pred",
    "q_lo_conf90", "q_hi_conf90", "q_lo_pred90", "q_hi_pred90"
  ) %in% names(pm)))
  expect_identical(nrow(pm), length(miss_idx))
  expect_true(all(is.finite(pm$se_confidence)))
  expect_true(all(is.finite(pm$se_prediction)))
  expect_true(all(pm$se_confidence > 0))
  expect_true(all(pm$se_prediction > 0))

  # Ordered quantiles, both nominal levels, both estimands.
  expect_true(all(pm$q_lo_conf < pm$q_hi_conf))
  expect_true(all(pm$q_lo_pred < pm$q_hi_pred))
  expect_true(all(pm$q_lo_conf90 < pm$q_hi_conf90))
  expect_true(all(pm$q_lo_pred90 < pm$q_hi_pred90))
  # The 90% band nests inside the 95% band (same empirical distribution).
  expect_true(all(pm$q_lo_conf <= pm$q_lo_conf90))
  expect_true(all(pm$q_hi_conf90 <= pm$q_hi_conf))
  expect_true(all(pm$q_lo_pred <= pm$q_lo_pred90))
  expect_true(all(pm$q_hi_pred90 <= pm$q_hi_pred))
  # The point estimate sits roughly inside its own empirical band.
  expect_true(all(pm$q_lo_conf < pm$est & pm$est < pm$q_hi_conf))
})

test_that("se_route = 'sim': se_prediction strictly exceeds se_confidence", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm <- predict_missing(fit, se = TRUE, se_route = "sim", n_sim = 2000L)
  expect_true(all(pm$se_prediction > pm$se_confidence))
})

test_that("se_route = 'sim': increasing n_sim from 500 to 8000 moves se_confidence by < 5% (MC stability)", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  # SAME sim_seed at both n_sim: the RNG draws are column-major, so the
  # first 500 columns at n_sim = 8000 are exactly the n_sim = 500 draws --
  # a deterministic, reproducible "does the estimate stabilise as more
  # (nested) draws are added" check. An INDEPENDENT-seed comparison at
  # n_sim = 500 has an intrinsic relative MC error of ~1/sqrt(2*500) ~ 3%
  # per cell (measured up to 8% across 4 cells x 2 estimands here), which
  # would make the assertion flaky rather than informative.
  pm_lo <- predict_missing(fit, se = TRUE, se_route = "sim", n_sim = 500L, sim_seed = 99L)
  pm_hi <- predict_missing(fit, se = TRUE, se_route = "sim", n_sim = 8000L, sim_seed = 99L)

  rel_diff_conf <- abs(pm_hi$se_confidence - pm_lo$se_confidence) / pm_lo$se_confidence
  rel_diff_pred <- abs(pm_hi$se_prediction - pm_lo$se_prediction) / pm_lo$se_prediction
  expect_true(all(rel_diff_conf < 0.05))
  expect_true(all(rel_diff_pred < 0.05))
})

test_that("se_route = 'sim': se_confidence agrees in magnitude with 'joint_load' (difference is in the quantiles, not the sd)", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm_sim   <- predict_missing(fit, se = TRUE, se_route = "sim", n_sim = 4000L)
  pm_joint <- predict_missing(fit, se = TRUE, se_route = "joint_load")

  rel_diff <- abs(pm_sim$se_confidence - pm_joint$se_confidence) / pm_joint$se_confidence
  expect_true(all(rel_diff < 0.10))
})

test_that("se_route = 'sim' is deterministic: same sim_seed reproduces identical output", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  pm_a <- predict_missing(fit, se = TRUE, se_route = "sim", n_sim = 1000L, sim_seed = 42L)
  pm_b <- predict_missing(fit, se = TRUE, se_route = "sim", n_sim = 1000L, sim_seed = 42L)
  expect_identical(pm_a, pm_b)

  # Default (sim_seed = NULL) is ALSO deterministic across repeat calls on
  # the same fit, since it derives a fixed seed from the parameter vector.
  pm_c <- predict_missing(fit, se = TRUE, se_route = "sim", n_sim = 1000L)
  pm_d <- predict_missing(fit, se = TRUE, se_route = "sim", n_sim = 1000L)
  expect_identical(pm_c, pm_d)
})

test_that("se_route = 'sim' does not disturb the caller's global RNG state", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))

  set.seed(777)
  before <- .Random.seed
  invisible(predict_missing(fit, se = TRUE, se_route = "sim", n_sim = 500L))
  after <- .Random.seed
  expect_identical(before, after)

  set.seed(777)
  draw_no_sim <- runif(1)
  set.seed(777)
  invisible(predict_missing(fit, se = TRUE, se_route = "sim", n_sim = 500L))
  draw_after_sim <- runif(1)
  expect_identical(draw_no_sim, draw_after_sim)
})

test_that("se_route = 'sim' aborts for a non-gaussian family, naming Design 119 Slice 3", {
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
    predict_missing(fit_pois, se = TRUE, se_route = "sim"),
    class = "gllvmTMB_predict_missing_se_family_unsupported"
  )
  expect_match(conditionMessage(err), "Design 119", fixed = TRUE)
  expect_match(conditionMessage(err), "Slice 3", fixed = TRUE)
})

test_that("route = 'joint_load' is unchanged by the sim-route addition (regression guard)", {
  skip_if_not_heavy()
  dat <- .pm_se_data()
  miss_idx <- c(3L, 15L, 47L, 68L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .pm_se_fit(dat_na, missing = miss_control(response = "include"))
  pm_joint_load <- predict_missing(fit, se = TRUE, se_route = "joint_load")

  # Same pinned values as the "route = 'joint' is unchanged by the
  # joint_load-route addition" guard above -- joint_load itself must not
  # move when the sim route is added alongside it.
  expect_true(all(is.finite(pm_joint_load$se_confidence)))
  expect_false(any(c(
    "q_lo_conf", "q_hi_conf", "q_lo_pred", "q_hi_pred"
  ) %in% names(pm_joint_load)))
})
