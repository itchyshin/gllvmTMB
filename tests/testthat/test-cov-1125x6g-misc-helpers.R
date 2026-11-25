test_that(".build_cv_fixture returns toy panels per family", {
  panels <- .build_cv_fixture(seed = 99L)
  for (fam in c("gaussian", "binomial", "poisson", "nbinom2")) {
    expect_type(panels[[fam]], "list")
    expect_s3_class(panels[[fam]]$data, "data.frame")
    expect_true(nrow(panels[[fam]]$data) > 0L)
    expect_identical(panels[[fam]]$truth$family, fam)
  }
})

test_that(".aghq_uf_union is idempotent on the same component", {
  uf <- .aghq_union_find(3L)
  uf2 <- .aghq_uf_union(uf, 1L, 1L)
  expect_equal(uf2$parent, uf$parent)
})

test_that(".gllvmTMB_keyword_bare_groups handles empty keyword sets", {
  f <- y ~ kernel_indep(unit, K = diag(2))
  empty <- .gllvmTMB_keyword_bare_groups(f, "not_a_kw", character())
  expect_equal(nrow(empty), 0L)
})

test_that(".lambda_constraint_decision maps known methods", {
  expect_equal(.lambda_constraint_decision_basis("none"), "no pins")
  expect_equal(.lambda_constraint_decision_cost("wald_retention"), "no refit; needs PD Hessian")
  expect_equal(
    .recommend_lambda_constraint_method(c("lower_triangular", "profile_retention")),
    "profile_retention"
  )
})