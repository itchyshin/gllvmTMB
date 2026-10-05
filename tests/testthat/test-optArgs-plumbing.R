## Issue #1354: top-level nlminb/optim control names in optArgs must not be silent.

test_that("gllvmTMB warns when nlminb optArgs uses top-level iter.max (#1354)", {
  set.seed(1)
  n <- 20
  p <- 3
  d <- expand.grid(
    unit = factor(seq_len(n)),
    trait = factor(paste0("t", seq_len(p))),
    KEEP.OUT.ATTRS = FALSE
  )
  d$value <- rnorm(nrow(d))
  fm <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
  ctl <- gllvmTMBcontrol(
    optArgs = list(iter.max = 1L),
    se = FALSE
  )
  expect_warning(
    fit <- suppressMessages(
      gllvmTMB(fm, data = d, unit = "unit", trait = "trait", control = ctl)
    ),
    regexp = "optArgs.*ignored|iter\\.max"
  )
  expect_s3_class(fit, "gllvmTMB")
})
