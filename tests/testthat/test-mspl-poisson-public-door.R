## Public Poisson LA-MSPL door (experimental point, not covered).
## Contract: estimator="mspl" must not error on a tiny complete Poisson
## grid. Registry is admitted / admit_packet after G0 2026-08-16.
## Notes must not claim covered. No public SE.

test_that("public Poisson estimator=mspl is no longer the old family fence", {
  n_site <- 8L
  n_trait <- 3L
  dat <- data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = rep(0:3, length.out = n_site * n_trait)
  )
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat,
      family = stats::poisson(),
      estimator = "mspl",
      control = gllvmTMBcontrol(n_init = 1, se = FALSE, warn_runaway = FALSE)
    ),
    NA
  )
})

test_that("Poisson MSPL registry cell is experimental-point admitted, not covered", {
  row <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "poisson",
    link = "log",
    structure = "ordinary",
    q = 1L
  )
  expect_false(is.null(row))
  expect_identical(row$status, "admitted")
  expect_identical(row$evidence, "admit_packet")
  expect_false(identical(row$evidence, "covered"))
  expect_match(row$notes, "not a covered campaign")
  expect_match(row$notes, "no public SE")
})
