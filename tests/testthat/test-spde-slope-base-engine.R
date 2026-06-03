## BASE augmented SPDE slope engine (Design 55 §5 / Design 56 §9.5e,
## Design 60 §3.4, Design 61 Track-B prerequisite for all spatial slope cells).
##
## This is the *engine* test for the second SPDE field on a covariate:
##
##   eta(o) += (A_proj omega_alpha)(o) + x(o) * (A_proj omega_beta)(o)
##
## with the augmented spatial field (omega_alpha, omega_beta) per mesh node
## sharing a 2x2 cross-field covariance Sigma_field, giving the
## matrix-normal-like prior
##
##   vec(Omega) ~ N(0, Sigma_field (x) Q^{-1}),   Omega = [omega_a | omega_b],
##
## where Q is the SPDE precision (sparse). The implementation REUSES the
## shipped per-trait GMRF(Q) machinery; no new atomic / sparse-solve op.
##
## The C++ block is gated by the dormant DATA_INTEGER(use_spde_slope). There
## is no parser route to it yet (parser activation is the next slice), so
## these tests drive the engine directly via TMB::MakeADFun against the
## compiled `gllvmTMB` DLL -- the same pattern as
## tests/testthat/test-phase56-1-phylo-augmented-stub.R.

skip_if_not_spatial <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
}

## Build a scaffold (intercept-only spatial) fit so we inherit the full
## TMB data/parameter contract + a real fmesher mesh, then reconfigure the
## data list to the augmented-slope path. Returns the scaffold fit + mesh.
.spde_slope_scaffold <- function(seed = 7, n_sites = 30, n_traits = 2,
                                 cutoff = 0.15) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites, n_species = 1, n_traits = n_traits,
    mean_species_per_site = 1, spatial_range = 0.3,
    sigma2_spa = rep(0.2, n_traits), seed = seed)
  df <- sim$data
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = cutoff)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE)))
  list(fit = fit, mesh = mesh, df = df)
}

## Reconstruct the dense SPDE precision Q_base for a given kappa.
.Q_base_dense <- function(mesh, kappa) {
  M0 <- as.matrix(mesh$spde$c0)
  M1 <- as.matrix(mesh$spde$g1)
  M2 <- as.matrix(mesh$spde$g2)
  kappa^4 * M0 + 2 * kappa^2 * M1 + M2
}

## ---------------------------------------------------------------------------
## 1. Dormancy / regression: the default contract has use_spde_slope == 0 and
##    all augmented SPDE params mapped off, so existing spatial fits are
##    untouched. (The broader regression is the unchanged test-stage4-spde /
##    test-spatial-* suites; this is the local contract check.)
## ---------------------------------------------------------------------------
test_that("base SPDE slope stays dormant by default", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  sc <- .spde_slope_scaffold()
  td <- sc$fit$tmb_data

  expect_identical(td$use_spde_slope, 0L)
  expect_identical(td$n_lhs_cols_spde, 1L)
  expect_equal(dim(td$Z_spde_aug), c(length(td$y), 1L))

  ## All augmented SPDE params are present (dormant infrastructure) and the
  ## scaffold fit converged exactly as the intercept-only spatial path.
  expect_false(is.null(sc$fit$tmb_params$omega_spde_aug))
  expect_false(is.null(sc$fit$tmb_params$log_sd_spde_b))
  expect_false(is.null(sc$fit$tmb_params$atanh_cor_spde_b))
  expect_equal(sc$fit$opt$convergence, 0L)
  ## omega_spde_aug must NOT be in the random vector while dormant.
  expect_false("omega_spde_aug" %in%
                 names(sc$fit$tmb_obj$env$par.fixed %||% list()))
})

