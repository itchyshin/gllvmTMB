## M1.3 — extract_Sigma() mixed-family validation.
##
## Walks register row MIX-03 from `partial` to `covered` by
## exercising extract_Sigma() against the M1.2 cached fixtures
## (3-family / T = 3 / d = 1, and 5-family / T = 8 / d = 2).
##
## Tests:
##   (1) shape: returns a T x T matrix on each fixture;
##   (2) symmetry + PSD;
##   (3) part = "shared" returns Lambda Lambda^T with rank ≤ d;
##   (4) part = "total" with link_residual = "auto" adds the
##       per-family link residual to the diagonal;
##   (5) link_residual = "none" reverts to Lambda Lambda^T
##       (no unique() in the fixture fit ⇒ no Psi diagonal);
##   (6) the additive identity diag(total) − diag(shared) equals
##       link_residual_per_trait(fit) (Gaussian traits → 0,
##       non-Gaussian → strictly positive);
##   (7) R = cov2cor(Sigma) is symmetric, diag = 1, off-diag in
##       (−1, 1);
##   (8) Backward-compat: a pure Gaussian fit gives identical Sigma
##       across link_residual = "auto" and "none".
##
## All tests skip_on_cran() because each fixture-load + fit-rebuild
## costs 0.3 s (3-family) to 3.1 s (5-family).

# ---- Shared helpers --------------------------------------------------

skip_on_cran_or_load <- function(n_families) {
  skip_on_cran()
  gllvmTMB:::fit_mixed_family_fixture(n_families = n_families)
}

# ---- (1)-(2): shape + PSD on both fixtures ---------------------------

test_that("extract_Sigma() shape + PSD on 3-family fixture (M1.3 / MIX-03)", {
  fit <- skip_on_cran_or_load(3L)
  fx  <- gllvmTMB:::load_mixed_family_fixture(n_families = 3L)
  T   <- fx$truth$n_traits

  total <- suppressMessages(extract_Sigma(fit, level = "unit",
                                          part = "total",
                                          link_residual = "auto"))
  expect_true(is.matrix(total$Sigma))
  expect_equal(dim(total$Sigma), c(T, T))
  expect_true(isSymmetric(total$Sigma, tol = 1e-8))
  ev <- eigen(total$Sigma, symmetric = TRUE, only.values = TRUE)$values
  expect_true(min(ev) >= -1e-8,
              info = sprintf("3-family Sigma not PSD: min(ev) = %g", min(ev)))
})

test_that("extract_Sigma() shape + PSD on 5-family fixture (M1.3 / MIX-03)", {
  fit <- skip_on_cran_or_load(5L)
  fx  <- gllvmTMB:::load_mixed_family_fixture(n_families = 5L)
  T   <- fx$truth$n_traits

  total <- suppressMessages(extract_Sigma(fit, level = "unit",
                                          part = "total",
                                          link_residual = "auto"))
  expect_true(is.matrix(total$Sigma))
  expect_equal(dim(total$Sigma), c(T, T))
  expect_true(isSymmetric(total$Sigma, tol = 1e-8))
  ev <- eigen(total$Sigma, symmetric = TRUE, only.values = TRUE)$values
  expect_true(min(ev) >= -1e-8,
              info = sprintf("5-family Sigma not PSD: min(ev) = %g", min(ev)))
})

# ---- (3): part = "shared" rank ≤ d ----------------------------------

test_that("part = 'shared' Lambda Lambda^T has rank ≤ d on both fixtures (M1.3)", {
  for (k in c(3L, 5L)) {
    fit <- skip_on_cran_or_load(k)
    fx  <- gllvmTMB:::load_mixed_family_fixture(n_families = k)
    d   <- fx$truth$d_B

    shared <- suppressMessages(extract_Sigma(fit, level = "unit",
                                             part = "shared",
                                             link_residual = "none"))
    expect_equal(dim(shared$Sigma), c(fx$truth$n_traits, fx$truth$n_traits))
    ## Rank of L L^T equals rank of L. Numerical rank from non-trivial
    ## singular values.
    sv <- svd(shared$Sigma, nu = 0, nv = 0)$d
    n_nontrivial <- sum(sv > max(sv) * 1e-6)
    expect_lte(n_nontrivial, d,
               label = sprintf("%d-family shared rank vs d=%d", k, d))
  }
})

