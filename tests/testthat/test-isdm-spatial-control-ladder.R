## Developer-only S3 spatial-control ladder for the synthetic GBIF-only
## Poisson slice.  This is deliberately a structural fit-input test, not a
## recovery study or an empirical ISDM analysis.
##
## Alignment (one row per modelled spatial term):
##   omega_t        | spatial_indep(..., common = TRUE) | independent fields |
##                  | no spatial cross-trait covariance | shared tau only
##   Lambda omega   | spatial_latent(..., d = 1)         | one shared field   |
##                  | Lambda_spde %*% t(Lambda_spde)    | rank <= 1

make_isdm_gbif_spatial_fixture <- function(seed = 20260810L) {
  testthat::skip_if_not_installed("fmesher")
  set.seed(seed)

  ## One synthetic GBIF count per (cell, trait); no survey rows, credentials,
  ## occurrence records, or empirical coordinates are used here.
  n_cell <- 28L
  n_trait <- 3L
  cells <- data.frame(
    cell_id = factor(seq_len(n_cell)),
    lon = stats::runif(n_cell),
    lat = stats::runif(n_cell),
    log_exposure = stats::runif(n_cell, -0.3, 0.3)
  )
  dat <- merge(
    cells,
    data.frame(trait = factor(paste0("taxon_", seq_len(n_trait)))),
    by = NULL
  )
  dat$source <- factor("GBIF", levels = "GBIF")
  dat$is_gbif <- TRUE
  trait_effect <- c(-0.25, 0.05, 0.28)
  dat$value <- stats::rpois(
    nrow(dat),
    lambda = exp(dat$log_exposure + trait_effect[as.integer(dat$trait)])
  )
  mesh <- tryCatch(
    gllvmTMB::make_mesh(dat, c("lon", "lat"), cutoff = 0.12),
    error = function(e) NULL
  )
  testthat::skip_if(is.null(mesh), "synthetic GBIF mesh build failed")
  list(data = dat, mesh = mesh, n_trait = n_trait)
}

test_that("synthetic GBIF-only S3 ladder distinguishes no spatial, independent, and rank-one spatial controls", {
  skip_on_cran()
  skip_if_not_heavy()
  fx <- make_isdm_gbif_spatial_fixture()

  fit_no_spatial <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + offset(log_exposure),
    data = fx$data, unit = "cell_id", family = poisson(), silent = TRUE
  )))
  expect_false(isTRUE(fit_no_spatial$use$spatial_indep))
  expect_false(isTRUE(fit_no_spatial$use$spatial_latent))
  expect_equal(fit_no_spatial$tmb_data$spde_lv_k, 0L)

  fit_indep_common <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + offset(log_exposure) +
      spatial_indep(0 + trait | cell_id, common = TRUE),
    data = fx$data, unit = "cell_id", mesh = fx$mesh, family = poisson(), silent = TRUE
  )))
  ## `common = TRUE` takes the scalar compatibility route internally; its
  ## covariance semantics remain independent fields with a shared variance.
  expect_true(isTRUE(fit_indep_common$use$spatial_scalar))
  expect_false(isTRUE(fit_indep_common$use$spatial_latent))
  ## The independent engine has one field per trait; `common` ties only tau.
  ## With no Lambda_spde axis there is no cross-trait spatial covariance.
  expect_equal(fit_indep_common$tmb_data$spde_lv_k, 0L)
  expect_true(all(is.na(fit_indep_common$tmb_map$theta_rr_spde_lv)))
  expect_equal(length(unique(stats::na.omit(fit_indep_common$tmb_map$log_tau_spde))), 1L)

  fit_latent_rank_one <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + offset(log_exposure) +
      spatial_latent(0 + trait | cell_id, d = 1),
    data = fx$data, unit = "cell_id", mesh = fx$mesh, family = poisson(), silent = TRUE
  )))
  expect_true(isTRUE(fit_latent_rank_one$use$spatial_latent))
  expect_false(isTRUE(fit_latent_rank_one$use$spatial_indep))
  expect_equal(fit_latent_rank_one$tmb_data$spde_lv_k, 1L)
  lambda <- fit_latent_rank_one$report$Lambda_spde
  expect_equal(dim(lambda), c(fx$n_trait, 1L))
  expect_lte(qr(lambda %*% t(lambda))$rank, 1L)

  ## Independent and latent spatial terms represent competing explanations;
  ## their duplication must fail before a TMB objective is constructed.
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + offset(log_exposure) +
        spatial_indep(0 + trait | cell_id, common = TRUE) +
        spatial_latent(0 + trait | cell_id, d = 1),
      data = fx$data, unit = "cell_id", mesh = fx$mesh, family = poisson(), silent = TRUE
    ))),
    regexp = "over-parameterised|cannot coexist|spatial_indep.*spatial_latent"
  )
})
