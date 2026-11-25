## #1788: predict(newdata) without the cluster2 column returned the fixed-effects
## prediction while diag_cluster2 was active. This test fails on main because
## that call succeeds.

.fit_1788 <- function() {
  set.seed(1788L)
  n_years <- 5L
  df <- expand.grid(
    site = factor(seq_len(20L)),
    trait = factor(letters[1:3])
  )
  df$year <- factor(((as.integer(df$site) - 1L) %% n_years) + 1L)
  yr_eff <- outer(c(0.2, 0.8, 1.5), rnorm(n_years))
  df$value <- yr_eff[cbind(as.integer(df$trait), as.integer(df$year))] +
    rnorm(nrow(df), sd = 0.4)
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | year),
    data = df,
    cluster2 = "year",
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L, laplace_auto_refit = FALSE),
    silent = TRUE
  )))
}

test_that("#1788 predict() stops when newdata omits the cluster2 column", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  fit <- .fit_1788()
  expect_true(isTRUE(fit$use$diag_cluster2))
  nd_miss <- fit$data[, setdiff(names(fit$data), fit$cluster2_col), drop = FALSE]

  expect_error(
    predict(fit, newdata = nd_miss),
    regexp = "cluster2 column[[:print:][:space:]]*re_form",
    class = "gllvmTMB_predict_newdata_cluster2_missing"
  )

  p0 <- predict(fit, newdata = nd_miss, re_form = ~0)
  p_fx <- predict(fit, newdata = fit$data, re_form = ~0)
  expect_equal(p0$est, p_fx$est, tolerance = 1e-8)

  p_nd <- suppressMessages(predict(fit, newdata = fit$data))
  expect_true(max(abs(p_nd$est - p_fx$est)) > 1e-6)
})