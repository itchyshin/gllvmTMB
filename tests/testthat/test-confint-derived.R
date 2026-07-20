## Stage 3a of the profile-CI unified framework (2026-05-27): routes the
## four derived-quantity profile-CI functions through
## `confint.gllvmTMB_multi()` via parm tokens
##   - "icc[:trait]"            -> profile_ci_repeatability / extract_repeatability
##   - "phylo_signal[:trait]"   -> profile_ci_phylo_signal
##   - "communality:tier[:trait]" -> profile_ci_communality
##   - "rho:tier:i,j[;k,l]"     -> profile_ci_correlation / extract_correlations
##
## The token recogniser / parser / dispatcher pattern mirrors the Stage 2
## Lambda machinery in test-confint-lambda.R.

## ---- Fixtures --------------------------------------------------------

## Build a small Gaussian fit with rr_B + diag_B at the unit tier and
## diag_W at the unit_obs tier, so the same fixture exercises ICC,
## communality:unit, and rho:unit:i,j.
##
## Mirrors `make_tiny_BW_fit()` from test-profile-ci.R. We use a
## Gaussian fit (not binary) because single-trial binomial fits map
## off theta_diag_W as structurally unidentifiable — and ICC needs
## both theta_diag_B and theta_diag_W. The brief notes binary "where
## possible" for unit_obs; the routing logic is family-agnostic, so
## Gaussian is the right choice here.
build_derived_fixture <- function(seed = 42L) {
  set.seed(seed)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 80L,
    n_species = 6L,
    n_traits = 3L,
    mean_species_per_site = 4L,
    Lambda_B = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B = c(0.40, 0.30, 0.50),
    psi_W = c(0.30, 0.40, 0.30),
    beta = matrix(0, 3L, 2L),
    seed = seed
  )
  fit <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | site, d = 1) +
        unique(0 + trait | site) +
        unique(0 + trait | site_species),
      data = s$data,
      silent = TRUE
    )
  ))
  list(fit = fit, T = 3L)
}

.unit_obs_profile_cache <- new.env(parent = emptyenv())

## Build a small Gaussian fit with rr_W + diag_W at the observed-unit
## tier and no unit-tier reduced-rank term. This is the fitted W-tier
## canary for `communality:unit_obs` and `rho:unit_obs:i,j` profile
## routes; the main fixture above only has diag_W at this tier.
build_unit_obs_profile_fixture <- function(seed = 20260705L) {
  if (!is.null(.unit_obs_profile_cache$fit)) {
    return(list(
      fit = .unit_obs_profile_cache$fit,
      T = .unit_obs_profile_cache$T
    ))
  }
  set.seed(seed)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 30L,
    n_species = 5L,
    n_traits = 3L,
    mean_species_per_site = 4L,
    Lambda_B = matrix(0, 3L, 1L),
    Lambda_W = matrix(c(0.8, 0.45, -0.35), 3L, 1L),
    psi_B = c(0.05, 0.05, 0.05),
    psi_W = c(0.25, 0.35, 0.30),
    beta = matrix(0, 3L, 2L),
    seed = seed
  )
  fit <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | site_species, d = 1) +
        unique(0 + trait | site_species),
      data = s$data,
      control = gllvmTMB::gllvmTMBcontrol(se = TRUE, n_init = 1),
      silent = TRUE
    )
  ))
  .unit_obs_profile_cache$fit <- fit
  .unit_obs_profile_cache$T <- 3L
  list(fit = fit, T = 3L)
}

## ============================================================================
##  ICC / repeatability tokens
## ============================================================================

test_that("confint(fit, parm = 'icc') returns one row per trait (matrix shape)", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(confint(fx$fit, parm = "icc", method = "wald"))
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), fx$T)
  expect_equal(ncol(ci), 2L)
  expect_match(rownames(ci)[1], "^icc:")
  expect_equal(colnames(ci), c("2.5 %", "97.5 %"))
})

test_that("confint(fit, parm = 'icc:trait_1') returns exactly one row", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(confint(fx$fit, parm = "icc:trait_1", method = "wald"))
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), 1L)
  expect_equal(rownames(ci), "icc:trait_1")
})

