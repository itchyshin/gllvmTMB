test_that("Poisson link-residual variance uses AGHQ conditional modes", {
  set.seed(497); n <- 50L; nt <- 4L
  unit <- factor(rep(seq_len(n), each = nt)); trait <- factor(rep(letters[1:nt], n)); z <- rnorm(n)
  eta <- rep(c(-.3, .1, .4, -.1), n) + rep(c(.8, .6, -.5, .7), n) * rep(z, each = nt)
  dat <- data.frame(value = rpois(n * nt, exp(eta)), unit, trait)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    dat, trait = "trait", unit = "unit", family = poisson(),
    control = gllvmTMBcontrol(se = FALSE, aghq = 5L, aghq_multistart = TRUE, n_init = 2L,
                              svd_start = FALSE, loading_ridge = .75))))
  expect_true(isTRUE(fit$aghq$used)); expect_true(isTRUE(fit$aghq$converged))
  eta <- .aghq_conditional_training_eta(fit)
  expected <- vapply(seq_len(nt), function(i) log1p(1 / mean(exp(eta[as.integer(trait) == i]))), numeric(1))
  expect_equal(as.numeric(link_residual_per_trait(fit)), expected, tolerance = 1e-8)
})

test_that("AGHQ binomial saturation screen uses conditional probabilities", {
  set.seed(9174); n <- 30L
  trait <- factor(rep(c("a", "b", "c"), n)); unit <- factor(rep(seq_len(n), each = 3L))
  x <- rep(seq(-1, 1, length.out = n), each = 3L); z <- rnorm(n)
  eta <- rep(c(-.5, .1, .3), n) + rep(c(.2, -.3, .4), n) * x + rep(c(.7, -.5, .3), n) * rep(z, each = 3L)
  dat <- data.frame(value = rbinom(3L * n, 1, pnorm(eta)), trait, unit, x)
  prior <- data.frame(coefficient = "traita", mean = .2, sd = 2)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(value ~ 0 + trait + trait:x + latent(0 + trait | unit, d = 1, unique = FALSE),
    dat, trait = "trait", unit = "unit", family = binomial("probit"),
    control = gllvmTMBcontrol(fixed_effect_priors = prior, loading_ridge = .75, aghq = 5L, aghq_n_adapt = 30L,
                              aghq_multistart = FALSE, svd_start = FALSE, n_init = 1L))))
  expect_true(isTRUE(fit$aghq$used)); expect_true(isTRUE(fit$aghq$converged))
  ref <- fit; ref$aghq$used <- FALSE; ref$report$eta <- .aghq_conditional_training_eta(fit)
  actual <- .gllvmTMB_binomial_prevalence_loading_row(fit, saturation_prob_thresh = .6)
  expected <- .gllvmTMB_binomial_prevalence_loading_row(ref, saturation_prob_thresh = .6)
  expect_equal(actual, expected)
  fit$tmb_obj$env$data$aghq_mode <- NULL
  fit$aghq$z_B_mode <- NULL
  expect_no_error(unavailable <- .gllvmTMB_binomial_prevalence_loading_row(fit))
  expect_identical(unavailable$status, "INFO")
  expect_match(unavailable$message, "saturation.*not evaluated")
  expect_no_error(suppressWarnings(check_gllvmTMB(fit)))
  messages <- character()
  text <- capture.output(withCallingHandlers(suppressWarnings(gllvmTMB_diagnose(fit)),
    message = function(m) {
      messages <<- c(messages, conditionMessage(m))
      invokeRestart("muffleMessage")
    }))
  expect_match(paste(c(text, messages), collapse = " "), "saturation.*not evaluated")
  flagged <- .gllvmTMB_binomial_prevalence_loading_row(fit, loading_absolute_thresh = 0)
  expect_identical(flagged$status, "WARN")
  expect_match(flagged$message, "saturation.*not evaluated")
  expect_equal(as.numeric(link_residual_per_trait(fit)), rep(1, 3L))
  fit$tmb_data$family_id_vec[1L] <- 2L
  seen <- character()
  mixed <- withCallingHandlers(link_residual_per_trait(fit), warning = function(w) {
    seen <<- c(seen, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  expect_true(any(grepl("multiple families", seen)))
  expect_true(any(grepl("Link-scale residual variance is unavailable", seen, fixed = TRUE)))
  expect_true(is.na(mixed[1L]))
  expect_equal(as.numeric(mixed[-1L]), c(1, 1))
  fit$tmb_data$family_id_vec[as.integer(fit$data$trait) == 1L] <- 2L
  expect_error(link_residual_per_trait(fit), class = "gllvmTMB_aghq_modes_unavailable")
})
