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

## Empty lifecycle's per-session "already signalled" deprecation cache and
## restore it on test exit. lifecycle stores signalled ids in the internal
## environment `lifecycle:::deprecation_env`; wiping it forces deprecate_warn()
## to treat the next call as fresh so the warning re-emits. Guarded so it
## degrades to a no-op if that internal ever disappears.
local_reset_lifecycle_cache <- function(env = parent.frame()) {
  dep_env <- tryCatch(
    get("deprecation_env", envir = asNamespace("lifecycle")),
    error = function(e) NULL
  )
  if (is.null(dep_env) || !is.environment(dep_env)) {
    return(invisible(NULL))
  }
  saved <- as.list(dep_env, all.names = TRUE)
  withr::defer(
    {
      rlang::env_unbind(dep_env, rlang::env_names(dep_env))
      rlang::env_bind(dep_env, !!!saved)
    },
    envir = env
  )
  rlang::env_unbind(dep_env, rlang::env_names(dep_env))
  invisible(NULL)
}

test_that("spatial() emits a lifecycle deprecation warning", {
  ## lifecycle::deprecate_warn() fires each deprecation only ONCE PER SESSION
  ## by default: it records signalled ids in lifecycle's internal
  ## `deprecation_env` and returns early on subsequent hits. Re-running this
  ## file in one persistent R session (full devtools::test(), repeated
  ## test_file()) therefore suppresses the warning on the 2nd+ run and fails
  ## expect_warning(). The documented lifecycle_verbosity = "warning" knob
  ## only bypasses the cache for *direct* calls (is_direct(user_env) TRUE);
  ## here the deprecation is signalled deep inside gllvmTMB()'s formula
  ## parser, so it stays cached regardless. To make the assertion
  ## deterministic we (a) force hard warnings via lifecycle_verbosity and
  ## (b) clear lifecycle's signalled-deprecation cache for the duration of
  ## this test so the warning re-emits on every run.
  withr::local_options(lifecycle_verbosity = "warning")
  local_reset_lifecycle_cache()

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
