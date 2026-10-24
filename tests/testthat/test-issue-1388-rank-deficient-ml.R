## Issue #1388: a rank-deficient fixed-effect design was checked only under
## REML. Under the default ML fit it reached TMB and surfaced as the
## reason-less "All 1 restarts failed." (NA/NaN gradient).

test_that("the rank helper names the redundant column (#1388)", {
  X <- cbind(`(Intercept)` = 1, x = c(1, 2, 3, 5), x2 = 2 * c(1, 2, 3, 5))
  expect_null(gllvmTMB:::.gllvmTMB_check_fixed_rank(X[, 1:2]))
  expect_error(
    gllvmTMB:::.gllvmTMB_check_fixed_rank(X),
    class = "gllvmTMB_rank_deficient_design"
  )
  expect_error(gllvmTMB:::.gllvmTMB_check_fixed_rank(X), "x2")
  expect_error(gllvmTMB:::.gllvmTMB_check_fixed_rank(X, reml = TRUE), "full-rank")
  expect_null(gllvmTMB:::.gllvmTMB_check_fixed_rank(X[, 0, drop = FALSE]))
})

test_that("ML and REML fits with an aliased covariate abort naming it (#1388)", {
  set.seed(8)
  n <- 30L
  nt <- 3L
  d <- data.frame(
    unit = factor(rep(seq_len(n), each = nt)),
    trait = factor(rep(paste0("t", seq_len(nt)), n))
  )
  xu <- stats::rnorm(n)
  d$x <- xu[as.integer(d$unit)]
  d$x2 <- 2 * d$x
  d$value <- c(1, 0, -1)[as.integer(d$trait)] + 0.5 * d$x +
    stats::rnorm(n * nt, sd = 0.7)
  fit <- function(rhs, ...) {
    gllvmTMB(
      stats::as.formula(paste(
        "value ~ 0 + trait +", rhs, "+ latent(0 + trait | unit, d = 1)"
      )),
      data = d, unit = "unit", trait = "trait", family = gaussian(),
      control = gllvmTMBcontrol(n_init = 1, se = FALSE), ...
    )
  }
  expect_error(fit("x + x2"), class = "gllvmTMB_rank_deficient_design")
  expect_error(fit("x + x2"), "x2")
  expect_error(fit("x + x2", REML = TRUE), "full-rank")
  expect_s3_class(fit("x"), "gllvmTMB_multi")
})
