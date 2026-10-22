# ordination_uncertainty(): per-unit joint covariance of latent scores
# (issue #1243, D-204 parity with GLLVM.jl's ordination_uncertainty()).
#
# The hazard this file targets: a wrong block position (or a wrong site/axis
# reshape) in the joint-precision extraction would produce a same-shaped,
# plausible-looking covariance array of WRONG numbers with no error -- the
# same class of silent-misordering bug `test-getlv-se.R` was built to catch
# for the diagonal-only case. The numeric checks below independently
# recompute the SAME quantity by a DIFFERENT route (a dense `solve()` of the
# joint precision, with hand-written -- not package-internal -- indexing)
# and compare.

skip_on_cran()

## ---- K = 1 fixture: known-truth hand check ------------------------------
## d_B = 1 has NO cross-axis covariance at all (nothing to get wrong there),
## so this fixture isolates "is the right (unit, axis) SLICE of Q^{-1} being
## read" from any axis-ordering question -- the simplest possible version of
## the hazard above.

.ordu_fit_K1 <- local({
  set.seed(2101)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 5, n_traits = 4, mean_species_per_site = 4,
    Lambda_B = matrix(c(0.9, 0.6, -0.4, 0.5), nrow = 4, ncol = 1),
    psi_B = rep(0.3, 4),
    seed = 2101
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim$data
  )))
  stopifnot(isTRUE(fit$sd_report$pdHess))
  fit
})

## ---- K = 2 fixture: cross-axis covariance ---------------------------------
## Same recipe (known stable) as dev/getlv-score-se-RESULTS.md /
## test-getlv-se.R's `.getlv_se_fit_B`, so this is not a new, unvetted
## configuration.

.ordu_fit_K2 <- local({
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 80, n_species = 12, n_traits = 4, mean_species_per_site = 6,
    Lambda_B = matrix(
      c(1.0, 0.7, -0.3, 0.5, 0.3, -0.5, 0.8, 0.2),
      nrow = 4, ncol = 2
    ),
    psi_B = c(0.3, 0.3, 0.3, 0.3),
    seed = 2025
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data
  )))
  stopifnot(isTRUE(fit$sd_report$pdHess))
  fit
})

## ---------------------------------------------------------------------
## (1) Known-truth numeric check, K = 1: an independent dense-solve route.
## ---------------------------------------------------------------------

test_that("ordination_uncertainty() se and cov agree with a hand-rolled dense joint-precision inversion (K = 1)", {
  fit <- .ordu_fit_K1
  u <- ordination_uncertainty(fit, level = "unit")

  expect_s3_class(u, "gllvmTMB_ordination_uncertainty")
  expect_equal(dim(u$scores), c(fit$n_sites, 1L))
  expect_equal(dim(u$se), c(fit$n_sites, 1L))
  expect_equal(dim(u$cov), c(1L, 1L, fit$n_sites))

  ## Independent route: a FRESH sdreport() + a DENSE solve() (base R, not
  ## Matrix::solve()) + hand-written indexing, none of it calling any
  ## package-internal helper this function itself uses.
  sdr2 <- TMB::sdreport(fit$tmb_obj, getJointPrecision = TRUE)
  Q <- as.matrix(sdr2$jointPrecision)
  Cov <- solve(Q)
  idx <- which(rownames(Q) == "z_B")
  expect_length(idx, fit$n_sites)  # d = 1: one z_B entry per site

  se_hand <- sqrt(diag(Cov)[idx])
  expect_equal(as.numeric(u$se[, 1L]), unname(se_hand), tolerance = 1e-6)
  for (s in seq_len(fit$n_sites)) {
    expect_equal(u$cov[1, 1, s], unname(Cov[idx[s], idx[s]]), tolerance = 1e-6)
  }
})

test_that("ordination_uncertainty() se matches getLV(se = TRUE) (independent internal route, K = 1)", {
  fit <- .ordu_fit_K1
  u <- ordination_uncertainty(fit, level = "unit")
  se_lv <- getLV(fit, level = "unit", se = TRUE)$se
  expect_equal(u$se, se_lv, tolerance = 1e-6)
  expect_equal(u$scores, getLV(fit, level = "unit"))
})

## ---------------------------------------------------------------------
## (2) Known-truth numeric check, K = 2: cross-axis covariance.
## ---------------------------------------------------------------------

