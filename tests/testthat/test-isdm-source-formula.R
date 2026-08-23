## Per-source iSDM observation formulas: constructor and source-masked design.

.isdm_source_formula_fixture <- function() {
  data.frame(
    trait = factor(rep(c("sp1", "sp2"), 3L)),
    isdm_source = factor(rep(c("gbif", "inat", "survey"), each = 2L),
                           levels = c("gbif", "inat", "survey")),
    access = c(0.2, -0.1, 0.4, -0.3, NA, NA),
    popdens = c(1.0, 1.2, 0.8, 0.7, NA, NA),
    observer = factor(c(NA, NA, NA, NA, "o1", "o2")),
    method = factor(c(NA, NA, NA, NA, "walk", "point"))
  )
}

.isdm_source_formula_family <- function() {
  isdm_sources(
    gbif = isdm_source(poisson(link = "log"), observation = ~ access + popdens),
    inat = isdm_source(poisson(), observation = ~ access + popdens),
    survey = isdm_source(poisson(), observation = ~ 0 + observer + method)
  )
}

.isdm_source_recovery_fixture <- function(seed = 41L, n_cell = 120L) {
  set.seed(seed)
  cells <- paste0("c", seq_len(n_cell))
  traits <- c("sp1", "sp2")
  env <- as.numeric(scale(stats::runif(n_cell)))
  make_source <- function(source) {
    d <- expand.grid(cell_id = cells, trait = traits, stringsAsFactors = FALSE)
    cell_id <- match(d$cell_id, cells)
    trait_id <- match(d$trait, traits)
    d$isdm_source <- source
    d$env <- env[cell_id]
    d$support <- 1.5
    d$access <- stats::rnorm(nrow(d))
    d$observer <- NA_character_
    d$method <- NA_character_
    eta <- c(-0.2, 0.15)[trait_id] + c(0.3, -0.2)[trait_id] * d$env
    if (identical(source, "gbif")) eta <- eta + 0.25 + 0.5 * d$access
    if (identical(source, "survey")) {
      d$observer <- sample(c("o1", "o2"), nrow(d), replace = TRUE)
      d$method <- sample(c("walk", "point"), nrow(d), replace = TRUE)
      eta <- eta + ifelse(d$observer == "o2", 0.2, 0) +
        ifelse(d$method == "point", -0.15, 0)
    }
    d$value <- stats::rpois(nrow(d), d$support * exp(eta))
    d
  }
  dat <- rbind(make_source("gbif"), make_source("inat"), make_source("survey"))
  dat$trait <- factor(dat$trait)
  dat$cell_id <- factor(dat$cell_id)
  dat$isdm_source <- factor(dat$isdm_source,
                            levels = c("gbif", "inat", "survey"))
  dat$observer <- factor(dat$observer)
  dat$method <- factor(dat$method)
  dat$log_support <- log(dat$support)
  dat
}

test_that("isdm_source() validates and preserves an observation formula", {
  wrapped <- isdm_source(poisson(link = "log"), observation = ~ access + popdens)
  expect_s3_class(wrapped, "gllvmTMB_isdm_source")
  expect_s3_class(wrapped$family, "family")
  expect_identical(deparse(wrapped$observation), "~access + popdens")
  expect_error(isdm_source(poisson(), observation = quote(access + popdens)), "one-sided")
  expect_error(isdm_source(list(), observation = ~ access), "family")
})

test_that("isdm_sources() accepts wrapped and bare laws without changing bare laws", {
  wrapped <- .isdm_source_formula_family()
  expect_identical(names(wrapped), c("gbif", "inat", "survey"))
  expect_identical(names(attr(wrapped, "isdm_observation")), names(wrapped))
  bare <- isdm_sources(gbif = poisson(), inat = poisson(), survey = binomial("cloglog"))
  expect_null(attr(bare, "isdm_observation", exact = TRUE))
})

test_that("iSDM observation designs are source-masked after filtering", {
  dat <- .isdm_source_formula_fixture()
  fam <- .isdm_source_formula_family()
  X <- stats::model.matrix(~ 0 + trait, data = dat)
  out <- .gll_isdm_observation_design(X, dat, dat$isdm_source, fam)
  added <- setdiff(colnames(out), colnames(X))
  expect_true(all(grepl("^isdm_source:", added)))
  gbif_cols <- added[grep("^isdm_source:gbif", added)]
  survey_cols <- added[grep("^isdm_source:survey", added)]
  expect_equal(unname(out[dat$isdm_source != "gbif", gbif_cols, drop = FALSE]),
               matrix(0, sum(dat$isdm_source != "gbif"), length(gbif_cols)))
  expect_equal(unname(out[dat$isdm_source != "survey", survey_cols, drop = FALSE]),
               matrix(0, sum(dat$isdm_source != "survey"), length(survey_cols)))
  expect_false(anyNA(out))
})

