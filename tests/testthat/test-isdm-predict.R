## predict() on isdm_sources() fits (class c("gllvmTMB_multi", "gllvmTMB")):
## the defensible core established by dev/isdm-predict-probe/probe.R (Part A,
## non-spatial). Spatial newdata behaviour (the field is silently dropped)
## is a known bug tracked separately and is deliberately NOT certified here.

.isdm_predict_fixture <- function() {
  set.seed(7)
  n_cell <- 30L
  cells <- paste0("c", seq_len(n_cell))
  species <- c("sp1", "sp2")
  x <- as.numeric(scale(runif(n_cell)))
  alpha <- c(-0.1, 0.2); beta <- c(0.4, -0.3)
  ## a REAL shared latent field, so random-effect re-add paths are testable
  u_cell <- rnorm(n_cell, sd = 0.8)
  lam_tr <- c(0.9, 0.6)
  mk <- function(src, kind, support) {
    d <- expand.grid(cell_id = cells, trait = species, stringsAsFactors = FALSE)
    ci <- match(d$cell_id, cells); si <- match(d$trait, species)
    eta <- alpha[si] + x[ci] * beta[si] + u_cell[ci] * lam_tr[si]
    d$isdm_source <- src
    d$support <- support
    d$value <- if (kind == "count") rpois(nrow(d), support * exp(eta))
               else rbinom(nrow(d), 1, -expm1(-support * exp(eta)))
    d
  }
  dat <- rbind(mk("gbif", "count", 1.5), mk("survey", "pa", 0.9))
  dat$trait <- factor(dat$trait)
  dat$cell_id <- factor(dat$cell_id)
  dat$isdm_source <- factor(dat$isdm_source, levels = c("gbif", "survey"))
  dat$log_support <- log(dat$support)
  dat$env <- x[match(as.character(dat$cell_id), cells)]
  dat$src_gbif <- as.integer(dat$isdm_source == "gbif")
  dat
}

.isdm_predict_fit <- function() {
  dat <- .isdm_predict_fixture()
  fam <- isdm_sources(gbif = poisson(), survey = binomial(link = "cloglog"))
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:env + trait:src_gbif + offset(log_support) +
      latent(0 + trait | cell_id, d = 1),
    data = dat, trait = "trait", unit = "cell_id", family = fam, silent = TRUE
  ))
  list(fit = fit, dat = dat)
}

## Fit once, reuse across test_that blocks (fixture is small; still an
## expensive TMB fit worth not repeating six times).
.isdm_pred_fx <- if (requireNamespace("TMB", quietly = TRUE)) {
  .isdm_predict_fit()
} else {
  NULL
}

test_that("in-sample predict() matches report$eta exactly (link scale)", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  out <- predict(fit)
  expect_s3_class(out, "data.frame")
  expect_identical(nrow(out), nrow(dat))
  expect_true(all(c("est") %in% names(out)))
  expect_identical(out$est, as.numeric(fit$report$eta))
})

test_that("type = 'response' applies each row's own arm inverse link", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  link_out <- predict(fit)
  resp_out <- predict(fit, type = "response")

  i_count <- dat$isdm_source == "gbif"
  i_pa <- dat$isdm_source == "survey"

  expect_equal(resp_out$est[i_count], exp(link_out$est[i_count]))
  expect_equal(resp_out$est[i_pa], -expm1(-exp(link_out$est[i_pa])))
  expect_true(all(resp_out$est[i_pa] >= 0 & resp_out$est[i_pa] <= 1))
  expect_true(all(resp_out$est[i_count] > 0))
})

test_that("predict(newdata = training data) equals in-sample predictions on a non-spatial fit", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  in_sample <- predict(fit)
  newdata_pred <- suppressMessages(predict(fit, newdata = dat))
  expect_equal(newdata_pred$est, in_sample$est)
})

test_that("re_form = ~0 drops the latent field relative to re_form = ~.", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  with_re <- suppressMessages(predict(fit, newdata = dat, re_form = ~.))
  fixed_only <- suppressMessages(predict(fit, newdata = dat, re_form = ~0))
  expect_gt(sd(with_re$est - fixed_only$est), 0)
})

test_that("se.fit = TRUE works in-sample and is refused with newdata", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  out <- predict(fit, se.fit = TRUE)
  expect_true("se.fit" %in% names(out))
  expect_true(all(is.finite(out$se.fit)))
  expect_true(all(out$se.fit > 0))

  err <- tryCatch(
    predict(fit, newdata = dat, se.fit = TRUE),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_predict_se_newdata_unsupported")
})

test_that("newdata with an unseen unit level falls back to the fixed-only prediction", {
  skip_if_not_installed("TMB")
  fit <- .isdm_pred_fx$fit
  dat <- .isdm_pred_fx$dat

  nd_new <- dat[dat$cell_id == levels(dat$cell_id)[1], ]
  nd_new$cell_id <- factor("cNEW")
  nd_new$env <- 0.25

  unseen_pred <- suppressMessages(predict(fit, newdata = nd_new))
  fixed_only_pred <- suppressMessages(predict(fit, newdata = nd_new, re_form = ~0))
  expect_equal(unseen_pred$est, fixed_only_pred$est)
})
