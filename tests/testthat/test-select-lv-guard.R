## Lane auto-d-20260926: fast, mock-based tests for select_lv()'s guard
## against a non-nesting or runaway fit and its warm-start retry (ported
## from GLLVM.jl's `test/test_model_selection.jl`, testsets "warm-start
## safeguard" and "runaway detector"; see R/select-lv.R for the oracle
## reference and the one divergence the file-restriction on this lane forced).
##
## All fits here are fakes returned by a stub `.fitter` (select_lv()'s own
## test hook, mirroring the oracle's `_fitter` keyword) so these tests run in
## milliseconds with no real TMB optimisation, and `getLoadings()` is
## replaced with `local_mocked_bindings()` so the runaway checks are exact.

## ---- Fake fit constructor --------------------------------------------------

## A minimal fake fit: `select_lv()`'s guard only ever reads $opt$convergence,
## $sd_report$pdHess, and stats::logLik(fit) (dispatched here on the
## "gllvmTMB_select_lv_test_fake" class) -- and, through getLoadings(), the
## loading matrix, which these tests stub separately so the fake fit itself
## need not carry one.
.guard_fake_fit <- function(loglik, npar = 5L, nobs = 100L, converged = TRUE, pdhess = TRUE) {
  structure(
    list(
      opt = list(convergence = if (converged) 0L else 1L),
      sd_report = list(pdHess = pdhess),
      .loglik = loglik, .npar = npar, .nobs = nobs
    ),
    class = "gllvmTMB_select_lv_test_fake"
  )
}

logLik.gllvmTMB_select_lv_test_fake <- function(object, ...) {
  structure(object$.loglik, df = object$.npar, nobs = object$.nobs, class = "logLik")
}
## registerS3method(), not just defining the function above, so
## stats::logLik()'s dispatch finds it regardless of where in the search
## path this test file happens to be sourced from.
registerS3method("logLik", "gllvmTMB_select_lv_test_fake", logLik.gllvmTMB_select_lv_test_fake)

## Test formula/data: content is irrelevant since `.fitter` is stubbed, but a
## real formula with exactly one ordinary latent() term must be supplied so
## the argument-validation checks ahead of the sweep pass.
.guard_formula <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
.guard_data <- data.frame(unit = 1, trait = 1, value = 1)

## ---- Warm-start safeguard --------------------------------------------------

test_that("a healthy sweep triggers no retries and every d is accepted", {
  calls <- integer(0)
  fitter <- function(formula, data, ...) {
    k <- length(calls) + 1L
    calls <<- c(calls, k)
    .guard_fake_fit(loglik = -500 + 60 * k)
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1),
    .package = "gllvmTMB"
  )
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 4L, .fitter = fitter)
  expect_equal(calls, 1:4)
  expect_equal(sel$table$d, 1:4)
  expect_true(all(sel$table$status == "ok"))
})

test_that("a non-monotone d is retried from the accepted (d - 1) fit's control(start_from=) and accepted", {
  starts_from <- list()
  ## d = 1: -440; d = 2: -390; default d = 3: -395 (below d = 2, rejected);
  ## warm-started d = 3: -388 (accepted).
  d_of <- function(formula) {
    ## Recover the swept d from the (mocked, but real) formula rewrite.
    txt <- paste(deparse(formula), collapse = " ")
    as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
  }
  fitter <- function(formula, data, ..., control = NULL) {
    d <- d_of(formula)
    warm <- !is.null(control) && !is.null(control$start_from)
    if (warm) starts_from[[length(starts_from) + 1L]] <<- d
    ll <- if (d == 1L) -440 else if (d == 2L) -390 else if (warm) -388 else -395
    .guard_fake_fit(loglik = ll)
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1),
    .package = "gllvmTMB"
  )
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 3L, .fitter = fitter)
  expect_equal(unlist(starts_from), 3L)
  a3 <- sel$table[sel$table$d == 3L, ]
  expect_equal(a3$status, "warm_start")
  expect_equal(a3$logLik, -388)
  expect_true(3L %in% sel$table$d[sel$table$status %in% c("ok", "warm_start")])
})

test_that("a non-monotone d without warm-start support is excluded, not chosen", {
  d_of <- function(formula) {
    txt <- paste(deparse(formula), collapse = " ")
    as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
  }
  fitter <- function(formula, data, ..., control = NULL) {
    d <- d_of(formula)
    ll <- c(`1` = -440, `2` = -390, `3` = -395)[[as.character(d)]]
    .guard_fake_fit(loglik = ll)
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1),
    .package = "gllvmTMB"
  )
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 3L,
                    criterion = "aic", warm_start = FALSE, .fitter = fitter)
  a3 <- sel$table[sel$table$d == 3L, ]
  expect_equal(a3$status, "nonmonotone")
  expect_false(3L %in% sel$table$d[sel$table$status %in% c("ok", "warm_start")])
  expect_equal(sel$selected_d, 2L)
})

