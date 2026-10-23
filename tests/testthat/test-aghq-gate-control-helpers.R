## Characterisation tests for pure-R internals of R/aghq-gate.R and
## R/aghq-control.R that had no direct test coverage. No fits are run.

# ---- union-find (R/aghq-gate.R) ---------------------------------------------

test_that(".aghq_union_find starts with every element its own root", {
  uf <- .aghq_union_find(5L)
  expect_identical(uf$parent, 1:5)
  expect_identical(uf$rank, integer(5))
  for (x in 1:5) expect_identical(.aghq_uf_find(uf, x), x)
})

test_that(".aghq_uf_union merges sets and find returns a common root", {
  uf <- .aghq_union_find(6L)
  uf <- .aghq_uf_union(uf, 1L, 2L)
  uf <- .aghq_uf_union(uf, 3L, 4L)
  expect_identical(.aghq_uf_find(uf, 1L), .aghq_uf_find(uf, 2L))
  expect_identical(.aghq_uf_find(uf, 3L), .aghq_uf_find(uf, 4L))
  expect_false(.aghq_uf_find(uf, 1L) == .aghq_uf_find(uf, 3L))
  uf <- .aghq_uf_union(uf, 2L, 4L)
  roots <- vapply(1:6, function(x) .aghq_uf_find(uf, x), integer(1))
  expect_length(unique(roots[1:4]), 1L)
  expect_identical(roots[5:6], 5:6)  # untouched singletons
})

test_that(".aghq_uf_union is idempotent and unions by rank", {
  uf <- .aghq_union_find(4L)
  uf <- .aghq_uf_union(uf, 1L, 2L)
  again <- .aghq_uf_union(uf, 2L, 1L)
  expect_identical(again, uf)             # same-root union returns uf unchanged
  expect_identical(uf$rank[.aghq_uf_find(uf, 1L)], 1L)
  uf <- .aghq_uf_union(uf, 3L, 1L)        # the rank-1 root absorbs the singleton
  expect_identical(.aghq_uf_find(uf, 3L), .aghq_uf_find(uf, 1L))
  expect_identical(uf$rank[.aghq_uf_find(uf, 1L)], 1L)
})

# ---- treewidth upper bound (R/aghq-gate.R) ----------------------------------
## `adj` is a list of integer neighbour vectors, one per vertex.

test_that(".aghq_treewidth_upper_bound: trees have width 1", {
  path <- list(2L, c(1L, 3L), c(2L, 4L), 3L)
  star <- list(2:4, 1L, 1L, 1L)
  expect_identical(.aghq_treewidth_upper_bound(path), 1L)
  expect_identical(.aghq_treewidth_upper_bound(star), 1L)
})

test_that(".aghq_treewidth_upper_bound: complete graph K_n has width n - 1", {
  complete <- function(n) lapply(seq_len(n), function(i) setdiff(seq_len(n), i))
  expect_identical(.aghq_treewidth_upper_bound(complete(4L)), 3L)
  expect_identical(.aghq_treewidth_upper_bound(complete(6L)), 5L)
})

test_that(".aghq_treewidth_upper_bound: cycle has width 2", {
  cyc <- list(c(2L, 4L), c(1L, 3L), c(2L, 4L), c(1L, 3L))
  expect_identical(.aghq_treewidth_upper_bound(cyc), 2L)
})

test_that(".aghq_treewidth_upper_bound: trivial sizes and size_cap", {
  expect_identical(.aghq_treewidth_upper_bound(list()), 0L)
  expect_identical(.aghq_treewidth_upper_bound(list(integer(0))), 0L)
  complete4 <- lapply(1:4, function(i) setdiff(1:4, i))
  # above the cap the trivial bound n - 1 is returned without running the heuristic
  expect_identical(.aghq_treewidth_upper_bound(complete4, size_cap = 3L), 3L)
  path <- list(2L, c(1L, 3L), c(2L, 4L), 3L)
  expect_identical(.aghq_treewidth_upper_bound(path, size_cap = 3L), 3L)
})

# ---- Gauss-Hermite nodes and weights (R/aghq-control.R) ---------------------

test_that(".gauss_hermite_physicist integrates low moments exactly", {
  for (k in 1:5) {
    g <- .gauss_hermite_physicist(k)
    expect_length(g$nodes, k)
    expect_length(g$weights, k)
    expect_equal(sum(g$weights), sqrt(pi), tolerance = 1e-12)
    expect_false(is.unsorted(g$nodes))
    expect_equal(g$nodes, -rev(g$nodes), tolerance = 1e-12)       # symmetry
    expect_equal(g$weights, rev(g$weights), tolerance = 1e-12)
    expect_true(all(g$weights > 0))
  }
  # int x^2 exp(-x^2) = sqrt(pi)/2 needs degree 2 <= 2k - 1, i.e. k >= 2
  # int x^4 exp(-x^2) = 3 sqrt(pi)/4 needs degree 4 <= 2k - 1, i.e. k >= 3
  for (k in 2:5) {
    g <- .gauss_hermite_physicist(k)
    expect_equal(sum(g$weights * g$nodes^2), sqrt(pi) / 2, tolerance = 1e-12)
  }
  for (k in 3:5) {
    g <- .gauss_hermite_physicist(k)
    expect_equal(sum(g$weights * g$nodes^4), 3 * sqrt(pi) / 4, tolerance = 1e-12)
  }
})

