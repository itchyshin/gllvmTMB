test_that("temporal AR1 fit retains public temporal metadata", {
  set.seed(42)
  dat <- expand.grid(
    series = paste0("s", 1:3),
    occasion = 1:3,
    trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  dat$value <- rnorm(nrow(dat))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
    data = dat, unit = "series", family = gaussian(), silent = TRUE
  ))
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
  expect_equal(fit$temporal$workflow, "unreplicated")
  expect_true(is.finite(fit$report$phi))
  expect_equal(fit$tmb_data$temporal_iid_total, 1L)
  expect_true(isTRUE(fit$integrated_gaussian_diag_B))
  random_names <- names(fit$tmb_obj$env$par)[fit$tmb_obj$env$random]
  expect_false("s_B" %in% random_names)
  temporal <- extract_temporal(fit)
  expect_equal(temporal$parameters$workflow, "unreplicated")
  expect_equal(nrow(temporal$pair_index), 9L)
  scores <- getLV(fit)
  expect_equal(attr(scores, "temporal_index")$pair_id, rownames(scores))
  ordination <- extract_ordination(fit, level = "unit")
  expect_equal(ordination$row_index$pair_id, rownames(ordination$scores))
  expect_true(is.list(ordination$temporal_sign))
  training_prediction <- predict(fit)
  expect_equal(nrow(training_prediction), nrow(dat))
  expect_equal(training_prediction$est, as.numeric(fit$report$eta))
  expect_named(training_prediction, c("series", "occasion", "trait", "est"))
  expect_false(any(names(training_prediction) == fit$temporal$pair_col))
  expect_error(
    predict(fit, newdata = dat),
    "newdata.*temporal"
  )
  expect_error(confint(fit), "not available.*temporal")
  expect_error(bootstrap_Sigma(fit, n_boot = 2), "not available.*temporal")
  expect_error(loading_profile(fit), "not available.*temporal")
  expect_error(profile_targets(fit), "not available.*temporal")
  expect_error(profile_ci_repeatability(fit), "not available.*temporal")
  expect_error(profile_ci_total_variance(fit), "not available.*temporal")
  expect_error(loading_ci(fit), "not available.*temporal")
  expect_error(bootstrap_ci_lv_effects(fit, n_boot = 2), "not available.*temporal")
  expect_error(extract_repeatability(fit), "not available.*temporal")
  expect_error(ordination_uncertainty(fit), "not available.*temporal")
  simulated <- simulate(fit, nsim = 2, seed = 99)
  expect_equal(dim(simulated), c(nrow(dat), 2L))
  expect_false(isTRUE(all.equal(simulated[, 1L], simulated[, 2L])))
  replay <- update(fit, evaluate = FALSE)
  expect_true(is.call(replay))
  expect_match(paste(deparse(replay$formula), collapse = " "), "temporal_latent", fixed = TRUE)
  refit <- suppressWarnings(update(fit))
  expect_s3_class(refit, "gllvmTMB_multi")
  expect_true(isTRUE(refit$temporal$active))
})

test_that("temporal reporting uses the documented stable sign anchor", {
  loadings <- matrix(c(0, -2, 0.5), ncol = 1L,
    dimnames = list(c("first", "largest", "third"), "LV1"))
  sign <- gllvmTMB:::.temporal_report_sign(loadings)
  expect_true(sign$first_loading_negligible)
  expect_equal(sign$anchor_trait, "largest")
  expect_equal(sign$multiplier, -1)
})

test_that("temporal score time ranks retain pair-level order for unequal series", {
  set.seed(260911L)
  dat <- rbind(
    transform(expand.grid(occasion = 11:14, trait = paste0("t", 1:3),
      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE), series = "a"),
    transform(expand.grid(occasion = 3:5, trait = paste0("t", 1:3),
      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE), series = "b")
  )
  dat$value <- stats::rnorm(nrow(dat))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
    data = dat, unit = "series", family = gaussian(), silent = TRUE
  ))
  pair <- fit$temporal$pair_table[
    match(levels(fit$data[[fit$unit_col]]), fit$temporal$pair_table$pair_id),
    , drop = FALSE
  ]
  ranks <- fit$tmb_data$temporal_time_index
  expect_equal(unname(ranks[pair$series == "a"]), 0:3)
  expect_equal(unname(ranks[pair$series == "b"]), 0:2)
})

