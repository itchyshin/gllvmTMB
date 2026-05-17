## M1.8 — bootstrap_Sigma mixed-family + simulate.gllvmTMB_multi family-aware draws.
##
## Walks register rows MIX-08 (bootstrap_Sigma per-row family
## preservation in resamples) and MIS-05 (simulate.gllvmTMB_multi
## family-aware redraws) from `partial` to `covered`.
##
## Root cause of the M1.4 bootstrap-correlation rank-1 degeneracy
## (CIs returning ±1): simulate.gllvmTMB_multi applied Gaussian
## noise to ALL rows regardless of per-row family, and
## bootstrap_Sigma's `family <- fit$family` only kept the first
## family of a mixed-family list (per fit-multi.R:174 reassignment
## `family <- family[[1]]`). The M1.8 fix:
##
##   - R/fit-multi.R: preserves the original family argument
##     (list with family_var attribute) as `fit$family_input`;
##     `fit$family` continues to be the first family for downstream
##     linkinv use.
##   - R/bootstrap-sigma.R: refit_one uses fit$family_input when
##     available, falling back to fit$family.
##   - R/methods-gllvmTMB.R: simulate.gllvmTMB_multi calls a new
##     internal `.draw_y_per_family()` that dispatches per-row by
##     family_id (Gaussian / binomial / Poisson / lognormal /
##     Gamma / nbinom2 supported; other families warn once and
##     fall back to Gaussian-on-link-scale).

skip_on_cran_or_load <- function(n_families) {
  skip_on_cran()
  gllvmTMB:::fit_mixed_family_fixture(n_families = n_families)
}

# ---- (1) MIS-05: simulate per-row family-aware draws -----------------

test_that("simulate() returns family-correct values on 3-family fixture (M1.8 / MIS-05)", {
  fit <- skip_on_cran_or_load(3L)
  fx  <- gllvmTMB:::load_mixed_family_fixture(n_families = 3L)
  y_sim <- simulate(fit, nsim = 1L)
  expect_equal(nrow(y_sim), nrow(fx$data))
  v <- y_sim[, 1]

  for (fam in c("gaussian", "binomial", "poisson")) {
    idx <- fx$data$family == fam
    vf <- v[idx]
    if (fam == "binomial") {
      expect_true(all(vf %in% c(0L, 1L)),
                  info = "binomial: all values 0/1")
    } else if (fam == "poisson") {
      expect_true(all(vf == as.integer(vf)),
                  info = "poisson: all values integer")
      expect_true(all(vf >= 0),
                  info = "poisson: all values >= 0")
    } else if (fam == "gaussian") {
      ## continuous — sanity check spread > 0
      expect_true(sd(vf) > 0.1,
                  info = "gaussian: non-degenerate spread")
    }
  }
})

test_that("simulate() returns family-correct values on 5-family fixture (M1.8 / MIS-05)", {
  fit <- skip_on_cran_or_load(5L)
  fx  <- gllvmTMB:::load_mixed_family_fixture(n_families = 5L)
  y_sim <- simulate(fit, nsim = 1L)
  v <- y_sim[, 1]

  for (fam in c("gaussian", "binomial", "poisson", "Gamma", "nbinom2")) {
    idx <- fx$data$family == fam
    vf <- v[idx]
    if (fam == "binomial") {
      expect_true(all(vf %in% c(0L, 1L)))
    } else if (fam == "poisson") {
      expect_true(all(vf == as.integer(vf)) && all(vf >= 0))
    } else if (fam == "Gamma") {
      expect_true(all(vf > 0),
                  info = "Gamma: all values strictly positive")
    } else if (fam == "nbinom2") {
      expect_true(all(vf == as.integer(vf)) && all(vf >= 0),
                  info = "nbinom2: non-negative integer")
    } else if (fam == "gaussian") {
      expect_true(sd(vf) > 0.1)
    }
  }
})

# ---- (2) MIX-08: bootstrap_Sigma preserves per-row family in refits --

