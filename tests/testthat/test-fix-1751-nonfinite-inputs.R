## Issue #1751: Inf / -Inf in the response or a covariate must abort with a
## helpful cli message before nlminb/TMB, not via base-R NA/NaN/Inf errors.
## NA responses stay droppable; NA predictors keep the existing abort.

.fix1751_fixture <- function() {
  set.seed(1L)
  n <- 20L
  p <- 3L
  data.frame(
    unit  = factor(rep(seq_len(n), p)),
    trait = factor(rep(paste0("t", seq_len(p)), each = n)),
    value = stats::rnorm(n * p),
    x     = stats::rnorm(n)[rep(seq_len(n), p)]
  )
}

.fit1751 <- function(dat, formula = value ~ 0 + trait + x + latent(0 + trait | unit, d = 1)) {
  suppressWarnings(suppressMessages(gllvmTMB(
    formula,
    data = dat,
    unit = "unit",
    trait = "trait",
    family = gaussian(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE),
    silent = TRUE
  )))
}

test_that("#1751 Inf and -Inf responses abort before the optimizer", {
  dat <- .fix1751_fixture()
  dat$value[1] <- Inf
  expect_error(
    .fit1751(dat, value ~ 0 + trait + latent(0 + trait | unit, d = 1)),
    "The observed response must be finite"
  )
  dat <- .fix1751_fixture()
  dat$value[2] <- -Inf
  expect_error(
    .fit1751(dat, value ~ 0 + trait + latent(0 + trait | unit, d = 1)),
    "The observed response must be finite"
  )
})

test_that("#1751 Inf in a fixed-effect covariate aborts and names the design column", {
  dat <- .fix1751_fixture()
  dat$x[1] <- Inf
  expect_error(
    .fit1751(dat),
    "Non-finite values in the fixed-effect design matrix"
  )
  expect_error(.fit1751(dat), "Offending design column")
})

test_that("#1751 NA responses still fit", {
  dat <- .fix1751_fixture()
  dat$value[1] <- NA_real_
  fit <- .fit1751(dat, value ~ 0 + trait + latent(0 + trait | unit, d = 1))
  expect_s3_class(fit, "gllvmTMB")
})
