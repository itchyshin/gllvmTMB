# Masked multinomial responses (family_id 16) under miss_control(response =
# "include"). The engine evaluates one categorical observation's grouped
# softmax density ONCE at its anchor pseudo-row, gated by is_y_observed at
# that anchor (src/gllvmTMB.cpp anchor branch). That gate is only correct if
# the R-side mask is GROUP-UNIFORM: an NA categorical value must mask every
# one of its K-1 contrast pseudo-rows together — a partially masked group
# would corrupt the one-hot numerator silently. These tests pin (1) the
# group-uniform invariant, (2) mask accounting, and (3) include == drop
# equivalence for the fitted model. Multinomial is Tier-1 (fixed effects
# only), so the equivalence is exact ML, not latent-conditional.

.make_multinomial_missing <- function(seed = 11L, n = 250L, K = 3L) {
  set.seed(seed)
  x   <- stats::rnorm(n)
  b0  <- c(0.5, -0.4)[seq_len(K - 1L)]
  b1  <- c(1.0, -0.8)[seq_len(K - 1L)]
  eta <- cbind(0, matrix(b0, n, K - 1L, byrow = TRUE) + outer(x, b1))
  P   <- exp(eta - apply(eta, 1L, max))
  P   <- P / rowSums(P)
  y   <- vapply(seq_len(n), function(i) sample.int(K, 1L, prob = P[i, ]), integer(1))
  data.frame(unit = factor(seq_len(n)), trait = factor("morph"),
             value = factor(y), x = x)
}

test_that("multinomial masked response: group-uniform mask, accounting, include == drop", {
  skip_on_cran()
  K <- 3L
  df <- .make_multinomial_missing(seed = 11L, n = 250L, K = K)
  masked <- c(4L, 40L, 111L, 190L, 233L)
  data_na <- df
  data_na$value[masked] <- NA
  data_cc <- df[-masked, , drop = FALSE]
  form <- value ~ 0 + trait + (0 + trait):x

  fit_inc <- suppressMessages(gllvmTMB(
    form, data = data_na, trait = "trait", unit = "unit",
    family = multinomial(), missing = miss_control(response = "include"),
    silent = TRUE
  ))
  fit_cc <- suppressMessages(gllvmTMB(
    form, data = data_cc, trait = "trait", unit = "unit",
    family = multinomial(), missing = miss_control(response = "drop"),
    silent = TRUE
  ))

  expect_true(all(fit_inc$tmb_data$family_id_vec == 16L))

  ## (2) accounting: each masked categorical cell masks all K-1 contrast rows
  iyo <- fit_inc$tmb_data$is_y_observed
  gid <- fit_inc$tmb_data$multinom_group_id
  expect_equal(sum(iyo == 0L), length(masked) * (K - 1L))

  ## (1) group-uniformity: within every contrast group the mask is constant
  by_group <- split(iyo, gid)
  expect_true(all(vapply(by_group, function(v) all(v == v[[1L]]), logical(1))))
  expect_equal(sum(vapply(by_group, function(v) v[[1L]] == 0L, logical(1))),
               length(masked))

  ## (3) include == drop: identical maximised likelihood and coefficients
  expect_true(is.finite(as.numeric(stats::logLik(fit_inc))))
  expect_equal(
    as.numeric(stats::logLik(fit_inc)),
    as.numeric(stats::logLik(fit_cc)),
    tolerance = 1e-6
  )
  expect_equal(fit_inc$opt$par, fit_cc$opt$par, tolerance = 1e-4)
})

test_that("multinomial masked response: predict_missing returns the masked cells", {
  skip_on_cran()
  df <- .make_multinomial_missing(seed = 12L, n = 200L, K = 3L)
  masked <- c(7L, 65L, 140L)
  data_na <- df
  data_na$value[masked] <- NA
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + (0 + trait):x, data = data_na,
    trait = "trait", unit = "unit", family = multinomial(),
    missing = miss_control(response = "include"), silent = TRUE
  ))
  pm <- predict_missing(fit)
  expect_s3_class(pm, "data.frame")
  expect_true(all(is.finite(pm$est)))
})
