## `mesh=` with no spatial term must not be silently ignored (#1165).
##
## Mesh validation used to run only under `use_spde` / `use_spde_slope` /
## `use_spde_latent_slope`. A user could pass a raw fmesher/INLA mesh,
## forget the spatial term, and get a clean converged non-spatial fit
## identical to the no-mesh fit -- then write science about a spatial
## mechanism that never ran. Same silent-fallback class as #1163.
##
## Contract:
##   * mesh non-NULL, no spatial term -> classed warning that names both
##     possible mistakes (missing `spatial_*()` term, or leftover mesh)
##   * a raw / non-`gllvmTMBmesh` object is then rejected by the existing
##     `make_mesh()` validator (the path that already ran when a spatial
##     term WAS present)
##   * a valid `make_mesh()` object still fits, as a non-spatial model,
##     after the warning
##   * a spatial term still consumes `mesh=` without that unused-mesh
##     warning (the guard is not over-broad)
##
## These tests are deliberately cheap and un-gated on CRAN skip only
## where a real mesh or spatial fit is required. The failure they guard
## is silent, so the non-mesh rejection must run on an ordinary check.

.mu_data <- function(n = 24L, seed = 7L) {
  set.seed(seed)
  loc <- data.frame(x = stats::runif(n, 0, 1), y = stats::runif(n, 0, 1))
  data.frame(
    site  = factor(rep(seq_len(n), 2L)),
    trait = factor(rep(c("A", "B"), each = n)),
    x     = rep(loc$x, 2L),
    y     = rep(loc$y, 2L),
    value = stats::rnorm(2L * n)
  )
}

.mu_fit_args <- function(d, mesh = NULL) {
  list(
    formula = value ~ 0 + trait,
    data = d,
    trait = "trait",
    unit = "site",
    family = gaussian(),
    mesh = mesh,
    silent = TRUE,
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
  )
}

test_that("a non-mesh object with no spatial term is rejected, not ignored", {
  d <- .mu_data()
  args <- .mu_fit_args(d, mesh = "not-a-mesh")
  expect_warning(
    expect_error(do.call(gllvmTMB, args), "make_mesh"),
    class = "gllvmTMB_unused_mesh"
  )
})

test_that("the unused-mesh warning names both possible mistakes", {
  d <- .mu_data()
  args <- .mu_fit_args(d, mesh = 42)
  wrn <- tryCatch(
    tryCatch(do.call(gllvmTMB, args), error = function(e) NULL),
    warning = function(w) w
  )
  expect_s3_class(wrn, "gllvmTMB_unused_mesh")
  msg <- conditionMessage(wrn)
  expect_match(msg, "no spatial term", ignore.case = TRUE)
  expect_match(msg, "spatial_")
  expect_match(msg, "removed")
})

.mu_unused_warning <- function(expr) {
  unused <- NULL
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      if (inherits(w, "gllvmTMB_unused_mesh")) unused <<- w
      tryInvokeRestart("muffleWarning")
    }
  )
  list(value = value, unused = unused)
}

test_that("no mesh and no spatial term still fits (the guard is not over-broad)", {
  d <- .mu_data()
  args <- .mu_fit_args(d, mesh = NULL)
  got <- .mu_unused_warning(do.call(gllvmTMB, args))
  expect_null(got$unused)
  expect_s3_class(got$value, "gllvmTMB")
})

test_that("a valid unused make_mesh() warns and fits the same non-spatial model", {
  skip_if_not_installed("fmesher")
  d <- .mu_data()
  mesh <- make_mesh(d, c("x", "y"), cutoff = 0.25)
  args_none <- .mu_fit_args(d, mesh = NULL)
  args_mesh <- .mu_fit_args(d, mesh = mesh)
  fit_none <- do.call(gllvmTMB, args_none)
  expect_warning(
    fit_mesh <- do.call(gllvmTMB, args_mesh),
    class = "gllvmTMB_unused_mesh"
  )
  expect_equal(fit_none$opt$objective, fit_mesh$opt$objective)
  expect_equal(fit_none$opt$convergence, fit_mesh$opt$convergence)
})

test_that("a raw fmesher mesh with no spatial term errors after the unused warning", {
  skip_if_not_installed("fmesher")
  d <- .mu_data()
  raw <- fmesher::fm_mesh_2d(
    loc = as.matrix(unique(d[, c("x", "y")])),
    max.edge = c(0.4, 1),
    cutoff = 0.15
  )
  args <- .mu_fit_args(d, mesh = raw)
  expect_warning(
    expect_error(do.call(gllvmTMB, args), "make_mesh"),
    class = "gllvmTMB_unused_mesh"
  )
})

test_that("a spatial term still consumes mesh= without the unused-mesh warning", {
  skip_on_cran()
  skip_if_not_installed("fmesher")
  set.seed(1)
  sim <- simulate_site_trait(
    n_sites = 24, n_species = 1, n_traits = 2,
    mean_species_per_site = 1,
    spatial_range = 0.3, sigma2_spa = c(0.3, 0.3),
    seed = 1
  )
  df <- sim$data
  mesh <- tryCatch(
    make_mesh(df, c("lon", "lat"), cutoff = 0.12),
    error = function(e) NULL
  )
  skip_if(is.null(mesh), "mesh build failed")
  got <- .mu_unused_warning(gllvmTMB(
    value ~ 0 + trait + spatial_indep(0 + trait | coords),
    data = df, mesh = mesh, silent = TRUE,
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
  ))
  expect_null(got$unused)
  expect_s3_class(got$value, "gllvmTMB")
})
