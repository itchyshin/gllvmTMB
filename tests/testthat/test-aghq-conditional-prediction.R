test_that("AGHQ conditional predictions use the final integration modes", {
  set.seed(9174)
  n <- 30L
  trait <- factor(rep(c("a", "b", "c"), n))
  unit <- factor(rep(seq_len(n), each = 3L))
  x <- rep(seq(-1, 1, length.out = n), each = 3L)
  z <- rnorm(n)
  eta <- rep(c(-.5, .1, .3), n) + rep(c(.2, -.3, .4), n) * x +
    rep(c(.7, -.5, .3), n) * rep(z, each = 3L)
  dat <- data.frame(value = rbinom(3L * n, 1, pnorm(eta)), trait, unit, x)
  pri <- data.frame(coefficient = "traita", mean = .2, sd = 2)
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + trait:x + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = dat, trait = "trait", unit = "unit", family = binomial("probit"),
    control = gllvmTMBcontrol(fixed_effect_priors = pri, loading_ridge = .75,
      aghq = 5L, aghq_n_adapt = 30L, aghq_multistart = FALSE,
      svd_start = FALSE, n_init = 1L)
  ))
  expect_true(isTRUE(fit$aghq$used))
  mode <- fit$tmb_obj$env$data$aghq_mode
  expect_identical(dim(mode), c(n, 1L))
  fixed <- as.numeric(model.matrix(~ 0 + trait + trait:x, dat) %*% coef(fit))
  expected <- fixed + rowSums(fit$report$Lambda_B[as.integer(trait), , drop = FALSE] *
    mode[as.integer(unit), , drop = FALSE])
  expect_equal(predict(fit, type = "link")$est, expected, tolerance = 1e-7)
  expect_equal(predict(fit, type = "response")$est, pnorm(expected), tolerance = 1e-7)
  expect_equal(predict(fit, type = "link", re_form = ~0)$est, fixed, tolerance = 1e-7)
  idx <- c(7L, 1L, 45L, 4L, 7L)
  expect_equal(suppressMessages(predict(fit, newdata = dat[idx, ], type = "link")$est),
               expected[idx], tolerance = 1e-7)
  unseen <- dat[1:3, , drop = FALSE]
  unseen$unit <- factor(rep("new-unit", nrow(unseen)))
  expect_equal(suppressMessages(predict(fit, newdata = unseen, type = "link")$est),
               as.numeric(model.matrix(~ 0 + trait + trait:x, unseen) %*% coef(fit)),
               tolerance = 1e-7)
  set.seed(1901); sim <- simulate(fit, nsim = 1L, condition_on_RE = TRUE)
  set.seed(1901); sim_expected <- .draw_y_per_family(fit, expected)
  expect_equal(as.numeric(sim[, 1]), as.numeric(sim_expected))
  reference <- fit
  reference$aghq$used <- FALSE
  reference$report$eta <- expected
  expect_equal(residuals(fit, seed = 2002), residuals(reference, seed = 2002))
  path <- tempfile(fileext = ".rds"); saveRDS(fit, path)
  expect_equal(predict(readRDS(path), type = "link")$est, expected, tolerance = 1e-7)
  fit$tmb_obj$env$data$aghq_mode <- NULL
  fit$aghq$z_B_mode <- NULL
  expect_error(predict(fit, type = "link"), class = "gllvmTMB_aghq_modes_unavailable")
  expect_equal(predict(fit, type = "link", re_form = ~0)$est, fixed, tolerance = 1e-7)
})

test_that("two-axis AGHQ mode reconstruction respects unit and trait indices", {
  mode <- rbind(c(1, 2), c(-1, .5))
  loadings <- rbind(c(1, 0), c(.5, -1), c(-.25, .75))
  fit <- list(
    aghq = list(used = TRUE), n_sites = 2L, d_B = 2L,
    tmb_obj = list(env = list(data = list(aghq_mode = mode))),
    tmb_data = list(site_id = c(1L, 0L, 1L), trait_id = c(2L, 1L, 0L)),
    report = list(eta = c(.1, .2, .3), Lambda_B = loadings)
  )
  expected <- c(.1 + sum(mode[2, ] * loadings[3, ]),
                .2 + sum(mode[1, ] * loadings[2, ]),
                .3 + sum(mode[2, ] * loadings[1, ]))
  expect_equal(.aghq_conditional_training_eta(fit), expected)
  fit$aghq$z_B_mode <- t(mode)
  fit$tmb_obj$env$data$aghq_mode <- NULL
  expect_equal(.aghq_conditional_training_eta(fit), expected)
  fit$aghq$z_B_mode <- matrix(NA_real_, 2L, 2L)
  expect_error(.aghq_conditional_training_eta(fit), class = "gllvmTMB_aghq_modes_unavailable")
})

