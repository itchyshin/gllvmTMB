# Typed refusal classes on the uncertainty surface (getLV(se = TRUE), ordiplot(
# ellipse = TRUE), ordination_uncertainty(), getREsd(), standard_errors()).
#
# Each classed abort below is part of the documented contract: callers (and
# other tests) branch on the condition class, not the message text. These
# tests pin the class AND the message fragment that tells the user what to do,
# so a renamed class or a silently dropped hint turns the suite red.
#
# Fixtures are tiny. Branches that guard against an internally inconsistent
# object (stale sdreport, missing joint-precision block) are reached by
# replacing the sdreport helper or editing the fitted object's sd_report slot,
# which is the only way to reach them; no R/ code is touched.

skip_on_cran()

## ---- fixtures -------------------------------------------------------------

.urc_latent_fit <- local({
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 80, n_species = 12, n_traits = 4, mean_species_per_site = 6,
    Lambda_B = matrix(c(1.0, 0.7, -0.3, 0.5, 0.3, -0.5, 0.8, 0.2),
                      nrow = 4, ncol = 2),
    psi_B = rep(0.3, 4),
    seed = 2025
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data
  )))
  stopifnot(isTRUE(fit$sd_report$pdHess))
  fit
})

.urc_re_fit <- local({
  set.seed(1)
  n_sites <- 15L; n_species <- 3L; n_traits <- 2L
  base <- data.frame(
    site = factor(rep(paste0("s", seq_len(n_sites)), each = n_species)),
    species = factor(rep(paste0("sp", seq_len(n_species)), times = n_sites))
  )
  df <- do.call(rbind, replicate(n_traits, base, simplify = FALSE))
  df$trait <- factor(rep(paste0("t", seq_len(n_traits)), each = nrow(base)))
  set.seed(2)
  df$value <- rnorm(nrow(df))
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | species),
    data = df, trait = "trait", unit = "site", family = gaussian()
  ))
})

.urc_se_data <- function(seed = 2024L, n_reps = 30L) {
  set.seed(seed)
  grid <- expand.grid(rep_idx = seq_len(n_reps), trait_idx = 1:2)
  grid$trait <- factor(c("a", "b")[grid$trait_idx], levels = c("a", "b"))
  grid$obs_id <- factor(seq_len(nrow(grid)))
  grid$value <- c(1.0, 2.0)[grid$trait_idx] + rnorm(nrow(grid), 0, 0.4)
  grid
}

.urc_lazy_fit <- function() {
  gllvmTMB(
    value ~ 0 + trait,
    data = .urc_se_data(), family = gaussian(), unit = "obs_id",
    control = gllvmTMBcontrol(se = FALSE)
  )
}

## Minimal VA fit, built from the engine adapter as test-va-ordination.R does.
.urc_va_fit <- function(eval_method = "jj", N = 30L, Tn = 5L, q = 1L) {
  set.seed(20260805L)
  trait_names <- paste0("sp", seq_len(Tn))
  long <- data.frame(
    unit = factor(rep(seq_len(N), each = Tn)),
    trait = factor(rep(trait_names, N), levels = trait_names)
  )
  beta_true <- seq(0.2, by = 0.15, length.out = Tn)
  Lambda_true <- matrix(c(0.6, 0.4, -0.3, 0.5, 0.2)[seq_len(Tn * q)], Tn, q)
  score <- matrix(stats::rnorm(N * q), N, q)
  unit <- as.integer(long$unit)
  trait <- as.integer(long$trait)
  eta <- beta_true[trait] +
    rowSums(Lambda_true[trait, , drop = FALSE] * score[unit, , drop = FALSE])
  y <- stats::rbinom(N * Tn, 1L, stats::plogis(eta))
  X <- stats::model.matrix(~ 0 + trait, long)
  engine_fit <- .approximation_engine_va_r3_fit(
    y = y, n_trials = rep(1L, N * Tn), X = X, unit_id = unit, trait_id = trait,
    q = q, family = "binomial", link = "logit", H = 15L,
    eval_method = eval_method
  )
  .va_route_build_fit(
    engine_fit, call = quote(dummy_call()), q = q, p = Tn, n = N,
    eval_method = eval_method, family = "binomial", link = "logit"
  )
}

.urc_julia_stub <- function() {
  structure(list(), class = c("gllvmTMB_julia", "gllvmTMB_multi"))
}

## ---- getLV(): julia bridge ------------------------------------------------