## ---------------------------------------------------------------------------
## 2. Density cross-check (< 1e-9): the C++ negative-log-density of the
##    augmented field equals the analytic Sigma_field (x) Q^{-1} multivariate
##    normal density, computed against the SPARSE Q.
##
##    Isolation strategy: zero the projection matrix A_proj so the response
##    likelihood does NOT depend on omega_spde_aug. Then
##      fn(omega) - fn(0) = 0.5 * vec(omega)' (Sigma_field^{-1} (x) Q) vec(omega)
##    isolates the prior quadratic form exactly (likelihood baseline + the
##    omega-independent normalizing constant cancel). Adding the analytic
##    normalizing constant recovers the absolute prior nll, which is compared
##    to a dense Kronecker MVN density. The kappa-dependent logdet(Q) and
##    logdet(Sigma_field) terms are validated separately below.
## ---------------------------------------------------------------------------
test_that("augmented SPDE prior matches analytic Sigma_field (x) Q^-1 density (<1e-9)", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  sc <- .spde_slope_scaffold(seed = 7)
  td <- sc$fit$tmb_data
  tp <- sc$fit$tmb_params
  n_mesh <- td$n_mesh
  n_obs  <- length(td$y)

  ## Reconfigure to the augmented slope; zero the projection.
  td$use_spde       <- 0L
  td$use_spde_slope <- 1L
  td$n_lhs_cols_spde <- 2L
  td$Z_spde_aug <- cbind(rep(1, n_obs), stats::rnorm(n_obs))
  td$A_proj <- Matrix::sparseMatrix(
    i = integer(0), j = integer(0), x = numeric(0),
    dims = c(n_obs, n_mesh))

  kappa <- 2.5; sd_a <- 0.7; sd_b <- 1.2; rho <- -0.3
  tp$log_kappa_spde  <- log(kappa)
  tp$log_sd_spde_b   <- c(log(sd_a), log(sd_b))
  tp$atanh_cor_spde_b <- atanh(rho)

  fn_at <- function(omega) {
    tp2 <- tp
    tp2$omega_spde_aug <- omega
    tmap <- lapply(tp2, function(v) factor(rep(NA_integer_, length(v))))
    obj <- TMB::MakeADFun(data = td, parameters = tp2, map = tmap,
                          DLL = "gllvmTMB", silent = TRUE)
    obj$fn()
  }

  set.seed(404)
  omega <- matrix(stats::rnorm(n_mesh * 2L), n_mesh, 2L)

  ## Analytic N(0, Sigma_field (x) Q^-1) via the SPARSE precision
  ## Sigma_field^-1 (x) Q. A dense reference (solve(Q) + kronecker(Sf, A) +
  ## determinant(BigCov) + solve(BigCov, .)) is floating-point-accumulation-
  ## limited near 1e-9: on some CI BLAS/LAPACK its own round-off exceeds the
  ## <1e-9 assertion even though the engine is correct. The sparse-Q path below
  ## -- logdet via a sparse Cholesky of forceSymmetric(Q), quadratic via sparse
  ## matvecs Q %*% omega_j (NEVER densifying Q^-1) -- reproduces the engine
  ## density to ~1e-11 (the #326/#327 verification panels reached 2.9e-11).
  C  <- 2L
  M0 <- sc$mesh$spde$c0; M1 <- sc$mesh$spde$g1; M2 <- sc$mesh$spde$g2
  Q  <- Matrix::forceSymmetric(kappa^4 * M0 + 2 * kappa^2 * M1 + M2)
  chQ <- Matrix::Cholesky(Q, LDL = FALSE, perm = TRUE)
  ## determinant(<CHMfactor>, sqrt = FALSE) returns logdet(Q) directly (the LL'
  ## determinant), so no factor of 2.
  logdet_Q <- as.numeric(
    Matrix::determinant(chQ, logarithm = TRUE, sqrt = FALSE)$modulus)
  Sf <- matrix(c(sd_a^2, rho * sd_a * sd_b,
                 rho * sd_a * sd_b, sd_b^2), 2, 2)
  logdet_Sf <- as.numeric(determinant(Sf, logarithm = TRUE)$modulus)
  Sinv <- solve(Sf)
  ## Sparse matvecs only: q_jl = omega_j' Q omega_l.
  Qom <- as.matrix(Q %*% omega)
  q00 <- sum(omega[, 1] * Qom[, 1])
  q11 <- sum(omega[, 2] * Qom[, 2])
  q01 <- sum(omega[, 1] * Qom[, 2])
  quad <- Sinv[1, 1] * q00 + Sinv[2, 2] * q11 + 2 * Sinv[1, 2] * q01
  ## logdet(Sigma_field (x) Q^-1) = n_mesh*logdet(Sf) - C*logdet(Q).
  const <- 0.5 * (2 * n_mesh * log(2 * pi) +
                    n_mesh * logdet_Sf - C * logdet_Q)
  analytic_prior <- const + 0.5 * quad

  ## Engine absolute prior = (fn(omega) - fn(0)) + analytic normalizing const.
  engine_prior <- (fn_at(omega) - fn_at(matrix(0, n_mesh, 2L))) + const

  expect_lt(abs(engine_prior - analytic_prior), 1e-9)
})

