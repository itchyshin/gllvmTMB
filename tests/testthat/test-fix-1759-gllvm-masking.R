## #1759. gllvm's S3 generics mask gllvmTMB's getLoadings() / getLV()
## (and the residual covariance / correlation wrappers) after
## library(gllvm). The exported functions must keep their formals and
## their return values. When gllvm is attached, the unqualified call
## must dispatch to the same return value as the namespaced call.

.fix1759 <- new.env(parent = emptyenv())

## testthat sources this file with the package namespace as a parent, so a
## bare getLoadings() is the namespace function and never sees search-path
## masking. An interactive session looks up from .GlobalEnv along the
## search path. That is the lookup library(gllvm) interferes with.
search_path_fun <- function(name) {
  get(name, envir = .GlobalEnv, mode = "function", inherits = TRUE)
}

fix1759_fit <- function() {
  if (!is.null(.fix1759$fit)) {
    return(.fix1759$fit)
  }
  set.seed(1)
  sim <- simulate_unit_trait(
    n_units = 20,
    n_obs_per_unit = 1,
    n_traits = 3,
    Lambda_B = matrix(c(0.8, 0.4, -0.3), ncol = 1),
    psi_B = c(0.3, 0.3, 0.3)
  )
  .fix1759$fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = sim$data,
    trait = "trait",
    unit = "unit",
    silent = TRUE,
    control = gllvmTMBcontrol(n_init = 1L, laplace_auto_refit = FALSE)
  )))
  .fix1759$fit
}

fix1759_detach_new <- function(before) {
  extra <- setdiff(search(), before)
  for (pkg in extra) {
    if (startsWith(pkg, "package:")) {
      detach(pkg, character.only = TRUE)
    }
  }
}

test_that("exported getLoadings() and getLV() keep their signatures", {
  expect_false(utils::isS3stdGeneric(gllvmTMB::getLoadings))
  expect_false(utils::isS3stdGeneric(gllvmTMB::getLV))
  expect_false(utils::isS3stdGeneric(gllvmTMB::getResidualCov))
  expect_false(utils::isS3stdGeneric(gllvmTMB::getResidualCor))
  expect_identical(
    names(formals(gllvmTMB::getLoadings)),
    c("fit", "level", "rotate")
  )
  expect_identical(
    names(formals(gllvmTMB::getLV)),
    c("fit", "level", "rotate", "se")
  )
  expect_identical(names(formals(gllvmTMB::getResidualCov)), c("fit", "level"))
  expect_identical(names(formals(gllvmTMB::getResidualCor)), c("fit", "level"))
  expect_identical(formals(gllvmTMB::getLoadings)$level, "unit")
  expect_identical(
    deparse(formals(gllvmTMB::getLoadings)$rotate),
    "c(\"none\", \"varimax\", \"promax\")"
  )
  expect_identical(formals(gllvmTMB::getLV)$level, "unit")
  expect_false(formals(gllvmTMB::getLV)$se)
  expect_identical(formals(gllvmTMB::getResidualCov)$level, "unit")
  expect_identical(formals(gllvmTMB::getResidualCor)$level, "unit")
})

test_that("unmasked getLoadings() and getLV() match the namespaced calls", {
  if ("package:gllvm" %in% search()) {
    detach("package:gllvm", character.only = TRUE)
  }
  expect_identical(find("getLoadings")[[1L]], "package:gllvmTMB")
  expect_identical(find("getLV")[[1L]], "package:gllvmTMB")
  expect_identical(
    environmentName(environment(search_path_fun("getLoadings"))),
    "gllvmTMB"
  )
  expect_identical(
    environmentName(environment(search_path_fun("getLV"))),
    "gllvmTMB"
  )

  fit <- fix1759_fit()
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(inherits(fit, "gllvmTMB"))

  loadings <- search_path_fun("getLoadings")(fit)
  scores <- search_path_fun("getLV")(fit)
  expect_true(is.matrix(loadings))
  expect_true(is.matrix(scores))
  expect_identical(dim(loadings), c(3L, 1L))
  expect_identical(dim(scores), c(20L, 1L))
  expect_false(anyNA(loadings))
  expect_false(anyNA(scores))

  expect_identical(loadings, gllvmTMB::getLoadings(fit))
  expect_identical(scores, gllvmTMB::getLV(fit))
  expect_identical(
    search_path_fun("getLoadings")(fit, level = "unit", rotate = "none"),
    gllvmTMB::getLoadings(fit, level = "unit", rotate = "none")
  )
  expect_identical(
    search_path_fun("getLV")(fit, level = "unit", rotate = "none", se = FALSE),
    gllvmTMB::getLV(fit, level = "unit", rotate = "none", se = FALSE)
  )
  expect_identical(extract_loadings(fit), gllvmTMB::getLoadings(fit))
  cov_ns <- suppressMessages(gllvmTMB::getResidualCov(fit))
  cor_ns <- suppressMessages(gllvmTMB::getResidualCor(fit))
  expect_identical(suppressMessages(search_path_fun("getResidualCov")(fit)), cov_ns)
  expect_identical(suppressMessages(search_path_fun("getResidualCor")(fit)), cor_ns)
  expect_true(is.matrix(cov_ns))
  expect_identical(dim(cov_ns), c(3L, 3L))
})

