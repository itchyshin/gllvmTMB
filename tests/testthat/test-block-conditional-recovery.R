## Block-conditional recovery tests (Hmsc-style; docs/design/54-cross-package-
## scout-protocol.md).
##
## Whole-model recovery tests simulate, fit everything, and check estimates --
## when one fails there is no way to tell WHICH parameter block is at fault
## (the 2026-05-25 binomial-psi episode, the canonical case behind design
## doc 54, cost days of diagnosis for exactly this reason). A block-
## conditional recovery test instead fixes every OTHER parameter block at its
## TRUE value via TMB's `map` and asks whether the ONE block under test is
## recovered, localising a failure before the investigation starts. This is
## borrowed from the `Hmsc` package's `tests/testthat/test-recovery-sanity.R`,
## which recovers one Gibbs block at a time conditional on the truth of the
## rest.
##
## Construction: follows the precedent in test-missing-response-gaussian.R /
## test-missing-response-traits.R -- take a normally-fitted reference object,
## reuse its `tmb_data` / `tmb_params` / `tmb_map` / `random`, and rebuild
## `TMB::MakeADFun()` with specific blocks mapped off at their TRUE (`map =
## factor(NA...)`, value taken from `parameters`) rather than estimated.
##
## DGP: simulate_site_trait() (R/simulate-site-trait.R), Gaussian, with a
## rank-1 between-site reduced-rank loading (Lambda_B) plus a between-site
## diagonal Psi (psi_B). Model formula:
##   value ~ 0 + trait + (0 + trait):env_1 + (0 + trait):env_2 +
##            latent(0 + trait | site, d = 1)
## `latent()` carries its diagonal Psi companion by default (project
## convention, CLAUDE.md), so this one term activates both the rr and diag
## "B" (between-site) tiers together, matching Lambda_B and psi_B in `truth`.
##
## Parameter blocks, discovered empirically from a reference fit
## (`fit0$tmb_params`, cross-checked against the `tmb_map`/`random`
## construction in R/fit-multi.R and the DATA/PARAMETER macros in
## src/gllvmTMB.cpp):
##   b_fix          -- fixed effects (trait intercepts + trait:env slopes),
##                     NOT in `random` under the default REML = FALSE.
##   theta_rr_B     -- packed between-site loadings (Lambda_B). For d_B = 1
##                     the packing (`.gllvmTMB_pack_rr_theta()`,
##                     R/init-warmstart.R:367) is the identity: theta_rr_B is
##                     simply Lambda_B as a plain length-n_traits column
##                     vector (rank 1 has no strict-lower-triangle entries to
##                     drop). Confirmed against the unpack loop in
##                     src/gllvmTMB.cpp:898-917 (no transform applied to the
##                     loading entries).
##   theta_diag_B   -- log-SD (NOT log-variance) of the between-site diagonal
##                     Psi_B: src/gllvmTMB.cpp:1009 `sd_B = exp(theta_diag_B)`.
##                     True value is therefore 0.5 * log(psi_B), since
##                     `truth$psi_B` from simulate_site_trait() is a variance.
##   log_sigma_eps  -- residual log-SD: src/gllvmTMB.cpp:582,2103
##                     (`sigma_eps = exp(log_sigma_eps)`). True value is
##                     0.5 * log(truth$sigma2_eps).
##   z_B, s_B       -- the between-site latent scores / diagonal random
##                     effects. These stay Laplace-integrated (`random`) in
##                     EVERY test below, regardless of which hyperparameter
##                     block is under test: their realised per-site draws are
##                     not returned by simulate_site_trait() (only the
##                     population-level Lambda_B / psi_B are), and they are
##                     always estimated conditional on whatever the
##                     hyperparameters currently are -- exactly as in a
##                     normal fit.
##
## Because the DGP's fixed part is EXACTLY spanned by the model's own design
## matrix (`fit0$X_fix`), the true b_fix vector is recovered by projecting
## the row-wise true linear predictor onto X_fix's column space (`qr.solve`)
## rather than guessed from column-name/order convention -- this is robust to
## whatever ordering model.matrix() produces for `0 + trait + (0 +
## trait):env_1 + (0 + trait):env_2`.

## ---- shared fixture --------------------------------------------------

.bcr_lambda_B_true <- matrix(c(0.9, -0.6, 0.5), ncol = 1L)
.bcr_psi_B_true    <- c(0.25, 0.20, 0.30)
.bcr_sigma2_eps_true <- 0.40

