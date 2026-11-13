## #1365: a user-pinned tweedie(p = ...) whose logit lies outside [-5, 5]
## warns once and the fit uses that endpoint. A pin inside the range is
## unchanged. Free p is the unclamped main parameterisation.

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

test_that("a free-p fit with an interior p matches the unclamped main fit", {
  testthat::skip_on_cran()
  msgs <- character()
  fit <- withCallingHandlers(
    .fit_1365(tweedie()),
    warning = function(w) {
      if (inherits(w, "gllvmTMB_tweedie_p_clamp")) {
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
  logit <- par[names(par) == "logit_p_tweedie"]
  expect_true(all(is.finite(logit)))
  expect_true(all(abs(logit) < 5))
  ## Main has no logit_p clamp: p = 1 + plogis(logit_p), and the objective
  ## is the template evaluated at that parameter. src/ matches main, so this
  ## fit is that calculation.
  p_main <- 1 + stats::plogis(logit)
  p <- as.numeric(obj$report(par)$p_tweedie)
  expect_equal(p, as.numeric(p_main), tolerance = 1e-10)
  expect_equal(as.numeric(fit$opt$objective), as.numeric(obj$fn(par)),
               tolerance = 1e-10)
})

test_that("a pinned p inside the clamp round-trips with no warning", {
  testthat::skip_on_cran()
  p_req <- 1.5
  fit <- expect_warning(
    .fit_1365(tweedie(p = p_req)),
    regexp = NA
  )
  p <- as.numeric(fit$tmb_obj$report()$p_tweedie)
  expect_equal(p, rep(p_req, length(p)), tolerance = 1e-8)
  expect_equal(tweedie(p = p_req)$p, p_req)
})

test_that("a pinned p outside the clamp warns and uses the bound", {
  testthat::skip_on_cran()
  check_pin <- function(p_req, logit_bound) {
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
    p_used <- 1 + stats::plogis(logit_bound)
    expect_match(msgs[[1L]], sprintf("%.6f", p_req), fixed = TRUE)
    expect_match(msgs[[1L]], sprintf("%.6f", p_used), fixed = TRUE)
    expect_match(msgs[[1L]], "The fit uses", fixed = TRUE)
    p <- as.numeric(fit$tmb_obj$report()$p_tweedie)
    expect_equal(p, rep(p_used, length(p)), tolerance = 1e-8)
    expect_true(all(p > 1 & p < 2))
    expect_false(isTRUE(all.equal(p[[1L]], p_req, tolerance = 1e-6)))
  }
  check_pin(1.001, -5)
  check_pin(1.999, 5)
})
