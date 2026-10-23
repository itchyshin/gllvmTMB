## Edge-case pins for chibar2_pvalue(), variance_lrt() and diagnostic_table().
## Test-only audit: every expectation records what the code does today.
## The select_lv()/compare_temporal() refusal classes and the uncertainty
## classes are pinned elsewhere and are not repeated here.

# ---- chibar2_pvalue() -------------------------------------------------------

test_that("chibar2_pvalue() is 1 at a zero or negative statistic", {
  expect_identical(chibar2_pvalue(0, 1), 1)
  expect_identical(chibar2_pvalue(0, 4L), 1)
  expect_identical(chibar2_pvalue(-3, 2), 1)
  expect_identical(chibar2_pvalue(-Inf, 1), 1)
})

test_that("chibar2_pvalue() just above 0 returns the mixture mass, not 1", {
  # The j = 0 atom is dropped for LRT > 0, so the p-value jumps from 1 at
  # LRT = 0 to 1 - 2^-q just above it.
  expect_equal(chibar2_pvalue(1e-12, 1), 0.5, tolerance = 1e-5)
  expect_equal(chibar2_pvalue(1e-12, 3), 1 - 2^-3, tolerance = 1e-5)
})

test_that("chibar2_pvalue() matches the closed forms", {
  # q = 1: half the naive chi-square_1 tail.
  for (s in c(0.5, 1, 3.84, 10)) {
    expect_equal(
      chibar2_pvalue(s, 1),
      0.5 * stats::pchisq(s, 1, lower.tail = FALSE),
      tolerance = 1e-12
    )
  }
  # q = 2: weights 1/2 on chi-square_1 and 1/4 on chi-square_2.
  expect_equal(
    chibar2_pvalue(3, 2),
    0.5 * stats::pchisq(3, 1, lower.tail = FALSE) +
      0.25 * stats::pchisq(3, 2, lower.tail = FALSE),
    tolerance = 1e-12
  )
  # integer-valued double and integer q agree
  expect_identical(chibar2_pvalue(3, 2), chibar2_pvalue(3, 2L))
})

test_that("chibar2_pvalue() is finite and near 0 for very large statistics", {
  p_big <- chibar2_pvalue(800, 5)
  expect_true(is.finite(p_big))
  expect_gt(p_big, 0)
  expect_lt(p_big, 1e-100)
  expect_identical(chibar2_pvalue(1e6, 3), 0)
  expect_identical(chibar2_pvalue(Inf, 1), 0)
})

test_that("chibar2_pvalue() is monotone decreasing in the statistic", {
  p <- vapply(c(0.1, 1, 5, 20), chibar2_pvalue, numeric(1), q = 3)
  expect_true(all(diff(p) < 0))
  expect_true(all(p >= 0 & p <= 1))
})

test_that("chibar2_pvalue() is scalar-only: a vector LRT is refused", {
  expect_error(
    chibar2_pvalue(c(1, 2), 1),
    class = "gllvmTMB_chibar2_bad_LRT"
  )
  expect_error(
    chibar2_pvalue(c(1, 2), 1),
    "single, non-missing numeric",
    class = "gllvmTMB_chibar2_bad_LRT"
  )
  # the scalar results are the elementwise values
  expect_equal(
    vapply(c(1, 2), chibar2_pvalue, numeric(1), q = 1),
    0.5 * stats::pchisq(c(1, 2), 1, lower.tail = FALSE),
    tolerance = 1e-12
  )
})

test_that("chibar2_pvalue() refuses a bad LRT with a classed error and advice", {
  for (bad in list(NA_real_, "a", NULL, numeric(0), TRUE)) {
    expect_error(
      chibar2_pvalue(bad, 1),
      class = "gllvmTMB_chibar2_bad_LRT"
    )
  }
  expect_error(
    chibar2_pvalue(NA_real_, 1),
    "Pass one likelihood-ratio statistic",
    class = "gllvmTMB_chibar2_bad_LRT"
  )
})

test_that("chibar2_pvalue() refuses a bad q (df / component count)", {
  # df = 0 and negative df
  expect_error(chibar2_pvalue(1, 0), class = "gllvmTMB_chibar2_bad_q")
  expect_error(chibar2_pvalue(1, -1), class = "gllvmTMB_chibar2_bad_q")
  # non-integer, vector, missing, non-numeric, NULL
  for (bad in list(1.5, c(1, 2), NA, NA_real_, "a", NULL, numeric(0))) {
    expect_error(chibar2_pvalue(1, bad), class = "gllvmTMB_chibar2_bad_q")
  }
  expect_error(
    chibar2_pvalue(1, 0),
    "single integer >= 1",
    class = "gllvmTMB_chibar2_bad_q"
  )
  expect_error(
    chibar2_pvalue(1, 0),
    "q = 1",
    class = "gllvmTMB_chibar2_bad_q"
  )
})