test_that("a throwing fit is recorded as failed with its reason, and excluded", {
  fitter <- function(formula, data, ...) {
    txt <- paste(deparse(formula), collapse = " ")
    d <- as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
    if (d == 2L) stop("singular covariance in the fit")
    .guard_fake_fit(loglik = -500 + 60 * d)
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1),
    .package = "gllvmTMB"
  )
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 3L, .fitter = fitter)
  a2 <- sel$table[sel$table$d == 2L, ]
  expect_equal(a2$status, "failed")
  expect_match(a2$error, "singular")
  expect_false(2L %in% sel$table$d[sel$table$status %in% c("ok", "warm_start")])
})

test_that("an unconverged fit is excluded", {
  fitter <- function(formula, data, ...) {
    txt <- paste(deparse(formula), collapse = " ")
    d <- as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
    .guard_fake_fit(loglik = -500 + 60 * d, converged = (d != 2L))
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1),
    .package = "gllvmTMB"
  )
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 3L, .fitter = fitter)
  a2 <- sel$table[sel$table$d == 2L, ]
  expect_equal(a2$status, "unconverged")
  expect_false(2L %in% sel$table$d[sel$table$status %in% c("ok", "warm_start")])
})

test_that("warm_start = FALSE disables the retry but keeps the guard", {
  retried <- FALSE
  fitter <- function(formula, data, ..., control = NULL) {
    txt <- paste(deparse(formula), collapse = " ")
    d <- as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
    if (!is.null(control) && !is.null(control$start_from)) retried <<- TRUE
    ll <- c(`1` = -440, `2` = -390, `3` = -395)[[as.character(d)]]
    .guard_fake_fit(loglik = ll)
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1),
    .package = "gllvmTMB"
  )
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 3L,
                    warm_start = FALSE, .fitter = fitter)
  expect_false(retried)
  a3 <- sel$table[sel$table$d == 3L, ]
  expect_equal(a3$status, "nonmonotone")
})

test_that("a non-error condition (standing in for an interrupt) is not swallowed", {
  ## select_lv()'s guard must use tryCatch(error =), never a condition
  ## catch-all, so a real interrupt is never absorbed into a "failed" row
  ## (the oracle's `InterruptException is not swallowed` test). A literal
  ## "interrupt"-classed condition -- or expect_error() itself -- would trip
  ## testthat's own interrupt handling and abort the whole test run instead
  ## of being reported as a pass/fail, so this catches the propagated
  ## condition directly with tryCatch(), matched by its own custom class,
  ## rather than going through expect_error().
  fitter <- function(formula, data, ...) stop(structure(
    class = c("select_lv_test_signal", "condition"),
    list(message = "not an ordinary error", call = NULL)
  ))
  caught <- tryCatch(
    select_lv(.guard_formula, data = .guard_data, d_max = 2L, .fitter = fitter),
    select_lv_test_signal = function(cnd) cnd
  )
  expect_s3_class(caught, "select_lv_test_signal")
})

## ---- Runaway detector -------------------------------------------------------

test_that("Mode B: a common-inflation d is retried, and excluded (without warm start) if still runaway", {
  d_of <- function(formula) {
    txt <- paste(deparse(formula), collapse = " ")
    as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
  }
  ## d = 3's default fit is common-inflation runaway; every other d is healthy.
  testthat::local_mocked_bindings(
    getLoadings = function(fit, ...) {
      if (isTRUE(fit$.runaway)) matrix(20, 6, 3) else matrix(0.5, 6, fit$.npar_lv %||% 1)
    },
    .package = "gllvmTMB"
  )
  fitter <- function(formula, data, ..., family = stats::poisson(), control = NULL) {
    d <- d_of(formula)
    ll <- c(`1` = -500, `2` = -400, `3` = -300)[[as.character(d)]]
    fit <- .guard_fake_fit(loglik = ll)
    fit$.runaway <- identical(d, 3L)
    fit$.npar_lv <- d
    fit
  }
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 3L, criterion = "aic",
                    warm_start = FALSE, family = stats::poisson(), .fitter = fitter)
  a3 <- sel$table[sel$table$d == 3L, ]
  expect_equal(a3$status, "runaway")
  expect_match(a3$message, "latent SD")
  expect_equal(sel$selected_d, 2L)
})

