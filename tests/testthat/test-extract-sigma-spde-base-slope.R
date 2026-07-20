## Issue #354 part (a) -- extract_Sigma() on augmented SPDE slope paths.
## `spatial_unique(1 + x | coords)` retains the shared 2x2 base engine;
## Design 79/80 routes `spatial_indep(1 + x | coords)` through the 2T
## per-trait block-diagonal dep engine.
##
## The base path REPORTs sd_spde_b (length 2), cor_spde_b (length 1), kappa_s.
## extract_Sigma(fit, level = "spatial") returns the 2x2 cross-field
## covariance Sigma_field on the SPDE parameterisation scale (tau absorbed,
## consistent with the spatial_dep branch), with a note documenting the
## marginal conversion sigma_marg = sd_spde_b / (sqrt(4*pi) * kappa_s).
##
## Guarded by !isTRUE(fit$use$spde_dep_slope) so the spatial_dep path (which
## ALSO sets fit$use$spde_slope, since use_spde_dep_slope nests under
## use_spde_slope) still routes to the dep branch, not this base branch.

skip_if_not_spatial <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
}

## Dense SPDE precision Q_base (Matern nu=1, d=2): kappa^4 M0 + 2 kappa^2 M1 + M2.
.spde_base_Q_dense <- function(mesh, kappa) {
  M0 <- as.matrix(mesh$spde$c0)
  M1 <- as.matrix(mesh$spde$g1)
  M2 <- as.matrix(mesh$spde$g2)
  kappa^4 * M0 + 2 * kappa^2 * M1 + M2
}

## Simulate an SPDE-slope Gaussian data set. `per_trait = FALSE` generates one
## shared 2x2 field for the base `spatial_unique()` route. `per_trait = TRUE`
## generates independent 2x2 fields for each trait, matching `spatial_indep()`.
.make_spde_base_slope_data <- function(seed, rho = -0.45,
                                        marg_a = 0.8, marg_b = 0.5,
                                        range_true = 0.3, sigma_eps = 0.15,
                                        n_traits = 3L, n_sites = 250L,
                                        cutoff = 0.06,
                                        per_trait = FALSE) {
  set.seed(seed)
  kappa_true <- sqrt(8) / range_true
  sf_norm    <- sqrt(4 * pi) * kappa_true
  sd_a_p     <- marg_a * sf_norm
  sd_b_p     <- marg_b * sf_norm

  coords <- cbind(lon = stats::runif(n_sites), lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites), trait_id = seq_len(n_traits))
  df$species      <- 1L
  df$site_species <- paste0(df$site, "_1")
  df$trait <- factor(paste0("trait_", df$trait_id),
                     levels = paste0("trait_", seq_len(n_traits)))
  df$lon <- coords[df$site, 1]
  df$lat <- coords[df$site, 2]
  df$x   <- stats::rnorm(nrow(df))

  mesh   <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = cutoff)
  n_mesh <- ncol(mesh$A_st)

  Q   <- .spde_base_Q_dense(mesh, kappa_true)
  A   <- solve(Q)
  Sf  <- matrix(c(sd_a_p^2, rho * sd_a_p * sd_b_p,
                  rho * sd_a_p * sd_b_p, sd_b_p^2), 2, 2)
  chA <- t(chol(A + 1e-9 * diag(n_mesh)))
  chS <- chol(Sf)
  A_full <- as.matrix(mesh$A_st)
  if (isTRUE(per_trait)) {
    Omega <- matrix(NA_real_, nrow = n_mesh, ncol = 2L * n_traits)
    eta <- numeric(nrow(df))
    for (tt in seq_len(n_traits)) {
      cols <- c(2L * tt - 1L, 2L * tt)
      Omega[, cols] <- chA %*%
        matrix(stats::rnorm(n_mesh * 2L), n_mesh, 2L) %*% chS
      idx <- df$trait_id == tt
      A_t <- A_full[idx, , drop = FALSE]
      eta[idx] <- as.numeric(A_t %*% Omega[, cols[1L]]) +
        df$x[idx] * as.numeric(A_t %*% Omega[, cols[2L]])
    }
  } else {
    Omega <- chA %*% matrix(stats::rnorm(n_mesh * 2L), n_mesh, 2L) %*% chS
    eta <- as.numeric(A_full %*% Omega[, 1L]) +
      df$x * as.numeric(A_full %*% Omega[, 2L])
  }
  df$value <- stats::rnorm(n_traits, 0, 0.5)[df$trait_id] + eta +
    stats::rnorm(nrow(df), sd = sigma_eps)

  df$site         <- factor(df$site)
  df$species      <- factor(df$species)
  df$site_species <- factor(df$site_species)

  list(data = df, mesh = mesh)
}

