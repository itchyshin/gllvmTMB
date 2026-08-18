## Issue #1117: per-trait dispersion/shape parameter vectors
## (log_phi_nbinom2, log_phi_nbinom1, log_phi_gamma, log_phi_tweedie +
## logit_p_tweedie, log_phi_beta, log_phi_betabinom, log_sigma_student +
## log_df_student, log_phi_truncnb2, log_sigma_lognormal_delta,
## log_phi_gamma_delta) were gated WHOLE-VECTOR by `any_<family>` flags
## (R/fit-multi.R). In a mixed-family fit where >= 1 trait uses such a
## family, the OTHER traits' vector entries were free parameters with
## zero likelihood contribution -- the C++ per-row family dispatch never
## reads them for a non-matching row -- so the joint Hessian was
## mechanically singular. `dispersion_trait_map()` /
## `dispersion_trait_family_mask()` (R/dispersion-trait-map.R) pin those
## entries per trait instead of leaving the whole vector free.
##
## All fits gated by skip_on_cran(): each takes a few seconds.

make_nbinom2_poisson_fit <- function() {
  set.seed(101)
  n <- 150L
  u <- stats::rnorm(n, sd = 1.0)
  dat <- data.frame(
    site  = factor(rep(seq_len(n), 2)),
    trait = factor(rep(c("counts_nb", "counts_pois"), each = n),
                   levels = c("counts_nb", "counts_pois")),
    y = c(stats::rnbinom(n, mu = exp(1.5 + 0.8 * u), size = 3),
          stats::rpois(n, exp(1 + 0.6 * u))),
    family = rep(c("nbinom2", "poisson"), each = n)
  )
  family_list <- list(nbinom2(), poisson())
  attr(family_list, "family_var") <- "family"
  suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = dat, unit = "site", trait = "trait",
    family = family_list, silent = TRUE
  )))
}

make_student_gaussian_fit <- function() {
  ## Strengthened per the #1121 CI follow-up (ubuntu pdHess FALSE, macOS
  ## arm64 pdHess TRUE): larger n, a tamer df_true within 6-8, and explicit
  ## per-trait residual signal (w_t/w_g) so the auto-Psi diag_B tier has
  ## real between-site variance to estimate rather than sitting near a
  ## boundary. This did not make pdHess robust across seeds locally (see
  ## the note on test (b) below) -- kept anyway because it is a more
  ## stable fixture for the entry-count/mapped assertions regardless.
  set.seed(4)
  n <- 400L
  u <- stats::rnorm(n, sd = 1.0)
  w_t <- stats::rnorm(n, sd = 0.6)
  w_g <- stats::rnorm(n, sd = 0.6)
  dat <- data.frame(
    site  = factor(rep(seq_len(n), 2)),
    trait = factor(rep(c("y_t", "y_g"), each = n), levels = c("y_t", "y_g")),
    y = c(1.5 + 0.8 * u + w_t + stats::rt(n, df = 7),
          1.0 + 0.6 * u + w_g + stats::rnorm(n, sd = 1.0)),
    ## Explicit factor levels in family-list order: an unordered character
    ## column gets re-sorted alphabetically ("gaussian" < "student") by the
    ## mixed-family alignment in R/fit-multi.R, which would silently swap
    ## which trait gets which family. Filed as its own issue (see the PR
    ## thread for the issue number); this `levels =` is the workaround.
    family = factor(rep(c("student", "gaussian"), each = n),
                     levels = c("student", "gaussian"))
  )
  family_list <- list(student(), gaussian())
  attr(family_list, "family_var") <- "family"
  suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = dat, unit = "site", trait = "trait",
    family = family_list, silent = TRUE
  )))
}

## Tweedie's compound-Poisson-gamma density has no base-R sampler; this
## small simulator matches gllvmTMB's own dtweedie parameterisation
## (mu, phi, p) via the Poisson-sum-of-gammas representation.
sim_tweedie <- function(n, mu, phi = 1.5, p = 1.5) {
  lambda <- mu^(2 - p) / (phi * (2 - p))
  alpha <- (2 - p) / (1 - p)
  gam_scale <- phi * (p - 1) * mu^(p - 1)
  N <- stats::rpois(n, lambda)
  y <- numeric(n)
  for (i in seq_len(n)) {
    if (N[i] > 0) y[i] <- sum(stats::rgamma(N[i], shape = -alpha, scale = gam_scale))
  }
  y
}

make_tweedie_gaussian_fit <- function() {
  ## No user-supplied `p` on tweedie() anywhere -- the regression case for
  ## the follow-up fix: `logit_p_tweedie`'s per-trait pin previously lived
  ## ONLY inside the `any(!is.na(p_pin))` branch (user-supplied `p`), so a
  ## DEFAULT tweedie() mixed with another family never reached ANY map for
  ## this vector (p is NULL on every row -> p_pin all NA).
  set.seed(2)
  n <- 200L
  u <- stats::rnorm(n, sd = 1.0)
  dat <- data.frame(
    site  = factor(rep(seq_len(n), 2)),
    trait = factor(rep(c("y_tw", "y_g"), each = n), levels = c("y_tw", "y_g")),
    y = c(sim_tweedie(n, exp(1.5 + 0.8 * u), phi = 1.2, p = 1.4),
          1.0 + 0.6 * u + stats::rnorm(n, sd = 1.0)),
    family = factor(rep(c("tweedie", "gaussian"), each = n),
                     levels = c("tweedie", "gaussian"))
  )
  family_list <- list(tweedie(), gaussian())
  attr(family_list, "family_var") <- "family"
  suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = dat, unit = "site", trait = "trait",
    family = family_list, silent = TRUE
  )))
}

