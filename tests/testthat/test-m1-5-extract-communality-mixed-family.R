## M1.5 — extract_communality() mixed-family validation.
##
## Walks register row MIX-05 from `partial` to `covered` by exercising
## extract_communality() against the M1.2 fixtures.
##
## extract_communality inherits mixed-family awareness via delegation
## to extract_Sigma (see M1.1 audit). Tests:
##   (1) shape: returns a length-T numeric vector on each fixture;
##   (2) range: all H^2 in [0, 1];
##   (3) link_residual = "auto" SHRINKS H^2 vs "none" on non-Gaussian
##       traits (because the denominator diag(Sigma_total) grows when
##       link_residual is added);
##   (4) Gaussian-trait communality is identical under "auto" and
##       "none" (link residual is 0 for Gaussian).
##
## All tests skip_on_cran() because each fixture-fit costs 0.3-3.1 s.

skip_on_cran_or_load <- function(n_families) {
  skip_on_cran()
  gllvmTMB:::fit_mixed_family_fixture(n_families = n_families)
}

# ---- (1) + (2): shape + range ---------------------------------------

test_that("extract_communality() shape + range on both fixtures (M1.5 / MIX-05)", {
  for (k in c(3L, 5L)) {
    fit <- skip_on_cran_or_load(k)
    fx  <- gllvmTMB:::load_mixed_family_fixture(n_families = k)
    T   <- fx$truth$n_traits

    H2 <- suppressMessages(extract_communality(
      fit, level = "unit", link_residual = "auto"
    ))
    expect_type(H2, "double")
    expect_equal(length(H2), T)
    expect_true(all(H2 >= 0 - 1e-8 & H2 <= 1 + 1e-8),
                info = sprintf("%d-family: H^2 out of [0, 1]; got %s",
                               k, paste(round(H2, 4), collapse = " / ")))
  }
})

# ---- (3): auto shrinks H^2 vs none on non-Gaussian traits ----------

test_that("link_residual = 'auto' shrinks H^2 on non-Gaussian traits (M1.5 / MIX-05)", {
  for (k in c(3L, 5L)) {
    fit <- skip_on_cran_or_load(k)
    fx  <- gllvmTMB:::load_mixed_family_fixture(n_families = k)

    H2_auto <- suppressMessages(extract_communality(
      fit, level = "unit", link_residual = "auto"
    ))
    H2_none <- suppressMessages(extract_communality(
      fit, level = "unit", link_residual = "none"
    ))

    gauss_idx <- which(fx$truth$trait_families == "gaussian")
    non_gauss <- setdiff(seq_along(H2_auto), gauss_idx)

    ## Gaussian traits: H^2_auto == H^2_none (link_residual = 0).
    expect_equal(unname(H2_auto[gauss_idx]), unname(H2_none[gauss_idx]),
                 tolerance = 1e-8,
                 label = sprintf("%d-family: Gaussian H^2 should be invariant to link_residual",
                                 k))

    ## Non-Gaussian traits: H^2_auto < H^2_none (link_residual adds to
    ## denominator → H^2 shrinks).
    if (length(non_gauss) > 0L) {
      diff <- H2_auto[non_gauss] - H2_none[non_gauss]
      expect_true(all(diff <= 1e-8),
                  info = sprintf(
                    "%d-family: non-Gaussian H^2 should NOT increase under link_residual='auto'; diff = %s",
                    k, paste(round(diff, 4), collapse = "/")))
      expect_true(any(diff < -1e-4),
                  info = sprintf(
                    "%d-family: at least one non-Gaussian H^2 should strictly shrink under 'auto'; diff = %s",
                    k, paste(round(diff, 4), collapse = "/")))
    }
  }
})

# ---- (4): partition identity (sanity) -------------------------------

test_that("communality is consistent with extract_Sigma decomposition (M1.5)", {
  for (k in c(3L, 5L)) {
    fit <- skip_on_cran_or_load(k)
    H2 <- suppressMessages(extract_communality(
      fit, level = "unit", link_residual = "auto"
    ))

    shared <- suppressMessages(extract_Sigma(
      fit, level = "unit", part = "shared", link_residual = "none"
    ))
    total  <- suppressMessages(extract_Sigma(
      fit, level = "unit", part = "total", link_residual = "auto"
    ))
    H2_manual <- diag(shared$Sigma) / diag(total$Sigma)

    expect_equal(unname(H2), unname(H2_manual), tolerance = 1e-8,
                 label = sprintf("%d-family: communality vs manual diag(shared)/diag(total)", k))
  }
})
