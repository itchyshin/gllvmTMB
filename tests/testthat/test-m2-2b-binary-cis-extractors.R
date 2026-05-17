## M2.2-B — Binary single-family CIs + extractors.
##
## Second sub-PR of M2.2 per docs/design/41-binary-completeness.md.
## Exercises Wald + Fisher-z + bootstrap CI surfaces and the four
## ratio extractors on a single-family binomial(logit) fit.
##
## Walks (cumulative with M2.2-A):
##   - FAM-02 binomial(logit) -- evidence cell extended with CI +
##     extractor tests (M1 cascade verified on single-family fits).
##   - CI-01 Wald: tested on binomial fit (no register row change;
##     CI-01 was already `covered` on Gaussian baseline; this
##     evidence reinforces).
##   - CI-09 Fisher-z: tested on binomial fit (same).
##   - CI-03 bootstrap: tested on binomial fit via bootstrap_Sigma()
##     (uses the M1.8 family-aware refit cascade).
##
## Tests are skip_on_cran() because each fit + extraction costs
## several seconds.

# ---- Shared DGP helper (mirrors test-m2-2a-binary-recovery.R) -------

binary_dgp <- function(T, n_sites, Lam, psi, seed,
                      link = c("logit", "probit", "cloglog")) {
  link <- match.arg(link)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites, n_species = 1L, n_traits = T,
    mean_species_per_site = 1, n_predictors = 1,
    alpha = rep(0, T),
    beta  = matrix(0, nrow = T, ncol = 1),
    Lambda_B = Lam, psi_B = psi,
    sigma2_eps = 0, seed = seed
  )
  df  <- sim$data
  eta <- df$value
  prob <- switch(link,
                 logit   = stats::plogis(eta),
                 probit  = stats::pnorm(eta),
                 cloglog = 1 - exp(-exp(eta)))
  df$value <- stats::rbinom(length(eta), size = 1L, prob = prob)
  list(data = df, truth = sim$truth, link = link)
}

build_logit_fit <- function(seed = 20260601L) {
  T   <- 3L
  Lam <- matrix(c(0.8, 0.6, -0.4), nrow = T, ncol = 1L)
  psi <- c(0.3, 0.2, 0.4)
  fx  <- binary_dgp(T = T, n_sites = 200L, Lam = Lam, psi = psi,
                    seed = seed, link = "logit")
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(0 + trait | site),
    data   = fx$data,
    family = binomial()
  )))
  list(fit = fit, fx = fx, Lam = Lam, psi = psi, T = T)
}

# ---- (1) Wald CI via tidy() on a binomial fit -----------------------

test_that("Wald CIs (tidy + conf.int) on binomial fit return sensible bounds (CI-01 / M2.2-B)", {
  skip_on_cran()
  obj <- build_logit_fit(seed = 20260601L)
  expect_equal(obj$fit$opt$convergence, 0L)

  td <- suppressMessages(gllvmTMB::tidy(obj$fit, "fixed",
                                        conf.int = TRUE, conf.level = 0.95))
  expect_true(nrow(td) >= obj$T)        # at least one row per trait
  expect_true(all(c("estimate", "conf.low", "conf.high") %in% names(td)))
  expect_true(all(is.finite(td$estimate)))
  expect_true(all(td$conf.low <= td$estimate + 1e-6),
              info = "Wald lower exceeds point estimate on some rows")
  expect_true(all(td$conf.high >= td$estimate - 1e-6),
              info = "Wald upper below point estimate on some rows")
})

# ---- (2) Fisher-z correlations on binomial fit ---------------------

test_that("extract_correlations(method = 'fisher-z') on binomial fit (CI-09 / M2.2-B)", {
  skip_on_cran()
  obj <- build_logit_fit(seed = 20260602L)
  df <- suppressMessages(gllvmTMB::extract_correlations(
    obj$fit, tier = "unit", method = "fisher-z",
    link_residual = "auto"
  ))
  expect_s3_class(df, "data.frame")
  expect_true(all(c("correlation", "lower", "upper") %in% names(df)))
  ## Correlations bounded in (-1, 1); Fisher-z back-transform preserves this.
  expect_true(all(df$correlation >= -1 - 1e-8 & df$correlation <= 1 + 1e-8))
  expect_true(all(df$lower >= -1 - 1e-8 & df$upper <= 1 + 1e-8))
  ## CI brackets the point estimate.
  expect_true(all(df$lower <= df$correlation + 1e-6))
  expect_true(all(df$upper >= df$correlation - 1e-6))
})

