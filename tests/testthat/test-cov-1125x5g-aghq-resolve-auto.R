## Coverage (cursor-cloud-1125x5g): `.aghq_resolve()`, auto gate/decide, `.aghq_grid()`.

test_that(".aghq_grid() builds k^d rows with finite log weights", {
  g1 <- gllvmTMB:::.aghq_grid(1L, 3L)
  expect_equal(nrow(g1$nodes), 3L)
  expect_equal(ncol(g1$nodes), 1L)
  expect_length(g1$logw, 3L)
  expect_true(all(is.finite(g1$logw)))

  g2 <- gllvmTMB:::.aghq_grid(2L, 3L)
  expect_equal(nrow(g2$nodes), 9L)
  expect_equal(ncol(g2$nodes), 2L)
  expect_length(g2$logw, 9L)
})

test_that(".aghq_grid() refuses bad dimension arguments", {
  for (bad in list(0, -1, 1.5, NA, NULL, c(1, 2))) {
    expect_error(
      gllvmTMB:::.aghq_grid(bad, 3L),
      "d must be a positive integer"
    )
  }
})

test_that(".aghq_resolve() honours explicit user k and attaches lbfgsb factr", {
  pois <- stats::poisson()
  out <- gllvmTMB:::.aghq_resolve(pois, "jj", n_traits = 4L, q = 1L,
                                  control = list(aghq = 7L))
  expect_equal(out$k, 7L)
  expect_match(out$reason, "user override")
  expect_type(out$reason, "character")
  expect_true("optimizer" %in% names(out))

  bin <- gllvmTMB:::.aghq_resolve("binomial", "jj", 4L, 2L,
                                   control = list())
  expect_equal(bin$optimizer, "lbfgsb")
  expect_type(bin$optArgs$factr, "double")
  expect_gt(bin$optArgs$factr, 1)
})

test_that(".aghq_resolve() picks ladder start k from family and tier", {
  ord <- gllvmTMB:::.aghq_resolve("ordinal_probit", "gh", 3L, 1L, list())
  expect_equal(ord$k, 9L)
  expect_match(ord$reason, "k = 9")

  disc <- gllvmTMB:::.aghq_resolve("poisson", "sparse", 3L, 1L, list())
  expect_equal(disc$k, 7L)

  floor <- gllvmTMB:::.aghq_resolve("gaussian", "gh", 3L, 1L, list())
  expect_equal(floor$k, 5L)
})

test_that(".aghq_auto_decide() declines when the gate table is unusable", {
  decline <- gllvmTMB:::.aghq_auto_decide(NULL, 5L, 1L, 50L)
  expect_false(decline$use)
  expect_true(is.na(decline$k))
  expect_match(decline$reason, "gate table")

  empty <- data.frame()
  decline2 <- gllvmTMB:::.aghq_auto_decide(empty, 5L, 1L, 50L)
  expect_false(decline2$use)

  bad_cols <- data.frame(block = 1L, size = 1L)
  decline3 <- gllvmTMB:::.aghq_auto_decide(bad_cols, 5L, 1L, 50L)
  expect_match(decline3$reason, "columns")

  gate <- data.frame(
    block = "z",
    size = 10L,
    n_components = 1L,
    treewidth = 1L,
    route = "laplace",
    reason = "cheap"
  )
  decline4 <- gllvmTMB:::.aghq_auto_decide(gate, 5L, 1L, 50L)
  expect_match(decline4$reason, "quadrature")
})

test_that(".aghq_auto_decide() accepts affordable quadrature below trait cutoff", {
  gate <- data.frame(
    block = "B",
    size = 8L,
    n_components = 1L,
    treewidth = 2L,
    route = "quadrature",
    reason = "ok"
  )
  ok <- gllvmTMB:::.aghq_auto_decide(gate, n_traits = 8L, q = 2L, n = 40L)
  expect_true(ok$use)
  expect_equal(ok$k, 5L)
  expect_match(ok$reason, "turning AGHQ on")
})

test_that(".aghq_auto_decide() declines at n_traits >= cutoff", {
  gate <- data.frame(
    block = "B",
    size = 8L,
    n_components = 1L,
    treewidth = 1L,
    route = "quadrature",
    reason = "ok"
  )
  big <- gllvmTMB:::.aghq_auto_decide(gate, n_traits = 25L, q = 1L, n = 100L)
  expect_false(big$use)
  expect_match(big$reason, "cutoff")
})

test_that(".aghq_auto_gate() returns NULL for explicit numeric aghq", {
  ctrl <- gllvmTMB::gllvmTMBcontrol(aghq = 5L)
  gate <- data.frame(
    block = "B", size = 1L, n_components = 1L, treewidth = 1L,
    route = "quadrature", reason = "x"
  )
  expect_null(gllvmTMB:::.aghq_auto_gate(ctrl, gate, 30L, 2L, 50L))
})

test_that(".aghq_auto_gate() surfaces decline reason for aghq = auto", {
  ctrl <- gllvmTMB::gllvmTMBcontrol(aghq = "auto")
  reason <- gllvmTMB:::.aghq_auto_gate(ctrl, NULL, 5L, 1L, 20L)
  expect_type(reason, "character")
  expect_match(reason, "gate table")
})