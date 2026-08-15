## Public Poisson LA-MSPL door (planned tape, not admitted).
## Contract: estimator="mspl" must not error on a tiny complete Poisson
## grid. Registry stays planned. Notes must not claim covered/admitted.
## If prepare or the C++ Poisson tape is not yet widened, this file is
## expected RED. Do not weaken the success test to go green.

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

test_that("Poisson MSPL registry cell stays planned, not admitted", {
  row <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "poisson",
    link = "log",
    structure = "ordinary",
    q = 1L
  )
  expect_false(is.null(row))
  expect_identical(row$status, "planned")
  expect_false(identical(row$status, "admitted"))
  expect_match(row$notes, "not admitted")
  expect_match(row$notes, "not covered")
})
