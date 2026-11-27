## Coverage pins for global ranks 13–15 R files (cursor/1127cov-gllvmTMB-w6).
## Tests only — fast contract paths, no package source edits.

# ---- R/gllvmTMB.R (rank 13) ------------------------------------------------

test_that(".gllvmTMB_as_flag() accepts logical and 0/1 numeric", {
  expect_true(gllvmTMB:::.gllvmTMB_as_flag(TRUE, "x"))
  expect_false(gllvmTMB:::.gllvmTMB_as_flag(0, "x"))
  expect_error(gllvmTMB:::.gllvmTMB_as_flag("yes", "x"), regexp = "must be")
})

test_that(".gllvmTMB_as_count() requires a positive integer", {
  expect_identical(gllvmTMB:::.gllvmTMB_as_count(3, "aghq"), 3L)
  expect_error(gllvmTMB:::.gllvmTMB_as_count(1.5, "aghq"), regexp = "positive whole number")
})

test_that(".gllvmTMB_as_tol() enforces positive or non-negative bounds", {
  expect_identical(gllvmTMB:::.gllvmTMB_as_tol(0.01, "tol"), 0.01)
  expect_error(gllvmTMB:::.gllvmTMB_as_tol(-1, "tol"), regexp = "positive")
  expect_identical(gllvmTMB:::.gllvmTMB_as_tol(0, "tol", allow_zero = TRUE), 0)
})

test_that(".gllvmTMB_normalize_aghq() maps FALSE, auto, TRUE, and integers", {
  expect_false(gllvmTMB:::.gllvmTMB_normalize_aghq(FALSE))
  expect_identical(gllvmTMB:::.gllvmTMB_normalize_aghq("auto"), "auto")
  expect_identical(gllvmTMB:::.gllvmTMB_normalize_aghq(TRUE), "auto")
  expect_identical(gllvmTMB:::.gllvmTMB_normalize_aghq(5), 5L)
  expect_error(gllvmTMB:::.gllvmTMB_normalize_aghq(1.5), regexp = "aghq")
})

test_that(".gllvmTMB_normalize_start_method() normalises list and legacy res", {
  expect_equal(
    gllvmTMB:::.gllvmTMB_normalize_start_method(NULL),
    list(method = NULL, jitter.sd = 0)
  )
  out <- gllvmTMB:::.gllvmTMB_normalize_start_method(
    list(method = "indep", jitter.sd = 0.1)
  )
  expect_equal(out$method, "indep")
  expect_equal(out$jitter.sd, 0.1)
  expect_error(
    gllvmTMB:::.gllvmTMB_normalize_start_method(list(method = "bad")),
    regexp = "Unknown"
  )
})

test_that("detect_covstruct_terms() finds spde bar terms but not exp(x)", {
  f_exp <- y ~ exp(x1) + latent(1 | site, d = 2)
  expect_false("exp" %in% gllvmTMB:::detect_covstruct_terms(f_exp))
  found <- gllvmTMB:::detect_covstruct_terms(stats::as.formula("y ~ spde(1 | site)"))
  expect_equal(found, "spde")
  found_rr <- gllvmTMB:::detect_covstruct_terms(stats::as.formula("y ~ rr(1 | site)"))
  expect_equal(found_rr, "rr")
})

test_that("miss_control() does not accept an estimator argument", {
  expect_error(
    gllvmTMB::miss_control(estimator = "REML"),
    regexp = "unused argument"
  )
})

# ---- R/extract-sigma.R (rank 14) -------------------------------------------

test_that(".safe_cov2cor() converts covariance to correlation", {
  Sigma <- matrix(c(4, 2, 2, 9), 2, 2, dimnames = list(c("a", "b"), c("a", "b")))
  R <- gllvmTMB:::.safe_cov2cor(Sigma)
  expect_equal(unname(diag(R)), c(1, 1))
  expect_equal(unname(R[1, 2]), 2 / (2 * 3))
})

test_that(".matrix_inv_sqrt() inverts square root of a PSD matrix", {
  x <- matrix(c(2, 0.5, 0.5, 3), 2, 2)
  inv_sqrt <- gllvmTMB:::.matrix_inv_sqrt(x, tol = 1e-8, arg = "Gamma_shape")
  rebuilt <- inv_sqrt %*% x %*% inv_sqrt
  expect_equal(rebuilt, diag(2), tolerance = 1e-6)
})

