## Redraw-recovery unit test for the unconditional-simulate "spde" branch
## (issue #750): the base per-trait SPDE spatial field (spde_lv_k == 0).
## Mirrors the mock-fit style used for the propto / phylo_rr precision-
## Cholesky branches (test-stage3-propto-equalto.R): build a tiny REAL
## mesh via make_mesh(), hand-build a minimal `fit` list carrying only
## the `tmb_data` / `report` fields .simulate_eta_unconditional() reads
## for the "spde" branch, call it many times, and check the empirical
## covariance of the redrawn field against the theoretical
## tau_t^-2 * A_proj Q_base^-1 A_proj^T (ground truth: src/gllvmTMB.cpp
## ~l.1443-1454 and ~l.1868-1871).

make_mock_spde_fit <- function(n_site = 6L, n_traits = 2L, kappa = 1.3,
                               tau = c(2.0, 0.6), seed = 1) {
  set.seed(seed)
  site_xy <- data.frame(x = stats::runif(n_site), y = stats::runif(n_site))
  ## cutoff = 0.08 verified (seed 1) to fully cover every site with a
  ## proper barycentric projection (rowSums(A_st) == 1); a coarser cutoff
  ## can leave an input point outside every mesh triangle (A_st row of
  ## all zeros), which would degenerate the covariance check below.
  mesh <- make_mesh(site_xy, c("x", "y"), cutoff = 0.08)
  A_site_sparse <- mesh$A_st # n_site x n_mesh -- one row per site
  A_site <- as.matrix(A_site_sparse) # dense copy for the test's own math
  n_mesh <- ncol(A_site)

  ## Long-format layout: trait varies slowest (block by trait), site
  ## fastest within a trait block -- same site location repeats across
  ## traits, so its A_proj row is IDENTICAL across traits (real models
  ## build the mesh on the repeated long-format coordinates; repeating
  ## A_site's rows here is numerically equivalent and avoids relying on
  ## fmesher's handling of literal duplicate point locations).
  trait_id0 <- rep(0:(n_traits - 1L), each = n_site) # 0-indexed
  site_rep <- rep(seq_len(n_site), times = n_traits)
  A_proj <- A_site_sparse[site_rep, , drop = FALSE]
  n_obs <- n_traits * n_site

  fit <- list(
    use = list(spde = TRUE),
    tmb_data = list(
      X_fix = matrix(0, n_obs, 0),
      trait_id = trait_id0,
      n_traits = n_traits,
      spde_lv_k = 0L,
      spde_M0 = mesh$spde$c0,
      spde_M1 = mesh$spde$g1,
      spde_M2 = mesh$spde$g2,
      A_proj = A_proj
    ),
    X_fix_names = character(0),
    report = list(
      kappa = kappa,
      log_tau_spde = log(tau)
    )
  )
  list(
    fit = fit, A_site = A_site, n_mesh = n_mesh, n_site = n_site,
    n_traits = n_traits, trait_id0 = trait_id0, kappa = kappa, tau = tau
  )
}

test_that(".simulate_eta_unconditional() spde branch recovers the per-trait field covariance", {
  setup <- make_mock_spde_fit()
  fit <- setup$fit

  ## can_redraw must be TRUE for the base per-trait spde tier.
  chk <- gllvmTMB:::.check_simulate_unconditional(fit)
  expect_true(chk$can_redraw)
  expect_length(chk$unhandled, 0L)

  nrep <- 4000L
  set.seed(2026)
  eta_mat <- replicate(nrep, gllvmTMB:::.simulate_eta_unconditional(fit))
  expect_equal(dim(eta_mat), c(setup$n_traits * setup$n_site, nrep))

  Qb <- setup$kappa^4 * fit$tmb_data$spde_M0 +
    2 * setup$kappa^2 * fit$tmb_data$spde_M1 +
    fit$tmb_data$spde_M2
  Qb_inv <- solve(as.matrix(Qb))
  A_site <- setup$A_site

  for (tr in seq_len(setup$n_traits)) {
    rows <- setup$trait_id0 == (tr - 1L)
    eta_tr <- eta_mat[rows, , drop = FALSE]
    cov_emp <- cov(t(eta_tr))
    cov_theory <- (1 / setup$tau[tr]^2) * (A_site %*% Qb_inv %*% t(A_site))
    rel_err <- norm(cov_emp - as.matrix(cov_theory), "F") /
      norm(as.matrix(cov_theory), "F")
    expect_lt(rel_err, 0.3)
  }

  ## Cross-trait independence: traits 1 and 2 are drawn from independent
  ## GMRFs, so the empirical cross-correlation should be close to zero.
  rows1 <- setup$trait_id0 == 0L
  rows2 <- setup$trait_id0 == 1L
  cross_cor <- stats::cor(t(eta_mat[rows1, , drop = FALSE]),
                          t(eta_mat[rows2, , drop = FALSE]))
  expect_lt(max(abs(cross_cor)), 0.15)
})

test_that(".check_simulate_unconditional() keeps spatial_latent (spde_lv_k > 0) fail-closed", {
  setup <- make_mock_spde_fit()

  ## Base per-trait path: spde_lv_k == 0, "spde" alone active -> redrawable.
  fit_base <- setup$fit
  expect_true(gllvmTMB:::.check_simulate_unconditional(fit_base)$can_redraw)

  ## Reduced-rank spatial_latent path (spde_lv_k > 0): the "spatial_latent"
  ## sub-flag must keep the whitelist closed even though the base "spde"
  ## engine flag is also TRUE (this is the non-negotiable fail-closed
  ## boundary -- the redraw math above does not cover this tier).
  fit_latent <- setup$fit
  fit_latent$use$spatial_latent <- TRUE
  fit_latent$tmb_data$spde_lv_k <- 1L
  chk_latent <- gllvmTMB:::.check_simulate_unconditional(fit_latent)
  expect_false(chk_latent$can_redraw)
  expect_true("spatial_latent" %in% chk_latent$unhandled)

  ## Augmented spatial random-slope tiers (Design 60/64) ride on
  ## DIFFERENT flag names entirely and must also stay fail-closed.
  for (flag in c("spde_slope", "spde_dep_slope", "spde_latent_slope")) {
    fit_slope <- setup$fit
    fit_slope$use$spde <- FALSE # the slope engines turn the base flag off
    fit_slope$use[[flag]] <- TRUE
    chk_slope <- gllvmTMB:::.check_simulate_unconditional(fit_slope)
    expect_false(chk_slope$can_redraw, info = flag)
    expect_true(flag %in% chk_slope$unhandled, info = flag)
  }
})
