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
      ## This small NB2 fixture can receive a platform-specific nlminb
      ## convergence code despite reaching the same finite fitted objective.
      ## The mask invariant is the equality below, not an optimizer-status
      ## certificate for every non-Gaussian family.
      expect_true(is.finite(as.numeric(stats::logLik(r$inc))))
      expect_true(is.finite(as.numeric(stats::logLik(r$cc))))
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

## ---- Tier-3b (2026-08-15): the same include == drop contract for EVERY
## remaining admitted family (Design 59 Phase 1 completeness: all
## distributions admit miss_control(response = "include")). Formula kind
## varies by family capability: delta families are exercised fixed-effects
## (their recovery cells are fixed-only), ordinal uses its unique() tier,
## everything else uses the d = 1 latent tier above. Where the model has a
## latent tier the identified comparison is Sigma (rotation-safe); for
## fixed/unique kinds opt$par is directly identified and compared raw.
## multinomial is covered in test-multinomial-missing-response.R
## (group-uniform contrast masking); betabinomial (cbind response) in the
## dedicated test at the foot of this file.

make_missing_resp_data2 <- function(family, seed = 7L, n_unit = 45L) {
  set.seed(seed)
  traits <- c("t1", "t2", "t3")
  df <- expand.grid(unit = factor(seq_len(n_unit)), trait = factor(traits))
  u <- stats::rnorm(n_unit)[as.integer(df$unit)]
  lam <- c(t1 = 0.8, t2 = 0.6, t3 = 0.5)[as.character(df$trait)]
  b0 <- c(t1 = 1.0, t2 = 1.2, t3 = 0.8)[as.character(df$trait)]
  eta <- b0 + lam * u
  n <- nrow(df)
  df$value <- switch(
    family,
    lognormal = exp(stats::rnorm(n, mean = 0.3 * eta, sd = 0.4)),
    ## shape = 10 keeps every draw well away from 0: the Gamma likelihood of a
    ## small fixture is SPIKED near y ~ 0 (scale -> 0 sends the density to
    ## +Inf), and on ubuntu CI a single-start include-fit found that spike
    ## (logLik +232,395 vs -276 on the complete-case arm) while macOS missed
    ## it. Conditioning the data removes the spike rather than widening the
    ## equality band.
    Gamma = stats::rgamma(n, shape = 10, rate = 10 / exp(eta)),
    nbinom1 = {
      mu <- exp(eta)
      stats::rnbinom(n, mu = mu, size = mu / 0.8)
    },
    tweedie = {
      ## compound Poisson-gamma: mean exp(eta), zeros included
      npois <- stats::rpois(n, 1.2)
      vapply(seq_len(n), function(i) {
        if (npois[i] == 0L) return(0)
        sum(stats::rgamma(npois[i], shape = 1.5,
                          scale = exp(eta[i]) / (1.2 * 1.5)))
      }, numeric(1))
    },
    Beta = {
      mu <- stats::plogis(eta - 1)
      pmin(pmax(stats::rbeta(n, mu * 8, (1 - mu) * 8), 1e-6), 1 - 1e-6)
    },
    student = eta + 0.5 * stats::rt(n, df = 5),
    truncated_poisson = {
      lambdav <- exp(eta)
      y <- stats::rpois(n, lambdav)
      while (any(y == 0L)) {
        i0 <- y == 0L
        y[i0] <- stats::rpois(sum(i0), lambdav[i0])
      }
      y
    },
    truncated_nbinom2 = {
      mu <- exp(eta)
      y <- stats::rnbinom(n, mu = mu, size = 3)
      while (any(y == 0L)) {
        i0 <- y == 0L
        y[i0] <- stats::rnbinom(sum(i0), mu = mu[i0], size = 3)
      }
      y
    },
    delta_lognormal = {
      occ <- stats::rbinom(n, 1L, stats::plogis(eta - 0.5))
      occ * exp(stats::rnorm(n, 0.3 * eta, 0.5))
    },
    delta_gamma = {
      occ <- stats::rbinom(n, 1L, stats::plogis(eta - 0.5))
      occ * stats::rgamma(n, shape = 2, rate = 2 / exp(eta))
    },
    ordinal_probit = {
      lat <- eta + stats::rnorm(n)
      factor(as.integer(cut(lat, c(-Inf, 0.8, 1.6, 2.4, Inf))),
             ordered = TRUE)
    }
  )
  df
}

run_include_drop_equiv2 <- function(family, famfun, formula_kind, seed = 7L) {
  df <- make_missing_resp_data2(family, seed = seed)
  masked <- c(3L, 27L, 55L, 88L, 111L)
  data_na <- df
  data_na$value[masked] <- NA
  data_cc <- df[-masked, , drop = FALSE]
  form <- switch(
    formula_kind,
    latent = value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    fixed  = value ~ 0 + trait,
    unique = value ~ 0 + trait + unique(0 + trait | unit)
  )
  fit_inc <- suppressWarnings(suppressMessages(gllvmTMB(
    form, data = data_na, trait = "trait", unit = "unit",
    family = famfun, missing = miss_control(response = "include"), silent = TRUE
  )))
  fit_cc <- suppressWarnings(suppressMessages(gllvmTMB(
    form, data = data_cc, trait = "trait", unit = "unit",
    family = famfun, missing = miss_control(response = "drop"), silent = TRUE
  )))
  list(inc = fit_inc, cc = fit_cc, n_masked = length(masked))
}

