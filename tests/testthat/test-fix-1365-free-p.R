## Free Tweedie power (#1365). The stored parameter is mapped by
## .gllvmTMB_tweedie_p onto (1 + plogis(-12), 1 + plogis(12)). A hard
## clamp is not used: its gradient is 0 outside the clamp.
##
## The interior comparison is the Laplace fit of this fixed data on main
## 02c0aa0b (TMB 1.9.25, nlminb, n_init = 1, se = FALSE,
## laplace_auto_refit = FALSE): p = 1.4876488337312583,
## objective = 62.914063034551049. The objective must agree to 1e-6
## relative. p must agree to 1e-5 absolute: the smooth map changes the
## gradient scale, the likelihood is flat in p, and nlminb stops a few
## millionths away in p while the objective still matches.

.fix1365_ctrl <- function(iter.max = 200L) {
  gllvmTMBcontrol(
    n_init = 1L,
    se = FALSE,
    optimizer = "nlminb",
    laplace_auto_refit = FALSE,
    optArgs = list(control = list(iter.max = iter.max))
  )
}

.fix1365_interior_data <- function() {
  data.frame(
    value = c(
      1.25764078, 0.4124267, 0.08418569, 6.14411667, 0,
      2.32374744, 0.43801456, 3.69060302, 4.81341478, 0, 1.42339382,
      0, 1.24945619, 0, 0.43912622, 0.58774753, 2.35682305, 0.29165363,
      0, 1.21627965, 0, 0.11400703, 2.47629067, 2.17316077, 0.88771959,
      1.32156147, 0.03452773, 0, 0.55398241, 0.55069577, 1.70669689,
      1.94894245, 0, 1.72084928, 0, 2.14278049, 0.63062657, 0.3035061,
      0, 0
    ),
    x = c(
      0.665689, -1.018127, 1.380437, 0.19484, -1.515182, 0.027647,
      -0.547706, 0.83416, 0.294088, -1.689337, 0.531014, -1.00939,
      -0.316312, 0.795044, -1.477515, -1.321977, -0.383678, 0.015795,
      0.428368, -1.023818, 0.386832, -0.15445, -0.410172, 0.663496,
      -1.395191, 1.44113, -1.774211, -2.678567, 0.881935, 0.291835,
      1.65336, -0.618502, -1.272366, 0.276707, 1.585333, -0.682674,
      -0.404057, 0.425107, 1.582639, -0.627303
    ),
    unit = factor(seq_len(40L)),
    trait = factor("t1")
  )
}

.fix1365_capture <- function(expr) {
  caught <- list()
  fit <- withCallingHandlers(
    force(expr),
    warning = function(w) {
      if (inherits(w, "gllvmTMB_tweedie_p_boundary")) {
        caught[[length(caught) + 1L]] <<- w
        invokeRestart("muffleWarning")
      }
    }
  )
  list(fit = fit, warnings = caught)
}

.fix1365_rel <- function(got, ref) abs(got - ref) / max(abs(ref), 1)

test_that("a free interior Tweedie power matches main to 1e-6 relative", {
  skip_on_cran()
  out <- .fix1365_capture(suppressMessages(gllvmTMB(
    value ~ x,
    data = .fix1365_interior_data(),
    unit = "unit",
    family = tweedie(),
    control = .fix1365_ctrl()
  )))
  fit <- out$fit
  expect_length(out$warnings, 0L)
  p <- as.numeric(fit$report$p_tweedie)[[1L]]
  theta <- as.numeric(fit$tmb_obj$env$parList(fit$opt$par)$logit_p_tweedie)[[1L]]
  expect_lt(abs(p - 1.4876488337312583), 1e-5)
  expect_lt(.fix1365_rel(fit$opt$objective, 62.914063034551049), 1e-6)
  expect_equal(p, .gllvmTMB_tweedie_p(theta), tolerance = 1e-10)
  expect_equal(fit$opt$convergence, 0L)
})

