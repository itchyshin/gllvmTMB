test_that("source-observation newdata design reproduces training and one-source grids", {
  source <- factor(rep(c("source1", "source2"), each = 6),
                   levels = c("source1", "source2"))
  training <- data.frame(
    trait = factor(rep(c("sp1", "sp2", "sp3"), times = 4)),
    isdm_source = source,
    bias_x = seq(-1, 1, length.out = 12),
    detect_x = c(rep(NA_real_, 6), seq(0, 1, length.out = 6)),
    method = factor(rep(c("visual", "audio"), 6),
                    levels = c("visual", "audio"))
  )
  family_input <- isdm_sources(
    source1 = isdm_source(poisson(),
                          observation = ~ poly(bias_x, 2) + method),
    source2 = isdm_source(binomial("cloglog"), observation = ~ detect_x)
  )
  base <- stats::model.matrix(~ 0 + trait, training)
  fitted <- .gll_isdm_observation_design(
    base, training, training$isdm_source, family_input
  )
  rebuilt <- .gll_isdm_observation_prediction_design(
    base, training, training$isdm_source, family_input,
    training_data = training, target_columns = colnames(fitted)
  )
  fitted_values <- fitted
  attr(fitted_values, "isdm_observation_basis") <- NULL
  expect_equal(rebuilt, fitted_values, tolerance = 1e-14)

  one_source <- training[
    training$isdm_source == "source1" & training$method == "visual",
    , drop = FALSE
  ]
  one_base <- stats::model.matrix(~ 0 + trait, one_source)
  one <- .gll_isdm_observation_prediction_design(
    one_base, one_source, one_source$isdm_source, family_input,
    training_data = training, target_columns = colnames(fitted)
  )
  source2_cols <- startsWith(colnames(one), "isdm_source:source2:")
  expect_true(any(source2_cols))
  expect_true(all(one[, source2_cols, drop = FALSE] == 0))
  expect_identical(colnames(one), colnames(fitted))

  unseen <- one_source
  unseen$method <- "camera"
  expect_error(
    .gll_isdm_observation_prediction_design(
      stats::model.matrix(~ 0 + trait, unseen), unseen,
      unseen$isdm_source, family_input, training, colnames(fitted)
    ),
    class = "gllvmTMB_predict_isdm_observation_level"
  )
})

test_that("source-observation prediction design fails closed", {
  training <- data.frame(
    trait = factor(rep(c("sp1", "sp2"), 2)),
    isdm_source = factor(rep(c("source1", "source2"), each = 2)),
    bias_x = 1:4
  )
  family_input <- isdm_sources(
    source1 = isdm_source(poisson(), observation = ~ bias_x),
    source2 = isdm_source(binomial("cloglog"), observation = ~ bias_x)
  )
  fitted <- .gll_isdm_observation_design(
    stats::model.matrix(~ 0 + trait, training), training,
    training$isdm_source, family_input
  )
  unknown <- training
  unknown$isdm_source <- "source3"
  expect_error(
    .gll_isdm_observation_prediction_design(
      stats::model.matrix(~ 0 + trait, unknown), unknown,
      unknown$isdm_source, family_input, training, colnames(fitted)
    ),
    class = "gllvmTMB_predict_isdm_source_unknown"
  )
  missing <- training[training$isdm_source == "source1",
                      setdiff(names(training), "bias_x"), drop = FALSE]
  expect_error(
    .gll_isdm_observation_prediction_design(
      stats::model.matrix(~ 0 + trait, missing), missing,
      missing$isdm_source, family_input, training, colnames(fitted)
    ),
    class = "gllvmTMB_predict_isdm_observation_missing"
  )
})

