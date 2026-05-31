## spatial_latent(1 + x | coords, d) Gaussian engine + recovery (Design 64 sec.3).
##
## Block-diagonal reduced-rank random regression on the SPDE field. For each
## LHS column k in {intercept, slope}, an independent rank-d factor structure:
##   d shared GMRF fields  g^{(k)}_f ~ N(0, Q^{-1})  i.i.d.,
##   a per-column loading  Lambda_k (T x d, rr() lower-triangular),
##   Sigma_k = Lambda_k Lambda_k^T  (T x T, rank d).
## No intercept-slope correlation (block-diagonal across LHS columns). It is
## the spatial analogue of phylo_latent (species score replaced by the
## A_proj-projected mesh field). The engine REUSES density::GMRF(Q).
##
## Tests mirror tests/testthat/test-spde-slope-base-engine.R +
## test-spatial-latent-recovery.R: a direct-engine density self-check against a
## dense kronecker(I, solve(Q)) MVN to < 1e-9, plus a full-wrapper Procrustes
## recovery of the per-column loading shape (multistart, as the factor model is
## multimodal), plus the fail-loud guards (d <= n_traits; gaussian only;
## malformed RHS). Heavy fits gated behind skip_if_not_heavy().

skip_if_not_spatial <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
}

.Q_base_dense_lat <- function(mesh, kappa) {
  M0 <- as.matrix(mesh$spde$c0)
  M1 <- as.matrix(mesh$spde$g1)
  M2 <- as.matrix(mesh$spde$g2)
  kappa^4 * M0 + 2 * kappa^2 * M1 + M2
}

## Procrustes shape correlation: rotation-invariant loading recovery.
.procrustes_cor <- function(Lhat, Ltru) {
  M <- t(Lhat) %*% Ltru
  sv <- svd(M)
  Rot <- sv$v %*% t(sv$u)
  stats::cor(as.numeric(Lhat %*% Rot), as.numeric(Ltru))
}

.spde_lat_scaffold <- function(seed = 7, n_sites = 30, n_traits = 3,
                               cutoff = 0.15) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites, n_species = 1, n_traits = n_traits,
    mean_species_per_site = 1, spatial_range = 0.3,
    sigma2_spa = rep(0.2, n_traits), seed = seed)
  df <- sim$data
  df$x <- stats::rnorm(nrow(df))
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = cutoff)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE)))
  list(fit = fit, mesh = mesh, df = df, n_traits = n_traits)
}

## ---------------------------------------------------------------------------
## 1. Density self-check (< 1e-9): the reduced-rank prior is a sum of
##    independent GMRF(Q) calls on the shared field columns, i.e.
##    vec(g) ~ N(0, I_{n_lhs*d} (x) Q^{-1}). The C++ nll equals the analytic
##    dense kronecker(I, solve(Q)) MVN. Isolation: zero A_proj so the
##    likelihood does not depend on the field; (fn(g) - fn(0)) + const recovers
##    the absolute prior nll. The loadings are irrelevant to the prior (they
##    enter eta, which is killed by A_proj = 0), so any values are fine.
## ---------------------------------------------------------------------------
test_that("spatial_latent prior matches analytic kronecker(I, Q^-1) density (<1e-9)", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  sc <- .spde_lat_scaffold(seed = 7, n_traits = 3)
  td <- sc$fit$tmb_data
  tp <- sc$fit$tmb_params
  n_mesh <- td$n_mesh
  n_obs  <- length(td$y)
  d <- 2L
  ncol_lat <- 2L
  n_traits <- sc$n_traits

  td$use_spde            <- 0L
  td$use_spde_latent_slope <- 1L
  td$d_spde_slope        <- d
  td$n_lhs_cols_spde_lat <- ncol_lat
  td$Z_spde_lat <- cbind(rep(1, n_obs), stats::rnorm(n_obs))
  td$A_proj <- Matrix::sparseMatrix(
    i = integer(0), j = integer(0), x = numeric(0),
    dims = c(n_obs, n_mesh))

  kappa <- 2.4
  tp$log_kappa_spde <- log(kappa)
  len_per_col <- n_traits * d - d * (d - 1L) / 2L
  set.seed(5)
  tp$theta_rr_spde_slope <- stats::rnorm(ncol_lat * len_per_col, 0, 0.4)
  tp$g_spde_slope <- array(0, dim = c(n_mesh, d, ncol_lat))

  fn_at <- function(g) {
    tp2 <- tp
    tp2$g_spde_slope <- g
    tmap <- lapply(tp2, function(v) factor(rep(NA_integer_, length(v))))
    TMB::MakeADFun(data = td, parameters = tp2, map = tmap,
                   DLL = "gllvmTMB", silent = TRUE)$fn()
  }

  set.seed(404)
  g <- array(stats::rnorm(n_mesh * d * ncol_lat), dim = c(n_mesh, d, ncol_lat))
  Q <- .Q_base_dense_lat(sc$mesh, kappa)
  A <- solve(Q)
  nfields <- d * ncol_lat

  ## Flatten the n_lhs*d independent N(0, Q^{-1}) field columns.
  gmat <- matrix(0, n_mesh, nfields)
  col <- 1L
  for (k in seq_len(ncol_lat)) for (f in seq_len(d)) { gmat[, col] <- g[, f, k]; col <- col + 1L }
  quad <- sum(diag(t(gmat) %*% Q %*% gmat))
  logdet_big <- nfields * as.numeric(determinant(A, logarithm = TRUE)$modulus)
  const <- 0.5 * (n_mesh * nfields * log(2 * pi) + logdet_big)
  analytic_prior <- const + 0.5 * quad
  engine_prior <- (fn_at(g) - fn_at(array(0, dim = c(n_mesh, d, ncol_lat)))) + const

  expect_lt(abs(engine_prior - analytic_prior), 1e-9)

  ## Non-vacuity: a wrong kappa in the reference Q blows the diff up.
  Qw <- .Q_base_dense_lat(sc$mesh, kappa * 1.5)
  Aw <- solve(Qw)
  quad_w <- sum(diag(t(gmat) %*% Qw %*% gmat))
  analytic_w <- 0.5 * (n_mesh * nfields * log(2 * pi) +
                         nfields * as.numeric(determinant(Aw, logarithm = TRUE)$modulus)) +
    0.5 * quad_w
  expect_gt(abs(analytic_w - engine_prior), 1)
})