test_that("a pinned power inside the smooth interval maps exactly", {
  skip_on_cran()
  pins <- c(1.00001, 1.1, 1.5, 1.6, 1.7, 1.9, 1.99, 1.999, 1.9999, 1.99999)
  for (p0 in pins) {
    expect_equal(.gllvmTMB_tweedie_p(.gllvmTMB_tweedie_theta(p0)), p0,
                 tolerance = 1e-12, info = p0)
  }
  df <- .fix1365_interior_data()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ x, data = df, unit = "unit", family = tweedie(p = 1.7),
    control = .fix1365_ctrl(iter.max = 5L)
  )))
  expect_equal(as.numeric(fit$report$p_tweedie)[[1L]], 1.7, tolerance = 1e-12)
  theta <- as.numeric(fit$tmb_obj$env$parList()$logit_p_tweedie)[[1L]]
  expect_equal(theta, .gllvmTMB_tweedie_theta(1.7), tolerance = 1e-12)
})

test_that("extreme starts and boundary data stay finite and warn", {
  skip_on_cran()
  df <- .fix1365_interior_data()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ x, data = df, unit = "unit", family = tweedie(),
    control = .fix1365_ctrl()
  )))
  obj <- fit$tmb_obj
  par0 <- obj$par
  idx <- which(names(par0) == "logit_p_tweedie")
  expect_length(idx, 1L)
  for (theta in c(-1000, -100, -40, 40, 100, 1000)) {
    par <- par0
    par[[idx]] <- theta
    fn <- obj$fn(par)
    gr <- obj$gr(par)
    expect_true(is.finite(fn), info = theta)
    expect_true(is.finite(gr[[idx]]), info = theta)
    expect_gt(abs(gr[[idx]]), 0, label = paste("gradient at", theta))
    expect_equal(as.numeric(obj$report(par)$p_tweedie)[[1L]],
                 .gllvmTMB_tweedie_p(theta), tolerance = 1e-8)
  }
  ## Past the overflow of theta^2. The unscaled quotient collapses to 0
  ## and would report the middle of the interval. The gradient underflows
  ## to 0 here, so this check is the reported power only.
  b_huge <- .gllvmTMB_tweedie_p_bounds()
  for (theta in c(-1e200, 1e200)) {
    par <- par0
    par[[idx]] <- theta
    p_hat <- as.numeric(obj$report(par)$p_tweedie)[[1L]]
    expect_equal(p_hat, .gllvmTMB_tweedie_p(theta), tolerance = 1e-8)
    expect_equal(
      p_hat,
      unname(if (theta > 0) b_huge[["hi"]] else b_huge[["lo"]]),
      tolerance = 1e-8
    )
  }

  ## Many zeros: the unrestricted power runs into 1.
  pois <- data.frame(
    value = c(0, 0, 1, 0, 0, 2, 0, 1, 0, 0, 0, 1, 0, 0, 3, 0, 0, 1, 0, 0,
              0, 0, 1, 0, 0, 0, 2, 0, 0, 1),
    x = seq(-1, 1, length.out = 30),
    unit = factor(seq_len(30L)),
    trait = factor("t1")
  )
  low <- .fix1365_capture(suppressMessages(gllvmTMB(
    value ~ x, data = pois, unit = "unit", family = tweedie(),
    control = .fix1365_ctrl()
  )))
  expect_length(low$warnings, 1L)
  expect_s3_class(low$warnings[[1L]], "gllvmTMB_tweedie_p_boundary")
  p_lo <- as.numeric(low$fit$report$p_tweedie)[[1L]]
  b <- .gllvmTMB_tweedie_p_bounds()
  expect_true(is.finite(low$fit$opt$objective))
  expect_true(is.finite(p_lo))
  expect_lte(p_lo, b[["lo"]] + 1e-5)
  msg <- conditionMessage(low$warnings[[1L]])
  expect_match(msg, sprintf("%.12f", p_lo), fixed = TRUE)
  expect_match(msg, sprintf("%.12f", b[["lo"]]), fixed = TRUE)
  expect_match(msg, "lower bound", fixed = TRUE)
  g_lo <- low$fit$tmb_obj$gr(low$fit$opt$par)
  ix <- which(names(low$fit$opt$par) == "logit_p_tweedie")
  expect_true(is.finite(g_lo[[ix]]))
  expect_gt(abs(g_lo[[ix]]), 0)

  ## Positive gamma-like responses (shape 4, scale 0.5, rounded).
  ## The unrestricted power runs into 2.
  gam <- data.frame(
    value = c(
      1.89938287, 1.57890967, 1.61322729, 3.38941179, 2.17519848,
      1.62277712, 1.09113785, 1.28421938, 2.10768618, 1.13824381, 1.74178965,
      1.77473317, 3.23193079, 1.33523867, 0.38538956, 2.71404423, 2.47609891,
      0.46875824, 1.0307911, 0.58967418, 1.74444305, 0.97245109, 1.18357937,
      1.44364904, 1.2555561, 2.53710178, 0.77669289, 0.80730545, 1.27427128,
      2.78684852, 1.3653897, 1.12114665, 2.64152057, 1.017846, 6.84594488,
      1.08930567, 3.17449698, 0.8272244, 1.53505458, 1.7224379
    ),
    x = c(
      -0.580269, 0.009978, -1.032621, -0.300622, 0.944016, 0.100053,
      -1.21631, 1.069924, 0.137436, 0.554933, 0.788695, 0.49601, -1.306435,
      0.663584, 0.87744, -1.284435, 0.860806, -0.676567, 0.104956,
      -0.339897, 0.10907, 0.511482, -0.611526, 0.865334, 0.826131,
      0.655857, 1.579724, -0.889728, -0.565705, 0.614331, 0.857722,
      -0.430236, -0.05874, 0.798669, -0.215728, -2.625369, 0.608669,
      -0.317592, -0.644177, -1.086195
    ),
    unit = factor(seq_len(40L)),
    trait = factor("t1")
  )
  high <- .fix1365_capture(suppressMessages(gllvmTMB(
    value ~ x, data = gam, unit = "unit", family = tweedie(),
    control = .fix1365_ctrl()
  )))
  expect_length(high$warnings, 1L)
  expect_s3_class(high$warnings[[1L]], "gllvmTMB_tweedie_p_boundary")
  p_hi <- as.numeric(high$fit$report$p_tweedie)[[1L]]
  expect_true(is.finite(high$fit$opt$objective))
  expect_gte(p_hi, b[["hi"]] - 1e-5)
  msg_hi <- conditionMessage(high$warnings[[1L]])
  expect_match(msg_hi, sprintf("%.12f", p_hi), fixed = TRUE)
  expect_match(msg_hi, sprintf("%.12f", b[["hi"]]), fixed = TRUE)
  expect_match(msg_hi, "upper bound", fixed = TRUE)
  g_hi <- high$fit$tmb_obj$gr(high$fit$opt$par)
  ixh <- which(names(high$fit$opt$par) == "logit_p_tweedie")
  expect_true(is.finite(g_hi[[ixh]]))
  expect_gt(abs(g_hi[[ixh]]), 0)
})

