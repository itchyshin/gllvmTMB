test_that("Design 86 frozen Gate-1 fixture is readable and checksummed", {
  skip_if_not_installed("jsonlite")
  path <- .eva_gate1_file()
  expect_equal(unname(tools::sha256sum(path)),
               "a3cb2b9302132b2a917639ac30ce070d5d0f67e9c21f50ffbcc232ead448b036")
  expect_identical(.eva_read_gate1_parameters()$status, "FROZEN_GATE1_ONLY")
  x <- .eva_fixture("bernoulli")
  malformed <- x; malformed$y[[1L]] <- 2
  expect_error(.eva_validate_fixture(malformed, 1L), "Bernoulli")
  duplicate <- x; duplicate$trait_id[[2L]] <- duplicate$trait_id[[1L]]
  expect_error(.eva_validate_fixture(duplicate, 1L), "complete")
})

test_that("Design 86 Bernoulli EVA template equals the independent scalar oracle", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("jsonlite")
  x <- .eva_fixture("bernoulli")
  obj <- .eva_make_objective("bernoulli", rebuild = TRUE)
  expect_equal(-.eva_evaluate(obj), .eva_scalar_bernoulli(x), tolerance = 1e-10)
  report <- obj$report(obj$par)
  expected_kl <- vapply(seq_len(x$N), function(i) {
    A <- exp(2 * x$log_A_diag[i, 1L])
    0.5 * (A + x$a[i, 1L]^2 - 2 * x$log_A_diag[i, 1L] - x$q)
  }, numeric(1))
  expect_equal(report$kl_by_unit, expected_kl, tolerance = 1e-12)
  expect_equal(report$negative_ell_eva, .eva_evaluate(obj), tolerance = 1e-12)

  q2 <- .eva_fixture("bernoulli_q2")
  q2_obj <- .eva_make_objective("bernoulli_q2")
  expect_equal(-.eva_evaluate(q2_obj), .eva_scalar_bernoulli(q2), tolerance = 1e-10)
  expect_true(isTRUE(attr(q2_obj, "eva_provenance")$research_only))
  expect_identical(attr(q2_obj, "eva_provenance")$objective_type, "EVA_TAYLOR2")

  idx <- c(2L, 1L, 3L, 6L, 4L, 5L)
  permuted <- q2
  permuted$y <- q2$y[idx]
  permuted$X <- q2$X[idx, , drop = FALSE]
  permuted$unit_id <- q2$unit_id[idx]
  permuted$trait_id <- q2$trait_id[idx]
  permuted_obj <- TMB::MakeADFun(
    data = c(permuted[c("y", "X", "unit_id", "trait_id", "N", "T", "q", "gaussian_sd")], family = 1L),
    parameters = permuted[c("beta", "theta_rr", "a", "log_A_diag", "A_off")],
    random = NULL, DLL = attr(q2_obj, "eva_dll")$DLL, silent = TRUE
  )
  expect_equal(-.eva_evaluate(permuted_obj), .eva_scalar_bernoulli(permuted), tolerance = 1e-10)
})

test_that("Design 86 test-only Gaussian branch is Taylor exact", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("jsonlite")
  x <- .eva_fixture("gaussian")
  obj <- .eva_make_objective("gaussian")
  expect_equal(-.eva_evaluate(obj), .eva_scalar_gaussian(x), tolerance = 1e-10)
})

test_that("Design 86 autodiff and small-variance behaviour meet Gate 1", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("jsonlite")
  obj <- .eva_make_objective("bernoulli")
  analytic <- .eva_evaluate(obj, gradient = TRUE)$gradient
  numeric <- vapply(seq_along(obj$par), function(j) {
    h <- 1e-6 * max(1, abs(obj$par[j]))
    plus <- minus <- obj$par; plus[j] <- plus[j] + h; minus[j] <- minus[j] - h
    (.eva_evaluate(obj, plus) - .eva_evaluate(obj, minus)) / (2 * h)
  }, numeric(1))
  expect_lt(max(abs(analytic - numeric) / pmax(1, abs(numeric))), 1e-5)

  theta <- which(names(obj$par) == "theta_rr")[1L]
  probe <- function(value) {
    par <- obj$par; par[theta] <- value
    evaluated <- .eva_evaluate(obj, par, gradient = TRUE)
    c(value = evaluated$value, gradient = evaluated$gradient[theta])
  }
  at_zero <- probe(0); near_zero <- probe(1e-8)
  expect_lt(abs(at_zero[["value"]] - near_zero[["value"]]), 1e-8)
  expect_lt(abs(at_zero[["gradient"]] - near_zero[["gradient"]]), 1e-7)

  # Deliberately violate the log-Cholesky diagonal's safe exponential domain.
  bad <- obj$par
  bad[which(names(bad) == "log_A_diag")[1L]] <- 1000
  expect_error(.eva_evaluate(obj, bad), "Cholesky diagonal")
})

test_that("Design 86 AGHQ marginal probe is converged and intentionally unsigned", {
  skip_if_not_installed("jsonlite")
  x <- .eva_fixture("d3_marginal_probe")
  d3 <- .eva_read_gate1_parameters()$gate1$d3_marginal_probe
  ladder <- vapply(as.integer(unlist(d3$quadrature_orders)), function(H) .eva_aghq_marginal_q1(x, H), numeric(1))
  expect_true(all(is.finite(ladder)))
  expect_lt(max(abs(ladder - ladder[[3L]])), 1e-10)
  obj <- .eva_make_objective("d3_marginal_probe")
  signed_measurement <- -.eva_evaluate(obj) - ladder[[3L]]
  expect_true(is.finite(signed_measurement))
  expect_equal(signed_measurement, as.numeric(d3$diagnostic_reference_value),
               tolerance = as.numeric(d3$diagnostic_tolerance))
})

test_that("Design 86 D4 reproduces the sparse exact-ELBO remainder sign", {
  skip_if_not_installed("jsonlite")
  d <- .eva_read_gate1_parameters()$gate1$d4_remainder
  mu <- as.numeric(d$mu); h <- 1e-2; p <- plogis(mu)
  s <- .eva_softplus_R
  fourth_fd <- (s(mu - 2 * h) - 4 * s(mu - h) + 6 * s(mu) - 4 * s(mu + h) + s(mu + 2 * h)) / h^4
  fourth_exact <- p * (1 - p) * (1 - 6 * p + 6 * p^2)
  expect_equal(fourth_fd, fourth_exact, tolerance = 1e-5)
  roots <- sort((3 + c(-1, 1) * sqrt(3)) / 6)
  expect_equal(roots, as.numeric(unlist(d$analytic_root_probability)), tolerance = 1e-15)
  remainder <- .eva_d4_remainder()
  expect_lt(remainder$upper_3se, 0)
})
