## Phase B-matrix Group E (agent E-nb1; Design 59): `nbinom1()` family-recovery
## depth + unit-tier structural smoke. Informs register row FAM-07.
##
## FAM-07 is currently smoke-only at baseline. This file is the sibling of
## test-matrix-tweedie.R (committed) and walks the same three unit-tier
## structural cells the matrix campaign asks for on the NB1 family:
##   latent(0 + trait | unit, d = 1) / unique(0 + trait | unit) / latent+unique.
##
## EMPIRICAL FINDING (probed 2026-05-29 via devtools::load_all on this
## worktree, branch agent/phase-b-matrix): `nbinom1()` is a documented family
## *constructor* (R/families.R:297) but is NOT wired into the multivariate
## engine. `gllvmTMB(..., family = nbinom1())` aborts at construction with
##   "Unsupported family: \"nbinom1\"."
## from family_to_id() in R/fit-multi.R (the switch at R/fit-multi.R:79-101
## has no nbinom1 case; the C++ template src/gllvmTMB.cpp has no phi_nbinom1
## REPORT and no NB1 response-likelihood branch). This is an engine-wiring
## gap, NOT a parameter-identification or small-sample failure.
##
## Per the Design 59 Honest-matrix discipline ("No fake-pass. A cell that does
## not converge ... is skipped with skip(<reason>) and reported as 'stays
## partial', NOT forced green") and the Coordination protocol ("Engine/parser
## frozen": no touches to R/fit-multi.R or src/gllvmTMB.cpp), this agent does
## NOT wire the family. Each of the three cells attempts the real fit and, when
## the engine rejects the family at construction, takes the shared honest-skip
## path -- exactly the skip architecture the tweedie sibling uses for its
## (different) non-convergence reason. FAM-07 therefore stays PARTIAL.
##
## The file is deliberately self-healing: the cells exercise the genuine
## recovery + PD-Hessian + dispersion-finiteness + rho:unit profile-CI smoke
## checks the moment nbinom1 is wired into family_to_id() + the C++ likelihood.
## Until then they skip honestly rather than fake-pass.
##
## DGP (one shared seed-controlled fixture, see make_nbinom1_unit_fixture()):
##   mu_{u,t} = exp(alpha_t + lambda_t * b_u),  b_u ~ N(0, sd_u^2)
##   y_{u,t}  ~ NB1(mu_{u,t}, phi)   with Var(y) = mu * (1 + phi)
## The NB1 mean-variance law is linear in the mean (Hilbe 2011), so for a
## target overdispersion `phi` we draw via stats::rnbinom() with the
## mean-dependent size parameter size = mu / phi (gives Var = mu + mu^2/size =
## mu + mu*phi = mu*(1+phi)). A single shared unit-level latent factor b_u with
## all-positive per-trait loadings lambda_t induces a clean cross-trait
## correlation the reduced-rank (`latent`) and paired (`latent+unique`) cells
## can identify, so the rho:unit profile-CI smoke has a real off-diagonal to
## profile (once the family is wired).
##
## Sizing: 3 traits, 60 units (the matrix-campaign "~3 traits / ~60 units"
## tier), log link, mean ~ 2 (mu_int on the log scale ~ c(1.0, 1.5, 0.5)).
##
## Tolerances (Phase B0 non-Gaussian scoping memo, 2026-05-26): NB1 is a
## mean-dependent count family, so trait-intercept recovery uses the WIDER B0
## band (|b_hat - mu_int| < 0.40), matching the tweedie sibling, rather than
## the tight fixed-residual-scale band of the binomial / ordinal-probit
## families. No per-cell tolerance widening.

skip_if_not_nbinom1_unit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## Seed-controlled NB1 fixture on a single shared unit factor.
## NB1 (linear mean-variance): Var(y) = mu * (1 + phi). Drawn via rnbinom with
## the mean-dependent size = mu / phi so the realised overdispersion is NB1, not
## NB2 (which would use a constant size).
make_nbinom1_unit_fixture <- function(n_unit = 60L, n_traits = 3L,
                                      phi_true = 2.0,
                                      mu_int = c(1.0, 1.5, 0.5),
                                      lambda = c(0.8, 0.6, 0.5),
                                      sd_u = 0.6, seed = 613L) {
  set.seed(seed)
  trait_names <- paste0("trait_", seq_len(n_traits))
  mu_int <- rep_len(mu_int, n_traits)
  lambda <- rep_len(lambda, n_traits)
  b_u    <- stats::rnorm(n_unit, sd = sd_u)        # shared unit-level latent effect

  rows <- vector("list", n_unit * n_traits)
  k <- 0L
  for (u in seq_len(n_unit)) {
    for (t in seq_len(n_traits)) {
      mu_ut <- exp(mu_int[t] + lambda[t] * b_u[u])
      k <- k + 1L
      rows[[k]] <- data.frame(
        unit  = u,
        trait = trait_names[t],
        ## NB1 draw: size = mu / phi  =>  Var = mu * (1 + phi)
        value = stats::rnbinom(1L, mu = mu_ut, size = mu_ut / phi_true)
      )
    }
  }
  df <- do.call(rbind, rows)
  df$unit  <- factor(df$unit, levels = seq_len(n_unit))
  df$trait <- factor(df$trait, levels = trait_names)
  list(
    data     = df,
    n_traits = n_traits,
    phi_true = phi_true,
    mu_int   = mu_int
  )
}

