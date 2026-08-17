## #1092: `aghq_ridge` is applied at the R level, OUTSIDE the TMB objective, so
## `tmb_obj$gr()` is the gradient of a function the optimiser was NOT
## minimising. Every reader of that gradient -- `fit_health$max_gradient`
## first -- therefore reports a number with no reason to be near zero on a
## ridged fit, and the `converged` conjunction reads a genuinely converged
## MAP fit as unconverged. At the penalised optimum the raw gradient on the
## loading block is exactly `|lambda| / tau^2` (the missing ridge term), which
## for a ridged Bernoulli toy sits ~0.44 against a gtol of 1e-2.
##
## The contract under test: gradient-based convergence reporting must judge
## the objective the fit actually optimised. Raw-vs-penalised remains
## DISCLOSED (the raw gradient stays reachable via `tmb_obj$gr()` and the
## fit_health surface labels the penalised reading), mirroring how
## `.aghq_check_penalised()` disclosed the logLik/AIC half of the same defect.

.pg_ridged_bernoulli_fit <- function(tau = 2) {
  set.seed(11L)
  n <- 30L
  p <- 3L
  L <- matrix(stats::rnorm(p), p, 1L)
  u <- stats::rnorm(n)
  eta <- outer(u, as.numeric(L))
  Y <- matrix(stats::rbinom(n * p, 1, stats::plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  dat <- as.data.frame(Y)
  dat$site <- factor(seq_len(n))
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(sp1, sp2, sp3) ~ 1 + latent(1 | site, d = 1),
    data = dat,
    family = stats::binomial(),
    control = gllvmTMB::gllvmTMBcontrol(
      aghq_ridge = tau, se = FALSE, warn_runaway = FALSE
    )
  )))
}

test_that("#1092: fit_health$max_gradient judges the objective the ridged fit optimised", {
  skip_on_cran()

  fit <- .pg_ridged_bernoulli_fit(tau = 2)
  expect_true(isTRUE(fit$aghq$penalised))
  expect_identical(fit$aghq$ridge_tau, 2)
  expect_identical(fit$opt$convergence, 0L)

  ## The truth, computed by hand at the reported optimum: raw gradient plus
  ## the ridge term on the loading block.
  par <- fit$opt$par
  g <- as.numeric(fit$tmb_obj$gr(par))
  li <- which(names(fit$tmb_obj$par) == "theta_rr_B")
  expect_gt(length(li), 0L)
  g_pen <- g
  g_pen[li] <- g_pen[li] + par[li] / (fit$aghq$ridge_tau^2)

  ## Sanity on the fixture itself: the fit IS stationary for its own
  ## objective, and the raw gradient is dominated by the missing ridge term
  ## (|lambda|/tau^2 >> gtol), so the two readings genuinely disagree here.
  ## If this block ever fails the fixture has drifted, not the fix.
  expect_lt(max(abs(g_pen)), 1e-3)
  expect_gt(max(abs(g)), 1e-1)

  ## THE DEFECT (#1092): the reported gradient must match the penalised
  ## objective's gradient, not the unpenalised one's.
  expect_lt(fit$fit_health$max_gradient, 1e-3)

  ## ... and the convergence conjunction must therefore accept this fit.
  expect_true(fit$fit_health$stationary_by_gradient)
  expect_true(fit$fit_health$converged)
})

test_that("#1092: an unpenalised fit's gradient reporting is unchanged", {
  skip_on_cran()

  ## ridge_tau = Inf: the penalty vanishes and the penalised gradient IS the
  ## raw gradient -- the fix must be an identity here.
  fit <- .pg_ridged_bernoulli_fit(tau = Inf)
  expect_false(isTRUE(fit$aghq$penalised))

  g_raw <- max(abs(as.numeric(fit$tmb_obj$gr(fit$opt$par))))
  expect_equal(fit$fit_health$max_gradient, g_raw, tolerance = 1e-10)
})

## The SECOND penalised block. `run_one()` applies the ridge to `theta_rr_B`
## AND `theta_rr_spde_lv`, so a fit combining `latent()` with
## `spatial_latent()` has two penalised blocks. The first fix for #1092
## repaired only `theta_rr_B` and was a silent NO-OP on exactly this shape --
## it passed every test above while `fit_health$max_gradient` still reported
## |lambda_spde|/tau^2 and `gradient_is_penalised` asserted TRUE about a
## number that was not fully penalised. Found by adversarial review, not by
## the suite, which is why this case is pinned here.
test_that("#1092: the ridge on theta_rr_spde_lv is corrected too", {
  skip_on_cran()
  skip_if_not_installed("fmesher")
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)

  set.seed(33L)
  n_site <- 50L
  n_trait <- 3L
  lam_spde <- c(1.8, 1.4, -1.6)   # spatial LV must carry real signal, or the
  lam_site <- c(0.1, -0.1, 0.1)   # spde block collapses and cannot discriminate
  coords <- cbind(lon = stats::runif(n_site), lat = stats::runif(n_site))
  D <- as.matrix(stats::dist(coords))
  z_spde <- as.numeric(
    t(chol(exp(-D / 0.7) + diag(1e-6, n_site))) %*% stats::rnorm(n_site)
  )
  z_site <- stats::rnorm(n_site)
  long <- do.call(rbind, lapply(seq_len(n_trait), function(t) {
    data.frame(
      site = paste0("s", seq_len(n_site)),
      lon = coords[, 1], lat = coords[, 2],
      trait = paste0("t", t),
      value = lam_spde[t] * z_spde + lam_site[t] * z_site +
        stats::rnorm(n_site, 0, 0.2),
      stringsAsFactors = FALSE
    )
  }))
  mesh <- gllvmTMB::make_mesh(long, c("lon", "lat"), cutoff = 0.05)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      spatial_latent(0 + trait | coords, d = 1) + latent(0 + trait | site, d = 1),
    data = long, unit = "site", family = gaussian(), mesh = mesh,
    control = gllvmTMB::gllvmTMBcontrol(aghq_ridge = 2, se = FALSE)
  )))

  nm <- names(fit$tmb_obj$par)
  par <- fit$opt$par
  i_spde <- which(nm == "theta_rr_spde_lv")
  i_B <- which(nm == "theta_rr_B")
  expect_gt(length(i_spde), 0L)
  expect_gt(length(i_B), 0L)
  expect_true(isTRUE(fit$aghq$penalised))

  ## FIXTURE GUARD: the spatial loadings must be large enough that the omitted
  ## penalty term would dominate. If the spde block collapses (it does at
  ## other n / mesh settings) this test silently stops discriminating, so fail
  ## loudly instead.
  expect_gt(max(abs(par[i_spde])), 1)

  g <- as.numeric(fit$tmb_obj$gr(par))
  g_b_only <- g
  g_b_only[i_B] <- g_b_only[i_B] + par[i_B] / (fit$aghq$ridge_tau^2)
  g_both <- g_b_only
  g_both[i_spde] <- g_both[i_spde] + par[i_spde] / (fit$aghq$ridge_tau^2)

  ## Correcting only `theta_rr_B` leaves the spde penalty term behind, and it
  ## is the dominant one here -- this is the assertion the old fix failed.
  expect_gt(max(abs(g_b_only)), 1e-1)
  expect_lt(max(abs(g_both)), 1e-2)

  expect_equal(fit$fit_health$max_gradient, max(abs(g_both)), tolerance = 1e-8)
  expect_true(fit$fit_health$converged)
})