test_that(".matrix_inv_sqrt() aborts on indefinite blocks", {
  x <- matrix(c(1, 2, 2, 1), 2, 2)
  expect_error(
    gllvmTMB:::.matrix_inv_sqrt(x, tol = 1e-8, arg = "Gamma_shape"),
    regexp = "positive semidefinite"
  )
})

test_that(".coevolution_axis_table() expands trait x module loadings", {
  traits <- c("t1", "t2")
  modules <- c("m1", "m2")
  x <- matrix(1:4, nrow = 2, ncol = 2, dimnames = list(traits, modules))
  tab <- gllvmTMB:::.coevolution_axis_table(
    x, traits, modules, "shape", "row"
  )
  expect_equal(NROW(tab), 4L)
  expect_true(all(c("component", "side", "module", "trait", "loading") %in% names(tab)))
  expect_equal(tab$loading[tab$trait == "t2" & tab$module == "m2"], 4)
})

test_that(".cross_covariance_arg() and .gamma_trait_arg() validate trait names", {
  expect_equal(
    gllvmTMB:::.cross_covariance_arg(c("a", "b"), "traits"),
    c("a", "b")
  )
  expect_error(
    gllvmTMB:::.cross_covariance_arg(c("a", "a"), "traits"),
    regexp = "duplicate"
  )
  expect_error(
    gllvmTMB:::.gamma_trait_arg("", "trait"),
    regexp = "non-empty"
  )
})

# ---- R/predictive-diagnostics.R (rank 15) ----------------------------------

test_that(".gllvmTMB_clip_unit_interval() keeps probabilities inside (0, 1)", {
  u <- c(-1, 0, 0.5, 1, 2)
  clipped <- gllvmTMB:::.gllvmTMB_clip_unit_interval(u)
  expect_true(all(clipped > 0 & clipped < 1))
  expect_equal(clipped[3], 0.5)
})

test_that(".gllvmTMB_binom_prob() matches link inverse at eta = 0", {
  expect_equal(gllvmTMB:::.gllvmTMB_binom_prob(0, 0L), 0.5)
  expect_equal(gllvmTMB:::.gllvmTMB_binom_prob(0, 1L), 0.5)
  expect_equal(
    gllvmTMB:::.gllvmTMB_binom_prob(0, 2L),
    -expm1(-1),
    tolerance = 1e-12
  )
})

test_that(".gllvmTMB_betabinom_cdf() is monotone and ends at one", {
  cdf <- gllvmTMB:::.gllvmTMB_betabinom_cdf(N = 5L, a = 2, b = 3)
  expect_equal(length(cdf), 6L)
  expect_true(all(diff(cdf) >= -1e-10))
  expect_equal(cdf[1], cdf[1]) # starts at pmf(0)
  expect_equal(tail(cdf, 1), 1, tolerance = 1e-8)
})

test_that(".gllvmTMB_resolve_nsim() defaults and rejects conflicting args", {
  expect_identical(gllvmTMB:::.gllvmTMB_resolve_nsim(), 50L)
  expect_identical(gllvmTMB:::.gllvmTMB_resolve_nsim(nsim = 10L), 10L)
  expect_error(
    gllvmTMB:::.gllvmTMB_resolve_nsim(nsim = 10L, ndraws = 20L),
    regexp = "only one"
  )
})

test_that(".gllvmTMB_count_bins() collapses tail counts", {
  expect_equal(
    gllvmTMB:::.gllvmTMB_count_bins(c(0, 3, 10), max_count = 5L),
    c("0", "3", ">5")
  )
})

test_that(".gllvmTMB_family_label_from_id() maps known family ids", {
  expect_equal(gllvmTMB:::.gllvmTMB_family_label_from_id(0L), "gaussian")
  expect_equal(gllvmTMB:::.gllvmTMB_family_label_from_id(8L), "betabinomial")
  expect_equal(gllvmTMB:::.gllvmTMB_family_label_from_id(99L), "family_id_99")
})