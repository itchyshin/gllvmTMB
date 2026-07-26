# getLV(se = TRUE): standard errors for unit-level (and within-unit) latent
# scores.
#
# The hazard this file is built to catch: the z_B (and z_W) random-effect
# block in a gllvmTMB_multi fit's TMB parameter vector is flattened
# column-major from a (d x n) matrix -- i.e. consecutive runs of `d` values
# belong to the SAME unit, not the same axis. A reshape that mixes up
# `nrow` and `ncol` (or otherwise misorders the block) produces a
# same-shaped, plausible-looking matrix of WRONG numbers with no error --
# exactly the silent-misordering class of bug this package has already had
# to fix once. See dev/getlv-score-se-RESULTS.md for the full
# investigation, including the level-name mix-up this suite caught during
# development (the first implementation always read the z_W block,
# regardless of the requested `level`, and every test below failed until
# it was fixed).
#
# The B-tier fixture fit is built once (module scope, not inside
# test_that()) because it is a known-good, positive-definite-Hessian
# configuration already used in test-extractors.R, and rebuilding it for
# every test would be slow for no additional coverage. Nothing below
# mutates it.
#
# The B+W-tier fixture is a heavier two-tier fit whose pdHess has proven
# BLAS/platform-sensitive: a module-scope `stopifnot(isTRUE(pdHess))` on
# this exact configuration passed locally on macOS/ARM but errored (and
# halted the whole file) on ubuntu-latest CI -- see
# dev/getlv-se-ci-fix-RESULTS.md. It is therefore NOT built at module
# scope. Instead, `.build_getlv_se_fit_BW()` is called inside each
# test_that() that actually needs the two-tier structure (the
# level = "unit_obs" / z_W tests below), and the numeric-SE test skip()s
# honestly, with a message naming the cause, when the Hessian is not PD
# on this platform -- rather than erroring the entire file.

.getlv_se_fit_B <- local({
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 80, n_species = 12, n_traits = 4, mean_species_per_site = 6,
    Lambda_B = matrix(
      c(1.0, 0.7, -0.3, 0.5, 0.3, -0.5, 0.8, 0.2),
      nrow = 4, ncol = 2
    ),
    psi_B = c(0.3, 0.3, 0.3, 0.3),
    seed = 2025
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data
  )))
  stopifnot(isTRUE(fit$sd_report$pdHess))
  fit
})

.build_getlv_se_fit_BW <- function() {
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 80, n_species = 12, n_traits = 4, mean_species_per_site = 6,
    Lambda_B = matrix(
      c(1.0, 0.7, -0.3, 0.5, 0.3, -0.5, 0.8, 0.2),
      nrow = 4, ncol = 2
    ),
    psi_B = c(0.3, 0.3, 0.3, 0.3),
    Lambda_W = matrix(c(0.8, 0.4, -0.2, 0.5), nrow = 4, ncol = 1),
    psi_W = c(0.4, 0.4, 0.4, 0.4),
    seed = 2025
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) +
      latent(0 + trait | site_species, d = 1),
    data = sim$data
  )))
}

## ---- shape / dimnames --------------------------------------------------

test_that("getLV(se = TRUE) returns a list with scores + se of matching shape", {
  fit <- .getlv_se_fit_B
  out <- getLV(fit, level = "unit", se = TRUE)
  expect_named(out, c("scores", "se"))
  expect_equal(dim(out$se), dim(out$scores))
  expect_identical(dimnames(out$se), dimnames(out$scores))
  expect_true(all(is.finite(out$se)))
  expect_true(all(out$se > 0))
})

test_that("getLV(se = FALSE) (the default) is unaffected -- bare matrix as before", {
  fit <- .getlv_se_fit_B
  out_default <- getLV(fit, level = "unit")
  out_explicit <- getLV(fit, level = "unit", se = FALSE)
  expect_true(is.matrix(out_default))
  expect_identical(out_default, out_explicit)
})

## ---- independent cross-check: joint-precision inversion -----------------

test_that("getLV(se = TRUE) agrees with an independent joint-precision-inversion route", {
  fit <- .getlv_se_fit_B
  out <- getLV(fit, level = "unit", se = TRUE)

  ## Independent route: recompute sdreport with the FULL joint precision
  ## matrix (fixed + random jointly), invert it, and read the diagonal of
  ## the z_B block directly -- a different linear-algebra path than the
  ## package's `sd_report$diag.cov.random` (which uses TMB's sparse
  ## Cholesky Schur-complement shortcut). Agreement between the two is
  ## evidence the block was found and reshaped correctly, not merely that
  ## the code ran without erroring.
  sd2 <- TMB::sdreport(
    fit$tmb_obj,
    par.fixed = fit$opt$par,
    getJointPrecision = TRUE
  )
  JP <- sd2$jointPrecision
  idx <- which(rownames(JP) == "z_B")
  cov_block <- as.matrix(Matrix::solve(JP))
  se_independent <- sqrt(diag(cov_block)[idx])
  se_independent_mat <- t(matrix(se_independent, nrow = fit$d_B, ncol = fit$n_sites))

  expect_equal(out$se, se_independent_mat, tolerance = 1e-6, ignore_attr = TRUE)
})

## ---- ordering hazard: a misordered reshape must NOT match ----------------

