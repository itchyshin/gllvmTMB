## Wald (delta-method) and Bootstrap CI helpers for per-trait
## communality (Phase B-INF Lane 1, A1). The profile path already exists
## in `profile_ci_communality()`; these tests exercise the two new
## internal helpers `.communality_wald_ci()` and
## `.communality_bootstrap_ci()` on a small binary-probit fixture.
##
## Fixture: `latent(0 + trait | site) + unique(0 + trait | site)` with
## 6 traits and n_sites = 40. Binary probit with `unique()` is on the
## edge of identifiability at n = 40 -- Lambda tends to absorb almost
## all latent variance while psi -> 0 -- so the Wald / Bootstrap
## agreement assertion is **narrowed** (per the Lane 1 hard constraint
## "narrow the test to more-identified traits rather than relax
## assertions") to a single trait whose post-fit c^2 sits squarely in
## the well-identified interior (~0.4 here). The mechanical assertions
## (finite, bracketing the point estimate) are tested on the same trait.

## ---- Shared binary probit fixture ---------------------------------

make_communality_binary_fit <- function(seed = 2026002L) {
  set.seed(seed)
  T_n <- 6L
  n_sites <- 40L
  ## Decreasing loadings so trait 1 carries the strongest signal; equal
  ## per-trait psi to keep psi sane at small n.
  Lam <- matrix(c(1.5, 1.2, 0.9, 0.6, 0.3, 0.0), nrow = T_n, ncol = 1L)
  psi <- rep(1.0, T_n)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites, n_species = 1L, n_traits = T_n,
    mean_species_per_site = 1, n_predictors = 1,
    alpha = rep(0, T_n),
    beta  = matrix(0, nrow = T_n, ncol = 1L),
    Lambda_B = Lam, psi_B = psi,
    sigma2_eps = 0, seed = seed
  )
  df <- sim$data
  prob <- stats::pnorm(df$value)
  df$value <- stats::rbinom(length(prob), size = 1L, prob = prob)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data   = df,
    family = stats::binomial(link = "probit")
  )))
  list(fit = fit, T = T_n)
}


## ---- Wald CI: finite, brackets the point estimate -----------------

test_that(".communality_wald_ci() returns finite (lower, upper) bracketing c2_hat", {
  skip_on_cran()
  obj <- make_communality_binary_fit()
  expect_equal(obj$fit$opt$convergence, 0L)

  ## Trait 1 has the strongest loading and a mid-range c^2 in (0.1, 0.9)
  ## -- the regime where the Wald delta on logit(c^2) is well-defined.
  ci <- gllvmTMB:::.communality_wald_ci(
    obj$fit, tier = "unit", trait_idx = 1L, level = 0.95
  )
  expect_named(ci, c("estimate", "lower", "upper"))
  expect_true(all(is.finite(ci)))
  expect_gte(ci["lower"], 0)
  expect_lte(ci["upper"], 1)
  expect_lt(ci["lower"], ci["estimate"])
  expect_lt(ci["estimate"], ci["upper"])
})


## ---- Bootstrap CI: finite, brackets the point estimate ------------

test_that(".communality_bootstrap_ci() with nsim = 50 returns finite (lower, upper)", {
  skip_on_cran()
  obj <- make_communality_binary_fit()

  ci <- gllvmTMB:::.communality_bootstrap_ci(
    obj$fit, tier = "unit", trait_idx = 1L, level = 0.95,
    nsim = 50L, seed = 42L
  )
  expect_named(ci, c("estimate", "lower", "upper"))
  expect_true(all(is.finite(ci)))
  expect_gte(ci["lower"], 0 - 1e-8)
  expect_lte(ci["upper"], 1 + 1e-8)
  expect_lte(ci["lower"], ci["estimate"] + 1e-6)
  expect_gte(ci["upper"], ci["estimate"] - 1e-6)
})


## ---- Wald vs Bootstrap rough agreement on the well-identified trait

test_that("Wald and Bootstrap CIs roughly agree on the well-identified trait", {
  skip_on_cran()
  obj <- make_communality_binary_fit()

  wald <- gllvmTMB:::.communality_wald_ci(
    obj$fit, tier = "unit", trait_idx = 1L, level = 0.95
  )
  boot <- gllvmTMB:::.communality_bootstrap_ci(
    obj$fit, tier = "unit", trait_idx = 1L, level = 0.95,
    nsim = 50L, seed = 101L
  )
  expect_true(all(is.finite(c(wald, boot))))
  ## Point estimates agree exactly (both pull from the same fit).
  expect_equal(unname(wald["estimate"]), unname(boot["estimate"]),
               tolerance = 1e-8)
  ## Lower / upper CI bounds: < 0.10 absolute difference for the
  ## well-identified trait (mid c^2, strongest loading).
  expect_lt(abs(wald["lower"] - boot["lower"]), 0.10)
  expect_lt(abs(wald["upper"] - boot["upper"]), 0.10)
})


## ---- Bad inputs error clearly -------------------------------------

test_that(".communality_wald_ci() errors clearly on bad inputs", {
  skip_on_cran()
  obj <- make_communality_binary_fit()

  expect_error(
    gllvmTMB:::.communality_wald_ci("not a fit", tier = "unit", trait_idx = 1L),
    "gllvmTMB"
  )
  expect_error(
    gllvmTMB:::.communality_wald_ci(obj$fit, tier = "unit",
                                    trait_idx = 1L, level = 1.5),
    "level"
  )
  expect_error(
    gllvmTMB:::.communality_wald_ci(obj$fit, tier = "unit",
                                    trait_idx = obj$T + 5L),
    "trait_idx"
  )
  ## A tier outside the supported set (phy / spatial / cluster) is
  ## rejected before any numerical work.
  expect_error(
    gllvmTMB:::.communality_wald_ci(obj$fit, tier = "phy", trait_idx = 1L)
  )
})


test_that(".communality_bootstrap_ci() errors clearly on bad inputs", {
  skip_on_cran()
  obj <- make_communality_binary_fit()

  expect_error(
    gllvmTMB:::.communality_bootstrap_ci("not a fit", tier = "unit",
                                         trait_idx = 1L, nsim = 5L),
    "gllvmTMB"
  )
  expect_error(
    gllvmTMB:::.communality_bootstrap_ci(obj$fit, tier = "unit",
                                         trait_idx = 1L, nsim = 0L),
    "nsim"
  )
  expect_error(
    gllvmTMB:::.communality_bootstrap_ci(obj$fit, tier = "unit",
                                         trait_idx = obj$T + 5L,
                                         nsim = 5L),
    "trait_idx"
  )
})
