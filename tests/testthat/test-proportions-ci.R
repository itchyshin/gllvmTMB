## Lane 1 / agent A2 of Design 58 (Phase B-INF): focused tests for the
## Wald + Bootstrap CI paths for per-(trait, component) variance
## proportions on a binary probit fixture.
##
## Fixture: 6 traits, n_sites = 40, single seed. We cache the fit
## because building the binary probit fit + sd_report takes a few
## seconds; the same fit drives all four tests below.

.prop_ci_cache <- new.env(parent = emptyenv())

build_binary_probit_proportions_fit <- function(seed = 20260528L) {
  if (!is.null(.prop_ci_cache$fit)) {
    return(.prop_ci_cache$fit)
  }
  T <- 6L
  ## DGP balanced so the per-trait proportions stay interior (away from
  ## the 0 / 1 boundary). Strong-but-not-saturating Lambda + matched
  ## per-trait psi at the unit + unit_obs tiers + 6 obs per site keeps
  ## the binary probit n_sites = 40 fit well-identified so Wald and
  ## Bootstrap CIs roughly agree (the test below checks max abs diff
  ## < 0.10). At smaller signal or fewer obs / site the bootstrap
  ## naturally inflates relative to Wald, breaking the agreement test.
  Lam <- matrix(c(0.8, 0.7, -0.6, 0.6, -0.5, 0.7), nrow = T, ncol = 1L)
  psi <- rep(0.5, T)

  ## Latent-scale DGP, then probit -> Bernoulli.
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 40L,
    n_species = 6L,
    n_traits = T,
    mean_species_per_site = 6L,
    n_predictors = 1L,
    alpha = rep(0, T),
    beta  = matrix(0, nrow = T, ncol = 1L),
    Lambda_B = Lam,
    psi_B = psi,
    psi_W = rep(0.5, T),
    sigma2_eps = 0,
    seed = seed
  )
  df <- sim$data
  prob <- stats::pnorm(df$value)
  df$value <- stats::rbinom(length(prob), size = 1L, prob = prob)

  fit <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        latent(0 + trait | site, d = 1) +
        unique(0 + trait | site) +
        unique(0 + trait | site_species),
      data = df,
      family = binomial(link = "probit")
    )
  ))
  .prop_ci_cache$fit <- fit
  fit
}


test_that(".proportions_wald_ci() on shared_unit returns finite bounds with lower < p_hat < upper (binary probit)", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fit <- build_binary_probit_proportions_fit()

  tbl <- suppressMessages(suppressWarnings(
    gllvmTMB:::.proportions_wald_ci(
      fit,
      components = "shared_unit",
      trait_idx = NULL,
      level = 0.95
    )
  ))

  expect_s3_class(tbl, "data.frame")
  expect_named(
    tbl,
    c("trait", "component", "proportion", "lower", "upper", "method")
  )
  ## One row per trait (n_traits = 6).
  expect_equal(nrow(tbl), 6L)
  expect_true(all(tbl$method == "wald"))
  expect_true(all(is.finite(tbl$lower)))
  expect_true(all(is.finite(tbl$upper)))
  ## Logit-Wald: bounds always in [0, 1] and bracket the point.
  expect_true(all(tbl$lower >= 0 - 1e-10))
  expect_true(all(tbl$upper <= 1 + 1e-10))
  expect_true(all(tbl$lower < tbl$proportion))
  expect_true(all(tbl$proportion < tbl$upper))
})


test_that(".proportions_bootstrap_ci(nsim = 50) returns finite bounds and roughly matches Wald (binary probit)", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fit <- build_binary_probit_proportions_fit()

  wald <- suppressMessages(suppressWarnings(
    gllvmTMB:::.proportions_wald_ci(
      fit,
      components = "shared_unit",
      trait_idx = NULL,
      level = 0.95
    )
  ))

  boot <- suppressMessages(suppressWarnings(
    gllvmTMB:::.proportions_bootstrap_ci(
      fit,
      components = "shared_unit",
      trait_idx = NULL,
      level = 0.95,
      nsim = 50L,
      seed = 20260528L
    )
  ))

  expect_s3_class(boot, "data.frame")
  expect_named(
    boot,
    c("trait", "component", "proportion", "lower", "upper", "method")
  )
  expect_equal(nrow(boot), 6L)
  expect_true(all(boot$method == "bootstrap"))
  expect_true(all(is.finite(boot$lower)))
  expect_true(all(is.finite(boot$upper)))
  expect_true(all(boot$lower >= 0 - 1e-10))
  expect_true(all(boot$upper <= 1 + 1e-10))

  ## Point-estimate column matches across the two paths exactly.
  expect_equal(boot$proportion, wald$proportion, tolerance = 1e-10)

  ## Rough agreement: max absolute bound difference < 0.10 across all
  ## six traits. The bootstrap is parametric with only 50 replicates;
  ## the bound this is checking is loose-but-meaningful, matching the
  ## "Bootstrap with nsim = 50 returns finite bounds; rough agreement
  ## with Wald (max abs diff < 0.10)" task specification.
  max_diff <- max(
    abs(boot$lower - wald$lower),
    abs(boot$upper - wald$upper)
  )
  expect_lt(max_diff, 0.10)
})


test_that(".proportions_wald_ci() and .proportions_bootstrap_ci() on link_residual: bounds collapse for probit (fixed scale)", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fit <- build_binary_probit_proportions_fit()

  ## Probit -> fixed link residual = 1; the proportion is constant in
  ## theta. Wald and Bootstrap both collapse bounds to the point with
  ## method = "(unavailable)".
  wald <- suppressMessages(suppressWarnings(
    gllvmTMB:::.proportions_wald_ci(
      fit,
      components = "link_residual",
      trait_idx = 1L,
      level = 0.95
    )
  ))
  expect_equal(nrow(wald), 1L)
  expect_equal(as.character(wald$component), "link_residual")
  expect_equal(wald$method, "(unavailable)")
  expect_equal(wald$lower, wald$proportion, tolerance = 1e-12)
  expect_equal(wald$upper, wald$proportion, tolerance = 1e-12)

  boot <- suppressMessages(suppressWarnings(
    gllvmTMB:::.proportions_bootstrap_ci(
      fit,
      components = "link_residual",
      trait_idx = 1L,
      level = 0.95,
      nsim = 50L,
      seed = 20260528L
    )
  ))
  expect_equal(nrow(boot), 1L)
  expect_equal(as.character(boot$component), "link_residual")
  expect_equal(boot$method, "(unavailable)")
  expect_equal(boot$lower, boot$proportion, tolerance = 1e-12)
  expect_equal(boot$upper, boot$proportion, tolerance = 1e-12)
})


test_that(".proportions_wald_ci() and .proportions_bootstrap_ci() error on unknown component name", {
  skip_if_not_installed("TMB")
  skip_on_cran()
  fit <- build_binary_probit_proportions_fit()

  expect_error(
    suppressMessages(suppressWarnings(
      gllvmTMB:::.proportions_wald_ci(
        fit,
        components = "shared_phy",
        trait_idx = 1L
      )
    )),
    "not present|Available"
  )

  expect_error(
    suppressMessages(suppressWarnings(
      gllvmTMB:::.proportions_bootstrap_ci(
        fit,
        components = "bogus_component",
        trait_idx = 1L,
        nsim = 5L
      )
    )),
    "not present|Available"
  )
})
