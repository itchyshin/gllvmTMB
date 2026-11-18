## Structural closure test for the per-trait dispersion pinning fix
## (issue #1117) and the pre-existing per-trait mask registry
## (`.gllvmTMB_estimable_component_masks`, R/diagnose.R).
##
## Two invariants, both stated as loops over a table rather than
## per-family copies:
##
##   1. Every `tmb_data` name matching "_skip$" is registered in
##      `.gllvmTMB_estimable_component_masks` (as a VALUE -- the registry
##      maps a REPORTed component name to the skip-mask name that filters
##      it). This is the existing diag_B_skip / diag_W_skip contract; the
##      #1117 fix does not add a new tmb_data skip mask (it pins via a
##      plain TMB `factor` map, since the C++ per-row family dispatch
##      never reads a non-matching trait's dispersion entry -- no
##      wasted-likelihood-evaluation problem to guard against), so this
##      assertion should hold unchanged.
##
##   2. For every per-trait dispersion parameter vector present in
##      `opt$par`, the number of FREE entries equals the number of traits
##      that actually use the corresponding family -- the invariant the
##      #1117 fix establishes. `dispersion_family_table` below is the
##      complete inventory (mirrors R/fit-multi.R's dispersion-map block
##      and R/dispersion-trait-map.R); the test loops over it rather than
##      hand-rolling one assertion per family, and runs it against TWO
##      fixtures so the loop actually reaches more than one family's
##      "else" branch (a single nbinom2 + Gamma fixture only reaches 2 of
##      the 12 table rows and would not have caught the tweedie
##      no-user-p regression the first version of this fix shipped with
##      -- `logit_p_tweedie`'s per-trait pin lived only inside the
##      user-supplied-`p` branch, so a DEFAULT tweedie() fit never
##      reached any map for it).

dispersion_family_table <- list(
  list(param = "log_phi_nbinom2",           fids = 5L),
  list(param = "log_phi_nbinom1",           fids = 15L),
  list(param = "log_phi_gamma",             fids = 4L),
  list(param = "log_phi_tweedie",           fids = 6L),
  list(param = "logit_p_tweedie",           fids = 6L),
  list(param = "log_phi_beta",              fids = 7L),
  list(param = "log_phi_betabinom",         fids = 8L),
  list(param = "log_sigma_student",         fids = 9L),
  list(param = "log_df_student",            fids = 9L),
  list(param = "log_phi_truncnb2",          fids = 11L),
  list(param = "log_sigma_lognormal_delta", fids = 12L),
  list(param = "log_phi_gamma_delta",       fids = 13L)
)

make_nbinom2_gamma_fit <- function() {
  set.seed(4)
  n <- 120L
  u <- stats::rnorm(n, sd = 1.0)
  dat <- data.frame(
    site  = factor(rep(seq_len(n), 2)),
    trait = factor(rep(c("t_nb", "t_gamma"), each = n), levels = c("t_nb", "t_gamma")),
    y = c(stats::rnbinom(n, mu = exp(1.5 + 0.8 * u), size = 3),
          stats::rgamma(n, shape = 4, rate = 4 / exp(0.5 + 0.5 * u))),
    family = factor(rep(c("nbinom2", "Gamma"), each = n), levels = c("nbinom2", "Gamma"))
  )
  family_list <- list(nbinom2(), Gamma(link = "log"))
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

make_tweedie_student_poisson_fit <- function() {
  ## No user-supplied `p`/`df` anywhere -- reaches BOTH tweedie vectors'
  ## and BOTH student vectors' family-mask-only ("else") branch. Poisson
  ## carries no dispersion vector, included as the third trait so the
  ## non-family trait actually differs in family from both dispersion
  ## families it is pinned against.
  set.seed(2)
  n <- 150L
  u <- stats::rnorm(n, sd = 1.0)
  dat <- data.frame(
    site  = factor(rep(seq_len(n), 3)),
    trait = factor(rep(c("t_tw", "t_stu", "t_pois"), each = n),
                   levels = c("t_tw", "t_stu", "t_pois")),
    y = c(sim_tweedie(n, exp(1.3 + 0.7 * u), phi = 1.2, p = 1.4),
          1.0 + 0.6 * u + stats::rt(n, df = 8),
          stats::rpois(n, exp(1 + 0.6 * u))),
    family = factor(rep(c("tweedie", "student", "poisson"), each = n),
                     levels = c("tweedie", "student", "poisson"))
  )
  family_list <- list(tweedie(), student(), poisson())
  attr(family_list, "family_var") <- "family"
  suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = dat, unit = "site", trait = "trait",
    family = family_list, silent = TRUE
  )))
}

test_that("every tmb_data '_skip' mask is registered in .gllvmTMB_estimable_component_masks", {
  skip_on_cran()
  fit <- make_nbinom2_gamma_fit()

  skip_names <- grep("_skip$", names(fit$tmb_data), value = TRUE)
  registry <- gllvmTMB:::.gllvmTMB_estimable_component_masks
  expect_true(length(skip_names) > 0L)
  expect_true(all(skip_names %in% unname(registry)))
})

test_that("every present per-trait dispersion vector has exactly one free entry per family trait", {
  skip_on_cran()
  fits <- list(make_nbinom2_gamma_fit(), make_tweedie_student_poisson_fit())

  checked_params <- character(0)
  for (fit in fits) {
    nm <- names(fit$opt$par)
    trait_id <- fit$tmb_data$trait_id
    family_id_vec <- fit$tmb_data$family_id_vec
    n_traits <- fit$tmb_data$n_traits

    for (row in dispersion_family_table) {
      if (!row$param %in% nm) next
      checked_params <- union(checked_params, row$param)
      mask <- gllvmTMB:::dispersion_trait_family_mask(
        trait_id, family_id_vec, row$fids, n_traits
      )
      expect_equal(
        sum(nm == row$param), sum(mask),
        info = sprintf("parameter %s", row$param)
      )
    }
  }
  ## The two fixtures together reach exactly 6 of the 12
  ## dispersion_family_table rows: log_phi_nbinom2, log_phi_gamma (fixture
  ## 1), log_phi_tweedie, logit_p_tweedie, log_sigma_student,
  ## log_df_student (fixture 2). nbinom1, beta, betabinom, truncnb2, and
  ## the two delta families are not exercised here -- adding a fixture for
  ## them would be a straightforward extension of this same loop, not a
  ## new mechanism.
  expect_equal(length(checked_params), 6L)
})