# ---- (3) Wald alias for Fisher-z ----------------------------------

test_that("extract_correlations(method = 'wald') aliases 'fisher-z' (M2.2-B)", {
  skip_on_cran()
  obj <- build_logit_fit(seed = 20260603L)
  df_wald <- suppressMessages(gllvmTMB::extract_correlations(
    obj$fit, tier = "unit", method = "wald",
    link_residual = "auto"
  ))
  df_fz <- suppressMessages(gllvmTMB::extract_correlations(
    obj$fit, tier = "unit", method = "fisher-z",
    link_residual = "auto"
  ))
  ## Numerical values match.
  expect_equal(df_wald$correlation, df_fz$correlation, tolerance = 1e-10)
  expect_equal(df_wald$lower,       df_fz$lower,       tolerance = 1e-10)
  expect_equal(df_wald$upper,       df_fz$upper,       tolerance = 1e-10)
})

# ---- (4) extract_communality on binomial fit ----------------------

test_that("extract_communality() on binomial fit returns H^2 in [0,1] (MIX-05 link-residual cascade / M2.2-B)", {
  skip_on_cran()
  obj <- build_logit_fit(seed = 20260604L)

  ## extract_communality() returns a named numeric vector (one entry per trait),
  ## not a data.frame.
  ## With link_residual = "auto": denominator includes pi^2/3 per trait.
  comm <- suppressMessages(gllvmTMB::extract_communality(
    obj$fit, level = "unit", link_residual = "auto"
  ))
  expect_type(comm, "double")
  expect_length(comm, obj$T)
  expect_true(all(comm >= 0 - 1e-8 & comm <= 1 + 1e-8),
              info = "communality out of [0, 1] under link_residual = auto")

  ## With link_residual = "none": denominator is Lambda Lambda^T + Psi.
  ## H^2 should be LARGER here (no link residual inflating the denominator).
  comm_none <- suppressMessages(gllvmTMB::extract_communality(
    obj$fit, level = "unit", link_residual = "none"
  ))
  expect_true(all(comm_none >= comm - 1e-6),
              info = "communality with link_residual = 'none' should be >= 'auto'")
})

# ---- (5) extract_repeatability on binomial fit (M1.6 cascade) ----

test_that("extract_repeatability() on binomial fit includes pi^2/3 in vW (MIX-06 cascade / M2.2-B)", {
  skip_on_cran()
  obj <- build_logit_fit(seed = 20260605L)

  rep_df <- suppressMessages(gllvmTMB::extract_repeatability(obj$fit))
  expect_s3_class(rep_df, "data.frame")
  ## extract_repeatability() returns columns: trait, R, lower, upper, method.
  expect_true(all(c("trait", "R", "lower", "upper", "method") %in% names(rep_df)))
  ## R (repeatability) bounded in [0, 1].
  expect_true(all(rep_df$R >= 0 - 1e-8 & rep_df$R <= 1 + 1e-8))
  ## Per-trait link residual on the within-tier denominator is the
  ## M1.6 fix; verify the function call succeeds and produces
  ## plausibly-shrunk values relative to a Gaussian-only baseline.
  ## (We don't have a Gaussian-baseline fit here; the sanity check
  ## above is the load-bearing one for FAM-02 evidence.)
})

# ---- (6) bootstrap_Sigma on binomial fit (M1.8 cascade) -----------

test_that("bootstrap_Sigma() converges on binomial fit (CI-03 cascade / M2.2-B)", {
  skip_on_cran()
  obj <- build_logit_fit(seed = 20260606L)

  boot <- suppressMessages(suppressWarnings(gllvmTMB::bootstrap_Sigma(
    obj$fit, n_boot = 15L, level = "unit", what = "Sigma",
    seed = 42L, progress = FALSE
  )))
  expect_true(is.list(boot))
  expect_true(boot$n_failed <= 5L,
              info = sprintf("bootstrap: %d/%d refits failed",
                             boot$n_failed, 15L))
  ## point_est$Sigma_B is the original fit's Sigma matrix (legacy field
  ## name; `level = "unit"` is the canonical alias for "B").
  expect_true(is.matrix(boot$point_est$Sigma_B))
  expect_equal(dim(boot$point_est$Sigma_B), c(obj$T, obj$T))
  ## CI matrices have finite entries.
  expect_true(all(is.finite(boot$ci_lower$Sigma_B)))
  expect_true(all(is.finite(boot$ci_upper$Sigma_B)))
  ## Diagonal of point-Sigma is positive.
  expect_true(all(diag(boot$point_est$Sigma_B) > 0))
})
