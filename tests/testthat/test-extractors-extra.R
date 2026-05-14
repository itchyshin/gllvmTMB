# Additional coverage for the biological-summary extractors
# (extract_Sigma_B, extract_Sigma_W, extract_ICC_site,
#  extract_communality, extract_ordination) and the gllvm-style
# accessors (getLoadings, getLV, getResidualCov, getResidualCor).
#
# The existing test-extractors.R already covers happy-path shapes and
# correlation-on-diagonal checks. This file adds:
#   - clean degradation when the relevant covstruct isn't in the fit
#   - rotation invariance (orthogonal rotation preserves Sigma_B)
#   - error on non-gllvmTMB_multi input
#   - getResidualCov / getResidualCor parity with extract_Sigma_*

# ---- helper: small fit for shape tests ------------------------------------

make_small_rrB_fit <- function(seed = 1, n_sites = 25, n_species = 6,
                               n_traits = 3, d = 2) {
  set.seed(seed)
  Lam <- matrix(runif(n_traits * d, -0.6, 0.6), n_traits, d)
  sim <- simulate_site_trait(
    n_sites = n_sites, n_species = n_species, n_traits = n_traits,
    mean_species_per_site = 3, Lambda_B = Lam,
    psi_B = rep(0.3, n_traits), seed = seed
  )
  fmla <- stats::as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | site, d = %d) + unique(0 + trait | site)",
    d
  ))
  suppressMessages(suppressWarnings(gllvmTMB(fmla, data = sim$data)))
}

make_diag_only_fit <- function(seed = 2) {
  sim <- simulate_site_trait(
    n_sites = 25, n_species = 6, n_traits = 3, mean_species_per_site = 3,
    psi_B = c(0.3, 0.3, 0.3), seed = seed
  )
  gllvmTMB(value ~ 0 + trait + unique(0 + trait | site), data = sim$data)
}

# ---- error on non-gllvmTMB_multi input -----------------------------------

test_that("extract_Sigma_B(): non-multi fit errors", {
  expect_error(extract_Sigma_B("not-a-fit"), regexp = "gllvmTMB_multi")
  expect_error(extract_Sigma_B(42), regexp = "gllvmTMB_multi")
})

test_that("extract_Sigma_W(): non-multi fit errors", {
  expect_error(extract_Sigma_W(list()), regexp = "gllvmTMB_multi")
})

# ---- clean degradation when covstruct absent -----------------------------

test_that("extract_Sigma_B(): NULL when neither rr_B nor diag_B is in the fit", {
  ## A fit with only diag_W: no between-site covstruct
  sim <- simulate_site_trait(n_sites = 20, n_species = 5, n_traits = 3,
                             mean_species_per_site = 3,
                             psi_W = rep(0.3, 3), seed = 9)
  fit <- gllvmTMB(value ~ 0 + trait + unique(0 + trait | site_species),
                  data = sim$data)
  expect_null(extract_Sigma_B(fit))
})

test_that("extract_Sigma_W(): NULL when neither rr_W nor diag_W is in the fit", {
  fit <- make_diag_only_fit()
  expect_null(extract_Sigma_W(fit))
})

test_that("extract_ICC_site(): NULL when only one of B / W is present", {
  fit <- make_diag_only_fit()           # only diag_B
  expect_null(extract_ICC_site(fit))
})

test_that("extract_communality(): NULL when level missing in fit", {
  fit <- make_diag_only_fit()           # no rr_B or rr_W
  expect_null(extract_communality(fit, "B"))
  expect_null(extract_communality(fit, "W"))
})

test_that("extract_ordination(): NULL when level missing in fit", {
  fit <- make_diag_only_fit()
  expect_null(extract_ordination(fit, "B"))
  expect_null(extract_ordination(fit, "W"))
})

# ---- diag_B alone produces a Sigma_B with zero off-diagonals -------------

test_that("extract_Sigma_B(): diag_B alone yields a diagonal Sigma_B", {
  fit <- make_diag_only_fit()
  out <- extract_Sigma_B(fit)
  expect_named(out, c("Sigma_B", "R_B"))
  ## Off-diagonal elements should be exactly zero
  od <- out$Sigma_B
  diag(od) <- 0
  expect_equal(sum(abs(od)), 0)
  ## Diagonal of correlation matrix should be 1
  expect_equal(unname(diag(out$R_B)), rep(1, fit$n_traits))
})

# ---- rotation invariance: Sigma_B = Lambda Lambda' ---------------------

test_that("extract_Sigma_B() is rotation-invariant (varimax leaves Sigma_B unchanged)", {
  fit <- make_small_rrB_fit(seed = 7, d = 2)
  before <- extract_Sigma_B(fit)$Sigma_B
  rt <- rotate_loadings(fit, "B", method = "varimax")
  ## Lambda Lambda' is invariant under orthogonal rotation
  Sigma_rot <- rt$Lambda %*% t(rt$Lambda)
  ## Add the diag_B contribution explicitly to mirror Sigma_B
  Sigma_rot_full <- Sigma_rot + diag(as.numeric(fit$report$sd_B)^2)
  ## extract_Sigma_B() now returns a named matrix; drop dimnames before equality
  expect_equal(unname(Sigma_rot_full), unname(before), tolerance = 1e-8)
})