test_that("chibar2_pvalue() checks q before LRT", {
  expect_error(chibar2_pvalue("a", 0), class = "gllvmTMB_chibar2_bad_q")
  # and even a non-positive LRT does not skip the q check
  expect_error(chibar2_pvalue(0, 0), class = "gllvmTMB_chibar2_bad_q")
})

# ---- variance_lrt() ---------------------------------------------------------

test_that("variance_lrt() gives the boundary-corrected p-value for hand-built logLiks", {
  out <- variance_lrt(ll_full = -100.2, ll_reduced = -102.1, n_boundary = 1)
  expect_named(out, c("LRT", "pvalue", "n_boundary"))
  expect_equal(out$LRT, 3.8, tolerance = 1e-12)
  expect_equal(
    out$pvalue,
    0.5 * stats::pchisq(3.8, 1, lower.tail = FALSE),
    tolerance = 1e-12
  )
  expect_identical(out$n_boundary, 1L)

  out2 <- variance_lrt(-98, -102, n_boundary = 2)
  expect_equal(out2$LRT, 8, tolerance = 1e-12)
  expect_equal(
    out2$pvalue,
    0.5 * stats::pchisq(8, 1, lower.tail = FALSE) +
      0.25 * stats::pchisq(8, 2, lower.tail = FALSE),
    tolerance = 1e-12
  )
  expect_identical(out2$n_boundary, 2L)

  # default n_boundary is 1 and the p-value is the chibar2_pvalue() one
  def <- variance_lrt(-100, -103)
  expect_identical(def$n_boundary, 1L)
  expect_identical(def$pvalue, chibar2_pvalue(def$LRT, 1L))
})

test_that("variance_lrt() does NOT clamp a negative LRT; only the p-value is 1", {
  # Today the statistic is reported as computed (2 * (ll_full - ll_reduced));
  # the 'values <= 0 give p = 1' rule lives in chibar2_pvalue().
  neg <- variance_lrt(ll_full = -102, ll_reduced = -100, n_boundary = 2)
  expect_equal(neg$LRT, -4)
  expect_identical(neg$pvalue, 1)
  zero <- variance_lrt(-100, -100)
  expect_identical(zero$LRT, 0)
  expect_identical(zero$pvalue, 1)
})

test_that("variance_lrt() does no nestedness check: swapping the models only flips the sign", {
  fwd <- variance_lrt(-100, -103)
  rev <- variance_lrt(-103, -100)
  expect_equal(rev$LRT, -fwd$LRT)
  expect_identical(rev$pvalue, 1)
  expect_lt(fwd$pvalue, 1)
})

test_that("variance_lrt() refuses non-scalar or non-numeric log-likelihoods", {
  for (bad in list(NA, NA_real_, c(1, 2), "a", NULL, numeric(0))) {
    expect_error(
      variance_lrt(bad, -1),
      class = "gllvmTMB_variance_lrt_bad_loglik"
    )
    expect_error(
      variance_lrt(-1, bad),
      class = "gllvmTMB_variance_lrt_bad_loglik"
    )
  }
  expect_error(
    variance_lrt(NA_real_, -1),
    "single, non-missing numeric",
    class = "gllvmTMB_variance_lrt_bad_loglik"
  )
  expect_error(
    variance_lrt(NA_real_, -1),
    "as.numeric(logLik(fit_full))",
    fixed = TRUE,
    class = "gllvmTMB_variance_lrt_bad_loglik"
  )
})

test_that("variance_lrt() forwards a bad n_boundary to the chibar2 q class", {
  expect_error(
    variance_lrt(-100, -103, n_boundary = 0),
    class = "gllvmTMB_chibar2_bad_q"
  )
  expect_error(
    variance_lrt(-100, -103, n_boundary = 1.5),
    class = "gllvmTMB_chibar2_bad_q"
  )
  # a non-positive LRT with a bad q still refuses: q is validated first
  expect_error(
    variance_lrt(-103, -100, n_boundary = 0),
    class = "gllvmTMB_chibar2_bad_q"
  )
  # a whole-number double is accepted and stored as integer
  expect_identical(variance_lrt(-100, -103, n_boundary = 2)$n_boundary, 2L)
})

