## Design 86 optimizer diagnostic harness.  This is dev-only and deliberately
## self-contained: it uses a controlled objective, never a Gate-2 input.

.d86_optimizer_counts <- function(fit, optimizer) {
  if (identical(optimizer, "nlminb")) {
    evaluations <- fit$evaluations
    return(stats::setNames(
      c(unname(as.integer(evaluations[["function"]])),
        unname(as.integer(evaluations[["gradient"]]))),
      c("function", "gradient")
    ))
  }

  counts <- fit$counts
  stats::setNames(
    c(unname(as.integer(counts[["function"]])),
      unname(as.integer(counts[["gradient"]]))),
    c("function", "gradient")
  )
}

.d86_optimizer_trace_stage <- function(stage, optimizer, fit, objective, gradient) {
  parameter <- as.numeric(fit$par)
  names(parameter) <- names(fit$par)
  gradient_at_parameter <- gradient(parameter)

  list(
    stage = stage,
    optimizer = optimizer,
    parameter = parameter,
    objective = as.numeric(objective(parameter)),
    max_abs_gradient = max(abs(gradient_at_parameter)),
    convergence = as.integer(fit$convergence),
    message = if (is.null(fit$message)) NA_character_ else as.character(fit$message),
    counts = .d86_optimizer_counts(fit, optimizer)
  )
}

design86_controlled_quadratic_objective <- function() {
  center <- c(alpha = 1.5, beta = -0.75)
  hessian <- matrix(c(4, 1, 1, 3), nrow = 2L,
                    dimnames = list(names(center), names(center)))

  list(
    start = c(alpha = -2, beta = 2),
    objective = function(parameter) {
      delta <- parameter - center
      as.numeric(0.5 * crossprod(delta, hessian %*% delta))
    },
    gradient = function(parameter) {
      gradient <- as.numeric(hessian %*% (parameter - center))
      names(gradient) <- names(center)
      gradient
    },
    solution = center
  )
}

design86_optimizer_diagnostic_trace <- function(
  objective,
  gradient,
  start,
  nlminb_control = list(eval.max = 200L, iter.max = 200L),
  bfgs_control = list(maxit = 200L, reltol = 1e-12)
) {
  run_nlminb <- function(parameter) {
    do.call(stats::nlminb, c(
      list(start = parameter, objective = objective, gradient = gradient),
      list(control = nlminb_control)
    ))
  }

  first <- run_nlminb(start)
  second <- run_nlminb(first$par)
  third <- run_nlminb(second$par)
  fourth <- stats::optim(third$par, objective, gradient, method = "BFGS",
                         control = bfgs_control)

  list(
    stages = list(
      .d86_optimizer_trace_stage("nlminb_1", "nlminb", first, objective, gradient),
      .d86_optimizer_trace_stage("nlminb_2", "nlminb", second, objective, gradient),
      .d86_optimizer_trace_stage("nlminb_3", "nlminb", third, objective, gradient),
      .d86_optimizer_trace_stage("bfgs", "BFGS", fourth, objective, gradient)
    )
  )
}
