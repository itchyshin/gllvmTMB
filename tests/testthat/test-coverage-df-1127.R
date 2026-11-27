## Coverage pins for R/[d-f]*.R (cursor/1127cov-gllvmTMB-df). Fast unit tests
## only; heavy fits use skip_on_cran() like sibling dispersion-pinning tests.

# ---- R/dispersion-trait-map.R -----------------------------------------------

test_that("dispersion_trait_family_mask() marks traits that carry a target family", {
  trait_id <- c(0L, 0L, 1L, 1L)
  family_id_vec <- c(5L, 2L, 2L, 2L)
  mask <- gllvmTMB:::dispersion_trait_family_mask(
    trait_id, family_id_vec, fids = 5L, n_traits = 2L
  )
  expect_identical(mask, c(TRUE, FALSE))
})

test_that("dispersion_trait_map() returns NULL when every trait is free and unpinned", {
  expect_null(gllvmTMB:::dispersion_trait_map(c(TRUE, TRUE)))
})

test_that("dispersion_trait_map() pins traits outside the family mask", {
  m <- gllvmTMB:::dispersion_trait_map(c(TRUE, FALSE))
  expect_identical(as.integer(m), c(1L, NA_integer_))
  expect_s3_class(m, "factor")
})

test_that("dispersion_trait_map() combines user pins with the family mask", {
  m <- gllvmTMB:::dispersion_trait_map(
    family_mask = c(TRUE, TRUE, FALSE),
    user_pin_mask = c(FALSE, TRUE, FALSE)
  )
  expect_identical(as.integer(m), c(1L, NA_integer_, NA_integer_))
})

test_that("zi_logit_start() uses method-of-moments defaults per zi family", {
  n_traits <- 3L
  trait_id <- c(0L, 0L, 1L, 1L, 2L, 2L, 2L)
  n_trials <- c(1L, 1L, 1L, 1L, 5L, 5L, 5L)
  family_id_vec <- c(17L, 17L, 18L, 18L, 19L, 19L, 19L)
  y <- c(0L, 2L, 0L, 4L, 0L, 2L, 5L)

  start <- gllvmTMB:::zi_logit_start(
    y, trait_id, family_id_vec, n_trials, n_traits
  )
  expect_length(start, n_traits)
  neutral <- stats::qlogis(0.1)
  lo <- stats::qlogis(0.02)
  hi <- stats::qlogis(0.8)
  expect_true(all(start >= lo & start <= hi))
  expect_true(all(is.finite(start)))

  expect_true(start[1L] != neutral)
  expect_true(start[2L] != neutral)
})

# ---- R/diagnostic-tables.R ------------------------------------------------

test_that("diagnostic_table(row_status) buckets missing and absent status values", {
  base <- data.frame(
  trait = "a", observed = 1, residual = 0,
  status = c(NA_character_, "", "ok")
)
  res <- structure(
    data.frame(a = 1:3),
    gllvmTMB_diagnostic = list(data = base)
  )
  tab <- diagnostic_table(res, table = "row_status")
  expect_identical(names(tab), c("status", "n"))
  expect_true(all(c("missing", "ok") %in% tab$status))

  no_status <- structure(
    data.frame(a = 1:5),
    gllvmTMB_diagnostic = list(data = data.frame(a = 1:5))
  )
  tab2 <- diagnostic_table(no_status, table = "row_status")
  expect_identical(tab2$status, "not_recorded")
  expect_identical(tab2$n, 5L)
})

test_that("diagnostic_table(fit_health_status) errors when status metadata is missing", {
  bad <- structure(
    data.frame(x = 1),
    gllvmTMB_diagnostic = list(fit_health_status = "nope")
  )
  expect_error(
    diagnostic_table(bad, table = "fit_health_status"),
    "fit-health"
  )
})

# ---- R/data-cv-fixture.R ----------------------------------------------------

test_that(".build_cv_fixture() produces the four documented family variants", {
  skip_on_cran()
  fx <- gllvmTMB:::.build_cv_fixture(seed = 20260802L)
  expect_identical(names(fx), c("gaussian", "binomial", "poisson", "nbinom2"))
  for (nm in names(fx)) {
    expect_s3_class(fx[[nm]]$data, "data.frame")
    expect_gt(nrow(fx[[nm]]$data), 0L)
    expect_identical(fx[[nm]]$truth$family, nm)
    expect_true(is.list(fx[[nm]]$family_arg))
  }
  cached <- gllvmTMB:::load_cv_fixture("gaussian")
  expect_equal(nrow(fx$gaussian$data), nrow(cached$data))
})

# ---- R/exact-marginal-gaussian.R ------------------------------------------

test_that(".gllvmTMB_check_unique_marginal_cells() enforces one row per unit-trait cell", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_unique_marginal_cells(1:2, 1:3),
    "equal length"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_check_unique_marginal_cells(c(0L, 0L), c(0L, 0L)),
    class = "gllvmTMB_exact_gaussian_duplicate_cell"
  )
  expect_invisible(
    gllvmTMB:::.gllvmTMB_check_unique_marginal_cells(c(0L, 1L), c(0L, 0L))
  )
})

# ---- R/eva-delta.R --------------------------------------------------------

test_that(".eva_delta_summary() validates its delta vector", {
  expect_error(
    gllvmTMB:::.eva_delta_summary(c(0, NA)),
    "finite"
  )
  expect_error(gllvmTMB:::.eva_delta_summary(character()), "finite")
})

# ---- R/estimator-provenance.R ---------------------------------------------

test_that(".gllvmTMB_resolve_estimator_provenance() records REML with non-Laplace integration", {
  reml_va <- gllvmTMB:::.gllvmTMB_resolve_estimator_provenance(
    estimator = "ml", reml = TRUE, integration = "va"
  )
  expect_identical(reml_va$criterion_id, "reml")
  expect_identical(reml_va$integration, "va")
  expect_true(reml_va$public_estimator_is_coarse)
  expect_identical(reml_va$numeric_kernel_id, "va")
  expect_true(is.na(reml_va$estimator_id))

  reml_aghq <- gllvmTMB:::.gllvmTMB_resolve_estimator_provenance(
    estimator = "ml", reml = TRUE, integration = "aghq"
  )
  expect_identical(reml_aghq$integration, "aghq")
  expect_identical(reml_aghq$numeric_kernel_id, "legacy_ml")
  expect_identical(reml_aghq$estimator_id, 0L)
})

test_that(".gllvmTMB_resolve_estimator_provenance() normalises unknown tape roles", {
  row <- gllvmTMB:::.gllvmTMB_resolve_estimator_provenance(
    estimator = "ml", integration = "laplace", tape_role = "unknown"
  )
  expect_identical(row$criterion_id, "la_ml")
})