test_that("variance_lrt() accepts a logLik object although its message calls it not bare numeric", {
  # Observation: the advice text says a <logLik> is "not a bare numeric", but
  # is.numeric() is TRUE for it, so it is NOT refused; the p-value is correct.
  # The LRT element keeps the logLik class. Pinned as today's behaviour.
  ll_full <- structure(-100, df = 5, class = "logLik")
  ll_red <- structure(-103, df = 4, class = "logLik")
  out <- variance_lrt(ll_full, ll_red)
  expect_equal(as.numeric(out$LRT), 6)
  expect_equal(
    out$pvalue,
    0.5 * stats::pchisq(6, 1, lower.tail = FALSE),
    tolerance = 1e-12
  )
})

# ---- diagnostic_table() -----------------------------------------------------

make_edges_diag_fit <- function(seed = 8L) {
  set.seed(seed)
  n_ind <- 36L
  trait_names <- c("a", "b")
  u <- stats::rnorm(n_ind, sd = 0.35)
  eta <- cbind(0.2 + u, -0.15 + 0.7 * u)
  y <- matrix(stats::rpois(n_ind * 2L, lambda = exp(as.vector(eta))), n_ind, 2L)
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = 2L)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df,
    unit = "individual",
    family = stats::poisson()
  )))
}

test_that("diagnostic_table() refuses input without diagnostic metadata", {
  for (bad in list(1, "a", NULL, list(), data.frame(a = 1), 1:3)) {
    expect_error(
      diagnostic_table(bad),
      "does not carry",
      class = "rlang_error"
    )
  }
  expect_error(
    diagnostic_table(data.frame(a = 1)),
    "predictive_check",
    class = "rlang_error"
  )
  expect_error(
    diagnostic_table(data.frame(a = 1)),
    "residuals",
    class = "rlang_error"
  )
  # metadata that is present but not a list is treated the same way
  expect_error(
    diagnostic_table(structure(1, gllvmTMB_diagnostic = "nope")),
    "does not carry",
    class = "rlang_error"
  )
})

test_that("diagnostic_table() names the valid choices for an unknown table", {
  # match.arg() runs before the metadata check, so even a bad x reports the
  # bad `table` first. The error is a base simpleError (no package class).
  err <- expect_error(
    diagnostic_table(data.frame(a = 1), table = "bogus"),
    "should be one of",
    class = "simpleError"
  )
  for (nm in c("data", "row_status", "fit_health_status", "check_gllvmTMB")) {
    expect_match(conditionMessage(err), nm, fixed = TRUE)
  }
  expect_error(
    diagnostic_table(data.frame(a = 1), table = c("data", "row_status")),
    "must be of length 1",
    class = "simpleError"
  )
  # partial matching of a unique prefix is allowed by match.arg()
  expect_error(
    diagnostic_table(data.frame(a = 1), table = "row"),
    "does not carry",
    class = "rlang_error"
  )
})

test_that("every documented diagnostic_table() value returns a plain data.frame with stable columns", {
  skip_on_cran()
  testthat::skip_if_not_installed("ggplot2")

  fit <- make_edges_diag_fit()
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 108L)
  p <- predictive_check(fit, type = "rq_qq", seed = 109L, condition_on_RE = TRUE)

  expected_cols <- list(
    data = c(
      ".row", "trait", "trait_id", "family_id", "family", "link_id",
      "observed", "cdf_lower", "cdf_upper", "u", "residual", "status",
      "scale", "method", "seed"
    ),
    row_status = c("status", "n"),
    fit_health_status = c("status", "n"),
    check_gllvmTMB = c(
      "component", "status", "value", "threshold", "message", "action"
    )
  )

  for (obj in list(res, p)) {
    for (tb in names(expected_cols)) {
      out <- diagnostic_table(obj, table = tb)
      expect_identical(class(out), "data.frame", info = tb)
      expect_identical(names(out), expected_cols[[tb]], info = tb)
      expect_gt(nrow(out), 0L)
      expect_identical(rownames(out), as.character(seq_len(nrow(out))), info = tb)
      expect_null(attr(out, "gllvmTMB_diagnostic"))
      expect_null(attr(out, "method"))
    }
  }

  # the default table is "data"
  expect_identical(diagnostic_table(res), diagnostic_table(res, table = "data"))
  # partial matching resolves to the documented value
  expect_identical(
    diagnostic_table(res, table = "row_s"),
    diagnostic_table(res, table = "row_status")
  )
  # simulation-rank residuals carry two extra columns in the data table
  sr <- stats::residuals(fit, type = "simulation_rank", seed = 110L)
  sr_cols <- names(diagnostic_table(sr, table = "data"))
  expect_true(all(c("nsim", "condition_on_RE") %in% sr_cols))
})
