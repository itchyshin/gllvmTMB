## spatial_dep(1 + x | coords) Gaussian engine + recovery (Design 64 sec.2).
##
## The full unstructured 2T x 2T field-covariance augmented SPDE slope:
##
##   vec(Omega) ~ N(0, Sigma_field (x) Q^{-1}),  Omega = [a_t0 | b_t0 | a_t1 | ...]
##
## Sigma_field is C x C (C = 2T) unstructured (theta_spde_dep_chol Cholesky),
## INTERLEAVED columns (intercept-field, slope-field) per trait. It is the
## spatial analogue of phylo_dep (A_phy replaced by the SPDE field covariance
## Q^{-1}) and the unstructured generalisation of the base SPDE slope. The
## engine REUSES density::GMRF(Q) -- no new atomic / sparse-solve op.
##
## Tests mirror tests/testthat/test-spde-slope-base-engine.R: a direct-engine
## density self-check against a dense kronecker(Sigma_field, solve(Q)) MVN to
## < 1e-9, plus a full-wrapper recovery of the marginal field SDs AND a
## cross-field correlation, plus the fail-loud guards. Heavy fits are gated
## behind skip_if_not_heavy() (tests/testthat/setup.R).

skip_if_not_spatial <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
}

## Reconstruct the dense SPDE precision Q_base for a given kappa.
.Q_base_dense_dep <- function(mesh, kappa) {
  M0 <- as.matrix(mesh$spde$c0)
  M1 <- as.matrix(mesh$spde$g1)
  M2 <- as.matrix(mesh$spde$g2)
  kappa^4 * M0 + 2 * kappa^2 * M1 + M2
}

## Build an intercept-only spatial scaffold fit to inherit the full TMB
## data/parameter contract + a real mesh, then reconfigure to the dep path.
.spde_dep_scaffold <- function(seed = 7, n_sites = 30, n_traits = 2,
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
## 1. Density self-check (< 1e-9): the C++ negative-log-density of the dep
##    field equals the analytic Sigma_field (x) Q^{-1} multivariate-normal
##    density, computed against the SPARSE Q. Isolation: zero A_proj so the
##    likelihood does not depend on omega; then (fn(omega) - fn(0)) isolates
##    the prior quadratic exactly, and adding the analytic normalising
##    constant recovers the absolute prior nll. The analytic reference uses
##    the EXACT Kronecker inverse identity (Sigma (x) A)^{-1} = Sigma^{-1} (x) Q
##    so the comparison is not limited by a dense solve's accumulation.
## ---------------------------------------------------------------------------
test_that("spatial_dep prior matches analytic Sigma_field (x) Q^-1 density (<1e-9)", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  sc <- .spde_dep_scaffold(seed = 7, n_traits = 2)
  td <- sc$fit$tmb_data
  tp <- sc$fit$tmb_params
  n_mesh <- td$n_mesh
  n_obs  <- length(td$y)
  C <- 2L * sc$n_traits

  td$use_spde        <- 0L
  td$use_spde_slope  <- 1L
  td$use_spde_dep_slope <- 1L
  td$n_lhs_cols_spde <- C
  td$Z_spde_aug <- matrix(0, n_obs, C)
  td$A_proj <- Matrix::sparseMatrix(
    i = integer(0), j = integer(0), x = numeric(0),
    dims = c(n_obs, n_mesh))

  kappa <- 2.3
  tp$log_kappa_spde <- log(kappa)
  tp$omega_spde_aug <- matrix(0, n_mesh, C)

  ## Random lower-triangular L (positive diagonal) -> Sigma_field = L L^T,
  ## packed the C++ way: C log-diagonal entries, then strictly-lower entries
  ## column-major.
  set.seed(99)
  Lmat <- diag(stats::runif(C, 0.5, 1.2))
  for (j in seq_len(C)) for (i in seq_len(C)) if (i > j) Lmat[i, j] <- stats::rnorm(1, 0, 0.3)
  Sf <- Lmat %*% t(Lmat)
  pack <- numeric(C * (C + 1L) / 2L)
  idx <- 1L
  for (j in seq_len(C)) { pack[idx] <- log(Lmat[j, j]); idx <- idx + 1L }
  for (j in seq_len(C)) for (i in seq_len(C)) if (i > j) { pack[idx] <- Lmat[i, j]; idx <- idx + 1L }
  tp$theta_spde_dep_chol <- pack

  fn_at <- function(omega) {
    tp2 <- tp
    tp2$omega_spde_aug <- omega
    tmap <- lapply(tp2, function(v) factor(rep(NA_integer_, length(v))))
    TMB::MakeADFun(data = td, parameters = tp2, map = tmap,
                   DLL = "gllvmTMB", silent = TRUE)$fn()
  }

  set.seed(404)
  omega <- matrix(stats::rnorm(n_mesh * C), n_mesh, C)
  Q <- .Q_base_dense_dep(sc$mesh, kappa)
  A <- solve(Q)

  ## Exact analytic via Kronecker: logdet(Sf (x) A) = n_mesh*logdet(Sf) +
  ## C*logdet(A); quad = tr(Sf^{-1} Omega^T Q Omega).
  logdet_big <- n_mesh * as.numeric(determinant(Sf, logarithm = TRUE)$modulus) +
    C * as.numeric(determinant(A, logarithm = TRUE)$modulus)
  Sfi  <- solve(Sf)
  Qmat <- t(omega) %*% Q %*% omega
  quad <- sum(Sfi * t(Qmat))
  const <- 0.5 * (n_mesh * C * log(2 * pi) + logdet_big)
  analytic_prior <- const + 0.5 * quad
  engine_prior <- (fn_at(omega) - fn_at(matrix(0, n_mesh, C))) + const

  expect_lt(abs(engine_prior - analytic_prior), 1e-9)

  ## Non-vacuity: perturbing one off-diagonal of Sigma_field blows the diff up.
  Sf_w <- Sf
  Sf_w[1, 2] <- Sf_w[2, 1] <- Sf[1, 2] + 0.5
  logdet_w <- n_mesh * as.numeric(determinant(Sf_w, logarithm = TRUE)$modulus) +
    C * as.numeric(determinant(A, logarithm = TRUE)$modulus)
  analytic_w <- 0.5 * (n_mesh * C * log(2 * pi) + logdet_w) +
    0.5 * sum(solve(Sf_w) * t(Qmat))
  expect_gt(abs(analytic_w - engine_prior), 1)
})