test_that("augmented SPDE prior log-determinant tracks kappa + Sigma_field (<1e-9)", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  sc <- .spde_slope_scaffold(seed = 7)
  td <- sc$fit$tmb_data
  tp <- sc$fit$tmb_params
  n_mesh <- td$n_mesh
  n_obs  <- length(td$y)

  td$use_spde       <- 0L
  td$use_spde_slope <- 1L
  td$n_lhs_cols_spde <- 2L
  td$Z_spde_aug <- cbind(rep(1, n_obs), stats::rnorm(n_obs))
  td$A_proj <- Matrix::sparseMatrix(
    i = integer(0), j = integer(0), x = numeric(0),
    dims = c(n_obs, n_mesh))

  ## With omega == 0, fn = likelihood_baseline + 0.5*(2n log2pi + logdet(Sf(x)A)).
  ## The likelihood baseline is independent of (kappa, Sigma_field), so the
  ## difference between two parameter settings isolates the log-determinant.
  eng_const <- function(kappa, sd_a, sd_b, rho) {
    tp2 <- tp
    tp2$log_kappa_spde   <- log(kappa)
    tp2$omega_spde_aug   <- matrix(0, n_mesh, 2L)
    tp2$log_sd_spde_b    <- c(log(sd_a), log(sd_b))
    tp2$atanh_cor_spde_b <- atanh(rho)
    tmap <- lapply(tp2, function(v) factor(rep(NA_integer_, length(v))))
    TMB::MakeADFun(data = td, parameters = tp2, map = tmap,
                   DLL = "gllvmTMB", silent = TRUE)$fn()
  }
  ana_const <- function(kappa, sd_a, sd_b, rho) {
    ## logdet(Sigma_field (x) Q^-1) = n_mesh*logdet(Sf) - C*logdet(Q), computed
    ## against the SPARSE precision Q. A dense reference (solve(Q) +
    ## kronecker(Sf, A) + determinant(.)) is floating-point-accumulation-limited
    ## near 1e-9: on some CI BLAS/LAPACK its own round-off exceeds the <1e-9
    ## assertion even though the engine is correct (#357). The sparse logdet via a
    ## Cholesky of forceSymmetric(Q) -- NEVER densifying Q^-1 -- reaches ~1e-11,
    ## matching the converted density self-check above (test at line ~95).
    C  <- 2L
    Q  <- Matrix::forceSymmetric(.Q_base_dense(sc$mesh, kappa))
    chQ <- Matrix::Cholesky(Q, LDL = FALSE, perm = TRUE)
    ## determinant(<CHMfactor>, sqrt = FALSE) returns logdet(Q) directly.
    logdet_Q <- as.numeric(
      Matrix::determinant(chQ, logarithm = TRUE, sqrt = FALSE)$modulus)
    Sf <- matrix(c(sd_a^2, rho * sd_a * sd_b,
                   rho * sd_a * sd_b, sd_b^2), 2, 2)
    logdet_Sf <- as.numeric(determinant(Sf, logarithm = TRUE)$modulus)
    0.5 * (2 * n_mesh * log(2 * pi) +
             n_mesh * logdet_Sf - C * logdet_Q)
  }
  p1 <- list(2.5, 0.7, 1.2, -0.3)
  p2 <- list(4.0, 1.1, 0.6,  0.5)
  eng_diff <- do.call(eng_const, p1) - do.call(eng_const, p2)
  ana_diff <- do.call(ana_const, p1) - do.call(ana_const, p2)
  expect_lt(abs(eng_diff - ana_diff), 1e-9)
})

