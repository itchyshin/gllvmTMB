## Gaussian ordinary LA-MSPL — local point-estimate smoke (se = FALSE).
## Pick C: pinned sigma_eps, Hirose atom, c_N = sqrt(2/N).
## Do NOT assert SEs, intervals, or coverage here (PROTECTED Codex Lane B).

.mspl_gauss_fixture <- function(n_site = 40L, q = 1L, psi = NULL, seed = 150815L) {
  set.seed(seed + q)
  n_trait <- 3L
  if (is.null(psi)) psi <- c(0.55, 0.70, 0.40)
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = n_trait))
  trait <- factor(
    rep(sprintf("t%d", seq_len(n_trait)), n_site),
    levels = sprintf("t%d", seq_len(n_trait))
  )
  z <- matrix(stats::rnorm(n_site * q), n_site, q)
  Lambda <- if (q == 1L) {
    matrix(c(0.90, -0.60, 0.45), n_trait, 1L)
  } else {
    matrix(c(0.90, -0.60, 0.45, 0, 0.50, -0.35), n_trait, 2L)
  }
  beta <- c(0.1, -0.2, 0.3)
  eta <- beta[as.integer(trait)] + rowSums(
    z[as.integer(site), , drop = FALSE] * Lambda[as.integer(trait), , drop = FALSE]
  )
  eps <- stats::rnorm(length(eta), sd = sqrt(psi[as.integer(trait)]))
  data.frame(site = site, trait = trait, y = eta + eps)
}

.mspl_gauss_fit <- function(dat, q = 1L, estimator = "mspl") {
  form <- stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = TRUE)",
    as.integer(q)
  ))
  suppressMessages(gllvmTMB(
    form,
    data = dat,
    family = stats::gaussian(link = "identity"),
    estimator = estimator,
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    )
  ))
}

test_that("Gaussian ordinary LA-MSPL (q=1) fits and reports Hirose (point only)", {
  skip_on_cran()
  dat <- .mspl_gauss_fixture(q = 1L)
  fit <- .mspl_gauss_fit(dat, q = 1L, estimator = "mspl")
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_identical(fit$mspl$family, "gaussian")
  expect_identical(fit$mspl$structure, "ordinary")
  expect_equal(as.integer(fit$report$mspl_family_mode_rep), 2L)
  expect_true(is.finite(fit$opt$objective))
  expect_true(is.finite(fit$report$mspl_hirose_nll))
  expect_gt(as.numeric(fit$report$mspl_hirose_nll), 0)
  expect_equal(
    as.numeric(fit$report$mspl_c_n),
    sqrt(2 / length(unique(dat$site))),
    tolerance = 1e-10
  )
  ## Jeffreys / V_loading must stay off on the Gaussian route.
  expect_equal(as.numeric(fit$report$mspl_jeffreys_nll), 0)
  expect_equal(as.numeric(fit$report$mspl_loading_nll), 0)
  expect_true(all(fit$tmb_data$diag_B_skip == 0L))
  expect_true(!is.null(fit$tmb_map$log_sigma_eps))
})

test_that("Gaussian LA-MSPL vs LA-ML pair: healthy cell (point only)", {
  skip_on_cran()
  dat <- .mspl_gauss_fixture(q = 1L, seed = 150816L)
  fit_ml <- .mspl_gauss_fit(dat, q = 1L, estimator = "ml")
  fit_mspl <- .mspl_gauss_fit(dat, q = 1L, estimator = "mspl")
  expect_true(is.finite(fit_ml$opt$objective))
  expect_true(is.finite(fit_mspl$opt$objective))
  ## Soft penalty should raise the outer objective relative to ML at the
  ## MSPL estimate's unpenalised nll, but both routes must converge.
  expect_true(is.finite(fit_mspl$mspl$unpenalized_nll_at_estimate))
  expect_gt(
    as.numeric(fit_mspl$mspl$total_penalty_nll),
    0
  )
})

test_that("Gaussian LA-MSPL near-Heywood cell still returns a finite point", {
  skip_on_cran()
  dat <- .mspl_gauss_fixture(
    q = 1L,
    psi = c(0.02, 0.55, 0.60),
    seed = 150817L
  )
  fit <- .mspl_gauss_fit(dat, q = 1L, estimator = "mspl")
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_true(is.finite(fit$opt$objective))
  expect_gt(as.numeric(fit$report$mspl_V_hirose), 0)
})

## Cheap q=2 structure pin (1 seed). Finite points / registry only —
## does NOT assert LA-MSPL superiority over LA-ML (see research note).
test_that("Gaussian LA-ML vs LA-MSPL q=2 pair: finite shared Sigma structure", {
  skip_on_cran()
  dat <- .mspl_gauss_fixture(q = 2L, seed = 160801L)
  fit_ml <- .mspl_gauss_fit(dat, q = 2L, estimator = "ml")
  fit_mspl <- .mspl_gauss_fit(dat, q = 2L, estimator = "mspl")
  expect_true(is.finite(fit_ml$opt$objective))
  expect_true(is.finite(fit_mspl$opt$objective))
  expect_identical(fit_mspl$mspl$registry_status, "admitted")
  expect_identical(fit_mspl$mspl$registry_evidence, "oracle_local")
  S_ml <- extract_Sigma(
    fit_ml, level = "unit", part = "shared", link_residual = "none"
  )$Sigma
  S_mspl <- extract_Sigma(
    fit_mspl, level = "unit", part = "shared", link_residual = "none"
  )$Sigma
  expect_equal(dim(S_ml), c(3L, 3L))
  expect_equal(dim(S_mspl), c(3L, 3L))
  expect_true(all(is.finite(S_ml)))
  expect_true(all(is.finite(S_mspl)))
})
