## Pure summarisation and gate helpers. This file never starts a fit and never
## writes into a raw result directory.

.ISDM_SUMMARY_DIR <- local({
  current <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(current) && nzchar(current)) {
    dirname(normalizePath(current, mustWork = TRUE))
  } else if (file.exists("contract.R") && file.exists("runner.R")) {
    normalizePath(".", mustWork = TRUE)
  } else {
    normalizePath(file.path("dev", "isdm-requalification"), mustWork = TRUE)
  }
})
source(file.path(.ISDM_SUMMARY_DIR, "contract.R"), local = TRUE)
source(file.path(.ISDM_SUMMARY_DIR, "runner.R"), local = TRUE)

isdm_attempt_ledger <- function(output_dir, plan, source_contract = NULL) {
  ledger <- isdm_reconcile_attempts(output_dir, plan$task_id,
                                    planned_seeds = plan$seed,
                                    planned_specs = plan,
                                    source_contract = source_contract)
  ledger$eligible <- vapply(seq_len(nrow(plan)), function(i) {
    if (!isTRUE(ledger$terminal[[i]])) return(FALSE)
    task_id <- plan$task_id[[i]]
    path <- file.path(output_dir, "attempts", sprintf("task-%06d.rds", task_id))
    .isdm_fit_eligible(.isdm_read_receipt(path))
  }, logical(1L))
  merge(plan, ledger, by = "task_id", all.x = TRUE, sort = FALSE)
}

isdm_denominators <- function(ledger) {
  data.frame(
    planned = nrow(ledger),
    started = sum(ledger$attempted),
    terminal = sum(ledger$terminal),
    eligible = if ("eligible" %in% names(ledger))
      sum(ledger$eligible %in% TRUE) else NA_integer_,
    fit_returned = sum(ledger$status == "fit_returned"),
    error = sum(ledger$status == "error"),
    interrupted = sum(ledger$status %in%
                        c("interrupted", "interrupted_missing_terminal")),
    unavailable = sum(ledger$status == "unavailable"),
    planned_not_started = sum(ledger$status == "planned_not_started")
  )
}

isdm_rate_all_attempts <- function(pass, planned_n) {
  if (length(planned_n) != 1L || planned_n < 1L) stop("invalid planned denominator")
  sum(pass %in% TRUE) / planned_n
}

isdm_target_available <- function(record, target, truth_target = target) {
  if (!.isdm_fit_eligible(record)) return(FALSE)
  estimate <- record$estimate[[target]]
  truth <- record$truth[[truth_target]]
  !is.null(estimate) && !is.null(truth) && length(estimate) == length(truth) &&
    all(is.finite(estimate)) && all(is.finite(truth))
}

.isdm_fit_eligible <- function(record) {
  identical(record$status, "fit_returned") &&
    identical(record$diagnostics$convergence, 0L) &&
    is.finite(record$diagnostics$objective %||% NA_real_) &&
    isTRUE(record$diagnostics$pd_hessian)
}

isdm_relative_frobenius <- function(estimate, truth) {
  sqrt(sum((estimate - truth)^2)) / sqrt(sum(truth^2))
}

