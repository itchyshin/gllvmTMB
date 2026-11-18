## Issue #1119: two boundary-screening FALSE NEGATIVES plus a dead-name row.
##
## 1. `sd_spde_unique` (the spatial `*_unique()` Psi companion,
##    src/gllvmTMB.cpp:2150) was absent from `.gllvmTMB_boundary_flags()`'s
##    intersect list entirely -- a real, non-trivial quantity that could
##    collapse to a degenerate boundary and never be flagged.
## 2. `sd_kernel_diag` (the multi-kernel Psi companion,
##    src/gllvmTMB.cpp:1861) had the identical gap. Empirically it is
##    currently always an all-zero placeholder (the R-level grammar
##    hard-blocks a fitted multi-kernel Psi; R/fit-multi.R:3456-3462), so
##    the fix must filter it the same way `sd_B`/`sd_W` filter their
##    mapped-off placeholders -- otherwise it fires on every 2+-named-kernel
##    fit. Test 2 below pins that non-firing behaviour.
## 3. `check_gllvmTMB()`'s own psi-screening loop used the dead bare name
##    `"sd_spde"` for its `spatial` row (no `REPORT(sd_spde)` exists;
##    src/gllvmTMB.cpp REPORTs `sd_spde_unique`), so it produced zero psi
##    rows for a spatial fixture -- no PASS, no WARN, nothing.

.spde_unique_fixture_1119 <- function(seed = 20260703L) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 55,
    n_species = 1,
    n_traits = 3,
    mean_species_per_site = 1,
    spatial_range = 0.25,
    sigma2_spa = c(0.45, 0.55, 0.35),
    seed = seed
  )
  df <- sim$data
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.08)
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      spatial_latent(0 + trait | site, d = 1, unique = TRUE),
    data = df,
    mesh = mesh,
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )))
}

test_that("#1119 (1): a collapsed sd_spde_unique fires near_zero_sd_spde_unique", {
  skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  fit <- .spde_unique_fixture_1119()

  ## Fixture sanity: sd_spde_unique is REPORTed and genuinely collapsed
  ## relative to its largest sibling (this is not a synthetic near-zero
  ## injection -- it is what this fixture actually fits).
  expect_true("sd_spde_unique" %in% names(fit$report))
  sd_unique <- as.numeric(fit$report$sd_spde_unique)
  expect_true(min(sd_unique) / max(sd_unique) < 1e-3)

  bf <- gllvmTMB:::.gllvmTMB_boundary_flags(fit)
  expect_true("near_zero_sd_spde_unique" %in% bf)
})

test_that("#1119 (2a): a collapsed sd_kernel_diag tier fires near_zero_sd_kernel_diag", {
  ## The R-level multi-kernel grammar currently hard-blocks a fitted
  ## kernel-tier Psi (R/fit-multi.R:3456-3462), so `sd_kernel_diag` cannot
  ## be driven to a real collapsed value through the public fitting API --
  ## see test 2b below for that structural fact pinned on a live fit. This
  ## synthetic object exercises `.gllvmTMB_boundary_flags()` directly the
  ## way it will see a REAL fitted tier once that R-level block is lifted:
  ## a 2-trait x 2-tier `sd_kernel_diag` matrix where tier 1 has
  ## `kernel_has_diag = 1` (fitted, collapsed) and tier 2 has
  ## `kernel_has_diag = 0` (still a placeholder).
  fake_fit <- list(
    report = list(
      sd_kernel_diag = matrix(c(1e-7, 5, 0, 0), nrow = 2L, ncol = 2L)
    ),
    tmb_data = list(kernel_has_diag = c(1L, 0L)),
    use = list()
  )
  bf <- gllvmTMB:::.gllvmTMB_boundary_flags(fake_fit)
  expect_true("near_zero_sd_kernel_diag" %in% bf)
})

test_that("#1119 (2b): a structurally-placeholder sd_kernel_diag does not false-fire", {
  skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  set.seed(31)
  n_unit <- 8L
  n_rep <- 3L
  unit_levels <- paste0("u", seq_len(n_unit))
  A_phy <- matrix(0.25, n_unit, n_unit)
  diag(A_phy) <- 1
  A_non <- matrix(0.10, n_unit, n_unit)
  diag(A_non) <- 1
  rownames(A_phy) <- colnames(A_phy) <- unit_levels
  rownames(A_non) <- colnames(A_non) <- unit_levels
  rows <- expand.grid(
    unit_id = unit_levels,
    rep_id = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  rows$row_id <- factor(seq_len(nrow(rows)))
  rows$unit_id <- factor(rows$unit_id, levels = unit_levels)
  rows$y1 <- stats::rnorm(nrow(rows))
  rows$y2 <- stats::rnorm(nrow(rows))
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2) ~ 1 +
      kernel_latent(unit_id, K = A_phy, d = 1, name = "phy") +
      kernel_latent(unit_id, K = A_non, d = 1, name = "non"),
    data = rows,
    unit = "row_id",
    cluster = "unit_id",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))

  ## Fixture sanity: a 2-named-kernel fit REPORTs sd_kernel_diag, and it is
  ## currently always the all-zero placeholder (kernel_has_diag is
  ## unconditionally 0 for every tier at the R level).
  expect_true("sd_kernel_diag" %in% names(fit$report))
  expect_true(all(as.numeric(fit$report$sd_kernel_diag) == 0))
  expect_true(all(fit$tmb_data$kernel_has_diag == 0L))

  bf <- gllvmTMB:::.gllvmTMB_boundary_flags(fit)
  expect_false("near_zero_sd_kernel_diag" %in% bf)
})

test_that("#1119 (3): check_gllvmTMB()'s spatial psi row is not dead", {
  skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  fit <- .spde_unique_fixture_1119()

  chk <- check_gllvmTMB(fit)
  psi_spatial <- chk[chk$component == "near_zero_psi_spatial", , drop = FALSE]
  expect_equal(nrow(psi_spatial), 1L)
  expect_true(psi_spatial$status %in% c("PASS", "WARN"))
})
