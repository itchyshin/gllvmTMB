## Issue #1371: engine = "julia" did not check a fixed-effect covariate for NA.
## The response mask is built from the response only, so the NA cells reached
## gllvm_julia_fit() inside the p x n x q covariate array, while engine = "tmb"
## aborts. Contract: the julia route aborts with the native wording before any
## bridge call. gllvm_julia_fit is mocked, so no Julia is started.

.na_1371_fixture <- function(na_units = integer(0)) {
  set.seed(1)
  n <- 40L
  p <- 4L
  df <- expand.grid(
    unit = factor(seq_len(n)),
    trait = factor(paste0("t", seq_len(p))),
    KEEP.OUT.ATTRS = FALSE
  )
  z <- rnorm(n)
  L <- c(1, 0.8, 0.5, -0.6)
  df$env <- rnorm(n)[as.integer(df$unit)]
  df$value <- L[as.integer(df$trait)] * z[as.integer(df$unit)] +
    0.5 * df$env + rnorm(nrow(df))
  df$env[df$unit %in% na_units] <- NA_real_
  df
}

.na_1371_fit <- function(df, engine = "julia") {
  gllvmTMB(
    value ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
    data = df, unit = "unit", trait = "trait",
    family = gaussian(), engine = engine
  )
}

test_that("julia route aborts on NA in a fixed-effect covariate before any bridge call", {
  withr::local_envvar(GLLVMODELS_JL_PATH = tempdir())
  reached <- FALSE
  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(y, ...) {
      reached <<- TRUE
      stop("STUB: reached gllvm_julia_fit")
    }
  )
  df <- .na_1371_fixture(na_units = c(3L, 17L))
  expect_error(
    .na_1371_fit(df),
    "NA in the fixed-effect design matrix"
  )
  expect_false(reached)
})

test_that("julia route still reaches the bridge when the covariate is complete", {
  withr::local_envvar(GLLVMODELS_JL_PATH = tempdir())
  sent <- NULL
  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(y, ...) {
      sent <<- list(...)
      stop("STUB: reached gllvm_julia_fit")
    }
  )
  df <- .na_1371_fixture()
  err <- tryCatch(.na_1371_fit(df), error = function(e) e)
  expect_match(conditionMessage(err), "STUB: reached gllvm_julia_fit", fixed = TRUE)
  expect_false(anyNA(sent$X))
})