test_that("prediction design distinguishes source names containing separators", {
  training <- data.frame(
    trait = factor(rep(c("sp1", "sp2"), 2L)),
    isdm_source = factor(rep(c("a", "a:b"), each = 2L)),
    bias_x = seq_len(4L)
  )
  fam <- isdm_sources(
    a = isdm_source(poisson(), observation = ~ 0 + bias_x),
    `a:b` = isdm_source(poisson(), observation = ~ 0 + I(bias_x^2))
  )
  base <- stats::model.matrix(~ 0 + trait, training)
  fitted <- .gll_isdm_observation_design(
    base, training, training$isdm_source, fam
  )
  one <- training[training$isdm_source == "a", , drop = FALSE]
  rebuilt <- .gll_isdm_observation_prediction_design(
    stats::model.matrix(~ 0 + trait, one), one, one$isdm_source, fam,
    training_data = training, target_columns = colnames(fitted)
  )
  other <- startsWith(colnames(rebuilt), "isdm_source:a:b:")
  expect_true(any(other))
  expect_true(all(rebuilt[, other, drop = FALSE] == 0))

  collision <- data.frame(
    trait = factor(rep(c("sp1", "sp2"), 2L)),
    isdm_source = factor(rep(c("a", "a:b"), each = 2L)),
    b = rep(c(1, 2), 2L),
    x = seq_len(4L)
  )
  collision_fam <- isdm_sources(
    a = isdm_source(poisson(), observation = ~ 0 + b:x),
    `a:b` = isdm_source(poisson(), observation = ~ 0 + x)
  )
  expect_error(
    .gll_isdm_observation_design(
      stats::model.matrix(~ 0 + trait, collision), collision,
      collision$isdm_source, collision_fam
    ),
    class = "gllvmTMB_isdm_observation_name_collision"
  )
})

test_that("public three-source prediction preserves fitted observation bases", {
  skip_if_not_installed("TMB")
  set.seed(20260829)
  dat <- expand.grid(
    cell = factor(paste0("c", seq_len(12L))),
    trait = factor(c("sp1", "sp2")),
    isdm_source = factor(
      c("portal", "checklist", "literature"),
      levels = c("portal", "checklist", "literature")
    ),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$bias_x <- NA_real_
  dat$method <- factor(NA_character_, levels = c("visual", "audio"))
  dat$alias_x <- NA_real_
  portal <- dat$isdm_source == "portal"
  checklist <- dat$isdm_source == "checklist"
  literature <- dat$isdm_source == "literature"
  dat$bias_x[portal] <- seq(-1, 1, length.out = sum(portal))
  dat$method[checklist] <- rep(c("visual", "audio"), length.out = sum(checklist))
  dat$alias_x[literature] <- seq(-0.75, 0.75, length.out = sum(literature))
  eta <- ifelse(dat$trait == "sp1", -0.2, 0.15)
  eta[portal] <- eta[portal] + 0.25 * dat$bias_x[portal]^2
  eta[checklist] <- eta[checklist] + ifelse(dat$method[checklist] == "audio", 0.2, 0)
  eta[literature] <- eta[literature] - 0.15 * dat$alias_x[literature]
  dat$value <- stats::rpois(nrow(dat), exp(eta))
  fam <- isdm_sources(
    portal = isdm_source(poisson(), observation = ~ poly(bias_x, 2)),
    checklist = isdm_source(poisson(), observation = ~ method),
    literature = isdm_source(
      poisson(), observation = ~ alias_x + I(2 * alias_x)
    )
  )
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait, data = dat, trait = "trait", unit = "cell",
    family = fam, silent = TRUE
  ))
  expect_identical(fit$opt$convergence, 0L)
  expect_false("isdm_source:literature:I(2 * alias_x)" %in% fit$X_fix_names)

  response_free <- dat[setdiff(names(dat), "value")]
  out <- suppressMessages(predict(fit, newdata = response_free, re_form = ~0))
  expect_equal(out$est, as.numeric(fit$report$eta), tolerance = 1e-10)

  unseen <- response_free[checklist, , drop = FALSE]
  unseen$method <- "camera"
  expect_error(
    predict(fit, newdata = unseen, re_form = ~0),
    class = "gllvmTMB_predict_isdm_observation_level"
  )

  ## A source-specific factor is irrelevant on rows from another source.  Its
  ## value must not be validated globally before source masking is applied.
  portal_only <- response_free[portal, , drop = FALSE]
  portal_only$method <- "not-a-checklist-level"
  expect_no_error(
    predict(fit, newdata = portal_only, re_form = ~0)
  )

  ## Prediction uses the basis frozen when the model was fitted, not whatever
  ## contrast option happens to be active later in the R session.
  old_contrasts <- getOption("contrasts")
  on.exit(options(contrasts = old_contrasts), add = TRUE)
  options(contrasts = c("contr.sum", "contr.poly"))
  fit_roundtrip <- unserialize(serialize(fit, NULL))
  contrast_out <- suppressMessages(
    predict(fit_roundtrip, newdata = response_free, re_form = ~0)
  )
  expect_equal(contrast_out$est, as.numeric(fit$report$eta), tolerance = 1e-10)
})

