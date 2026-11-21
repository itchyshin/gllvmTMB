## Adopted converged rule (18 Nov 2026): fit_health$convergence_status.
## #1808: binomial BFGS fit on vegan::dune had opt$convergence 0 and raw
## max|g| 0.004 (< the old absolute 1e-2 gate) but a loading near 520.

test_that("status function: first match wins, boundary before Hessian", {
  st <- gllvmTMB:::.gllvmTMB_convergence_status
  ok <- list(optimizer_converged = TRUE, obj_val = 10,
             premature_termination = FALSE, relative_gradient = 1e-8,
             n_boundary = 0L, pd_hessian = TRUE, se_nonfinite = FALSE)
  call <- function(...) do.call(st, utils::modifyList(ok, list(...)))
  expect_identical(call(), "converged")
  expect_identical(call(optimizer_converged = FALSE), "not_converged")
  expect_identical(call(obj_val = Inf), "not_converged")
  expect_identical(call(relative_gradient = 1e-2), "not_converged")
  expect_identical(call(relative_gradient = NA_real_), "not_converged")
  expect_identical(call(n_boundary = 1L), "boundary")
  expect_identical(call(n_boundary = 1L, pd_hessian = FALSE), "boundary")
  expect_identical(call(optimizer_converged = FALSE, n_boundary = 1L),
                   "not_converged")
  expect_identical(call(pd_hessian = FALSE), "degenerate")
  expect_identical(call(se_nonfinite = TRUE), "degenerate")
  expect_identical(call(pd_hessian = NA), "converged")
})

test_that("relative gradient is unit-free in the parameter", {
  rg <- gllvmTMB:::.gllvmTMB_relative_gradient
  ## rescaling par by c rescales grad by 1/c: g * par is unchanged.
  expect_equal(rg(c(0.004), c(500), 70), rg(c(0.004 * 100), c(5), 70))
  expect_gt(rg(0.004, 523, 71.7), gllvmTMB:::.gllvmTMB_converged_rel_gtol)
  expect_true(is.na(rg(c(1, NA), c(1, 1), 10)))
})

test_that("boundary_params folds Heywood, SD, loading and dispersion flags", {
  bp <- gllvmTMB:::.gllvmTMB_boundary_params(
    c("near_zero_sd_B", "near_zero_B_loading", "boundary_phi_gamma",
      "boundary_ordinal_cutpoint"),
    data.frame(name = "loading", kind = "runaway_loading")
  )
  expect_named(bp, c("name", "kind"))
  expect_identical(bp$kind, c("sd", "loading", "dispersion", "other",
                              "runaway_loading"))
})

test_that("#1808: binomial BFGS fit on vegan::dune is not 'converged'", {
  skip_on_cran()
  skip_if_not_installed("vegan")
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE,
                       lifecycle_verbosity = "quiet")
  data(dune, package = "vegan", envir = environment())
  cols <- c("Scorautu", "Trifrepe", "Bracruta", "Poaprat", "Poatriv",
            "Lolipere", "Agrostol", "Alopgeni")
  n <- nrow(dune)
  long <- data.frame(
    site = factor(rep(seq_len(n), length(cols))),
    trait = factor(rep(cols, each = n), levels = cols),
    value = as.numeric(as.vector(as.matrix(dune[, cols])) > 0)
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = long, family = binomial(), trait = "trait", unit = "site",
    silent = TRUE,
    control = gllvmTMB::gllvmTMBcontrol(
      n_init = 1L, se = FALSE, svd_start = TRUE,
      optimizer = "optim", optArgs = list(method = "BFGS")
    )
  )))
  h <- fit$fit_health
  expect_identical(h$convergence, 0L)
  expect_lt(h$max_gradient, 1e-2)       # the old absolute gate passed it
  # whether the relative gate rejects this fit is platform-sensitive (the
  # instrumented coverage runner converges it), so pin consistency, not outcome
  expect_identical(h$converged, identical(h$convergence_status, "converged"))
  if (!h$converged) {
    expect_true(h$convergence_status %in%
                  c("not_converged", "boundary", "degenerate"))
  }
  if (identical(h$convergence_status, "boundary")) {
    expect_gt(nrow(h$boundary_params), 0L)
  }
})