test_that("Mode B: the warm-start refit replaces a runaway fit when it is healthy", {
  d_of <- function(formula) {
    txt <- paste(deparse(formula), collapse = " ")
    as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
  }
  testthat::local_mocked_bindings(
    getLoadings = function(fit, ...) {
      if (isTRUE(fit$.runaway)) matrix(20, 6, fit$.npar_lv) else matrix(0.5, 6, fit$.npar_lv)
    },
    .package = "gllvmTMB"
  )
  fitter <- function(formula, data, ..., family = stats::poisson(), control = NULL) {
    d <- d_of(formula)
    warm <- !is.null(control) && !is.null(control$start_from)
    ll <- if (d == 1L) -500 else if (d == 2L) -400 else if (warm) -380 else -300
    fit <- .guard_fake_fit(loglik = ll)
    fit$.runaway <- identical(d, 3L) && !warm
    fit$.npar_lv <- d
    fit
  }
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 3L,
                    family = stats::poisson(), .fitter = fitter)
  a3 <- sel$table[sel$table$d == 3L, ]
  expect_equal(a3$status, "warm_start")
  expect_equal(a3$logLik, -380)
})

test_that("Mode A: one binary trait separating is caught by the ratio check (binomial only)", {
  d_of <- function(formula) {
    txt <- paste(deparse(formula), collapse = " ")
    as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
  }
  testthat::local_mocked_bindings(
    getLoadings = function(fit, ...) {
      Lam <- matrix(0.5, 6, fit$.npar_lv)
      if (fit$.npar_lv >= 1L) Lam[4L, 1L] <- fit$.sep
      Lam
    },
    .package = "gllvmTMB"
  )
  fitter <- function(formula, data, ..., family = stats::binomial(), control = NULL) {
    d <- d_of(formula)
    fit <- .guard_fake_fit(loglik = -500 + 60 * d)
    fit$.npar_lv <- d
    fit$.sep <- if (d == 2L) 15 else if (d == 3L) 48 else 0.5   ## ratio 30 at d=2 (>= 25)
    fit
  }
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 3L, warm_start = FALSE,
                    max_latent_sd = Inf, family = stats::binomial(), .fitter = fitter)
  a2 <- sel$table[sel$table$d == 2L, ]
  expect_equal(a2$status, "runaway")
  expect_match(a2$message, "ratio")
  expect_equal(sel$table$d[sel$table$status %in% c("ok", "warm_start")], 1L)
})

test_that("the ratio check is binomial-only, and the scale check can be disabled with max_latent_sd = Inf", {
  d_of <- function(formula) {
    txt <- paste(deparse(formula), collapse = " ")
    as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
  }
  ## One trait at loading 9 with the rest at 0.5: ratio 18 (< 25) and row norm
  ## < 10, so a Poisson fit accepts both d = 1 and d = 2 without any check
  ## triggering.
  testthat::local_mocked_bindings(
    getLoadings = function(fit, ...) {
      Lam <- matrix(0.5, 6, fit$.npar_lv)
      Lam[4L, 1L] <- 9
      Lam
    },
    .package = "gllvmTMB"
  )
  fitter <- function(formula, data, ..., family = stats::poisson(), control = NULL) {
    d <- d_of(formula)
    fit <- .guard_fake_fit(loglik = -500 + 60 * d)
    fit$.npar_lv <- d
    fit
  }
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 2L,
                    family = stats::poisson(), .fitter = fitter)
  expect_equal(sel$table$d[sel$table$status %in% c("ok", "warm_start")], 1:2)

  ## d = 3's common-inflation runaway (row norm 20 * sqrt(3) > 10) is not
  ## caught when max_latent_sd = Inf disables the scale check, and Poisson
  ## skips the binomial-only ratio check.
  testthat::local_mocked_bindings(
    getLoadings = function(fit, ...) matrix(20, 6, fit$.npar_lv),
    .package = "gllvmTMB"
  )
  fitter2 <- function(formula, data, ..., family = stats::poisson(), control = NULL) {
    d <- d_of(formula)
    fit <- .guard_fake_fit(loglik = c(`1` = -500, `2` = -400, `3` = -300)[[as.character(d)]])
    fit$.npar_lv <- d
    fit
  }
  sel2 <- select_lv(.guard_formula, data = .guard_data, d_max = 3L, max_latent_sd = Inf,
                     warm_start = FALSE, family = stats::poisson(), .fitter = fitter2)
  expect_true(3L %in% sel2$table$d[sel2$table$status %in% c("ok", "warm_start")])
})

test_that("identity-link (Gaussian) fits skip the runaway check entirely", {
  d_of <- function(formula) {
    txt <- paste(deparse(formula), collapse = " ")
    as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
  }
  testthat::local_mocked_bindings(
    getLoadings = function(fit, ...) matrix(999, 6, fit$.npar_lv),
    .package = "gllvmTMB"
  )
  fitter <- function(formula, data, ..., family = stats::gaussian(), control = NULL) {
    d <- d_of(formula)
    fit <- .guard_fake_fit(loglik = -500 + 60 * d)
    fit$.npar_lv <- d
    fit
  }
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 2L,
                    family = stats::gaussian(), .fitter = fitter)
  expect_equal(sel$table$d[sel$table$status %in% c("ok", "warm_start")], 1:2)
})

