## Predictor-informed latent-score means estimate alpha_lv_B.  The current
## Gaussian REML route restricts b_fix only, so it must reject lv until the
## full restriction is derived and validated.

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

test_that("predictor-informed lv rejects REML before fitting", {
  df <- make_reml_lv_data()
  expect_error(
    fit_reml_lv(df, TRUE),
    regexp = "not available with predictor-informed|alpha_lv_B|REML = FALSE"
  )
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
