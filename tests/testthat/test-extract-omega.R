## Tests for extract_Omega(), extract_phylo_signal(), and
## extract_proportions() — the multi-tier PGLLVM convenience layer.

make_BW_fit <- function(seed = 1) {
  set.seed(seed)
  Tn <- 4
  Lambda_B <- matrix(c(1.0, 0.5, -0.4, 0.3, 0.0, 0.8, 0.4, -0.2), Tn, 2)
  Lambda_W <- matrix(c(0.4, 0.2, -0.1, 0.3), Tn, 1)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 50, n_species = 8, n_traits = Tn, mean_species_per_site = 5,
    Lambda_B = Lambda_B, S_B = c(0.20, 0.15, 0.10, 0.25),
    Lambda_W = Lambda_W, S_W = c(0.10, 0.08, 0.05, 0.12),
    beta = matrix(0, Tn, 2), seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site,         d = 2) + unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) + unique(0 + trait | site_species),
    data = s$data
  )))
}

test_that("extract_Omega(tiers = c('B','W')) sums B and W tiers", {
  fit <- make_BW_fit()
  Sigma_B <- suppressMessages(extract_Sigma(fit, "B", "total"))$Sigma
  Sigma_W <- suppressMessages(extract_Sigma(fit, "W", "total"))$Sigma
  out <- suppressMessages(extract_Omega(fit, tiers = c("B", "W")))
  expect_equal(out$Omega, Sigma_B + Sigma_W, tolerance = 1e-10)
  ## Diagonal of correlation matrix is 1
  expect_equal(unname(diag(out$R_Omega)), rep(1, fit$n_traits))
  expect_equal(out$tiers_used, c("B", "W"))
})

test_that("extract_Omega() with auto-detected tiers includes B and W (no phylo here)", {
  fit <- make_BW_fit()
  out <- suppressMessages(extract_Omega(fit))
  ## Auto-detect should include B and W (both have rr+diag)
  expect_true(all(c("B", "W") %in% out$tiers_used))
  expect_false("phy" %in% out$tiers_used)
})

test_that("extract_Omega errors when no covariance tiers are available", {
  ## Construct a fit with no rr/diag at all (shouldn't happen normally,
  ## but test the error path)
  expect_error(
    extract_Omega(structure(list(use = list(), n_traits = 4),
                            class = c("gllvmTMB_multi", "gllvmTMB"))),
    regexp = "No covariance tiers"
  )
})

test_that("extract_proportions() (long format) returns a tidy frame summing to 1 per trait", {
  fit <- make_BW_fit()
  out <- suppressMessages(extract_proportions(fit, format = "long"))
  expect_named(out, c("trait", "component", "variance", "proportion"))
  ## Per-trait proportions sum to 1
  agg <- aggregate(out$proportion, by = list(out$trait), FUN = sum)
  expect_equal(agg$x, rep(1, nlevels(out$trait)), tolerance = 1e-10)
  ## Components include shared/unique at unit and unit_obs (Stage 4 of
  ## design 02 renamed *_B / *_W to *_unit / *_unit_obs).
  comps <- unique(out$component)
  expect_true(all(c("shared_unit", "unique_unit",
                    "shared_unit_obs", "unique_unit_obs") %in% comps))
})

test_that("extract_proportions() (wide format) has one row per trait", {
  fit <- make_BW_fit()
  out <- suppressMessages(extract_proportions(fit, format = "wide"))
  expect_equal(nrow(out), fit$n_traits)
  expect_true("total_variance" %in% names(out))
  ## Per-trait proportions sum to 1 (excluding `trait` and `total_variance`)
  prop_cols <- setdiff(names(out), c("trait", "total_variance"))
  per_trait_sum <- rowSums(out[, prop_cols, drop = FALSE]) /
                   out$total_variance
  expect_equal(unname(per_trait_sum), rep(1, fit$n_traits), tolerance = 1e-10)
})

test_that("extract_phylo_signal() errors when phylo_latent is not in the fit", {
  fit <- make_BW_fit()
  expect_error(
    extract_phylo_signal(fit),
    regexp = "no .*phylo_latent"
  )
})

test_that("extract_proportions() includes link_residual = 'auto' for binomial fits", {
  set.seed(2025)
  n <- 100; Tn <- 3
  Lambda <- matrix(c(0.8, 0.5, -0.3, 0.0, 0.6, 0.4), Tn, 2)
  u <- matrix(rnorm(n * 2), n, 2)
  eta <- u %*% t(Lambda)
  p <- plogis(eta)
  y_bin <- matrix(rbinom(n * Tn, 1, p), n, Tn)
  df <- data.frame(
    individual = factor(rep(seq_len(n), each = Tn)),
    trait      = factor(rep(c("a","b","c"), n), levels = c("a","b","c")),
    value      = as.integer(t(y_bin))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 2),
    data = df, site = "individual", family = binomial(link = "logit")
  )))
  out <- suppressMessages(extract_proportions(fit, link_residual = "auto",
                                               format = "wide"))
  expect_true("link_residual" %in% names(out))
  ## Link residual = pi^2/3 for logit ≈ 3.290 absolute, divided by total
  expect_true(all(out$link_residual > 0))
})
