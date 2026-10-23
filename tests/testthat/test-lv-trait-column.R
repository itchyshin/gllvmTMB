.lv_named_trait_data <- function() {
  set.seed(14675)
  n <- 30L
  x <- rep(c("Introduced", "Native"), each = n / 2L)
  z <- rnorm(n)
  data <- data.frame(article = factor(rep(seq_len(n), each = 5L)),
    analysis_word = factor(rep(paste0("w", 1:5), n)),
    nativeness = factor(rep(x, each = 5L)))
  eta <- rep(c(.1, -.2, .3, -.1, .2), n) +
    rep(c(.7, -.4, .5, -.3, .4), n) * rep(z + .5 * (x == "Native"), each = 5L)
  data$y <- rbinom(nrow(data), 1L, pnorm(eta))
  data
}

test_that("actual trait column is classified as an intercept-only LV block", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  f <- y ~ 0 + analysis_word +
    latent(0 + analysis_word | article, d = 1, lv = ~ nativeness)
  p <- gllvmTMB:::parse_multi_formula(gllvmTMB:::desugar_brms_sugar(f, trait_col = "analysis_word"), trait_col = "analysis_word")
  expect_equal(vapply(p$covstructs, function(x) x$extra$lhs_form, character(1L)),
    rep("intercept_only", 2L))
  expect_silent(gllvmTMB:::gll_prepare_lv_predictor_setup(p, .lv_named_trait_data(),
    trait = "analysis_word", site = "article", family_id_vec = rep(1L, 150L),
    link_id_vec = rep(1L, 150L)))
})

test_that("real trait spelling and placeholder fit the same d1 d2 and ridge models", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  data <- .lv_named_trait_data()
  for (setting in list(c(1, Inf), c(2, Inf), c(2, 2))) {
    d <- setting[1L]
    tau <- setting[2L]
    fit_one <- function(lhs, renamed = FALSE) {
      f <- y ~ 0 + analysis_word + latent(0 + trait | article, d = 1, lv = ~ nativeness)
      f[[3L]][[3L]][[2L]][[2L]][[3L]] <- as.name(lhs)
      f[[3L]][[3L]][["d"]] <- d
      selected <- if (renamed) "trait" else "analysis_word"
      fit_data <- data
      if (renamed) {
        names(fit_data)[names(fit_data) == "analysis_word"] <- "trait"
        f[[3L]][[2L]][[3L]] <- as.name("trait")
      }
      set.seed(1467)
      suppressMessages(suppressWarnings(gllvmTMB(f, data = fit_data,
        unit = "article", trait = selected, family = binomial(link = "probit"),
        control = gllvmTMBcontrol(se = FALSE, n_init = 1L, loading_ridge = tau))))
    }
    placeholder <- fit_one("trait")
    actual <- fit_one("analysis_word")
    renamed <- fit_one("trait", renamed = TRUE)
    expect_equal(renamed$opt$par, actual$opt$par, tolerance = 1e-10)
    expect_equal(as.numeric(suppressWarnings(logLik(renamed))),
      as.numeric(suppressWarnings(logLik(actual))), tolerance = 1e-10)
    expect_equal(renamed$report$B_lv_unit, actual$report$B_lv_unit, tolerance = 1e-10)
    expect_equal(actual$opt$par, placeholder$opt$par, tolerance = 1e-10)
    expect_equal(actual$opt$objective, placeholder$opt$objective, tolerance = 1e-10)
    expect_equal(as.numeric(suppressWarnings(logLik(actual))),
      as.numeric(suppressWarnings(logLik(placeholder))), tolerance = 1e-10)
    expect_equal(actual$report$B_lv_unit, placeholder$report$B_lv_unit, tolerance = 1e-10)
    expect_equal(actual$lv$X_lv_B, placeholder$lv$X_lv_B)
  }
})

test_that("resolved custom trait names retain the LHS and augmented LV guard", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  for (column in c("analysis_word", "response_species")) {
    f <- y ~ 0 + analysis_word + latent(0 + analysis_word | article, d = 1)
    f[[3L]][[3L]][[2L]][[2L]][[3L]] <- as.name(column)
    p <- gllvmTMB:::parse_multi_formula(gllvmTMB:::desugar_brms_sugar(f, trait_col = column), trait_col = column)
    expect_identical(as.character(p$covstructs[[1L]]$lhs[[3L]]), column)
    expect_identical(p$covstructs[[1L]]$extra$lhs_form, "intercept_only")
  }
  loadings <- gllvmTMB:::parse_multi_formula(gllvmTMB:::desugar_brms_sugar(
    y ~ 0 + analysis_word + latent(0 + analysis_word | article, d = 1, unique = FALSE, lv = ~ nativeness),
    trait_col = "analysis_word"), trait_col = "analysis_word")
  expect_length(loadings$covstructs, 1L)
  expect_identical(loadings$covstructs[[1L]]$extra$lhs_form, "intercept_only")
  common <- gllvmTMB:::parse_multi_formula(gllvmTMB:::desugar_brms_sugar(
    y ~ 0 + analysis_word + latent(0 + analysis_word | article, d = 1, common = TRUE, lv = ~ nativeness),
    trait_col = "analysis_word"), trait_col = "analysis_word")
  expect_true(common$covstructs[[2L]]$extra$common)
  expect_identical(common$covstructs[[2L]]$extra$lhs_form, "intercept_only")
  expect_error(gllvmTMB:::desugar_brms_sugar(
    y ~ 0 + analysis_word +
      latent(0 + analysis_word + (0 + analysis_word):x | article, d = 1, lv = ~ nativeness),
    trait_col = "analysis_word"), "augmented|not supported")
  wrong <- y ~ 0 + analysis_word + latent(0 + other_predictor | article, d = 1, lv = ~ nativeness)
  expect_error(gllvmTMB:::desugar_brms_sugar(wrong, trait_col = "analysis_word"), "augmented|not supported")
})

test_that("malformed latent calls retain useful formula advice", {
  expect_error(gllvmTMB:::desugar_brms_sugar(y ~ latent(article, d = 1)), "lhs.*group")
  expect_error(gllvmTMB:::desugar_brms_sugar(y ~ latent()), "lhs.*group")
  expect_error(gllvmTMB:::desugar_brms_sugar(
    y ~ latent(0 + analysis_word | article, d = 1, lhs_form = "intercept_only", lv = ~ nativeness),
    trait_col = "analysis_word"), "Unknown argument")
})

test_that("selected trait names classify parenthesised forms without becoming slopes", {
  expect_identical(gllvmTMB:::.gllvmTMB_lhs_form(quote((0 + analysis_word)), "analysis_word")$lhs_form,
    "intercept_only")
  expect_identical(gllvmTMB:::.gllvmTMB_lhs_form(quote(1 + analysis_word), "analysis_word")$lhs_form,
    "unsupported")
  expect_identical(gllvmTMB:::.gllvmTMB_lhs_form(quote(0 + analysis_word + (0 + analysis_word):x), "analysis_word")$lhs_form,
    "long_intercept_slope")
})

test_that("screen preparation threads the selected trait column to the shared parser", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  prepared <- gllvmTMB:::.screen_prepare_formula_data(
    y ~ 0 + analysis_word + latent(0 + analysis_word | article, d = 1, lv = ~ nativeness),
    data = .lv_named_trait_data(), weights = NULL,
    trait = "analysis_word", unit = "article", missing = miss_control())
  expect_identical(prepared$parsed$covstructs[[1L]]$extra$lhs_form, "intercept_only")
  expect_identical(prepared$parsed$covstructs[[2L]]$extra$lhs_form, "intercept_only")
})
