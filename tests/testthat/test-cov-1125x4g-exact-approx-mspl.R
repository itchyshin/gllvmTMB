## Coverage (cursor-cloud-1125x4g): R/exact-marginal-gaussian.R, R/approximation-engine.R, R/mspl-registry.R.

test_that(".gllvmTMB_exact_pair_woodbury_data() returns disabled for unsupported geometry", {
  K <- diag(3)
  out <- gllvmTMB:::.gllvmTMB_exact_pair_woodbury_data(
    list(K), c(0L, 0L, 1L), c(0L, 0L, 1L), n_traits = 2L
  )
  expect_equal(out$enabled, 0L)
})

test_that(".gllvmTMB_exact_pair_woodbury_data() stays disabled without two tiers", {
  out <- gllvmTMB:::.gllvmTMB_exact_pair_woodbury_data(
    list(diag(2)), c(0L, 1L), c(0L, 1L), n_traits = 1L
  )
  expect_equal(out$enabled, 0L)
  expect_equal(out$base_tier, 0L)
})

test_that(".approximation_engine_regime() describes VA and EVA contracts", {
  va <- gllvmTMB:::.approximation_engine_regime("va_r3")
  expect_type(va, "list")
  expect_equal(va$link, "logit or log")
  eva <- gllvmTMB:::.approximation_engine_regime("eva")
  expect_false(eva$fixture_only)
  expect_null(gllvmTMB:::.approximation_engine_regime("not_real"))
})

test_that(".approximation_engine_scalar_character() validates input", {
  expect_equal(
    gllvmTMB:::.approximation_engine_scalar_character("binomial", "family"),
    "binomial"
  )
  expect_error(
    gllvmTMB:::.approximation_engine_scalar_character(1L, "family"),
    "must be one non-missing"
  )
})

test_that(".approximation_engine_va_r3_fit() stops on incompatible family/link", {
  expect_error(
    gllvmTMB:::.approximation_engine_va_r3_fit(
      y = c(0, 1), n_trials = c(1, 1), X = matrix(1, 2, 1),
      unit_id = c(0L, 1L), trait_id = c(0L, 0L), q = 1L, N = 2L, T = 1L,
      family = "poisson", link = "logit"
    ),
    "admits"
  )
})

test_that(".approximation_engine_validate_eva_fixture() rejects incomplete lists", {
  expect_error(
    gllvmTMB:::.approximation_engine_validate_eva_fixture(list()),
    "EVA requires"
  )
})

test_that(".gllvmTMB_mspl_link_name() maps engine link ids", {
  expect_equal(gllvmTMB:::.gllvmTMB_mspl_link_name(0L), "logit")
  expect_equal(gllvmTMB:::.gllvmTMB_mspl_link_name(1L), "probit")
  expect_equal(gllvmTMB:::.gllvmTMB_mspl_link_name(2L), "cloglog")
  expect_true(is.na(gllvmTMB:::.gllvmTMB_mspl_link_name(9L)))
})

test_that(".gllvmTMB_mspl_family_link_name() distinguishes count log links", {
  expect_equal(
    gllvmTMB:::.gllvmTMB_mspl_family_link_name(2L, 0L),
    "log"
  )
  expect_equal(
    gllvmTMB:::.gllvmTMB_mspl_family_link_name(0L, 0L),
    "identity"
  )
  expect_true(is.na(gllvmTMB:::.gllvmTMB_mspl_family_link_name(0L, 1L)))
})

test_that(".gllvmTMB_mspl_S_diag() errors on short grids and zero variance", {
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_S_diag(c(1, 2), c(0L, 0L), c(0L, 0L)),
    "at least two units"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_S_diag(c(5, 5), c(0L, 0L, 1L, 1L), c(0L, 0L, 1L, 1L)),
    "balanced"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_mspl_S_diag(c(5, 5, 5, 5), c(0L, 0L, 1L, 1L), c(0L, 1L, 0L, 1L)),
    "strictly positive"
  )
  vals <- gllvmTMB:::.gllvmTMB_mspl_S_diag(
    c(1.1, 2.2, 3.5, 4.8), c(0L, 0L, 1L, 1L), c(0L, 1L, 0L, 1L)
  )
  expect_length(vals, 2L)
  expect_equal(vals, c(var(c(1.1, 2.2)), var(c(3.5, 4.8))))
})

test_that("aghq union-find merges component ids", {
  uf <- gllvmTMB:::.aghq_union_find(4L)
  uf <- gllvmTMB:::.aghq_uf_union(uf, 1L, 2L)
  uf <- gllvmTMB:::.aghq_uf_union(uf, 3L, 4L)
  expect_equal(gllvmTMB:::.aghq_uf_find(uf, 2L), gllvmTMB:::.aghq_uf_find(uf, 1L))
  expect_equal(gllvmTMB:::.aghq_uf_find(uf, 4L), gllvmTMB:::.aghq_uf_find(uf, 3L))
})

test_that(".aghq_treewidth_upper_bound() returns a finite width", {
  adj <- list(
    c(2L, 3L),
    c(1L, 3L, 4L),
    c(1L, 2L, 4L),
    c(2L, 3L)
  )
  tw <- gllvmTMB:::.aghq_treewidth_upper_bound(adj)
  expect_true(is.finite(tw))
  expect_gte(tw, 0L)
})

test_that(".gllvmTMB_mspl_registry_cell_id() formats stable ids", {
  id <- gllvmTMB:::.gllvmTMB_mspl_registry_cell_id("poisson", "log", "ordinary", 1L)
  expect_match(id, "poisson")
  expect_match(id, "log")
})