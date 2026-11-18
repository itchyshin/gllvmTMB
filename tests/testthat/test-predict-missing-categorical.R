# predict_missing() categorical surface warts (#986):
#   Fix 1 -- ordinal_probit masked rows under type = "response" must return
#   the EXPECTED CATEGORY E[k] = sum_k k * P(category k | eta, cutpoints),
#   not an elementwise pnorm(eta) (not a category quantity once K > 2).
#   type = "link" is unchanged.
# Fix 2 (multinomial original_row) is exercised in
# test-multinomial-missing-response.R.

.make_ordinal_missing <- function(seed = 21L, n = 300L, taus = c(0, 0.6, 1.3)) {
  set.seed(seed)
  x <- stats::rnorm(n)
  ystar <- 0.3 + 1.1 * x + stats::rnorm(n)
  y <- rep(1L, n)
  for (k in seq_along(taus)) y <- y + as.integer(ystar > taus[k])
  data.frame(
    unit = factor(seq_len(n)), trait = factor("morph"),
    value = y, x = x
  )
}

test_that("ordinal masked response: type = 'response' is the expected category in [1, K] and correlates with truth; type = 'link' unchanged", {
  skip_on_cran()
  K <- 4L # length(taus) + 1
  df <- .make_ordinal_missing(seed = 21L, n = 300L)
  masked <- c(5L, 47L, 118L, 201L, 260L)
  data_na <- df
  data_na$value[masked] <- NA

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 1 + x, data = data_na,
    trait = "trait", unit = "unit", family = ordinal_probit(),
    missing = miss_control(response = "include"), silent = TRUE
  )))
  expect_identical(fit$opt$convergence, 0L)
  expect_true(all(fit$tmb_data$family_id_vec == 14L))

  pm_link <- predict_missing(fit, type = "link")
  pm_resp <- predict_missing(fit, type = "response")

  expect_equal(nrow(pm_link), length(masked))
  expect_equal(nrow(pm_resp), length(masked))
  expect_equal(pm_resp$original_row, sort(masked))

  ## type = "link" is unchanged by fix 1: est is the raw probit-scale eta.
  expect_equal(pm_link$est, as.numeric(fit$report$eta)[pm_link$model_row])

  ## type = "response" is now the expected category: in [1, K], not a
  ## pnorm(eta) probability in [0, 1].
  expect_true(all(pm_resp$est >= 1 - 1e-6 & pm_resp$est <= K + 1e-6))
  expect_false(isTRUE(all.equal(
    pm_resp$est,
    stats::pnorm(as.numeric(fit$report$eta)[pm_resp$model_row])
  )))

  truth <- df$value[sort(masked)]
  rho <- suppressWarnings(stats::cor(pm_resp$est, truth, method = "spearman"))
  expect_true(is.finite(rho))
  expect_gt(rho, 0)
})

test_that("ordinal masked response: expected category matches a hand-computed cutpoint reconstruction", {
  skip_on_cran()
  df <- .make_ordinal_missing(seed = 22L, n = 250L)
  masked <- c(3L, 60L, 130L, 210L)
  data_na <- df
  data_na$value[masked] <- NA

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 1 + x, data = data_na,
    trait = "trait", unit = "unit", family = ordinal_probit(),
    missing = miss_control(response = "include"), silent = TRUE
  )))
  skip_if_not(identical(fit$opt$convergence, 0L), "fit did not converge")

  pm_resp <- predict_missing(fit, type = "response")
  cuts <- extract_cutpoints(fit, quiet = TRUE)
  tau_full <- c(0, cuts$tau_estimate[order(cuts$cutpoint_index)])
  bnds <- c(-Inf, tau_full, Inf)
  eta <- as.numeric(fit$report$eta)[pm_resp$model_row]
  expected <- vapply(eta, function(e) {
    probs <- diff(stats::pnorm(bnds - e))
    sum(seq_along(probs) * probs)
  }, numeric(1))
  expect_equal(pm_resp$est, expected, tolerance = 1e-8)
})
