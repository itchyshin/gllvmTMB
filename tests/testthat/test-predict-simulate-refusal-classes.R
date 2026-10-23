## Refusal and warning classes in R/methods-gllvmTMB.R that no other test file
## pins.  Each test builds the smallest fit that reaches the branch and checks
## both the condition class and a fragment of the advice text, so a rename of
## the class or a rewrite of the guidance fails loudly.
##
## Branches covered:
##   predict(se.fit = TRUE)    -> gllvmTMB_predict_se_multinomial_unsupported
##                             -> gllvmTMB_predict_se_mi_unsupported
##   predict(newdata = )       -> gllvmTMB_temporal_predict_newdata
##   logLik()                  -> gllvmTMB_weighted_objective_no_logLik
##   simulate()                -> gllvmTMB_temporal_composed_simulation_unsupported
##                             -> gllvmTMB_structured_rho_simulation_unsupported
##                             -> gllvmTMB_simulate_newdata_gaussian_fallback

## ---- fixtures ------------------------------------------------------------

## Small Gaussian two-trait-factor fit on simulated site x trait data.
.refusal_gauss_fit <- function(weights = NULL) {
  set.seed(11L)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 20, n_species = 1, n_traits = 3,
    mean_species_per_site = 1,
    Lambda_B = matrix(stats::rnorm(3, sd = 0.4), 3, 1),
    psi_B = rep(0.2, 3), seed = 11L
  )
  args <- list(
    value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = sim$data, silent = TRUE, control = gllvmTMBcontrol(se = FALSE)
  )
  if (!is.null(weights)) args$weights <- rep(weights, nrow(sim$data))
  suppressMessages(suppressWarnings(do.call(gllvmTMB, args)))
}

## Two-trait Gaussian fit with a missing binary predictor x modelled by mi().
.refusal_mi_fit <- function() {
  set.seed(303L)
  n <- 30L
  z <- stats::rnorm(n)
  x <- stats::rbinom(n, 1L, stats::plogis(1.1 * z))
  dat <- do.call(rbind, lapply(seq_len(n), function(s) {
    data.frame(
      site = s, trait = c("t1", "t2"),
      value = c(0.6, -0.2) + 1.2 * x[s] + stats::rnorm(2, sd = 0.35),
      x = x[s], z = z[s]
    )
  }))
  dat$site <- factor(dat$site, levels = seq_len(n))
  dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
  dat$species <- factor(1L)
  dat$site_species <- factor(paste(dat$site, dat$species, sep = "_"))
  dat$x[as.integer(dat$site) %in% c(5L, 14L, 22L)] <- NA_real_
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data = dat, family = gaussian(),
    impute = list(x = impute_model(x ~ z, family = binomial())),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

## Gaussian + multinomial traits sharing one latent factor.
.refusal_multinomial_fit <- function() {
  set.seed(14L)
  N <- 60L
  Lam <- matrix(c(1.3, 0.4, 1.0), 3, 1)
  u <- matrix(stats::rnorm(N), N, 1L) %*% t(Lam)
  rows <- list()
  for (i in seq_len(N)) for (r in 1:2) {
    p <- c(1, exp(u[i, 2]), exp(u[i, 3]))
    rows[[length(rows) + 1L]] <- data.frame(
      unit = i, trait = "cat", family = "m",
      value = sample.int(3L, 1L, prob = p / sum(p))
    )
    rows[[length(rows) + 1L]] <- data.frame(
      unit = i, trait = "g", family = "g",
      value = u[i, 1] + stats::rnorm(1, sd = 0.25)
    )
  }
  dat <- do.call(rbind, rows)
  dat$unit <- factor(dat$unit, levels = seq_len(N))
  dat$trait <- factor(dat$trait)
  dat$family <- factor(dat$family)
  fam <- list(g = gaussian(), m = multinomial())
  attr(fam, "family_var") <- "family"
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat, family = fam, trait = "trait", unit = "unit", silent = TRUE
  )))
}

