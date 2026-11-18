## Public Beta-logit LA-MSPL door (planned only, not covered).
## Contract: estimator="mspl" must not error on a tiny complete Beta
## grid. Registry stays planned / phase4_prep. Notes must not claim
## covered. No public SE. Tweedie stays fenced.

test_that("public Beta estimator=mspl is no longer the old family fence", {
  n_site <- 8L
  n_trait <- 3L
  dat <- data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = rep(c(0.2, 0.5, 0.8), length.out = n_site * n_trait)
  )
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat,
      family = Beta(),
      estimator = "mspl",
      control = gllvmTMBcontrol(n_init = 1, se = FALSE, warn_runaway = FALSE)
    ),
    NA
  )
})

test_that("Beta MSPL registry cell stays planned, not admitted or covered", {
  row <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "Beta",
    link = "logit",
    structure = "ordinary",
    q = 1L
  )
  expect_false(is.null(row))
  expect_identical(row$status, "planned")
  expect_identical(row$evidence, "phase4_prep")
  expect_false(identical(row$status, "admitted"))
  expect_false(identical(row$evidence, "covered"))
  expect_match(row$notes, "not admitted")
  expect_match(row$notes, "not covered")
  expect_false(grepl("no public door", row$notes, fixed = TRUE))
})