test_that("slope-only (n_lhs_cols_spde == 1) collapses to a scaled GMRF prior", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  sc <- .spde_slope_scaffold(seed = 7)
  td <- sc$fit$tmb_data
  tp <- sc$fit$tmb_params
  n_mesh <- td$n_mesh
  n_obs  <- length(td$y)

  td$use_spde        <- 0L
  td$use_spde_slope  <- 1L
  td$n_lhs_cols_spde <- 1L
  td$Z_spde_aug <- matrix(stats::rnorm(n_obs), nrow = n_obs, ncol = 1L)
  td$A_proj <- Matrix::sparseMatrix(
    i = integer(0), j = integer(0), x = numeric(0),
    dims = c(n_obs, n_mesh))

  kappa <- 2.5; sd <- 0.8
  tp$log_kappa_spde   <- log(kappa)
  tp$log_sd_spde_b    <- log(sd)
  tp$atanh_cor_spde_b <- numeric(0)

  fn_at <- function(om0) {
    tp2 <- tp
    tp2$omega_spde_aug <- matrix(om0, nrow = n_mesh, ncol = 1L)
    tmap <- lapply(tp2, function(v) factor(rep(NA_integer_, length(v))))
    TMB::MakeADFun(data = td, parameters = tp2, map = tmap,
                   DLL = "gllvmTMB", silent = TRUE)$fn()
  }
  set.seed(11)
  om0 <- stats::rnorm(n_mesh)

  ## omega ~ N(0, sd^2 Q^{-1}), evaluated against the SPARSE precision Q.
  ## Covariance A = sd^2 Q^-1, so A^-1 = Q / sd^2 and
  ##   logdet(A) = n_mesh*log(sd^2) - logdet(Q),
  ##   om0' A^-1 om0 = (1/sd^2) * om0' Q om0.
  ## A dense reference (solve(Q) + determinant(A) + solve(A, om0)) is
  ## floating-point-accumulation-limited near 1e-9 on some CI BLAS/LAPACK even
  ## though the engine is correct (#357). The sparse path -- logdet via a
  ## Cholesky of forceSymmetric(Q), quadratic via the sparse matvec Q %*% om0
  ## (NEVER densifying Q^-1) -- reaches ~1e-11, matching the converted density
  ## self-check above (test at line ~95).
  Q   <- Matrix::forceSymmetric(.Q_base_dense(sc$mesh, kappa))
  chQ <- Matrix::Cholesky(Q, LDL = FALSE, perm = TRUE)
  logdet_Q <- as.numeric(
    Matrix::determinant(chQ, logarithm = TRUE, sqrt = FALSE)$modulus)
  logdet_A <- n_mesh * log(sd^2) - logdet_Q
  const <- 0.5 * (n_mesh * log(2 * pi) + logdet_A)
  quad  <- sum(om0 * as.numeric(Q %*% om0)) / sd^2
  analytic <- const + 0.5 * quad
  engine   <- (fn_at(om0) - fn_at(rep(0, n_mesh))) + const

  expect_lt(abs(engine - analytic), 1e-9)
})

