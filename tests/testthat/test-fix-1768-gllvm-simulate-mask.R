## #1768: after library(gllvm), stats::simulate is masked and simulate(fit)
## may not reach gllvmTMB's method. This test fails on main when gllvm is
## installed and the S3 registration is missing.

.fix1768_env <- new.env(parent = emptyenv())

.fix1768_fit <- function() {
  if (!is.null(.fix1768_env$fit)) {
    return(.fix1768_env$fit)
  }
  set.seed(1768L)
  sim <- simulate_unit_trait(
    n_units = 16L,
    n_obs_per_unit = 1L,
    n_traits = 2L,
    Lambda_B = matrix(c(0.7, 0.3), ncol = 1L),
    psi_B = c(0.25, 0.25)
  )
  .fix1768_env$fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1L, unique = FALSE),
    data = sim$data,
    trait = "trait",
    unit = "unit",
    silent = TRUE,
    control = gllvmTMBcontrol(n_init = 1L, laplace_auto_refit = FALSE)
  )))
  .fix1768_env$fit
}

.search_path_fun <- function(name) {
  get(name, envir = .GlobalEnv, mode = "function", inherits = TRUE)
}

test_that("attaching gllvm still dispatches simulate() to gllvmTMB", {
  skip_on_cran()
  skip_if_not_installed("gllvm")
  skip_if_not_installed("TMB")

  fit <- .fix1768_fit()
  nsim <- 2L
  seed <- 1768L
  namespaced <- stats::simulate(fit, nsim = nsim, seed = seed)

  before <- search()
  suppressPackageStartupMessages(library(gllvm))
  on.exit({
    extra <- setdiff(search(), before)
    for (pkg in extra) {
      if (startsWith(pkg, "package:")) {
        detach(pkg, character.only = TRUE)
      }
    }
  }, add = TRUE)

  expect_identical(find("simulate")[[1L]], "package:gllvm")
  expect_true(utils::isS3stdGeneric(.search_path_fun("simulate")))

  s3_table <- asNamespace("gllvm")$.__S3MethodsTable__.
  expect_true("simulate.gllvmTMB_multi" %in% names(s3_table))

  masked <- .search_path_fun("simulate")(fit, nsim = nsim, seed = seed)
  expect_identical(masked, namespaced)
  expect_identical(dim(masked), c(nrow(fit$data), nsim))
})