test_that("a converged two-axis AGHQ fit uses both modes in predictions", {
  set.seed(5)
  n <- 80L
  loadings <- cbind(c(1.2, .8, .6, .9, .5, .7), c(0, .7, -.5, .4, .8, -.6))
  z <- matrix(rnorm(n * 2L), n, 2L)
  eta <- z %*% t(loadings) + matrix(c(0, .3, -.2, .5, -.5, 0), n, 6, byrow = TRUE)
  y <- matrix(rbinom(n * 6L, 1, pnorm(eta)), n, 6L)
  dat <- data.frame(unit = factor(rep(seq_len(n), each = 6L)),
                    trait = factor(rep(paste0("t", 1:6), n)), value = as.vector(t(y)))
  prior <- data.frame(coefficient = paste0("traitt", 1:6), mean = 0, sd = 10)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE),
    dat, trait = "trait", unit = "unit", family = binomial("probit"),
    control = gllvmTMBcontrol(se = FALSE, fixed_effect_priors = prior,
      aghq = 9L, aghq_multistart = FALSE, n_init = 1L)
  )))
  expect_true(isTRUE(fit$aghq$used))
  expect_true(isTRUE(fit$aghq$converged))
  mode <- fit$tmb_obj$env$data$aghq_mode
  L <- fit$report$Lambda_B
  expected <- as.numeric(model.matrix(~0 + trait, dat) %*% coef(fit)) +
    rowSums(L[as.integer(dat$trait), , drop = FALSE] * mode[as.integer(dat$unit), , drop = FALSE])
  expect_equal(predict(fit, type = "link")$est, expected, tolerance = 1e-7)
})

test_that("ordinal missing response reconstruction uses AGHQ modes", {
  fit <- list(
    aghq = list(used = TRUE), n_sites = 2L, d_B = 1L,
    tmb_obj = list(env = list(data = list(aghq_mode = matrix(c(1, -1), 2L, 1L)))),
    tmb_data = list(site_id = c(0L, 1L), trait_id = c(0L, 0L),
      n_ordinal_cuts_per_trait = 0L, ordinal_offset_per_trait = 0L),
    data = data.frame(trait = factor(c("a", "a"))),
    report = list(eta = c(0, 0), Lambda_B = matrix(.8, 1L, 1L), ordinal_cutpoints = numeric())
  )
  out <- data.frame(model_row = 1:2, trait = c("a", "a"), est = c(0, 0))
  got <- .predict_missing_ordinal_response(fit, out, c(14L, 14L), "trait")
  expect_equal(got$est, 1 + pnorm(c(.8, -.8)))
})

test_that("AGHQ missing-response uncertainty fails closed", {
  fit <- structure(list(aghq = list(used = TRUE)), class = "gllvmTMB_multi")
  for (route in c("quad", "joint", "joint_load", "sim", "boot")) {
    expect_error(predict_missing(fit, se = TRUE, se_route = route),
                 class = "gllvmTMB_aghq_missing_se_unsupported")
  }
})

test_that("ordinal AGHQ predicts masked responses using conditional modes", {
  set.seed(412)
  n <- 100L; nt <- 6L
  unit <- factor(rep(seq_len(n), each = nt))
  trait <- factor(rep(letters[1:nt], n))
  z <- rnorm(n)
  latent_y <- rep(c(-.3, .1, .4, -.1, .2, .3), n) +
    rep(c(.8, .6, -.5, .7, -.6, .5), n) * rep(z, each = nt) + rnorm(n * nt)
  value <- 1L + (latent_y > 0) + (latent_y > 1)
  value[c(7, 42, 71)] <- NA
  dat <- data.frame(value, unit, trait)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    dat, trait = "trait", unit = "unit", family = ordinal_probit(),
    missing = miss_control(response = "include"),
    control = gllvmTMBcontrol(se = FALSE, aghq = 5L, aghq_multistart = TRUE,
      n_init = 2L, svd_start = FALSE, loading_ridge = .75)
  )))
  expect_true(isTRUE(fit$aghq$used))
  expect_true(isTRUE(fit$aghq$converged))
  response <- predict_missing(fit, type = "response")
  link <- predict_missing(fit, type = "link")
  expect_equal(nrow(response), 3L)
  tid <- fit$tmb_data$trait_id[response$model_row] + 1L
  expected <- vapply(seq_len(nrow(response)), function(i) {
    t <- tid[i]
    count <- fit$tmb_data$n_ordinal_cuts_per_trait[t]
    offset <- fit$tmb_data$ordinal_offset_per_trait[t]
    cuts <- if (count > 0) fit$report$ordinal_cutpoints[offset + seq_len(count)] else numeric()
    bounds <- c(-Inf, 0, cuts, Inf)
    sum(seq_len(length(bounds) - 1L) * diff(pnorm(bounds - link$est[i])))
  }, numeric(1))
  expect_equal(response$est, expected, tolerance = 1e-7)
  expect_error(predict_missing(fit, se = TRUE), class = "gllvmTMB_aghq_missing_se_unsupported")
})
