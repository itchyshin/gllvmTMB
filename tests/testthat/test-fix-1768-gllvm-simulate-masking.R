## #1768. After library(gllvm), gllvm's simulate() generic masks
## stats::simulate(), so simulate(gllvmTMB_fit) fails to find
## simulate.gllvmTMB_multi. The gllvm-table registration must forward
## to stats::simulate() for gllvmTMB fit classes.

.fix1768 <- new.env(parent = emptyenv())

search_path_fun <- function(name) {
  get(name, envir = .GlobalEnv, mode = "function", inherits = TRUE)
}

fix1768_fit <- function() {
  if (!is.null(.fix1768$fit)) {
    return(.fix1768$fit)
  }
  set.seed(2)
  sim <- simulate_unit_trait(
    n_units = 16,
    n_obs_per_unit = 1,
    n_traits = 2,
    Lambda_B = matrix(c(0.6, 0.5), ncol = 1),
    psi_B = c(0.25, 0.25)
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

test_that("stats::simulate() works on a gllvmTMB fit without gllvm attached", {
  fit <- fix1768_fit()
  expect_s3_class(fit, "gllvmTMB_multi")
  sim <- stats::simulate(fit, nsim = 2, seed = 99L, condition_on_RE = TRUE)
  expect_true(is.matrix(sim))
  expect_identical(dim(sim), c(nrow(fit$data), 2L))
  expect_false(anyNA(sim))
})

test_that("attaching gllvm still dispatches simulate() to gllvmTMB (#1768)", {
  skip_if_not_installed("gllvm")
  fit <- fix1768_fit()
  namespaced <- stats::simulate(fit, nsim = 2, seed = 99L, condition_on_RE = TRUE)

  before <- search()
  suppressPackageStartupMessages(library(gllvm))
  on.exit(fix1768_detach_new(before), add = TRUE)

  expect_identical(find("simulate")[[1L]], "package:gllvm")
  expect_true(utils::isS3stdGeneric(search_path_fun("simulate")))

  s3_table <- asNamespace("gllvm")$.__S3MethodsTable__.
  expect_true("simulate.gllvmTMB" %in% names(s3_table))
  expect_true("simulate.gllvmTMB_multi" %in% names(s3_table))

  masked <- search_path_fun("simulate")(fit, nsim = 2, seed = 99L, condition_on_RE = TRUE)
  expect_true(is.matrix(masked))
  expect_identical(masked, namespaced)
  expect_identical(masked, stats::simulate(fit, nsim = 2, seed = 99L, condition_on_RE = TRUE))
})