## Design 79 §4 (B2b) -- spatial `||` uncorrelated random slope.
## spatial_indep(1 + x || coords) = fully diagonal Sigma_field (2T free
## theta_spde_dep_chol, block_size 1); spatial_dep(1 + x || coords) =
## Sigma_int (+) Sigma_slope via the parity pin (T(T+1) free). Both ride the same
## spde dep-slope engine as their `|` forms. `latent` accepts the `||` spelling
## (already uncorrelated). Structural (construction-time) contract; spatial dep
## slopes are weakly identified on modest data (convergence is a follow-up).

skip_spatial <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  if (!identical(Sys.getenv("GLLVMTMB_HEAVY_TESTS"), "1")) {
    testthat::skip("heavy recovery test; set GLLVMTMB_HEAVY_TESTS=1 to run")
  }
}

make_sp_fx <- function(seed, n_sites = 170L, n_traits = 3L, range = 0.3, cutoff = 0.09) {
  set.seed(seed)
  coords <- cbind(lon = stats::runif(n_sites), lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites), trait_id = seq_len(n_traits))
  df$trait <- factor(paste0("t", df$trait_id), levels = paste0("t", seq_len(n_traits)))
  df$lon <- coords[df$site, 1]; df$lat <- coords[df$site, 2]
  df$x <- stats::rnorm(nrow(df)); df$site <- factor(df$site)
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = cutoff)
  kappa <- sqrt(8) / range
  M0 <- as.matrix(mesh$spde$c0); M1 <- as.matrix(mesh$spde$g1); M2 <- as.matrix(mesh$spde$g2)
  Q <- kappa^4 * M0 + 2 * kappa^2 * M1 + M2
  Lq <- t(chol(Q)); n_mesh <- nrow(Q); Ast <- mesh$A_st
  fld <- function(s) as.numeric(Ast %*% backsolve(t(Lq), stats::rnorm(n_mesh))) * s
  val <- numeric(nrow(df))
  for (t in seq_len(n_traits)) {
    a <- fld(0.7); b <- fld(0.5); idx <- df$trait_id == t
    val[idx] <- a[idx] + df$x[idx] * b[idx]
  }
  df$value <- val + stats::rnorm(nrow(df), 0, 0.15)
  list(df = df, mesh = mesh)
}

.fit <- function(fx, mode, cp) suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  stats::as.formula(sprintf("value ~ 0 + trait + spatial_%s(1 + x %s site, mesh = mesh)", mode, cp)),
  data = fx$df, mesh = fx$mesh, unit = "site", cluster = "site",
  family = stats::gaussian(), silent = TRUE)))
.nchol <- function(f) sum(!is.na(as.integer(f$tmb_obj$env$map$theta_spde_dep_chol)))

test_that("spatial_indep(1 + x || coords) is fully diagonal (2T), vs 3T for `|`", {
  skip_spatial()
  fx <- make_sp_fx(seed = 5L); T <- 3L
  fu <- .fit(fx, "indep", "||"); fc <- .fit(fx, "indep", "|")
  expect_equal(fu$tmb_data$n_lhs_cols_spde, 2L * T)
  expect_equal(.nchol(fu), 2L * T)          # fully diagonal (block_size 1)
  expect_equal(.nchol(fc), 3L * T)          # correlated per-trait 2x2 blocks
  expect_equal(fu$opt$convergence, 0L)      # indep|| is well identified here
})

test_that("spatial_dep(1 + x || coords) = Sigma_int (+) Sigma_slope (T(T+1) free)", {
  skip_spatial()
  fx <- make_sp_fx(seed = 6L); T <- 3L
  fu <- .fit(fx, "dep", "||")
  ## Parity pin: T(T+1) free theta_spde_dep_chol (two T x T Cholesky blocks),
  ## vs the full 2T(2T+1)/2 for spatial_dep `|`. Construction-time contract.
  expect_equal(.nchol(fu), T * (T + 1L))
  expect_equal(fu$tmb_data$n_lhs_cols_spde, 2L * T)
})