test_that("iSDM observation formulas accept source-specific intercept or 0 + bases", {
  dat <- .isdm_source_formula_fixture()
  X <- stats::model.matrix(~ 0 + trait, data = dat)
  no_intercept <- .gll_isdm_observation_design(
    X, dat, dat$isdm_source,
    isdm_sources(gbif = isdm_source(poisson(), observation = ~ 0 + access),
                 inat = poisson(), survey = poisson())
  )
  expect_true("isdm_source:gbif:access" %in% colnames(no_intercept))
  expect_equal(unname(no_intercept[dat$isdm_source != "gbif", "isdm_source:gbif:access"]),
               rep(0, sum(dat$isdm_source != "gbif")))

  ## A Poisson survey may likewise use a no-intercept observer/method basis.
  ## This crossed fixture makes the source levels estimable beyond `0 + trait`.
  survey_dat <- data.frame(
    trait = factor(rep(c("sp1", "sp2"), 6L)),
    isdm_source = factor(rep(c("gbif", "survey"), each = 6L),
                            levels = c("gbif", "survey")),
    observer = factor(c(rep(NA_character_, 6L), "o1", "o1", "o2", "o2", "o1", "o2")),
    method = factor(c(rep(NA_character_, 6L), "walk", "point", "point", "walk", "walk", "point"))
  )
  survey_X <- stats::model.matrix(~ 0 + trait, data = survey_dat)
  survey_basis <- .gll_isdm_observation_design(
    survey_X, survey_dat, survey_dat$isdm_source,
    isdm_sources(gbif = poisson(),
                 survey = isdm_source(poisson(), observation = ~ 0 + observer + method))
  )
  survey_cols <- grep("^isdm_source:survey:", colnames(survey_basis), value = TRUE)
  expect_gt(length(survey_cols), 0L)
  expect_equal(unname(survey_basis[survey_dat$isdm_source != "survey", survey_cols, drop = FALSE]),
               matrix(0, sum(survey_dat$isdm_source != "survey"), length(survey_cols)))
})

test_that("iSDM observation formulas fail where the user can repair them", {
  dat <- .isdm_source_formula_fixture()
  X <- stats::model.matrix(~ 0 + trait, data = dat)
  expect_error(
    .gll_isdm_observation_design(
      X, dat, dat$isdm_source,
      isdm_sources(gbif = isdm_source(poisson(), observation = ~ unavailable),
                   inat = poisson(), survey = poisson())
    ),
    "not found"
  )
  dat$access[1L] <- NA_real_
  expect_error(.gll_isdm_observation_design(X, dat, dat$isdm_source,
                                             .isdm_source_formula_family()),
               "missing values")
  dat <- .isdm_source_formula_fixture()
  duplicate_X <- stats::model.matrix(~ 0 + trait + trait:isdm_source, data = dat)
  expect_error(.gll_isdm_observation_design(duplicate_X, dat, dat$isdm_source,
                                             .isdm_source_formula_family()),
               "duplicate")
})

test_that("all-Poisson source formulas fit and recover a source-masked observation slope", {
  dat <- .isdm_source_recovery_fixture()
  fam <- isdm_sources(
    gbif = isdm_source(poisson(), observation = ~ access),
    inat = poisson(),
    survey = isdm_source(poisson(), observation = ~ 0 + observer + method)
  )
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:env + offset(log_support),
    data = dat, trait = "trait", unit = "cell_id", family = fam,
    silent = TRUE
  ))
  expect_identical(fit$opt$convergence, 0L)
  access_col <- "isdm_source:gbif:access"
  estimate <- fit$opt$par[names(fit$opt$par) == "b_fix"][match(access_col, fit$X_fix_names)]
  expect_equal(unname(estimate), 0.5, tolerance = 0.15)
  expect_equal(unname(fit$tmb_data$X_fix[dat$isdm_source != "gbif", access_col]),
               rep(0, sum(dat$isdm_source != "gbif")))
  survey_cols <- grep("^isdm_source:survey:", fit$X_fix_names, value = TRUE)
  expect_gt(length(survey_cols), 0L)
  expect_false(anyNA(fit$opt$par[names(fit$opt$par) == "b_fix"]))
})