## ---------------------------------------------------------------------------
## 2. Gaussian recovery (full wrapper, multistart): simulate from the reduced-
##    rank prior with known per-column loadings and recover the loading SHAPE
##    (Procrustes correlation, rotation-invariant) for both the intercept and
##    slope columns; convergence code 0 + PD Hessian. The factor model is
##    multimodal, so we use multistart (n_init = 5) exactly as the intercept-
##    only spatial_latent recovery test (test-spatial-latent-recovery.R).
## ---------------------------------------------------------------------------
test_that("spatial_latent recovers per-column loading shape (Procrustes)", {
  skip_if_not_heavy()
  skip_if_not_spatial()

  n_traits <- 5L
  K <- 2L
  range_true <- 0.3
  kappa_true <- sqrt(8) / range_true

  ## Per-column loadings (lower-triangular identified: L[1, 2] = 0). Entries on
  ## a 0.2 - 1.5 scale for a moderate signal-to-noise ratio.
  L0 <- matrix(c(1.5, -0.8, 0.4, 1.0, 0.2,
                 0.0,  1.2, 1.0, -0.5, 0.7), n_traits, K)
  L1 <- matrix(c(1.0,  0.5, -0.6, 0.3, -0.4,
                 0.0,  0.9, -0.7, 0.6, 0.4), n_traits, K)

  set.seed(7)
  n_sites <- 250L
  coords <- cbind(lon = stats::runif(n_sites), lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites), trait_id = seq_len(n_traits))
  df$species      <- 1L
  df$site_species <- paste0(df$site, "_1")
  df$trait <- factor(paste0("trait_", df$trait_id),
                     levels = paste0("trait_", seq_len(n_traits)))
  df$lon <- coords[df$site, 1]
  df$lat <- coords[df$site, 2]
  df$x   <- stats::rnorm(nrow(df))
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.07)
  n_mesh <- ncol(mesh$A_st)

  Qb <- .Q_base_dense_lat(mesh, kappa_true)
  Sb <- solve(Qb)
  scale_om <- 1 / sqrt(mean(diag(Sb)))
  chS <- chol(Sb + 1e-8 * diag(n_mesh))
  om0 <- matrix(0, n_mesh, K)
  om1 <- matrix(0, n_mesh, K)
  for (k in seq_len(K)) {
    om0[, k] <- scale_om * as.numeric(t(chS) %*% stats::rnorm(n_mesh))
    om1[, k] <- scale_om * as.numeric(t(chS) %*% stats::rnorm(n_mesh))
  }
  A_full <- as.matrix(mesh$A_st)
  sp0 <- as.numeric(rowSums((A_full %*% om0) * L0[df$trait_id, , drop = FALSE]))
  sp1 <- as.numeric(rowSums((A_full %*% om1) * L1[df$trait_id, , drop = FALSE]))
  df$value <- stats::rnorm(n_traits, 0, 0.5)[df$trait_id] + sp0 + df$x * sp1 +
    stats::rnorm(nrow(df), sd = 0.3)
  df$site         <- factor(df$site)
  df$species      <- factor(df$species)
  df$site_species <- factor(df$site_species)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_latent(1 + x | coords, d = 2),
    data = df, mesh = mesh, silent = TRUE,
    control = list(n_init = 5, init_jitter = 0.5))))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$fit_health$pd_hessian))
  ## The augmented latent block is active; the intercept-only one is OFF.
  expect_true(isTRUE(fit$use$spde_latent_slope))
  expect_identical(fit$tmb_data$spde_lv_k, 0L)
  expect_identical(fit$tmb_data$d_spde_slope, 2L)

  s <- gllvmTMB::extract_Sigma(fit, level = "spde_slope")
  expect_s3_class(s, "gllvmTMB_Sigma_phy_slope")
  ## Loading-shape recovery (rotation-invariant) for both LHS columns.
  expect_gt(.procrustes_cor(s$Lambda_intercept, L0), 0.90)
  expect_gt(.procrustes_cor(s$Lambda_slope, L1), 0.90)
  ## Sigma off-diagonal correlation pattern recovered for both columns.
  S0 <- L0 %*% t(L0)
  S1 <- L1 %*% t(L1)
  expect_gt(stats::cor(s$intercept[lower.tri(s$intercept)], S0[lower.tri(S0)]), 0.80)
  expect_gt(stats::cor(s$slope[lower.tri(s$slope)], S1[lower.tri(S1)]), 0.80)
})

