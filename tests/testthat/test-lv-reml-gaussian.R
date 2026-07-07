## REML for Gaussian predictor-informed latent scores (lv). REML gives unbiased
## variance components (matches drmTMB's Gaussian-only REML: integrate the mean
## fixed effects out of the marginal likelihood). Enabled for the Gaussian lv /
## Model A path; non-Gaussian lv REML stays blocked (needs its own derivation).

make_reml_lv_data <- function(n_units = 40L, n_traits = 4L, seed = 20260706L) {
  set.seed(seed)
  units <- paste0("u", seq_len(n_units))
  traits <- paste0("t", seq_len(n_traits))
  x_unit <- stats::rnorm(n_units)
  Lambda <- c(0.9, -0.6, 0.5, 0.3)[seq_len(n_traits)]
  beta <- c(0.2, -0.1, 0.15, -0.05)[seq_len(n_traits)]
  alpha <- 0.8
  score <- alpha * x_unit + stats::rnorm(n_units, 0, 0.4)
  df <- do.call(rbind, lapply(seq_along(units), function(i) {
    data.frame(unit = units[[i]], trait = traits, x = x_unit[[i]],
               stringsAsFactors = FALSE)
  }))
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  ti <- as.integer(df$trait); ui <- as.integer(df$unit)
  df$value <- beta[ti] + Lambda[ti] * score[ui] + stats::rnorm(nrow(df), 0, 0.5)
  df
}

fit_reml_lv <- function(data, reml) {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
    data = data, unit = "unit", trait = "trait", family = gaussian(), REML = reml,
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ))
}

test_that("Gaussian lv admits REML and it genuinely engages (fixed effects integrated out)", {
  df <- make_reml_lv_data()
  fit_ml <- fit_reml_lv(df, FALSE)
  fit_reml <- fit_reml_lv(df, TRUE)

  expect_equal(fit_ml$opt$convergence, 0L)
  expect_equal(fit_reml$opt$convergence, 0L)

  ## REML is a different estimator: the restricted objective differs from ML, and
  ## the mean fixed effects (b_fix) are moved into the Laplace-integrated block.
  expect_false(isTRUE(all.equal(fit_ml$opt$objective, fit_reml$opt$objective)))
  ml_random <- unique(names(fit_ml$tmb_obj$env$par[fit_ml$tmb_obj$env$random]))
  reml_random <- unique(names(fit_reml$tmb_obj$env$par[fit_reml$tmb_obj$env$random]))
  expect_false("b_fix" %in% ml_random)
  expect_true("b_fix" %in% reml_random)

  ## REML variance components are >= ML (removes the ML downward bias); at this
  ## small n the difference is present, converging to 0 as n grows.
  expect_true(mean(as.numeric(fit_reml$report$sd_B)) >=
                mean(as.numeric(fit_ml$report$sd_B)) - 1e-6)
})

test_that("non-Gaussian lv still rejects REML = TRUE", {
  df <- make_reml_lv_data()
  df$succ <- rbinom(nrow(df), 10L, plogis(df$value))
  df$fail <- 10L - df$succ
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  expect_error(
    suppressMessages(gllvmTMB::gllvmTMB(
      cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
      data = df, unit = "unit", trait = "trait",
      family = binomial(), REML = TRUE,
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    )),
    regexp = "only for Gaussian|REML"
  )
})
