## Regression test for the W-tier twin of the pinned-Psi log-likelihood defect.
##
## The B-tier version is covered in `test-binary-loglik-sign.R`. This file
## covers the same defect class one tier down: for single-trial Bernoulli /
## ordinal_probit / multinomial traits the R-side gate pins the OLRE
## (`theta_diag_W[t]` at `log(1e-6)`, the matching `s_W` row at 0), but the C++
## diag_W loop used to iterate over every (trait, site_species) cell regardless,
## adding `dnorm(0, 0, 1e-6, log = TRUE)` = **+12.8966** per cell.
##
## The `diag_W_skip` mask excludes pinned traits from the objective.

test_that("a fully skipped OLRE contributes nothing to the log-likelihood", {
  skip_on_cran()
  ## When every trait is skipped, the OLRE term is entirely mapped off, so the
  ## fit is the SAME statistical model as the no-OLRE reference. Their
  ## log-likelihoods must therefore agree. This is the sharpest available
  ## check: it needs no tolerance argument about what the "right" value is.
  set.seed(456)
  n_traits <- 3
  n_units <- 200
  true_alpha <- c(0.0, 0.5, -0.5)
  df <- expand.grid(unit = seq_len(n_units), trait_idx = seq_len(n_traits))
  df$obs <- factor(seq_len(nrow(df)))
  df$trait <- factor(paste0("t", df$trait_idx),
                     levels = paste0("t", seq_len(n_traits)))
  df$value <- stats::rbinom(nrow(df), 1L, stats::plogis(true_alpha[df$trait_idx]))

  fit_ref <- suppressMessages(suppressWarnings(
    gllvmTMB(value ~ 0 + trait, data = df, unit = "unit", unit_obs = "obs",
             family = stats::binomial())
  ))
  fit_olre <- suppressMessages(suppressWarnings(
    gllvmTMB(value ~ 0 + trait + indep(0 + trait | obs), data = df,
             unit = "unit", unit_obs = "obs", family = stats::binomial())
  ))

  ll_ref <- as.numeric(stats::logLik(fit_ref))
  ll_olre <- as.numeric(stats::logLik(fit_olre))

  ## Guard the premise: this fit really does exercise the diag_W path with
  ## every trait pinned. Without this the equality below could pass vacuously.
  expect_true(isTRUE(fit_olre$use$diag_W))
  expect_true(all(is.na(fit_olre$tmb_obj$env$map$theta_diag_W)))

  ## A Bernoulli log-likelihood cannot be positive.
  expect_lt(ll_olre, 0)
  expect_equal(ll_olre, ll_ref, tolerance = 1e-4)
})

test_that("a partially skipped OLRE keeps the free traits estimable", {
  skip_on_cran()
  ## The mixed case the mask exists for: one Bernoulli trait is pinned while
  ## the Gaussian and Poisson traits keep an estimable OLRE. A whole-block
  ## `use_diag_W <- 0` shortcut would break this; the per-trait mask must not.
  set.seed(789)
  n_units <- 150
  df <- expand.grid(unit = seq_len(n_units), trait_idx = 1:3)
  df$obs <- factor(seq_len(nrow(df)))
  df$trait <- factor(c("gaus", "bern", "pois")[df$trait_idx],
                     levels = c("gaus", "bern", "pois"))
  df$value <- ifelse(
    df$trait_idx == 1L, stats::rnorm(nrow(df)),
    ifelse(df$trait_idx == 2L, stats::rbinom(nrow(df), 1L, 0.5),
           stats::rpois(nrow(df), 2))
  )

  fit <- suppressMessages(suppressWarnings(
    gllvmTMB(value ~ 0 + trait + indep(0 + trait | obs), data = df,
             unit = "unit", unit_obs = "obs",
             family = list(gaussian(), stats::binomial(), stats::poisson()))
  ))

  td_map <- fit$tmb_obj$env$map$theta_diag_W
  ## Exactly the Bernoulli trait is pinned; the other two stay free.
  expect_equal(sum(is.na(td_map)), 1L)
  expect_lt(as.numeric(stats::logLik(fit)), 0)
})
