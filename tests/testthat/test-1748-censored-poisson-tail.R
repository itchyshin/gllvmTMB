## #1748. Right-censored censored_poisson rows used log(pgamma(mu, C, 1)).
## Once C * eta is very negative that underflows and fn() / gr() are NaN.

test_that("#1748 a right-censored row stays finite for a very negative predictor", {
  skip_on_cran()
  etas <- c(-5, -50, -150, -250, -300, -400, -800)
  for (C in 1:3) {
    n_site <- 8L
    n_trait <- 2L
    dat <- data.frame(
      site = factor(rep(seq_len(n_site), n_trait)),
      trait = factor(rep(seq_len(n_trait), each = n_site)),
      y = C,
      censored = 1L
    )
    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      cbind(y, censored) ~ 0 + trait,
      data = dat, family = censored_poisson(), unit = "site",
      control = gllvmTMBcontrol(se = FALSE, n_init = 1L, laplace_auto_refit = FALSE),
      silent = TRUE
    )))
    expect_equal(fit$tmb_data$family_id_vec[1], 21L)
    obj <- fit$tmb_obj
    for (eta in etas) {
      p <- obj$par
      p[names(p) == "b_fix"] <- eta
      fn <- as.numeric(obj$fn(p))
      gr <- as.numeric(obj$gr(p))
      expect_true(is.finite(fn))
      expect_true(all(is.finite(gr)))
      ref <- log(stats::pgamma(exp(eta), shape = C, rate = 1))
      if (is.finite(ref)) {
        expect_equal(fn, -length(fit$tmb_data$y) * ref, tolerance = 1e-8)
      }
    }
    p <- obj$par
    p[names(p) == "b_fix"] <- -800
    fn <- as.numeric(obj$fn(p))
    n <- length(fit$tmb_data$y)
    expect_equal(
      fn,
      -n * (C * -800 - exp(-800) - lgamma(C + 1)),
      tolerance = 1e-6
    )
  }
})

test_that("#1748 large C right-censored tail matches ppois survival (eta > 0)", {
  skip_on_cran()
  C <- 1000L
  n_site <- 4L
  n_trait <- 2L
  dat <- data.frame(
    site = factor(rep(seq_len(n_site), n_trait)),
    trait = factor(rep(seq_len(n_trait), each = n_site)),
    y = C,
    censored = 1L
  )
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    cbind(y, censored) ~ 0 + trait,
    data = dat, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L, laplace_auto_refit = FALSE),
    silent = TRUE
  )))
  obj <- fit$tmb_obj
  n <- length(fit$tmb_data$y)
  for (mu in c(880, 1000)) {
    eta <- log(mu)
    p <- obj$par
    p[names(p) == "b_fix"] <- eta
    fn <- as.numeric(obj$fn(p))
    gr <- as.numeric(obj$gr(p))
    expect_true(is.finite(fn))
    expect_true(all(is.finite(gr)))
    ref <- stats::ppois(C - 1L, mu, lower.tail = FALSE, log.p = TRUE)
    expect_equal(fn, -n * ref, tolerance = 1e-10)
  }
  for (eta in c(0.5, 2, 5)) {
    mu <- exp(eta)
    p <- obj$par
    p[names(p) == "b_fix"] <- eta
    fn <- as.numeric(obj$fn(p))
    ref <- stats::ppois(C - 1L, mu, lower.tail = FALSE, log.p = TRUE)
    expect_equal(fn, -n * ref, tolerance = 1e-10)
  }
})
