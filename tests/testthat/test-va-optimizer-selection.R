test_that("VA optimizer intent survives control construction", {
  omitted <- gllvmTMBcontrol(integration = "va")
  explicit_nlminb <- gllvmTMBcontrol(integration = "va", optimizer = "nlminb")
  explicit_bfgs <- gllvmTMBcontrol(
    integration = "va", optimizer = "optim",
    optArgs = list(method = "BFGS")
  )

  expect_false(omitted$optimizer_explicit)
  expect_true(explicit_nlminb$optimizer_explicit)
  expect_true(explicit_bfgs$optimizer_explicit)
  expect_true(omitted$va_polish)
  expect_error(gllvmTMBcontrol(integration = "va", va_polish = 1),
               "va_polish")
})

test_that("VA resolves optimizer intent to a native primary method", {
  default <- .va_route_optimizer_spec(gllvmTMBcontrol(integration = "va"))
  nlminb <- .va_route_optimizer_spec(gllvmTMBcontrol(
    integration = "va", optimizer = "nlminb",
    optArgs = list(control = list(iter.max = 17L))
  ))
  bfgs <- .va_route_optimizer_spec(gllvmTMBcontrol(
    integration = "va", optimizer = "optim",
    optArgs = list(method = "BFGS", control = list(maxit = 19L))
  ))
  lbfgsb <- .va_route_optimizer_spec(gllvmTMBcontrol(
    integration = "va", optimizer = "optim",
    optArgs = list(method = "L-BFGS-B", control = list(maxit = 23L))
  ))

  expect_identical(default$requested, "auto")
  expect_identical(default$va_polish, TRUE)
  expect_identical(nlminb$primary, "nlminb")
  expect_identical(nlminb$control$iter.max, 17L)
  expect_identical(bfgs$primary, "bfgs")
  expect_identical(bfgs$control$maxit, 19L)
  expect_identical(lbfgsb$primary, "lbfgsb")
  expect_identical(lbfgsb$control$maxit, 23L)
})

test_that("the VA router forwards optimizer controls into the approximation engine", {
  n <- 100L
  p <- 2L
  unit_id <- rep(seq_len(n) - 1L, each = p)
  trait_id <- rep.int(seq_len(p) - 1L, times = n)
  captured <- NULL
  local_mocked_bindings(
    .approximation_engine_fit = function(engine, ...) {
      captured <<- list(engine = engine, ...)
      list(status = "healthy", diagnostics = list(), provenance = list(),
           score = list(), fixed = list(), fitted = list(), engine_result = list())
    },
    .package = "gllvmTMB"
  )
  ctl <- gllvmTMBcontrol(
    integration = "va", optimizer = "optim",
    optArgs = list(method = "BFGS", control = list(maxit = 19L)),
    va_polish = FALSE
  )
  cs <- list(kind = "rr", group = quote(site),
             extra = list(d = 1L, lhs_form = quote(0 + trait)))
  fit <- .gllvmTMB_va_route(
    parsed = list(covstructs = list(cs)), y = rep(c(0, 1), n),
    n_trials = rep.int(1L, n * p), X = matrix(1, n * p, 1L,
      dimnames = list(NULL, "(Intercept)")),
    unit_id = unit_id, trait_id = trait_id, n_units = n, n_traits = p,
    unit_col = "site", family_per_row = rep(list(stats::binomial()), n * p),
    family_id_vec = rep.int(1L, n * p), link_id_vec = rep.int(0L, n * p),
    is_y_observed = rep.int(TRUE, n * p), weights_i = NULL,
    mi_enabled = FALSE, offset_expr = NULL,
    optimizer = ctl$optimizer, optimizer_explicit = ctl$optimizer_explicit,
    optArgs = ctl$optArgs, va_polish = ctl$va_polish
  )

  expect_s3_class(fit, "gllvmTMB_va")
  expect_identical(captured$engine, "va_r3")
  expect_identical(captured$optimizer, "bfgs")
  expect_identical(captured$optimizer_request, "BFGS")
  expect_identical(captured$control$maxit, 19L)
  expect_false(captured$va_polish)
})

test_that("VA refuses invalid native controls before building an objective", {
  expect_error(gllvmTMBcontrol(
    integration = "va", optimizer = "nlminb",
    optArgs = list(method = "BFGS")
  ), "nlminb")
  expect_error(gllvmTMBcontrol(
    integration = "va", optimizer = "optim",
    optArgs = list(method = "CG")
  ), "supports only")
  expect_error(gllvmTMBcontrol(
    integration = "va", optimizer = "optim",
    optArgs = list(method = "BFGS", control = list(iter.max = 100L))
  ), "Unsupported native control")
  expect_error(gllvmTMBcontrol(
    integration = "va", optimizer = "optim",
    optArgs = list(mystery = TRUE)
  ), "does not accept these")
  invalid_controls <- list(
    list(fnscale = -1), list(parscale = 0), list(ndeps = 0),
    list(maxit = 1.5), list(trace = 0.5)
  )
  for (native_control in invalid_controls) {
    expect_error(gllvmTMBcontrol(
      integration = "va", optimizer = "optim",
      optArgs = list(method = "BFGS", control = native_control)
    ), "positive finite|non-negative integer")
  }
})

