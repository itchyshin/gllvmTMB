## REML must work with the FIML response mask, not only with `drop`.
##
## Before this change, `REML = TRUE` aborted on any masked response:
##   "REML = TRUE currently requires miss_control(response = 'drop')"
## That left a hole in the FIML story: the one estimator where the missing-data
## policy interacts with the likelihood correction was the one policy you could
## not use it with.
##
## Why it is safe to lift. REML here is TMB's standard idiom -- `b_fix` joins the
## random vector and Laplace integrates it out (R/fit-multi.R, "Gaussian REML is
## implemented by integrating the fixed-effect coefficient block"). Masked rows
## contribute exactly zero to the joint likelihood via the `is_y_observed` gate,
## so the joint remains a Gaussian LMM over the OBSERVED rows; Laplace is still
## exact there, and integrating `b_fix` over it is REML over the observed rows.
## The rank check already subset the design by `!masked_response`, anticipating
## precisely this.
##
## Each test asserts ENGAGEMENT before equivalence. An equivalence between two
## routes that are secretly the same computation proves nothing -- so REML must
## first be shown to differ from ML.

.rm_data <- function(n = 40, seed = 3) {
  set.seed(seed)
  d <- data.frame(site = factor(seq_len(n)), z = rnorm(n))
  d$t1 <- 0.4 + 0.7 * d$z + rnorm(n, sd = 0.4)
  d$t2 <- -0.2 + 0.3 * d$z + rnorm(n, sd = 0.5)
  d
}

.rm_fit <- function(dat, miss, reml) {
  suppressMessages(gllvmTMB(
    traits(t1, t2) ~ 1 + z,
    data = dat, unit = "site", family = gaussian(),
    missing = miss, REML = reml,
    control = gllvmTMBcontrol(se = FALSE)
  ))
}

test_that("REML is doing something (differs from ML on the same data)", {
  skip_on_cran()
  d <- .rm_data()
  ml   <- .rm_fit(d, miss_control(), FALSE)
  reml <- .rm_fit(d, miss_control(), TRUE)
  # Without this, the equivalence below would be vacuous.
  expect_gt(
    abs(as.numeric(stats::logLik(ml)) - as.numeric(stats::logLik(reml))),
    1e-3
  )
})

test_that("REML accepts response='include' and matches response='drop'", {
  skip_on_cran()
  d <- .rm_data()
  d$t1[1:3] <- NA

  # `drop` physically removes the missing cells, so a REML fit under `drop` IS
  # "REML on the reduced data". Agreement therefore shows the restricted
  # likelihood is being formed over the OBSERVED rows, which is the whole
  # correctness question.
  r_drop <- .rm_fit(d, miss_control(),                     TRUE)
  r_incl <- .rm_fit(d, miss_control(response = "include"), TRUE)

  expect_equal(
    as.numeric(stats::logLik(r_drop)),
    as.numeric(stats::logLik(r_incl)),
    tolerance = 1e-6
  )
  expect_equal(
    unname(r_drop$opt$par), unname(r_incl$opt$par),
    tolerance = 1e-4
  )
  expect_identical(nobs(r_drop), nobs(r_incl))
  expect_identical(nobs(r_incl), 77L)   # 40 * 2 - 3
})

test_that("REML + include still differs from ML + include", {
  skip_on_cran()
  # Guards against a regression where lifting the restriction silently dropped
  # the REML correction and fell back to ML.
  d <- .rm_data()
  d$t1[1:3] <- NA
  ml   <- .rm_fit(d, miss_control(response = "include"), FALSE)
  reml <- .rm_fit(d, miss_control(response = "include"), TRUE)
  expect_gt(
    abs(as.numeric(stats::logLik(ml)) - as.numeric(stats::logLik(reml))),
    1e-3
  )
})

test_that("the other REML guards still fire", {
  skip_on_cran()
  d <- .rm_data()
  d$t1[1:3] <- NA
  # Only the masked-response restriction is lifted. Non-Gaussian REML remains
  # unsupported and must still abort.
  expect_error(
    suppressMessages(gllvmTMB(
      traits(t1, t2) ~ 1 + z,
      data = transform(d, t1 = abs(round(d$t1 * 3)) , t2 = abs(round(d$t2 * 3))),
      unit = "site", family = poisson(),
      missing = miss_control(response = "include"), REML = TRUE,
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "Gaussian"
  )
})