test_that("getLV(se = TRUE) on a julia bridge fit aborts with its own class", {
  fit <- .urc_julia_stub()
  expect_error(
    getLV(fit, se = TRUE),
    class = "gllvmTMB_getLV_se_julia_unsupported"
  )
  expect_error(getLV(fit, se = TRUE), "se = FALSE")
})

test_that("getLV(rotate != 'none') on a julia bridge fit names the working route", {
  fit <- .urc_julia_stub()
  expect_error(getLV(fit, rotate = "varimax"), "rotate = \"none\"")
})

## ---- getLV(): VA eval_method gate -----------------------------------------

test_that("getLV(se = TRUE) on a VA fit is refused unless eval_method is 'gh'", {
  skip_if_not(exists(".approximation_engine_va_r3_fit", mode = "function"))
  fit <- .urc_va_fit("jj")
  expect_identical(fit$eval_method, "jj")
  err <- expect_error(
    getLV(fit, se = TRUE),
    class = "gllvmTMB_getLV_se_va_eval_method_unsupported"
  )
  ## the non-'ac' wording names the offending value; the hint names the way out
  expect_match(conditionMessage(err), "jj", fixed = TRUE)
  expect_match(conditionMessage(err), "se = FALSE", fixed = TRUE)

  ## the 'ac' branch carries its own reason but the same class
  fit$eval_method <- "ac"
  err_ac <- expect_error(
    getLV(fit, se = TRUE),
    class = "gllvmTMB_getLV_se_va_eval_method_unsupported"
  )
  expect_match(conditionMessage(err_ac), "same value for every unit", fixed = TRUE)
})

## ---- ordiplot(ellipse = TRUE) ---------------------------------------------

test_that("ordiplot(ellipse = TRUE) aborts when ordination_uncertainty() returns NULL", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  testthat::local_mocked_bindings(
    ordination_uncertainty = function(...) NULL
  )
  expect_error(
    ordiplot(.urc_latent_fit, ellipse = TRUE),
    class = "gllvmTMB_ordiplot_ellipse_no_uncertainty"
  )
  expect_error(
    ordiplot(.urc_latent_fit, ellipse = TRUE),
    "ellipse = FALSE", fixed = TRUE
  )
})

test_that("ordiplot() documented ellipse defaults and refusals", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_equal(formals(ordiplot.gllvmTMB_multi)$ellipse, FALSE)
  expect_equal(formals(ordiplot.gllvmTMB_multi)$ellipse_level, 0.95)
  expect_error(
    ordiplot(.urc_latent_fit, ellipse = TRUE, rotate = "varimax"),
    class = "gllvmTMB_ordiplot_ellipse_rotated_unsupported"
  )
  expect_error(
    ordiplot(.urc_latent_fit, ellipse = TRUE, axes = 1),
    class = "gllvmTMB_ordiplot_ellipse_one_axis_unsupported"
  )
  ## the plain call still draws without computing uncertainty
  expect_no_error(ordiplot(.urc_latent_fit))
})

## ---- ordination_uncertainty() ---------------------------------------------

test_that("ordination_uncertainty() refuses a fit with no joint precision block", {
  testthat::local_mocked_bindings(
    .gllvmTMB_sdreport_loading_ridge = function(...) list(jointPrecision = NULL)
  )
  expect_error(
    ordination_uncertainty(.urc_latent_fit),
    class = "gllvmTMB_ordination_uncertainty_joint_precision_unavailable"
  )
  expect_error(
    ordination_uncertainty(.urc_latent_fit),
    "jointPrecision", fixed = TRUE
  )
})

test_that("ordination_uncertainty() refuses a joint precision with the wrong z block", {
  ## A precision matrix that has no `z_B` entries at all: the extraction must
  ## stop rather than read a wrong slice.
  Q <- Matrix::Diagonal(3)
  dimnames(Q) <- list(c("beta", "beta", "beta"), c("beta", "beta", "beta"))
  testthat::local_mocked_bindings(
    .gllvmTMB_sdreport_loading_ridge = function(...) list(jointPrecision = Q)
  )
  err <- expect_error(
    ordination_uncertainty(.urc_latent_fit),
    class = "gllvmTMB_ordination_uncertainty_block_mismatch"
  )
  d <- .urc_latent_fit$d_B
  n <- .urc_latent_fit$n_sites
  expect_match(conditionMessage(err), as.character(d * n), fixed = TRUE)
  expect_match(conditionMessage(err), "found 0", fixed = TRUE)
})