test_that("bootstrap_Sigma() converges on mixed-family fit (M1.8 / MIX-08)", {
  fit <- skip_on_cran_or_load(3L)
  boot <- suppressMessages(bootstrap_Sigma(
    fit, n_boot = 15L, level = "B", what = "Sigma",
    seed = 42L, progress = FALSE
  ))
  ## Most refits should succeed (n_failed small relative to n_boot)
  expect_true(boot$n_failed <= 5L,
              info = sprintf("bootstrap: %d/%d refits failed", boot$n_failed, 15))
  ## point_est$Sigma_B is the original fit's Σ
  expect_true(is.matrix(boot$point_est$Sigma_B))
  expect_equal(dim(boot$point_est$Sigma_B), c(3L, 3L))
  ## ci_lower and ci_upper Sigma_B are 3x3 matrices with finite values
  expect_true(all(is.finite(boot$ci_lower$Sigma_B)))
  expect_true(all(is.finite(boot$ci_upper$Sigma_B)))
  ## Diagonal of Sigma is positive
  expect_true(all(diag(boot$point_est$Sigma_B) > 0))
})

# ---- (3) M1.4 fix verification: bootstrap correlations are no longer ±1 -

test_that("extract_correlations(bootstrap) on mixed-family no longer returns degenerate ±1 (M1.8 / M1.4 follow-up)", {
  fit <- skip_on_cran_or_load(3L)
  df <- suppressMessages(extract_correlations(
    fit, tier = "unit", method = "bootstrap",
    nsim = 30L, seed = 42L, link_residual = "auto"
  ))
  expect_equal(nrow(df), 3L)
  ## CI must bracket the point estimate (the bug we're fixing).
  expect_true(all(df$lower <= df$correlation + 1e-6),
              info = sprintf("lower > correlation in some rows; lower=%s, corr=%s",
                             paste(round(df$lower, 3), collapse = "/"),
                             paste(round(df$correlation, 3), collapse = "/")))
  expect_true(all(df$upper >= df$correlation - 1e-6),
              info = "upper < correlation")
  ## CIs should NOT all be degenerate ±1 (the pre-M1.8 symptom).
  not_degenerate <- sum(abs(df$lower) < 0.999 | abs(df$upper) < 0.999)
  expect_gt(not_degenerate, 0,
            label = "at least one CI bound is non-degenerate (not ±1)")
})

# ---- (4) Backward-compat: Gaussian-only simulate still works -----------

test_that("simulate() on pure Gaussian fit is unchanged after M1.8 (backward-compat)", {
  skip_on_cran()
  set.seed(20260517L)
  sim_in <- gllvmTMB::simulate_site_trait(
    n_sites = 30L, n_species = 1L, n_traits = 3L,
    mean_species_per_site = 1, seed = 20260517L
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim_in$data, family = gaussian()
  )))
  expect_equal(fit$opt$convergence, 0L)
  y_sim <- simulate(fit, nsim = 1L)
  ## Pure Gaussian → continuous values everywhere (no integer constraints).
  expect_equal(nrow(y_sim), nrow(sim_in$data))
  v <- y_sim[, 1]
  expect_true(sd(v) > 0.1)
  ## With no mixed families, family_id_vec is all 0 (Gaussian);
  ## .draw_y_per_family produces the same eta + rnorm(sigma_eps) as before.
})

# ---- (5) family_input preservation on the fit object ------------------

test_that("fit$family_input preserves the original family list for mixed-family fits (M1.8)", {
  fit <- skip_on_cran_or_load(3L)
  expect_true(!is.null(fit$family_input))
  expect_true(is.list(fit$family_input))
  expect_equal(length(fit$family_input), 3L)
  expect_equal(attr(fit$family_input, "family_var"), "family")
  ## fit$family stays the first family (gaussian) for backward compat
  ## with downstream linkinv use.
  expect_s3_class(fit$family, "family")
})
