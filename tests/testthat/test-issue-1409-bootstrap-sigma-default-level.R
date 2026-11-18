## #1409: bootstrap_Sigma(fit) with the default `level` must not emit the
## `level = "B"/"W"` deprecation warnings -- the user passed neither.

test_that("bootstrap_Sigma() default level does not warn about legacy B/W", {
  set.seed(1409)
  n <- 40L
  dat <- data.frame(id = factor(seq_len(n)))
  z <- rnorm(n)
  dat$y1 <- 0.8 * z + rnorm(n, sd = 0.5)
  dat$y2 <- 0.5 * z + rnorm(n, sd = 0.5)
  dat$y3 <- -0.6 * z + rnorm(n, sd = 0.5)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 + latent(1 | id, d = 1),
    data = dat,
    unit = "id",
    silent = TRUE
  )))

  ## Reset the once-per-session cache so the warning can fire.
  withr::local_options(
    gllvmTMB.warned_level_B = NULL,
    gllvmTMB.warned_level_W = NULL
  )
  warns <- character()
  withCallingHandlers(
    suppressMessages(bootstrap_Sigma(
      fit, n_boot = 2L, seed = 1L, progress = FALSE
    )),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_false(any(grepl("is deprecated", warns, fixed = TRUE)))

  ## A user who explicitly passes the legacy alias is still warned.
  withr::local_options(gllvmTMB.warned_level_B = NULL)
  expect_warning(
    suppressMessages(bootstrap_Sigma(
      fit, n_boot = 2L, level = "B", seed = 1L, progress = FALSE
    )),
    "deprecated"
  )
})
