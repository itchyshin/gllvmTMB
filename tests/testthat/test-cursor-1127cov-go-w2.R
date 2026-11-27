## Coverage slice: R/[p-s]* helpers outside the 1127cov go lane (cursor-cloud-1127cov w2).
## Fast unit tests on documented contracts — no fits unless unavoidable.

test_that(".gllvm_mask_is_generic() classifies generics and plain functions", {
  is_gen <- gllvmTMB:::.gllvm_mask_is_generic
  expect_false(is_gen("character"))
  expect_false(is_gen(function(x) x))
  usemethod_fn <- function(x) UseMethod("disp")
  expect_true(is_gen(usemethod_fn))
  expect_true(is_gen(stats::simulate))
})

test_that(".gllvm_mask_call() forwards `object` as `fit`", {
  recorded <- list()
  stub_fn <- function(fit, ...) {
    recorded$fit <<- fit
    recorded$dots <<- list(...)
    99L
  }
  obj <- structure(list(id = 7L), class = "gllvmTMB_multi")
  expect_identical(
    gllvmTMB:::.gllvm_mask_call(stub_fn, obj, rotate = TRUE),
    99L
  )
  expect_identical(recorded$fit, obj)
  expect_identical(recorded$dots, list(rotate = TRUE))
})

test_that(".register_gllvm_masking_methods() is a no-op when gllvm is absent", {
  skip_if(requireNamespace("gllvm", quietly = TRUE))
  expect_false(gllvmTMB:::.register_gllvm_masking_methods())
})

test_that(".register_gllvm_masking_methods() registers on gllvm when installed", {
  skip_if_not_installed("gllvm")
  skip_if_not(requireNamespace("gllvm", quietly = TRUE))
  gllvmTMB:::.register_gllvm_masking_methods()
  fn <- utils::getS3method("getLoadings", "gllvmTMB", envir = asNamespace("gllvm"))
  expect_true(is.function(fn))
})

test_that(".gllvmTMB_jitter_offsets() honours n and reproducibility", {
  expect_equal(gllvmTMB:::.gllvmTMB_jitter_offsets(0L, 4L, 0.05), list())
  set.seed(1)
  a <- runif(1)
  set.seed(1)
  x <- gllvmTMB:::.gllvmTMB_jitter_offsets(2L, 3L, 0.1, seed = 99L)
  expect_identical(a, runif(1))
  set.seed(1)
  y <- gllvmTMB:::.gllvmTMB_jitter_offsets(2L, 3L, 0.1, seed = 99L)
  expect_equal(x, y)
  expect_length(x, 2L)
  expect_length(x[[1L]], 3L)
  expect_type(x[[1L]], "double")
})

test_that("coef.gllvmTMB_multi() and vcov.gllvmTMB_multi() expose the X_fix block", {
  set.seed(1127)
  d <- data.frame(
    unit = factor(rep(1:8, each = 2)),
    trait = factor(rep(c("a", "b"), 8)),
    value = stats::rnorm(16)
  )
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait,
    data = d,
    unit = "unit",
    trait = "trait",
    family = gaussian(),
    control = gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = TRUE)
  ))
  nm <- fit$X_fix_names
  cfix <- coef(fit)
  expect_named(cfix, nm)
  expect_equal(unname(cfix), unname(gllvmTMB:::.gllvmTMB_b_fix_values(fit)))
  V <- vcov(fit)
  expect_equal(dim(V), c(length(nm), length(nm)))
  expect_identical(rownames(V), nm)
  expect_identical(colnames(V), nm)
  expect_true(all(is.finite(V[!is.na(V)])))
})

test_that("coef.gllvmTMB_multi() returns an empty named vector when there are no fixed effects", {
  fit <- list(X_fix_names = character(0), opt = list(par = numeric(0)))
  class(fit) <- "gllvmTMB_multi"
  expect_equal(coef(fit), stats::setNames(numeric(0), character(0)))
  V <- vcov(fit)
  expect_equal(dim(V), c(0L, 0L))
})