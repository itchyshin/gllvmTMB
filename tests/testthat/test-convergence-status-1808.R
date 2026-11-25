## Adopted converged rule (SHINICHI-1434-1119): fit_health$convergence_status.
## #1808: binomial BFGS fit on vegan::dune had opt$convergence 0 and raw
## max|g| 0.004 (< the old absolute 1e-2 gate) but a loading near 520.

test_that("status function: first match wins, boundary before Hessian", {
  st <- gllvmTMB:::.gllvmTMB_convergence_status
  ok <- list(optimizer_converged = TRUE, obj_val = 10,
             premature_termination = FALSE, newton_se_gradient = 1e-8,
             n_boundary = 0L, pd_hessian = TRUE, se_nonfinite = FALSE)
  call <- function(...) do.call(st, utils::modifyList(ok, list(...)))
  expect_identical(call(), "converged")
  expect_identical(call(optimizer_converged = FALSE), "not_converged")
  expect_identical(call(obj_val = Inf), "not_converged")
  expect_identical(call(newton_se_gradient = 1e-2), "not_converged")
  expect_identical(call(newton_se_gradient = NA_real_), "not_converged")
  expect_identical(call(n_boundary = 1L), "boundary")
  expect_identical(call(n_boundary = 1L, pd_hessian = FALSE), "boundary")
  expect_identical(call(optimizer_converged = FALSE, n_boundary = 1L),
                   "not_converged")
  expect_identical(call(pd_hessian = FALSE), "degenerate")
  expect_identical(call(se_nonfinite = TRUE), "degenerate")
  expect_identical(
    call(pd_hessian = NA, newton_se_gradient = NA_real_),
    "not_converged"
  )
  expect_identical(call(se_skipped = TRUE, pd_hessian = NA), "converged")
  expect_identical(call(se_skipped = TRUE, newton_se_gradient = NA_real_),
                   "converged")
})

test_that("Newton-in-SE gradient helper is NA when curvature is unusable", {
  ng <- gllvmTMB:::.gllvmTMB_newton_se_gradient
  g <- c(0.001, 0.0005)
  cov_pd <- diag(c(0.25, 0.04))
  expect_lt(ng(g, list(pdHess = TRUE, cov.fixed = cov_pd)),
            gllvmTMB:::.gllvmTMB_converged_newton_gtol)
  expect_true(is.na(ng(g, list(pdHess = FALSE, cov.fixed = cov_pd))))
  expect_true(is.na(ng(c(NA, 0.01), list(pdHess = TRUE, cov.fixed = cov_pd))))
})

test_that("relative gradient remains a descriptive diagnostic", {
  rg <- gllvmTMB:::.gllvmTMB_relative_gradient
  expect_equal(rg(c(0.004), c(500), 70), rg(c(0.004 * 100), c(5), 70))
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

test_that("se = FALSE: converged without Hessian check and check_gllvmTMB NOTE", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE,
                       lifecycle_verbosity = "quiet")
  set.seed(2)
  n <- 40L
  p <- 3L
  df <- expand.grid(
    unit = factor(paste0("u", seq_len(n))),
    trait = factor(paste0("t", seq_len(p))),
    KEEP.OUT.ATTRS = FALSE
  )
  z <- stats::rnorm(n)
  df$value <- z[as.integer(df$unit)] * c(0.9, 0.6, -0.4)[as.integer(df$trait)] +
    stats::rnorm(nrow(df))
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df, unit = "unit", trait = "trait", family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
  h <- fit$fit_health
  expect_true(isTRUE(h$se_skipped))
  expect_true(is.na(h$pd_hessian))
  expect_identical(h$convergence_status, "converged")
  expect_true(isTRUE(h$converged))
  chk <- check_gllvmTMB(fit)
  expect_equal(chk$status[chk$component == "hessian_se_skipped"], "NOTE")
  expect_equal(chk$status[chk$component == "pd_hessian"], "NOTE")
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
      n_init = 1L, se = TRUE, svd_start = TRUE,
      optimizer = "optim", optArgs = list(method = "BFGS")
    )
  )))
  h <- fit$fit_health
  expect_identical(h$convergence, 0L)
  ## Optimizer reports success but Newton-in-SE gradient fails before boundary.
  expect_identical(h$convergence_status, "not_converged")
  expect_false(isTRUE(h$converged))
  expect_gt(nrow(h$boundary_params), 0L)
})