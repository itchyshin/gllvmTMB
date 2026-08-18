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
##      and R/dispersion-trait-map.R); the test loops over it once rather
##      than hand-rolling one assertion per family.

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
  fit <- make_nbinom2_gamma_fit()

  nm <- names(fit$opt$par)
  trait_id <- fit$tmb_data$trait_id
  family_id_vec <- fit$tmb_data$family_id_vec
  n_traits <- fit$tmb_data$n_traits

  checked <- 0L
  for (row in dispersion_family_table) {
    if (!row$param %in% nm) next
    checked <- checked + 1L
    mask <- gllvmTMB:::dispersion_trait_family_mask(
      trait_id, family_id_vec, row$fids, n_traits
    )
    expect_equal(
      sum(nm == row$param), sum(mask),
      info = sprintf("parameter %s", row$param)
    )
  }
  ## The fixture actually exercises two families (nbinom2, Gamma); make
  ## sure the loop did real work rather than silently matching nothing.
  expect_true(checked >= 2L)
})