test_that("getLV(se = TRUE) uses the correct (unit-major) reshape, not a swapped one", {
  fit <- .getlv_se_fit_B
  out <- getLV(fit, level = "unit", se = TRUE)

  sd_rep <- fit$sd_report
  idx <- which(names(sd_rep$par.random) == "z_B")
  se_vec <- sqrt(sd_rep$diag.cov.random[idx])
  d <- fit$d_B
  n <- fit$n_sites
  expect_false(d == n)  # otherwise the hazard below would be dimensionally forced to agree

  ## Correct convention (matches extract_ordination()): z_B is stored
  ## column-major as a (d x n) matrix, i.e. consecutive runs of `d` values
  ## belong to the same site. Reshape then transpose to get n x d.
  se_correct <- t(matrix(se_vec, nrow = d, ncol = n))

  ## The hazard: building the (n x d) matrix directly with nrow = n,
  ## ncol = d (i.e. treating the flat vector as if consecutive runs of `n`
  ## values belonged to the same axis, instead of consecutive runs of `d`
  ## belonging to the same site) gives the SAME n x d shape -- so it is
  ## silent at the R level -- but reads entirely different (unit, axis)
  ## pairings from the identical underlying vector.
  se_wrong <- matrix(se_vec, nrow = n, ncol = d)

  expect_equal(dim(se_wrong), dim(se_correct))
  expect_equal(out$se, se_correct, ignore_attr = TRUE)
  ## The wrong reshape must produce a materially different matrix -- if it
  ## didn't, this test would be unable to detect a misordered reshape.
  expect_gt(max(abs(se_correct - se_wrong)), 1e-3)
  expect_false(isTRUE(all.equal(unname(out$se), se_wrong, tolerance = 1e-6)))
})

## ---- rotate / level / control gating -------------------------------------

test_that("getLV(se = TRUE) errors when rotate != 'none'", {
  fit <- .getlv_se_fit_B
  expect_error(
    getLV(fit, level = "unit", rotate = "varimax", se = TRUE),
    class = "gllvmTMB_getLV_se_rotated_unsupported"
  )
})

test_that("getLV(se = TRUE) errors for a predictor-informed latent(..., lv = ~x) fit", {
  set.seed(11)
  n <- 20L
  df <- expand.grid(
    unit = factor(paste0("u", seq_len(n))),
    trait = factor(paste0("t", 1:3))
  )
  df$x <- stats::rnorm(n)[as.integer(df$unit)]
  df$value <- stats::rnorm(nrow(df))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
    data = df, unit = "unit", trait = "trait", family = stats::gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_error(
    getLV(fit, level = "unit", se = TRUE),
    class = "gllvmTMB_getLV_se_lv_predictor_unsupported"
  )
})

test_that("getLV(se = TRUE) errors cleanly when the fit has no sdreport", {
  set.seed(13)
  Lam <- matrix(stats::runif(3 * 2, -0.6, 0.6), 3, 2)
  sim <- simulate_site_trait(
    n_sites = 15, n_species = 5, n_traits = 3, mean_species_per_site = 4,
    Lambda_B = Lam, psi_B = rep(0.3, 3), seed = 13
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_null(fit$sd_report)
  expect_error(
    getLV(fit, level = "unit", se = TRUE),
    class = "gllvmTMB_getLV_se_no_sdreport"
  )
})

test_that("getLV(se = TRUE) returns NULL (not an error) when there is no rr term at that level", {
  ## Diagonal-only (no rr_B) fit: extract_ordination() already returns NULL
  ## for this fit at level = 'unit'; se = TRUE must not change that.
  set.seed(17)
  sim <- simulate_site_trait(
    n_sites = 15, n_species = 5, n_traits = 3, mean_species_per_site = 4,
    psi_B = rep(0.3, 3), seed = 17
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site),
    data = sim$data
  )))
  expect_null(getLV(fit, level = "unit", se = TRUE))
})

## ---- level = 'unit_obs' (z_W) -------------------------------------------

test_that("getLV(level = 'unit_obs', se = TRUE) uses the z_W block with matching shape", {
  fit <- .build_getlv_se_fit_BW()
  if (!isTRUE(fit$sd_report$pdHess)) {
    skip("two-tier (B+W) getlv-se fixture did not converge to a PD Hessian on this platform")
  }
  out <- getLV(fit, level = "unit_obs", se = TRUE)
  expect_named(out, c("scores", "se"))
  expect_equal(dim(out$se), dim(out$scores))
  expect_equal(nrow(out$se), fit$n_site_species)
  expect_equal(ncol(out$se), fit$d_W)
  expect_true(all(is.finite(out$se)))
  expect_true(all(out$se > 0))

  ## Same ordering-hazard guard as the unit-level test, at the W tier.
  sd_rep <- fit$sd_report
  idx <- which(names(sd_rep$par.random) == "z_W")
  se_vec <- sqrt(sd_rep$diag.cov.random[idx])
  se_correct <- t(matrix(se_vec, nrow = fit$d_W, ncol = fit$n_site_species))
  expect_equal(out$se, se_correct, ignore_attr = TRUE)
})

test_that("getLV(level = 'unit', se = TRUE) on the B+W fit still reads z_B, not z_W", {
  ## Guards specifically against the level-name mix-up this suite caught
  ## during development: requesting level = 'unit' must read the z_B
  ## block even when the fit also has a z_W block of a DIFFERENT length
  ## present in the same sd_report$par.random vector.
  ## This test's assertions (block shape/name resolution) hold regardless
  ## of pdHess -- .getLV_se() locates z_B by name/length before it ever
  ## looks at pdHess, and NA-filled SEs (the non-PD fallback) have the
  ## same dims as real ones -- so, unlike the numeric-SE test above, this
  ## one does not skip() on a non-PD Hessian; it still exercises the
  ## level-dispatch guard on every platform.
  fit <- .build_getlv_se_fit_BW()
  out <- getLV(fit, level = "unit", se = TRUE)
  expect_equal(nrow(out$se), fit$n_sites)
  expect_equal(ncol(out$se), fit$d_B)
})
