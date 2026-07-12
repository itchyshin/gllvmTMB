# Tier-3 coverage: the response mask (miss_control(response = "include")) is
# family-agnostic in the engine (is_y_observed gates the masked row out of the
# likelihood). The Gaussian equivalence "include (masked NA) == drop
# (complete-case)" is well tested; these tests extend the same
# sentinel-invariance contract to Poisson, NB2, and Bernoulli responses.

make_missing_resp_data <- function(family = "poisson", seed = 5L, n_unit = 45L) {
  set.seed(seed)
  traits <- c("t1", "t2", "t3")
  df <- expand.grid(unit = factor(seq_len(n_unit)), trait = factor(traits))
  u <- stats::rnorm(n_unit)[as.integer(df$unit)]
  lam <- c(t1 = 0.8, t2 = 0.6, t3 = 0.5)[as.character(df$trait)]
  b0 <- c(t1 = 1.0, t2 = 1.2, t3 = 0.8)[as.character(df$trait)]
  eta <- b0 + lam * u
  df$value <- switch(
    family,
    poisson = stats::rpois(nrow(df), exp(eta)),
    nbinom2 = stats::rnbinom(nrow(df), mu = exp(eta), size = 3),
    binomial = stats::rbinom(nrow(df), 1L, stats::plogis(eta))
  )
  df
}

run_include_drop_equiv <- function(family, famfun, seed = 5L) {
  df <- make_missing_resp_data(family, seed = seed)
  masked <- c(3L, 27L, 55L, 88L, 111L)
  data_na <- df
  data_na$value[masked] <- NA
  data_cc <- df[-masked, , drop = FALSE]
  form <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE)
  fit_inc <- suppressMessages(gllvmTMB(
    form, data = data_na, trait = "trait", unit = "unit",
    family = famfun, missing = miss_control(response = "include"), silent = TRUE
  ))
  fit_cc <- suppressMessages(gllvmTMB(
    form, data = data_cc, trait = "trait", unit = "unit",
    family = famfun, missing = miss_control(response = "drop"), silent = TRUE
  ))
  list(inc = fit_inc, cc = fit_cc, n_masked = length(masked))
}

for (fam in list(
  list(name = "poisson", fun = quote(poisson())),
  list(name = "nbinom2", fun = quote(nbinom2())),
  list(name = "binomial", fun = quote(binomial()))
)) {
  local({
    fam_name <- fam$name
    fam_fun <- eval(fam$fun)
    test_that(sprintf("masked response == complete-case for %s", fam_name), {
      r <- run_include_drop_equiv(fam_name, fam_fun)
      expect_identical(r$inc$opt$convergence, 0L)
      expect_identical(r$cc$opt$convergence, 0L)
      ## masked rows kept and sentinel-zeroed, gated out of the likelihood
      expect_equal(sum(r$inc$tmb_data$is_y_observed == 0L), r$n_masked)
      ## sentinel-invariance: same fit as dropping the masked rows. Compare
      ## the likelihood and the identifiable covariance Sigma = Lambda
      ## Lambda^T + (residual) rather than raw params -- the d = 1 loading is
      ## sign/rotation-ambiguous, so raw par can differ while the model is
      ## identical.
      expect_equal(
        as.numeric(stats::logLik(r$inc)),
        as.numeric(stats::logLik(r$cc)),
        tolerance = 1e-6
      )
      expect_equal(
        extract_Sigma(r$inc, level = "unit")$Sigma,
        extract_Sigma(r$cc, level = "unit")$Sigma,
        tolerance = 1e-3
      )
    })
  })
}