## ---------------------------------------------------------------------------
## 2. Gaussian recovery (full wrapper): simulate from the dep prior with a
##    known unstructured Sigma_field and recover the marginal field SDs and a
##    cross-field correlation within the documented 0.20 band; convergence
##    code 0 + PD Hessian.
## ---------------------------------------------------------------------------
test_that("spatial_dep recovers marginal field variances + a cross-field correlation", {
  skip_if_not_heavy()
  skip_if_not_spatial()

  n_traits <- 2L
  C <- 2L * n_traits
  range_true <- 0.3
  kappa_true <- sqrt(8) / range_true
  sf_norm    <- sqrt(4 * pi) * kappa_true
  ## Marginal field SDs (interleaved a_t0, b_t0, a_t1, b_t1) + a correlation
  ## structure with two intercept-slope and one cross-trait correlation.
  marg <- c(0.8, 0.5, 0.6, 0.4)
  sdp  <- marg * sf_norm
  Rtrue <- diag(C)
  Rtrue[1, 2] <- Rtrue[2, 1] <- -0.4   # intercept-slope (trait 0)
  Rtrue[3, 4] <- Rtrue[4, 3] <-  0.3   # intercept-slope (trait 1)
  Rtrue[1, 3] <- Rtrue[3, 1] <-  0.2   # cross-trait intercept-intercept
  Sf <- diag(sdp) %*% Rtrue %*% diag(sdp)
  sigma_eps <- 0.15

  fit_one <- function(seed) {
    set.seed(seed)
    n_sites <- 300L
    coords <- cbind(lon = stats::runif(n_sites), lat = stats::runif(n_sites))
    df <- expand.grid(site = seq_len(n_sites), trait_id = seq_len(n_traits))
    df$species      <- 1L
    df$site_species <- paste0(df$site, "_1")
    df$trait <- factor(paste0("trait_", df$trait_id),
                       levels = paste0("trait_", seq_len(n_traits)))
    df$lon <- coords[df$site, 1]
    df$lat <- coords[df$site, 2]
    df$x   <- stats::rnorm(nrow(df))
    df$value <- NA_real_
    mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.05)
    n_mesh <- ncol(mesh$A_st)

    Q   <- .Q_base_dense_dep(mesh, kappa_true)
    A   <- solve(Q)
    chA <- t(chol(A + 1e-9 * diag(n_mesh)))
    chS <- chol(Sf)
    ## Matrix-normal draw: vec(Omega) ~ N(0, Sf (x) A); Omega is n_mesh x C.
    Omega <- chA %*% matrix(stats::rnorm(n_mesh * C), n_mesh, C) %*% chS
    A_full <- as.matrix(mesh$A_st)
    proj <- A_full %*% Omega                       # n_obs x C
    eta <- numeric(nrow(df))
    for (o in seq_len(nrow(df))) {
      t0 <- df$trait_id[o] - 1L
      eta[o] <- proj[o, 2L * t0 + 1L] + df$x[o] * proj[o, 2L * t0 + 2L]
    }
    df$value <- stats::rnorm(n_traits, 0, 0.5)[df$trait_id] + eta +
      stats::rnorm(nrow(df), sd = sigma_eps)
    df$site         <- factor(df$site)
    df$species      <- factor(df$species)
    df$site_species <- factor(df$site_species)

    fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_dep(1 + x | coords),
      data = df, mesh = mesh, silent = TRUE)))
    s <- gllvmTMB::extract_Sigma(fit, level = "spatial")
    list(conv = fit$opt$convergence,
         pd   = isTRUE(fit$fit_health$pd_hessian),
         marg = sqrt(diag(s$Sigma)) / sf_norm,
         r12  = s$R[1, 2],
         r34  = s$R[3, 4],
         r13  = s$R[1, 3])
  }

  seeds <- 1:5
  res <- lapply(seeds, fit_one)
  conv <- vapply(res, `[[`, integer(1), "conv")
  pd   <- vapply(res, `[[`, logical(1), "pd")
  marg_hat <- rowMeans(vapply(res, `[[`, numeric(C), "marg"))
  r12  <- vapply(res, `[[`, numeric(1), "r12")
  r34  <- vapply(res, `[[`, numeric(1), "r34")
  r13  <- vapply(res, `[[`, numeric(1), "r13")

  expect_true(all(conv == 0L))
  expect_true(all(pd))
  ## Marginal field SDs recovered on average (truths in `marg`).
  expect_lt(max(abs(marg_hat - marg)), 0.20)
  ## At least the intercept-slope (trait 0) cross-field correlation recovered.
  expect_lt(abs(mean(r12) - (-0.4)), 0.20)
  ## And the cross-trait intercept correlation recovered.
  expect_lt(abs(mean(r13) - 0.2), 0.20)
})

