## Issue #1910: gllvmTMBcontrol(REML = TRUE) must route REML like the top-level
## argument, and disagreeing top-level vs control values must error.

test_that("control REML = TRUE matches top-level REML = TRUE (logLik and attr)", {
  set.seed(1126L)
  d <- expand.grid(site = factor(seq_len(18)), trait = factor(c("t1", "t2")))
  d$value <- stats::rnorm(nrow(d))
  fml <- value ~ 0 + trait + latent(1 | site, d = 1)

  fit_ml <- suppressMessages(gllvmTMB(
    fml, data = d, family = gaussian(), unit = "site",
    control = gllvmTMBcontrol(REML = FALSE)
  ))
  fit_ctl <- suppressMessages(gllvmTMB(
    fml, data = d, family = gaussian(), unit = "site",
    control = gllvmTMBcontrol(REML = TRUE)
  ))
  fit_top <- suppressMessages(gllvmTMB(
    fml, data = d, family = gaussian(), unit = "site",
    REML = TRUE
  ))

  expect_equal(as.numeric(logLik(fit_ctl)), as.numeric(logLik(fit_top)))
  expect_equal(attr(logLik(fit_ctl), "REML"), attr(logLik(fit_top), "REML"))
  expect_true(isTRUE(attr(logLik(fit_ctl), "REML")))

  expect_equal(as.numeric(logLik(fit_ml)), as.numeric(logLik(fit_ctl)), negate = TRUE)
  expect_false(isTRUE(attr(logLik(fit_ml), "REML")))
})

test_that("disagreeing REML in gllvmTMB() and gllvmTMBcontrol() errors", {
  set.seed(1126L)
  d <- expand.grid(site = factor(seq_len(6)), trait = factor(c("t1", "t2")))
  d$value <- stats::rnorm(nrow(d))
  fml <- value ~ 0 + trait + latent(1 | site, d = 1)

  expect_error(
    gllvmTMB(
      fml, data = d, family = gaussian(), unit = "site",
      REML = FALSE,
      control = gllvmTMBcontrol(REML = TRUE)
    ),
    class = "gllvmTMB_reml_control_conflict"
  )
  expect_error(
    gllvmTMB(
      fml, data = d, family = gaussian(), unit = "site",
      REML = TRUE,
      control = gllvmTMBcontrol(REML = FALSE)
    ),
    class = "gllvmTMB_reml_control_conflict"
  )
})