test_that("attaching gllvm still dispatches getLoadings() and getLV() to gllvmTMB", {
  skip_if_not_installed("gllvm")
  fit <- fix1759_fit()
  namespaced_loadings <- gllvmTMB::getLoadings(fit)
  namespaced_scores <- gllvmTMB::getLV(fit)
  namespaced_cov <- suppressMessages(gllvmTMB::getResidualCov(fit))
  namespaced_cor <- suppressMessages(gllvmTMB::getResidualCor(fit))

  before <- search()
  suppressPackageStartupMessages(library(gllvm))
  on.exit(fix1759_detach_new(before), add = TRUE)

  expect_identical(find("getLoadings")[[1L]], "package:gllvm")
  expect_identical(find("getLV")[[1L]], "package:gllvm")
  expect_identical(environmentName(environment(search_path_fun("getLoadings"))), "gllvm")
  expect_identical(environmentName(environment(search_path_fun("getLV"))), "gllvm")
  expect_true(utils::isS3stdGeneric(search_path_fun("getLoadings")))
  expect_true(utils::isS3stdGeneric(search_path_fun("getLV")))
  expect_false(utils::isS3stdGeneric(gllvmTMB::getLoadings))
  expect_false(utils::isS3stdGeneric(gllvmTMB::getLV))
  expect_identical(
    names(formals(gllvmTMB::getLoadings)),
    c("fit", "level", "rotate")
  )
  expect_identical(
    names(formals(gllvmTMB::getLV)),
    c("fit", "level", "rotate", "se")
  )

  s3_table <- asNamespace("gllvm")$.__S3MethodsTable__.
  expect_true("getLoadings.gllvmTMB" %in% names(s3_table))
  expect_true("getLoadings.gllvmTMB_multi" %in% names(s3_table))
  expect_true("getLoadings.gllvmTMB_va" %in% names(s3_table))
  expect_true("getLoadings.gllvmTMB_mspl" %in% names(s3_table))
  expect_true("getLoadings.gllvmTMB_julia" %in% names(s3_table))
  expect_true("getLV.gllvmTMB" %in% names(s3_table))
  expect_true("getLV.gllvmTMB_multi" %in% names(s3_table))
  expect_true("getLV.gllvmTMB_julia" %in% names(s3_table))
  expect_true("getResidualCov.gllvmTMB" %in% names(s3_table))
  expect_true("getResidualCor.gllvmTMB" %in% names(s3_table))
  expect_true("getLoadings.gllvm" %in% names(s3_table))
  expect_true("getLV.gllvm" %in% names(s3_table))
  expect_false(is.null(getS3method(
    "getLoadings", "gllvmTMB", optional = TRUE, envir = .GlobalEnv
  )))
  expect_false(is.null(getS3method(
    "getLV", "gllvmTMB", optional = TRUE, envir = .GlobalEnv
  )))

  masked_loadings <- search_path_fun("getLoadings")
  masked_scores <- search_path_fun("getLV")
  expect_identical(masked_loadings(fit), namespaced_loadings)
  expect_identical(masked_loadings(fit), gllvmTMB::getLoadings(fit))
  expect_identical(
    masked_loadings(fit, level = "unit", rotate = "none"),
    gllvmTMB::getLoadings(fit, level = "unit", rotate = "none")
  )
  expect_identical(gllvm::getLoadings(fit), gllvmTMB::getLoadings(fit))
  expect_identical(masked_scores(fit), namespaced_scores)
  expect_identical(masked_scores(fit), gllvmTMB::getLV(fit))
  expect_identical(
    masked_scores(fit, level = "unit", rotate = "none", se = FALSE),
    gllvmTMB::getLV(fit, level = "unit", rotate = "none", se = FALSE)
  )
  expect_identical(gllvm::getLV(fit), gllvmTMB::getLV(fit))
  expect_identical(
    suppressMessages(search_path_fun("getResidualCov")(fit)),
    namespaced_cov
  )
  expect_identical(suppressMessages(gllvm::getResidualCov(fit)), namespaced_cov)
  expect_identical(
    suppressMessages(search_path_fun("getResidualCor")(fit)),
    namespaced_cor
  )
  expect_identical(suppressMessages(gllvm::getResidualCor(fit)), namespaced_cor)
  expect_identical(dim(masked_loadings(fit)), c(3L, 1L))
  expect_identical(dim(masked_scores(fit)), c(20L, 1L))
})