test_that("VA primary runner calls the selected native solver directly", {
  calls <- list()
  local_mocked_bindings(
    .va_r3_nlminb = function(start, objective, gradient, control,
                             opt_args = list()) {
      calls[[length(calls) + 1L]] <<- list(method = "nlminb", control = control)
      list(par = start, objective = objective(start), convergence = 0L,
           message = NULL, evaluations = c(`function` = 1L, gradient = 1L),
           iterations = 1L)
    },
    .va_r3_optim = function(start, objective, gradient, method, control,
                            opt_args = list()) {
      calls[[length(calls) + 1L]] <<- list(method = method, control = control)
      list(par = start, value = objective(start), convergence = 0L,
           message = NULL, counts = c(`function` = 1L, gradient = 1L))
    },
    .package = "gllvmTMB"
  )
  obj <- list(par = c(a = 1), fn = function(x) sum(x^2),
              gr = function(x) 2 * x)

  .va_r3_run_primary("nlminb", obj, obj$par, list(iter.max = 7L))
  .va_r3_run_primary("bfgs", obj, obj$par, list(maxit = 9L))
  .va_r3_run_primary("lbfgsb", obj, obj$par, list(maxit = 11L))

  expect_identical(vapply(calls, `[[`, character(1), "method"),
                   c("nlminb", "BFGS", "L-BFGS-B"))
  expect_identical(calls[[1]]$control$iter.max, 7L)
  expect_identical(calls[[2]]$control$maxit, 9L)
  expect_identical(calls[[3]]$control$maxit, 11L)
})

test_that("the selected method runs for all four primary starts", {
  n <- 4L
  p <- 2L
  dat <- expand.grid(unit = seq_len(n), trait = seq_len(p))
  X <- model.matrix(~ 0 + factor(trait), dat)
  y <- c(1, 0, 0, 1, 1, 1, 0, 0)
  calls <- list()
  real_optim <- .va_r3_optim
  stats_spy <- new.env(parent = emptyenv())
  stats_spy$methods <- character()
  assign(".va_test_stats_optim_spy", stats_spy, envir = .GlobalEnv)
  trace("optim", where = asNamespace("stats"),
        tracer = quote(.va_test_stats_optim_spy$methods <-
          c(.va_test_stats_optim_spy$methods, method)), print = FALSE)
  on.exit({
    untrace("optim", where = asNamespace("stats"))
    if (exists(".va_test_stats_optim_spy", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".va_test_stats_optim_spy", envir = .GlobalEnv)
    }
  }, add = TRUE)
  local_mocked_bindings(
    .va_r3_optim = function(start, objective, gradient, method, control,
                            opt_args = list()) {
      calls[[length(calls) + 1L]] <<- list(method = method, start = start)
      real_optim(start, objective, gradient, method, control, opt_args)
    },
    .package = "gllvmTMB"
  )

  set.seed(1595L)
  fit <- .va_r3_fit(
    y = y, n_trials = rep.int(1L, length(y)), X = X,
    unit_id = dat$unit, trait_id = dat$trait, q = 1L,
    family = "binomial", link = "logit", H = 3L,
    optimizer = "bfgs", optimizer_request = "BFGS",
    control = list(maxit = 3L), va_polish = FALSE
  )

  expect_length(calls, 4L)
  expect_identical(vapply(calls, `[[`, character(1), "method"), rep("BFGS", 4L))
  expect_identical(stats_spy$methods, rep("BFGS", 4L))
  expect_identical(vapply(fit$starts, `[[`, character(1), "primary_optimizer"),
                   rep("BFGS", 4L))
  expect_true(all(vapply(fit$starts, function(x) {
    length(x$optimizer_attempts) == 1L &&
      identical(x$optimizer_attempts[[1]]$stage, "primary") &&
      identical(x$polish_optimizer, "disabled")
  }, logical(1))))
  expect_identical(fit$requested_optimizer, "BFGS")
  expect_identical(fit$optimizer_method, "BFGS")

  bfgs_starts <- lapply(calls, `[[`, "start")
  calls <- list()
  stats_spy$methods <- character()
  set.seed(1595L)
  lbfgsb_fit <- .va_r3_fit(
    y = y, n_trials = rep.int(1L, length(y)), X = X,
    unit_id = dat$unit, trait_id = dat$trait, q = 1L,
    family = "binomial", link = "logit", H = 3L,
    optimizer = "lbfgsb", optimizer_request = "L-BFGS-B",
    control = list(maxit = 3L), va_polish = FALSE
  )
  expect_identical(vapply(calls, `[[`, character(1), "method"),
                   rep("L-BFGS-B", 4L))
  expect_identical(stats_spy$methods, rep("L-BFGS-B", 4L))
  expect_identical(lapply(calls, `[[`, "start"), bfgs_starts)
  expect_identical(lbfgsb_fit$optimizer_method, "L-BFGS-B")
})

