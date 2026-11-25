## Coverage (cursor-cloud-1125x4g): assorted guard rails across R/ files.

.cov1125x4g_binom <- function() {
  set.seed(112547)
  n <- 16L
  df <- data.frame(
    unit = factor(rep(seq_len(n / 2L), each = 2L)),
    trait = factor(rep(c("a", "b"), n / 2L)),
    value = stats::rbinom(n, 1, 0.4)
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df,
    unit = "unit",
    trait = "trait",
    family = binomial(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE, warn_runaway = FALSE),
    silent = TRUE
  )))
}

test_that("gll_prepare_offset() allows zero offsets on gaussian rows", {
  df <- data.frame(x = 1:2)
  off <- gllvmTMB:::gll_prepare_offset(
    quote(c(0, 0)), df, environment(),
    family_id_vec = c(0L, 0L), link_id_vec = c(0L, 0L),
    family_per_row = rep(list(gaussian()), 2), trait_vec = c("a", "b")
  )
  expect_equal(off, c(0, 0))
})

test_that("gll_prepare_offset() accepts poisson offsets", {
  df <- data.frame(x = 1:2, off = c(0.5, 0.2))
  out <- gllvmTMB:::gll_prepare_offset(
    quote(off), df, environment(),
    family_id_vec = c(2L, 2L), link_id_vec = c(0L, 0L),
    family_per_row = rep(list(poisson()), 2), trait_vec = c("a", "b")
  )
  expect_equal(out, c(0.5, 0.2))
})

test_that("gll_prepare_offset() allows cloglog binomial offsets", {
  df <- data.frame(off = c(1, 2))
  out <- gllvmTMB:::gll_prepare_offset(
    quote(off), df, environment(),
    family_id_vec = c(1L, 1L), link_id_vec = c(2L, 2L),
    family_per_row = rep(list(binomial()), 2), trait_vec = c("a", "b")
  )
  expect_equal(out, c(1, 2))
})

test_that("loading_profile() rejects non-numeric grid_extent", {
  fit <- .cov1125x4g_binom()
  expect_error(loading_profile(fit, grid_extent = "wide"), "numeric")
})

test_that("confint_inspect() rejects non-multi stubs", {
  expect_error(confint_inspect(structure(list(), class = "lm"), "x"), "gllvmTMB")
})

test_that(".gllvmTMB_mspl_nbinom1_jeffreys() returns a numeric scalar", {
  X <- cbind(1, c(-1, 0, 1, 2))
  val <- gllvmTMB:::.gllvmTMB_mspl_nbinom1_jeffreys(X, mu = c(0, 0.2, 0.4, 0.6), phi = 2)
  expect_type(val, "double")
  expect_length(val, 1L)
})

test_that(".gllvmTMB_mspl_nbinom1_exact_I_eta() is non-negative", {
  I <- gllvmTMB:::.gllvmTMB_mspl_nbinom1_exact_I_eta(1, 2)
  expect_gte(I, 0)
})

test_that(".mn_classify_covstruct() passes propto through", {
  out <- gllvmTMB:::.mn_classify_covstruct(
    list(kind = "propto"), "site", "ss", "sp", "cl"
  )
  expect_true(out$admitted)
})

test_that("miss_control() returns a list with predictor field", {
  mc <- miss_control(predictor = "model")
  expect_type(mc, "list")
  expect_equal(mc$predictor, "model")
})

test_that("cumulative_logit() builds an impute family", {
  fam <- cumulative_logit()
  expect_s3_class(fam, "gllvmTMB_impute_family")
  m <- impute_model(x ~ z, family = fam)
  expect_equal(m$family_type, "ordinal")
})

test_that("tidy() returns coefficient rows on a binomial fit", {
  fit <- .cov1125x4g_binom()
  td <- tidy(fit)
  expect_s3_class(td, "data.frame")
  expect_gt(nrow(td), 0L)
  expect_true("estimate" %in% names(td))
})

test_that("logLik and npar stay consistent", {
  fit <- .cov1125x4g_binom()
  expect_true(attr(logLik(fit), "nobs") > 0L)
  expect_true(attr(logLik(fit), "df") >= 1L)
})

test_that("weights() returns ones on unweighted fits", {
  fit <- .cov1125x4g_binom()
  w <- weights(fit)
  expect_true(all(w == 1))
})