test_that("temporal admission rejects a missing response before panel construction", {
  dat <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:3, trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  dat$value <- seq_len(nrow(dat))
  dat$value[1L] <- NA_real_
  expect_error(
    gllvmTMB(value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
      data = dat, unit = "series", family = gaussian()),
    "complete Gaussian response"
  )
})

test_that("temporal selection is refused before iid rank rewriting", {
  dat <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:3, trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  dat$value <- seq_len(nrow(dat))
  expect_error(
    select_lv(
      value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
      data = dat, unit = "series", trait = "trait", d_max = 2
    ), "not available.*temporal"
  )
})

test_that("temporal admission fences alternative integration and competing providers", {
  dat <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:3, trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  dat$value <- seq_len(nrow(dat))
  temporal_formula <- value ~ 0 + trait +
    temporal_latent(0 + trait | series, time = occasion)
  expect_error(
    gllvmTMB(temporal_formula, data = dat, unit = "series", family = gaussian(),
      control = gllvmTMBcontrol(integration = "va")),
    "Laplace integration"
  )
  expect_error(
    gllvmTMB(value ~ 0 + trait +
      temporal_latent(0 + trait | series, time = occasion) +
      latent(0 + trait | series, d = 1), data = dat,
      unit = "series", family = gaussian()),
    "one temporal intercept block"
  )
})

test_that("temporal replicated fit retains separate variance labels", {
  set.seed(7)
  dat <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:3, measurement = 1:2,
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  dat$value <- rnorm(nrow(dat))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_latent(
      0 + trait | series, time = occasion, replicate = measurement
    ),
    data = dat, unit = "series", family = gaussian(), silent = TRUE
  ))
  variance <- extract_temporal(fit)$variance
  expect_equal(fit$temporal$workflow, "replicated")
  expect_true(isTRUE(fit$integrated_gaussian_diag_B))
  random_names <- names(fit$tmb_obj$env$par)[fit$tmb_obj$env$random]
  expect_false("s_B" %in% random_names)
  expect_true(any(names(fit$opt$par) == "log_sigma_eps"))
  expect_true("measurement_variance" %in% variance$component)
  expect_equal(dim(simulate(fit, nsim = 2, seed = 8)), c(nrow(dat), 2L))
  prediction <- predict(fit)
  pair_trait <- interaction(dat$series, dat$occasion, dat$trait, drop = TRUE)
  expect_true(all(vapply(split(prediction$est, pair_trait), function(x) {
    length(unique(round(x, 12L))) == 1L
  }, logical(1))))
  conditional <- simulate(fit, nsim = 2, seed = 81, condition_on_RE = TRUE)
  expect_true(all(vapply(split(conditional[, 1L] - prediction$est, pair_trait),
    function(x) length(unique(round(x, 12L))) > 1L, logical(1))))
})

