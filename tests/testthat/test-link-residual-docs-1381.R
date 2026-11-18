## Issue #1381: link_residual = "auto" applies per-family residuals, not binomial-only.

test_that("extract_communality link_residual=auto differs from none on Poisson (#1381)", {
  set.seed(1381)
  n <- 30
  traits <- c("a", "b")
  d <- expand.grid(
    unit = factor(rep(seq_len(n), times = length(traits))),
    trait = factor(rep(traits, each = n), levels = traits),
    KEEP.OUT.ATTRS = FALSE
  )
  d$value <- rpois(nrow(d), lambda = 5)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = d,
    unit = "unit",
    trait = "trait",
    family = poisson(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  comm_auto <- extract_communality(fit, link_residual = "auto")
  comm_none <- extract_communality(fit, link_residual = "none")
  expect_length(comm_auto, 2L)
  expect_false(isTRUE(all.equal(unname(comm_auto), unname(comm_none), tolerance = 1e-8)))
})