test_that("public integrated prediction always requires declared source labels", {
  skip_if_not_installed("TMB")
  dat <- expand.grid(
    cell = factor(paste0("c", seq_len(8L))),
    trait = factor(c("sp1", "sp2")),
    isdm_source = factor(c("portal", "survey")),
    KEEP.OUT.ATTRS = FALSE
  )
  eta <- ifelse(dat$trait == "sp1", -0.2, 0.15)
  dat$value <- ifelse(
    dat$isdm_source == "portal",
    stats::rpois(nrow(dat), exp(eta)),
    stats::rbinom(nrow(dat), 1L, -expm1(-exp(eta)))
  )
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait, data = dat, trait = "trait", unit = "cell",
    family = isdm_sources(
      portal = poisson(), survey = binomial("cloglog")
    ),
    silent = TRUE
  ))
  response_free <- dat[setdiff(names(dat), c("value", "isdm_source"))]
  expect_error(
    predict(fit, newdata = response_free, re_form = ~0),
    class = "gllvmTMB_predict_isdm_source_missing"
  )

  valid <- dat[setdiff(names(dat), "value")]
  link <- suppressMessages(predict(
    fit, newdata = valid, re_form = ~0, type = "link"
  ))
  response <- suppressMessages(predict(
    fit, newdata = valid, re_form = ~0, type = "response"
  ))
  expected <- ifelse(
    valid$isdm_source == "portal",
    exp(link$est),
    -expm1(-exp(link$est))
  )
  expect_equal(response$est, expected, tolerance = 1e-12)

  unknown <- valid
  unknown$isdm_source <- "undeclared"
  expect_error(
    predict(fit, newdata = unknown, re_form = ~0),
    class = "gllvmTMB_predict_isdm_source_unknown"
  )
})

test_that("public integrated fit refuses an all-NA declared source-trait arm", {
  dat <- expand.grid(
    cell = factor(paste0("c", 1:4)),
    trait = factor(c("sp1", "sp2")),
    isdm_source = factor(c("source1", "source2")),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$value <- ifelse(dat$isdm_source == "source1", 1, 0)
  dat$value[dat$isdm_source == "source2" & dat$trait == "sp1"] <- NA_real_
  family_input <- isdm_sources(
    source1 = poisson(), source2 = binomial("cloglog")
  )
  expect_error(
    gllvmTMB(
      value ~ 0 + trait, data = dat, trait = "trait", unit = "cell",
      family = family_input,
      missing = miss_control(response = "include"), silent = TRUE
    ),
    class = "gllvmTMB_isdm_observed_source_incomplete"
  )

  all_count <- isdm_sources(
    source1 = poisson(), source2 = poisson()
  )
  expect_error(
    gllvmTMB(
      value ~ 0 + trait, data = dat, trait = "trait", unit = "cell",
      family = all_count,
      missing = miss_control(response = "include"), silent = TRUE
    ),
    class = "gllvmTMB_isdm_observed_source_incomplete"
  )
})
