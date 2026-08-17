## #25 (Ayumi B1): a trait whose Psi coordinate R/fit-multi.R's auto-Psi skip
## block pins to `log(1e-6)` and maps off (single-trial Bernoulli, multinomial
## fid-16 contrasts) still gets REPORTed in `sd_B` for every trait.
## `.gllvmTMB_boundary_flags()` looped over the raw vector with no filter, so
## the pinned 1e-6 placeholder fired `near_zero_sd_B` unconditionally.
## `check_gllvmTMB()`'s own Psi screen (R/diagnose.R's `psi_specs` loop)
## already filters `sd_B` via `object$tmb_data$diag_B_skip` before it is
## thresholded -- the two readers of the same reported quantity disagreed.
## `.gllvmTMB_estimable_components()` unifies them at every reader.

.mob_bernoulli_fit <- function(unique = TRUE, seed = 501L, n = 30L, p = 3L) {
  set.seed(seed)
  L <- matrix(stats::rnorm(p), p, 1L)
  u <- stats::rnorm(n)
  eta <- outer(u, as.numeric(L))
  Y <- matrix(stats::rbinom(n * p, 1, stats::plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  dat <- as.data.frame(Y)
  dat$site <- factor(seq_len(n))
  lhs <- paste(colnames(Y), collapse = ", ")
  form <- stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = 1%s)",
    lhs, if (unique) "" else ", unique = FALSE"
  ))
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    form,
    data = dat,
    family = stats::binomial(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE, warn_runaway = FALSE)
  )))
}

test_that("#25 B1: mapped-off Psi placeholders do not fire near_zero_sd_B", {
  skip_on_cran()
  fit <- .mob_bernoulli_fit(unique = TRUE)
  ## Fixture sanity: every trait is single-trial Bernoulli, so the auto-Psi
  ## skip block maps every coordinate off and pins the placeholder.
  expect_true(all(fit$tmb_data$diag_B_skip == 1L))
  expect_true(all(as.numeric(fit$report$sd_B) < 1e-4))

  bf <- gllvmTMB:::.gllvmTMB_boundary_flags(fit)
  expect_false("near_zero_sd_B" %in% bf)
})

test_that("#25 B1: auto-skip and explicit unique = FALSE report identical boundary flags", {
  skip_on_cran()
  auto <- .mob_bernoulli_fit(unique = TRUE, seed = 502L)
  mirror <- .mob_bernoulli_fit(unique = FALSE, seed = 502L)
  expect_identical(
    sort(gllvmTMB:::.gllvmTMB_boundary_flags(auto)),
    sort(gllvmTMB:::.gllvmTMB_boundary_flags(mirror))
  )
})

test_that("#25 B1: a mixed-family fit only filters the skipped (binomial) trait's sd_B", {
  ## `.gllvmTMB_boundary_flags()` only reads `report$sd_B` and
  ## `tmb_data$diag_B_skip`, so a minimal stub object is a faithful fixture
  ## (the same pattern already used in test-slope-boundary-flag.R) and pins
  ## the screening behaviour exactly rather than leaving it to chance in a
  ## real mixed-family fit. Trait 2 (binomial, single trial) is skipped;
  ## traits 1 and 3 (gaussian) are not, and must still be screened.
  healthy <- gllvmTMB:::.gllvmTMB_boundary_flags(list(
    report = list(sd_B = c(0.8, 1e-6, 0.9)),
    tmb_data = list(diag_B_skip = c(0L, 1L, 0L)),
    use = list()
  ))
  expect_false("near_zero_sd_B" %in% healthy)

  collapsed <- gllvmTMB:::.gllvmTMB_boundary_flags(list(
    report = list(sd_B = c(0.8, 1e-6, 1e-7)),
    tmb_data = list(diag_B_skip = c(0L, 1L, 0L)),
    use = list()
  ))
  expect_true("near_zero_sd_B" %in% collapsed)
})
