test_that("profile_temporal profiles the qualified replicated temporal-kernel time parameter", {
  skip_if_not_installed("TMB")
  d <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  set.seed(260913L)
  d$value <- as.numeric(factor(d$trait)) + .1 * d$occasion + stats::rnorm(nrow(d), sd = .08)
  K <- matrix(c(1, .35, .15, .35, 1, .25, .15, .25, 1), 3L, 3L,
    byrow = TRUE, dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      temporal_indep(0 + trait | series, time = occasion,
        replicate = measurement) +
      kernel_indep(series, K = K, name = "fixed_kernel"),
    data = d, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(
      se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
      optimizer_passes = 2L
    )
  ))
  skip_if(!is.finite(fit$opt$objective), "fixture did not converge to a finite objective")

  out <- profile_temporal(fit, ystep = .25, ytol = 1)
  idx <- match("theta_temporal_time", names(fit$opt$par))
  trace <- TMB::tmbprofile(fit$tmb_obj, name = idx, ystep = .25,
    ytol = 1, trace = FALSE)
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  at_mle <- which.min(abs(trace[[1L]] - fit$opt$par[[idx]]))

  expect_named(out, c("estimate", "lower", "upper"))
  expect_equal(out[["estimate"]], (1 - 1e-6) * tanh(par$theta_temporal_time),
    tolerance = 1e-10)
  expect_equal(trace[[2L]][[at_mle]], fit$opt$objective, tolerance = 1e-8)
  expect_gt(max(trace[[2L]]), fit$opt$objective + .1)
  dep_fit <- suppressWarnings(update(fit, formula = value ~ 0 + trait +
    temporal_dep(0 + trait | series, time = occasion, replicate = measurement)))
  expect_error(profile_temporal(dep_fit),
    "temporal_indep")
})