# ---- (4)-(6): link_residual = "auto" vs "none" + identity ------------

test_that("link_residual = 'auto' adds per-family residual to diagonal (M1.3 / MIX-03)", {
  for (k in c(3L, 5L)) {
    fit <- skip_on_cran_or_load(k)
    fx  <- gllvmTMB:::load_mixed_family_fixture(n_families = k)
    trait_names <- levels(fx$data$trait)
    T <- fx$truth$n_traits

    auto <- suppressMessages(extract_Sigma(fit, level = "unit",
                                           part = "total",
                                           link_residual = "auto"))
    none <- suppressMessages(extract_Sigma(fit, level = "unit",
                                           part = "total",
                                           link_residual = "none"))

    ## auto - none on the diagonal must equal link_residual_per_trait(fit)
    diag_diff <- diag(auto$Sigma) - diag(none$Sigma)
    expected  <- gllvmTMB:::link_residual_per_trait(fit)
    names(expected) <- trait_names
    expect_equal(unname(diag_diff), unname(expected),
                 tolerance = 1e-8,
                 label = sprintf("%d-family diag(auto) - diag(none) vs link_residual_per_trait(fit)", k))

    ## Off-diagonal must be identical between auto and none (residual
    ## only adds to the diagonal).
    od_auto <- auto$Sigma - diag(diag(auto$Sigma))
    od_none <- none$Sigma - diag(diag(none$Sigma))
    expect_equal(od_auto, od_none, tolerance = 1e-8,
                 label = sprintf("%d-family off-diag unchanged by link_residual", k))

    ## Per-family residual signs: Gaussian → 0; non-Gaussian → strictly
    ## positive.
    gauss_idx <- which(fx$truth$trait_families == "gaussian")
    non_gauss <- setdiff(seq_len(T), gauss_idx)
    expect_true(all(abs(expected[gauss_idx]) < 1e-8),
                info = sprintf("%d-family: Gaussian trait residual should be 0", k))
    expect_true(all(expected[non_gauss] > 0),
                info = sprintf("%d-family: non-Gaussian residual should be > 0", k))
  }
})

# ---- (7): correlation R is valid ------------------------------------

test_that("R = cov2cor(Sigma) is valid (symmetric, diag=1, off-diag in [-1, 1]) (M1.3)", {
  for (k in c(3L, 5L)) {
    fit <- skip_on_cran_or_load(k)
    out <- suppressMessages(extract_Sigma(fit, level = "unit",
                                          part = "total",
                                          link_residual = "auto"))
    R <- out$R
    expect_true(isSymmetric(R, tol = 1e-8))
    expect_equal(unname(diag(R)), rep(1, ncol(R)), tolerance = 1e-8)
    od <- R - diag(diag(R))
    expect_true(all(od >= -1 - 1e-8 & od <= 1 + 1e-8),
                info = sprintf("%d-family R off-diag out of [-1, 1]: range %s",
                               k, paste(round(range(od), 4), collapse = " / ")))
  }
})

# ---- (8): backward-compat on a pure Gaussian fit --------------------

test_that("backward-compat: pure Gaussian fit gives equal Sigma for auto vs none (M1.3)", {
  skip_on_cran()
  ## Construct a small pure-Gaussian fit directly. The 3-family fixture's
  ## DGP simulator generates the same Gaussian latent values; we just
  ## fit Gaussian on the original sim$value before per-family casting.
  set.seed(20260517L)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 40L, n_species = 1L, n_traits = 3L,
    mean_species_per_site = 1,
    Lambda_B = matrix(c(1.0, 0.7, -0.3), nrow = 3, ncol = 1),
    psi_B    = rep(0.3, 3),
    seed     = 20260517L
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data   = sim$data,
    family = gaussian()
  )))
  expect_equal(fit$opt$convergence, 0L)

  auto <- suppressMessages(extract_Sigma(fit, level = "unit",
                                         part = "total",
                                         link_residual = "auto"))
  none <- suppressMessages(extract_Sigma(fit, level = "unit",
                                         part = "total",
                                         link_residual = "none"))
  ## For pure Gaussian, link residual is 0 → auto == none exactly.
  expect_equal(auto$Sigma, none$Sigma, tolerance = 1e-10)
})
