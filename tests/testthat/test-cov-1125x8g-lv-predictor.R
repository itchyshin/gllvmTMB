## Coverage (cursor-cloud-1125x8g): lv-predictor.R parser preflight helpers.

test_that("gll_lv_covstruct_indices finds lv_formula slots", {
  cs <- list(
    list(extra = list()),
    list(extra = list(lv_formula = ~1)),
    list(extra = list(foo = 1))
  )
  idx <- gllvmTMB:::gll_lv_covstruct_indices(cs)
  expect_equal(idx, 2L)
  expect_length(gllvmTMB:::gll_lv_covstruct_indices(list()), 0L)
})

test_that("gll_lv_term_label names rr and phylo kinds", {
  rr <- list(kind = "rr", extra = list())
  expect_equal(gllvmTMB:::gll_lv_term_label(rr), "latent()")
  krr <- list(kind = "rr", extra = list(.kernel_mode = "latent"))
  expect_equal(gllvmTMB:::gll_lv_term_label(krr), "kernel_latent()")
  phy <- list(kind = "phylo_rr", extra = list())
  expect_equal(gllvmTMB:::gll_lv_term_label(phy), "phylo_latent()")
  sp <- list(kind = "spde", extra = list())
  expect_equal(gllvmTMB:::gll_lv_term_label(sp), "spatial_latent()")
})

test_that("gll_lv_formula and rhs function harvesters", {
  cs <- list(extra = list(lv = ~x + y))
  expect_equal(gllvmTMB:::gll_lv_formula(cs), ~x + y)
  fml <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x)
  fns <- gllvmTMB:::gll_lv_rhs_functions(fml)
  expect_true("latent" %in% fns)
  no_int <- gllvmTMB:::gll_lv_no_intercept_formula(fml)
  expect_s3_class(no_int, "formula")
})

test_that("gll_prepare_lv_predictor_setup disables without lv terms", {
  parsed <- list(covstructs = list(list(kind = "rr", group = quote(unit), extra = list())))
  out <- gllvmTMB:::gll_prepare_lv_predictor_setup(
    parsed = parsed,
    data = data.frame(unit = 1:3, trait = rep("a", 3)),
    trait = "trait",
    site = "unit",
    family_id_vec = rep(1L, 3L),
    link_id_vec = rep(1L, 3L)
  )
  expect_false(out$enabled)
})