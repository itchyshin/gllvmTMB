## Spatial-keyword formula orientation flip.
##
## At gllvmTMB 0.1.4 the canonical orientation for every spatial_*
## keyword is `0 + trait | coords`, parallel to `latent(0 + trait | g)`,
## `unique(0 + trait | g)`, and glmmTMB's `gau(0 + trait | pos)` /
## `exp(0 + trait | pos)`. The pre-0.1.4 orientation `coords | trait` is
## accepted as a deprecated alias and emits a one-shot
## `lifecycle::deprecate_warn()` per session.
##
## What this file covers:
##   (a) Canonical orientation `spatial_unique(0 + trait | coords)` fits
##       cleanly with no orientation-flip warning.
##   (b) Deprecated orientation `spatial_unique(coords | trait)` still
##       fits and emits the lifecycle warning.
##   (c) Byte-identical objective: the two orientations should produce
##       the same `fit$opt$objective` -- the flip is parser-only.
##   (d) Bad orientations are rejected with a clear `cli::cli_abort()`.
##   (e) Same coverage holds for `spatial_scalar()` and `spatial_latent()`.

skip_on_cran()

make_spatial_fixture <- function(seed = 1, n_traits = 2,
                                 sigma2_spa = c(0.4, 0.4)) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = n_traits,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = sigma2_spa,
    seed = seed
  )
  df <- sim$data
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.1)
  list(df = df, mesh = mesh)
}

test_that("spatial_unique(0 + trait | coords) is the silent canonical orientation", {
  fix <- make_spatial_fixture()
  ## Reset the lifecycle once-per-session cache so this test does not
  ## depend on whether any earlier test already triggered the warning.
  rlang::env_unbind(
    lifecycle:::deprecation_env,
    "gllvmTMB-spatial-orientation-flip-spatial_unique"
  )
  ## A canonical-orientation fit must NOT trigger the orientation-flip
  ## lifecycle warning. We catch all warnings and assert that none of
  ## them carry the orientation-flip id.
  ws <- list()
  suppressMessages(
    withCallingHandlers(
      gllvmTMB::gllvmTMB(
        value ~ 0 + trait + spatial_unique(0 + trait | coords),
        data = fix$df, mesh = fix$mesh, silent = TRUE),
      warning = function(w) {
        ws[[length(ws) + 1L]] <<- w
        invokeRestart("muffleWarning")
      })
  )
  msgs <- vapply(ws, conditionMessage, character(1))
  expect_false(any(grepl("spatial-orientation-flip|coords \\| trait",
                         msgs)),
               info = "Canonical orientation must not fire the flip warning.")
})

test_that("spatial_unique(coords | trait) emits a lifecycle deprecation warning", {
  fix <- make_spatial_fixture()
  rlang::env_unbind(
    lifecycle:::deprecation_env,
    "gllvmTMB-spatial-orientation-flip-spatial_unique"
  )
  expect_warning(
    suppressMessages(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_unique(coords | trait),
      data = fix$df, mesh = fix$mesh, silent = TRUE)),
    regexp = "deprecated|0 \\+ trait \\| coords"
  )
})

test_that("Both orientations of spatial_unique() give byte-identical fits", {
  fix <- make_spatial_fixture()
  fit_new <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords),
    data = fix$df, mesh = fix$mesh, silent = TRUE)))
  fit_old <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(coords | trait),
    data = fix$df, mesh = fix$mesh, silent = TRUE)))
  expect_equal(fit_new$opt$convergence, 0L)
  expect_equal(fit_old$opt$convergence, 0L)
  ## Parser-only flip -> identical converged objective and parameter count.
  expect_equal(fit_new$opt$objective, fit_old$opt$objective,
               tolerance = 1e-10)
  expect_equal(length(fit_new$opt$par), length(fit_old$opt$par))
})

test_that("Both orientations of spatial_scalar() give byte-identical fits", {
  fix <- make_spatial_fixture(n_traits = 3, sigma2_spa = rep(0.4, 3))
  fit_new <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_scalar(0 + trait | coords),
    data = fix$df, mesh = fix$mesh, silent = TRUE)))
  fit_old <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_scalar(coords | trait),
    data = fix$df, mesh = fix$mesh, silent = TRUE)))
  expect_equal(fit_new$opt$convergence, 0L)
  expect_equal(fit_old$opt$convergence, 0L)
  expect_equal(fit_new$opt$objective, fit_old$opt$objective,
               tolerance = 1e-10)
})

test_that("Both orientations of spatial_latent() give byte-identical fits", {
  fix <- make_spatial_fixture(n_traits = 3, sigma2_spa = rep(0.4, 3))
  fit_new <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_latent(0 + trait | coords, d = 2),
    data = fix$df, mesh = fix$mesh, silent = TRUE)))
  fit_old <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_latent(coords | trait, d = 2),
    data = fix$df, mesh = fix$mesh, silent = TRUE)))
  expect_equal(fit_new$opt$convergence, 0L)
  expect_equal(fit_old$opt$convergence, 0L)
  expect_equal(fit_new$opt$objective, fit_old$opt$objective,
               tolerance = 1e-10)
})

test_that("Malformed spatial_*() bar is rejected with a clear error", {
  fix <- make_spatial_fixture()
  ## LHS = `0 + foo` is fine syntactically but the user is expected to
  ## use the literal `trait` symbol on LHS. We cannot validate that the
  ## name is *actually* the trait column at parse time (the engine reads
  ## neither side of the bar for spde), so the only structurally-bad
  ## cases we trap at parse time are non-bar arguments.
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_unique(coords),
      data = fix$df, mesh = fix$mesh, silent = TRUE),
    regexp = "0 \\+ trait \\| coords|formula"
  )
})

test_that("spatial(coords | trait) (deprecated keyword + orientation) still works", {
  ## The doubly-deprecated form: deprecated keyword `spatial()` (alias
  ## for spatial_unique() since 0.1.2) AND deprecated orientation
  ## (alias for `0 + trait | coords` since 0.1.4). Both warnings should
  ## fire but the fit should still converge identically.
  fix <- make_spatial_fixture()
  fit_doubly <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial(coords | trait),
    data = fix$df, mesh = fix$mesh, silent = TRUE)))
  fit_canon <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait | coords),
    data = fix$df, mesh = fix$mesh, silent = TRUE)))
  expect_equal(fit_doubly$opt$convergence, 0L)
  expect_equal(fit_canon$opt$convergence, 0L)
  expect_equal(fit_doubly$opt$objective, fit_canon$opt$objective,
               tolerance = 1e-10)
})
