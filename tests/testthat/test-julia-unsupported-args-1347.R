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

## ---- the remaining accepted-but-dropped arguments (#1347, second pass) ----

test_that("engine = 'julia' refuses cluster2, phylo_vcv, phylo_tree and mesh before calling Julia", {
  local_mocked_bindings(.gllvmTMB_julia_dispatch = function(...) {
    stop("Julia dispatch must not be reached")
  })
  expect_error(
    fit_julia_1347(cluster2 = "unit"),
    "cluster2",
    class = "gllvmTMB_julia_unsupported_arg"
  )
  expect_error(
    suppressMessages(fit_julia_1347(phylo_vcv = diag(4L))),
    "phylo_vcv",
    class = "gllvmTMB_julia_unsupported_arg"
  )
  expect_error(
    suppressMessages(fit_julia_1347(phylo_tree = ape::rtree(4L))),
    "phylo_tree",
    class = "gllvmTMB_julia_unsupported_arg"
  )
  expect_error(
    fit_julia_1347(mesh = 1),
    "mesh",
    class = "gllvmTMB_julia_unsupported_arg"
  )
})

test_that("engine = 'julia' refuses a modelled missing predictor before calling Julia", {
  local_mocked_bindings(.gllvmTMB_julia_dispatch = function(...) {
    stop("Julia dispatch must not be reached")
  })
  df <- make_long_1347()
  df$x <- rnorm(nrow(df))
  df$x[3L] <- NA_real_
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + mi(x) + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = gaussian(),
      engine = "julia",
      missing = miss_control(predictor = "model"),
      impute = list(x ~ 1)
    ),
    "missing",
    class = "gllvmTMB_julia_unsupported_arg"
  )
})

test_that("engine = 'julia' refuses non-default control fields it never reads", {
  local_mocked_bindings(.gllvmTMB_julia_dispatch = function(...) {
    stop("Julia dispatch must not be reached")
  })
  expect_error(
    fit_julia_1347(control = gllvmTMBcontrol(aghq = 9L)),
    "aghq",
    class = "gllvmTMB_julia_unsupported_control"
  )
  expect_error(
    fit_julia_1347(control = gllvmTMBcontrol(d_B = 1L)),
    "d_B",
    class = "gllvmTMB_julia_unsupported_control"
  )
  expect_error(
    fit_julia_1347(control = gllvmTMBcontrol(init_strategy = "single_trait_warmup")),
    "init_strategy",
    class = "gllvmTMB_julia_unsupported_control"
  )
})

## ---- cases already refused upstream of the Julia block (#1347) ----
## Pinned here so a later refactor cannot reopen them: both abort in R before
## the dispatch is reached.

test_that("engine = julia refuses wrong-length binomial weights before calling Julia", {
  local_mocked_bindings(.gllvmTMB_julia_dispatch = function(...) {
    stop("Julia dispatch must not be reached")
  })
  df <- make_long_1347()
  df$value <- rbinom(nrow(df), 1L, 0.5)
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = binomial(),
      engine = "julia",
      weights = rep(1, 3L)
    ),
    "length-"
  )
})

test_that("engine = julia refuses impute without a modelled missing predictor before calling Julia", {
  local_mocked_bindings(.gllvmTMB_julia_dispatch = function(...) {
    stop("Julia dispatch must not be reached")
  })
  expect_error(
    fit_julia_1347(impute = list(x ~ 1)),
    "impute"
  )
})
