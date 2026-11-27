test_that("predict(type = response) returns expected category for ordinal_logit (#1949)", {
  skip_on_cran()
  set.seed(5)
  o <- expand.grid(
    site = factor(1:18),
    trait = factor(c("a", "b")),
    KEEP.OUT.ATTRS = FALSE
  )
  o$value <- sample(1:4, nrow(o), replace = TRUE)

  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = o,
    unit = "site",
    family = ordinal_logit(),
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  ))
  expect_equal(fit$opt$convergence, 0L)

  eta <- predict(fit, type = "link")$est[1]
  resp <- predict(fit, type = "response")$est[1]
  cuts <- extract_cutpoints(fit)
  bnds <- c(-Inf, 0, cuts$tau_estimate[1:2], Inf)
  probs <- diff(plogis(bnds - eta))
  ecat <- sum(seq_along(probs) * probs)

  expect_false(identical(resp, plogis(eta)))
  expect_gt(resp, 1)
  expect_lt(resp, 4)
  expect_equal(resp, ecat, tolerance = 1e-6)
  expect_equal(fitted(fit, type = "response")$est[1], resp)
})