test_that("ordination_uncertainty() cross-axis covariance agrees with a hand-rolled dense joint-precision inversion (K = 2)", {
  fit <- .ordu_fit_K2
  u <- ordination_uncertainty(fit, level = "unit")
  expect_equal(dim(u$cov), c(2L, 2L, fit$n_sites))

  sdr2 <- TMB::sdreport(fit$tmb_obj, getJointPrecision = TRUE)
  Q <- as.matrix(sdr2$jointPrecision)
  Cov <- solve(Q)
  idx <- which(rownames(Q) == "z_B")
  expect_length(idx, 2L * fit$n_sites)
  ## Hand-written reshape, independent of the package's own
  ## `matrix(zpos, nrow = d, ncol = n)` convention: site s's two z_B
  ## parameter-vector positions are idx[2s - 1] (axis 1) and idx[2s] (axis 2).
  site_idx <- function(s) idx[c(2L * s - 1L, 2L * s)]

  ## Check every site's full 2x2 block, including the off-diagonal
  ## (cross-axis) entry -- the number `getLV(se = TRUE)` cannot produce.
  for (s in seq_len(fit$n_sites)) {
    ij <- site_idx(s)
    hand_block <- Cov[ij, ij]
    expect_equal(unname(u$cov[, , s]), unname(hand_block), tolerance = 1e-6)
  }
  ## The off-diagonal entries are not (numerically) all zero for this
  ## fixture -- otherwise the check above would be vacuous for the one
  ## number getLV(se = TRUE) does not expose.
  off_diag <- vapply(seq_len(fit$n_sites), function(s) u$cov[1, 2, s], numeric(1))
  expect_true(any(abs(off_diag) > 1e-8))
  ## Every cov[,,s] is symmetric.
  for (s in seq_len(fit$n_sites)) {
    expect_equal(u$cov[, , s], t(u$cov[, , s]), tolerance = 1e-8)
  }
})

test_that("ordination_uncertainty() se == sqrt(diag(cov)) and matches getLV(se = TRUE) (K = 2)", {
  fit <- .ordu_fit_K2
  u <- ordination_uncertainty(fit, level = "unit")
  se_from_cov <- t(vapply(seq_len(fit$n_sites), function(s) sqrt(diag(u$cov[, , s])), numeric(2)))
  dimnames(se_from_cov) <- dimnames(u$se)
  expect_equal(u$se, se_from_cov, tolerance = 1e-10)
  expect_equal(u$se, getLV(fit, level = "unit", se = TRUE)$se, tolerance = 1e-6)
})

## ---------------------------------------------------------------------
## (3) Shape / dimnames / NULL-when-absent.
## ---------------------------------------------------------------------

test_that("ordination_uncertainty() dimnames match extract_ordination()'s scores", {
  fit <- .ordu_fit_K2
  u <- ordination_uncertainty(fit, level = "unit")
  expect_identical(dimnames(u$se), dimnames(u$scores))
  expect_identical(dimnames(u$cov)[[1]], colnames(u$scores))
  expect_identical(dimnames(u$cov)[[2]], colnames(u$scores))
  expect_identical(dimnames(u$cov)[[3]], rownames(u$scores))
  expect_identical(u$level, "unit")
})

test_that("ordination_uncertainty() returns NULL when there is no rr term at that level", {
  set.seed(17)
  sim <- simulate_site_trait(
    n_sites = 15, n_species = 5, n_traits = 3, mean_species_per_site = 4,
    psi_B = rep(0.3, 3), seed = 17
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site),
    data = sim$data
  )))
  expect_null(ordination_uncertainty(fit, level = "unit"))
})

test_that("print.gllvmTMB_ordination_uncertainty() states the estimand and does not error", {
  u <- ordination_uncertainty(.ordu_fit_K1, level = "unit")
  out <- utils::capture.output(print(u))
  expect_true(any(grepl("[Cc]onditional", out)))
  expect_true(any(grepl("posterior", out)))
})

## ---------------------------------------------------------------------
## (4) Refusals -- every unsupported estimator/route names its next step.
## ---------------------------------------------------------------------

test_that("ordination_uncertainty() refuses a non-gllvmTMB fit", {
  expect_error(
    ordination_uncertainty(list(a = 1), level = "unit"),
    class = "gllvmTMB_ordination_uncertainty_bad_fit"
  )
})

