## P0 audit fix 2026-05-15: multi-start `obj$report()` / `sdreport(obj)`
## consistency with `fit$opt$par`.
##
## Bug (pre-fix): after the multi-start loop in `R/fit-multi.R`, the
## TMB object's internal `obj$env$last.par` held the FINAL restart's
## last evaluation point, NOT necessarily `best_opt$par`. Calls of
## `obj$report()` (default arg = `last.par`) and
## `TMB::sdreport(obj)` (default arg = `last.par.best`) then returned
## quantities for the wrong parameter vector whenever restart-1 won
## but restart-N (N > 1) ran last. Every downstream extractor reading
## `fit$report` was silently inconsistent with `fit$opt$par` and
## `fit$opt$objective`.
##
## Fix (R/fit-multi.R:1700-1737 in the patched version): force
## `obj$fn(opt$par)`, override `obj$env$last.par.best <-
## obj$env$last.par`, then call `obj$report(opt$par)` and
## `TMB::sdreport(obj, par.fixed = opt$par, ...)` with explicit
## `opt$par` so the report and sdreport are self-consistent
## regardless of TMB's internal state.
##
## Why the existing `test-stage39-multi-start.R` did not catch this:
## that file only checks `fit$opt$convergence == 0L` and
## `is.finite(-fit$opt$objective)`. Neither verifies that
## `fit$report` and `fit$sd_report` are consistent with `fit$opt$par`.

make_multistart_fit <- function(seed = 7L) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 40, n_species = 10, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(1.0, 0.7, -0.3,
                        0.3, -0.5, 0.8), nrow = 3, ncol = 2),
    psi_B = c(0.3, 0.3, 0.3),
    seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) +
            unique(0 + trait | site),
    data    = sim$data,
    control = gllvmTMB::gllvmTMBcontrol(
      n_init     = 3L,
      init_jitter = 1.0   # large jitter so restarts 2-3 walk far
    )
  )))
}

## ---- report consistency with opt$par ------------------------------------

test_that("fit$report matches obj$report(fit$opt$par) after multi-start", {
  skip_on_cran()
  fit <- make_multistart_fit()

  ## Re-fetch the report at fit$opt$par directly from the TMB object;
  ## this is the source-of-truth value the bug-fix guarantees.
  rep_at_opt <- { invisible(fit$tmb_obj$fn(fit$opt$par)); fit$tmb_obj$report() }

  ## Lambda_B is the headline quantity every downstream extractor
  ## reads. Mismatch here would propagate to extract_Sigma,
  ## extract_correlations, extract_communality, ordination, etc.
  expect_equal(fit$report$Lambda_B, rep_at_opt$Lambda_B,
               tolerance = 1e-12)

  ## sd_B (the unique-variance diagonal SDs) is the second
  ## extractor-load-bearing quantity.
  expect_equal(fit$report$sd_B, rep_at_opt$sd_B,
               tolerance = 1e-12)

  ## eta (the linear predictor) drives mu_t in link_residual_per_trait().
  expect_equal(fit$report$eta, rep_at_opt$eta,
               tolerance = 1e-12)
})

## ---- sd_report at opt$par -----------------------------------------------

test_that("fit$sd_report$par.fixed equals fit$opt$par after multi-start", {
  skip_on_cran()
  fit <- make_multistart_fit()

  ## par.fixed is what sdreport() was evaluated at; if the bug were
  ## back, this would equal obj$env$last.par.best, which after a
  ## non-monotone multi-start sequence may not match opt$par.
  expect_equal(unname(fit$sd_report$par.fixed),
               unname(fit$opt$par),
               tolerance = 1e-12)
})

## ---- objective consistency ----------------------------------------------

test_that("logLik(fit) equals -fit$opt$objective, both at opt$par", {
  skip_on_cran()
  fit <- make_multistart_fit()

  expect_equal(as.numeric(stats::logLik(fit)),
               -fit$opt$objective, tolerance = 1e-10)

  ## And `obj$fn(opt$par)` should reproduce `opt$objective`. This is
  ## the cross-check the audit explicitly named.
  expect_equal(as.numeric(fit$tmb_obj$fn(fit$opt$par)),
               fit$opt$objective, tolerance = 1e-10)
})

## ---- downstream extractors land on opt$par values ----------------------

test_that("extract_Sigma reads the opt$par-aligned report", {
  skip_on_cran()
  fit <- make_multistart_fit()

  S_from_fit <- gllvmTMB::extract_Sigma(fit, level = "unit",
                                        part = "total")$Sigma

  ## Recompute Sigma from a fresh report at opt$par:
  ## Sigma_B_total = Lambda_B Lambda_B^T + diag(sd_B^2) +
  ##                 link_residual_per_trait().
  ## We compare only the shared part (Lambda Lambda^T), which is the
  ## piece the bug would mis-align if `fit$report$Lambda_B` were
  ## taken from the wrong restart.
  rep_ref <- { invisible(fit$tmb_obj$fn(fit$opt$par)); fit$tmb_obj$report() }
  L_ref   <- rep_ref$Lambda_B
  shared_ref <- tcrossprod(L_ref)

  L_fit <- fit$report$Lambda_B
  shared_fit <- tcrossprod(L_fit)

  expect_equal(shared_fit, shared_ref, tolerance = 1e-12)
  ## And of course extract_Sigma reads through fit$report and so must
  ## also be at the opt$par values. We don't assert exact equality
  ## with shared_ref (extract_Sigma adds the diagonal s_B^2 + link
  ## residual), only that extract_Sigma's shared component is
  ## consistent.
  expect_equal(
    unname(gllvmTMB::extract_Sigma(fit, level = "unit", part = "shared")$Sigma),
    unname(shared_fit), tolerance = 1e-10
  )
})

## ---- n_init = 1 is unaffected (regression guard) -----------------------

test_that("n_init = 1 still produces a consistent fit (no regression)", {
  skip_on_cran()
  set.seed(13)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 8, n_traits = 3,
    mean_species_per_site = 3,
    Lambda_B = matrix(c(0.8, 0.5, -0.2), 3, 1),
    psi_B    = c(0.3, 0.3, 0.3),
    seed     = 13
  )
  fit1 <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
            unique(0 + trait | site),
    data    = sim$data,
    control = gllvmTMB::gllvmTMBcontrol(n_init = 1L)
  )))
  invisible(fit1$tmb_obj$fn(fit1$opt$par))
  rep_ref <- fit1$tmb_obj$report()
  expect_equal(fit1$report$Lambda_B, rep_ref$Lambda_B,
               tolerance = 1e-12)
  expect_equal(unname(fit1$sd_report$par.fixed),
               unname(fit1$opt$par), tolerance = 1e-12)
})