test_that("confint(fit, parm = 'icc:[1]') accepts 1-based index", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(confint(fx$fit, parm = "icc:[1]", method = "wald"))
  expect_equal(nrow(ci), 1L)
  expect_equal(rownames(ci), "icc:trait_1")
})

test_that("confint(fit, parm = 'icc:[1,3]') returns two rows", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(confint(fx$fit, parm = "icc:[1,3]", method = "wald"))
  expect_equal(nrow(ci), 2L)
  expect_equal(rownames(ci), c("icc:trait_1", "icc:trait_3"))
})

test_that("confint(fit, parm = 'icc:trait_1;trait_3') returns two rows by name", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(
    confint(fx$fit, parm = "icc:trait_1;trait_3", method = "wald")
  )
  expect_equal(nrow(ci), 2L)
  expect_equal(rownames(ci), c("icc:trait_1", "icc:trait_3"))
})

test_that("confint(fit, parm = 'icc:bogus') errors clearly on unknown trait", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  expect_error(
    suppressMessages(confint(fx$fit, parm = "icc:bogus")),
    "bogus|not found"
  )
})

test_that("confint(fit, parm = 'icc:[99]') errors on out-of-range index", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  expect_error(
    suppressMessages(confint(fx$fit, parm = "icc:[99]")),
    "range"
  )
})

test_that("confint(fit, parm = 'icc') with method = 'profile' is explicitly withheld", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  expect_error(
    suppressMessages(confint(fx$fit, parm = "icc:trait_1", method = "profile")),
    class = "gllvmTMB_repeatability_profile_withdrawn"
  )
})

test_that("confint(fit, parm = 'icc') bounds are within [0, 1]", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(confint(fx$fit, parm = "icc", method = "wald"))
  ## Bounds should be inside [0, 1] (allow tiny numerical leeway)
  finite <- is.finite(ci)
  expect_true(all(ci[finite] >= -1e-8))
  expect_true(all(ci[finite] <= 1 + 1e-8))
})

test_that("confint(fit, parm = 'icc') with method = 'bootstrap' returns matrix", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(confint(
    fx$fit,
    parm = "icc",
    method = "bootstrap",
    nsim = 25L,
    seed = 1L
  ))
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), fx$T)
  expect_equal(ncol(ci), 2L)
})

## ============================================================================
##  Phylogenetic signal token
## ============================================================================

test_that("confint(fit, parm = 'phylo_signal') errors when no phylo component", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ## Fixture has no phylo_*() term; phylo_signal must error clearly.
  expect_error(
    suppressMessages(confint(fx$fit, parm = "phylo_signal")),
    "phylo"
  )
})

test_that("confint(fit, parm = 'phylo_signal', method = 'wald') errors when fit has no phylo component", {
  skip_if_not_heavy()
  ## Phase B-INF Lane 1 A3 wired wald for phylo_signal; the error now
  ## comes from the per-trait absence-of-phylo check, not a
  ## not-implemented message.
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  expect_error(
    suppressMessages(confint(fx$fit, parm = "phylo_signal", method = "wald")),
    "phylogenetic|phylo"
  )
})

test_that("confint(fit, parm = 'phylo_signal:trait_1') parses one trait", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ## Still errors (no phylo component) but the per-trait token must parse.
  ## We're catching the absence-of-phylo error, not a parse error.
  expect_error(
    suppressMessages(confint(fx$fit, parm = "phylo_signal:trait_1")),
    "phylo"
  )
})

test_that("confint(fit, parm = 'phylo_signal:bogus') errors on unknown trait", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ## The parser runs BEFORE the phylo check, so unknown trait name
  ## should hit the parse error, not the phylo error.
  expect_error(
    suppressMessages(confint(fx$fit, parm = "phylo_signal:bogus")),
    "bogus|not found"
  )
})

## ============================================================================
##  Communality tokens
## ============================================================================

test_that("confint(fit, parm = 'communality:unit') returns one row per trait", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(confint(fx$fit, parm = "communality:unit"))
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), fx$T)
  expect_equal(ncol(ci), 2L)
  expect_true(all(grepl("^communality:unit:", rownames(ci))))
})