## Temporal fit plus a second diagonal grouping (cluster2): admitted, but the
## cluster2 tier is one unconditional simulate() cannot redraw.
.refusal_temporal_cluster2_fit <- function() {
  data <- expand.grid(
    series = paste0("s", 1:3), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$unit_obs <- paste(data$series, data$occasion)
  data$g2 <- paste0("g", (data$occasion %% 2L) + 1L)
  data$value <- with(data, as.numeric(factor(trait)) + occasion / 10 +
    rep(c(.1, -.2, .3, .05, 0, -.1), length.out = nrow(data)))
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      indep(0 + trait | g2),
    data = data, unit = "series", unit_obs = "unit_obs", cluster2 = "g2",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

## Fixed-rho phylogenetic block plus a cluster2 diagonal tier: the structured
## block is the only one new `rho` admits, and cluster2 is ordinary.
.refusal_rho_cluster2_fit <- function() {
  fx <- .rho_fixed_fixture(3L)
  d <- fx$data
  d$g2 <- paste0("h", as.integer(d$rep))
  suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait +
      phylo_indep(0 + trait | group, A = fx$K, common = TRUE, rho = 0.35) +
      indep(0 + trait | g2),
    data = d, trait = "trait", unit = "obs", cluster = "group",
    cluster2 = "g2", family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

## Series x occasion Gaussian temporal fit (no other tier).
.refusal_temporal_fit <- function() {
  data <- expand.grid(
    series = paste0("s", 1:3), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  data$unit_obs <- paste(data$series, data$occasion)
  data$value <- with(data, as.numeric(factor(trait)) + occasion / 10)
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion) +
      indep(0 + trait | series) + indep(0 + trait | unit_obs),
    data = data, unit = "series", unit_obs = "unit_obs",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

## ---- predict(se.fit = TRUE) ------------------------------------------------

test_that("predict(se.fit = TRUE) on a multinomial fit names the softmax reason", {
  skip_on_cran()
  fit <- .refusal_multinomial_fit()
  expect_true(any(fit$tmb_data$family_id_vec == 16L))
  err <- expect_error(
    predict(fit, se.fit = TRUE),
    class = "gllvmTMB_predict_se_multinomial_unsupported"
  )
  msg <- rlang::cnd_message(err)
  expect_match(msg, "not supported for", fixed = TRUE)
  expect_match(msg, "multinomial", fixed = TRUE)
  expect_match(msg, "per-observation softmax", fixed = TRUE)
  ## The point prediction itself is not refused.
  expect_s3_class(predict(fit), "data.frame")
})

test_that("predict(se.fit = TRUE) on an mi() fit names the imputed-cell reason", {
  skip_on_cran()
  fit <- .refusal_mi_fit()
  expect_true(isTRUE(fit$tmb_data$has_mi == 1L))
  err <- expect_error(
    predict(fit, se.fit = TRUE),
    class = "gllvmTMB_predict_se_mi_unsupported"
  )
  msg <- rlang::cnd_message(err)
  expect_match(msg, "missing-covariate", fixed = TRUE)
  expect_match(msg, "masked/imputed cells", fixed = TRUE)
  expect_s3_class(predict(fit), "data.frame")
})

## ---- predict(newdata = ) on a temporal fit ------------------------------------

test_that("predict(newdata =) on a temporal_latent-family fit points to the training-row routes", {
  skip_on_cran()
  fit <- .refusal_temporal_fit()
  expect_true(isTRUE(fit$temporal$active))
  err <- expect_error(
    predict(fit, newdata = fit$data),
    class = "gllvmTMB_temporal_predict_newdata"
  )
  msg <- rlang::cnd_message(err)
  expect_match(msg, "not yet available", fixed = TRUE)
  expect_match(msg, "series--occasion score index", fixed = TRUE)
  expect_match(msg, "predict(fit)", fixed = TRUE)
  expect_match(msg, "re_form = ~0", fixed = TRUE)
  ## The two routes the message advertises do work.
  expect_s3_class(predict(fit), "data.frame")
  expect_s3_class(predict(fit, re_form = ~0), "data.frame")
})

## ---- logLik() on a non-unit weighted objective ---------------------------------

test_that("logLik() on a non-unit likelihood-weights fit refuses and names the diagnostics route", {
  skip_on_cran()
  fit <- .refusal_gauss_fit(weights = 2)
  expect_true(isTRUE(fit$likelihood_weights$active))
  err <- expect_error(logLik(fit), class = "gllvmTMB_weighted_objective_no_logLik")
  msg <- rlang::cnd_message(err)
  expect_match(msg, "undefined for this non-unit weighted objective", fixed = TRUE)
  expect_match(msg, "weighted estimating criterion", fixed = TRUE)
  expect_match(msg, "fit$opt$objective", fixed = TRUE)
  expect_match(msg, "unit likelihood weights", fixed = TRUE)
  ## Unit weights are not refused.
  expect_s3_class(logLik(.refusal_gauss_fit()), "logLik")
})

## ---- unconditional simulate() refusals -------------------------------------------

test_that("unconditional simulate() on a temporal fit with an un-redrawable tier refuses and names the way out", {
  skip_on_cran()
  fit <- .refusal_temporal_cluster2_fit()
  expect_true(isTRUE(fit$temporal$active))
  ok <- gllvmTMB:::.check_simulate_unconditional(fit)
  expect_false(ok$can_redraw)
  err <- expect_error(
    simulate(fit, nsim = 1L),
    class = "gllvmTMB_temporal_composed_simulation_unsupported"
  )
  msg <- rlang::cnd_message(err)
  expect_match(msg, "cannot redraw every component of this temporal fit", fixed = TRUE)
  expect_match(msg, "Unsupported components", fixed = TRUE)
  expect_match(msg, "condition_on_RE = TRUE", fixed = TRUE)
  ## The advertised conditional route works.
  expect_equal(nrow(simulate(fit, nsim = 1L, condition_on_RE = TRUE)),
               nrow(fit$data))
})

test_that("unconditional simulate() on a rho-enabled fit refuses when a tier cannot be redrawn", {
  skip_on_cran()
  fit <- .refusal_rho_cluster2_fit()
  expect_false(is.null(fit$source_strength))
  ok <- gllvmTMB:::.check_simulate_unconditional(fit)
  expect_false(ok$can_redraw)
  expect_identical(ok$unhandled, "diag_cluster2")
  err <- expect_error(
    simulate(fit, nsim = 1L),
    class = "gllvmTMB_structured_rho_simulation_unsupported"
  )
  msg <- rlang::cnd_message(err)
  expect_match(msg, "cannot redraw every component of this rho-enabled fit", fixed = TRUE)
  expect_match(msg, "Unsupported components", fixed = TRUE)
  expect_match(msg, "diag_cluster2", fixed = TRUE)
  expect_match(msg, "condition_on_RE = TRUE", fixed = TRUE)
  ## The conditional route the message advertises is not refused.
  expect_equal(nrow(simulate(fit, nsim = 1L, condition_on_RE = TRUE)),
               nrow(fit$data))
})

## ---- simulate(newdata = ) Gaussian fallback warning ------------------------------

test_that("simulate(newdata =) warns once per session that it falls back to Gaussian draws", {
  skip_on_cran()
  fit <- .refusal_gauss_fit()
  cache_key <- "gllvmTMB.warned_simulate_newdata_gaussian_fallback"
  withr::local_options(stats::setNames(list(NULL), cache_key))
  expect_null(getOption(cache_key))

  w <- expect_warning(
    sim1 <- suppressMessages(simulate(fit, nsim = 1L, newdata = fit$data, seed = 1L)),
    class = "gllvmTMB_simulate_newdata_gaussian_fallback"
  )
  msg <- rlang::cnd_message(w)
  expect_match(msg, "falls back to Gaussian-on-link-scale draws", fixed = TRUE)
  expect_match(msg, "per-row family lookup", fixed = TRUE)
  expect_match(msg, "call `simulate()` without `newdata`", fixed = TRUE)
  expect_true(isTRUE(getOption(cache_key)))
  expect_equal(nrow(sim1), nrow(fit$data))

  ## Second call in the same session: cached, so no warning.
  expect_no_warning(suppressMessages(
    simulate(fit, nsim = 1L, newdata = fit$data, seed = 1L)
  ))

  ## Clearing the cache key re-arms the warning.
  options(stats::setNames(list(NULL), cache_key))
  expect_warning(
    suppressMessages(simulate(fit, nsim = 1L, newdata = fit$data, seed = 1L)),
    class = "gllvmTMB_simulate_newdata_gaussian_fallback"
  )
})
