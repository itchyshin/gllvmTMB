# AIC()/BIC() must not silently rank REML fits against ML fits (#1411).
# anova() refuses REML outright; the information criteria warn instead.

make_ic_reml_data <- function(seed = 1411, n_groups = 12L, n_rep = 4L) {
  set.seed(seed)
  trait_levels <- c("t1", "t2")
  df <- expand.grid(
    study = factor(seq_len(n_groups)),
    trait = factor(trait_levels, levels = trait_levels),
    rep = seq_len(n_rep)
  )
  df$x <- stats::rnorm(nrow(df))
  u <- stats::rnorm(n_groups, 0, 0.65)
  df$value <- c(t1 = -0.2, t2 = 0.3)[as.character(df$trait)] +
    0.4 * df$x + u[as.integer(df$study)] + stats::rnorm(nrow(df), 0, 0.35)
  df
}

ic_fit <- function(formula, REML) {
  suppressMessages(suppressWarnings(gllvmTMB(
    formula, data = make_ic_reml_data(), unit = "study",
    REML = REML, silent = TRUE
  )))
}

ic_reml_warnings <- function(expr) {
  caught <- list()
  withCallingHandlers(
    expr,
    warning = function(w) {
      if (inherits(w, "gllvmTMB_ic_reml_not_comparable")) {
        caught[[length(caught) + 1L]] <<- w
        invokeRestart("muffleWarning")
      }
    }
  )
  caught
}

test_that("AIC()/BIC() warn when a REML fit is tabulated with an ML fit", {
  f <- value ~ 0 + trait + x + (1 | study)
  fit_reml <- ic_fit(f, REML = TRUE)
  fit_ml <- ic_fit(f, REML = FALSE)

  expect_warning(
    AIC(fit_reml, fit_ml),
    class = "gllvmTMB_ic_reml_not_comparable"
  )
  expect_warning(
    BIC(fit_ml, fit_reml),
    class = "gllvmTMB_ic_reml_not_comparable"
  )
})

test_that("AIC()/BIC() warn for REML fits with different fixed effects", {
  fit_a <- ic_fit(value ~ 0 + trait + (1 | study), REML = TRUE)
  fit_b <- ic_fit(value ~ 0 + trait + x + (1 | study), REML = TRUE)

  expect_warning(AIC(fit_a, fit_b), class = "gllvmTMB_ic_reml_not_comparable")
  expect_warning(BIC(fit_a, fit_b), class = "gllvmTMB_ic_reml_not_comparable")
})

test_that("AIC()/BIC() stay silent where the comparison is valid", {
  f <- value ~ 0 + trait + x + (1 | study)
  fit_reml <- ic_fit(f, REML = TRUE)
  fit_reml2 <- ic_fit(value ~ 0 + trait + x + latent(1 | study, d = 1), REML = TRUE)
  fit_ml <- ic_fit(f, REML = FALSE)
  fit_ml2 <- ic_fit(value ~ 0 + trait + (1 | study), REML = FALSE)

  expect_length(ic_reml_warnings(AIC(fit_reml)), 0L)
  expect_length(ic_reml_warnings(BIC(fit_reml)), 0L)
  expect_length(ic_reml_warnings(AIC(fit_reml, fit_reml2)), 0L)
  expect_length(ic_reml_warnings(AIC(fit_ml, fit_ml2)), 0L)
  expect_length(ic_reml_warnings(BIC(fit_ml, fit_ml2)), 0L)
})
