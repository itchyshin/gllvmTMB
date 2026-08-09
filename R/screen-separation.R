.screen_empty_separation <- function() {
  data.frame(
    block_id = character(0),
    traits = character(0),
    n_traits = integer(0),
    link = character(0),
    n_observed = integer(0),
    n_columns_total = integer(0),
    n_columns_active = integer(0),
    rank = integer(0),
    status = character(0),
    severity = character(0),
    separated = logical(0),
    complete = logical(0),
    has_offset = logical(0),
    infinite_terms = character(0),
    structural_zero_terms = character(0),
    pinned_zero_terms = character(0),
    action = character(0),
    message = character(0),
    stringsAsFactors = FALSE
  )
}

.screen_separation_table <- function(
  prep,
  fam,
  response,
  control,
  Xcoef_fixed = NULL
) {
  if (is.null(prep$X)) {
    return(.screen_separation_row(
      block_id = "fixed_01",
      traits = levels(prep$data[[prep$trait_col]]),
      link = fam$link,
      n_observed = sum(
        prep$is_y_observed %||% rep.int(1L, nrow(prep$data))
      ),
      n_columns_total = 0L,
      n_columns_active = 0L,
      rank = NA_integer_,
      status = "NOT_CHECKED",
      severity = "fixed_design_unavailable",
      action = "inspect_fixed_design",
      message = prep$fixed_error %||% "the fixed-effect design is unavailable"
    ))
  }

  X <- prep$X
  if (is.null(colnames(X))) {
    colnames(X) <- paste0("x", seq_len(ncol(X)))
  }
  resolved <- .normalise_Xcoef_fixed(
    Xcoef_fixed,
    colnames(X),
    REML = FALSE
  )
  observed <- prep$is_y_observed %||% rep.int(1L, nrow(X))
  observed <- as.logical(observed)
  observed[is.na(observed)] <- FALSE
  blocks <- .screen_fixed_blocks(
    X = X,
    trait = prep$data[[prep$trait_col]],
    observed = observed,
    active_columns = resolved$status == "estimated"
  )
  offset <- .screen_separation_offset(prep)
  dependency <- .screen_detectseparation_state()

  rows <- lapply(blocks$blocks, function(block) {
    .screen_separation_block(
      block = block,
      X = X,
      trait = prep$data[[prep$trait_col]],
      response = response,
      fam = fam,
      prep = prep,
      offset = offset,
      dependency = dependency,
      tolerance = control$separation_tolerance
    )
  })
  if (!length(rows)) {
    return(.screen_empty_separation())
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.screen_fixed_blocks <- function(
  X,
  trait,
  observed,
  active_columns,
  zero_tolerance = 0
) {
  stopifnot(
    is.matrix(X),
    length(trait) == nrow(X),
    length(observed) == nrow(X),
    length(active_columns) == ncol(X)
  )
  trait <- factor(trait, levels = unique(as.character(trait)))
  trait_levels <- levels(trait)
  free_idx <- which(active_columns)
  support <- matrix(
    FALSE,
    nrow = length(trait_levels),
    ncol = length(free_idx),
    dimnames = list(trait_levels, colnames(X)[free_idx])
  )
  for (tt in seq_along(trait_levels)) {
    rows <- observed & trait == trait_levels[[tt]]
    if (length(free_idx)) {
      support[tt, ] <- vapply(
        free_idx,
        function(jj) any(abs(X[rows, jj]) > zero_tolerance, na.rm = TRUE),
        logical(1L)
      )
    }
  }

  globally_supported <- if (ncol(support)) {
    colSums(support) > 0L
  } else {
    logical(0)
  }
  structural_zero_idx <- free_idx[!globally_supported]
  free_idx <- free_idx[globally_supported]
  support <- support[, globally_supported, drop = FALSE]
  adjacency <- if (ncol(support)) {
    tcrossprod(support) > 0
  } else {
    matrix(FALSE, length(trait_levels), length(trait_levels))
  }
  diag(adjacency) <- TRUE

  component <- rep(NA_integer_, length(trait_levels))
  component_id <- 0L
  for (start in seq_along(trait_levels)) {
    if (!is.na(component[[start]])) next
    component_id <- component_id + 1L
    queue <- start
    component[[start]] <- component_id
    while (length(queue)) {
      current <- queue[[1L]]
      queue <- queue[-1L]
      neighbours <- which(adjacency[current, ] & is.na(component))
      if (length(neighbours)) {
        component[neighbours] <- component_id
        queue <- c(queue, neighbours)
      }
    }
  }

  blocks <- vector("list", component_id)
  for (bb in seq_len(component_id)) {
    trait_idx <- which(component == bb)
    block_traits <- trait_levels[trait_idx]
    rows <- which(observed & trait %in% block_traits)
    supported_local <- if (ncol(support)) {
      colSums(support[trait_idx, , drop = FALSE]) > 0L
    } else {
      logical(0)
    }
    cols <- free_idx[supported_local]
    inactive_here <- setdiff(which(active_columns), cols)
    blocks[[bb]] <- list(
      block_id = sprintf("fixed_%02d", bb),
      traits = block_traits,
      row_index = rows,
      column_index = cols,
      structural_zero_index = union(structural_zero_idx, inactive_here),
      pinned_zero_index = which(!active_columns)
    )
  }
  list(
    blocks = blocks,
    support = support,
    component = stats::setNames(component, trait_levels)
  )
}

.screen_separation_block <- function(
  block,
  X,
  trait,
  response,
  fam,
  prep,
  offset,
  dependency,
  tolerance
) {
  rows <- block$row_index
  cols <- block$column_index
  base <- list(
    block_id = block$block_id,
    traits = block$traits,
    link = fam$link,
    n_observed = length(rows),
    n_columns_total = ncol(X),
    n_columns_active = length(cols),
    has_offset = isTRUE(offset$present),
    structural_zero_terms = colnames(X)[block$structural_zero_index],
    pinned_zero_terms = colnames(X)[block$pinned_zero_index]
  )
  not_checked <- function(severity, action, message, rank = NA_integer_) {
    do.call(
      .screen_separation_row,
      c(
        base,
        list(
          rank = rank,
          status = "NOT_CHECKED",
          severity = severity,
          action = action,
          message = message
        )
      )
    )
  }

  if (!isTRUE(fam$supported)) {
    return(not_checked(
      "unsupported_family",
      "use_supported_scope",
      fam$reason
    ))
  }
  if (length(prep$parsed$mi_vars %||% character(0))) {
    return(not_checked(
      "missing_predictor_model",
      "use_supported_scope",
      "fixed-design separation is not checked for mi() predictor models"
    ))
  }
  if (is.null(response) || !isTRUE(response$valid_global)) {
    return(not_checked(
      "response_unavailable",
      "inspect_response",
      "the Bernoulli response could not be normalized"
    ))
  }
  if (!identical(response$mode, "bernoulli")) {
    return(not_checked(
      "grouped_binomial",
      "use_supported_scope",
      "fixed-design separation is checked for unweighted single-trial Bernoulli rows only"
    ))
  }
  if (!isTRUE(offset$ok)) {
    return(not_checked(
      "offset_unavailable",
      "use_supported_scope",
      offset$message
    ))
  }
  if (!length(rows)) {
    return(not_checked(
      "no_observed_response",
      "inspect_response",
      "the block has no observed response rows"
    ))
  }
  if (any(!response$valid[rows] | !response$binary_row[rows])) {
    return(not_checked(
      "invalid_response",
      "inspect_response",
      "the block contains invalid or non-Bernoulli response rows"
    ))
  }
  X_block <- X[rows, cols, drop = FALSE]
  if (anyNA(X_block)) {
    return(not_checked(
      "missing_predictor",
      "inspect_predictors",
      "the active fixed design contains missing predictor values"
    ))
  }
  if (any(!is.finite(X_block))) {
    return(not_checked(
      "non_finite_design",
      "inspect_predictors",
      "the active fixed design contains non-finite predictor values"
    ))
  }

  y <- as.numeric(response$success[rows])
  trait_block <- as.character(trait[rows])
  constant_traits <- vapply(
    block$traits,
    function(tt) length(unique(y[trait_block == tt])) < 2L,
    logical(1L)
  )
  if (any(constant_traits)) {
    return(not_checked(
      "constant_response",
      "inspect_or_remove_constant_trait",
      paste0(
        "constant response in trait(s): ",
        paste(block$traits[constant_traits], collapse = ", ")
      )
    ))
  }
  if (!length(cols)) {
    return(not_checked(
      "no_free_coefficients",
      "resolve_fixed_design",
      "the block has no free, supported fixed-effect coefficient"
    ))
  }

  rank <- qr(X_block, tol = sqrt(.Machine$double.eps))$rank
  if (rank < ncol(X_block)) {
    return(not_checked(
      "rank_deficient",
      "resolve_fixed_design",
      sprintf(
        "the active fixed design has rank %d but %d columns",
        rank,
        ncol(X_block)
      ),
      rank = rank
    ))
  }
  if (!isTRUE(dependency$ok)) {
    return(not_checked(
      dependency$severity,
      dependency$action,
      dependency$message,
      rank = rank
    ))
  }

  detected <- tryCatch(
    .screen_run_detectseparation(
      X = X_block,
      y = y,
      offset = offset$value[rows],
      link = fam$link,
      tolerance = tolerance
    ),
    error = function(e) e
  )
  if (inherits(detected, "error")) {
    return(not_checked(
      "solver_failure",
      "report_or_disable_separation",
      paste("the separation solver failed:", conditionMessage(detected)),
      rank = rank
    ))
  }
  outcome_valid <- is.logical(detected$outcome) &&
    length(detected$outcome) == 1L &&
    !is.na(detected$outcome)
  complete_valid <- !isTRUE(detected$outcome) ||
    (is.logical(detected$complete) &&
      length(detected$complete) == 1L &&
      !is.na(detected$complete))
  if (!outcome_valid || !complete_valid) {
    return(not_checked(
      "solver_failure",
      "report_or_disable_separation",
      "the separation solver returned an incomplete certificate",
      rank = rank
    ))
  }

  separated <- isTRUE(detected$outcome)
  complete <- if (separated) isTRUE(detected$complete) else NA
  severity <- if (!separated) {
    "overlap"
  } else if (complete) {
    "complete"
  } else {
    "quasi_complete"
  }
  coefficients <- tryCatch(stats::coef(detected), error = function(e) numeric(0))
  if (length(coefficients) == ncol(X_block) && is.null(names(coefficients))) {
    names(coefficients) <- colnames(X_block)
  }
  infinite_terms <- if (length(coefficients)) {
    names(coefficients)[is.infinite(coefficients)]
  } else {
    character(0)
  }
  .screen_separation_row(
    block_id = block$block_id,
    traits = block$traits,
    link = fam$link,
    n_observed = length(rows),
    n_columns_total = ncol(X),
    n_columns_active = length(cols),
    rank = rank,
    status = if (separated) "WARN" else "PASS",
    severity = severity,
    separated = separated,
    complete = complete,
    has_offset = base$has_offset,
    infinite_terms = infinite_terms,
    structural_zero_terms = base$structural_zero_terms,
    pinned_zero_terms = base$pinned_zero_terms,
    action = if (separated) "consider_penalized_fit" else "fit_as_planned",
    message = if (separated) {
      paste("fixed-design", gsub("_", "-", severity), "detected")
    } else {
      "the observed fixed design has overlap"
    }
  )
}

.screen_separation_row <- function(
  block_id,
  traits,
  link,
  n_observed,
  n_columns_total,
  n_columns_active,
  rank,
  status,
  severity,
  separated = NA,
  complete = NA,
  has_offset = FALSE,
  infinite_terms = character(0),
  structural_zero_terms = character(0),
  pinned_zero_terms = character(0),
  action,
  message
) {
  collapse <- function(x) paste(x, collapse = ", ")
  data.frame(
    block_id = block_id,
    traits = collapse(traits),
    n_traits = length(traits),
    link = link %||% NA_character_,
    n_observed = as.integer(n_observed),
    n_columns_total = as.integer(n_columns_total),
    n_columns_active = as.integer(n_columns_active),
    rank = as.integer(rank),
    status = status,
    severity = severity,
    separated = as.logical(separated),
    complete = as.logical(complete),
    has_offset = as.logical(has_offset),
    infinite_terms = collapse(infinite_terms),
    structural_zero_terms = collapse(structural_zero_terms),
    pinned_zero_terms = collapse(pinned_zero_terms),
    action = action,
    message = message,
    stringsAsFactors = FALSE
  )
}

.screen_separation_offset <- function(prep) {
  expr <- prep$parsed$offset_expr
  if (is.null(expr)) {
    return(list(
      ok = TRUE,
      present = FALSE,
      value = numeric(nrow(prep$data))
    ))
  }
  value <- tryCatch(
    eval(expr, prep$data, environment(prep$formula)),
    error = function(e) e
  )
  if (inherits(value, "error")) {
    return(list(
      ok = FALSE,
      message = paste("the binary offset could not be evaluated:", conditionMessage(value))
    ))
  }
  if (!is.numeric(value)) {
    return(list(ok = FALSE, message = "the binary offset is not numeric"))
  }
  if (length(value) == 1L) value <- rep(value, nrow(prep$data))
  if (length(value) != nrow(prep$data) || anyNA(value) || any(!is.finite(value))) {
    return(list(
      ok = FALSE,
      message = "the binary offset must be finite and have one value per screened row"
    ))
  }
  list(ok = TRUE, present = TRUE, value = as.numeric(value))
}

.screen_detectseparation_state <- function() {
  if (!requireNamespace("detectseparation", quietly = TRUE)) {
    return(list(
      ok = FALSE,
      severity = "dependency_missing",
      action = "install_or_disable_separation",
      message = paste0(
        "install detectseparation (>= 0.4.0), or set separation = ",
        "\"none\""
      )
    ))
  }
  version <- utils::packageVersion("detectseparation")
  if (version < numeric_version("0.4.0")) {
    return(list(
      ok = FALSE,
      severity = "dependency_too_old",
      action = "update_or_disable_separation",
      message = sprintf(
        "detectseparation >= 0.4.0 is required; found %s",
        as.character(version)
      )
    ))
  }
  list(ok = TRUE)
}

.screen_run_detectseparation <- function(X, y, offset, link, tolerance) {
  detector_control <- detectseparation::detect_separation_control(
    tolerance = tolerance,
    separation_type = TRUE
  )
  detectseparation::detect_separation(
    x = X,
    y = y,
    offset = offset,
    family = stats::binomial(link = link),
    control = detector_control,
    intercept = FALSE,
    singular.ok = FALSE
  )
}

.screen_recommend_from_separation <- function(separation) {
  if (is.null(separation) || !nrow(separation)) {
    return(.screen_empty_recommendations())
  }
  data.frame(
    scope = "separation",
    status = separation$status,
    action = separation$action,
    trait = separation$traits,
    evidence = separation$message,
    model_implication = ifelse(
      separation$status == "WARN",
      paste0(
        "fixed-design separation was detected; consider an explicitly ",
        "chosen penalized or bias-reduced fit within its supported scope"
      ),
      ifelse(
        separation$status == "NOT_CHECKED",
        paste0(
          "fixed-design separation is not certified; resolve the stated ",
          "condition before relying on it"
        ),
        "fixed-design overlap does not change the planned fit"
      )
    ),
    stringsAsFactors = FALSE
  )
}
