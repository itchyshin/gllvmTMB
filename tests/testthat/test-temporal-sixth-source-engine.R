.temporal_sixth_fixture <- function() {
  out <- expand.grid(
    series = paste0("s", 1:3), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  out$unit <- out$series
  out$value <- with(out, as.numeric(factor(trait)) + occasion / 10)
  out
}

test_that("temporal source uses a dedicated state tier rather than B scores", {
  dat <- .temporal_sixth_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = dat, unit = "series", family = gaussian(), silent = TRUE
  ))

  expect_equal(fit$tmb_data$n_temporal_states, 9L)
  expect_length(fit$tmb_data$temporal_state_id, nrow(fit$data))
  expect_true(all(fit$tmb_data$temporal_predecessor %in% c(-1L, 0:8)))
  expect_true(any(fit$tmb_data$temporal_gap == 2L))
  expect_true(any(fit$tmb_data$temporal_gap == 4L))
  expect_equal(fit$tmb_data$use_rr_B, 0L)
  random_names <- names(fit$tmb_obj$env$par)[fit$tmb_obj$env$random]
  expect_false(any(grepl("^z_B", random_names)))
  expect_true(any(grepl("^q_temporal", random_names)))
  expect_true("q_temporal" %in% names(fit$tmb_obj$env$parList(fit$opt$par)))
  temporal <- extract_temporal(fit)
  expect_true(all(temporal$variance$component == "temporal_indep_variance"))
  expect_equal(nrow(temporal$variance), fit$n_traits)
})

test_that("temporal admission keeps an ordinary unit intercept separate", {
  dat <- .temporal_sixth_fixture()
  expect_s3_class(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion) +
      (1 | series),
    data = dat, unit = "series", family = gaussian(), silent = TRUE
  )), "gllvmTMB_multi")
})

test_that("temporal series may use a distinct label for the same unit partition", {
  dat <- .temporal_sixth_fixture()
  dat$unit_label <- paste0("unit-", dat$series)
  expect_s3_class(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = dat, unit = "unit_label", family = gaussian(), silent = TRUE
  )), "gllvmTMB_multi")
})

test_that("ordinary unit_obs stays a unit-nested grouping, not a temporal state", {
  dat <- .temporal_sixth_fixture()
  dat$within_unit <- dat$series
  expect_s3_class(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = dat, unit = "series", unit_obs = "within_unit",
    family = gaussian(), silent = TRUE
  )), "gllvmTMB_multi")

  dat$crossed_obs <- rep(c("shared", "other"), length.out = nrow(dat))
  expect_error(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = dat, unit = "series", unit_obs = "crossed_obs",
    family = gaussian(), silent = TRUE
  ), "unit_obs.*nested")
})

test_that("temporal source composes with every ordinary unit and unit_obs mode", {
  dat <- .temporal_sixth_fixture()
  dat$within_unit <- dat$series
  ordinary <- c("indep", "dep", "latent")
  for (level in c("series", "within_unit")) {
    for (mode in ordinary) {
      term <- if (identical(mode, "latent")) {
        call("latent", call("|", quote(0 + trait), as.name(level)), d = 1L)
      } else {
        call(mode, call("|", quote(0 + trait), as.name(level)))
      }
      form <- as.formula(call("~", quote(value), call("+",
        call("+", quote(0 + trait),
          quote(temporal_indep(0 + trait | series, time = occasion))), term)))
      fit <- suppressWarnings(gllvmTMB(form, data = dat, unit = "series",
        unit_obs = "within_unit", family = gaussian(), silent = TRUE))
      expect_s3_class(fit, "gllvmTMB_multi")
      expect_equal(fit$tmb_data$use_temporal, 1L)
    }
  }
})

test_that("ordinary unit ordination remains available beside a temporal source", {
  dat <- .temporal_sixth_fixture()
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion) +
      latent(0 + trait | series, d = 1, unique = FALSE),
    data = dat, unit = "series", family = gaussian(), silent = TRUE
  ))
  ordination <- extract_ordination(fit, level = "unit")
  expect_equal(nrow(ordination$scores), length(levels(fit$data$series)))
  expect_equal(rownames(ordination$scores), levels(fit$data$series))
  expect_false("pair_id" %in% names(ordination))
})

test_that("composed temporal simulation redraws every supported ordinary tier", {
  dat <- .temporal_sixth_fixture()
  dat$within_unit <- paste(dat$series, dat$occasion)
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion) +
      indep(0 + trait | series) + indep(0 + trait | within_unit),
    data = dat, unit = "series", unit_obs = "within_unit",
    family = gaussian(), silent = TRUE
  ))
  expect_equal(dim(simulate(fit, nsim = 1, seed = 41L)),
    c(nrow(fit$data), 1L))
  expect_equal(dim(simulate(fit, nsim = 2, seed = 41L, condition_on_RE = TRUE)),
    c(nrow(fit$data), 2L))
})