make_all_nbinom2_fit <- function() {
  set.seed(101)
  n <- 150L
  u <- stats::rnorm(n, sd = 1.0)
  dat <- data.frame(
    site  = factor(rep(seq_len(n), 2)),
    trait = factor(rep(c("counts_a", "counts_b"), each = n),
                   levels = c("counts_a", "counts_b")),
    y = c(stats::rnbinom(n, mu = exp(1.5 + 0.8 * u), size = 3),
          stats::rnbinom(n, mu = exp(1 + 0.6 * u), size = 4))
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = dat, unit = "site", trait = "trait",
    family = nbinom2(), silent = TRUE
  )))
}

test_that("(a) nbinom2 + poisson mixed fit pins the poisson trait's log_phi_nbinom2", {
  skip_on_cran()
  fit <- make_nbinom2_poisson_fit()

  nm <- names(fit$tmb_obj$par)
  i_phi <- which(nm == "log_phi_nbinom2")
  expect_length(i_phi, 1L)
  expect_true("log_phi_nbinom2" %in% names(fit$tmb_map))

  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_true(isTRUE(fit$fit_health$converged))
})

test_that("(b) student + gaussian mixed fit pins the gaussian trait's sigma/df", {
  skip_on_cran()
  fit <- make_student_gaussian_fit()

  nm <- names(fit$tmb_obj$par)
  expect_length(which(nm == "log_sigma_student"), 1L)
  expect_length(which(nm == "log_df_student"), 1L)
  expect_true("log_sigma_student" %in% names(fit$tmb_map))
  expect_true("log_df_student" %in% names(fit$tmb_map))

  ## No pdHess assertion here: PR #1121 CI showed this exact fixture's
  ## Hessian flips PD/non-PD across platforms (TRUE on macOS arm64, FALSE
  ## on ubuntu) even after strengthening n/df/signal above and checking
  ## three local seeds (4: TRUE, 5: TRUE, 6: FALSE) -- the student trait's
  ## own residual (log_sigma_student) and the auto-Psi between-site
  ## diagonal (theta_diag_B) are both additive noise on the SAME identity-
  ## link scale with one observation per (site, trait) cell, so they are
  ## only weakly separable; that is a genuine, platform-sensitive
  ## identifiability property of this fixture, not a defect in the
  ## pinning mechanism under test here. pdHess TRUE for a mixed fit with a
  ## pinned dispersion vector is exercised by test (a) instead, on a
  ## well-conditioned family pair (nbinom2 + poisson) that is robust on
  ## CI.
})

test_that("(c) profile_targets() drops the phantom dispersion entry for the non-family trait", {
  skip_on_cran()
  fit <- make_nbinom2_poisson_fit()

  tg <- profile_targets(fit)
  phi_rows <- tg[tg$tmb_parameter == "log_phi_nbinom2", , drop = FALSE]
  ## Exactly one row (the real nbinom2 trait). Pre-fix this enumerated TWO
  ## rows -- phi_nbinom2[1] (real) and phi_nbinom2[2] (the poisson trait's
  ## phantom entry, estimate == 1 == exp(0), the untouched init value).
  expect_equal(nrow(phi_rows), 1L)
  expect_false(any(grepl("\\[2\\]$", phi_rows$parm)))
})

test_that("(d) a single-family (all-nbinom2) fit leaves every trait's log_phi_nbinom2 free", {
  skip_on_cran()
  fit <- make_all_nbinom2_fit()

  nm <- names(fit$tmb_obj$par)
  i_phi <- which(nm == "log_phi_nbinom2")
  expect_length(i_phi, fit$n_traits)
  ## Identity control: when every trait uses the family, no map is needed
  ## (dispersion_trait_map() returns NULL and R/fit-multi.R leaves
  ## tmb_map untouched -- TMB's identity default).
  expect_false("log_phi_nbinom2" %in% names(fit$tmb_map))
})

test_that("(e) tweedie (no user p=) + gaussian mixed fit pins the gaussian trait's phi/p", {
  skip_on_cran()
  fit <- make_tweedie_gaussian_fit()

  nm <- names(fit$tmb_obj$par)
  expect_length(which(nm == "log_phi_tweedie"), 1L)
  expect_length(which(nm == "logit_p_tweedie"), 1L)
  expect_true("log_phi_tweedie" %in% names(fit$tmb_map))
  expect_true("logit_p_tweedie" %in% names(fit$tmb_map))

  expect_true(isTRUE(fit$sd_report$pdHess))

  tg <- profile_targets(fit)
  p_rows <- tg[tg$tmb_parameter == "logit_p_tweedie", , drop = FALSE]
  ## Exactly one row (the real tweedie trait). Pre-repair this enumerated
  ## TWO rows -- p_tweedie[1] (real) and p_tweedie[2] (the gaussian trait's
  ## phantom entry, estimate == 1.5 == 1 + plogis(0), the untouched init).
  expect_equal(nrow(p_rows), 1L)
  expect_false(any(grepl("\\[2\\]$", p_rows$parm)))

  expect_no_error(confint(fit))
})