## ---------------------------------------------------------------------------
## 3. Gaussian recovery: simulate from the augmented SPDE prior with known
##    (marginal field variances, cross-field correlation) and recover them.
##
##    The DGP is parameterised by the IDENTIFIABLE marginal field SD, with
##    the engine sd-parameter = marg_sd * sqrt(4*pi) * kappa (the Matern
##    nu=1, d=2 normalisation sigma^2_marg = sd^2 / (4*pi*kappa^2)). The
##    cross-field correlation rho is invariant to that normalisation.
## ---------------------------------------------------------------------------
test_that("base SPDE slope recovers marginal field variances + cross-field cor", {
  skip_if_not_heavy()
  skip_if_not_spatial()

  marg_a <- 0.8; marg_b <- 0.5; rho_true <- -0.45
  range_true <- 0.3; kappa_true <- sqrt(8) / range_true
  sf_norm <- sqrt(4 * pi) * kappa_true
  sd_a_p <- marg_a * sf_norm
  sd_b_p <- marg_b * sf_norm
  sigma_eps <- 0.15
  n_traits <- 3L

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

    Q  <- .Q_base_dense(mesh, kappa_true)
    A  <- solve(Q)
    Sf <- matrix(c(sd_a_p^2, rho_true * sd_a_p * sd_b_p,
                   rho_true * sd_a_p * sd_b_p, sd_b_p^2), 2, 2)
    chA <- t(chol(A + 1e-9 * diag(n_mesh)))
    chS <- chol(Sf)
    ## Matrix-normal draw: vec(Omega) ~ N(0, Sf (x) A).
    Omega <- chA %*% matrix(stats::rnorm(n_mesh * 2L), n_mesh, 2L) %*% chS
    A_full <- as.matrix(mesh$A_st)
    fa_tru <- as.numeric(A_full %*% Omega[, 1])
    fb_tru <- as.numeric(A_full %*% Omega[, 2])
    eta <- fa_tru + df$x * fb_tru
    df$value <- stats::rnorm(n_traits, 0, 0.5)[df$trait_id] + eta +
      stats::rnorm(nrow(df), sd = sigma_eps)
    df$site         <- factor(df$site)
    df$species      <- factor(df$species)
    df$site_species <- factor(df$site_species)

    sc <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_unique(0 + trait | coords),
      data = df, mesh = mesh, silent = TRUE)))
    td <- sc$tmb_data
    tp <- sc$tmb_params
    td$use_spde        <- 0L
    td$use_spde_slope  <- 1L
    td$n_lhs_cols_spde <- 2L
    td$Z_spde_aug <- cbind(rep(1, nrow(df)), df$x)
    tp$omega_spde_aug   <- matrix(0, n_mesh, 2L)
    tp$log_sd_spde_b    <- c(log(sd_a_p), log(sd_b_p))
    tp$atanh_cor_spde_b <- 0
    tp$log_kappa_spde   <- log(kappa_true)
    keep <- c("omega_spde_aug", "log_sd_spde_b", "atanh_cor_spde_b",
              "log_kappa_spde", "beta", "log_sigma_eps")
    tmap <- list()
    for (nm in names(tp)) {
      if (!(nm %in% keep))
        tmap[[nm]] <- factor(rep(NA_integer_, length(tp[[nm]])))
    }
    obj <- TMB::MakeADFun(data = td, parameters = tp, map = tmap,
                          random = "omega_spde_aug", DLL = "gllvmTMB",
                          silent = TRUE)
    op <- stats::nlminb(obj$par, obj$fn, obj$gr,
                        control = list(eval.max = 1000, iter.max = 1000))
    e   <- op$par
    sd_hat  <- exp(e[grepl("^log_sd_spde_b", names(e))])
    rho_hat <- tanh(e[grepl("^atanh_cor_spde_b", names(e))])
    rep_ <- obj$env$last.par.best
    om_hat <- matrix(rep_[grepl("^omega_spde_aug", names(rep_))], n_mesh, 2L)
    list(conv = op$convergence,
         marg_a = sd_hat[1] / sf_norm,
         marg_b = sd_hat[2] / sf_norm,
         rho = as.numeric(rho_hat),
         cor_fa = stats::cor(as.numeric(A_full %*% om_hat[, 1]), fa_tru),
         cor_fb = stats::cor(as.numeric(A_full %*% om_hat[, 2]), fb_tru))
  }

  seeds <- 1:6
  res <- lapply(seeds, fit_one)
  conv     <- vapply(res, `[[`, integer(1), "conv")
  marg_a_h <- vapply(res, `[[`, numeric(1), "marg_a")
  marg_b_h <- vapply(res, `[[`, numeric(1), "marg_b")
  rho_h    <- vapply(res, `[[`, numeric(1), "rho")
  cor_fa   <- vapply(res, `[[`, numeric(1), "cor_fa")
  cor_fb   <- vapply(res, `[[`, numeric(1), "cor_fb")

  expect_true(all(conv == 0L))
  ## Field BLUP recovery is the strong, distribution-free check.
  expect_gt(mean(cor_fa), 0.90)
  expect_gt(mean(cor_fb), 0.90)
  ## Marginal variances + cross-field correlation recovered on average
  ## (marg_a / marg_b / rho_true are the simulated truths).
  expect_lt(abs(mean(marg_a_h) - marg_a), 0.20)
  expect_lt(abs(mean(marg_b_h) - marg_b), 0.20)
  expect_lt(abs(mean(rho_h) - rho_true), 0.20)
})