## ---- Panel fixes (review, 2026-09-26) --------------------------------------
## Ported from GLLVM.jl's "select_lv — review fixes" testset (commit
## bf8940ad2 in GLLVM.jl-auto-d-20260926), restricted to what applies on this
## side of the file split (see R/select-lv.R banner): the monotonicity bar
## and the Gaussian/mixed-family runaway-skip robustness. The warm-start
## column-padding fix and the mask-reaches-bic fix are Julia-internal
## (`_lv_warm_start()`'s explicit `Λ_init` construction, and a `bic()`
## `mask` keyword) with no R analogue -- gllvmTMB's `start_from` route and
## `getLoadings()` accessor already sidestep both.

test_that("bar = best converged fit at any smaller d, not just the last accepted one (drift)", {
  ## d1 = -500 (accepted, bar = -500). d2 = -500.008 (within tol = 0.01 of
  ## -500, accepted; bar STAYS -500, the true best-so-far, not -500.008).
  ## d3 = -500.016 is within tol of d2's -500.008 but more than tol below the
  ## true bar (-500), so it must be rejected. A guard that (bugged) compares
  ## only against the last ACCEPTED d would instead compare d3 to -500.008
  ## and wrongly accept it (drift compounding across small allowed steps).
  d_of <- function(formula) {
    txt <- paste(deparse(formula), collapse = " ")
    as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
  }
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(0.5, 6, 1),
    .package = "gllvmTMB"
  )
  fitter <- function(formula, data, ...) {
    d <- d_of(formula)
    ll <- c(`1` = -500, `2` = -500.008, `3` = -500.016)[[as.character(d)]]
    .guard_fake_fit(loglik = ll)
  }
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 3L,
                    tol = 0.01, warm_start = FALSE, .fitter = fitter)
  a3 <- sel$table[sel$table$d == 3L, ]
  expect_equal(a3$status, "nonmonotone")
  expect_false(3L %in% sel$table$d[sel$table$status %in% c("ok", "warm_start")])
})

test_that("a runaway fit's inflated logLik never raises the bar for later d", {
  ## d1 = -500 (ok, bar = -500). d2 = -300 is RUNAWAY (inflated loadings), so
  ## its higher logLik must never become the bar. d3 = -420 must be compared
  ## to d1's -500, not d2's -300, and accepted.
  d_of <- function(formula) {
    txt <- paste(deparse(formula), collapse = " ")
    as.integer(sub(".*d = ([0-9]+).*", "\\1", txt))
  }
  testthat::local_mocked_bindings(
    getLoadings = function(fit, ...) if (isTRUE(fit$.runaway)) matrix(20, 6, 1) else matrix(0.5, 6, 1),
    .package = "gllvmTMB"
  )
  fitter <- function(formula, data, ..., family = stats::poisson(), control = NULL) {
    d <- d_of(formula)
    ll <- c(`1` = -500, `2` = -300, `3` = -420)[[as.character(d)]]
    fit <- .guard_fake_fit(loglik = ll)
    fit$.runaway <- identical(d, 2L)
    fit
  }
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 3L, warm_start = FALSE,
                    family = stats::poisson(), .fitter = fitter)
  a2 <- sel$table[sel$table$d == 2L, ]
  a3 <- sel$table[sel$table$d == 3L, ]
  expect_equal(a2$status, "runaway")
  expect_equal(a3$status, "ok")
})

test_that("the Gaussian runaway-skip works for a family object with no $link element", {
  fam_no_link <- structure(list(family = "gaussian"), class = "family")
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(999, 6, 1),
    .package = "gllvmTMB"
  )
  fitter <- function(formula, data, ...) .guard_fake_fit(loglik = -500)
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 1L,
                    family = fam_no_link, .fitter = fitter)
  expect_equal(sel$table$status, "ok")
})

test_that("the Gaussian runaway-skip applies to an all-Gaussian mixed-family list", {
  testthat::local_mocked_bindings(
    getLoadings = function(...) matrix(999, 6, 1),
    .package = "gllvmTMB"
  )
  fitter <- function(formula, data, ...) .guard_fake_fit(loglik = -500)
  sel <- select_lv(.guard_formula, data = .guard_data, d_max = 1L,
                    family = list(stats::gaussian(), stats::gaussian()), .fitter = fitter)
  expect_equal(sel$table$status, "ok")
})