test_that("confint(fit, parm = 'communality:unit:trait_1') returns one row", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(
    confint(fx$fit, parm = "communality:unit:trait_1")
  )
  expect_equal(nrow(ci), 1L)
  expect_equal(rownames(ci), "communality:unit:trait_1")
})

test_that("confint(fit, parm = 'communality:unit:[2]') accepts bracketed index", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(
    confint(fx$fit, parm = "communality:unit:[2]")
  )
  expect_equal(nrow(ci), 1L)
  expect_equal(rownames(ci), "communality:unit:trait_2")
})

test_that("confint(fit, parm = 'communality:bogus') errors on bad tier", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  expect_error(
    suppressMessages(confint(fx$fit, parm = "communality:bogus")),
    "tier|bogus"
  )
})

test_that("confint(fit, parm = 'communality') without tier errors loudly", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ## Bare "communality" does NOT match the recogniser (which requires
  ## "communality:"). It must fail loudly at ordinary parameter resolution
  ## rather than returning an empty/all-NA matrix.
  expect_error(
    suppressMessages(confint(fx$fit, parm = "communality", method = "wald")),
    "Unknown `parm` value|Available terms"
  )
})

test_that("confint(fit, parm = 'communality:unit', method = 'wald') returns finite bounds", {
  skip_if_not_heavy()
  ## Phase B-INF Lane 1 A1 wired wald for communality via delta method
  ## on logit-c^2; bounds must be inside [0, 1].
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  res <- suppressMessages(suppressWarnings(
    confint(fx$fit, parm = "communality:unit", method = "wald")
  ))
  expect_true(is.matrix(res))
  expect_equal(ncol(res), 2L)
  expect_true(all(is.finite(res)))
  expect_true(all(res >= 0 & res <= 1))
})

test_that("confint(fit, parm = 'communality:unit', method = 'bootstrap') returns finite bounds", {
  skip_if_not_heavy()
  ## Phase B-INF Lane 1 A1 wired bootstrap (default nsim).
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  res <- suppressMessages(suppressWarnings(
    confint(
      fx$fit,
      parm = "communality:unit",
      method = "bootstrap",
      nsim = 30L,
      seed = 42L
    )
  ))
  expect_true(is.matrix(res))
  expect_equal(ncol(res), 2L)
  expect_true(all(is.finite(res)))
  expect_true(all(res >= 0 & res <= 1))
})

test_that("confint(fit, parm = 'communality:unit') bounds are within [0, 1]", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(confint(fx$fit, parm = "communality:unit"))
  finite <- is.finite(ci)
  expect_true(all(ci[finite] >= -1e-3))
  expect_true(all(ci[finite] <= 1 + 1e-3))
})

test_that("confint(fit, parm = 'communality:unit_obs') profile is explicitly withheld", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_unit_obs_profile_fixture()
  expect_true(isTRUE(fx$fit$use$rr_W))
  expect_true(isTRUE(fx$fit$use$diag_W))
  expect_false(isTRUE(fx$fit$use$rr_B))
  expect_error(suppressMessages(suppressWarnings(
    confint(
      fx$fit,
      parm = "communality:unit_obs:trait_1",
      method = "profile"
    )
  )), class = "gllvmTMB_nonlinear_profile_withdrawn")
})

## ============================================================================
##  Cross-trait correlation tokens
## ============================================================================

test_that("confint(fit, parm = 'rho:unit:1,2') returns exactly one row", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(
    confint(fx$fit, parm = "rho:unit:1,2", method = "fisher-z")
  )
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), 1L)
  expect_equal(rownames(ci), "rho:unit:1,2")
  expect_equal(ncol(ci), 2L)
})

test_that("confint(fit, parm = 'rho:unit:1,2;1,3') returns two rows", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(
    confint(fx$fit, parm = "rho:unit:1,2;1,3", method = "fisher-z")
  )
  expect_equal(nrow(ci), 2L)
  expect_equal(rownames(ci), c("rho:unit:1,2", "rho:unit:1,3"))
})

test_that("confint(fit, parm = 'rho:unit:9,9') errors on out-of-range pair", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  expect_error(
    suppressMessages(confint(fx$fit, parm = "rho:unit:9,9")),
    "range"
  )
})

