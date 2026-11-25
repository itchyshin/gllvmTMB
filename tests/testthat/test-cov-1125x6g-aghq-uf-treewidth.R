test_that("union-find helpers merge and find roots", {
  uf <- .aghq_union_find(5L)
  expect_equal(uf$parent, 1:5)
  expect_equal(.aghq_uf_find(uf, 3L), 3L)
  uf2 <- .aghq_uf_union(uf, 1L, 2L)
  uf3 <- .aghq_uf_union(uf2, 2L, 3L)
  expect_equal(.aghq_uf_find(uf3, 1L), .aghq_uf_find(uf3, 3L))
  expect_equal(.aghq_uf_find(uf3, 4L), 4L)
  uf4 <- .aghq_uf_union(uf3, 3L, 4L)
  r1 <- .aghq_uf_find(uf4, 1L)
  expect_equal(.aghq_uf_find(uf4, 4L), r1)
})

test_that(".aghq_treewidth_upper_bound handles tiny and capped graphs", {
  expect_equal(.aghq_treewidth_upper_bound(list(1), size_cap = 10L), 0L)
  adj_line <- list(2, c(1, 3), 2)
  tw <- .aghq_treewidth_upper_bound(adj_line, size_cap = 10L)
  expect_true(tw >= 1L && tw <= 2L)
  big <- replicate(500L, integer(0), simplify = FALSE)
  expect_equal(.aghq_treewidth_upper_bound(big, size_cap = 100L), 499L)
})

test_that(".aghq_treewidth_upper_bound on a triangle is bounded", {
  adj <- list(c(2, 3), c(1, 3), c(1, 2))
  tw <- .aghq_treewidth_upper_bound(adj, size_cap = 20L)
  expect_true(tw >= 1L && tw <= 2L)
})

test_that(".aghq_gate returns empty frame when random index is empty", {
  obj <- list(env = list(random = integer(0), par = numeric(0)))
  out <- .aghq_gate(obj, list(REML = FALSE))
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
  expect_equal(names(out), c(
    "block", "size", "n_components", "treewidth", "route", "reason"
  ))
})

test_that(".aghq_gate_hard_dense_reasons is keyed for dense blocks", {
  reasons <- .aghq_gate_hard_dense_reasons
  expect_true(length(reasons) >= 3L)
  expect_true(all(nzchar(unname(reasons))))
  expect_true("e_eq" %in% names(reasons))
  expect_true(grepl("equalto", reasons[["e_eq"]], fixed = TRUE))
})