## Coverage (cursor-cloud-1125x4g): R/aghq-gate.R and R/utils-call.R edges.

test_that("aghq union-find handles singleton merges", {
  uf <- gllvmTMB:::.aghq_union_find(3L)
  expect_equal(uf$parent, 1:3)
  uf2 <- gllvmTMB:::.aghq_uf_union(uf, 1L, 1L)
  expect_equal(gllvmTMB:::.aghq_uf_find(uf2, 1L), 1L)
})

test_that(".aghq_treewidth_upper_bound() is zero for empty graphs", {
  expect_equal(gllvmTMB:::.aghq_treewidth_upper_bound(list()), 0L)
  expect_equal(gllvmTMB:::.aghq_treewidth_upper_bound(list(integer(0))), 0L)
})

test_that("safe_deparse() preserves short symbols", {
  expect_equal(gllvmTMB:::safe_deparse(quote(trait)), "trait")
})

test_that("extract_call_name() handles symbols and calls", {
  expect_equal(gllvmTMB:::extract_call_name(quote(site)), "site")
  expect_match(
    gllvmTMB:::extract_call_name(call("latent", 1), max_width = 80L),
    "latent"
  )
})

test_that("gllvmTMB:::ggplot2_installed() matches requireNamespace", {
  expect_identical(
    gllvmTMB:::ggplot2_installed(),
    requireNamespace("ggplot2", quietly = TRUE)
  )
})

test_that(".gllvmTMB_mspl_poisson_rate() matches sqrt formula", {
  expect_equal(
    gllvmTMB:::.gllvmTMB_mspl_poisson_rate(9, 100),
    2 * sqrt(9 / 100)
  )
})

test_that(".gllvmTMB_mspl_poisson_event_count() floors zero counts", {
  expect_equal(gllvmTMB:::.gllvmTMB_mspl_poisson_event_count(0), 1)
})

test_that(".gllvmTMB_estimator_compatibility_table() covers MSPL row", {
  tbl <- gllvmTMB:::.gllvmTMB_estimator_compatibility_table()
  expect_true(any(tbl$public_estimator == "mspl"))
  expect_true(any(tbl$integration == "aghq"))
})

test_that("variance_lrt() validates boundary count", {
  expect_error(variance_lrt(-1, -2, n_boundary = 0L), "q")
  out <- variance_lrt(-5, -7, n_boundary = 1L)
  expect_equal(out$LRT, 4)
  expect_equal(out$n_boundary, 1L)
})

test_that("chibar2_pvalue() returns one for zero LRT", {
  expect_equal(chibar2_pvalue(0, 1L), 1)
})

test_that("diagnostic_table() requires metadata", {
  expect_error(diagnostic_table(data.frame(x = 1), table = "data"), "metadata")
})