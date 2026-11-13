## Issue #1752: the documented one-grouping call
## `kernel_indep(unit, K = K, name = "known")` (and the matching
## `kernel_latent()` form) must fit when `cluster` is omitted. The kernel
## grouping is the column named inside the keyword. An explicit
## `cluster = "unit"` fit is the same model. A `K` that still does not
## match that grouping names `K`, not `phylo_vcv`. Phylogenetic checks
## keep the `phylo_vcv` wording.

kernel_1752_layout <- function() {
  set.seed(11)
  n <- 12L
  p <- 3L
  u <- stats::rnorm(n)
  Y <- outer(u, c(0.7, 0.2, -0.4)) +
    matrix(stats::rnorm(n * p, sd = 0.4), n, p)
  unit_levels <- paste0("u", seq_len(n))
  df <- data.frame(
    unit = factor(rep(unit_levels, p), levels = unit_levels),
    trait = factor(rep(paste0("t", seq_len(p)), each = n)),
    value = as.vector(Y)
  )
  K <- diag(n)
  rownames(K) <- colnames(K) <- unit_levels
  list(df = df, K = K, n = n)
}

kernel_1752_control <- function() {
  gllvmTMBcontrol(n_init = 1L, se = FALSE)
}

test_that("kernel_indep(unit, K = K) fits without cluster and matches cluster = unit (#1752)", {
  fx <- kernel_1752_layout()
  K <- fx$K
  ctrl <- kernel_1752_control()
  fit_omit <- gllvmTMB(
    value ~ 0 + trait + kernel_indep(unit, K = K, name = "known"),
    data = fx$df, unit = "unit",
    control = ctrl, silent = TRUE
  )
  fit_cluster <- gllvmTMB(
    value ~ 0 + trait + kernel_indep(unit, K = K, name = "known"),
    data = fx$df, unit = "unit", cluster = "unit",
    control = ctrl, silent = TRUE
  )
  expect_s3_class(fit_omit, "gllvmTMB")
  expect_equal(fit_omit$opt$convergence, 0L)
  expect_equal(fit_cluster$opt$convergence, 0L)
  expect_equal(
    as.numeric(stats::logLik(fit_omit)),
    as.numeric(stats::logLik(fit_cluster)),
    tolerance = 1e-8
  )
})

test_that("kernel_latent(unit, K = K) fits without cluster and matches cluster = unit (#1752)", {
  fx <- kernel_1752_layout()
  K <- fx$K
  ctrl <- kernel_1752_control()
  fit_omit <- gllvmTMB(
    value ~ 0 + trait + kernel_latent(unit, K = K, d = 1, name = "known"),
    data = fx$df, unit = "unit",
    control = ctrl, silent = TRUE
  )
  fit_cluster <- gllvmTMB(
    value ~ 0 + trait + kernel_latent(unit, K = K, d = 1, name = "known"),
    data = fx$df, unit = "unit", cluster = "unit",
    control = ctrl, silent = TRUE
  )
  expect_s3_class(fit_omit, "gllvmTMB")
  expect_equal(fit_omit$opt$convergence, 0L)
  expect_equal(fit_cluster$opt$convergence, 0L)
  expect_equal(
    as.numeric(stats::logLik(fit_omit)),
    as.numeric(stats::logLik(fit_cluster)),
    tolerance = 1e-8
  )
})

test_that("a kernel K that misses a grouping level names K, not phylo_vcv (#1752)", {
  fx <- kernel_1752_layout()
  K_bad <- fx$K[-1L, -1L, drop = FALSE]
  err <- tryCatch(
    gllvmTMB(
      value ~ 0 + trait + kernel_indep(unit, K = K_bad, name = "known"),
      data = fx$df, unit = "unit",
      control = kernel_1752_control(), silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(msg, "K")
  expect_match(msg, "unit")
  expect_match(msg, "u1")
  expect_no_match(msg, "phylo_vcv")
  expect_no_match(msg, "placeholder")
  expect_no_match(msg, "tree")
})

test_that("a kernel K without rownames names K, not phylo_vcv (#1752)", {
  fx <- kernel_1752_layout()
  K_noname <- fx$K
  rownames(K_noname) <- NULL
  err <- tryCatch(
    gllvmTMB(
      value ~ 0 + trait + kernel_latent(unit, K = K_noname, d = 1, name = "known"),
      data = fx$df, unit = "unit",
      control = kernel_1752_control(), silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(msg, "K")
  expect_match(msg, "unit")
  expect_no_match(msg, "phylo_vcv")
  expect_no_match(msg, "placeholder")
})

test_that("a phylogenetic vcv mismatch still names phylo_vcv (#1752)", {
  sp <- paste0("sp", seq_len(4L))
  K <- diag(4L)
  rownames(K) <- colnames(K) <- sp
  K_bad <- K[1:3, 1:3, drop = FALSE]
  df <- data.frame(
    unit = factor(rep(sp, 2L), levels = sp),
    species = factor(rep(sp, 2L), levels = sp),
    trait = factor(rep(c("t1", "t2"), each = 4L)),
    value = stats::rnorm(8L)
  )
  err <- tryCatch(
    gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1, vcv = K_bad),
      data = df, unit = "unit", cluster = "species",
      control = kernel_1752_control(), silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(msg, "phylo_vcv")
  expect_match(msg, "sp4")
  expect_match(msg, "tree")
})