## ======================================================================
## 1. spatial_unique(1 + x | coords): 2x2 Sigma with the right dimnames,
##    R[1,2] = reported cor_spde_b, kappa_s finite, and the marginal note.
## ======================================================================
test_that("extract_Sigma() on spatial_unique(1 + x | coords) returns the 2x2 base-slope block", {
  skip_if_not_heavy()
  skip_if_not_spatial()

  fx  <- .make_spde_base_slope_data(seed = 101, rho = -0.45,
                                    n_sites = 200L, cutoff = 0.07)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(1 + x | coords),
    data = fx$data, mesh = fx$mesh, silent = TRUE)))

  ## Gate flags: the base-slope branch is active and the dep / latent
  ## branches are not (the new fit$use$spde_slope flag drives dispatch).
  expect_true(isTRUE(fit$use$spde_slope))
  expect_false(isTRUE(fit$use$spde_dep_slope))
  expect_false(isTRUE(fit$use$spde_latent_slope))

  es <- extract_Sigma(fit, level = "spatial")

  ## Shape + dimnames (mirrors the spde_dep / phy_dep extractor contract,
  ## but a single 2x2 block over (intercept, slope), not trait-stacked).
  expect_type(es, "list")
  expect_equal(dim(es$Sigma), c(2L, 2L))
  expect_identical(rownames(es$Sigma), c("intercept", "slope"))
  expect_identical(colnames(es$Sigma), c("intercept", "slope"))
  expect_equal(dim(es$R), c(2L, 2L))
  expect_identical(rownames(es$R), c("intercept", "slope"))
  expect_identical(es$level, "spde_base_slope")
  expect_identical(es$part, "slope")

  ## Sigma is symmetric and PSD; diagonal = sd_spde_b^2.
  sd_b <- as.numeric(fit$report$sd_spde_b)
  expect_equal(unname(diag(es$Sigma)), sd_b^2, tolerance = 1e-8)
  expect_equal(es$Sigma[1L, 2L], es$Sigma[2L, 1L], tolerance = 1e-12)

  ## R[1,2] equals the reported cross-field correlation cor_spde_b.
  rho_rep <- as.numeric(fit$report$cor_spde_b)
  expect_equal(unname(es$R[1L, 2L]), rho_rep, tolerance = 1e-8)
  expect_equal(unname(diag(es$R)), c(1, 1), tolerance = 1e-8)

  ## kappa_s surfaced, finite, positive.
  expect_true(is.finite(es$kappa_s))
  expect_gt(es$kappa_s, 0)
  expect_equal(es$kappa_s, as.numeric(fit$report$kappa_s), tolerance = 1e-12)

  ## The note documents the scale + the marginal conversion formula
  ## (regression guard against silent removal of the scale caveat).
  expect_true(grepl("sqrt(4*pi)", es$note, fixed = TRUE))
  expect_true(grepl("parameterisation scale", es$note, fixed = TRUE))

  ## extract_Sigma(level = "spde") (legacy alias) routes to the same branch.
  es_legacy <- suppressWarnings(extract_Sigma(fit, level = "spde"))
  expect_equal(es_legacy$Sigma, es$Sigma, tolerance = 1e-12)
})

## ======================================================================
## 2. spatial_indep(1 + x | coords): per-trait block-diagonal route.
## ======================================================================
test_that("extract_Sigma() on spatial_indep(1 + x | coords) returns per-trait block-diagonal covariance", {
  skip_if_not_heavy()
  skip_if_not_spatial()

  fx  <- .make_spde_base_slope_data(seed = 202, rho = 0,
                                    n_sites = 200L, cutoff = 0.07,
                                    per_trait = TRUE)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_indep(1 + x | coords),
    data = fx$data, mesh = fx$mesh, silent = TRUE)))

  expect_true(isTRUE(fit$use$spde_slope))
  expect_true(isTRUE(fit$use$spde_dep_slope))
  expect_true(isTRUE(fit$use$spde_indep_slope))

  es <- extract_Sigma(fit, level = "spatial")

  ## Design 79/80: three independent 2x2 intercept/slope blocks, represented
  ## through the spatial-dep engine with cross-trait Cholesky entries pinned.
  T <- nlevels(fx$data$trait)
  C <- 2L * T
  expect_equal(dim(es$Sigma), c(C, C))
  expect_identical(es$level, "spde_indep_slope")
  expect_identical(es$part, "indep")
  expect_identical(
    rownames(es$Sigma),
    as.vector(rbind(
      paste0("intercept.", levels(fx$data$trait)),
      paste0("slope.", levels(fx$data$trait))
    ))
  )
  expect_identical(colnames(es$Sigma), rownames(es$Sigma))
  expect_true(grepl("field-covariance scale", es$note, fixed = TRUE))
  expect_true(grepl("4*pi*kappa^2", es$note, fixed = TRUE))
  block <- rep(seq_len(T), each = 2L)
  cross <- outer(block, block, `!=`)
  expect_lt(max(abs(es$R[cross])), 1e-6)
  ## Within-trait intercept--slope correlations remain free in the map; do
  ## not accidentally pin the complete matrix to a diagonal covariance.
  expect_equal(
    sum(!is.na(as.integer(fit$tmb_obj$env$map$theta_spde_dep_chol))),
    3L * T
  )
})

## ======================================================================
## 3. spatial_dep(1 + x | coords) still routes to the dep branch, NOT the
##    new base branch (both flags set; the !spde_dep_slope guard excludes).
## ======================================================================
test_that("spatial_dep(1 + x | coords) still routes to the dep branch (base guard excludes it)", {
  skip_if_not_heavy()
  skip_if_not_spatial()

  fx  <- .make_spde_base_slope_data(seed = 303, rho = -0.3,
                                    n_traits = 2L, n_sites = 160L, cutoff = 0.09)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_dep(1 + x | coords),
    data = fx$data, mesh = fx$mesh, silent = TRUE)))

  ## The dep path nests under use_spde_slope: BOTH flags are TRUE.
  expect_true(isTRUE(fit$use$spde_slope))
  expect_true(isTRUE(fit$use$spde_dep_slope))
  expect_false(isTRUE(fit$use$spde_indep_slope))

  es <- extract_Sigma(fit, level = "spatial")
  ## Dep branch returns the full unstructured 2T x 2T (here 4 x 4) field
  ## covariance with interleaved (intercept.t, slope.t) dimnames -- NOT the
  ## 2x2 base-slope block.
  expect_equal(dim(es$Sigma), c(4L, 4L))
  expect_identical(es$level, "spde_dep")
  expect_true(grepl("intercept", rownames(es$Sigma)[1L]))
})
