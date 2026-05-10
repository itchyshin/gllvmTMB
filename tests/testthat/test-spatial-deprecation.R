## spatial() -> spatial_unique() deprecation shim, introduced at gllvmTMB
## 0.1.2. Calling spatial() should:
##   (a) emit a lifecycle deprecation warning (lifecycle::deprecate_warn),
##   (b) route to the same internal handler as spatial_unique() (i.e.
##       fit identically), and
##   (c) the printed covstruct label should resolve to "spatial_unique"
##       (not "spatial") because the canonical name is now the
##       unique-rank one in the 3 x 3 grid.
##
## Both formula orientations are accepted: the canonical
## `spatial_unique(0 + trait | coords)` and the deprecated
## `spatial_unique(coords | trait)`. The latter triggers a separate
## lifecycle warning at gllvmTMB 0.1.4 (orientation flip); see
## `test-spatial-orientation.R` for the dedicated coverage.

skip_on_cran()

test_that("spatial() emits a lifecycle deprecation warning", {
  set.seed(1)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 2,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = c(0.4, 0.4),
    seed = 1
  )
  df <- sim$data
  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.1)

  ## lifecycle warnings carry class "lifecycle_warning_deprecated";
  ## expect_warning() with regexp picks up the message text. We use the
  ## canonical orientation here so this test only fires the keyword
  ## deprecation, not the orientation-flip one.
  expect_warning(
    suppressMessages(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial(0 + trait | coords),
      data = df, mesh = mesh, silent = TRUE)),
    regexp = "deprecated|spatial_unique"
  )
})

test_that("spatial() and spatial_unique() produce identical fits", {
  set.seed(1)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 2,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = c(0.4, 0.4),
    seed = 1
  )
  df <- sim$data
  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.1)

  fit_old <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE)))
  fit_new <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE)))

  expect_equal(fit_old$opt$convergence, 0L)
  expect_equal(fit_new$opt$convergence, 0L)
  ## Same engine path -> same converged log-likelihood.
  expect_equal(-fit_old$opt$objective, -fit_new$opt$objective,
               tolerance = 1e-8)
  ## Same number of free parameters.
  expect_equal(length(fit_old$opt$par), length(fit_new$opt$par))
})

test_that("printed covstruct label is spatial_unique (not spatial)", {
  set.seed(1)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 2,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = c(0.4, 0.4),
    seed = 1
  )
  df <- sim$data
  mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.1)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE)))
  out <- capture.output(print(fit))
  cov_line <- grep("Covstructs:", out, value = TRUE)
  expect_match(cov_line, "spatial_unique",
               info = "Print should show the canonical name spatial_unique.")
  expect_false(grepl("\\bspatial\\b(?! [_a-z])", cov_line, perl = TRUE),
               info = "Print should NOT show the bare 'spatial' label.")
})