test_that("Laplace, MSPL and VA report the same Tweedie power", {
  skip_on_cran()
  df <- data.frame(
    value = c(0.2, 1.1, 0, 0.4, 2.0, 0.8, 0, 1.5),
    x = c(-0.4, 0.2, 0.7, -1.1, 0.3, 1.2, -0.6, 0.1),
    unit = factor(seq_len(8L)),
    trait = factor("t1")
  )
  theta <- 20
  lap <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ x + latent(1 | unit, d = 1, unique = FALSE),
    data = df, unit = "unit", family = tweedie(),
    control = .fix1365_ctrl(iter.max = 2L)
  )))
  ## report() wants the full parameter vector. opt$par / $par drops the
  ## random effects, so last.par is the vector that matches the tape.
  par <- lap$tmb_obj$env$last.par
  par[names(par) == "logit_p_tweedie"] <- theta
  p_lap <- as.numeric(lap$tmb_obj$report(par)$p_tweedie)[[1L]]
  expect_equal(p_lap, .gllvmTMB_tweedie_p(theta), tolerance = 1e-8)
  expect_gt(abs(p_lap - (1 + stats::plogis(theta))), 1e-4)

  old <- Sys.getenv("GLLVMTMB_MSPL_TWEEDIE_PROBE", unset = NA_character_)
  Sys.setenv(GLLVMTMB_MSPL_TWEEDIE_PROBE = "1")
  on.exit({
    if (is.na(old)) Sys.unsetenv("GLLVMTMB_MSPL_TWEEDIE_PROBE")
    else Sys.setenv(GLLVMTMB_MSPL_TWEEDIE_PROBE = old)
  }, add = TRUE)
  mspl <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ x + latent(1 | unit, d = 1, unique = FALSE),
    data = df, unit = "unit", family = tweedie(),
    estimator = "mspl",
    control = .fix1365_ctrl(iter.max = 1L)
  )))
  par_m <- mspl$tmb_obj$env$last.par
  par_m[names(par_m) == "logit_p_tweedie"] <- theta
  p_mspl <- as.numeric(mspl$tmb_obj$report(par_m)$p_tweedie)[[1L]]
  expect_equal(p_mspl, p_lap, tolerance = 1e-10)

  validated <- .va_r3_validate_data(
    y = 1.2, n_trials = 1L, X = matrix(1, 1L, 1L),
    unit_id = 1L, trait_id = 1L, q = 1L, N = 1L, T = 1L,
    family_codes = 6L, link_ids = 0L,
    n_ordinal_cuts_per_trait = 0L, ordinal_offset_per_trait = 0L,
    ordinal_log_increments_start = numeric(0)
  )
  parameters <- .va_r3_default_parameters(validated)
  parameters$logit_p_tweedie[] <- theta
  parameters$log_phi_tweedie[] <- log(0.8)
  va <- .va_r3_make_objective(
    validated, H = 3L, parameters = parameters, eval_method = "gh",
    silent = TRUE
  )
  p_va <- as.numeric(va$report(va$par)$p_tweedie)[[1L]]
  expect_equal(p_va, p_lap, tolerance = 1e-8)
  expect_equal(p_va, .gllvmTMB_tweedie_p(theta), tolerance = 1e-8)

  va_fixed <- .va_r3_make_objective(
    validated, H = 3L, parameters = parameters, eval_method = "gh",
    silent = TRUE, fixed_tweedie_power = 1.7
  )
  va_fixed$fn(va_fixed$par)
  expect_equal(as.numeric(va_fixed$report()$p_tweedie)[[1L]], 1.7,
               tolerance = 1e-12)
  b <- .gllvmTMB_tweedie_p_bounds()
  clamp_msgs <- character()
  va_clamp <- withCallingHandlers(
    .va_r3_make_objective(
      validated, H = 3L, parameters = parameters, eval_method = "gh",
      silent = TRUE, fixed_tweedie_power = 1.000001
    ),
    warning = function(w) {
      if (inherits(w, "gllvmTMB_tweedie_p_clamp")) {
        clamp_msgs <<- c(clamp_msgs, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    }
  )
  expect_length(clamp_msgs, 1L)
  expect_match(clamp_msgs[[1L]], "1.000001", fixed = TRUE)
  expect_match(clamp_msgs[[1L]], sprintf("%.6f", b[["lo"]]), fixed = TRUE)
  va_clamp$fn(va_clamp$par)
  expect_equal(as.numeric(va_clamp$report()$p_tweedie)[[1L]], unname(b[["lo"]]),
               tolerance = 1e-8)
})

