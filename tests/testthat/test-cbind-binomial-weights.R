# #1369: cbind(successes, failures) + weights was accepted and silently
# ignored. Honoring those weights as a likelihood multiplier would change
# the fitted likelihood, so the combination must abort instead.

skip_if_not_installed("gllvmTMB")

test_that("cbind binomial response refuses weights instead of ignoring them", {
  set.seed(11L)
  n <- 8L
  p <- 2L
  df <- expand.grid(
    site = factor(seq_len(n)),
    trait = factor(paste0("t", seq_len(p))),
    KEEP.OUT.ATTRS = FALSE
  )
  df$succ <- stats::rbinom(nrow(df), size = 4L, prob = 0.5)
  df$fail <- 4L - df$succ
  df$w <- ifelse(as.integer(df$site) <= 4L, 0, 1)

  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      cbind(succ, fail) ~ 0 + trait +
        latent(0 + trait | site, d = 1, unique = FALSE),
      data = df,
      family = binomial(),
      weights = df$w,
      silent = TRUE,
      control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
    ))),
    regexp = "weights.*cbind|cbind.*weights",
    ignore.case = TRUE,
    class = "gllvmTMB_cbind_binomial_weights_unsupported"
  )
})
