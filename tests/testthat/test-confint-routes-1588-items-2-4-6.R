## confint() interval routes (#1588), items 2, 4 and 6: rho intervals honour
## `link_residual`, profile_targets() lists each cluster-tier SD once, and a
## profile whose interval reaches zero does not leak the optimizer warning.

make_binomial_fit_1588 <- function() {
  set.seed(2)
  simb <- gllvmTMB::simulate_unit_trait(
    n_units = 150,
    n_obs_per_unit = 4,
    n_traits = 4,
    Lambda_B = matrix(c(1, 0.9, -0.8, 0.7)),
    sigma2_eps = 1e-6
  )
  simb$data$y <- stats::rbinom(nrow(simb$data), 1, stats::plogis(simb$data$value))
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = simb$data,
    trait = "trait",
    unit = "unit",
    family = stats::binomial()
  )))
}

make_cluster_fit_1588 <- function() {
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 40,
    n_species = 15,
    n_traits = 3,
    mean_species_per_site = 5,
    Lambda_B = matrix(c(0.8, 0.6, -0.5)),
    psi_B = 0.2,
    sigma2_sp = c(0.5, 0.4, 0.3),
    beta = matrix(0, 3, 2),
    seed = 4
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      latent(0 + trait | site, d = 1, unique = TRUE) +
      indep(0 + trait | species),
    data = s$data,
    trait = "trait",
    unit = "site",
    cluster = "species"
  )))
}

test_that("confint(parm = 'rho:...') forwards link_residual and never warns about its default (#1588 item 2)", {
  skip_on_cran()
  fitb <- make_binomial_fit_1588()

  ## The default-change warning fires once per session; reset it so the
  ## test does not depend on what ran before.
  withr::local_options(list(gllvmTMB.warned_link_residual_default_changed = NULL))
  ref_none <- suppressMessages(suppressWarnings(extract_correlations(
    fitb, tier = "unit", pair = c(1, 3), method = "fisher-z",
    link_residual = "none"
  )))
  ref_auto <- suppressMessages(extract_correlations(
    fitb, tier = "unit", pair = c(1, 3), method = "fisher-z",
    link_residual = "auto"
  ))

  ci_default <- expect_no_warning(confint(fitb, parm = "rho:unit:1,3"))
  ci_auto <- expect_no_warning(
    confint(fitb, parm = "rho:unit:1,3", link_residual = "auto")
  )
  ci_none <- confint(fitb, parm = "rho:unit:1,3", link_residual = "none")

  expect_equal(unname(ci_default[1, ]), c(ref_auto$lower, ref_auto$upper))
  expect_equal(unname(ci_auto[1, ]), c(ref_auto$lower, ref_auto$upper))
  expect_equal(unname(ci_none[1, ]), c(ref_none$lower, ref_none$upper))
  ## "none" and "auto" are different quantities on this binomial fit.
  expect_false(isTRUE(all.equal(ref_none$correlation, ref_auto$correlation)))

  expect_error(
    confint(fitb, parm = "rho:unit:1,3", link_residual = "nope"),
    "link_residual"
  )
})

test_that("confint() warns that link_residual is ignored outside the rho route (#1588 item 2)", {
  skip_on_cran()
  fitb <- make_binomial_fit_1588()
  ci_plain <- suppressMessages(confint(fitb, method = "wald"))
  expect_warning(
    ci_lr <- suppressMessages(confint(fitb, method = "wald", link_residual = "none")),
    class = "gllvmTMB_confint_link_residual_ignored"
  )
  ## The warning is the only change: the interval itself is the same.
  expect_equal(ci_lr, ci_plain)
  ## The rho route uses it, so it does not warn there.
  expect_no_warning(suppressMessages(
    confint(fitb, parm = "rho:unit:1,3", link_residual = "none")
  ))
})

test_that("profile_targets() lists each first-cluster-tier SD once (#1588 item 4)", {
  skip_on_cran()
  fitc <- make_cluster_fit_1588()
  pt <- profile_targets(fitc)
  rows <- pt[pt$tmb_parameter == "theta_diag_species", , drop = FALSE]
  expect_equal(rows$parm, sprintf("sd_cluster[%d]", 1:3))
  expect_false(any(grepl("^sd_phy_unique", pt$parm)))

  ## The legacy label still resolves in confint() and gives the same interval.
  ci_new <- confint(fitc, parm = "sd_cluster[2]", method = "wald")
  ci_old <- confint(fitc, parm = "sd_phy_unique[2]", method = "wald")
  expect_equal(rownames(ci_old), "sd_phy_unique[2]")
  expect_equal(unname(ci_old), unname(ci_new))
})

test_that("profiling an SD whose interval reaches zero does not leak the nlminb warning (#1588 item 6)", {
  skip_on_cran()
  set.seed(1)
  sim <- gllvmTMB::simulate_unit_trait(
    n_units = 50,
    n_obs_per_unit = 2,
    n_traits = 4,
    Lambda_B = matrix(c(0.9, 0.8, -0.7, 0.5)),
    psi_B = 0.2,
    sigma2_eps = 0.3
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = TRUE),
    data = sim$data,
    trait = "trait",
    unit = "unit"
  )))

  ci <- expect_no_warning(confint(fit, parm = "sd_B[1]"))
  expect_equal(unname(ci[1, 1]), 0)
  expect_true(is.finite(ci[1, 2]))

  insp <- expect_no_warning(confint_inspect(fit, parm = "sd_B[1]"))
  expect_true("hits_lower_bound" %in% insp$diagnostics)
})