test_that("ordination_uncertainty() documented input errors", {
  expect_error(
    ordination_uncertainty(list()),
    class = "gllvmTMB_ordination_uncertainty_bad_fit"
  )
  expect_error(
    ordination_uncertainty(.urc_julia_stub()),
    class = "gllvmTMB_ordination_uncertainty_julia_unsupported"
  )
  fit <- .urc_latent_fit
  fit$sd_report <- NULL
  expect_error(
    ordination_uncertainty(fit),
    class = "gllvmTMB_ordination_uncertainty_no_sdreport"
  )
})

## ---- getREsd() ------------------------------------------------------------

test_that("getREsd() on a fit without an sdreport aborts with its own class", {
  fit <- .urc_re_fit
  fit$sd_report <- NULL
  expect_error(getREsd(fit, "diag_species"), class = "gllvmTMB_getREsd_no_sdreport")
  expect_error(getREsd(fit, "diag_species"), "se = TRUE", fixed = TRUE)
})

test_that("getREsd() aborts when the requested block is absent from the sdreport", {
  fit <- .urc_re_fit
  expect_true(isTRUE(fit$use$diag_species))
  names(fit$sd_report$par.random) <- rep("not_a_block", length(fit$sd_report$par.random))
  expect_error(getREsd(fit, "diag_species"), class = "gllvmTMB_getREsd_block_missing")
  expect_error(getREsd(fit, "diag_species"), "stale", fixed = TRUE)
})

test_that("getREsd() aborts when the block size disagrees with the fit dimensions", {
  fit <- .urc_re_fit
  fit$n_species <- fit$n_species + 1L
  err <- expect_error(
    getREsd(fit, "diag_species"),
    class = "gllvmTMB_getREsd_block_mismatch"
  )
  expect_match(conditionMessage(err), "stale", fixed = TRUE)
})

test_that("getREsd() documented input errors and a clean read", {
  expect_error(getREsd(list()), class = "gllvmTMB_getREsd_bad_fit")
  expect_error(getREsd(.urc_re_fit, "phylo"), class = "gllvmTMB_getREsd_block_absent")
  se <- getREsd(.urc_re_fit, "diag_species")
  expect_equal(dim(se), c(.urc_re_fit$n_traits, .urc_re_fit$n_species))
})

## ---- standard_errors() ----------------------------------------------------

test_that("standard_errors() aborts with its own class when the TMB object cannot be evaluated", {
  fit <- .urc_lazy_fit()
  expect_null(fit$sd_report)
  ## A dead ADFun pointer surfaces as an error from obj$fn(); simulate that
  ## error with the message TMB raises for an invalid external pointer.
  fit$tmb_obj$fn <- function(...) stop("Cannot restore pointer: invalid external pointer")
  err <- expect_error(
    standard_errors(fit),
    class = "gllvmTMB_standard_errors_dead_tmb_obj"
  )
  expect_match(conditionMessage(err), "invalid external pointer", fixed = TRUE)
  expect_match(conditionMessage(err), "saveRDS", fixed = TRUE)
  expect_match(conditionMessage(err), "se = TRUE", fixed = TRUE)
})

test_that("standard_errors() on a saveRDS/readRDS round trip either recovers or aborts with the dead-pointer class", {
  ## Newer TMB retapes a dead ADFun on first use, so the round trip can
  ## succeed; older TMB raises. Either is acceptable; a raw error is not.
  fit <- .urc_lazy_fit()
  path <- tempfile(fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(fit, path)
  restored <- readRDS(path)
  out <- tryCatch(
    standard_errors(restored),
    gllvmTMB_standard_errors_dead_tmb_obj = function(e) e
  )
  if (inherits(out, "condition")) {
    expect_s3_class(out, "gllvmTMB_standard_errors_dead_tmb_obj")
  } else {
    expect_false(is.null(out$sd_report))
  }
})

test_that("standard_errors() reports a failure inside sdreport() with its own class", {
  fit <- .urc_lazy_fit()
  testthat::local_mocked_bindings(
    .gllvmTMB_sdreport_loading_ridge = function(...) stop("boom from sdreport")
  )
  err <- expect_error(
    standard_errors(fit),
    class = "gllvmTMB_standard_errors_sdreport_failed"
  )
  expect_match(conditionMessage(err), "boom from sdreport", fixed = TRUE)
})

test_that("standard_errors() documented input errors", {
  expect_error(standard_errors(list()), class = "gllvmTMB_standard_errors_bad_fit")
  fit <- .urc_lazy_fit()
  fit$tmb_obj <- NULL
  expect_error(standard_errors(fit), class = "gllvmTMB_standard_errors_no_tmb_obj")
})
