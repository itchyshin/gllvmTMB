## Design 86 Arc-5 Gate-A controlled probe.
##
## This is a deterministic, NON_GATE2 diagnostic only. It never reads a
## Gate-2 fixture or artifact, calls a Design-86 runner, generates a response,
## or writes an artifact root. It uses the existing tiny Gate-1 EVA objective
## solely to distinguish derivative, telemetry, and raw-loading-scale behavior.

.d86_arc5_fd_gradient <- function(objective, parameter, step) {
  value <- numeric(length(parameter))
  for (index in seq_along(parameter)) {
    delta <- rep.int(0, length(parameter)); delta[index] <- step
    value[index] <- (objective(parameter + delta) - objective(parameter - delta)) / (2 * step)
  }
  names(value) <- names(parameter)
  value
}

.d86_arc5_gradient_receipt <- function(objective, gradient, parameter,
                                        steps = c(1e-4, 1e-5, 1e-6)) {
  ad <- gradient(parameter)
  rows <- lapply(steps, function(step) {
    fd <- .d86_arc5_fd_gradient(objective, parameter, step)
    discrepancy <- abs(ad - fd) / (1 + pmax(abs(ad), abs(fd)))
    list(
      step = step,
      finite = all(is.finite(fd)),
      max_normalized_discrepancy = max(discrepancy),
      median_normalized_discrepancy = stats::median(discrepancy),
      normalized_discrepancy = discrepancy
    )
  })
  names(rows) <- format(steps, scientific = TRUE, trim = TRUE)
  stable <- vapply(seq_len(length(rows) - 1L), function(index) {
    rows[[index]]$finite && rows[[index + 1L]]$finite &&
      rows[[index]]$max_normalized_discrepancy <= 1e-4 &&
      rows[[index + 1L]]$max_normalized_discrepancy <= 1e-4
  }, logical(1))
  list(ad_gradient = ad, by_step = rows, pass = any(stable))
}

.d86_arc5_original_trace <- function(trace, map_to_original, original_objective,
                                     original_gradient) {
  trace$stages <- lapply(trace$stages, function(stage) {
    parameter <- map_to_original(stage$parameter)
    gradient <- original_gradient(parameter)
    stage$parameter <- parameter
    stage$objective <- original_objective(parameter)
    stage$max_abs_gradient <- max(abs(gradient))
    stage
  })
  trace
}

design86_arc5_controlled_probe <- function(rebuild = FALSE) {
  required <- c(".eva_make_objective", "design86_optimizer_diagnostic_trace",
                "design86_controlled_quadratic_objective",
                "design86_controlled_nonstationary_objective")
  missing <- required[!vapply(required, exists, logical(1), inherits = TRUE)]
  if (length(missing)) {
    stop("Source R/eva-proto.R and dev/design86-optimizer-diagnostic-harness.R first: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  objective <- .eva_make_objective("bernoulli_q2", rebuild = rebuild, silent = TRUE)
  parameter <- objective$par
  block_map <- objective$env$parList(parameter)
  if (!identical(as.numeric(unlist(block_map, use.names = FALSE)), as.numeric(parameter))) {
    stop("Controlled TMB parList round-trip changed the flattened parameter order.", call. = FALSE)
  }

  interior <- parameter + 0.01 * sin(seq_along(parameter))
  interior[names(interior) == "log_A_diag"] <- pmin(0.5,
    pmax(-0.5, interior[names(interior) == "log_A_diag"])
  )
  offset <- parameter + 0.02 * cos(seq_along(parameter))
  offset[names(offset) == "log_A_diag"] <- pmin(0.5,
    pmax(-0.5, offset[names(offset) == "log_A_diag"])
  )
  value <- function(x) .eva_evaluate(objective, x, gradient = FALSE)
  gradient <- function(x) .eva_evaluate(objective, x, gradient = TRUE)$gradient

  gradient_checks <- list(
    interior = .d86_arc5_gradient_receipt(value, gradient, interior),
    offset = .d86_arc5_gradient_receipt(value, gradient, offset)
  )

  convergent <- design86_controlled_quadratic_objective()
  nonstationary <- design86_controlled_nonstationary_objective()
  telemetry <- list(
    convergent = design86_optimizer_diagnostic_trace(
      convergent$objective, convergent$gradient, convergent$start
    ),
    nonstationary = design86_optimizer_diagnostic_trace(
      nonstationary$objective, nonstationary$gradient, nonstationary$start
    )
  )

  loading <- names(parameter) == "theta_rr"
  raw_start <- parameter
  raw_start[loading] <- 5
  raw_trace <- design86_optimizer_diagnostic_trace(value, gradient, raw_start)
  scale <- 10
  map_to_original <- function(z) {
    ans <- z
    ans[loading] <- scale * ans[loading]
    ans
  }
  scaled_value <- function(z) value(map_to_original(z))
  scaled_gradient <- function(z) {
    ans <- gradient(map_to_original(z))
    ans[loading] <- scale * ans[loading]
    ans
  }
  scaled_start <- raw_start
  scaled_start[loading] <- scaled_start[loading] / scale
  scaled_trace <- design86_optimizer_diagnostic_trace(scaled_value, scaled_gradient, scaled_start)
  scaled_trace <- .d86_arc5_original_trace(scaled_trace, map_to_original, value, gradient)

  health <- function(stage) {
    isTRUE(stage$convergence == 0L) && is.finite(stage$objective) &&
      is.finite(stage$max_abs_gradient) && stage$max_abs_gradient < 1e-4
  }
  raw_final <- raw_trace$stages[[length(raw_trace$stages)]]
  scaled_final <- scaled_trace$stages[[length(scaled_trace$stages)]]
  scaling <- list(
    scale = scale,
    raw_trace = raw_trace,
    scaled_trace = scaled_trace,
    raw_healthy = health(raw_final),
    scaled_healthy = health(scaled_final),
    same_target = isTRUE(all.equal(raw_final$objective, scaled_final$objective,
      tolerance = 1e-8, check.attributes = FALSE
    ))
  )

  list(
    label = "NON_GATE2_CONTROLLED_EVA_DIAGNOSTIC",
    fixture = "gate1_bernoulli_q2",
    parameter_blocks = vapply(block_map, length, integer(1)),
    parlist_roundtrip = TRUE,
    gradient_checks = gradient_checks,
    telemetry = telemetry,
    scaling = scaling
  )
}