## ---------------------------------------------------------------------------
## 4. Fail-loud negatives: the C++ dimension asserts (Design 56 §7.2
##    fail-loud invariant) must error on any shape mismatch, never silently
##    truncate.
## ---------------------------------------------------------------------------
test_that("base SPDE slope errors loudly on shape mismatches", {
  skip_if_not_heavy()
  skip_if_not_spatial()
  sc <- .spde_slope_scaffold(seed = 7)
  td0 <- sc$fit$tmb_data
  tp0 <- sc$fit$tmb_params
  n_mesh <- td0$n_mesh
  n_obs  <- length(td0$y)

  build <- function(td, tp) {
    tmap <- lapply(tp, function(v) factor(rep(NA_integer_, length(v))))
    TMB::MakeADFun(data = td, parameters = tp, map = tmap,
                   DLL = "gllvmTMB", silent = TRUE)
  }

  ## (a) n_lhs_cols_spde out of {1,2}.
  td <- td0; tp <- tp0
  td$use_spde_slope <- 1L; td$n_lhs_cols_spde <- 3L
  td$Z_spde_aug <- matrix(0, n_obs, 3L)
  tp$omega_spde_aug   <- matrix(0, n_mesh, 3L)
  tp$log_sd_spde_b    <- rep(0, 3L)
  tp$atanh_cor_spde_b <- rep(0, 3L)
  expect_error(build(td, tp), "n_lhs_cols_spde")

  ## (b) Z_spde_aug column count disagrees with n_lhs_cols_spde.
  td <- td0; tp <- tp0
  td$use_spde_slope <- 1L; td$n_lhs_cols_spde <- 2L
  td$Z_spde_aug <- matrix(0, n_obs, 1L)          # should be 2 columns
  tp$omega_spde_aug   <- matrix(0, n_mesh, 2L)
  tp$log_sd_spde_b    <- c(0, 0)
  tp$atanh_cor_spde_b <- 0
  expect_error(build(td, tp), "n_lhs_cols_spde")

  ## (c) Z_spde_aug row count disagrees with n_obs.
  td <- td0; tp <- tp0
  td$use_spde_slope <- 1L; td$n_lhs_cols_spde <- 2L
  td$Z_spde_aug <- matrix(0, n_obs + 5L, 2L)     # wrong number of rows
  tp$omega_spde_aug   <- matrix(0, n_mesh, 2L)
  tp$log_sd_spde_b    <- c(0, 0)
  tp$atanh_cor_spde_b <- 0
  expect_error(build(td, tp), "n_obs")

  ## (d) log_sd_spde_b length disagrees with n_lhs_cols_spde.
  td <- td0; tp <- tp0
  td$use_spde_slope <- 1L; td$n_lhs_cols_spde <- 2L
  td$Z_spde_aug <- matrix(0, n_obs, 2L)
  tp$omega_spde_aug   <- matrix(0, n_mesh, 2L)
  tp$log_sd_spde_b    <- 0                        # should be length 2
  tp$atanh_cor_spde_b <- 0
  expect_error(build(td, tp), "log_sd_spde_b")
})
