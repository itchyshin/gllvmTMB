## #1768. gllvm's `simulate` generic masks `stats::simulate` after
## `library(gllvm)`. gllvmTMB registers simulate methods on the stats
## generic only; an unqualified `simulate(gllvmTMB_fit)` must still reach
## gllvmTMB's method.

.fix1768 <- new.env(parent = emptyenv())

search_path_fun <- function(name) {
  get(name, envir = .GlobalEnv, mode = "function", inherits = TRUE)
}

fix1768_fit <- function() {
  if (!is.null(.fix1768$fit)) {
    return(.fix1768$fit)
  }
  set.seed(1)
  sim <- simulate_unit_trait(
    n_units = 20,
    n_obs_per_unit = 1,
    n_traits = 3,
    Lambda_B = matrix(c(0.8, 0.4, -0.3), ncol = 1),
    psi_B = c(0.3, 0.3, 0.3)
  )
  .fix1768$fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = sim$data,
    trait = "trait",
    unit = "unit",
    silent = TRUE,
    control = gllvmTMBcontrol(n_init = 1L, laplace_auto_refit = FALSE)
  )))
  .fix1768$fit
}

fix1768_detach_new <- function(before) {
  extra <- setdiff(search(), before)
  for (pkg in extra) {
    if (startsWith(pkg, "package:")) {
      detach(pkg, character.only = TRUE)
    }
  }
}

test_that("attaching gllvm still dispatches simulate() to gllvmTMB", {
  skip_if_not_installed("gllvm")
  fit <- fix1768_fit()
  sim_args <- list(nsim = 1L, seed = 1768L)
  namespaced <- do.call(stats::simulate, c(list(fit), sim_args))
  expect_true(is.data.frame(namespaced) || is.matrix(namespaced))

  before <- search()
  suppressPackageStartupMessages(library(gllvm))
  on.exit(fix1768_detach_new(before), add = TRUE)

  expect_identical(find("simulate")[[1L]], "package:gllvm")
  expect_identical(
    environmentName(environment(search_path_fun("simulate"))),
    "gllvm"
  )
  expect_true(utils::isS3stdGeneric(search_path_fun("simulate")))

  s3_table <- asNamespace("gllvm")$.__S3MethodsTable__.
  expect_true("simulate.gllvmTMB" %in% names(s3_table))
  expect_true("simulate.gllvmTMB_multi" %in% names(s3_table))
  expect_false(is.null(getS3method(
    "simulate", "gllvmTMB_multi", optional = TRUE, envir = .GlobalEnv
  )))

  masked <- do.call(search_path_fun("simulate"), c(list(fit), sim_args))
  expect_identical(masked, namespaced)
  expect_identical(do.call(gllvm::simulate, c(list(fit), sim_args)), namespaced)
  expect_identical(do.call(stats::simulate, c(list(fit), sim_args)), namespaced)
})