# Issue #1368: the mi() discrete-predictor report was read with
# `obj$report(opt$par)`, which errors ("Wrong parameter length.") whenever the
# model has a random effect; a tryCatch turned that into NULL and the missing
# units' conditional probabilities silently became NA.

.make_mi_re_1368 <- function(seed = 303, n = 50, miss = c(5L, 14L, 27L, 38L)) {
  set.seed(seed)
  z <- stats::rnorm(n); w <- stats::rnorm(n)
  x <- stats::rbinom(n, 1, stats::plogis(-0.2 + 1.1 * z - 0.7 * w))
  u <- stats::rnorm(n)
  rows <- lapply(seq_len(n), function(s) data.frame(
    site = s, trait = c("t1", "t2"),
    value = c(0.6 + 1.2 * x[s] - 0.3 * z[s], -0.2 + 1.2 * x[s] + 0.5 * z[s]) +
      0.8 * u[s] * c(1, 0.7) + stats::rnorm(2, sd = 0.35),
    x = x[s], z = z[s], w = w[s]))
  dat <- do.call(rbind, rows)
  dat$site <- factor(dat$site, levels = seq_len(n))
  dat$trait <- factor(dat$trait)
  dat$x[as.integer(dat$site) %in% miss] <- NA_real_
  list(data = dat, miss = miss)
}

.fit_mi_re_1368 <- function(data, rhs) {
  suppressMessages(suppressWarnings(gllvmTMB(
    stats::as.formula(paste("value ~ 0 + trait + (0 + trait):z + mi(x)", rhs)),
    data = data, family = gaussian(), unit = "site", trait = "trait",
    impute = list(x = impute_model(x ~ z + w, family = binomial())),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE))))
}

test_that("binary mi() conditional probabilities are finite when the model has latent() (#1368)", {
  skip_on_cran()
  d <- .make_mi_re_1368()
  b <- .fit_mi_re_1368(d$data, "+ latent(0 + trait | site, d = 1)")
  p <- b$missing_data$predictors$x$conditional_probability
  expect_length(p, length(d$miss))
  expect_true(all(is.finite(p)))
  expect_true(all(p >= 0 & p <= 1))
})

test_that("the no-random-effect fit is unchanged by the report fix (#1368)", {
  skip_on_cran()
  d <- .make_mi_re_1368()
  a <- .fit_mi_re_1368(d$data, "")
  p <- a$missing_data$predictors$x$conditional_probability
  expect_equal(p[1], 0.49983375, tolerance = 1e-4)
  expect_true(all(is.finite(p)))
})
