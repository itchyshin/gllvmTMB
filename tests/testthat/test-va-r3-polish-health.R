test_that("VA polishing does not discard an equivalent eligible point", {
  point <- function(objective, convergence = 0L) list(objective = objective, convergence = convergence, par = c(1, 2))
  old <- point(1201.086795275519, 1L)
  near <- point(1201.086795149948, 1L)
  expect_false(.va_r3_accept_polish(old, near, .0005588, .0058526))
  expect_true(.va_r3_accept_polish(old, point(old$objective - 2e-6, 1L), .0005588, .0058526))
  expect_true(.va_r3_accept_polish(old, near, .006, .0005))
  expect_true(.va_r3_accept_polish(old, near, .0005, .0006))
  expect_false(.va_r3_accept_polish(old, point(old$objective + 1e-4), .0005, .0006))
  expect_false(.va_r3_accept_polish(old, point(Inf), .0005, .0006))
  expect_false(.va_r3_accept_polish(point(0), point(-1e-6), .0005, .006))
  expect_true(.va_r3_accept_polish(point(0), point(-1.01e-6), .0005, .006))
  expect_false(.va_r3_accept_polish(old, near, .0005, NA_real_))
})

test_that("both VA polish solvers retain the qualified point and restore state", {
  run_case <- function(profile) {
    real_make <- .va_r3_make_objective
    observed <- new.env(parent = emptyenv())
    local_mocked_bindings(
      .va_r3_make_objective = function(...) {
        obj <- real_make(...)
        original_fn <- obj$fn
        start <- obj$par
        obj$fn <- function(p) { observed$last_eval <- p; original_fn(p) }
        obj$gr <- function(p) rep(if (max(abs(p - start)) > .05) .006 else .001, length(p))
        obj
      },
      .va_r3_nlminb = function(start, objective, gradient, control, opt_args = list()) {
        old_value <- objective(start)
        candidate <- start; candidate[1L] <- candidate[1L] + .1
        objective(candidate)
        list(par = candidate, objective = old_value - 1e-7, convergence = 1L,
             message = "test nlminb", evaluations = c(`function` = 2L, gradient = 1L), iterations = 1L)
      },
      .va_r3_run_primary = function(optimizer, obj, start, control, optimizer_args = list()) {
        old_value <- obj$fn(start)
        if (identical(optimizer, "lbfgsb")) {
          candidate <- start; candidate[1L] <- candidate[1L] + .1
          obj$fn(candidate)
          return(list(par = candidate, objective = old_value - 1e-7, convergence = 0L,
                      message = "test lbfgsb", optimizer = "L-BFGS-B",
                      evaluations = c(`function` = 2L, gradient = 1L), iterations = 1L))
        }
        list(par = start, objective = old_value, convergence = 0L,
             message = "test primary", optimizer = "nlminb",
             evaluations = c(`function` = 1L, gradient = 1L), iterations = 1L)
      }, .package = "gllvmTMB"
    )
    dat <- expand.grid(unit = seq_len(4L), trait = seq_len(2L))
    fit <- .va_r3_fit(y = c(1, 0, 0, 1, 1, 1, 0, 0), n_trials = rep.int(1L, 8L),
      X = model.matrix(~ 0 + factor(trait), dat), unit_id = dat$unit,
      trait_id = dat$trait, q = 1L, family = "binomial", link = "logit",
      H = 3L, n_starts = 1L, optimizer = "nlminb", profile_variational = profile)
    chosen <- fit$starts[[1L]]
    attempts <- Filter(function(x) identical(x$stage, "polish"), chosen$optimizer_attempts)
    expect_identical(vapply(attempts, `[[`, character(1), "method"), c("nlminb", "L-BFGS-B"))
    expect_true(all(vapply(attempts, function(x) identical(x$accepted, FALSE), logical(1))))
    expect_true(all(vapply(attempts, function(x) identical(x$max_abs_gradient, .006), logical(1))))
    expect_true(all(vapply(attempts, function(x) grepl("ineligible near-tie", x$rejection_reason), logical(1))))
    expect_true(chosen$agreement_eligible)
    expect_equal(unname(fit$objective$env$last.par), unname(chosen$par), tolerance = 1e-8)
    expect_equal(unname(observed$last_eval), unname(if (profile) chosen$outer_par else chosen$par), tolerance = 1e-8)
  }
  run_case(FALSE)
  run_case(TRUE)
})