# ---- ICC_site bounds -----------------------------------------------------

test_that("extract_ICC_site(): values are named by trait levels", {
  ## Need a fit with both B and W components.
  set.seed(3)
  L_B <- matrix(c(0.8, 0.3, -0.2), 3, 1)
  sim <- simulate_site_trait(
    n_sites = 25, n_species = 6, n_traits = 3, mean_species_per_site = 3,
    Lambda_B = L_B, psi_B = c(0.3, 0.3, 0.3),
    Lambda_W = matrix(c(0.5, 0.2, 0.0), 3, 1), psi_W = c(0.3, 0.3, 0.3),
    seed = 3
  )
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 1) + unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) + unique(0 + trait | site_species),
    data = sim$data
  ))
  icc <- extract_ICC_site(fit)
  expect_length(icc, 3L)
  expect_equal(names(icc), levels(sim$data$trait))
})

# ---- communality: matches LL'/Sigma at level B ---------------------------

test_that("extract_communality('B') equals diag(LL') / diag(Sigma_B)", {
  fit <- make_small_rrB_fit(seed = 11, d = 2)
  comm <- extract_communality(fit, "B")
  ## Recompute manually
  L  <- fit$report$Lambda_B
  LL <- L %*% t(L)
  S  <- extract_Sigma_B(fit)$Sigma_B
  expect_equal(unname(comm), as.numeric(diag(LL) / diag(S)),
               tolerance = 1e-10)
})

# ---- extract_ordination: shapes ------------------------------------------

test_that("extract_ordination('B'): scores are n_sites x d_B", {
  fit <- make_small_rrB_fit(seed = 5, d = 2)
  ord <- extract_ordination(fit, "B")
  expect_named(ord, c("scores", "loadings", "row_id"))
  expect_equal(dim(ord$scores), c(fit$n_sites, fit$d_B))
  expect_equal(dim(ord$loadings), c(fit$n_traits, fit$d_B))
  expect_length(ord$row_id, fit$n_sites)
})

# ---- getResidualCov / getResidualCor ------------------------------------

test_that("getResidualCov(level='B') matches extract_Sigma_B()$Sigma_B", {
  fit <- make_small_rrB_fit(seed = 13, d = 2)
  expect_equal(getResidualCov(fit, "B"),
               extract_Sigma_B(fit)$Sigma_B)
})

test_that("getResidualCor(level='B') matches extract_Sigma_B()$R_B", {
  fit <- make_small_rrB_fit(seed = 17, d = 2)
  expect_equal(getResidualCor(fit, "B"),
               extract_Sigma_B(fit)$R_B)
})

test_that("getResidualCov / Cor return NULL when level is empty in fit", {
  fit <- make_diag_only_fit()
  ## diag_B is active so B is non-NULL; W has nothing
  expect_null(getResidualCov(fit, "W"))
  expect_null(getResidualCor(fit, "W"))
})

# ---- getLoadings / getLV: shapes & rotate args ---------------------------

test_that("getLoadings(level='B'): returns NULL when no rr_B in fit", {
  fit <- make_diag_only_fit()
  expect_null(getLoadings(fit, "B"))
  expect_null(getLoadings(fit, "W"))
})

test_that("getLoadings(level='B', rotate='varimax'): rotated matrix has same shape as raw", {
  fit <- make_small_rrB_fit(seed = 19, d = 2)
  raw <- suppressMessages(getLoadings(fit, "B", "none"))
  vmx <- getLoadings(fit, "B", "varimax")
  expect_equal(dim(raw), dim(vmx))
  ## Varimax rotation should not preserve raw values exactly (the columns
  ## actually rotate). Check: at least one entry differs.
  expect_false(isTRUE(all.equal(as.numeric(raw), as.numeric(vmx))))
})

test_that("getLoadings(rotate='promax'): runs and returns matrix", {
  fit <- make_small_rrB_fit(seed = 21, d = 2)
  prx <- getLoadings(fit, "B", "promax")
  expect_true(is.matrix(prx))
  expect_equal(dim(prx), c(fit$n_traits, fit$d_B))
})

test_that("getLV(level='B'): returns NULL when no rr_B in fit", {
  fit <- make_diag_only_fit()
  expect_null(getLV(fit, "B"))
})

test_that("getLV(level='B'): rows = n_sites, cols = d_B", {
  fit <- make_small_rrB_fit(seed = 23, d = 2)
  z <- getLV(fit, "B")
  expect_equal(nrow(z), fit$n_sites)
  expect_equal(ncol(z), fit$d_B)
})

test_that("getLV(rotate='varimax'): scores rotate by the same T as loadings", {
  fit <- make_small_rrB_fit(seed = 27, d = 2)
  ## Use rotate_loadings to grab T, scores
  rt <- rotate_loadings(fit, "B", "varimax")
  z_rot <- getLV(fit, "B", "varimax")
  expect_equal(z_rot, rt$scores)
})
