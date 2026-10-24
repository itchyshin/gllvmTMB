## Issue #1347: engine = "julia" accepted REML, lambda_constraint and known_V
## and then never passed them to GLLVModels.jl, so the fit silently ignored
## the request. Each is now refused in R, before any Julia call, with the
## class gllvmTMB_julia_unsupported_arg. No Julia is needed: the dispatch is
## mocked to fail loudly if it is ever reached.

make_long_1347 <- function(n = 20L, p = 4L) {
  set.seed(1347)
  df <- expand.grid(
    unit = factor(seq_len(n)),
    trait = factor(paste0("t", seq_len(p))),
    KEEP.OUT.ATTRS = FALSE
  )
  df$value <- rnorm(nrow(df))
  df
}

fit_julia_1347 <- function(...) {
  gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = make_long_1347(),
    trait = "trait",
    unit = "unit",
    family = gaussian(),
    engine = "julia",
    ...
  )
}

test_that("engine = 'julia' refuses REML = TRUE before calling Julia", {
  local_mocked_bindings(.gllvmTMB_julia_dispatch = function(...) {
    stop("Julia dispatch must not be reached")
  })
  expect_error(
    fit_julia_1347(REML = TRUE),
    "REML",
    class = "gllvmTMB_julia_unsupported_arg"
  )
})

test_that("engine = 'julia' refuses a non-NULL lambda_constraint before calling Julia", {
  local_mocked_bindings(.gllvmTMB_julia_dispatch = function(...) {
    stop("Julia dispatch must not be reached")
  })
  expect_error(
    fit_julia_1347(lambda_constraint = list(unit = matrix(NA_real_, 4L, 1L))),
    "lambda_constraint",
    class = "gllvmTMB_julia_unsupported_arg"
  )
})

test_that("engine = 'julia' refuses a non-NULL known_V before calling Julia", {
  local_mocked_bindings(.gllvmTMB_julia_dispatch = function(...) {
    stop("Julia dispatch must not be reached")
  })
  expect_error(
    fit_julia_1347(known_V = list(diag(4L))),
    "known_V",
    class = "gllvmTMB_julia_unsupported_arg"
  )
})

test_that("the defaults still reach the Julia dispatch", {
  local_mocked_bindings(.gllvmTMB_julia_dispatch = function(...) {
    stop("dispatch reached")
  })
  expect_error(fit_julia_1347(), "dispatch reached")
  expect_error(fit_julia_1347(REML = FALSE), "dispatch reached")
})