test_that("VA polish retains bounds and primary-method metadata", {
  dat <- expand.grid(unit = seq_len(4L), trait = seq_len(2L))
  X <- model.matrix(~ 0 + factor(trait), dat)
  y <- c(1, 0, 0, 1, 1, 1, 0, 0)
  real_nlminb <- .va_r3_nlminb
  real_primary <- .va_r3_run_primary
  nl_calls <- list()
  primary_calls <- list()
  local_mocked_bindings(
    .VA_R3_POLISH_GRADIENT_TARGET = -1,
    .va_r3_nlminb = function(start, objective, gradient, control,
                             opt_args = list()) {
      nl_calls[[length(nl_calls) + 1L]] <<- list(
        control = control, opt_args = opt_args
      )
      real_nlminb(start, objective, gradient, control, opt_args)
    },
    .va_r3_run_primary = function(optimizer, obj, start, control,
                                  optimizer_args = list()) {
      primary_calls[[length(primary_calls) + 1L]] <<- list(
        optimizer = optimizer, control = control,
        optimizer_args = optimizer_args
      )
      real_primary(optimizer, obj, start, control, optimizer_args)
    },
    .package = "gllvmTMB"
  )

  set.seed(1595L)
  bounded <- .va_r3_fit(
    y = y, n_trials = rep.int(1L, length(y)), X = X,
    unit_id = dat$unit, trait_id = dat$trait, q = 1L,
    family = "binomial", link = "logit", H = 3L,
    optimizer = "lbfgsb", optimizer_request = "L-BFGS-B",
    optimizer_args = list(lower = -100, upper = 100),
    control = list(maxit = 2L), va_polish = TRUE
  )

  expect_length(nl_calls, 8L)
  expect_true(all(vapply(nl_calls, function(x) {
    identical(x$opt_args$lower, -100) && identical(x$opt_args$upper, 100) &&
      !"maxit" %in% names(x$control)
  }, logical(1))))
  polish_lbfgsb_calls <- Filter(function(x) identical(x$optimizer, "lbfgsb"),
                                primary_calls)
  polish_lbfgsb_calls <- Filter(function(x) identical(x$control$maxit, 500L),
                                polish_lbfgsb_calls)
  expect_length(polish_lbfgsb_calls, 4L)
  expect_true(all(vapply(polish_lbfgsb_calls, function(x) {
    identical(x$optimizer_args$lower, -100) &&
      identical(x$optimizer_args$upper, 100)
  }, logical(1))))
  expect_true(all(vapply(bounded$starts, function(x) {
    all(x$par >= -100 & x$par <= 100)
  }, logical(1))))

  ## With BFGS as the primary method, the usual L-BFGS-B polish may become the
  ## final solver. The public record must still report BFGS as the primary.
  nl_calls <- list()
  primary_calls <- list()
  set.seed(1595L)
  polished_bfgs <- .va_r3_fit(
    y = y, n_trials = rep.int(1L, length(y)), X = X,
    unit_id = dat$unit, trait_id = dat$trait, q = 1L,
    family = "binomial", link = "logit", H = 3L,
    optimizer = "bfgs", optimizer_request = "BFGS",
    control = list(maxit = 2L), va_polish = TRUE
  )
  expect_true(all(vapply(polished_bfgs$starts, function(x) {
    identical(x$primary_optimizer, "BFGS") &&
      any(vapply(x$optimizer_attempts, function(a) {
        identical(a$stage, "polish") && identical(a$method, "L-BFGS-B")
      }, logical(1)))
  }, logical(1))))
})

test_that("VA polish can be disabled without changing the default", {
  expect_true(gllvmTMBcontrol(integration = "va")$va_polish)
  expect_false(gllvmTMBcontrol(integration = "va", va_polish = FALSE)$va_polish)
  expect_error(
    gllvmTMB(y ~ 1, data = data.frame(y = c(0, 1)),
             control = gllvmTMBcontrol(va_polish = FALSE)),
    "applies only to the VA integration route"
  )
})