test_that("confint(fit, parm = 'rho:unit:1,1') errors on self-pair", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  expect_error(
    suppressMessages(confint(fx$fit, parm = "rho:unit:1,1")),
    "distinct"
  )
})

test_that("confint(fit, parm = 'rho:unit:2,1') canonicalises to i<j", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ## User passes "2,1"; parser canonicalises to (1, 2). Row label
  ## reports the canonical form.
  ci <- suppressMessages(
    confint(fx$fit, parm = "rho:unit:2,1", method = "fisher-z")
  )
  expect_equal(nrow(ci), 1L)
  expect_equal(rownames(ci), "rho:unit:1,2")
})

test_that("confint(fit, parm = 'rho:bogus:1,2') errors on bad tier", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  expect_error(
    suppressMessages(confint(fx$fit, parm = "rho:bogus:1,2")),
    "tier|bogus"
  )
})

test_that("confint(fit, parm = 'rho:unit:1,2', method = 'fisher-z') gives bounds in [-1, 1]", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci <- suppressMessages(
    confint(fx$fit, parm = "rho:unit:1,2", method = "fisher-z")
  )
  expect_true(all(is.finite(ci)))
  expect_true(all(ci >= -1 - 1e-8))
  expect_true(all(ci <= 1 + 1e-8))
})

test_that("confint(fit, parm = 'rho:unit:1,2', method = 'wald') aliases fisher-z", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ## extract_correlations() treats wald as an alias of fisher-z.
  ci_w <- suppressMessages(
    confint(fx$fit, parm = "rho:unit:1,2", method = "wald")
  )
  ci_f <- suppressMessages(
    confint(fx$fit, parm = "rho:unit:1,2", method = "fisher-z")
  )
  expect_equal(ci_w, ci_f)
})

test_that("confint(fit, parm = 'rho:unit_obs') profile is explicitly withheld", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_unit_obs_profile_fixture()
  expect_true(isTRUE(fx$fit$use$rr_W))
  expect_true(isTRUE(fx$fit$use$diag_W))
  expect_false(isTRUE(fx$fit$use$rr_B))
  expect_error(suppressMessages(suppressWarnings(
    confint(
      fx$fit,
      parm = "rho:unit_obs:1,2",
      method = "profile"
    )
  )), class = "gllvmTMB_nonlinear_profile_withdrawn")
})

## ============================================================================
##  Return-shape invariants (cross-token)
## ============================================================================

test_that("All derived-quantity tokens return numeric matrices with 2 columns", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci_icc <- suppressMessages(confint(fx$fit, parm = "icc", method = "wald"))
  ci_com <- suppressMessages(confint(fx$fit, parm = "communality:unit"))
  ci_rho <- suppressMessages(confint(
    fx$fit,
    parm = "rho:unit:1,2",
    method = "fisher-z"
  ))
  expect_true(is.matrix(ci_icc) && is.numeric(ci_icc) && ncol(ci_icc) == 2L)
  expect_true(is.matrix(ci_com) && is.numeric(ci_com) && ncol(ci_com) == 2L)
  expect_true(is.matrix(ci_rho) && is.numeric(ci_rho) && ncol(ci_rho) == 2L)
})

test_that("Column names follow '<lo>%' / '<hi>%' convention with custom level", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ci80 <- suppressMessages(
    confint(fx$fit, parm = "icc:trait_1", level = 0.80, method = "wald")
  )
  ## 80% interval -> "10.0 %" and "90.0 %"
  expect_equal(colnames(ci80), c("10.0 %", "90.0 %"))
})

test_that("Tier alias 'B' is accepted for communality and rho", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  fx <- build_derived_fixture()
  ## Legacy alias path. The parser accepts "B" as a tier; downstream
  ## `.normalise_level()` may emit a deprecation warning (suppressed
  ## here).
  ci_com <- suppressWarnings(suppressMessages(
    confint(fx$fit, parm = "communality:B")
  ))
  expect_true(is.matrix(ci_com))
  expect_equal(nrow(ci_com), fx$T)

  ci_rho <- suppressWarnings(suppressMessages(
    confint(fx$fit, parm = "rho:B:1,2", method = "fisher-z")
  ))
  expect_true(is.matrix(ci_rho))
  expect_equal(nrow(ci_rho), 1L)
})
