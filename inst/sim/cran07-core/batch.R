# Restart-safe manifest construction and atomic per-attempt persistence.

cran07_manifest <- function(registry, stage = c("smoke", "production"), reps = NULL,
                            cells = NULL, campaign_id, registry_sha256) {
  stage <- match.arg(stage)
  if (!is.null(cells)) registry <- registry[registry$cell_id %in% cells, , drop = FALSE]
  if (!nrow(registry)) stop("No registry cells selected.", call. = FALSE)
  nrep <- if (!is.null(reps)) rep(as.integer(reps), nrow(registry)) else
    registry[[paste0(stage, "_reps")]]
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    data.frame(campaign_id = campaign_id, registry_sha256 = registry_sha256,
      cell_number = registry$cell_number[i], cell_id = registry$cell_id[i],
      replicate = seq_len(nrep[i]), seed = vapply(seq_len(nrep[i]), function(r)
        cran07_seed(registry$cell_number[i], r,
                    cran07_campaign_seed_offset(campaign_id)), integer(1L)),
      stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

cran07_attempt_path <- function(output_dir, cell_id, replicate) {
  file.path(output_dir, sprintf("%s__rep%05d.rds", cell_id, replicate))
}

cran07_write_attempt <- function(result, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(pattern = ".cran07-attempt-", tmpdir = dirname(path), fileext = ".rds")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  saveRDS(result, tmp, version = 3)
  check <- readRDS(tmp)
  cran07_validate_attempt_table(check$attempt)
  if (!file.rename(tmp, path)) stop("Atomic attempt rename failed: ", path, call. = FALSE)
  invisible(path)
}

cran07_run_manifest <- function(registry, manifest, output_dir) {
  Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
             VECLIB_MAXIMUM_THREADS = "1", BLIS_NUM_THREADS = "1")
  for (i in seq_len(nrow(manifest))) {
    key <- manifest[i, ]
    offset <- cran07_campaign_seed_offset(key$campaign_id)
    expected_seed <- cran07_seed(key$cell_number, key$replicate, offset)
    if (!identical(as.integer(key$seed), expected_seed)) {
      stop("Manifest seed contradicts the immutable cell/replicate seed rule.", call. = FALSE)
    }
    path <- cran07_attempt_path(output_dir, key$cell_id, key$replicate)
    if (file.exists(path)) {
      old <- tryCatch(readRDS(path), error = function(e) NULL)
      valid <- !is.null(old) && tryCatch({
        cran07_validate_attempt_table(old$attempt)
        identical(old$attempt$campaign_id, key$campaign_id) &&
          identical(old$attempt$registry_sha256, key$registry_sha256) &&
          identical(old$attempt$cell_id, key$cell_id) &&
          identical(old$attempt$replicate, as.integer(key$replicate)) &&
          identical(old$attempt$seed, as.integer(key$seed))
      }, error = function(e) FALSE)
      if (isTRUE(valid)) next
      stop("Existing attempt file is corrupt or belongs to another immutable key: ", path,
           call. = FALSE)
    }
    cell <- registry[registry$cell_id == key$cell_id, , drop = FALSE]
    result <- cran07_run_attempt(cell, key$replicate, key$campaign_id, key$registry_sha256)
    cran07_write_attempt(result, path)
  }
  invisible(TRUE)
}

cran07_detector_2x2 <- function(x, by_cell = TRUE) {
  if (!nrow(x)) return(data.frame())
  cells <- if (by_cell) unique(x$cell_id) else "ALL"
  grids <- lapply(cells, function(cell) {
    z <- if (by_cell) x[x$cell_id == cell, , drop = FALSE] else x
    grid <- expand.grid(catastrophic_truth_error = c(FALSE, TRUE),
                        detector_flagged = c(FALSE, TRUE), KEEP.OUT.ATTRS = FALSE)
    count <- aggregate(rep.int(1L, nrow(z)),
      list(catastrophic_truth_error = z$catastrophic_truth_error,
           detector_flagged = z$detector_flagged), sum)
    names(count)[[3L]] <- "n"
    grid <- merge(grid, count, all.x = TRUE, sort = FALSE)
    grid$n[is.na(grid$n)] <- 0L
    data.frame(cell_id = cell, grid, stringsAsFactors = FALSE)
  })
  do.call(rbind, grids)
}

cran07_exact_binomial_upper <- function(events, denominator, conf.level = 0.95) {
  if (length(events) != 1L || length(denominator) != 1L ||
      is.na(events) || is.na(denominator) || denominator < 1L ||
      events < 0L || events > denominator) return(NA_real_)
  unname(stats::binom.test(events, denominator, alternative = "less",
                           conf.level = conf.level)$conf.int[[2L]])
}

cran07_attempt_denominators <- function(attempts, manifest = NULL) {
  if (!nrow(attempts) && is.null(manifest)) return(data.frame())
  cells <- if (is.null(manifest)) unique(attempts$cell_id) else unique(manifest$cell_id)
  do.call(rbind, lapply(cells, function(cell) {
    z <- attempts[attempts$cell_id == cell, , drop = FALSE]
    n_expected <- if (is.null(manifest)) nrow(z) else sum(manifest$cell_id == cell)
    n_attempts <- nrow(z)
    n_stationary_usable <- sum(z$status == "usable" & z$stationary)
    data.frame(
      cell_id = cell, n_expected = n_expected, n_attempts = n_attempts,
      n_terminal = sum(z$status != "planned"), n_optimizer_converged = sum(z$optimizer_converged),
      n_stationary = sum(z$stationary), n_stationary_usable = n_stationary_usable,
      n_pd_hessian = sum(z$pd_hessian), n_usable = sum(z$status == "usable"),
      optimizer_rate = if (n_attempts) sum(z$optimizer_converged) / n_attempts else NA_real_,
      stationary_rate = if (n_attempts) sum(z$stationary) / n_attempts else NA_real_,
      stationary_usable_rate = if (n_attempts) n_stationary_usable / n_attempts else NA_real_,
      pd_hessian_rate = if (n_attempts) sum(z$pd_hessian) / n_attempts else NA_real_,
      complete = n_attempts == n_expected && sum(z$status != "planned") == n_expected,
      stringsAsFactors = FALSE)
  }))
}

cran07_detector_metrics <- function(attempts) {
  if (!nrow(attempts)) return(data.frame())
  do.call(rbind, lapply(unique(attempts$cell_id), function(cell) {
    z <- attempts[attempts$cell_id == cell, , drop = FALSE]
    tp <- sum(z$catastrophic_truth_error & z$detector_flagged)
    fn <- sum(z$catastrophic_truth_error & !z$detector_flagged)
    fp <- sum(!z$catastrophic_truth_error & z$detector_flagged)
    tn <- sum(!z$catastrophic_truth_error & !z$detector_flagged)
    positive_n <- tp + fn
    negative_n <- tn + fp
    data.frame(
      cell_id = cell, true_positive = tp, false_negative = fn,
      false_positive = fp, true_negative = tn,
      sensitivity_denominator = positive_n,
      specificity_denominator = negative_n,
      false_negative_rate_denominator = nrow(z),
      sensitivity = if (positive_n > 0L) tp / positive_n else NA_real_,
      specificity = if (negative_n > 0L) tn / negative_n else NA_real_,
      catastrophic_but_healthy_rate = fn / nrow(z),
      catastrophic_but_healthy_upper_95 = cran07_exact_binomial_upper(fn, nrow(z)),
      stringsAsFactors = FALSE)
  }))
}

cran07_gate_summary <- function(attempt_denominators, detector_metrics,
                                estimand_summary) {
  if (!nrow(attempt_denominators)) return(data.frame())
  x <- merge(attempt_denominators, detector_metrics, by = "cell_id", all.x = TRUE,
             sort = FALSE)
  beta <- if ("estimand" %in% names(estimand_summary))
    estimand_summary[estimand_summary$estimand == "beta", , drop = FALSE] else data.frame()
  beta_pass <- vapply(x$cell_id, function(cell) {
    if (!nrow(beta)) return(FALSE)
    z <- beta[beta$cell_id == cell, , drop = FALSE]
    nrow(z) > 0L && all(z$n_estimates == z$n_attempts) &&
      all(!z$zero_sd) && all(z$standardized_abs_bias <= 0.10)
  }, logical(1L))
  x$production_complete <- x$complete & x$n_expected == 400L & x$n_attempts == 400L
  x$stationary_usable_pass <- x$stationary_usable_rate >= 0.95
  x$pd_hessian_pass <- x$pd_hessian_rate >= 0.90
  x$detector_sensitivity_pass <- !is.na(x$sensitivity) & x$sensitivity >= 0.95
  x$detector_specificity_pass <- !is.na(x$specificity) & x$specificity >= 0.90
  x$catastrophic_but_healthy_pass <-
    !is.na(x$catastrophic_but_healthy_upper_95) &
    x$catastrophic_but_healthy_upper_95 < 0.02
  x$fixed_effect_bias_pass <- beta_pass
  x$g1_pass <- with(x, production_complete & stationary_usable_pass &
    pd_hessian_pass & detector_sensitivity_pass & detector_specificity_pass &
    catastrophic_but_healthy_pass & fixed_effect_bias_pass)
  x
}

cran07_estimand_group_summary <- function(g, n_attempts) {
  empirical_sd <- if (nrow(g) > 1L) stats::sd(g$estimate) else NA_real_
  zero_sd <- is.na(empirical_sd) || !is.finite(empirical_sd) || empirical_sd <= 0
  data.frame(
    cell_id = g$cell_id[[1L]], estimand = g$estimand[[1L]],
    component = g$component[[1L]], n_estimates = nrow(g),
    n_attempts = n_attempts, bias = mean(g$error),
    rmse = sqrt(mean(g$error^2)),
    mcse_bias = if (nrow(g) > 1L) stats::sd(g$error) / sqrt(nrow(g)) else NA_real_,
    empirical_sd_estimate = empirical_sd, zero_sd = zero_sd,
    standardized_abs_bias = if (zero_sd) Inf else abs(mean(g$error)) / empirical_sd,
    mean_truth = mean(g$truth), mean_estimate = mean(g$estimate),
    stringsAsFactors = FALSE)
}

cran07_summarize <- function(output_dir, manifest = NULL) {
  paths <- sort(list.files(output_dir, pattern = "\\.rds$", full.names = TRUE))
  results <- lapply(paths, readRDS)
  attempts <- if (length(results)) do.call(rbind, lapply(results, `[[`, "attempt")) else data.frame()
  if (nrow(attempts)) cran07_validate_attempt_table(attempts)
  if (!is.null(manifest)) {
    expected <- paste(manifest$campaign_id, manifest$cell_id, manifest$replicate, sep = "::")
    observed <- if (nrow(attempts)) paste(attempts$campaign_id, attempts$cell_id, attempts$replicate, sep = "::") else character()
    missing <- setdiff(expected, observed)
    extra <- setdiff(observed, expected)
    if (length(extra)) stop("Output contains attempts absent from manifest.", call. = FALSE)
  } else missing <- character()
  estimands <- do.call(rbind, Filter(Negate(is.null), lapply(results, `[[`, "estimands")))
  status <- if (nrow(attempts)) as.data.frame.matrix(table(attempts$cell_id, attempts$status)) else data.frame()
  detector_by_cell <- cran07_detector_2x2(attempts, TRUE)
  detector_overall <- cran07_detector_2x2(attempts, FALSE)
  attempt_denominators <- cran07_attempt_denominators(attempts, manifest)
  detector_metrics <- cran07_detector_metrics(attempts)
  if (!is.null(estimands) && nrow(estimands)) {
    z <- estimands[estimands$applicable & is.finite(estimands$estimate), ]
    z$error <- z$estimate - z$truth
    groups <- split(z, interaction(z$cell_id, z$estimand, z$component, drop = TRUE))
    estimand_summary <- do.call(rbind, lapply(groups, function(g) {
      n_attempts <- sum(attempts$cell_id == g$cell_id[[1L]])
      cran07_estimand_group_summary(g, n_attempts)
    }))
    rownames(estimand_summary) <- NULL
  } else estimand_summary <- data.frame()
  gates <- cran07_gate_summary(attempt_denominators, detector_metrics, estimand_summary)
  list(attempts = attempts, status_by_cell = status, estimands = estimands,
       estimand_summary = estimand_summary,
       attempt_denominators_by_cell = attempt_denominators,
       detector_2x2_by_cell = detector_by_cell,
       detector_2x2_overall = detector_overall,
       detector_metrics_by_cell = detector_metrics,
       gate_summary_by_cell = gates,
       missing_attempt_keys = missing)
}