test_that("temporal simulation reproduces selected Gaussian moments", {
  set.seed(91)
  dat <- expand.grid(
    series = c("a", "b"), occasion = 1:3, measurement = 1:2,
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  dat$value <- rnorm(nrow(dat))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_latent(
      0 + trait | series, time = occasion, replicate = measurement
    ), data = dat, unit = "series", family = gaussian(), silent = TRUE
  ))
  draws <- simulate(fit, nsim = 10000, seed = 92)
  lambda <- as.numeric(fit$report$Lambda_B[, 1L])
  names(lambda) <- levels(fit$data[[fit$trait_col]])
  variance <- extract_temporal(fit)$variance
  psi <- stats::setNames(
    variance$value[variance$component == "occasion_variance"],
    variance$trait[variance$component == "occasion_variance"]
  )
  sigma_eps2 <- variance$value[variance$component == "measurement_variance"]
  phi <- as.numeric(fit$report$phi)
  index <- function(series, occasion, measurement, trait) {
    which(dat$series == series & dat$occasion == occasion &
      dat$measurement == measurement & dat$trait == trait)
  }
  selected <- list(
    lag = c(index("a", 1, 1, "t1"), index("a", 2, 1, "t1")),
    cross_trait = c(index("a", 1, 1, "t1"), index("a", 1, 1, "t2")),
    replicate = c(index("a", 1, 1, "t1"), index("a", 1, 2, "t1")),
    cross_series = c(index("a", 1, 1, "t1"), index("b", 1, 1, "t1"))
  )
  expected <- c(
    lag = unname(phi * lambda["t1"]^2),
    cross_trait = unname(lambda["t1"] * lambda["t2"]),
    replicate = unname(lambda["t1"]^2 + psi["t1"]),
    cross_series = 0
  )
  variances <- c(
    t1 = unname(lambda["t1"]^2 + psi["t1"] + sigma_eps2),
    t2 = unname(lambda["t2"]^2 + psi["t2"] + sigma_eps2)
  )
  empirical <- vapply(selected, function(pair) stats::cov(draws[pair[1L], ], draws[pair[2L], ]), numeric(1))
  se <- c(
    lag = sqrt((variances["t1"]^2 + expected["lag"]^2) / 9999),
    cross_trait = sqrt((variances["t1"] * variances["t2"] + expected["cross_trait"]^2) / 9999),
    replicate = sqrt((variances["t1"]^2 + expected["replicate"]^2) / 9999),
    cross_series = sqrt(variances["t1"]^2 / 9999)
  )
  ## Four predeclared two-sided checks: Bonferroni gives one simultaneous
  ## 95% Monte Carlo bound without treating any selected moment as post hoc.
  bound <- stats::qnorm(1 - 0.05 / (2 * length(expected))) * se
  expect_true(all(abs(empirical - expected) <= bound))
})

test_that("temporal_latent wide syntax rewrites to the same public index", {
  set.seed(11)
  wide <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:3,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  wide$y1 <- rnorm(nrow(wide))
  wide$y2 <- rnorm(nrow(wide))
  wide$y3 <- rnorm(nrow(wide))

  fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 + temporal_latent(1 | series, time = occasion),
    data = wide, unit = "series", family = gaussian(), silent = TRUE
  ))

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(isTRUE(fit$temporal$active))
  expect_equal(fit$traits_meta$input_shape, "wide_data_frame")
  expect_equal(nrow(extract_temporal(fit)$pair_index), nrow(wide))
  replay <- update(fit, evaluate = FALSE)
  expect_match(paste(deparse(replay$formula), collapse = " "), "traits", fixed = TRUE)
  changed <- wide
  changed$y1 <- changed$y1 + 0.01
  refit <- suppressWarnings(update(fit, data = changed))
  expect_s3_class(refit, "gllvmTMB_multi")
  expect_true(isTRUE(refit$temporal$active))
})

test_that("temporal_latent supports replicated wide data and public update replay", {
  set.seed(12)
  wide <- expand.grid(series = paste0("s", 1:3), occasion = 1:3, measurement = 1:2,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  wide$y1 <- rnorm(nrow(wide))
  wide$y2 <- rnorm(nrow(wide))
  wide$y3 <- rnorm(nrow(wide))
  fit <- suppressWarnings(gllvmTMB(
    traits(y1, y2, y3) ~ 1 + temporal_latent(
      1 | series, time = occasion, replicate = measurement
    ), data = wide, unit = "series", family = gaussian(), silent = TRUE
  ))
  expect_equal(fit$temporal$workflow, "replicated")
  expect_equal(nrow(predict(fit)), nrow(wide) * 3L)
  replay <- update(fit, formula = traits(y1, y2, y3) ~ 1 + temporal_latent(
    1 | series, time = occasion, replicate = measurement
  ), evaluate = FALSE)
  expect_match(paste(deparse(replay$formula), collapse = " "), "temporal_latent", fixed = TRUE)
})