test_that("the density at the smooth bounds matches tweedie::dtweedie", {
  ## skip_if_not_installed() is used only in this test, and only for the
  ## tweedie package. The other tests in this file do not need it.
  skip_if_not_installed("tweedie")
  skip_on_cran()
  b <- .gllvmTMB_tweedie_p_bounds()
  ## 1e-8 inside each open end. The inverse does not clip, so these
  ## values round-trip. A power outside [p_lo, p_hi] is not passed here.
  ## y = 0 at the upper end underflows in tweedie::dtweedie, so that
  ## zero is checked at the lower end only. The full grid is in
  ## docs/design/03-likelihoods.md.
  ends <- c(lower = unname(b[["lo"]] + 1e-8), upper = unname(b[["hi"]] - 1e-8))
  plan <- list(
    lower = expand.grid(y = c(0, 1, 5), mu = c(0.5, 2), phi = c(0.5, 1),
                        KEEP.OUT.ATTRS = FALSE),
    upper = expand.grid(y = c(1, 5), mu = c(0.5, 2), phi = c(0.5, 1),
                        KEEP.OUT.ATTRS = FALSE)
  )
  for (nm in names(ends)) {
    end <- ends[[nm]]
    cells <- plan[[nm]]
    for (y in unique(cells$y)) {
      df <- data.frame(value = y, unit = factor(1), trait = factor("t1"))
      fit <- suppressMessages(suppressWarnings(gllvmTMB(
        value ~ 1, data = df, unit = "unit", family = tweedie(p = end),
        control = .fix1365_ctrl(iter.max = 1L)
      )))
      reported <- as.numeric(fit$report$p_tweedie)[[1L]]
      expect_equal(reported, end, tolerance = 1e-12)
      rows <- cells[cells$y == y, , drop = FALSE]
      for (i in seq_len(nrow(rows))) {
        mu <- rows$mu[[i]]
        phi <- rows$phi[[i]]
        par <- fit$tmb_obj$par
        par[names(par) == "b_fix"] <- log(mu)
        par[names(par) == "log_phi_tweedie"] <- log(phi)
        nll <- fit$tmb_obj$fn(par)
        d_r <- tweedie::dtweedie(y, mu = mu, phi = phi, power = reported)
        expect_true(is.finite(d_r) && d_r > 0, info = paste(nm, y, mu, phi))
        expect_lt(
          .fix1365_rel(nll, -log(d_r)), 1e-6,
          label = paste("density", nm, y, mu, phi)
        )
      }
    }
  }
})

