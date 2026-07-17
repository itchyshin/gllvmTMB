# Stage 3: propto() (phylogenetic random effect) and equalto() (known V).
# Cross-validate against glmmTMB on identical formulas.

skip_if_not_glmmTMB <- function() {
  testthat::skip_if_not_installed("glmmTMB")
  testthat::skip_if_not_installed("ape")
}

simulate_phylo_data <- function(n_sites = 50, n_species = 12, n_traits = 3,
                                sigma2_phy = c(0.6, 0.6, 0.6), seed = 11) {
  set.seed(seed)
  tree <- ape::rcoal(n_species)
  tree$tip.label <- paste0("sp", seq_len(n_species))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- simulate_site_trait(
    n_sites = n_sites, n_species = n_species, n_traits = n_traits,
    mean_species_per_site = 5,
    Cphy = Cphy, sigma2_phy = sigma2_phy,
    seed = seed
  )
  df <- sim$data
  levels(df$species) <- paste0("sp", seq_len(n_species))
  list(data = df, Cphy = Cphy, sim = sim)
}

test_that("Sparse propto precision resolver marginalizes extra precision nodes", {
  node_names <- c("sp1", "sp2", "sp3", "sp4")
  basis <- matrix(c(
    1.2, 0.3, 0.2, 0.1,
    0.0, 1.1, 0.4, 0.2,
    0.2, 0.1, 1.0, 0.3,
    0.1, 0.3, 0.2, 0.9
  ), nrow = 4L, byrow = TRUE)
  C_full <- crossprod(basis) + diag(c(0.8, 0.7, 0.9, 0.6))
  dimnames(C_full) <- list(node_names, node_names)
  Ainv_full <- Matrix::Matrix(solve(C_full), sparse = TRUE)
  levs <- c("sp2", "sp4")

  resolved <- gllvmTMB:::.resolve_sparse_propto_precision(Ainv_full, levs)
  C_tip <- C_full[levs, levs, drop = FALSE] + diag(1e-8, length(levs))
  wrong_precision_subset <- as.matrix(Ainv_full[levs, levs, drop = FALSE])

  expect_equal(
    unname(resolved$Cphy_inv),
    unname(solve(C_tip)),
    tolerance = 1e-8
  )
  expect_equal(
    unname(resolved$log_det_Cphy),
    unname(as.numeric(determinant(C_tip, logarithm = TRUE)$modulus)),
    tolerance = 1e-8
  )
  expect_false(isTRUE(all.equal(
    unname(resolved$Cphy_inv),
    unname(wrong_precision_subset),
    tolerance = 1e-6
  )))
})

test_that("Sparse propto precision resolver preserves tip-only precision path", {
  levs <- c("sp2", "sp4")
  C_tip <- matrix(c(1.5, 0.35, 0.35, 1.1), nrow = 2L)
  dimnames(C_tip) <- list(levs, levs)
  Ainv_tip <- Matrix::Matrix(solve(C_tip), sparse = TRUE)
  Ainv_tip <- Ainv_tip[rev(levs), rev(levs), drop = FALSE]

  resolved <- gllvmTMB:::.resolve_sparse_propto_precision(Ainv_tip, levs)

  expect_equal(
    unname(resolved$Cphy_inv),
    unname(solve(C_tip)),
    tolerance = 1e-10
  )
  expect_equal(
    unname(resolved$log_det_Cphy),
    unname(as.numeric(determinant(C_tip, logarithm = TRUE)$modulus)),
    tolerance = 1e-10
  )
})

test_that("Stage 3: propto simulation uses lambda as variance, not sd", {
  n_species <- 40L
  n_draw <- 1000L
  lambda <- 4
  fit <- list(
    X_fix_names = character(0),
    opt = list(par = numeric(0)),
    use = list(
      rr_B = FALSE, diag_B = FALSE,
      rr_W = FALSE, diag_W = FALSE,
      propto = TRUE
    ),
    tmb_data = list(
      X_fix = matrix(numeric(0), n_species, 0L),
      trait_id = rep(0L, n_species),
      n_traits = 1L,
      species_id = seq_len(n_species) - 1L,
      n_species = n_species,
      Cphy_inv = diag(n_species)
    ),
    report = list(lam_phy = lambda)
  )

  set.seed(596)
  eta_draws <- replicate(n_draw, gllvmTMB:::.simulate_eta_unconditional(fit))
  empirical_var <- stats::var(as.numeric(eta_draws))

  expect_gt(empirical_var, 3.6)
  expect_lt(empirical_var, 4.4)
})

