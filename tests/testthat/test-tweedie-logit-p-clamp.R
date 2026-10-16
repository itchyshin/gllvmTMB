## Tweedie power logit is clamped inside the TMB template (#1365).
## p = 1 + invlogit(logit_p_tweedie). Past |logit_p| ~ 36.7 the sum rounds onto
## exactly 1 or 2 and dtweedie() returned NaN; from ~20 on, 2 - p had lost digits.
## The template now clamps logit_p to [-5, 5] (identity inside, flat outside).

.tw_rtweedie <- function(n, mu, phi, p) {
  lam <- mu^(2 - p) / (phi * (2 - p))
  N <- stats::rpois(n, lam)
  shp <- (2 - p) / (p - 1)
  sc <- phi * (p - 1) * mu^(p - 1)
  vapply(seq_len(n), function(i) {
    if (N[i] == 0) 0 else sum(stats::rgamma(N[i], shape = shp, scale = sc[i]))
  }, numeric(1))
}

.tw_fit <- function(p_true = 1.6, phi = 1.4, seed = 3L, n = 300L, control = NULL) {
  set.seed(seed)
  df <- data.frame(
    trait = factor(rep(c("t1", "t2"), each = n)),
    unit = factor(rep(seq_len(n), 2)),
    x = stats::rnorm(2 * n)
  )
  df$value <- .tw_rtweedie(2 * n, exp(0.3 + 0.2 * df$x), phi, p_true)
  args <- list(value ~ 0 + trait + x, data = df, unit = "unit", family = tweedie())
  if (!is.null(control)) args$control <- control
  suppressMessages(suppressWarnings(do.call(gllvmTMB::gllvmTMB, args)))
}

.tw_with_logit_p <- function(obj, value) {
  par <- obj$par
  par[names(par) == "logit_p_tweedie"] <- value
  par
}

.central_diff_grad <- function(obj, par, h = 1e-5) {
  vapply(seq_along(par), function(i) {
    up <- par; dn <- par
    up[i] <- up[i] + h
    dn[i] <- dn[i] - h
    (obj$fn(up) - obj$fn(dn)) / (2 * h)
  }, numeric(1))
}

test_that("objective and reported power stay finite and inside (1, 2) at extreme logit_p", {
  skip_on_cran()
  fit <- .tw_fit()
  obj <- fit$tmb_obj
  for (v in c(-40, -1000, 40, 1000)) {
    par <- .tw_with_logit_p(obj, v)
    expect_true(is.finite(obj$fn(par)), info = paste("logit_p =", v))
    p <- obj$report(par)$p_tweedie
    expect_true(all(is.finite(p)), info = paste("logit_p =", v))
    expect_true(all(p > 1 & p < 2), info = paste("logit_p =", v))
  }
})

test_that("the clamp is flat outside +/-5 and the identity inside", {
  skip_on_cran()
  fit <- .tw_fit()
  obj <- fit$tmb_obj
  f <- function(v) obj$fn(.tw_with_logit_p(obj, v))
  expect_equal(f(5), f(40), tolerance = 1e-12)
  expect_equal(f(-5), f(-40), tolerance = 1e-12)
  expect_false(isTRUE(all.equal(f(4), f(5), tolerance = 1e-12)))
  ## reported power and its complement stay accurate at the bound
  p <- obj$report(.tw_with_logit_p(obj, 40))$p_tweedie
  expect_equal(p - 1, rep(stats::plogis(5), length(p)), tolerance = 1e-12)
  expect_equal(2 - p, rep(stats::plogis(-5), length(p)), tolerance = 1e-12)
})

test_that("TMB AD gradient matches central differences, inside and on the clamp", {
  skip_on_cran()
  check <- function(obj, par, label) {
    g <- as.numeric(obj$gr(par))
    fd <- .central_diff_grad(obj, par)
    expect_true(all(is.finite(g)), info = label)
    rel <- abs(g - fd) / pmax(abs(g), 1)
    expect_lt(max(rel), 1e-6, label = label)
  }
  ## Gamma-like data (power near 2, no zeros) pull logit_p towards the bound,
  ## so the clamp is active at a well-conditioned objective.
  fit <- .tw_fit(p_true = 1.98, phi = 0.5)
  obj <- fit$tmb_obj
  check(obj, fit$opt$par, "interior (fitted)")
  check(obj, .tw_with_logit_p(obj, 3), "interior (logit_p = 3)")
  ## clamp ACTIVE: d/d logit_p is exactly 0, other components unchanged
  par_hi <- .tw_with_logit_p(obj, 40)
  check(obj, par_hi, "clamp active (logit_p = 40)")
  expect_true(all(as.numeric(obj$gr(par_hi))[names(par_hi) == "logit_p_tweedie"] == 0))
  par_lo <- .tw_with_logit_p(obj, -40)
  check(obj, par_lo, "clamp active (logit_p = -40)")
})

test_that("converged and pd_hessian still come from the optimiser and sdreport", {
  skip_on_cran()
  ## iteration-capped fit: the optimiser code and the derived flag both fail
  capped <- .tw_fit(control = gllvmTMB::gllvmTMBcontrol(
    optimizer = "nlminb",
    optArgs = list(control = list(iter.max = 1L, eval.max = 2L))
  ))
  expect_false(identical(as.integer(capped$opt$convergence), 0L))
  expect_false(isTRUE(capped$fit_health$converged))
  expect_false(isTRUE(capped$fit_health$optimizer_converged))
  expect_identical(capped$fit_health$convergence, capped$opt$convergence)
  chk <- gllvmTMB::check_gllvmTMB(capped)
  expect_identical(chk$status[chk$component == "optimizer_convergence"], "FAIL")
  ## the pd_hessian flag is the sdreport()'s own pdHess
  expect_identical(capped$fit_health$pd_hessian, isTRUE(capped$sd_report$pdHess))
})