test_that(".gauss_hermite_physicist k = 1 and k = 2 closed forms", {
  g1 <- .gauss_hermite_physicist(1L)
  expect_equal(g1$nodes, 0)
  expect_equal(g1$weights, sqrt(pi))
  g2 <- .gauss_hermite_physicist(2L)
  expect_equal(g2$nodes, c(-1, 1) / sqrt(2), tolerance = 1e-12)
  expect_equal(g2$weights, rep(sqrt(pi) / 2, 2), tolerance = 1e-12)
  # a whole-number double is accepted
  expect_equal(.gauss_hermite_physicist(3)$nodes[2], 0, tolerance = 1e-12)
})

test_that(".gauss_hermite_physicist refuses bad k", {
  # plain stop(): no condition class beyond simpleError
  for (bad in list(0, -1, 1.5, "a", c(1, 2), NA, NULL)) {
    expect_error(.gauss_hermite_physicist(bad), "k must be a positive integer")
  }
})

test_that(".aghq_grid_selftest recovers the standard-normal moments", {
  st <- .aghq_grid_selftest(c(3L, 5L))
  expect_s3_class(st, "data.frame")
  expect_named(st, c("k", "d", "moment", "target", "value", "abs_error"))
  expect_equal(nrow(st), 10L)
  expect_identical(unique(st$k), c(3L, 5L))
  expect_equal(st$target[1:5], c(1, 1, 3, 1, 1))
  expect_true(all(st$abs_error < 1e-10))
  expect_equal(st$value, st$target, tolerance = 1e-10)
})

# ---- family label (R/aghq-control.R) ----------------------------------------

test_that(".aghq_family_label collapses assorted inputs to one lowercase string", {
  expect_identical(.aghq_family_label(NULL), "")
  expect_identical(.aghq_family_label("Poisson"), "poisson")
  expect_identical(.aghq_family_label(poisson()), "poisson")       # family object
  expect_identical(.aghq_family_label(poisson), "poisson")         # family function
  expect_identical(.aghq_family_label(list(family = "NB2")), "nb2")
  expect_identical(.aghq_family_label(c("a", "B")), "a b")         # mixed-family
  expect_identical(.aghq_family_label(NA_character_), "")
  expect_identical(.aghq_family_label(character(0)), "")
  expect_identical(.aghq_family_label(c("a", NA, "")), "a")        # NA and "" dropped
})

# ---- start index (R/aghq-control.R) -----------------------------------------

test_that(".aghq_start_index picks the starting ladder rung", {
  # high-curvature families start at rung 3 (k = 9), whatever the tier
  for (f in c("tweedie", "ordinal_probit", "ordinal_logit", "zip", "zinb",
              "hurdle_nbinom2", "delta_gamma", "delta_lognormal")) {
    expect_identical(.aghq_start_index(f, "gh"), 3L)
    expect_identical(.aghq_start_index(f, "jj"), 3L)
  }
  # discrete families: rung 1 normally, rung 2 for sparse / jj / rare tiers
  for (f in c("binomial", "bernoulli", "poisson", "nbinom1", "nbinom2")) {
    expect_identical(.aghq_start_index(f, "gh"), 1L)
    expect_identical(.aghq_start_index(f, "jj"), 2L)
    expect_identical(.aghq_start_index(f, "Sparse"), 2L)            # tier lowercased
    expect_identical(.aghq_start_index(f, "rare_events"), 2L)
  }
  # continuous / unknown / empty fall through to the floor
  expect_identical(.aghq_start_index("gaussian", "jj"), 1L)
  expect_identical(.aghq_start_index("", "gh"), 1L)
  expect_identical(.aghq_start_index(NULL, "gh"), 1L)
  expect_identical(.aghq_start_index(NA, "gh"), 1L)
  # family objects go through .aghq_family_label (issue #844)
  expect_identical(.aghq_start_index(poisson(), "gh"), 1L)
  expect_identical(.aghq_start_index(poisson(), "jj"), 2L)
  # matching is by substring, so a mixed-family label hits the highest rung
  expect_identical(.aghq_start_index(c("gaussian", "tweedie"), "gh"), 3L)
  # SUSPECTED QUIRK (pinned, not fixed): "betabinomial" contains "binomial",
  # so it is treated as an ordinary discrete family.
  expect_identical(.aghq_start_index("betabinomial", "jj"), 2L)
})

# ---- optimizer table (R/aghq-control.R) -------------------------------------

test_that(".aghq_optimizer_table returns optimizer and reason per cell", {
  jj <- .aghq_optimizer_table("binomial", "jj")
  expect_named(jj, c("optimizer", "reason"))
  expect_identical(jj$optimizer, "lbfgsb")
  expect_match(jj$reason, "binomial-jj")

  gh <- .aghq_optimizer_table("binomial", "gh")
  expect_named(gh, c("optimizer", "reason"))
  expect_identical(gh$optimizer, "nlminb")
  expect_match(gh$reason, "binomial-gh")

  nb <- .aghq_optimizer_table("nbinom2", "anything")
  expect_identical(nb$optimizer, "nlminb")
  expect_match(nb$reason, "nbinom2")

  unk <- .aghq_optimizer_table("gaussian", "jj")
  expect_identical(unk$optimizer, "nlminb")
  expect_match(unk$reason, "unknown")
  expect_identical(.aghq_optimizer_table("binomial", "other")$reason, unk$reason)
})

test_that(".aghq_optimizer_table normalises family objects and tier case", {
  expect_identical(.aghq_optimizer_table(binomial(), "JJ")$optimizer, "lbfgsb")
  expect_identical(.aghq_optimizer_table(NULL, "jj")$optimizer, "nlminb")
  # SUSPECTED QUIRK (pinned, not fixed): "betabinomial" matches "binomial".
  expect_identical(.aghq_optimizer_table("betabinomial", "jj")$optimizer, "lbfgsb")
})
