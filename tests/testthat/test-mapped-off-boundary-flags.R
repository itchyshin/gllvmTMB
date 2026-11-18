## #25 (Ayumi B1): a trait whose Psi coordinate R/fit-multi.R's auto-Psi skip
## block pins to `log(1e-6)` and maps off (single-trial Bernoulli, multinomial
## fid-16 contrasts) still gets REPORTed in `sd_B` for every trait.
## `.gllvmTMB_boundary_flags()` looped over the raw vector with no filter, so
## the pinned 1e-6 placeholder fired `near_zero_sd_B` unconditionally.
## `check_gllvmTMB()`'s own Psi screen (R/diagnose.R's `psi_specs` loop)
## already filters `sd_B` via `object$tmb_data$diag_B_skip` before it is
## thresholded -- the two readers of the same reported quantity disagreed.
## `.gllvmTMB_estimable_components()` unifies them at every reader.
##
## REPAIR (adversarial review): the first pass claimed "only sd_B carries a
## skip mask" and was REFUTED -- the identical mapped-off mechanism exists
## one tier over. R/fit-multi.R's W-tier OLRE gate (`skip_olre_t`,
## `diag_W_skip`) pins `theta_diag_W` at `log(1e-6)` for single-trial
## Bernoulli, ordinal_probit, AND multinomial traits (a strictly wider set
## than the B-tier gate's Bernoulli + multinomial), and `sd_W` is REPORTed
## unconditionally the same way `sd_B` is. `.gllvmTMB_estimable_components()`
## now carries a name -> mask map (`sd_B` -> `diag_B_skip`, `sd_W` ->
## `diag_W_skip`) instead of a single hard-coded name, and both readers
## route every masked component through it.

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

## ---- REPAIR: the W-tier (OLRE) twin of the mixed-family stub above --------

test_that("#25 B1 REPAIR: a mixed-family fit only filters the skipped (binomial) trait's sd_W", {
  ## The W-tier mirror of the sd_B stub test above -- same reasoning: a
  ## minimal stub object is a faithful fixture because the instrument only
  ## reads `report$sd_W` and `tmb_data$diag_W_skip`. Trait 2 (binomial,
  ## single trial) is skipped; traits 1 and 3 (gaussian) are not, and must
  ## still be screened.
  healthy <- gllvmTMB:::.gllvmTMB_boundary_flags(list(
    report = list(sd_W = c(0.8, 1e-6, 0.9)),
    tmb_data = list(diag_W_skip = c(0L, 1L, 0L)),
    use = list()
  ))
  expect_false("near_zero_sd_W" %in% healthy)

  collapsed <- gllvmTMB:::.gllvmTMB_boundary_flags(list(
    report = list(sd_W = c(0.8, 1e-6, 1e-7)),
    tmb_data = list(diag_W_skip = c(0L, 1L, 0L)),
    use = list()
  ))
  expect_true("near_zero_sd_W" %in% collapsed)
})

.mob_mixed_olre_fit <- function(seed = 910L, n_units = 60L) {
  set.seed(seed)
  true_alpha <- c(0.0, 0.0, 1.0)
  true_sigma2_e <- c(0.4, 0.6, 0.5)
  trait_levels <- c("gauss", "binom", "pois")
  fam_levels <- c("gaussian", "binomial", "poisson")
  df <- expand.grid(unit = seq_len(n_units), trait_idx = 1:3)
  df$obs <- factor(seq_len(nrow(df)))
  df$trait <- factor(trait_levels[df$trait_idx], levels = trait_levels)
  df$family <- factor(fam_levels[df$trait_idx], levels = fam_levels)
  e_it <- stats::rnorm(nrow(df), sd = sqrt(true_sigma2_e[df$trait_idx]))
  df$value <- ifelse(
    df$trait_idx == 1L,
    true_alpha[1] + e_it,
    ifelse(df$trait_idx == 2L,
           stats::rbinom(nrow(df), 1L, stats::plogis(true_alpha[2] + e_it)),
           stats::rpois(nrow(df), exp(true_alpha[3] + e_it))))
  fams <- list(stats::gaussian(), stats::binomial(), stats::poisson())
  attr(fams, "family_var") <- "family"
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | obs),
    data = df,
    unit = "unit",
    unit_obs = "obs",
    family = fams,
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE, warn_runaway = FALSE)
  )))
}

test_that("#25 B1 REPAIR: a real mixed-family + OLRE fit is clean of near_zero_sd_W / near_zero_psi_unit_obs", {
  ## Pre-fix (git-stashed R/diagnose.R, run once during development):
  ## `boundary_flags` == "near_zero_sd_W" and `check_gllvmTMB()` reported
  ## `near_zero_psi_unit_obs  WARN  1e-06  (collapsed relative to the
  ## largest, ratio 1.363e-06)` on this exact fixture, despite the
  ## Bernoulli trait's OLRE being deliberately mapped off and the Gaussian
  ## (0.734) / Poisson (0.484) traits being entirely healthy.
  skip_on_cran()
  fit <- .mob_mixed_olre_fit()
  expect_identical(fit$opt$convergence, 0L)
  ## Fixture sanity: only the Bernoulli trait (position 2) is skipped.
  expect_identical(fit$tmb_data$diag_W_skip, c(0L, 1L, 0L))

  bf <- gllvmTMB:::.gllvmTMB_boundary_flags(fit)
  expect_false("near_zero_sd_W" %in% bf)

  chk <- check_gllvmTMB(fit)
  psi_row <- chk[chk$component == "near_zero_psi_unit_obs", ]
  expect_identical(nrow(psi_row), 1L)
  expect_identical(psi_row$status, "PASS")
})