test_that("phylo_diag unconditional redraw recovers sd_phy_diag[t]^2 * A per trait", {
  ## phylo_diag is diagonal ACROSS traits but phylogenetically correlated WITHIN
  ## each trait: eta[obs] = sd_phy_diag[t] * g_t[species], with g_t ~ N(0, A) and
  ## the SAME precision Ainv_phy_rr = A^{-1} shared across traits. Mock a fit so
  ## the redraw branch fires in isolation (mirrors the propto mock above) and
  ## check the empirical per-trait species (co)variance against sd^2 * A, and
  ## that the two traits are independent (the "diagonal across traits" property).
  n_sp <- 6L
  n_traits <- 2L
  n_obs <- n_sp * n_traits
  sd_pd <- c(1.4, 0.7)
  ## AR(1)-style correlation matrix stands in for a phylogenetic A (PD, unit diag).
  A <- 0.6^abs(outer(seq_len(n_sp), seq_len(n_sp), "-"))
  Ainv <- solve(A)
  ## Trait-major observation grid: rows 1:n_sp are trait 1 over species 1..n_sp,
  ## rows (n_sp+1):(2 n_sp) are trait 2 over species 1..n_sp.
  fit <- list(
    X_fix_names = character(0),
    opt = list(par = numeric(0)),
    use = list(phylo_diag = TRUE),
    tmb_data = list(
      X_fix = matrix(numeric(0), n_obs, 0L),
      trait_id = rep(0:(n_traits - 1L), each = n_sp),      # 0-indexed
      n_traits = n_traits,
      n_aug_phy = n_sp,
      Ainv_phy_rr = Ainv,
      species_aug_id = rep(0:(n_sp - 1L), times = n_traits) # 0-indexed
    ),
    report = list(sd_phy_diag = sd_pd)
  )

  set.seed(4242)
  n_draw <- 4000L
  eta_draws <- replicate(n_draw, gllvmTMB:::.simulate_eta_unconditional(fit))
  blk1 <- eta_draws[seq_len(n_sp), , drop = FALSE]
  blk2 <- eta_draws[n_sp + seq_len(n_sp), , drop = FALSE]
  emp1 <- stats::cov(t(blk1))
  emp2 <- stats::cov(t(blk2))
  emp_cross <- stats::cov(t(blk1), t(blk2))

  expect_lt(max(abs(emp1 - sd_pd[1]^2 * A)), 0.2)
  expect_lt(max(abs(emp2 - sd_pd[2]^2 * A)), 0.2)
  ## Diagonal ACROSS traits: independent draws per trait -> ~0 cross-covariance.
  expect_lt(max(abs(emp_cross)), 0.15)
})

test_that("Stage 3: propto() matches glmmTMB log-likelihood exactly", {
  skip_if_not_glmmTMB()
  s <- simulate_phylo_data()
  df <- s$data; Cphy <- s$Cphy
  fit_g <- gllvmTMB(
    value ~ 0 + trait + propto(0 + species | trait, Cphy),
    data = df, phylo_vcv = Cphy
  )
  expect_s3_class(fit_g, "gllvmTMB_multi")
  expect_equal(fit_g$opt$convergence, 0L)

  ll_g <- -fit_g$opt$objective
  fit_t <- suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + propto(0 + species | trait, Cphy),
    data = df, REML = FALSE
  ))
  ll_t <- as.numeric(stats::logLik(fit_t))
  testthat::skip_if(is.na(ll_t),
                    "glmmTMB hit non-PD Hessian on this dataset")
  expect_equal(ll_g, ll_t, tolerance = 1e-4)
})

test_that("Stage 3: propto() recovers loglambda_phy reasonably", {
  s <- simulate_phylo_data(sigma2_phy = c(0.8, 0.8, 0.8), seed = 23)
  fit_g <- gllvmTMB(
    value ~ 0 + trait + propto(0 + species | trait, Cphy),
    data = s$data, phylo_vcv = s$Cphy
  )
  expect_equal(fit_g$opt$convergence, 0L)
  ## True log-lambda = log(sigma2_phy) = log(0.8) = -0.22
  est <- fit_g$opt$par["loglambda_phy"]
  expect_equal(unname(as.numeric(est)), log(0.8), tolerance = 0.7)
})

test_that("Stage 3: default latent covariance + propto can run together (smoke test)", {
  skip_if_not_glmmTMB()
  s <- simulate_phylo_data(n_sites = 80, n_species = 14, n_traits = 4,
                           sigma2_phy = c(0.5, 0.5, 0.5, 0.5), seed = 13)
  df <- s$data; Cphy <- s$Cphy

  ## Add a between-site latent layer with its default diagonal Psi companion.
  ## This is just a smoke test that the combined model fits without error.
  fit_g <- gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
            latent(0 + trait | site, d = 2) +
            propto(0 + species | trait, Cphy),
    data = df, phylo_vcv = Cphy
  )
  expect_equal(fit_g$opt$convergence, 0L)
  expect_true(fit_g$use$propto)
  expect_true(fit_g$use$rr_B)
  expect_true(fit_g$use$diag_B)

  ## Cross-check LL against glmmTMB on the same formula. glmmTMB-side
  ## uses its own `rr()` / `diag()` keywords. In gllvmTMB, ordinary
  ## latent() now carries the matching diagonal Psi companion by default.
  ll_g <- -fit_g$opt$objective
  fit_t <- suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
            rr(0 + trait | site, d = 2) +
            diag(0 + trait | site) +
            propto(0 + species | trait, Cphy),
    data = df, REML = FALSE
  ))
  ll_t <- as.numeric(stats::logLik(fit_t))
  testthat::skip_if(is.na(ll_t),
                    "glmmTMB hit non-PD Hessian on combined model")
  expect_equal(ll_g, ll_t, tolerance = 1e-3)
})

test_that("Stage 3: propto() requires phylo_vcv argument", {
  s <- simulate_phylo_data()
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + propto(0 + species | trait, Cphy),
      data = s$data, phylo_vcv = NULL
    ),
    "phylo_vcv"
  )
})
