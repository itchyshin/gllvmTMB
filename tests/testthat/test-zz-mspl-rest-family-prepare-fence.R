## zz- prefix: run after test-va-all-family-light-fits.R (CI order).
## Live public-door fence for families that still have no MSPL door.
## Complements test-mspl-prepare-fence.R (Tweedie after the Beta door)
## and does not open a door. Not an admission. No src/.
## These families now have planned rows but no public door — live
## reject stays; the registry pin below requires planned, not admitted.
##
## Sibling oracle PRs (#1003/#1004/#1005/#1023/#1024/#1025) are
## source-scan only; this file is the live gllvmTMB() reject.

.mspl_rest_grid <- function(y) {
  n_site <- 8L
  n_trait <- 3L
  data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = y
  )
}

.mspl_rest_form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)

.mspl_rest_expect_unsupported <- function(family_name, expr) {
  expect_error(
    expr,
    "supports a single gaussian, bernoulli, Poisson, nbinom1, nbinom2, or Beta response family only",
    class = "gllvmTMB_mspl_unsupported",
    info = family_name
  )
}

test_that("LA-MSPL prepare still rejects Gamma, lognormal, student, ordinal, and delta", {
  n <- 24L
  cases <- list(
    Gamma = list(
      family = stats::Gamma(link = "log"),
      y = rep(c(0.5, 1, 2), length.out = n)
    ),
    lognormal = list(
      family = lognormal(),
      y = rep(c(0.5, 1, 2), length.out = n)
    ),
    student = list(
      family = suppressMessages(student(df = 5)),
      y = rep(c(-0.5, 0, 0.8), length.out = n)
    ),
    ordinal_probit = list(
      family = ordinal_probit(),
      ## Cycle by site so every trait sees K>=2 categories.
      y = factor(rep(rep(1:3, length.out = 8L), each = 3L), ordered = TRUE)
    ),
    delta_lognormal = list(
      family = delta_lognormal(),
      y = rep(c(0, 0.5, 1.5), length.out = n)
    ),
    delta_gamma = list(
      family = delta_gamma(),
      y = rep(c(0, 0.5, 1.5), length.out = n)
    )
  )
  for (family_name in names(cases)) {
    case <- cases[[family_name]]
    .mspl_rest_expect_unsupported(
      family_name,
      gllvmTMB(
        .mspl_rest_form,
        data = .mspl_rest_grid(case$y),
        family = case$family,
        estimator = "mspl"
      )
    )
  }
})

test_that("LA-MSPL prepare still rejects truncated Poisson and truncated NB2", {
  n <- 24L
  y <- rep(1:4, length.out = n)
  .mspl_rest_expect_unsupported(
    "truncated_poisson",
    gllvmTMB(
      .mspl_rest_form,
      data = .mspl_rest_grid(y),
      family = truncated_poisson(),
      estimator = "mspl"
    )
  )
  .mspl_rest_expect_unsupported(
    "truncated_nbinom2",
    gllvmTMB(
      .mspl_rest_form,
      data = .mspl_rest_grid(y),
      family = truncated_nbinom2(),
      estimator = "mspl"
    )
  )
})

test_that("LA-MSPL prepare still rejects betabinomial cbind", {
  n_site <- 8L
  n_trait <- 3L
  dat <- data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    succ = rep(c(1L, 2L, 3L), length.out = n_site * n_trait),
    fail = rep(c(4L, 3L, 2L), length.out = n_site * n_trait)
  )
  .mspl_rest_expect_unsupported(
    "betabinomial",
    gllvmTMB(
      cbind(succ, fail) ~ 0 + trait +
        latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat,
      family = betabinomial(),
      estimator = "mspl"
    )
  )
})

test_that("LA-MSPL prepare still rejects multinomial", {
  n <- 8L
  dat <- data.frame(
    site = factor(seq_len(n)),
    trait = factor(rep("morph", n)),
    y = factor(rep(1:3, length.out = n))
  )
  .mspl_rest_expect_unsupported(
    "multinomial",
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat,
      family = multinomial(),
      trait = "trait",
      unit = "site",
      estimator = "mspl"
    )
  )
})

test_that("rest-family cells are planned phase4_prep, not admitted", {
  reg <- gllvmTMB:::.gllvmTMB_mspl_registry()
  ## Planned rows exist; live reject above still covers the public door.
  rest <- c(
    "student", "ordinal_probit", "betabinomial",
    "truncated_poisson", "truncated_nbinom2", "multinomial"
  )
  rest_rows <- reg[reg$family %in% rest, , drop = FALSE]
  expect_identical(nrow(rest_rows), 12L)
  expect_true(all(rest_rows$status == "planned"))
  expect_true(all(rest_rows$evidence == "phase4_prep"))
  expect_false(any(rest_rows$status == "admitted"))
  expect_false(any(reg$family %in% rest & reg$status == "admitted"))
})