test_that("temporal long and wide calls retain modes, labels, and lifecycle guards", {
  long <- .temporal_sixth_fixture()
  wide <- unique(long[c("series", "occasion")])
  for (trait_name in paste0("t", 1:3)) {
    wide[[paste0("y", sub("t", "", trait_name))]] <- long$value[long$trait == trait_name]
  }
  specs <- list(
    list(mode = "indep", long = quote(temporal_indep(0 + trait | series, time = occasion)),
      wide = quote(temporal_indep(1 | series, time = occasion))),
    list(mode = "dep", long = quote(temporal_dep(0 + trait | series, time = occasion)),
      wide = quote(temporal_dep(1 | series, time = occasion))),
    list(mode = "latent", long = quote(temporal_latent(0 + trait | series, time = occasion, unique = TRUE)),
      wide = quote(temporal_latent(1 | series, time = occasion, unique = TRUE)))
  )
  for (spec in specs) {
    long_formula <- as.formula(call("~", quote(value), call("+", quote(0 + trait), spec$long)))
    wide_formula <- as.formula(call("~", call("traits", quote(y1), quote(y2), quote(y3)),
      call("+", quote(1), spec$wide)))
    long_fit <- suppressWarnings(gllvmTMB(long_formula, data = long,
      unit = "series", family = gaussian(), silent = TRUE))
    wide_fit <- suppressWarnings(gllvmTMB(wide_formula, data = wide,
      unit = "series", family = gaussian(), silent = TRUE))
    expect_identical(long_fit$temporal$mode, spec$mode)
    expect_identical(wide_fit$temporal$mode, spec$mode)
    if (identical(spec$mode, "dep")) {
      expect_equal(dim(extract_temporal(long_fit)$loadings), c(3L, 3L))
    }
    expect_equal(unname(as.matrix(extract_temporal(long_fit)$pair_index)),
      unname(as.matrix(extract_temporal(wide_fit)$pair_index)))
    if (identical(spec$mode, "latent")) {
      scores <- getLV(long_fit)
      ordination <- extract_ordination(long_fit, level = "unit")
      expect_equal(attr(scores, "temporal_index")$pair_id, rownames(scores))
      expect_equal(ordination$row_index$pair_id, rownames(ordination$scores))
      expect_equal(rownames(ordination$loadings), levels(long_fit$data$trait))
    } else {
      expect_null(getLV(long_fit))
    }
    prediction <- predict(long_fit)
    expect_equal(prediction[c("series", "occasion", "trait")],
      long_fit$data[c("series", "occasion", "trait")])
    expect_equal(dim(simulate(long_fit, nsim = 2, seed = 19L)), c(nrow(long_fit$data), 2L))
    expect_s3_class(suppressWarnings(update(long_fit)), "gllvmTMB_multi")
    expect_error(predict(long_fit, newdata = long), "newdata.*temporal")
    expect_error(confint(long_fit), "not available.*temporal")
    expect_error(select_lv(long_formula, data = long, unit = "series",
      trait = "trait", d_max = 1), "not available.*temporal")
  }
})

test_that("temporal source refuses each deferred provider and duplicate temporal terms", {
  dat <- .temporal_sixth_fixture()
  deferred <- list(
    quote(phylo_indep(0 + trait | series)),
    quote(animal_indep(0 + trait | series)),
    quote(spatial_indep(0 + trait | series))
  )
  for (other in deferred) {
    form <- as.formula(call("~", quote(value), call("+",
      call("+", quote(0 + trait), quote(temporal_indep(0 + trait | series, time = occasion))), other)))
    expect_error(gllvmTMB(form, data = dat, unit = "series", family = gaussian()),
      if (as.character(other[[1L]]) %in% c("phylo_indep", "animal_indep"))
        "requires replicated AR1" else "temporal covariance term cannot be combined",
      info = deparse(other))
  }
  kernel_form <- value ~ 0 + trait +
    temporal_indep(0 + trait | series, time = occasion) +
    kernel_indep(series, K = diag(3L), name = "deferred_kernel")
  expect_error(gllvmTMB(kernel_form, data = dat, unit = "series", family = gaussian()),
    "requires replicated AR1")
  expect_error(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion) +
      temporal_dep(0 + trait | series, time = occasion),
    data = dat, unit = "series", family = gaussian()
  ), "Only one temporal covariance term")
})

test_that("all temporal modes and both time structures reach their dedicated tier", {
  dat <- .temporal_sixth_fixture()
  dat$elapsed <- c(0, 0.5, 2)[match(dat$occasion, c(1L, 3L, 7L))]
  specs <- list(
    list(mode = "indep", structure = "ar1",
      term = quote(temporal_indep(0 + trait | series, time = occasion))),
    list(mode = "dep", structure = "ar1",
      term = quote(temporal_dep(0 + trait | series, time = occasion))),
    list(mode = "latent", structure = "ar1",
      term = quote(temporal_latent(0 + trait | series, time = occasion, unique = FALSE))),
    list(mode = "latent", structure = "ar1",
      term = quote(temporal_latent(0 + trait | series, time = occasion, unique = TRUE))),
    list(mode = "indep", structure = "ou",
      term = quote(temporal_indep(0 + trait | series, time = elapsed, structure = "ou"))),
    list(mode = "dep", structure = "ou",
      term = quote(temporal_dep(0 + trait | series, time = elapsed, structure = "ou"))),
    list(mode = "latent", structure = "ou",
      term = quote(temporal_latent(0 + trait | series, time = elapsed, unique = FALSE, structure = "ou"))),
    list(mode = "latent", structure = "ou",
      term = quote(temporal_latent(0 + trait | series, time = elapsed, unique = TRUE, structure = "ou")))
  )
  for (spec in specs) {
    formula <- as.formula(call("~", quote(value), call("+", quote(0 + trait), spec$term)))
    fit <- suppressWarnings(gllvmTMB(formula, data = dat, unit = "series",
      family = gaussian(), silent = TRUE))
    expect_identical(fit$temporal$mode, spec$mode)
    expect_identical(fit$temporal$structure, spec$structure)
    expect_equal(fit$tmb_data$use_temporal, 1L)
  }
})