## ---------------------------------------------------------------------------
## 3. wide == long byte-identity (Design 55 sec.3).
## ---------------------------------------------------------------------------
test_that("spatial_latent wide == long byte-identical", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  sc <- .spde_lat_scaffold(seed = 11, n_sites = 150, n_traits = 3, cutoff = 0.08)
  df <- sc$df

  f_w <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_latent(1 + x | coords, d = 1),
    data = df, mesh = sc$mesh, silent = TRUE,
    control = list(n_init = 3, init_jitter = 0.4))))
  f_l <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_latent(0 + trait + (0 + trait):x | coords, d = 1),
    data = df, mesh = sc$mesh, silent = TRUE,
    control = list(n_init = 3, init_jitter = 0.4))))

  expect_identical(f_w$tmb_data$Z_spde_lat, f_l$tmb_data$Z_spde_lat)
  expect_identical(f_w$tmb_data$n_lhs_cols_spde_lat, 2L)
  expect_identical(f_l$tmb_data$n_lhs_cols_spde_lat, 2L)
  ## logLik is invariant to wide/long (the engine reads the same Z_spde_lat);
  ## multistart makes the optimum reproducible to a loose tolerance.
  expect_lt(abs(as.numeric(logLik(f_w)) - as.numeric(logLik(f_l))), 1e-3)
})

## ---------------------------------------------------------------------------
## 4. Guards fire: d > n_traits aborts; non-Gaussian aborts; malformed RHS
##    aborts.
## ---------------------------------------------------------------------------
test_that("spatial_latent guards fire (d > n_traits, non-Gaussian, malformed)", {
  skip_if_not_spatial()
  sc <- .spde_lat_scaffold(seed = 5, n_sites = 30, n_traits = 2)
  df <- sc$df
  df$count <- stats::rpois(nrow(df), 2)

  ## d > n_traits aborts (n_traits = 2 here).
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_latent(1 + x | coords, d = 3),
      data = df, mesh = sc$mesh, silent = TRUE))),
    "exceeds the number of traits"
  )
  ## A RESERVED family (not on the augmented spatial_latent allowlist
  ## gaussian/binomial/poisson/nbinom2/Gamma/Beta/ordinal_probit) still aborts.
  ## tweedie (runtime id 6) is outside the allowlist; poisson et al. are now
  ## validated, so the guard is checked with a genuinely-reserved family.
  df$pos <- stats::rgamma(nrow(df), shape = 2, scale = 1)
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      pos ~ 0 + trait + spatial_latent(1 + x | coords, d = 1),
      data = df, mesh = sc$mesh, family = tweedie(), silent = TRUE))),
    "validated for"
  )
  ## Malformed augmented LHS aborts (handled in normalise_spatial_orientation).
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_latent(foo + x | coords, d = 1),
      data = df, mesh = sc$mesh, silent = TRUE)))
  )
})