test_that("ordination_uncertainty() refuses an engine = 'julia' bridge fit", {
  fake_julia_fit <- structure(list(), class = c("gllvmTMB_julia", "list"))
  expect_error(
    ordination_uncertainty(fake_julia_fit, level = "unit"),
    class = "gllvmTMB_ordination_uncertainty_julia_unsupported"
  )
})

test_that("ordination_uncertainty() refuses a variational (integration = 'va') fit", {
  set.seed(20260805L)
  N <- 20L; Tn <- 5L; q <- 1L
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

  engine_fit <- gllvmTMB:::.approximation_engine_va_r3_fit(
    y = y, n_trials = rep(1L, N * Tn), X = X, unit_id = unit, trait_id = trait,
    q = q, family = "binomial", link = "logit", H = 15L, eval_method = "jj"
  )
  va_fit <- gllvmTMB:::.va_route_build_fit(
    engine_fit, call = quote(dummy_call()), q = q, p = Tn, n = N,
    eval_method = "jj", family = "binomial", link = "logit"
  )
  expect_identical(va_fit$status, "healthy")
  expect_error(
    ordination_uncertainty(va_fit, level = "unit"),
    class = "gllvmTMB_ordination_uncertainty_va_unsupported"
  )
})

test_that("ordination_uncertainty() refuses an estimator = 'mspl' fit", {
  set.seed(160915L)
  n_site <- 8L; n_trait <- 3L
  site <- factor(rep(seq_len(n_site), each = n_trait))
  trait <- factor(rep(paste0("t", seq_len(n_trait)), n_site))
  z <- stats::rnorm(n_site)
  Lambda <- c(0.55, -0.40, 0.30)
  beta <- c(0.35, 0.10, 0.50)
  eta <- beta[as.integer(trait)] + z[as.integer(site)] * Lambda[as.integer(trait)]
  y <- stats::rpois(n_site * n_trait, lambda = exp(eta))
  dat <- data.frame(site = site, trait = trait, y = y)

  fit <- suppressMessages(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat,
    family = stats::poisson(link = "log"),
    estimator = "mspl",
    control = gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE)
  ))
  expect_error(
    ordination_uncertainty(fit, level = "unit"),
    class = "gllvmTMB_mspl_inference_unsupported"
  )
})

test_that("ordination_uncertainty() refuses a predictor-informed latent(..., lv = ~x) fit", {
  set.seed(11)
  n <- 20L
  df <- expand.grid(
    unit = factor(paste0("u", seq_len(n))),
    trait = factor(paste0("t", 1:3))
  )
  df$x <- stats::rnorm(n)[as.integer(df$unit)]
  df$value <- stats::rnorm(nrow(df))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
    data = df, unit = "unit", trait = "trait", family = stats::gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_error(
    ordination_uncertainty(fit, level = "unit"),
    class = "gllvmTMB_ordination_uncertainty_lv_predictor_unsupported"
  )
})

test_that("ordination_uncertainty() refuses a fit with no sdreport", {
  set.seed(13)
  Lam <- matrix(stats::runif(3 * 2, -0.6, 0.6), 3, 2)
  sim <- simulate_site_trait(
    n_sites = 15, n_species = 5, n_traits = 3, mean_species_per_site = 4,
    Lambda_B = Lam, psi_B = rep(0.3, 3), seed = 13
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_null(fit$sd_report)
  expect_error(
    ordination_uncertainty(fit, level = "unit"),
    class = "gllvmTMB_ordination_uncertainty_no_sdreport"
  )
})

## ---------------------------------------------------------------------
## (5) ordiplot(ellipse = TRUE) integration.
## ---------------------------------------------------------------------

test_that("ordiplot(ellipse = TRUE) draws without error at rotate = 'none'", {
  fit <- .ordu_fit_K2
  tf <- withr::local_tempfile(fileext = ".png")
  grDevices::png(tf)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(ordiplot(fit, level = "unit", ellipse = TRUE))
})

test_that("ordiplot(ellipse = TRUE, rotate = 'varimax') refuses with a next step", {
  fit <- .ordu_fit_K2
  expect_error(
    ordiplot(fit, level = "unit", ellipse = TRUE, rotate = "varimax"),
    class = "gllvmTMB_ordiplot_ellipse_rotated_unsupported"
  )
})
