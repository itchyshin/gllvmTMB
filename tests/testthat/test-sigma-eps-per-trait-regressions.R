## Issue #856 -- CHEAP regressions for the two defects the adversarial review
## found in the per-trait `sigma_eps` promotion.
##
## Deliberately gated with `skip_on_cran()` ONLY, not `skip_if_not_heavy()`.
## The recovery tests for this feature are gated behind BOTH, and routine CI
## leaves `GLLVMTMB_HEAVY_TESTS` unset by design, so neither of the regressions
## below would surface in CI if guarded only there. These fixtures are small
## enough to run every time: reverting either fix must turn CI red.

test_that("#856: a trait with no Gaussian/lognormal rows does not leave a flat sigma_eps direction", {
  skip_on_cran()

  ## Gaussian trait + Poisson trait. The Poisson trait has NO rows with family
  ## id in {0, 3}, so its `log_sigma_eps` entry has no data. Before the fix it
  ## stayed free: gradient exactly zero, Hessian not positive-definite, and the
  ## frozen `lm` start value was reported as an estimated residual scale.
  set.seed(108)
  n_unit <- 60L
  R_rep <- 2L
  u <- cbind(stats::rnorm(n_unit), stats::rnorm(n_unit))
  d <- do.call(rbind, lapply(seq_len(n_unit), function(i) {
    rbind(
      data.frame(unit = i, trait = "t1", fam = "g",
                 value = u[i, 1] + stats::rnorm(R_rep, 0, 0.5)),
      data.frame(unit = i, trait = "t2", fam = "p",
                 value = stats::rpois(R_rep, lambda = 3))
    )
  }))
  d$unit <- factor(d$unit)
  d$trait <- factor(d$trait)
  d$fam <- factor(d$fam, levels = c("g", "p"))
  fl <- list(gaussian(), poisson())
  attr(fl, "family_var") <- "fam"

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | unit),
    data = d, unit = "unit", trait = "trait", family = fl
  )))

  ## The Poisson trait's entry must be mapped off, leaving exactly one free.
  map_eps <- fit$tmb_obj$env$map$log_sigma_eps
  expect_false(is.null(map_eps))
  expect_true(is.na(as.vector(map_eps)[2L]))
  expect_false(is.na(as.vector(map_eps)[1L]))
  expect_equal(sum(names(fit$opt$par) == "log_sigma_eps"), 1L)

  ## The symptom that reached users: a non-PD Hessian.
  expect_true(isTRUE(fit$sd_report$pdHess))

  ## And a fabricated residual scale for the Poisson trait, marked PASS.
  health <- check_gllvmTMB(fit)
  eps_rows <- health$component[grepl("^boundary_sigma_eps", health$component)]
  expect_true(any(grepl("t1", eps_rows)))
  expect_false(any(grepl("t2", eps_rows)))
})

test_that("#856: a trait mixing identity- and log-scale rows warns rather than pooling silently", {
  skip_on_cran()

  ## Family is per ROW, so one trait can carry both Gaussian and lognormal
  ## rows. Per-trait `sigma_eps` gives such a trait a single residual SD
  ## spanning both scales, which is interpretable on neither. It must not be
  ## reported without qualification.
  set.seed(109)
  n_unit <- 60L
  uu <- stats::rnorm(n_unit)
  d <- do.call(rbind, lapply(seq_len(n_unit), function(i) {
    rbind(
      data.frame(unit = i, trait = "A", fam = "g",
                 value = 10 + uu[i] + stats::rnorm(2, 0, 3.0)),
      data.frame(unit = i, trait = "A", fam = "l",
                 value = exp(1 + 0.2 * stats::rnorm(2))),
      data.frame(unit = i, trait = "B", fam = "g",
                 value = uu[i] + stats::rnorm(2, 0, 1.0))
    )
  }))
  d$unit <- factor(d$unit)
  d$trait <- factor(d$trait)
  d$fam <- factor(d$fam, levels = c("g", "l"))
  fl <- list(gaussian(), lognormal())
  attr(fl, "family_var") <- "fam"

  expect_warning(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + indep(0 + trait | unit),
      data = d, unit = "unit", trait = "trait", family = fl
    )),
    regexp = "both Gaussian and lognormal"
  )
})
