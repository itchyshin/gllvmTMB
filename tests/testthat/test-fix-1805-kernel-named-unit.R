## Issue #1805: kernel_*(K = K, unit = g) must group by g when cluster is
## omitted. The helper used to read the first argument by position, so this
## call picked up K.

.fix1805_layout <- function() {
  set.seed(1805)
  n <- 8L
  p <- 3L
  u <- stats::rnorm(n)
  Y <- outer(u, c(0.6, -0.2, 0.3)) +
    matrix(stats::rnorm(n * p, sd = 0.3), n, p)
  g_levels <- paste0("g", seq_len(n))
  df <- data.frame(
    unit = factor(rep(g_levels, p), levels = g_levels),
    g = factor(rep(g_levels, p), levels = g_levels),
    trait = factor(rep(paste0("t", seq_len(p)), each = n)),
    value = as.vector(Y)
  )
  K <- diag(n)
  rownames(K) <- colnames(K) <- g_levels
  list(df = df, K = K)
}

.fix1805_control <- function() {
  gllvmTMBcontrol(n_init = 1L, se = FALSE, laplace_auto_refit = FALSE)
}

test_that("kernel_indep(K = K, unit = g) groups by g when cluster is omitted (#1805)", {
  fx <- .fix1805_layout()
  K <- fx$K
  ctrl <- .fix1805_control()
  fit_omit <- gllvmTMB(
    value ~ 0 + trait + kernel_indep(K = K, unit = g, name = "known"),
    data = fx$df, unit = "unit",
    control = ctrl, silent = TRUE
  )
  fit_cluster <- gllvmTMB(
    value ~ 0 + trait + kernel_indep(K = K, unit = g, name = "known"),
    data = fx$df, unit = "unit", cluster = "g",
    control = ctrl, silent = TRUE
  )
  expect_s3_class(fit_omit, "gllvmTMB")
  expect_equal(fit_omit$opt$convergence, 0L)
  expect_equal(
    as.numeric(stats::logLik(fit_omit)),
    as.numeric(stats::logLik(fit_cluster)),
    tolerance = 1e-8
  )
})

test_that("a missing named kernel unit is reported as that column, not K (#1805)", {
  fx <- .fix1805_layout()
  K <- fx$K
  df <- fx$df
  df$g <- NULL
  err <- tryCatch(
    gllvmTMB(
      value ~ 0 + trait + kernel_indep(K = K, unit = g, name = "known"),
      data = df, unit = "unit",
      control = .fix1805_control(), silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_kernel_grouping")
  msg <- conditionMessage(err)
  expect_match(msg, "groups by .g., which is not a column in|rownames\\(K\\).*, or pass that column as .cluster.")
  expect_no_match(msg, "groups by .K.")
  expect_no_match(msg, "placeholder")
  expect_no_match(msg, "phylo_vcv")
})
