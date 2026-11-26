## refs #1926 — converged rule requires pd_hessian, finite SEs, and a
## Newton step within 1e-3 standard errors (26 Nov 2026).

test_that("convergence_status: non-PD Hessian or non-finite SE is degenerate", {
  st <- gllvmTMB:::.gllvmTMB_convergence_status
  ok <- list(
    optimizer_converged = TRUE,
    obj_val = 50,
    premature_termination = FALSE,
    stationary_by_gradient = TRUE,
    n_boundary = 0L,
    pd_hessian = TRUE,
    se_nonfinite = FALSE,
    newton_se_ratio = 0,
    newton_se_applicable = TRUE
  )
  call <- function(...) do.call(st, utils::modifyList(ok, list(...)))
  expect_identical(call(), "converged")
  expect_identical(call(newton_se_ratio = 1e-3), "converged")
  expect_identical(call(newton_se_ratio = 1e-3 + 1e-9), "not_converged")
  expect_identical(call(newton_se_ratio = NA_real_), "not_converged")
  expect_identical(call(pd_hessian = FALSE, newton_se_ratio = 10), "degenerate")
  expect_identical(call(se_nonfinite = TRUE, newton_se_ratio = 10), "degenerate")
  expect_identical(call(n_boundary = 1L), "boundary")
  expect_identical(call(n_boundary = 1L, pd_hessian = FALSE), "boundary")
  ## No sdreport: the Newton gate does not apply, and a stored ratio is ignored.
  expect_identical(
    call(newton_se_applicable = FALSE, newton_se_ratio = 10),
    "converged"
  )
})

test_that("Newton-SE ratio is max |(H^-1 g)_i| / SE_i", {
  ratio <- gllvmTMB:::.gllvmTMB_newton_se_ratio
  ## Diagonal covariance: |(H^-1 g)_i| / SE_i = |g_i| * SE_i.
  expect_equal(ratio(c(1e-3, 0), diag(2)), 1e-3)
  ## Off-diagonal mass changes the step. A diagonal |g|*SE shortcut is 1e-3.
  g <- c(1e-3, -1e-3)
  Hinv <- matrix(c(1, 0.5, 0.5, 1), 2, 2)
  expect_equal(ratio(g, Hinv), 5e-4)
  ## Named covariance is aligned to the gradient, not to storage order.
  ## Stored as (b, a). Positional use of g = c(a, b) would score 1e-3.
  named <- matrix(c(1, 0.5, 0.5, 4), 2, 2)
  dimnames(named) <- list(c("b", "a"), c("b", "a"))
  expect_equal(ratio(c(a = 1e-3, b = 0), named), 2e-3)
  expect_true(is.na(ratio(c(1, NA), diag(2))))
  expect_true(is.na(ratio(c(1, 1), diag(c(1, -1)))))
})

## Stationary optimum whose reported Hessian is not positive definite.
## The covariance diagonal is positive and the gradient is tiny, so the
## only reason the status is not `converged` is `pdHess = FALSE`. The
## matrix is indefinite on every platform; nothing is read from BLAS.
nonpd_stationary_fit_1926 <- function() {
  g <- c(1e-8, 1e-8)
  indefinite <- matrix(c(1, 2, 2, 1), 2, 2)
  structure(list(
    tmb_obj = list(par = c(0, 0), gr = function(par) g),
    opt = list(
      par = c(0, 0),
      objective = 25,
      convergence = 0L,
      iterations = 12L,
      message = "relative convergence"
    ),
    sd_report = list(
      pdHess = FALSE,
      cov.fixed = indefinite,
      par.random = c(b_fix = 0),
      diag.cov.random = 0.01
    ),
    X_fix_names = "traitA",
    report = list(),
    use = list()
  ), class = "gllvmTMB_multi")
}

test_that("#1926: non-PD Hessian at a stationary point is not converged", {
  fit <- nonpd_stationary_fit_1926()
  fit$fit_health <- gllvmTMB:::.gllvmTMB_build_fit_health(fit)
  warned <- FALSE
  withCallingHandlers(
    gllvmTMB:::.gllvmTMB_warn_fit_health_convergence(fit$fit_health),
    warning = function(w) {
      if (inherits(w, "gllvmTMB_fit_health_not_converged")) warned <<- TRUE
      invokeRestart("muffleWarning")
    }
  )
  expect_true(warned)
  expect_false(isTRUE(fit$fit_health$pd_hessian))
  expect_false(isTRUE(fit$fit_health$se_nonfinite))
  expect_true(isTRUE(fit$fit_health$stationary_by_gradient))
  expect_false(isTRUE(fit$fit_health$converged))
  expect_true(fit$fit_health$convergence_status %in% c("boundary", "degenerate"))
  expect_identical(fit$fit_health$convergence_status, "degenerate")
})

newton_gate_fit_1926 <- function(gradient, covariance) {
  g <- as.numeric(gradient)
  structure(list(
    tmb_obj = list(
      par = numeric(length(g)),
      gr = function(par) g
    ),
    opt = list(
      par = numeric(length(g)),
      objective = 25,
      convergence = 0L,
      iterations = 12L,
      message = "relative convergence"
    ),
    sd_report = list(
      pdHess = TRUE,
      cov.fixed = covariance,
      par.random = c(b_fix = 0),
      diag.cov.random = 0.01
    ),
    X_fix_names = "traitA",
    report = list(),
    use = list()
  ), class = "gllvmTMB_multi")
}

test_that("Newton-SE above 1e-3 is not labelled converged", {
  ## max |g| = 5e-3 is under the raw 1e-2 gate. SE = 1, so
  ## |(H^-1 g)| / SE = 5e-3, which fails the Newton-SE rule.
  fit <- newton_gate_fit_1926(5e-3, diag(1))
  h <- gllvmTMB:::.gllvmTMB_build_fit_health(fit)
  expect_lt(h$max_gradient, 1e-2)
  expect_true(isTRUE(h$pd_hessian))
  expect_false(isTRUE(h$se_nonfinite))
  expect_true(isTRUE(h$stationary_by_gradient))
  expect_gt(h$newton_se_ratio, 1e-3)
  expect_false(isTRUE(h$converged))
  expect_identical(h$convergence_status, "not_converged")
})

test_that("Newton-SE at or under 1e-3 is labelled converged", {
  fit <- newton_gate_fit_1926(1e-6, diag(1))
  h <- gllvmTMB:::.gllvmTMB_build_fit_health(fit)
  expect_lte(h$newton_se_ratio, 1e-3)
  expect_true(isTRUE(h$optimizer_converged))
  expect_true(isTRUE(h$pd_hessian))
  expect_false(isTRUE(h$se_nonfinite))
  expect_true(isTRUE(h$converged))
  expect_identical(h$convergence_status, "converged")

  ## The bound is inclusive: ratio == 1e-3 still converges.
  on_bound <- newton_gate_fit_1926(1e-3, diag(1))
  h_bound <- gllvmTMB:::.gllvmTMB_build_fit_health(on_bound)
  expect_equal(h_bound$newton_se_ratio, 1e-3)
  expect_true(isTRUE(h_bound$converged))
})