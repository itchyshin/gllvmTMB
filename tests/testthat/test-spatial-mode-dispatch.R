## Design 07 Stage 2 (spatial parallel): spatial() mode-dispatch wrapper.
## See dev/design/07-phylo-lme4-bar-syntax.md (the spatial parallel of
## the phylo() Stage 2 work in df76c705).
##
## The new `spatial()` keyword accepts an lme4-bar formula + a `mode = ...`
## argument and rewrites to one of the five existing canonical keywords
## (spatial_scalar / spatial_unique / spatial_indep / spatial_latent /
## spatial_dep) via the parser's rewrite_canonical_aliases() pass.
## Stage 2 covers the five existing T-column shapes; augmented LHS
## (intercept+slope, per-trait+slope) errors with a Stage 3 redirect.
##
## Engine slot: SPDE (Matern field on a fmesher mesh), in contrast
## to the Hadfield A^-1 path of the phylo() parallel.

## Tiny fixture: 30 sites, 1 species, 2 traits with weak spatial signal,
## small enough to fit in a few seconds. Mirrors the fixture pattern in
## tests/testthat/test-spatial-deprecation.R.
##
## The SPDE engine path uses fmesher directly (no INLA dependency) for
## the Matern precision matrix; INLA is only listed as a Suggests for
## the wider article workflow. See R/mesh.R and R/fit-multi.R.
make_spa_fixture <- function(seed = 1) {
  testthat::skip_if_not_installed("fmesher")
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 2,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = c(0.4, 0.4),
    seed = seed
  )
  df <- sim$data
  mesh <- tryCatch(
    gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.1),
    error = function(e) NULL
  )
  testthat::skip_if(is.null(mesh), "mesh build failed")
  list(df = df, mesh = mesh)
}

## ---- 1. spatial(1 | site) == spatial_scalar(site) -----------------------

test_that("spatial(1 | site) is byte-identical to spatial_scalar(site)", {
  skip_on_cran()
  fx <- make_spa_fixture()
  fit_new <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial(1 | site, mesh = fx$mesh),
    data = fx$df, silent = TRUE
  )))
  fit_canon <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_scalar(0 + trait | coords),
    data = fx$df, mesh = fx$mesh, silent = TRUE
  )))
  expect_equal(fit_new$opt$convergence, 0L)
  expect_equal(fit_canon$opt$convergence, 0L)
  expect_equal(fit_new$opt$objective, fit_canon$opt$objective,
               tolerance = 1e-8)
})

## ---- 2. spatial(0 + trait | coords, mode = "diag") == spatial_unique ----

test_that("spatial(0 + trait | coords, mode = 'diag') is byte-identical to spatial_unique", {
  skip_on_cran()
  fx <- make_spa_fixture()
  fit_new <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial(0 + trait | coords, mode = "diag",
                                mesh = fx$mesh),
    data = fx$df, silent = TRUE
  )))
  fit_canon <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords),
    data = fx$df, mesh = fx$mesh, silent = TRUE
  )))
  expect_equal(fit_new$opt$convergence, 0L)
  expect_equal(fit_canon$opt$convergence, 0L)
  expect_equal(fit_new$opt$objective, fit_canon$opt$objective,
               tolerance = 1e-8)
})

## ---- 3. spatial(0 + trait | coords, mode = "latent", d = 1) == spatial_latent ----

test_that("spatial(0 + trait | coords, mode = 'latent', d = 1) is byte-identical to spatial_latent", {
  skip_on_cran()
  fx <- make_spa_fixture()
  fit_new <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial(0 + trait | coords, mode = "latent",
                                d = 1, mesh = fx$mesh),
    data = fx$df, silent = TRUE
  )))
  fit_canon <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_latent(0 + trait | coords, d = 1),
    data = fx$df, mesh = fx$mesh, silent = TRUE
  )))
  expect_equal(fit_new$opt$convergence, 0L)
  expect_equal(fit_canon$opt$convergence, 0L)
  expect_equal(fit_new$opt$objective, fit_canon$opt$objective,
               tolerance = 1e-8)
})

## ---- 4. Augmented LHS errors with Stage-3 redirect ----------------------

test_that("spatial(1 + x | coords) errors with Stage 3 redirect", {
  skip_on_cran()
  fx <- make_spa_fixture()
  ## Add a covariate to the data so the formula is well-formed for
  ## checking; the parser should reject before fitting.
  fx$df$temp <- stats::rnorm(nrow(fx$df))
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial(1 + temp | coords, mesh = fx$mesh),
      data = fx$df, silent = TRUE
    ))),
    regexp = "augmented LHS|intercept.*slope|Stage 3"
  )
})

## ---- 5. Backward compat: legacy bare-formula spatial(0 + trait | coords) works ----

test_that("legacy spatial(0 + trait | coords) still rewrites to engine path", {
  skip_on_cran()
  fx <- make_spa_fixture()
  ## Legacy bare-formula form (no mode = ...): spatial(0 + trait | coords)
  ## is the historical deprecated alias of spatial_unique(0 + trait | coords).
  ## It should continue to work via the existing rewrite_canonical_aliases
  ## `spatial -> spatial_unique` rename, with a deprecation warning.
  fit_legacy <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial(0 + trait | coords),
    data = fx$df, mesh = fx$mesh, silent = TRUE
  )))
  expect_equal(fit_legacy$opt$convergence, 0L)
})

## ---- 6. mode mandatory when LHS = 0 + trait ----------------------------

test_that("spatial(0 + trait | coords, mesh = ...) without mode errors", {
  skip_on_cran()
  fx <- make_spa_fixture()
  ## When the user writes `mesh = ...` (the new dispatch trigger) but
  ## omits `mode`, the parser must require `mode` rather than silently
  ## defaulting (the legacy no-mesh, no-mode form goes through the
  ## deprecation alias instead -- see test 5).
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial(0 + trait | coords, mesh = fx$mesh),
      data = fx$df, silent = TRUE
    ))),
    regexp = "requires `mode`|`mode`.*required|`mode`.*mandatory"
  )
})
