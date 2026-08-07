test_that("Design 110 registry contains exactly the 18 scalar family/link cells", {
  expect_length(.va_oracle_cells, 18L)
  expect_setequal(vapply(.va_oracle_cells, `[[`, integer(1), "family_id"), 0:15)
  binomial <- .va_oracle_cells[
    vapply(.va_oracle_cells, function(x) x$family_id == 1L, logical(1))]
  expect_setequal(vapply(binomial, `[[`, character(1), "link"),
                  c("logit", "probit", "cloglog"))
  expect_false(16L %in% vapply(.va_oracle_cells, `[[`, integer(1), "family_id"))
})

test_that("every scalar oracle converges to its conditional density as v tends to zero", {
  for (name in names(.va_oracle_cells)) {
    cell <- .va_oracle_cells[[name]]
    conditional <- .va_oracle_log_density(cell, cell$mu)
    near_point_mass <- .va_oracle_gh_expectation(cell, v = 1e-10, H = 7L)
    expect_equal(near_point_mass, conditional, tolerance = 2e-8, info = name)
  }
})

test_that("closed-form expectations equal direct adaptive scalar integration", {
  exact_names <- names(Filter(function(x) x$route == "exact", .va_oracle_cells))
  expect_setequal(exact_names,
                  c("gaussian_identity", "poisson_log", "lognormal_log", "gamma_log"))
  for (name in exact_names) {
    cell <- .va_oracle_cells[[name]]
    analytic <- .va_oracle_exact_expectation(cell)
    adaptive <- .va_oracle_adaptive_expectation(cell)
    expect_equal(analytic, adaptive, tolerance = 1e-10, info = name)
  }
})

test_that("H7 and hybrid expectations meet the ordinary adaptive-oracle gate", {
  gh_names <- names(Filter(function(x) x$route != "exact", .va_oracle_cells))
  for (name in gh_names) {
    cell <- .va_oracle_cells[[name]]
    candidate <- if (cell$route == "hybrid")
      .va_oracle_exact_expectation(cell, H = 7L) else
      .va_oracle_gh_expectation(cell, H = 7L)
    adaptive <- .va_oracle_adaptive_expectation(cell)
    expect_lt(abs(candidate - adaptive), .va_oracle_ordinary_tolerance[[name]],
              label = sprintf("%s: abs(H7-adaptive), H7=%0.12g adaptive=%0.12g",
                              name, candidate, adaptive))
  }
})

test_that("the lightweight H ladder is finite and H61 matches adaptive integration", {
  ladder <- c(5L, 7L, 9L, 15L, 61L)
  gh_names <- names(Filter(function(x) x$route != "exact", .va_oracle_cells))
  for (name in gh_names) {
    cell <- .va_oracle_cells[[name]]
    values <- vapply(ladder, function(H) {
      if (cell$route == "hybrid") .va_oracle_exact_expectation(cell, H = H) else
        .va_oracle_gh_expectation(cell, H = H)
    }, numeric(1))
    adaptive <- .va_oracle_adaptive_expectation(cell)
    expect_true(all(is.finite(values)), info = name)
    expect_lt(abs(values[[length(values)]] - adaptive), 2e-8,
              label = paste(name, "abs(H61-adaptive)"))
  }
})

test_that("predeclared tail fixtures meet the family-specific H7 gate", {
  gh_names <- names(Filter(function(x) x$route != "exact", .va_oracle_cells))
  for (name in gh_names) {
    cell <- .va_oracle_cells[[name]]
    ## A larger latent variance moves H7 nodes into both tails without relying
    ## on H61's numerically harsher 14.5-SD reach.
    tail_v <- min(0.30, max(0.18, cell$v * 2))
    h7 <- if (cell$route == "hybrid")
      .va_oracle_exact_expectation(cell, v = tail_v, H = 7L) else
      .va_oracle_gh_expectation(cell, v = tail_v, H = 7L)
    adaptive <- .va_oracle_adaptive_expectation(cell, v = tail_v)
    expect_lt(abs(h7 - adaptive), .va_oracle_tail_tolerance[[name]],
              label = sprintf("%s abs(H7-adaptive) at v=%g", name, tail_v))
  }
})

test_that("compiled bridge assumptions stay explicit and do not admit multinomial", {
  expect_identical(.va_oracle_bridge_contract$family_ids, 0:15)
  expect_identical(unname(.va_oracle_bridge_contract$binomial_link_ids), 0:2)
  expect_identical(.va_oracle_bridge_contract$quadrature_order, 7L)
  expect_identical(.va_oracle_bridge_contract$excluded_family_ids, 16L)
})
