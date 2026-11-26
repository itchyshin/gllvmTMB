## #1903: TMB `sdreport()` may report `pdHess = TRUE` while every entry of
## `cov.fixed` is non-finite. `vcov()` / Wald readers treat that as unusable
## curvature; `gllvmTMB_diagnose()` and `fit_health` must not PASS pd Hessian.

test_that(".gllvmTMB_pd_hessian rejects pdHess TRUE with unusable covariance", {
  good <- list(sd_report = list(pdHess = TRUE, cov.fixed = diag(c(0.1, 0.2))))
  bad <- list(sd_report = list(pdHess = TRUE, cov.fixed = matrix(NaN, 2, 2)))
  neg_pd <- list(sd_report = list(pdHess = FALSE, cov.fixed = diag(2)))

  expect_true(gllvmTMB:::.gllvmTMB_pd_hessian(good))
  expect_false(gllvmTMB:::.gllvmTMB_pd_hessian(bad))
  expect_false(gllvmTMB:::.gllvmTMB_pd_hessian(neg_pd))
  expect_identical(gllvmTMB:::.gllvmTMB_pd_hessian(list()), NA)
})

test_that("sanity_multi and fit_health fail pd Hessian when cov.fixed is all NaN (#1903)", {
  fit <- list(
    opt = list(
      convergence = 0L, objective = 100, par = c(b1 = 0, b2 = 0),
      iterations = 10L, message = ""
    ),
    sd_report = list(pdHess = TRUE, cov.fixed = matrix(NaN, 2, 2)),
    tmb_obj = list(
      par = c(b1 = 0, b2 = 0),
      gr = function(p) c(1e-6, 1e-6)
    ),
    aghq = list(ridge_tau = Inf, penalised = FALSE),
    restart_history = data.frame(),
    X_fix_names = c("b1", "b2"),
    class = "gllvmTMB_multi"
  )

  health <- gllvmTMB:::.gllvmTMB_build_fit_health(fit)
  expect_false(health$pd_hessian)

  out <- NULL
  txt <- utils::capture.output(out <- sanity_multi(fit))
  expect_false(out$pd_hessian)
  expect_identical(out$pd_hessian, health$pd_hessian)
  expect_match(txt, "Hessian positive-definite:\\s+WARN")

  chk <- check_gllvmTMB(fit)
  expect_equal(chk$status[chk$component == "pd_hessian"], "WARN")
})

test_that("seed-202 nbinom2 latent+unique repro agrees pd diagnostic with vcov refusal (#1903)", {
  skip_on_cran()
  skip_if_not_installed("MASS")
  set.seed(202L)
  n <- 30L
  z <- stats::rnorm(n)
  long <- do.call(rbind, lapply(1:2, function(j) {
    mu <- exp(1 + 0.6 * z * ifelse(j == 1L, 1, -1))
    data.frame(
      unit = factor(seq_len(n)),
      trait = factor(paste0("t", j)),
      value = MASS::rnegbin(n, mu = mu, theta = 2)
    )
  }))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit),
    data = long, unit = "unit", family = nbinom2(), silent = TRUE
  )))

  expect_false(any(is.finite(fit$sd_report$cov.fixed)))
  expect_true(isTRUE(fit$sd_report$pdHess))

  expect_false(fit$fit_health$pd_hessian)
  expect_error(vcov(fit), class = "gllvmTMB_confint_nonfinite_se")

  san <- NULL
  txt <- utils::capture.output(san <- sanity_multi(fit))
  expect_false(san$pd_hessian)
  expect_match(txt, "Hessian positive-definite:\\s+WARN")
})