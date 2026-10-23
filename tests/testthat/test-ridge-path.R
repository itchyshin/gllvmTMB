.ridge_path_fixture <- function(n = 24, seed = 1) {
  set.seed(seed)
  data.frame(
    unit = factor(seq_len(n)),
    a = rbinom(n, 1, 0.5),
    b = rbinom(n, 1, 0.5)
  )
}

## Reviewer's runaway fixture: n = 40, two well-identified traits (a, b)
## sharing one latent axis, and a rare, near-separated trait (sep) alone on
## a second axis -- the classic "single item defines its own axis" GLLVM
## degeneracy. seed = 19 was picked because a and b stabilise cleanly
## between tau = 8 and tau = Inf while sep keeps moving (11.0 -> 49.1); the
## PRE-FIX classifier (tau = 2 -> 8 only, no Inf, abs()) mislabels a and b
## "penalty-determined" (15.4% and 10.0% raw relative change) even though
## both are flat between 8 and Inf (<1% change).
.ridge_path_runaway_fixture <- function(n = 40, seed = 19) {
  set.seed(seed)
  z <- matrix(rnorm(n * 2), n, 2)
  Lam <- rbind(a = c(0.8, 0), b = c(0.7, 0), sep = c(0, 6))
  alpha <- c(a = 0, b = 0, sep = -8)
  eta <- z %*% t(Lam) + matrix(alpha, n, 3, byrow = TRUE)
  Y <- matrix(
    stats::rbinom(n * 3, 1, stats::plogis(eta)), n, 3,
    dimnames = list(NULL, rownames(Lam))
  )
  data.frame(unit = factor(seq_len(n)), Y)
}

test_that("ridge_path() returns the expected grid contract on a tiny Bernoulli fixture", {
  skip_on_cran()
  df <- .ridge_path_fixture()

  path <- ridge_path(
    traits(a, b) ~ 1 + latent(1 | unit, d = 1),
    data = df,
    family = binomial(),
    unit = "unit",
    tau = c(2, Inf),
    control = gllvmTMBcontrol(n_init = 1, se = FALSE, warn_runaway = FALSE)
  )

  expect_s3_class(path, "gllvmTMB_ridge_path")
  expect_true(is.data.frame(path))
  expect_true(all(
    c(
      "tau", "trait", "max_loading", "communality",
      "logLik_at_map", "convergence", "fit_error"
    ) %in% names(path)
  ))
  expect_equal(sort(unique(path$tau)), sort(c(2, Inf)))
  expect_equal(sort(unique(as.character(path$trait))), c("a", "b"))
  expect_equal(nrow(path), 4L)
})

test_that("ridge_path() rejects a non-positive or missing tau grid", {
  df <- .ridge_path_fixture()
  expect_error(
    ridge_path(
      traits(a, b) ~ 1 + latent(1 | unit, d = 1),
      data = df,
      family = binomial(),
      unit = "unit",
      tau = c(0, 2)
    ),
    class = "rlang_error"
  )
})

test_that(".ridge_path_verdict() classifies a shrinking trait as interior, not penalty-determined", {
  ## Bug (i): the pre-fix classifier used abs(), so a trait whose loading
  ## SHRINKS as tau grows (well-behaved) printed "penalty-determined".
  v <- .ridge_path_verdict(tau = c(2, 4), max_loading = c(1.0, 0.5))
  expect_equal(v$verdict, "interior")
})

test_that(".ridge_path_verdict() flags a constant-elasticity trait even on a narrow, large-tau grid", {
  ## Bug (ii): tau = c(2000, 2100) is only a 1.05x ratio, so the raw
  ## relative change of a genuinely still-growing (elasticity ~= 1) trait
  ## is only 5% -- below any reasonable flat threshold, and decaying like
  ## 1/tau for any fixed absolute grid step. The elasticity normalisation
  ## (log-log slope) must recover the same verdict regardless of grid
  ## spacing: v = tau exactly (elasticity == 1) at both a widely- and a
  ## narrowly-spaced tau pair.
  v_narrow <- .ridge_path_verdict(tau = c(2000, 2100), max_loading = c(2000, 2100))
  v_wide <- .ridge_path_verdict(tau = c(2, 8), max_loading = c(2, 8))
  expect_equal(v_narrow$verdict, "penalty-determined")
  expect_equal(v_wide$verdict, "penalty-determined")
  expect_equal(v_narrow$statistic, v_wide$statistic, tolerance = 1e-8)
})

test_that(".ridge_path_verdict() includes a converged tau = Inf point as the diagnostic evidence", {
  ## Bug (iii): the pre-fix classifier excluded tau = Inf outright via
  ## is.finite(tau), so a converged blow-up at Inf (5.2 -> 1e4) never
  ## entered the comparison and printed "interior", contradicting the
  ## roxygen's own claim that an Inf blow-up is part of the diagnostic.
  v <- .ridge_path_verdict(tau = c(4, Inf), max_loading = c(5.2, 1e4))
  expect_equal(v$verdict, "penalty-determined")
  expect_true(is.infinite(v$tau2))
})

test_that(".ridge_path_verdict() reports insufficient evidence with fewer than two usable points", {
  expect_equal(.ridge_path_verdict(tau = 2, max_loading = 1)$verdict, "insufficient")
  expect_equal(
    .ridge_path_verdict(tau = c(2, 4), max_loading = c(1, NA))$verdict,
    "insufficient"
  )
})

test_that("print.gllvmTMB_ridge_path() pins interior/penalty-determined verdicts on the runaway fixture", {
  skip_on_cran()
  df <- .ridge_path_runaway_fixture()
  path <- suppressWarnings(suppressMessages(ridge_path(
    traits(a, b, sep) ~ 1 + latent(1 | unit, d = 2),
    data = df,
    family = binomial(),
    unit = "unit",
    tau = c(2, 8, Inf),
    control = gllvmTMBcontrol(n_init = 1, se = FALSE, warn_runaway = FALSE)
  )))
  expect_equal(sum(path$convergence == 0L, na.rm = TRUE), 9L)

  out <- capture.output(print(path))
  a_line <- out[grepl("^  a:", out)]
  b_line <- out[grepl("^  b:", out)]
  sep_line <- out[grepl("^  sep:", out)]
  expect_match(a_line, "interior", fixed = TRUE)
  expect_match(b_line, "interior", fixed = TRUE)
  expect_match(sep_line, "penalty-determined", fixed = TRUE)
  expect_false(grepl("penalty-determined", a_line))
  expect_false(grepl("penalty-determined", b_line))
})