## ---------------------------------------------------------------------------
## 3. spatial_dep is GENUINELY richer than spatial_unique: more free engine
##    parameters (C(C+1)/2 unstructured vs the 2-parameter shared field),
##    a different random-node count (C = 2T fields vs 2), and a better logLik
##    on dep-structured data (cross-field correlations the base cannot capture).
## ---------------------------------------------------------------------------
test_that("spatial_dep is richer than spatial_unique (params, nodes, logLik)", {
  skip_if_not_heavy()
  skip_if_not_spatial()

  n_traits <- 2L
  C <- 2L * n_traits
  range_true <- 0.3
  kappa_true <- sqrt(8) / range_true
  sf_norm    <- sqrt(4 * pi) * kappa_true
  sdp  <- c(0.8, 0.5, 0.6, 0.4) * sf_norm
  Rtrue <- diag(C)
  Rtrue[1, 3] <- Rtrue[3, 1] <- 0.7   # strong cross-trait intercept correlation
  Rtrue[2, 4] <- Rtrue[4, 2] <- 0.6   # strong cross-trait slope correlation
  Sf <- diag(sdp) %*% Rtrue %*% diag(sdp)

  set.seed(3)
  n_sites <- 300L
  coords <- cbind(lon = stats::runif(n_sites), lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites), trait_id = seq_len(n_traits))
  df$species      <- 1L
  df$site_species <- paste0(df$site, "_1")
  df$trait <- factor(paste0("trait_", df$trait_id),
                     levels = paste0("trait_", seq_len(n_traits)))
  df$lon <- coords[df$site, 1]
  df$lat <- coords[df$site, 2]
  df$x   <- stats::rnorm(nrow(df))
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.05)
  n_mesh <- ncol(mesh$A_st)
  Q   <- .Q_base_dense_dep(mesh, kappa_true)
  A   <- solve(Q)
  chA <- t(chol(A + 1e-9 * diag(n_mesh)))
  Omega <- chA %*% matrix(stats::rnorm(n_mesh * C), n_mesh, C) %*% chol(Sf)
  A_full <- as.matrix(mesh$A_st)
  proj <- A_full %*% Omega
  eta <- numeric(nrow(df))
  for (o in seq_len(nrow(df))) {
    t0 <- df$trait_id[o] - 1L
    eta[o] <- proj[o, 2L * t0 + 1L] + df$x[o] * proj[o, 2L * t0 + 2L]
  }
  df$value <- stats::rnorm(n_traits, 0, 0.5)[df$trait_id] + eta +
    stats::rnorm(nrow(df), sd = 0.15)
  df$site         <- factor(df$site)
  df$species      <- factor(df$species)
  df$site_species <- factor(df$site_species)

  fit_dep <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_dep(1 + x | coords),
    data = df, mesh = mesh, silent = TRUE)))
  fit_unq <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(1 + x | coords),
    data = df, mesh = mesh, silent = TRUE)))

  ## More free engine parameters: dep frees theta_spde_dep_chol (C(C+1)/2 = 10)
  ## and maps off log_sd_spde_b (2) + atanh_cor_spde_b (1), a net +7 over the
  ## base unique slope path.
  expect_identical(length(fit_dep$tmb_params$theta_spde_dep_chol),
                   as.integer(C * (C + 1L) / 2L))
  expect_equal(length(fit_dep$opt$par), length(fit_unq$opt$par) + 7L)
  expect_gt(length(fit_dep$opt$par), length(fit_unq$opt$par))
  ## Different random-node count: dep has C = 2T field columns, unique has 2.
  expect_identical(fit_dep$tmb_data$n_lhs_cols_spde, C)
  expect_identical(fit_unq$tmb_data$n_lhs_cols_spde, 2L)
  ## Better fit on dep-structured data (dep captures the cross-field
  ## correlations the base shared-field model cannot).
  expect_gt(as.numeric(logLik(fit_dep)), as.numeric(logLik(fit_unq)))
})