.bcr_make_data <- function(seed = 4001L) {
  simulate_site_trait(
    n_sites               = 200,
    n_species             = 15,
    n_traits              = 3,
    mean_species_per_site = 6,
    n_predictors           = 2,
    Lambda_B              = .bcr_lambda_B_true,
    psi_B                 = .bcr_psi_B_true,
    sigma2_eps             = .bcr_sigma2_eps_true,
    seed                   = seed
  )
}

.bcr_formula <- value ~ 0 + trait + (0 + trait):env_1 + (0 + trait):env_2 +
  latent(0 + trait | site, d = 1)

.bcr_fit_reference <- function(data) {
  suppressMessages(suppressWarnings(gllvmTMB(
    .bcr_formula,
    data    = data,
    family  = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

## True b_fix, recovered by projecting the row-wise true linear predictor
## (implied by truth$alpha / truth$beta and the DGP's fixed-effect equation,
## R/simulate-site-trait.R:188) onto the fitted reference's OWN design matrix
## -- exact up to floating point because the model formula spans the DGP's
## fixed part exactly.
.bcr_true_b_fix <- function(fit0, data, truth) {
  trait_idx <- as.integer(data$trait)
  eta_fix_true <- truth$alpha[trait_idx] +
    truth$beta[trait_idx, 1] * data$env_1 +
    truth$beta[trait_idx, 2] * data$env_2
  b_fix_true <- as.numeric(qr.solve(fit0$X_fix, eta_fix_true))
  span_err <- max(abs(as.numeric(fit0$X_fix %*% b_fix_true) - eta_fix_true))
  testthat::expect_lt(
    span_err, 1e-6,
    label = "true fixed-effect predictor exactly spanned by X_fix"
  )
  b_fix_true
}

## ---- Test 1: fixed effects given true between-site latent structure ------

test_that("fixed effects (b_fix) are recovered given the true between-site latent structure", {
  skip_if_not_heavy()
  sim   <- .bcr_make_data()
  data  <- sim$data
  truth <- sim$truth

  fit0 <- .bcr_fit_reference(data)
  expect_true(isTRUE(fit0$use$rr_B))
  expect_true(isTRUE(fit0$use$diag_B))

  b_fix_true         <- .bcr_true_b_fix(fit0, data, truth)
  theta_rr_B_true    <- as.numeric(.bcr_lambda_B_true)
  theta_diag_B_true  <- 0.5 * log(.bcr_psi_B_true)
  log_sigma_eps_true <- 0.5 * log(.bcr_sigma2_eps_true)

  params <- fit0$tmb_params
  params$theta_rr_B    <- theta_rr_B_true
  params$theta_diag_B  <- theta_diag_B_true
  params$log_sigma_eps <- log_sigma_eps_true

  map <- fit0$tmb_map
  map$theta_rr_B    <- factor(rep(NA_integer_, length(theta_rr_B_true)))
  map$theta_diag_B  <- factor(rep(NA_integer_, length(theta_diag_B_true)))
  map$log_sigma_eps <- factor(NA_integer_)

  obj <- TMB::MakeADFun(
    data       = fit0$tmb_data,
    parameters = params,
    map        = map,
    random     = fit0$random,
    DLL        = "gllvmTMB",
    silent     = TRUE
  )
  opt <- stats::nlminb(obj$par, obj$fn, obj$gr)
  expect_stationary_for_recovery_test(list(tmb_obj = obj, opt = opt))

  b_fix_hat <- obj$env$parList(opt$par)$b_fix
  abs_err   <- max(abs(b_fix_hat - b_fix_true))
  expect_lt(
    abs_err, 0.15,
    label = sprintf("max abs b_fix recovery error = %.4f", abs_err)
  )
})

## ---- Test 2: between-site latent structure given true fixed effects ------

test_that("between-site latent structure (Lambda_B, psi_B) is recovered given the true fixed effects", {
  skip_if_not_heavy()
  sim   <- .bcr_make_data()
  data  <- sim$data
  truth <- sim$truth

  fit0 <- .bcr_fit_reference(data)
  b_fix_true         <- .bcr_true_b_fix(fit0, data, truth)
  log_sigma_eps_true <- 0.5 * log(.bcr_sigma2_eps_true)

  params <- fit0$tmb_params
  params$b_fix         <- b_fix_true
  params$log_sigma_eps <- log_sigma_eps_true

  map <- fit0$tmb_map
  map$b_fix         <- factor(rep(NA_integer_, length(b_fix_true)))
  map$log_sigma_eps <- factor(NA_integer_)

  obj <- TMB::MakeADFun(
    data       = fit0$tmb_data,
    parameters = params,
    map        = map,
    random     = fit0$random,
    DLL        = "gllvmTMB",
    silent     = TRUE
  )
  opt <- stats::nlminb(obj$par, obj$fn, obj$gr)
  expect_stationary_for_recovery_test(list(tmb_obj = obj, opt = opt))

  par_hat       <- obj$env$parList(opt$par)
  Lambda_B_hat  <- matrix(par_hat$theta_rr_B, ncol = 1L)
  psi_B_hat     <- exp(2 * par_hat$theta_diag_B)

  ## Rotation/sign-invariant comparison via the total between-site
  ## covariance (house convention: relative Frobenius norm, mirroring
  ## test-lv-gaussian-recovery.R:222-225).
  Sigma_true <- .bcr_lambda_B_true %*% t(.bcr_lambda_B_true) +
    diag(.bcr_psi_B_true, nrow = length(.bcr_psi_B_true))
  Sigma_hat  <- Lambda_B_hat %*% t(Lambda_B_hat) +
    diag(psi_B_hat, nrow = length(psi_B_hat))

  rel_frob <- norm(Sigma_hat - Sigma_true, "F") / norm(Sigma_true, "F")
  expect_lt(
    rel_frob, 0.40,
    label = sprintf("relative Frobenius error of Sigma_B = %.4f", rel_frob)
  )
})

## ---- Test 3: negative control -- a wrong fixed value must cost likelihood

test_that("a deliberately wrong fixed loading gives a clearly worse objective than the true value (map binds)", {
  skip_if_not_heavy()
  sim   <- .bcr_make_data()
  data  <- sim$data
  truth <- sim$truth

  fit0 <- .bcr_fit_reference(data)
  theta_rr_B_true    <- as.numeric(.bcr_lambda_B_true)
  theta_diag_B_true  <- 0.5 * log(.bcr_psi_B_true)
  log_sigma_eps_true <- 0.5 * log(.bcr_sigma2_eps_true)
  ## Deliberately wrong: drop the between-site loading to zero, i.e. deny
  ## the between-site trait correlation the DGP actually has, while keeping
  ## the diagonal Psi_B contribution (theta_diag_B) at its true value. A
  ## sign flip of Lambda_B would NOT be a valid negative control here --
  ## Lambda_B and -Lambda_B (with z_B re-signed) give an identical Sigma_B
  ## and hence an identical achievable likelihood, so it would not
  ## demonstrate power.
  theta_rr_B_wrong <- rep(0, length(theta_rr_B_true))

  map <- fit0$tmb_map
  map$theta_rr_B    <- factor(rep(NA_integer_, length(theta_rr_B_true)))
  map$theta_diag_B  <- factor(rep(NA_integer_, length(theta_diag_B_true)))
  map$log_sigma_eps <- factor(NA_integer_)

  .fit_conditional <- function(theta_rr_B_val) {
    params <- fit0$tmb_params
    params$theta_rr_B    <- theta_rr_B_val
    params$theta_diag_B  <- theta_diag_B_true
    params$log_sigma_eps <- log_sigma_eps_true
    obj <- TMB::MakeADFun(
      data       = fit0$tmb_data,
      parameters = params,
      map        = map,
      random     = fit0$random,
      DLL        = "gllvmTMB",
      silent     = TRUE
    )
    opt <- stats::nlminb(obj$par, obj$fn, obj$gr)
    list(obj = obj, opt = opt)
  }

  true_fit  <- .fit_conditional(theta_rr_B_true)
  wrong_fit <- .fit_conditional(theta_rr_B_wrong)

  expect_stationary_for_recovery_test(list(tmb_obj = true_fit$obj,  opt = true_fit$opt))
  expect_stationary_for_recovery_test(list(tmb_obj = wrong_fit$obj, opt = wrong_fit$opt))

  ## Negative log-likelihood at the wrong fixed loading must be clearly
  ## (not just numerically) worse than at the true loading -- this is what
  ## proves the test has power and that `map` is actually binding the
  ## supplied value into the objective, not silently ignoring it.
  expect_gt(wrong_fit$opt$objective, true_fit$opt$objective + 5)
})