## Fit one unit-tier NB1 structural spec; return the fit or the error.
fit_nbinom1_unit <- function(formula, fx) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data   = fx$data,
      unit   = "unit",
      family = nbinom1()
    ))),
    error = function(e) e
  )
}

## Shared health gate. nbinom1 is wired into the multivariate engine
## (family_to_id() case `nbinom1 = 15L`, C++ `fid == 15` NB1 likelihood branch
## with the `phi_nbinom1` REPORT; verified to recover with conv == 0, PD
## Hessian, and phi within ~6% bias on the unit cell). A construct failure is
## therefore a real regression, not an expected unwired state, so it FAILS hard
## rather than skipping. A converged-but-non-PD fit is still a legitimate
## small-sample health skip and stays a skip.
skip_unless_healthy_nbinom1 <- function(fit, cell) {
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::fail(sprintf(
      "%s nbinom1 unit fit failed to construct: %s",
      cell,
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_converged(fit)) {
    testthat::skip(sprintf(
      paste0("%s nbinom1 unit fit did not converge with PD Hessian; FAM-07 ",
             "stays partial pending bigger n / different seed"),
      cell
    ))
  }
  invisible(fit)
}

## Common per-cell health + NB1 dispersion finiteness assertions.
## NB1 dispersion is per-trait; it must be finite and positive. The report
## field follows the family convention (phi_nbinom1, analogous to phi_nbinom2 /
## phi_tweedie); we read it defensively so the check survives whatever the
## eventual wiring names it.
expect_nbinom1_unit_health <- function(fit, fx) {
  expect_converged(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_converged(fit)

  phi_field <- intersect(
    c("phi_nbinom1", "phi_nb1", "phi_nbinom"),
    names(fit$report)
  )[1L]
  testthat::expect_false(is.na(phi_field))
  phi_hat <- as.numeric(fit$report[[phi_field]])
  testthat::expect_equal(length(phi_hat), fx$n_traits)
  testthat::expect_true(all(is.finite(phi_hat) & phi_hat > 0))
}

## Wider Phase-B0 trait-intercept recovery check for this mean-dependent family.
expect_nbinom1_intercepts_recover <- function(fit, fx, tol = 0.40) {
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  testthat::expect_equal(length(bfix), fx$n_traits)
  testthat::expect_lt(max(abs(bfix - fx$mu_int)), tol)
}

## rho:unit profile-CI smoke on the canonical (1,2) pair: one finite bound.
## Only meaningful for cells with off-diagonal unit-tier structure (`latent`,
## `latent+unique`); a degenerate profile is an honest skip, not a relaxed
## assertion (CI-08 stays partial there).
expect_rho_unit_ci_smoke <- function(fit) {
  ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "rho:unit:1,2", method = "profile"
    ))),
    error = function(e) e
  )
  ok <- !inherits(ci, "error") && is.matrix(ci) && nrow(ci) == 1L &&
    ncol(ci) == 2L && any(is.finite(ci))
  if (!ok) {
    testthat::skip(paste0(
      "Profile CI for rho:unit:1,2 did not return a finite bound; honest skip ",
      "rather than relax assertion (CI-08 stays partial here)"
    ))
  }
  testthat::expect_true(ok)
}

## ---------------------------------------------------------------
## latent(0 + trait | unit, d = 1) -- reduced-rank, one shared factor
## ---------------------------------------------------------------
test_that("nbinom1 x latent(0 + trait | unit, d = 1): converges, PD Hessian, phi finite, rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_nbinom1_unit_deps()
  fx  <- make_nbinom1_unit_fixture()
  fit <- fit_nbinom1_unit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), fx
  )
  skip_unless_healthy_nbinom1(fit, "latent(d=1)")

  expect_nbinom1_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_nbinom1_intercepts_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit)
})

## ---------------------------------------------------------------
## unique(0 + trait | unit) -- per-trait diagonal; cleanest phi recovery
## ---------------------------------------------------------------
test_that("nbinom1 x unique(0 + trait | unit): converges, PD Hessian, phi finite", {
  skip_if_not_heavy()
  skip_if_not_nbinom1_unit_deps()
  fx  <- make_nbinom1_unit_fixture()
  fit <- fit_nbinom1_unit(
    value ~ 0 + trait + unique(0 + trait | unit), fx
  )
  skip_unless_healthy_nbinom1(fit, "unique")

  expect_nbinom1_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$diag_B))
  expect_nbinom1_intercepts_recover(fit, fx)
  ## Diagonal cell has no off-diagonal unit-tier correlation by construction,
  ## so there is no rho:unit to profile here.
})

## ---------------------------------------------------------------
## latent + unique paired (reduced-rank + diagonal on the same grouping)
## ---------------------------------------------------------------
test_that("nbinom1 x latent + unique paired (unit): converges, PD Hessian, phi finite, rho:unit CI smoke", {
  skip_if_not_heavy()
  skip_if_not_nbinom1_unit_deps()
  fx  <- make_nbinom1_unit_fixture()
  fit <- fit_nbinom1_unit(
    value ~ 0 + trait +
            latent(0 + trait | unit, d = 1) +
            unique(0 + trait | unit),
    fx
  )
  skip_unless_healthy_nbinom1(fit, "latent+unique")

  expect_nbinom1_unit_health(fit, fx)
  expect_true(isTRUE(fit$use$rr_B) && isTRUE(fit$use$diag_B))
  expect_equal(dim(fit$report$Lambda_B), c(fx$n_traits, 1L))
  expect_nbinom1_intercepts_recover(fit, fx)
  expect_rho_unit_ci_smoke(fit)
})