## ---------------------------------------------------------------------------
## 4. wide == long byte-identity (Design 55 sec.3): the `1 + x | coords` wide
##    surface and the `0 + trait + (0 + trait):x | coords` long surface build
##    the same interleaved Z and the same reported field structure.
## ---------------------------------------------------------------------------
test_that("spatial_dep wide == long byte-identical", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  sc <- .spde_dep_scaffold(seed = 11, n_sites = 150, n_traits = 2, cutoff = 0.08)
  df <- sc$df

  f_w <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_dep(1 + x | coords),
    data = df, mesh = sc$mesh, silent = TRUE)))
  f_l <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_dep(0 + trait + (0 + trait):x | coords),
    data = df, mesh = sc$mesh, silent = TRUE)))

  expect_identical(f_w$tmb_data$Z_spde_aug, f_l$tmb_data$Z_spde_aug)
  expect_identical(f_w$tmb_data$n_lhs_cols_spde, 4L)
  expect_identical(f_l$tmb_data$n_lhs_cols_spde, 4L)
  expect_lt(abs(as.numeric(logLik(f_w)) - as.numeric(logLik(f_l))), 1e-6)
  expect_lt(max(abs(as.numeric(f_w$report$Sigma_field) -
                      as.numeric(f_l$report$Sigma_field))), 1e-6)
})

## ---------------------------------------------------------------------------
## 5. Guards fire: non-Gaussian aborts; malformed RHS aborts.
## ---------------------------------------------------------------------------
test_that("spatial_dep guards fire (non-Gaussian, malformed RHS)", {
  skip_if_not_spatial()
  sc <- .spde_dep_scaffold(seed = 5, n_sites = 30, n_traits = 2)
  df <- sc$df
  df$count <- stats::rpois(nrow(df), 2)

  ## Non-Gaussian family aborts (gaussian only this release).
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      count ~ 0 + trait + spatial_dep(1 + x | coords),
      data = df, mesh = sc$mesh, family = poisson(), silent = TRUE))),
    "gaussian"
  )
  ## Malformed augmented LHS (not 1 + x / long form) aborts.
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_dep(foo + x | coords),
      data = df, mesh = sc$mesh, silent = TRUE))),
    "not yet supported"
  )
})
