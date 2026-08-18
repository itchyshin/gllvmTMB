## #25 (Ayumi B2): `fitted.gllvmTMB_multi()` was absent. NAMESPACE registers
## `fitted` for gllvmTMB_julia and gllvmTMB_va only; with no method for the
## default `gllvmTMB_multi` fit, `fitted(fit)` silently returns NULL (there is
## no `object$fitted` slot for `fitted.default` to reach for, unlike the
## `gllvmTMB_va` case documented in R/va-methods.R). `fitted.gllvmTMB_multi()`
## is a thin wrapper over `predict(object, newdata = NULL, type = ...)`,
## default `type = "response"` (the `fitted()` convention).

.ftm_binomial_fit <- function(seed = 601L, n = 30L, p = 3L) {
  set.seed(seed)
  L <- matrix(stats::rnorm(p), p, 1L)
  u <- stats::rnorm(n)
  eta <- outer(u, as.numeric(L))
  Y <- matrix(stats::rbinom(n * p, 1, stats::plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  dat <- as.data.frame(Y)
  dat$site <- factor(seq_len(n))
  lhs <- paste(colnames(Y), collapse = ", ")
  form <- stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = 1)", lhs
  ))
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    form,
    data = dat,
    family = stats::binomial(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE, warn_runaway = FALSE)
  )))
}

.ftm_binomial_fit_se <- function(seed = 604L, n = 30L, p = 3L) {
  set.seed(seed)
  L <- matrix(stats::rnorm(p), p, 1L)
  u <- stats::rnorm(n)
  eta <- outer(u, as.numeric(L))
  Y <- matrix(stats::rbinom(n * p, 1, stats::plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  dat <- as.data.frame(Y)
  dat$site <- factor(seq_len(n))
  lhs <- paste(colnames(Y), collapse = ", ")
  form <- stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = 1)", lhs
  ))
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    form,
    data = dat,
    family = stats::binomial(),
    control = gllvmTMB::gllvmTMBcontrol(se = TRUE, warn_runaway = FALSE)
  )))
}

.ftm_multinomial_fit <- function(seed = 700L, n = 90L, K = 3L) {
  set.seed(seed)
  x <- stats::rnorm(n)
  b0 <- c(0.5, -0.4)
  b1 <- c(1.0, -0.8)
  eta <- cbind(0, matrix(b0, n, K - 1L, byrow = TRUE) + outer(x, b1))
  P <- exp(eta - apply(eta, 1L, max))
  P <- P / rowSums(P)
  y <- vapply(seq_len(n), function(i) {
    sample.int(K, 1L, prob = P[i, ])
  }, integer(1))
  df <- data.frame(
    unit = factor(seq_len(n)), trait = factor("morph"),
    value = factor(y), x = x
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (0 + trait):x,
    data = df,
    family = gllvmTMB::multinomial(),
    trait = "trait",
    unit = "unit"
  )))
}

test_that("#25 B2: fitted() on a gllvmTMB_multi fit matches predict(newdata = NULL)", {
  skip_on_cran()
  fit <- .ftm_binomial_fit()
  pr <- predict(fit, newdata = NULL, type = "response")

  ft <- fitted(fit)
  expect_false(is.null(ft))
  expect_s3_class(ft, "data.frame")
  expect_equal(nrow(ft), nrow(pr))
  expect_identical(ft$est, pr$est)
})

test_that("#25 B2: fitted(type = ) dispatches link vs response like predict()", {
  skip_on_cran()
  fit <- .ftm_binomial_fit(seed = 602L)

  ft_link <- fitted(fit, type = "link")
  ft_resp <- fitted(fit, type = "response")
  expect_identical(ft_link$est, predict(fit, newdata = NULL, type = "link")$est)
  expect_identical(
    ft_resp$est,
    predict(fit, newdata = NULL, type = "response")$est
  )
  ## Binomial link/response scales genuinely differ.
  expect_false(isTRUE(all.equal(ft_link$est, ft_resp$est)))
})

test_that("#25 B2: default type is \"response\", the fitted() convention", {
  skip_on_cran()
  fit <- .ftm_binomial_fit(seed = 603L)
  expect_identical(fitted(fit)$est, fitted(fit, type = "response")$est)
})

test_that("#25 B2 REPAIR: fitted(fit, se.fit = TRUE) forwards ... to predict()", {
  ## REPAIR (adversarial review): `fitted.gllvmTMB_multi()` used to silently
  ## swallow `...`, so `se.fit` / `re_form` never reached predict(). Verified
  ## first (not assumed): `predict(fit, se.fit = TRUE)` adds an `se.fit`
  ## column (plus `se.fit.scale` / `se.fit.conditional` attributes) to the
  ## same long data frame -- this test checks fitted() reproduces exactly
  ## that, not a guessed column name.
  skip_on_cran()
  fit <- .ftm_binomial_fit_se()
  pr <- predict(fit, newdata = NULL, type = "response", se.fit = TRUE)
  ft <- fitted(fit, type = "response", se.fit = TRUE)
  expect_true("se.fit" %in% names(ft))
  expect_identical(ft, pr)
})

test_that("#25 B2: fitted() on a multinomial fit routes through .predict_multinomial", {
  skip_on_cran()
  fit <- .ftm_multinomial_fit()
  ft <- fitted(fit)
  expect_false(is.null(ft))
  expect_identical(ft, predict(fit, newdata = NULL, type = "response"))
})

test_that("#25 B2: fitted() exists for every engine class (method-parity contract)", {
  ## Cross-class contract: gllvmTMB_julia and gllvmTMB_va both got a
  ## fitted() method; gllvmTMB_multi, the default engine, never did. This
  ## test is the guard against that recurrence -- every engine class must
  ## carry a fitted() method.
  for (cls in c("gllvmTMB_multi", "gllvmTMB_va", "gllvmTMB_julia")) {
    expect_true(
      exists(paste0("fitted.", cls)),
      info = paste("missing fitted() method for class", cls)
    )
  }
})