isdm_centered_surface_metrics <- function(estimate, truth, trait) {
  if (length(estimate) != length(truth) || length(trait) != length(truth)) {
    stop("surface vectors and trait labels must align")
  }
  groups <- split(seq_along(truth), trait)
  rows <- lapply(names(groups), function(name) {
    idx <- groups[[name]]
    est <- estimate[idx] - mean(estimate[idx])
    tru <- truth[idx] - mean(truth[idx])
    data.frame(
      trait = name,
      correlation = if (stats::sd(est) > 0 && stats::sd(tru) > 0)
        stats::cor(est, tru) else NA_real_,
      nrmse = sqrt(mean((est - tru)^2)) / stats::sd(tru),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

isdm_wilson_interval <- function(covered, available, confidence = 0.90) {
  if (available < 1L || covered < 0L || covered > available) {
    return(c(lower = NA_real_, upper = NA_real_))
  }
  z <- stats::qnorm(1 - (1 - confidence) / 2)
  p <- covered / available
  denominator <- 1 + z^2 / available
  centre <- (p + z^2 / (2 * available)) / denominator
  half <- z * sqrt(p * (1 - p) / available + z^2 / (4 * available^2)) /
    denominator
  c(lower = centre - half, upper = centre + half)
}

isdm_order_stat_interval <- function(draws, level = 0.95) {
  stats::quantile(draws, probs = c((1 - level) / 2, 1 - (1 - level) / 2),
                  type = 1, names = FALSE)
}

isdm_interval_transform_identity <- function(draws, inverse_link,
                                             level = 0.95) {
  link <- isdm_order_stat_interval(draws, level)
  response <- isdm_order_stat_interval(inverse_link(draws), level)
  max(abs(response - inverse_link(link)))
}

.isdm_available_pair <- function(record, target) {
  .isdm_fit_eligible(record) &&
    !is.null(record$estimate[[target]]) && !is.null(record$truth[[target]]) &&
    length(record$estimate[[target]]) == length(record$truth[[target]]) &&
    all(is.finite(record$estimate[[target]])) &&
    all(is.finite(record$truth[[target]]))
}

.isdm_records_frame <- function(records) {
  data.frame(
    index = seq_along(records),
    task_id = vapply(records, function(x) x$task_id %||% NA_integer_, integer(1L)),
    programme = vapply(records, function(x) x$programme %||% NA_character_,
                       character(1L)),
    status = vapply(records, function(x) x$status %||% "missing", character(1L)),
    stringsAsFactors = FALSE
  )
}

isdm_records_match_plan <- function(records, plan, source_contract = NULL) {
  if (!isdm_source_contract_valid(source_contract)) return(FALSE)
  if (length(records) != nrow(plan)) return(FALSE)
  ids <- vapply(records, function(x) as.integer(x$task_id %||% NA_integer_),
                integer(1L))
  if (anyNA(ids) || anyDuplicated(ids) || !setequal(ids, plan$task_id)) return(FALSE)
  all(vapply(seq_len(nrow(plan)), function(i) {
    record <- records[[match(plan$task_id[[i]], ids)]]
    .isdm_terminal_valid(record, plan$task_id[[i]], plan$seed[[i]],
                         as.list(plan[i, , drop = FALSE]), source_contract) &&
      identical(record$programme, plan$programme[[i]])
  }, logical(1L)))
}

.isdm_align_records <- function(records, plan) {
  ids <- vapply(records, function(x) as.integer(x$task_id %||% NA_integer_),
                integer(1L))
  records[match(plan$task_id, ids)]
}

isdm_stress_summary <- function(records) {
  n <- length(records)
  if (!n) return(list(n = 0L, promotion_eligible = FALSE))
  eligible <- vapply(records, .isdm_fit_eligible, logical(1L))
  fixed_errors <- unlist(lapply(records[eligible], function(x) {
    common <- intersect(names(x$estimate$fixed), names(x$truth$fixed))
    x$estimate$fixed[common] - x$truth$fixed[common]
  }), use.names = FALSE)
  sigma <- vapply(records[eligible], function(x) {
    if (.isdm_available_pair(x, "Sigma"))
      isdm_relative_frobenius(x$estimate$Sigma, x$truth$Sigma) else NA_real_
  }, numeric(1L))
  surfaces <- do.call(rbind, lapply(records[eligible], function(x) {
    if (!.isdm_available_pair(x, "surface")) return(NULL)
    isdm_centered_surface_metrics(x$estimate$surface, x$truth$surface,
                                  x$truth$surface_trait)
  }))
  warning_n <- vapply(records, function(x) length(x$warnings %||% character()),
                      integer(1L))
  list(
    n = n, promotion_eligible = FALSE,
    statuses = table(vapply(records, function(x) x$status, character(1L))),
    convergence_rate = sum(vapply(records, function(x)
      identical(x$diagnostics$convergence, 0L), logical(1L))) / n,
    finite_objective_rate = sum(vapply(records, function(x)
      is.finite(x$diagnostics$objective %||% NA_real_), logical(1L))) / n,
    pd_hessian_rate = sum(vapply(records, function(x)
      isTRUE(x$diagnostics$pd_hessian), logical(1L))) / n,
    warning_attempt_rate = sum(warning_n > 0L) / n,
    fixed_rmse = if (length(fixed_errors)) sqrt(mean(fixed_errors^2)) else NA_real_,
    sigma_median_relative_error = if (any(is.finite(sigma)))
      stats::median(sigma, na.rm = TRUE) else NA_real_,
    surface_median_correlation = if (!is.null(surfaces) && nrow(surfaces))
      stats::median(surfaces$correlation, na.rm = TRUE) else NA_real_,
    surface_median_nrmse = if (!is.null(surfaces) && nrow(surfaces))
      stats::median(surfaces$nrmse, na.rm = TRUE) else NA_real_
  )
}

isdm_adjudicate_ordinary <- function(records,
                                     gates = isdm_frozen_gates()$ordinary,
                                     plan = isdm_ordinary_campaign_plan(),
                                     source_contract = NULL) {
  plan_match <- isdm_records_match_plan(records, plan, source_contract)
  if (plan_match) records <- .isdm_align_records(records, plan)
  index <- .isdm_records_frame(records)
  promotion_i <- which(index$programme == "ordinary")
  stress_i <- which(index$programme == "attack")
  promotion <- records[promotion_i]
  planned <- gates$promotion_terminal_n
  terminal_status <- c("fit_returned", "error", "interrupted", "unavailable")
  complete <- plan_match && length(records) == gates$campaign_terminal_n &&
    length(promotion) == planned && length(stress_i) == gates$stress_terminal_n &&
    all(index$status %in% terminal_status)

  diagnostics <- data.frame(
    metric = c("convergence", "finite_objective", "pd_hessian"),
    rate = c(
      isdm_rate_all_attempts(vapply(promotion, function(x)
        identical(x$diagnostics$convergence, 0L), logical(1L)), planned),
      isdm_rate_all_attempts(vapply(promotion, function(x)
        is.finite(x$diagnostics$objective %||% NA_real_), logical(1L)), planned),
      isdm_rate_all_attempts(vapply(promotion, function(x)
        isTRUE(x$diagnostics$pd_hessian), logical(1L)), planned)
    ),
    threshold = c(gates$convergence_min, gates$finite_objective_min,
                  gates$pd_hessian_min)
  )
  diagnostics$pass <- diagnostics$rate >= diagnostics$threshold

  coefficient_names <- sort(unique(c(isdm_expected_fixed_targets(2L),
                                     isdm_expected_fixed_targets(3L))))
  coefficients <- do.call(rbind, lapply(coefficient_names, function(name) {
    applicable <- vapply(promotion, function(x) {
      spec <- x$task_spec
      !is.null(spec) && name %in% isdm_expected_fixed_targets(spec$n_sources)
    }, logical(1L))
    applicable_records <- promotion[applicable]
    target_planned <- sum(applicable)
    available <- vapply(applicable_records, function(x) {
      .isdm_fit_eligible(x) && name %in% names(x$truth$fixed) &&
        name %in% names(x$estimate$fixed) && is.finite(x$truth$fixed[[name]]) &&
        is.finite(x$estimate$fixed[[name]])
    }, logical(1L))
    errors <- vapply(applicable_records[available], function(x)
      x$estimate$fixed[[name]] - x$truth$fixed[[name]], numeric(1L))
    availability <- if (target_planned) sum(available) / target_planned else 0
    bias <- if (length(errors)) mean(errors) else NA_real_
    rmse <- if (length(errors)) sqrt(mean(errors^2)) else NA_real_
    data.frame(target = name, planned = target_planned,
               available = sum(available), availability = availability, bias = bias,
               rmse = rmse,
               pass = availability >= gates$target_availability_min &&
                 is.finite(bias) && abs(bias) <= gates$coefficient_abs_bias_max &&
                 is.finite(rmse) && rmse <= gates$coefficient_rmse_max)
  }))
  if (is.null(coefficients)) coefficients <- data.frame()

  paired_rmse <- do.call(rbind, lapply(coefficient_names, function(name) {
    rows <- do.call(rbind, lapply(promotion, function(x) {
      spec <- x$task_spec
      if (is.null(spec) || !.isdm_fit_eligible(x) ||
          !spec$overlap %in% c("full", "weak") ||
          !name %in% names(x$truth$fixed) || !name %in% names(x$estimate$fixed) ||
          !is.finite(x$truth$fixed[[name]]) || !is.finite(x$estimate$fixed[[name]])) {
        return(NULL)
      }
      data.frame(
        target = name, n_sources = spec$n_sources, n_cells = spec$n_cells,
        pair_id = spec$pair_id, overlap = spec$overlap,
        error = x$estimate$fixed[[name]] - x$truth$fixed[[name]]
      )
    }))
    if (is.null(rows)) return(NULL)
    full <- rows[rows$overlap == "full", ]
    weak <- rows[rows$overlap == "weak", ]
    paired <- merge(full, weak,
                    by = c("target", "n_sources", "n_cells", "pair_id"),
                    suffixes = c("_full", "_weak"))
    if (!nrow(paired)) return(NULL)
    groups <- split(seq_len(nrow(paired)),
                    interaction(paired$n_sources, paired$n_cells, drop = TRUE))
    do.call(rbind, lapply(groups, function(idx) {
      full_rmse <- sqrt(mean(paired$error_full[idx]^2))
      weak_rmse <- sqrt(mean(paired$error_weak[idx]^2))
      ratio <- if (full_rmse == 0) {
        if (weak_rmse == 0) 0 else Inf
      } else weak_rmse / full_rmse
      data.frame(target = name, n_sources = paired$n_sources[idx[[1L]]],
                 n_cells = paired$n_cells[idx[[1L]]], n_pairs = length(idx),
                 full_rmse = full_rmse, weak_rmse = weak_rmse,
                 ratio = ratio, pass = ratio <= gates$weak_rmse_ratio_max)
    }))
  }))
  if (is.null(paired_rmse)) paired_rmse <- data.frame()

  matrix_metrics <- function(target, metric) {
    available <- vapply(promotion, .isdm_available_pair, logical(1L), target)
    values <- vapply(promotion[available], function(x)
      metric(x$estimate[[target]], x$truth[[target]]), numeric(1L))
    list(availability = sum(available) / planned, values = values)
  }
  sigma <- matrix_metrics("Sigma", isdm_relative_frobenius)
  sigma_summary <- data.frame(
    target = "Sigma", availability = sigma$availability,
    median_relative_error = if (length(sigma$values)) stats::median(sigma$values) else NA_real_
  )
  sigma_summary$pass <- sigma_summary$availability >= gates$target_availability_min &&
    sigma_summary$median_relative_error <= gates$sigma_relative_frobenius_median_max

  trait_names <- sort(unique(unlist(lapply(promotion, function(x)
    rownames(x$truth$Psi %||% matrix(numeric(), 0, 0))))))
  psi <- do.call(rbind, lapply(seq_along(trait_names), function(j) {
    name <- trait_names[[j]]
    available <- vapply(promotion, function(x) {
      .isdm_available_pair(x, "Psi") && name %in% rownames(x$truth$Psi) &&
        name %in% rownames(x$estimate$Psi) && x$truth$Psi[name, name] > 0
    }, logical(1L))
    values <- vapply(promotion[available], function(x)
      abs(x$estimate$Psi[name, name] - x$truth$Psi[name, name]) /
        x$truth$Psi[name, name], numeric(1L))
    availability <- sum(available) / planned
    med <- if (length(values)) stats::median(values) else NA_real_
    data.frame(target = paste0("Psi:", name), availability = availability,
               median_relative_error = med,
               pass = availability >= gates$target_availability_min &&
                 is.finite(med) && med <= gates$psi_relative_error_median_max)
  }))

  surface_available <- vapply(promotion, .isdm_available_pair, logical(1L),
                              "surface")
  surface_rows <- do.call(rbind, lapply(promotion[surface_available], function(x) {
    out <- isdm_centered_surface_metrics(x$estimate$surface, x$truth$surface,
                                         x$truth$surface_trait)
    out$overlap <- x$task_spec$overlap %||% NA_character_
    out
  }))
  if (is.null(surface_rows)) surface_rows <- data.frame()
  surface <- data.frame(
    availability = sum(surface_available) / planned,
    median_correlation = if (nrow(surface_rows))
      stats::median(surface_rows$correlation, na.rm = TRUE) else NA_real_,
    median_nrmse = if (nrow(surface_rows))
      stats::median(surface_rows$nrmse, na.rm = TRUE) else NA_real_,
    weak_median_correlation = if (nrow(surface_rows) &&
                                  any(surface_rows$overlap == "weak"))
      stats::median(surface_rows$correlation[surface_rows$overlap == "weak"],
                    na.rm = TRUE) else NA_real_
  )
  surface$pass <- surface$availability >= gates$target_availability_min &&
    surface$median_correlation >= gates$surface_correlation_median_min &&
    surface$median_nrmse <= gates$surface_nrmse_median_max &&
    surface$weak_median_correlation >= gates$weak_surface_correlation_median_min

  pass <- complete && all(diagnostics$pass) && nrow(coefficients) > 0L &&
    all(coefficients$pass) && nrow(paired_rmse) > 0L && all(paired_rmse$pass) &&
    isTRUE(sigma_summary$pass) &&
    nrow(psi) > 0L && all(psi$pass) && isTRUE(surface$pass)
  list(verdict = if (pass) "PASS" else "FAIL", complete = complete,
       diagnostics = diagnostics, coefficients = coefficients,
       weak_full_coefficient_rmse = paired_rmse,
       Sigma = sigma_summary, Psi = psi, surface = surface,
       stress = isdm_stress_summary(records[stress_i]))
}

isdm_adjudicate_spatial <- function(records,
                                    gates = isdm_frozen_gates()$spatial,
                                    plan = isdm_point_plan("spatial"),
                                    source_contract = NULL) {
  planned <- gates$terminal_n
  plan_match <- isdm_records_match_plan(records, plan, source_contract)
  if (plan_match) records <- .isdm_align_records(records, plan)
  complete <- plan_match && length(records) == planned && all(vapply(records, function(x)
    x$status %in% c("fit_returned", "error", "interrupted", "unavailable"),
    logical(1L)))
  available <- vapply(records, function(x) {
    .isdm_available_pair(x, "heldout_surface") &&
      is.finite(x$estimate$training_identity_error %||% NA_real_) &&
      is.finite(x$estimate$source_dispatch_error %||% NA_real_)
  }, logical(1L))
  metric_rows <- do.call(rbind, lapply(records[available], function(x)
    isdm_centered_surface_metrics(x$estimate$heldout_surface,
                                  x$truth$heldout_surface,
                                  x$truth$heldout_group)))
  if (is.null(metric_rows)) metric_rows <- data.frame()
  summary <- data.frame(
    availability = sum(available) / planned,
    training_identity_max = if (any(available)) max(vapply(records[available],
      function(x) x$estimate$training_identity_error, numeric(1L))) else NA_real_,
    source_dispatch_max = if (any(available)) max(vapply(records[available],
      function(x) x$estimate$source_dispatch_error, numeric(1L))) else NA_real_,
    zero_offset_all = any(available) && all(vapply(records[available],
      function(x) isTRUE(x$estimate$zero_offset_ok), logical(1L))),
    out_of_hull_warning_all = any(available) && all(vapply(records[available],
      function(x) isTRUE(x$estimate$out_of_hull_warning_ok), logical(1L))),
    median_correlation = if (nrow(metric_rows))
      stats::median(metric_rows$correlation, na.rm = TRUE) else NA_real_,
    median_nrmse = if (nrow(metric_rows))
      stats::median(metric_rows$nrmse, na.rm = TRUE) else NA_real_
  )
  pass <- complete && summary$availability >= gates$target_availability_min &&
    summary$training_identity_max <= gates$training_identity_max &&
    summary$source_dispatch_max <= 1e-10 && summary$zero_offset_all &&
    summary$out_of_hull_warning_all &&
    summary$median_correlation >= gates$heldout_surface_correlation_median_min &&
    summary$median_nrmse <= gates$heldout_surface_nrmse_median_max
  list(verdict = if (isTRUE(pass)) "PASS" else "FAIL",
       complete = complete, summary = summary)
}
