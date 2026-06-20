## Tests for block_V() and fit_site_meta(V = ...) -- block-diagonal
## known-V support for multivariate meta-regression with within-study
## sampling correlation.
## Note: fit_site_meta() is deprecated as of 0.1.1. These tests verify that
## the backward-compatible interface still works; calls are wrapped in
## suppressWarnings() to silence the deprecation notice.

test_that("block_V with rho_within = 0 equals diag(sampling_var)", {
  set.seed(1)
  study <- factor(rep(c("s1", "s2", "s3"), each = 2))
  var   <- c(0.04, 0.05, 0.06, 0.04, 0.05, 0.07)
  V0  <- block_V(study, var, rho_within = 0)
  expect_equal(V0, diag(var), tolerance = 1e-12)
})

test_that("block_V with positive rho creates within-study off-diagonals", {
  study <- factor(rep(c("s1", "s2"), each = 2))
  var   <- c(0.04, 0.04, 0.09, 0.09)
  V <- block_V(study, var, rho_within = 0.5)
  ## Within s1: off-diag = 0.5 * sqrt(0.04 * 0.04) = 0.5 * 0.04 = 0.02
  expect_equal(V[1, 2], 0.02, tolerance = 1e-12)
  expect_equal(V[2, 1], 0.02, tolerance = 1e-12)
  ## Within s2: off-diag = 0.5 * sqrt(0.09 * 0.09) = 0.045
  expect_equal(V[3, 4], 0.045, tolerance = 1e-12)
  ## Across studies: 0
  expect_equal(V[1, 3], 0)
  expect_equal(V[2, 4], 0)
})

test_that("block_V is symmetric and positive-definite", {
  set.seed(2)
  study <- factor(sample(paste0("s", 1:5), 20, replace = TRUE))
  var   <- runif(20, 0.01, 0.1)
  V <- block_V(study, var, rho_within = 0.4)
  expect_equal(V, t(V), tolerance = 1e-12)
  expect_true(all(eigen(V, symmetric = TRUE, only.values = TRUE)$values > 0))
})

test_that("block_V accepts per-study rho_within named vector", {
  study <- factor(rep(c("s1", "s2"), each = 2))
  var   <- c(0.04, 0.04, 0.09, 0.09)
  V <- block_V(study, var, rho_within = c(s1 = 0.2, s2 = 0.8))
  expect_equal(V[1, 2], 0.2 * 0.04, tolerance = 1e-12)
  expect_equal(V[3, 4], 0.8 * 0.09, tolerance = 1e-12)
})

test_that("block_V errors on length mismatch", {
  study <- factor(c("a", "a", "b"))
  expect_error(block_V(study, c(0.1, 0.2)), "must equal")
})

test_that("block_V errors on negative sampling_var", {
  study <- factor(c("a", "b"))
  expect_error(block_V(study, c(0.1, -0.05)), "non-negative")
})

test_that("block_V errors on rho_within out of (-1, 1)", {
  study <- factor(c("a", "b"))
  expect_error(block_V(study, c(0.1, 0.1), rho_within = 1.0), "strictly in")
  expect_error(block_V(study, c(0.1, 0.1), rho_within = -1.0), "strictly in")
})

test_that("block_V errors on missing study in named rho_within", {
  study <- factor(c("a", "a", "b", "b"))
  expect_error(
    block_V(study, c(0.1, 0.1, 0.2, 0.2), rho_within = c(a = 0.5)),
    "Missing rho_within entries"
  )
})

## fit_site_meta() / fit_trait_stage1() were dropped in 0.2.0 (see
## R/two-stage.R header). The tests below were retired with them; users
## now call gllvmTMB() directly with phylo_*/meta_V() keywords.

## Single-V glmmTMB::equalto() log-likelihood comparator (FG-14 / MET-01
## evidence). The phylo propto() / known-V equalto() comparators in
## test-stage3-propto-equalto.R cross-validate the phylogenetic and
## RE-block paths; they do NOT exercise the single-V meta_V(V = V)
## additive-sampling-error path. This cell closes the named comparator
## gap for that path only -- it adds test breadth, not a promotion of
## any validation-debt row, and is NOT a claim of full Gaussian meta
## recovery (that remains the maintainer's call).
##
## Equivalence: gllvmTMB's meta_V(V = V, type = "exact") adds a fixed
## per-observation latent draw e_eq ~ MVN(0, V) to the linear predictor
## while still estimating a residual sigma_eps. glmmTMB's
## equalto(0 + obs | grp, V) fixes a single-group observation-level RE
## covariance to the same known V alongside its own residual variance.
## On identical data the two marginal Gaussian likelihoods coincide, so
## the maximised log-likelihoods must agree.
test_that("single-V meta_V(V = V) matches glmmTMB::equalto() logLik (FG-14/MET-01)", {
  testthat::skip_if_not_installed("glmmTMB")

  set.seed(909)
  n_eff <- 40
  n_trait <- 3
  df <- expand.grid(
    site  = factor(seq_len(n_eff)),
    trait = factor(paste0("t", seq_len(n_trait)))
  )
  df$value <- rnorm(nrow(df), sd = 0.5)
  ## Per-row known sampling variance (single-V, no within-study
  ## correlation): V is diagonal.
  df$sampling_var <- runif(nrow(df), min = 0.02, max = 0.08)
  df$obs <- factor(seq_len(nrow(df)))
  df$grp <- factor(1)
  V <- diag(df$sampling_var)

  fit_g <- gllvmTMB(
    value ~ 0 + trait + meta_V(V = V, type = "exact"),
    data = df, trait = "trait", unit = "site", known_V = V
  )
  expect_s3_class(fit_g, "gllvmTMB_multi")
  expect_equal(fit_g$opt$convergence, 0L)
  ll_g <- -fit_g$opt$objective

  fit_t <- suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + equalto(0 + obs | grp, V),
    data = df, REML = FALSE
  ))
  ll_t <- as.numeric(stats::logLik(fit_t))
  testthat::skip_if(is.na(ll_t),
                    "glmmTMB hit non-PD Hessian on this dataset")

  ## Non-vacuous: both sides actually carry the known-V structure.
  expect_true(isTRUE(fit_g$use$equalto))
  expect_equal(ll_g, ll_t, tolerance = 1e-4)
})
