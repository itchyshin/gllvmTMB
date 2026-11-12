## #1783: y ~ 0 + trait with a one-level trait died in model.matrix() with
## "contrasts can be applied only to factors with 2 or more levels".
## y ~ 1 on the same data fits. This test fails on main because the error
## is a base-R simpleError, not gllvmTMB_one_level_factor.

.ctrl_1783 <- function() {
  gllvmTMBcontrol(se = FALSE, n_init = 1L, laplace_auto_refit = FALSE)
}

.one_trait_1783 <- function() {
  set.seed(1)
  d <- expand.grid(
    unit = factor(1:12),
    trait = factor(paste0("t", 1:3)),
    KEEP.OUT.ATTRS = FALSE
  )
  d$y <- stats::rnorm(nrow(d))
  d1 <- d[d$trait == "t1", ]
  d1$trait <- factor(d1$trait)
  list(d = d, d1 = d1)
}

test_that("#1783 one-level 0 + trait aborts with gllvmTMB_one_level_factor", {
  d1 <- .one_trait_1783()$d1
  expect_error(
    suppressWarnings(gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = d1, trait = "trait", unit = "unit",
      family = gaussian(),
      control = .ctrl_1783(),
      silent = TRUE
    )),
    "trait",
    class = "gllvmTMB_one_level_factor"
  )
  expect_error(
    suppressWarnings(gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = d1, trait = "trait", unit = "unit",
      family = gaussian(),
      control = .ctrl_1783(),
      silent = TRUE
    )),
    "two levels",
    class = "gllvmTMB_one_level_factor"
  )
})

test_that("#1783 one-level data still fits with an intercept-only formula", {
  d1 <- .one_trait_1783()$d1
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    y ~ 1 + latent(1 | unit, d = 1),
    data = d1, trait = "trait", unit = "unit",
    family = gaussian(),
    control = .ctrl_1783(),
    silent = TRUE
  )))
  expect_s3_class(fit, "gllvmTMB_multi")
})

test_that("#1783 two-level 0 + trait still fits", {
  dat <- .one_trait_1783()$d
  dat <- dat[dat$trait != "t3", ]
  dat$trait <- factor(dat$trait)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat, trait = "trait", unit = "unit",
    family = gaussian(),
    control = .ctrl_1783(),
    silent = TRUE
  )))
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_gte(nlevels(fit$data[[fit$trait_col]]), 2L)
})