for (fam in list(
  list(name = "lognormal",         fun = quote(lognormal()),          kind = "latent"),
  list(name = "Gamma",             fun = quote(Gamma(link = "log")),  kind = "latent"),
  list(name = "nbinom1",           fun = quote(nbinom1()),            kind = "latent"),
  list(name = "tweedie",           fun = quote(tweedie()),            kind = "latent"),
  list(name = "Beta",              fun = quote(Beta()),               kind = "latent"),
  ## df fixed: with estimated df this small fixture is multimodal and the two
  ## arms can converge to different basins (ubuntu CI: -146.3 vs -67.2). The
  ## mask contract is about the SAME likelihood surface, so pin df.
  list(name = "student",           fun = quote(student(df = 5)),      kind = "latent"),
  list(name = "truncated_poisson", fun = quote(truncated_poisson()),  kind = "latent"),
  list(name = "truncated_nbinom2", fun = quote(truncated_nbinom2()),  kind = "latent"),
  list(name = "delta_lognormal",   fun = quote(delta_lognormal()),    kind = "fixed"),
  list(name = "delta_gamma",       fun = quote(delta_gamma()),        kind = "fixed"),
  list(name = "ordinal_probit",    fun = quote(ordinal_probit()),     kind = "unique")
)) {
  local({
    fam_name <- fam$name
    fam_fun <- eval(fam$fun)
    fam_kind <- fam$kind
    test_that(sprintf("masked response == complete-case for %s", fam_name), {
      r <- run_include_drop_equiv2(fam_name, fam_fun, fam_kind)
      expect_true(is.finite(as.numeric(stats::logLik(r$inc))))
      expect_true(is.finite(as.numeric(stats::logLik(r$cc))))
      expect_equal(sum(r$inc$tmb_data$is_y_observed == 0L), r$n_masked)
      expect_equal(
        as.numeric(stats::logLik(r$inc)),
        as.numeric(stats::logLik(r$cc)),
        tolerance = 1e-6
      )
      if (identical(fam_kind, "latent")) {
        ## The mask invariant is the logLik equality above (measured
        ## |dlogLik| <= 2.5e-6 across all eleven families, mostly ~1e-9).
        ## Sigma on this small d = 1 fixture sits in a locally flat
        ## direction: nbinom1 / tweedie / truncated_poisson wobble by
        ## 5e-3..9e-3 relative while logLik agrees to 1e-9, so the identity
        ## band here guards against gross divergence, not termination noise.
        expect_equal(
          extract_Sigma(r$inc, level = "unit")$Sigma,
          extract_Sigma(r$cc, level = "unit")$Sigma,
          tolerance = 2e-2
        )
      } else {
        ## theta_diag_B (unique-tier diagonal log-SDs) collapses to the
        ## zero boundary on this fixture (values ~ -6..-3.7 on log scale)
        ## where the likelihood is flat: ordinal shows |dlogLik| = 8e-9
        ## while theta_diag_B moves 0.58. Compare the identified mean /
        ## threshold structure only.
        keep <- names(r$inc$opt$par) != "theta_diag_B"
        expect_equal(r$inc$opt$par[keep], r$cc$opt$par[keep], tolerance = 1e-3)
      }
    })
  })
}

## betabinomial: two-column cbind(succ, fail) response; an NA in EITHER
## component marks the cell missing (mirrors test-binomial-cbind behaviour).
test_that("masked response == complete-case for betabinomial (cbind)", {
  set.seed(9L)
  n_unit <- 45L
  traits <- c("t1", "t2", "t3")
  df <- expand.grid(unit = factor(seq_len(n_unit)), trait = factor(traits))
  u <- stats::rnorm(n_unit)[as.integer(df$unit)]
  lam <- c(t1 = 0.8, t2 = 0.6, t3 = 0.5)[as.character(df$trait)]
  b0 <- c(t1 = 0.4, t2 = 0.6, t3 = 0.2)[as.character(df$trait)]
  eta <- b0 + lam * u
  size <- 10L
  mu <- stats::plogis(eta)
  p <- stats::rbeta(nrow(df), mu * 6, (1 - mu) * 6)
  df$succ <- stats::rbinom(nrow(df), size, p)
  df$fail <- size - df$succ
  masked <- c(3L, 27L, 55L, 88L, 111L)
  data_na <- df
  data_na$succ[masked] <- NA
  data_cc <- df[-masked, , drop = FALSE]
  form <- cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE)
  fit_inc <- suppressMessages(gllvmTMB(
    form, data = data_na, trait = "trait", unit = "unit",
    family = betabinomial(), missing = miss_control(response = "include"),
    silent = TRUE
  ))
  fit_cc <- suppressMessages(gllvmTMB(
    form, data = data_cc, trait = "trait", unit = "unit",
    family = betabinomial(), missing = miss_control(response = "drop"),
    silent = TRUE
  ))
  expect_true(is.finite(as.numeric(stats::logLik(fit_inc))))
  expect_equal(sum(fit_inc$tmb_data$is_y_observed == 0L), length(masked))
  expect_equal(
    as.numeric(stats::logLik(fit_inc)),
    as.numeric(stats::logLik(fit_cc)),
    tolerance = 1e-6
  )
  expect_equal(
    extract_Sigma(fit_inc, level = "unit")$Sigma,
    extract_Sigma(fit_cc, level = "unit")$Sigma,
    tolerance = 1e-3
  )
})
