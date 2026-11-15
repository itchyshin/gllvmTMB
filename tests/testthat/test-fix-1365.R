## #1365: a user-pinned tweedie(p = ...) outside [p_lo, p_hi] warns once
## and the fit uses that end. p_lo = 1 + plogis(-12), p_hi = 1 + plogis(12).
## A pin inside the interval is stored with .gllvmTMB_tweedie_theta and
## comes back unchanged. 1.001 and 1.999 are inside the interval.

.fit_1365 <- function(family) {
  set.seed(1365)
  n <- 25L
  df <- data.frame(
    trait = factor(rep(c("t1", "t2"), each = n)),
    unit = factor(rep(seq_len(n), 2L)),
    x = stats::rnorm(2L * n),
    value = ifelse(stats::runif(2L * n) < 0.3, 0, stats::rexp(2L * n))
  )
  suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + x,
    data = df,
    unit = "unit",
    family = family,
    control = gllvmTMB::gllvmTMBcontrol(
      n_init = 1L,
      se = FALSE,
      optimizer = "nlminb",
      optArgs = list(control = list(iter.max = 5L, eval.max = 8L))
    )
  ))
}

test_that("a free-p fit reports the smooth map and the template objective", {
  testthat::skip_on_cran()
  msgs <- character()
  fit <- withCallingHandlers(
    .fit_1365(tweedie()),
    warning = function(w) {
      if (inherits(w, "gllvmTMB_tweedie_p_clamp") ||
          inherits(w, "gllvmTMB_tweedie_p_boundary")) {
        msgs <<- c(msgs, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    }
  )
  expect_length(msgs, 0L)
  obj <- fit$tmb_obj
  par <- fit$opt$par
  names(par) <- names(obj$par)
  expect_true("logit_p_tweedie" %in% names(par))
  theta <- par[names(par) == "logit_p_tweedie"]
  expect_true(all(is.finite(theta)))
  p <- as.numeric(obj$report(par)$p_tweedie)
  expect_equal(p, as.numeric(.gllvmTMB_tweedie_p(theta)), tolerance = 1e-10)
  b <- .gllvmTMB_tweedie_p_bounds()
  expect_true(all(p > b[["lo"]] + 1e-5 & p < b[["hi"]] - 1e-5))
  expect_equal(as.numeric(fit$opt$objective), as.numeric(obj$fn(par)),
               tolerance = 1e-10)
})

test_that("a pinned p inside the interval round-trips with no warning", {
  testthat::skip_on_cran()
  ## 1.001 and 1.999 used to sit outside the logit-5 clamp. They are
  ## inside [p_lo, p_hi]. 1.7 is not the midpoint: storing qlogis(p - 1)
  ## would report about 1.823.
  for (p_req in c(1.001, 1.5, 1.7, 1.999)) {
    fit <- expect_warning(
      .fit_1365(tweedie(p = p_req)),
      regexp = NA
    )
    p <- as.numeric(fit$tmb_obj$report()$p_tweedie)
    expect_equal(p, rep(p_req, length(p)), tolerance = 1e-8, info = p_req)
    expect_equal(tweedie(p = p_req)$p, p_req)
  }
})

test_that("a pinned p outside the interval warns and uses the bound", {
  testthat::skip_on_cran()
  b <- .gllvmTMB_tweedie_p_bounds()
  check_pin <- function(p_req, p_used) {
    msgs <- character()
    fit <- withCallingHandlers(
      .fit_1365(tweedie(p = p_req)),
      warning = function(w) {
        if (inherits(w, "gllvmTMB_tweedie_p_clamp")) {
          msgs <<- c(msgs, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      }
    )
    expect_length(msgs, 1L)
    expect_match(msgs[[1L]], sprintf("%.6f", p_req), fixed = TRUE)
    expect_match(msgs[[1L]], sprintf("%.6f", p_used), fixed = TRUE)
    expect_match(msgs[[1L]], "The fit uses", fixed = TRUE)
    p <- as.numeric(fit$tmb_obj$report()$p_tweedie)
    expect_equal(p, rep(p_used, length(p)), tolerance = 1e-8)
    expect_true(all(p > 1 & p < 2))
    expect_false(isTRUE(all.equal(p[[1L]], p_req, tolerance = 1e-6)))
  }
  expect_lt(1.000001, unname(b[["lo"]]))
  expect_gt(1.999999, unname(b[["hi"]]))
  check_pin(1.000001, unname(b[["lo"]]))
  check_pin(1.999999, unname(b[["hi"]]))
})
