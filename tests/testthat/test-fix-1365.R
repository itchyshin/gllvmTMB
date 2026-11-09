## #1365: p = 1 + invlogit(logit_p_tweedie) is clamped to logit_p in [-5, 5]
## so an extreme power stays strictly inside (1, 2). A user-pinned
## tweedie(p = ...) outside that range warns and the fit uses the bound.
## A pinned power inside the range is unchanged and does not warn.

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

.logit_p_par <- function(obj, value) {
  par <- obj$par
  idx <- names(par) == "logit_p_tweedie"
  expect_true(any(idx))
  par[idx] <- value
  par
}

test_that("extreme logit_p stays finite and strictly inside (1, 2)", {
  testthat::skip_on_cran()
  fit <- .fit_1365(tweedie())
  obj <- fit$tmb_obj
  for (v in c(-40, -1000, 40, 1000)) {
    par <- .logit_p_par(obj, v)
    expect_true(is.finite(obj$fn(par)), info = paste("logit_p =", v))
    p <- obj$report(par)$p_tweedie
    expect_true(all(is.finite(p)), info = paste("logit_p =", v))
    expect_true(all(p > 1 & p < 2), info = paste("logit_p =", v))
    bound <- 1 + stats::plogis(max(min(v, 5), -5))
    expect_equal(as.numeric(p), rep(bound, length(p)), tolerance = 1e-8,
                 info = paste("logit_p =", v))
  }
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
