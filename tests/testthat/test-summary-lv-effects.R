# Focused output regression: ordinary fixed effects and LV score-predictor
# coefficients occupy different parameter blocks, even with one latent axis.
make_summary_lv_fit <- function(d, ridge_tau = Inf) {
  set.seed(1467 + d)
  n <- 48L
  traits <- paste0("word", seq_len(4L))
  dat <- expand.grid(article_id = seq_len(n), analysis_word = traits)
  dat$article_id <- factor(dat$article_id)
  dat$analysis_word <- factor(dat$analysis_word, levels = traits)
  predictor <- rep(c(0, 1), length.out = n)
  dat$Fox_Nativeness <- predictor[as.integer(dat$article_id)]
  scores <- matrix(rnorm(n * d, sd = 0.5), n, d)
  scores[, 1L] <- scores[, 1L] + 0.5 * predictor
  loadings <- matrix(seq(-0.6, 0.6, length.out = 4L * d), 4L, d)
  eta <- rowSums(scores[as.integer(dat$article_id), , drop = FALSE] *
                 loadings[as.integer(dat$analysis_word), , drop = FALSE])
  dat$yi <- rbinom(nrow(dat), 1L, pnorm(eta))
  form <- if (d == 1L) {
    yi ~ 0 + analysis_word + latent(0 + trait | article_id,
                                  d = 1, lv = ~ Fox_Nativeness)
  } else {
    yi ~ 0 + analysis_word + latent(0 + trait | article_id,
                                  d = 2, lv = ~ Fox_Nativeness)
  }
  gllvmTMB(form, data = dat, trait = "analysis_word", unit = "article_id",
           family = binomial(link = "probit"),
           control = gllvmTMBcontrol(se = FALSE, loading_ridge = ridge_tau))
}

test_that("summary exposes predictor-informed LV coefficients at both ranks", {
  for (d in 1:2) {
    fit <- make_summary_lv_fit(d)
    sm <- summary(fit)
    expect_equal(sm$lv_effects$axis_effect,
                 extract_lv_effects(fit, type = "axis_effect"))
    expect_equal(sm$lv_effects$trait_effect,
                 extract_lv_effects(fit, type = "trait_effect"))
    expect_equal(sm$lv_effects$axis_effect$axis, paste0("LV", seq_len(d)))
    expect_equal(sm$lv_effects$axis_effect$predictor,
                 rep("Fox_Nativeness", d))
    expect_true(all(is.na(sm$lv_effects$axis_effect$std.error)))
    output <- paste(capture.output(print(sm)), collapse = "\n")
    expect_match(output, "Fox_Nativeness")
    expect_match(output, "rotation dependent")
    expect_match(output, "Induced trait effects")
    expect_match(output, "sdreport_skipped_no_lv_se")
    expect_match(output, "coverage is not validated")

    fit$sd_report <- list(pdHess = FALSE)
    sm <- summary(fit)
    expect_true(all(is.na(sm$lv_effects$trait_effect$std.error)))
    expect_true(all(sm$lv_effects$axis_effect$uncertainty_status ==
                      "sdreport_non_pd_hessian_no_lv_se"))

    # Unsupported inference routes must remain printable, without invoking
    # the extractor that deliberately rejects these objectives.
    fit$likelihood_weights <- list(active = TRUE)
    expect_identical(summary(fit)$lv_effects$status,
                     "withheld_unsupported_inference")
    fit$likelihood_weights <- NULL
    fit$estimator <- "MSPL"
    expect_identical(summary(fit)$lv_effects$status,
                     "withheld_unsupported_inference")
    fit$estimator <- "ML"
    fit$use$lv_B <- FALSE
    expect_null(summary(fit)$lv_effects)
  }
})

test_that("ridge summary reports likelihood separately from the penalised objective", {
  fit <- make_summary_lv_fit(2L, ridge_tau = 2)
  sm <- summary(fit)
  expect_true(isTRUE(sm$header$penalised))
  expect_equal(sm$header$logLik, -fit$objective_components$likelihood_nll)
  expect_equal(sm$header$logLik, as.numeric(suppressWarnings(logLik(fit))))
  expect_gt(fit$objective_components$ridge_penalty, 0)
  expect_false(isTRUE(all.equal(sm$header$logLik, -fit$opt$objective)))
  # Unpenalised sdreport curvature cannot supply ridge-MAP uncertainty,
  # even if that likelihood Hessian happens to be positive definite.
  for (pd in c(TRUE, FALSE)) {
    fit$sd_report <- list(pdHess = pd)
    for (kind in c("axis_effect", "trait_effect")) {
      effects <- extract_lv_effects(fit, type = kind)
      expect_true(all(is.finite(effects$estimate)))
      expect_true(all(is.na(effects$std.error)))
      expect_true(all(is.na(effects$lower)))
      expect_true(all(effects$uncertainty_status == "loading_ridge_point_only_no_lv_se"))
    }
  }
  fit$objective_components <- NULL
  fit$tmb_obj <- NULL
  stored <- summary(fit)
  expect_true(is.na(stored$header$logLik))
  expect_equal(stored$lv_effects$axis_effect$estimate,
               sm$lv_effects$axis_effect$estimate)
  expect_match(paste(capture.output(print(stored)), collapse = "\n"),
               "Log L is unavailable")
})


test_that("matched ridge curvature exposes posterior LV SDs in summary", {
  fit <- make_summary_lv_fit(2L, ridge_tau = 2)
  fit <- standard_errors(fit)
  expect_true(isTRUE(fit$sd_report$pdHess))
  sm <- summary(fit)
  for (kind in c("axis_effect", "trait_effect")) {
    expect_true(all(is.finite(sm$lv_effects[[kind]]$std.error)))
    expect_true(all(sm$lv_effects[[kind]]$uncertainty_status ==
      "loading_ridge_posterior_sd_no_sampling_ci_validation"))
  }
  expect_match(paste(capture.output(print(sm)), collapse = "\n"), "posterior SDs")
  stale <- fit
  stale$opt$par[1L] <- stale$opt$par[1L] + 0.1
  expect_true(all(is.na(extract_lv_effects(stale)$std.error)))
  expect_true(all(extract_lv_effects(stale)$uncertainty_status ==
    "loading_ridge_point_only_no_lv_se"))
})

test_that("unstable binomial LV fits suggest an explicit ridge", {
  fit <- make_summary_lv_fit(2L)
  fit$opt$convergence <- 1L
  hints <- suppressMessages(gllvmTMB_diagnose(fit, verbose = FALSE))$hints
  expect_true(any(grepl("loading_ridge = 2", hints, fixed = TRUE)))
  expect_true(any(grepl("Normal(0, 2^2)", hints, fixed = TRUE)))
})


test_that("binomial loading warnings remain visible in diagnosis", {
  fit <- make_summary_lv_fit(1L)
  fit$report$Lambda_B[1L, 1L] <- 50
  screen <- gllvmTMB:::.gllvmTMB_binomial_prevalence_loading_row(fit)
  expect_identical(screen$status[[1L]], "WARN")
  result <- suppressMessages(gllvmTMB_diagnose(fit, verbose = FALSE))
  expect_true(any(grepl(screen$message[[1L]], result$hints, fixed = TRUE)))
})