test_that("the power map does not flip at huge theta or clip a pin", {
  b <- .gllvmTMB_tweedie_p_bounds()
  expect_equal(.gllvmTMB_tweedie_p(1e200), unname(b[["hi"]]), tolerance = 1e-12)
  expect_equal(.gllvmTMB_tweedie_p(-1e200), unname(b[["lo"]]), tolerance = 1e-12)
  expect_equal(.gllvmTMB_tweedie_p(0), 1.5, tolerance = 1e-15)
  expect_equal(.gllvmTMB_tweedie_p(.gllvmTMB_tweedie_theta(1.7)), 1.7,
               tolerance = 1e-12)
  ## Outside [p_lo, p_hi] the inverse is not a silent clip onto the end.
  expect_false(is.finite(.gllvmTMB_tweedie_theta(1.000001)))
  expect_false(is.finite(.gllvmTMB_tweedie_theta(1.999999)))
})

test_that("a free VA power at the bound warns once and a pin does not", {
  b <- .gllvmTMB_tweedie_p_bounds()
  build <- function(p, pin) {
    .va_route_build_fit(
      list(
        report = list(p_tweedie = p),
        fixed_family_parameters = list(tweedie_power = pin)
      ),
      call = NULL, q = 1L, p = 1L, n = 4L,
      eval_method = "gh", family = "tweedie", link = "log"
    )
  }
  msgs <- character()
  withCallingHandlers(
    build(unname(b[["lo"]]) + 1e-8, NA_real_),
    warning = function(w) {
      if (inherits(w, "gllvmTMB_tweedie_p_boundary")) {
        msgs <<- c(msgs, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    }
  )
  expect_length(msgs, 1L)
  expect_s3_class(
    withCallingHandlers(
      build(unname(b[["hi"]]) - 1e-8, NA_real_),
      warning = function(w) {
        if (inherits(w, "gllvmTMB_tweedie_p_boundary")) {
          msgs <<- c(msgs, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      }
    ),
    "gllvmTMB_va"
  )
  expect_match(msgs[[1L]], sprintf("%.12f", b[["lo"]]), fixed = TRUE)
  expect_match(msgs[[2L]], sprintf("%.12f", b[["hi"]]), fixed = TRUE)
  expect_warning(build(unname(b[["lo"]]), unname(b[["lo"]])), regexp = NA)
  expect_warning(build(1.5, NA_real_), regexp = NA)
})

test_that("a fitted dispersion below 0.1 is named on the boundary warning", {
  b <- .gllvmTMB_tweedie_p_bounds()
  low <- list(
    report = list(p_tweedie = unname(b[["lo"]]), phi_tweedie = 0.02),
    fixed_family_parameters = list(tweedie_power = NA_real_)
  )
  expect_warning(
    .va_route_build_fit(
      low, call = NULL, q = 1L, p = 1L, n = 4L,
      eval_method = "gh", family = "tweedie", link = "log"
    ),
    regexp = "TMB's Tweedie density accuracy degrades",
    class = "gllvmTMB_tweedie_p_boundary"
  )
  high <- character()
  withCallingHandlers(
    .gllvmTMB_warn_tweedie_p_boundary(list(
      report = list(p_tweedie = unname(b[["hi"]]), phi_tweedie = 0.5),
      tmb_map = list(logit_p_tweedie = factor(1L))
    )),
    warning = function(w) {
      if (inherits(w, "gllvmTMB_tweedie_p_boundary")) {
        high <<- c(high, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    }
  )
  expect_length(high, 1L)
  expect_false(grepl("density accuracy degrades", high[[1L]], fixed = TRUE))
})
