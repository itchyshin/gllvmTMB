## Paper 1 Gate C1 — no-fit B2 gradient-topology receipt helpers.
## These functions inspect an already-retained ledger only. They never load,
## construct, optimise, profile, or simulate a model.

paper1_c1_required_ledger <- c(
  "schema", "attempt_id", "status", "terminal", "objective", "optimizer_code",
  "gradient", "gradient_by_block", "pd_hessian", "boundary_flags", "source_map",
  "field_outputs", "versions"
)

paper1_c1_classify_topology <- function(gradient, parameter_names, pd_hessian,
                                        boundary_flags, raw_gradient_gate = 1e-3,
                                        health_gradient_gate = 1e-2) {
  if (!is.numeric(gradient) || !length(gradient) || any(!is.finite(gradient)) ||
      !is.character(parameter_names) || length(parameter_names) != length(gradient) ||
      !identical(pd_hessian, TRUE) || !is.character(boundary_flags) ||
      !is.finite(raw_gradient_gate) || !is.finite(health_gradient_gate) ||
      raw_gradient_gate <= 0 || health_gradient_gate <= raw_gradient_gate) {
    return(list(case = "D", reason = "invalid_prerequisites",
                max_indices = integer(), max_blocks = character()))
  }
  maximum <- max(abs(gradient))
  indices <- which(abs(gradient) == maximum)
  blocks <- parameter_names[indices]
  if (maximum <= raw_gradient_gate) {
    return(list(case = "A", reason = "raw_gradient_pass",
                max_indices = indices, max_blocks = blocks))
  }
  if (maximum < health_gradient_gate && !length(boundary_flags) &&
      length(indices) == 1L && blocks[[1L]] %in% c("b_fix", "theta_rr_B")) {
    return(list(case = "C", reason = paste0("nonboundary_", blocks[[1L]]),
                max_indices = indices, max_blocks = blocks))
  }
  list(case = "D", reason = "unsupported_raw_gradient_state",
       max_indices = indices, max_blocks = blocks)
}

paper1_c1_receipt <- function(ledger) {
  if (!is.list(ledger) || !all(paper1_c1_required_ledger %in% names(ledger))) {
    stop("C1 requires the complete retained B2 ledger.", call. = FALSE)
  }
  gradient <- as.numeric(ledger$gradient)
  names <- names(ledger$gradient_by_block$outer)
  if (!is.numeric(ledger$gradient_by_block$outer) || length(names) != length(gradient) ||
      !isTRUE(all.equal(unname(ledger$gradient_by_block$outer), gradient, tolerance = 0))) {
    stop("B2 gradient and named topology do not agree.", call. = FALSE)
  }
  topology <- paper1_c1_classify_topology(
    gradient, names, ledger$pd_hessian, ledger$boundary_flags
  )
  if (!identical(topology$case, "D") ||
      !identical(topology$reason, "unsupported_raw_gradient_state")) {
    stop("retained B2 topology must remain Case D / unsupported_raw_gradient_state.",
         call. = FALSE)
  }
  idx <- topology$max_indices
  block <- topology$max_blocks
  if (!identical(block, "theta_rr_spde_slope") || length(idx) != 1L) {
    stop("B2 maximum must be one GBIF-only spatial-slope loading coordinate.",
         call. = FALSE)
  }
  list(
    schema = "PAPER1_C1_B2_GRADIENT_TOPOLOGY_V1",
    retained_attempt_id = ledger$attempt_id,
    retained_commit = ledger$versions$commit,
    status = "PRIVATE_NUMERICAL_ADMISSION_HOLD",
    maximum = list(index = as.integer(idx), block = block,
      signed_gradient = unname(gradient[idx]), absolute_gradient = abs(unname(gradient[idx])),
      tie_count = length(idx)),
    classifier = list(case = topology$case, reason = topology$reason,
      raw_gradient_gate = 1e-3, health_gradient_gate = 1e-2,
      case_c_blocks = c("b_fix", "theta_rr_B"), case_b_boundary = "near_zero_sd_B"),
    parameter_map = list(
      outer_block = "theta_rr_spde_slope",
      model_role = "GBIF-only spatial SPDE slope loading",
      source_column = ledger$source_map$gbif_bias_column,
      pa_structural_zero = isTRUE(ledger$source_map$pa_gbif_field_structural_zero),
      field_output = "Sigma_spde_slope_slope",
      truth_output = ledger$source_map$extractor_truth_map$gbif_bias
    ),
    immutable_state = list(objective = ledger$objective, optimizer_code = ledger$optimizer_code,
      pd_hessian = ledger$pd_hessian, boundary_flags = ledger$boundary_flags),
    decision = list(candidate = "NO_CANDIDATE",
      rationale = "The sole maximum is a spatial-only loading block outside the frozen Case-C names and lacks the named Case-B boundary.")
  )
}

paper1_c1_validate_receipt <- function(x) {
  required <- c("schema", "retained_attempt_id", "retained_commit", "status",
    "maximum", "classifier", "parameter_map", "immutable_state", "decision")
  if (!is.list(x) || !identical(names(x), required) ||
      !identical(x$schema, "PAPER1_C1_B2_GRADIENT_TOPOLOGY_V1") ||
      !identical(x$status, "PRIVATE_NUMERICAL_ADMISSION_HOLD") ||
      !identical(x$maximum$block, "theta_rr_spde_slope") ||
      !is.numeric(x$maximum$absolute_gradient) || length(x$maximum$absolute_gradient) != 1L ||
      abs(x$maximum$absolute_gradient - 0.003392914) > 1e-8 ||
      !identical(x$maximum$tie_count, 1L) ||
      !identical(x$classifier$case, "D") ||
      !identical(x$classifier$reason, "unsupported_raw_gradient_state") ||
      !identical(x$parameter_map$model_role, "GBIF-only spatial SPDE slope loading") ||
      !identical(x$decision$candidate, "NO_CANDIDATE")) {
    stop("invalid C1 topology receipt", call. = FALSE)
  }
  invisible(TRUE)
}
