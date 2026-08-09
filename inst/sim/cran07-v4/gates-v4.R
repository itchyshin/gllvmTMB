# Pure v4 gates. Thresholds are inherited from v3; denominators are 20/1600.

CRAN07_V4_PILOT_REPS <- 20L
CRAN07_V4_PRODUCTION_REPS <- 1600L
CRAN07_V4_RMSE_BOOT_B <- 2000L
CRAN07_V4_RMSE_BOOT_SEED <- 670830001L
CRAN07_V4_NUMERICAL_ZERO_TOL <- 64 * .Machine$double.eps

cran07_v4_assess_estimands <- function(estimands) {
  ans <- cran07_assess_estimands(estimands)
  phi <- estimands[estimands$estimand == "phi_nbinom2" & estimands$applicable,
                   , drop = FALSE]
  if (nrow(phi)) {
    ratio <- phi$estimate / phi$truth
    bad <- any(!is.finite(ratio) | ratio < 0.1 | ratio > 10)
    ans$catastrophic_truth_error <- ans$catastrophic_truth_error || bad
  }
  ans
}

cran07_v4_expected_campaign_cells <- function(registries) {
  ids <- CRAN07_V4_CAMPAIGNS$campaign_id
  if (!is.list(registries) || !all(ids %in% names(registries))) {
    stop("All three named v4 registries are required.", call. = FALSE)
  }
  do.call(rbind, lapply(ids, function(id) data.frame(
    campaign_id = id, cell_id = registries[[id]]$cell_id,
    stringsAsFactors = FALSE)))
}

cran07_v4_detector_metrics_global <- cran07_v3_detector_metrics_global

cran07_v4_pilot_admission <- function(attempts, expected_cells) {
  required <- c("cell_id", "status", "finite_estimands", "stationary", "pd_hessian")
  if (length(setdiff(required, names(attempts)))) {
    stop("Pilot attempts are missing v4 gate columns.", call. = FALSE)
  }
  x <- cran07_v3_status_counts(attempts, expected_cells, CRAN07_V4_PILOT_REPS)
  x$complete_pass <- x$n_attempts == 20L & x$n_terminal == 20L
  x$unusable_pass <- x$n_unusable <= 3L
  x$unclassified_pass <- x$n_unclassified == 0L
  x$nonfinite_core_pass <- x$n_nonfinite_core == 0L
  x$admitted <- with(x, complete_pass & unusable_pass & unclassified_pass &
                       nonfinite_core_pass)
  x
}

cran07_v4_pilot_global_gate <- function(attempts, expected_campaign_cells) {
  required <- c("campaign_id", "cell_id", "catastrophic_truth_error",
                "detector_flagged")
  if (!is.data.frame(expected_campaign_cells) ||
      nrow(expected_campaign_cells) != 34L ||
      anyDuplicated(paste(expected_campaign_cells$campaign_id,
                          expected_campaign_cells$cell_id)) ||
      !setequal(unique(expected_campaign_cells$campaign_id),
                CRAN07_V4_CAMPAIGNS$campaign_id) ||
      length(setdiff(required, names(attempts)))) {
    return(cran07_v4_detector_metrics_global(data.frame(), expected_n = 680L))
  }
  expected_key <- paste(expected_campaign_cells$campaign_id,
                        expected_campaign_cells$cell_id, sep = "::")
  observed_key <- paste(attempts$campaign_id, attempts$cell_id, sep = "::")
  counts <- table(factor(observed_key, levels = expected_key))
  if (length(observed_key) != 680L || any(!observed_key %in% expected_key) ||
      any(counts != 20L)) {
    return(cran07_v4_detector_metrics_global(data.frame(), expected_n = 680L))
  }
  cran07_v4_detector_metrics_global(attempts, expected_n = 680L)
}

cran07_v4_pilot_verdict <- function(attempts, expected_campaign_cells,
                                    cell_admission = NULL) {
  required <- c("campaign_id", "cell_id", "admitted")
  expected_key <- paste(expected_campaign_cells$campaign_id,
                        expected_campaign_cells$cell_id, sep = "::")
  recomputed <- do.call(rbind, lapply(unique(expected_campaign_cells$campaign_id),
    function(id) {
      cells <- expected_campaign_cells$cell_id[
        expected_campaign_cells$campaign_id == id]
      z <- cran07_v4_pilot_admission(
        attempts[attempts$campaign_id == id, , drop = FALSE], cells)
      z$campaign_id <- id
      z
    }))
  if (!is.null(cell_admission)) {
    if (!is.data.frame(cell_admission) ||
        length(setdiff(required, names(cell_admission))) ||
        nrow(cell_admission) != 34L || anyNA(cell_admission$admitted) ||
        !setequal(paste(cell_admission$campaign_id, cell_admission$cell_id,
                        sep = "::"), expected_key)) {
      stop("Stored v4 admission ledger is not a complete 34-cell decision.",
           call. = FALSE)
    }
    fields <- names(recomputed)
    order_gate <- function(x) {
      x <- x[order(x$campaign_id, x$cell_id), fields, drop = FALSE]
      rownames(x) <- NULL
      x
    }
    if (!identical(order_gate(cell_admission), order_gate(recomputed))) {
      stop("Stored v4 pilot gate differs from recomputation from attempts.",
           call. = FALSE)
    }
  }
  detector <- cran07_v4_pilot_global_gate(attempts, expected_campaign_cells)
  challenge <- recomputed$cell_id %in% CRAN07_V4_HELD_CHALLENGE_CELLS
  target <- recomputed[!challenge, , drop = FALSE]
  admitted <- target[target$admitted, c("campaign_id", "cell_id"), drop = FALSE]
  held <- rbind(
    recomputed[challenge, c("campaign_id", "cell_id"), drop = FALSE],
    target[!target$admitted, c("campaign_id", "cell_id"), drop = FALSE])
  list(detector_global = detector, detector_qualified = isTRUE(detector$pass),
       production_target_n = 31L, admitted_cells = admitted,
       held_cells = held, challenge_cells = CRAN07_V4_HELD_CHALLENGE_CELLS,
       cell_admission = recomputed,
       production_authorized = isTRUE(detector$pass) && nrow(admitted) > 0L)
}

cran07_v4_validate_pilot_summary <- function(summary, registry, campaign_id) {
  if (!is.list(summary) || !is.list(summary$v4_identity) ||
      !is.data.frame(summary$attempts) || !is.data.frame(summary$v4_gate)) {
    stop("V4 pilot summary is structurally incomplete.", call. = FALSE)
  }
  id <- summary$v4_identity
  spec <- cran07_v4_campaign_spec(campaign_id)
  if (!identical(id$campaign_id, campaign_id) ||
      !identical(id$stage, "pilot") || !isTRUE(id$complete) ||
      !identical(id$registry_sha256, spec$registry_sha256) ||
      !grepl("^[0-9a-f]{64}$", id$source_archive_sha256) ||
      !identical(id$expected_attempts, as.integer(nrow(registry) * 20L)) ||
      !identical(id$observed_attempts, id$expected_attempts) ||
      !identical(sort(id$expected_cells), sort(registry$cell_id))) {
    stop("V4 pilot summary identity is invalid.", call. = FALSE)
  }
  manifest <- cran07_v4_manifest(registry, campaign_id, "pilot",
                                 id$source_archive_sha256)
  if (!identical(id$manifest_sha256, cran07_v4_manifest_sha256(manifest))) {
    stop("V4 pilot summary manifest hash differs from canonical reconstruction.",
         call. = FALSE)
  }
  cran07_v4_validate_attempt_table(summary$attempts)
  cran07_v4_assert_attempt_manifest_identity(summary$attempts, manifest)
  recomputed <- cran07_v4_pilot_admission(summary$attempts, registry$cell_id)
  fields <- names(recomputed)
  order_gate <- function(x) {
    x <- x[order(x$cell_id), fields, drop = FALSE]
    rownames(x) <- NULL
    x
  }
  if (length(setdiff(fields, names(summary$v4_gate))) ||
      !identical(order_gate(summary$v4_gate), order_gate(recomputed))) {
    stop("Stored pilot gate differs from the retained-attempt recomputation.",
         call. = FALSE)
  }
  recomputed
}

cran07_v4_complete_component <- function(z, expected_n = CRAN07_V4_PRODUCTION_REPS) {
  all(CRAN07_V4_IDENTITY_COLUMNS %in% names(z)) && nrow(z) == expected_n &&
    !anyDuplicated(z$replicate) && !anyDuplicated(z$seed) &&
    identical(sort(as.integer(z$replicate)), seq_len(expected_n)) &&
    length(unique(z$campaign_id)) == 1L &&
    length(unique(z$registry_sha256)) == 1L &&
    length(unique(z$source_archive_sha256)) == 1L &&
    length(unique(z$cell_id)) == 1L &&
    all(z$applicable) && all(is.finite(z$estimate)) && all(is.finite(z$truth))
}

cran07_v4_expected_component_schema <- function(registry, campaign_id) {
  spec <- cran07_v4_campaign_spec(campaign_id)
  v3_id <- sub("-v4$", "-v3", campaign_id)
  ans <- cran07_v3_expected_component_schema(registry, v3_id)
  nb2 <- registry[registry$family == "nbinom2", , drop = FALSE]
  if (nrow(nb2)) {
    extra <- do.call(rbind, lapply(seq_len(nrow(nb2)), function(i) data.frame(
      cell_id = nb2$cell_id[[i]], estimand = "phi_nbinom2",
      component = paste0("t", seq_len(nb2$n_traits[[i]])),
      stringsAsFactors = FALSE)))
    ans <- rbind(ans, extra)
  }
  if (!identical(attr(registry, "sha256"), spec$registry_sha256) ||
      anyDuplicated(paste(ans$cell_id, ans$estimand, ans$component, sep = "::"))) {
    stop("V4 expected component schema is not uniquely registry-derived.",
         call. = FALSE)
  }
  rownames(ans) <- NULL
  ans
}

cran07_v4_component_schema_pass <- function(estimands, cell, expected_schema) {
  expected <- expected_schema[expected_schema$cell_id == cell, , drop = FALSE]
  observed <- estimands[estimands$cell_id == cell & estimands$applicable,
                        c("estimand", "component"), drop = FALSE]
  identical(sort(unique(paste(observed$estimand, observed$component, sep = "::"))),
            sort(unique(paste(expected$estimand, expected$component, sep = "::"))))
}

cran07_v4_validate_estimand_identity <- function(estimands, attempts, manifest,
                                                  registry, campaign_id) {
  core_required <- c("estimand", "component", "applicable", "truth", "estimate",
                     "trait_i", "trait_j")
  absent <- setdiff(c(CRAN07_V4_IDENTITY_COLUMNS, core_required), names(estimands))
  if (length(absent)) stop("V4 estimands lack identity/schema columns: ",
                           paste(absent, collapse = ", "), call. = FALSE)
  cran07_v4_validate_attempt_table(attempts)
  cran07_v4_assert_attempt_manifest_identity(attempts, manifest)
  normalized <- cran07_v4_normalize_structural_psi(estimands)
  if (!identical(normalized$applicable, estimands$applicable)) {
    structural <- estimands$estimand == "Psi" &
      estimands$trait_i != estimands$trait_j
    if (any(estimands$applicable[structural])) {
      stop("Structural Psi applicability was not normalized before persistence.",
           call. = FALSE)
    }
  }
  id_key <- function(x) do.call(paste, c(x[CRAN07_V4_IDENTITY_COLUMNS],
                                         list(sep = "::")))
  attempt_key <- id_key(attempts)
  estimand_key <- id_key(estimands)
  if (anyNA(estimands[CRAN07_V4_IDENTITY_COLUMNS]) ||
      any(!estimand_key %in% attempt_key)) {
    stop("Every estimand row must join exactly to one six-field attempt identity.",
         call. = FALSE)
  }
  row_key <- paste(estimand_key, estimands$estimand, estimands$component, sep = "::")
  if (anyDuplicated(row_key)) {
    stop("Estimand ledger duplicates an attempt/component identity.", call. = FALSE)
  }
  expected_schema <- cran07_v4_expected_component_schema(registry, campaign_id)
  applicable <- estimands$applicable
  app <- estimands[applicable, , drop = FALSE]
  app_key <- estimand_key[applicable]
  expected_by_cell <- split(paste(expected_schema$estimand,
                                  expected_schema$component, sep = "::"),
                            expected_schema$cell_id)
  observed_by_cell <- split(paste(app$estimand, app$component, sep = "::"),
                            app$cell_id)
  for (cell in registry$cell_id) {
    observed <- sort(unique(observed_by_cell[[cell]] %||% character()))
    expected <- sort(unique(expected_by_cell[[cell]] %||% character()))
    if (length(observed) && !identical(observed, expected)) {
      stop("Applicable estimand schema differs from the canonical schema for ",
           cell, ".", call. = FALSE)
    }
  }
  app_counts <- table(factor(app_key, levels = attempt_key))
  expected_count <- vapply(attempts$cell_id, function(cell)
    length(expected_by_cell[[cell]] %||% character()), integer(1L))
  should_have <- attempts$finite_estimands
  if (any(app_counts[should_have] != expected_count[should_have]) ||
      any(app_counts[!should_have] != 0L)) {
    stop("Each finite attempt must contribute every canonical applicable component exactly once.",
         call. = FALSE)
  }
  invisible(TRUE)
}

cran07_v4_validate_truth_metrics <- function(attempts, estimands) {
  required <- c("catastrophic_truth_error", "relative_covariance_error",
                "max_eigen_ratio", "detector_flagged", "status",
                "finite_estimands")
  if (length(setdiff(required, names(attempts))) ||
      (nrow(estimands) &&
       length(setdiff(CRAN07_V4_IDENTITY_COLUMNS, names(estimands))))) {
    stop("Truth-metric recomputation lacks attempt or estimand fields.",
         call. = FALSE)
  }
  id_key <- function(x) do.call(paste, c(x[CRAN07_V4_IDENTITY_COLUMNS],
                                         list(sep = "::")))
  attempt_key <- id_key(attempts)
  estimand_key <- if (nrow(estimands)) id_key(estimands) else character()
  recomputed <- lapply(seq_len(nrow(attempts)), function(i) {
    z <- estimands[estimand_key == attempt_key[[i]], , drop = FALSE]
    if (isTRUE(attempts$finite_estimands[[i]])) {
      if (!nrow(z)) stop("Finite attempt has no estimands for truth recomputation.",
                         call. = FALSE)
      cran07_v4_assess_estimands(z)
    } else {
      if (nrow(z)) stop("Nonfinite attempt cannot retain estimands.", call. = FALSE)
      list(catastrophic_truth_error = TRUE,
           relative_covariance_error = Inf, max_eigen_ratio = Inf)
    }
  })
  catastrophic <- vapply(recomputed, `[[`, logical(1L),
                         "catastrophic_truth_error")
  relative <- vapply(recomputed, `[[`, numeric(1L),
                     "relative_covariance_error")
  eigen_ratio <- vapply(recomputed, `[[`, numeric(1L), "max_eigen_ratio")
  detector <- attempts$status != "usable"
  if (!identical(unname(attempts$catastrophic_truth_error), catastrophic) ||
      !identical(unname(as.numeric(attempts$relative_covariance_error)), relative) ||
      !identical(unname(as.numeric(attempts$max_eigen_ratio)), eigen_ratio) ||
      !identical(unname(attempts$detector_flagged), detector)) {
    stop("Stored truth-error or detector labels differ from estimand recomputation.",
         call. = FALSE)
  }
  invisible(TRUE)
}

cran07_v4_beta_pass <- function(estimands, cell) {
  z <- estimands[estimands$cell_id == cell & estimands$estimand == "beta", ]
  groups <- split(z, z$component, drop = TRUE)
  length(groups) > 0L && all(vapply(groups, function(g) {
    if (!cran07_v4_complete_component(g)) return(FALSE)
    s <- stats::sd(g$estimate)
    is.finite(s) && s > 0 && abs(mean(g$estimate - g$truth)) / s <= 0.10
  }, logical(1L)))
}

cran07_v4_matrix_bias <- function(estimands, cell, estimand, n_traits) {
  z <- estimands[estimands$cell_id == cell & estimands$estimand == estimand &
                   estimands$applicable, , drop = FALSE]
  components <- unique(z$component)
  if (length(components) != n_traits * (n_traits + 1L) / 2L) return(NA_real_)
  means <- lapply(components, function(component) {
    g <- z[z$component == component, , drop = FALSE]
    if (!cran07_v4_complete_component(g) || length(unique(g$truth)) != 1L)
      return(NULL)
    c(estimate = mean(g$estimate), truth = unique(g$truth),
      trait_i = unique(g$trait_i), trait_j = unique(g$trait_j))
  })
  if (any(vapply(means, is.null, logical(1L)))) return(NA_real_)
  means <- do.call(rbind, means)
  truth <- estimate <- matrix(0, n_traits, n_traits)
  idx <- cbind(means[, "trait_i"], means[, "trait_j"])
  truth[idx] <- means[, "truth"]; estimate[idx] <- means[, "estimate"]
  truth <- truth + t(truth) - diag(diag(truth))
  estimate <- estimate + t(estimate) - diag(diag(estimate))
  denom <- sqrt(sum(truth^2))
  if (!is.finite(denom) || denom <= 0) return(NA_real_)
  sqrt(sum((estimate - truth)^2)) / denom
}

cran07_v4_psi_pass <- function(estimands, cell, truth_profile, n_traits,
                               applicable) {
  z <- estimands[estimands$cell_id == cell & estimands$estimand == "Psi" &
                   estimands$applicable, , drop = FALSE]
  groups <- split(z, z$component, drop = TRUE)
  if (!length(groups)) return(!applicable)
  if (!applicable || length(groups) != n_traits ||
      any(z$trait_i != z$trait_j)) return(FALSE)
  all(vapply(groups, function(g) {
    if (!cran07_v4_complete_component(g) || length(unique(g$truth)) != 1L)
      return(FALSE)
    bias <- abs(mean(g$estimate - g$truth))
    if (identical(truth_profile, "psi_small")) bias <= 0.01 else
      abs(unique(g$truth)) > 0 && bias / abs(unique(g$truth)) <= 0.20
  }, logical(1L)))
}

cran07_v4_correlation_pass <- function(estimands, cell, truth_profile,
                                       n_traits, shared_applicable) {
  z <- estimands[estimands$cell_id == cell &
    estimands$estimand %in% c("correlation_total", "correlation_shared") &
    estimands$applicable, , drop = FALSE]
  groups <- split(z, interaction(z$estimand, z$component, drop = TRUE))
  expected <- n_traits * (n_traits - 1L) / 2L * (1L + as.integer(shared_applicable))
  tolerance <- if (identical(truth_profile, "rho_boundary98")) 0.15 else 0.10
  length(groups) == expected && all(vapply(groups, function(g)
    cran07_v4_complete_component(g) && length(unique(g$truth)) == 1L &&
      abs(mean(g$estimate - g$truth)) <= tolerance, logical(1L)))
}

cran07_v4_phi_pass <- function(estimands, cell, applicable, n_traits) {
  z <- estimands[estimands$cell_id == cell & estimands$estimand == "phi_nbinom2" &
                   estimands$applicable, , drop = FALSE]
  groups <- split(z, z$component, drop = TRUE)
  if (!applicable) return(!length(groups))
  length(groups) == n_traits && all(vapply(groups, function(g) {
    cran07_v4_complete_component(g) && length(unique(g$truth)) == 1L &&
      unique(g$truth) > 0 &&
      abs(mean(g$estimate - g$truth)) / unique(g$truth) <= 0.20
  }, logical(1L)))
}

cran07_v4_production_gate <- function(attempts, estimands, registry,
                                      admitted_cells, campaign_id,
                                      manifest = NULL) {
  if (is.null(manifest)) {
    stop("Production truth validation requires the canonical manifest.",
         call. = FALSE)
  }
  cran07_v4_validate_estimand_identity(
    estimands, attempts, manifest, registry, campaign_id)
  cran07_v4_validate_truth_metrics(attempts, estimands)
  x <- cran07_v3_status_counts(attempts, admitted_cells,
                               CRAN07_V4_PRODUCTION_REPS)
  x <- merge(x, cran07_detector_metrics(attempts), by = "cell_id", all.x = TRUE,
             sort = FALSE)
  x$production_complete <- x$n_attempts == 1600L & x$n_terminal == 1600L
  x$stationary_usable_pass <- x$n_stationary_usable / 1600 >= 0.95
  x$pd_hessian_pass <- x$n_pd_hessian / 1600 >= 0.90
  x$unclassified_pass <- x$n_unclassified == 0L
  x$specificity_pass <- !is.na(x$specificity_denominator) &
    (x$specificity_denominator == 0L |
       (!is.na(x$specificity) & x$specificity >= 0.90))
  x$catastrophic_but_healthy_pass <-
    !is.na(x$catastrophic_but_healthy_upper_95) &
    x$catastrophic_but_healthy_upper_95 < 0.02
  reg <- registry[match(x$cell_id, registry$cell_id), , drop = FALSE]
  schema <- cran07_v4_expected_component_schema(registry, campaign_id)
  x$component_schema_pass <- vapply(x$cell_id, cran07_v4_component_schema_pass,
    logical(1L), estimands = estimands, expected_schema = schema)
  x$beta_bias_pass <- vapply(x$cell_id, cran07_v4_beta_pass, logical(1L),
                             estimands = estimands)
  x$sigma_shared_relative_bias <- mapply(function(cell, n)
    cran07_v4_matrix_bias(estimands, cell, "Sigma_shared", n), x$cell_id,
    reg$n_traits)
  x$sigma_total_relative_bias <- mapply(function(cell, n)
    cran07_v4_matrix_bias(estimands, cell, "Sigma_total", n), x$cell_id,
    reg$n_traits)
  x$sigma_shared_bias_pass <- reg$mode == "indep" |
    (!is.na(x$sigma_shared_relative_bias) & x$sigma_shared_relative_bias <= 0.15)
  x$sigma_total_bias_pass <- !is.na(x$sigma_total_relative_bias) &
    x$sigma_total_relative_bias <= 0.15
  x$psi_bias_pass <- mapply(function(cell, profile, n, mode)
    cran07_v4_psi_pass(estimands, cell, profile, n, mode != "dep"), x$cell_id,
    reg$truth_profile, reg$n_traits, reg$mode)
  x$correlation_bias_pass <- mapply(function(cell, profile, n, mode)
    cran07_v4_correlation_pass(estimands, cell, profile, n, mode != "indep"),
    x$cell_id, reg$truth_profile, reg$n_traits, reg$mode)
  x$phi_nbinom2_bias_pass <- mapply(function(cell, family, n)
    cran07_v4_phi_pass(estimands, cell, family == "nbinom2", n), x$cell_id,
    reg$family, reg$n_traits)
  x$cell_pass <- with(x, production_complete & stationary_usable_pass &
    pd_hessian_pass & unclassified_pass & specificity_pass &
    catastrophic_but_healthy_pass & component_schema_pass & beta_bias_pass &
    sigma_shared_bias_pass & sigma_total_bias_pass & psi_bias_pass &
    correlation_bias_pass & phi_nbinom2_bias_pass)
  fenced <- x$cell_id %in% c("g_latent_n60", "nb2_latent_n100")
  x$cell_verdict <- ifelse(x$cell_pass, "PASS", "HOLD")
  x$publicly_promotable <- x$cell_pass & !fenced
  x$public_status <- ifelse(fenced, "CHARACTERIZATION_ONLY",
                            ifelse(x$cell_pass, "PASS", "HOLD"))
  x
}

CRAN07_V4_RMSE_PAIRS <- CRAN07_V3_RMSE_PAIRS

cran07_v4_bootstrap_rmse_se <- cran07_v3_bootstrap_rmse_se

cran07_v4_numerical_zero <- function(small, large) {
  cran07_v4_complete_component(small) && cran07_v4_complete_component(large) &&
    all(abs(abs(small$truth) - 1) <= CRAN07_V4_NUMERICAL_ZERO_TOL) &&
    all(abs(abs(large$truth) - 1) <= CRAN07_V4_NUMERICAL_ZERO_TOL) &&
    all(abs(small$estimate - small$truth) <= CRAN07_V4_NUMERICAL_ZERO_TOL) &&
    all(abs(large$estimate - large$truth) <= CRAN07_V4_NUMERICAL_ZERO_TOL)
}

cran07_v4_rmse_pair_gate <- function(estimands, registry,
                                      pairs = CRAN07_V4_RMSE_PAIRS,
                                      B = CRAN07_V4_RMSE_BOOT_B,
                                      seed = CRAN07_V4_RMSE_BOOT_SEED) {
  schema <- cran07_v4_expected_component_schema(registry,
                                                "cran07-core-recovery-v4")
  out <- list(); k <- 0L
  for (p in seq_len(nrow(pairs))) {
    pair <- pairs[p, , drop = FALSE]
    pair_rank <- registry$rank[match(c(pair$small_cell, pair$large_cell),
                                     registry$cell_id)]
    rank_one_pair <- length(pair_rank) == 2L && !anyNA(pair_rank) &&
      all(pair_rank == 1L)
    keys_s <- schema[schema$cell_id == pair$small_cell, ]
    keys_l <- schema[schema$cell_id == pair$large_cell, ]
    expected_s <- sort(paste(keys_s$estimand, keys_s$component, sep = "::"))
    expected_l <- sort(paste(keys_l$estimand, keys_l$component, sep = "::"))
    if (!identical(expected_s, expected_l)) {
      stop("V4 small/large component schemas differ for ", pair$pair_id, ".",
           call. = FALSE)
    }
    for (j in seq_along(expected_s)) {
      k <- k + 1L
      bits <- strsplit(expected_s[[j]], "::", fixed = TRUE)[[1L]]
      s <- estimands[estimands$cell_id == pair$small_cell & estimands$applicable &
        estimands$estimand == bits[[1L]] & estimands$component == bits[[2L]], ]
      l <- estimands[estimands$cell_id == pair$large_cell & estimands$applicable &
        estimands$estimand == bits[[1L]] & estimands$component == bits[[2L]], ]
      valid_s <- cran07_v4_complete_component(s)
      valid_l <- cran07_v4_complete_component(l)
      es <- if (valid_s) s$estimate - s$truth else numeric()
      el <- if (valid_l) l$estimate - l$truth else numeric()
      rs <- if (length(es)) sqrt(mean(es^2)) else NA_real_
      rl <- if (length(el)) sqrt(mean(el^2)) else NA_real_
      se <- cran07_v4_bootstrap_rmse_se(es, el, B,
        seed + match(pair$pair_id, CRAN07_V4_RMSE_PAIRS$pair_id) * 10000L + j)
      numerical_zero <- rank_one_pair &&
        identical(bits[[1L]], "correlation_shared") &&
        cran07_v4_numerical_zero(s, l)
      out[[k]] <- data.frame(pair_id = pair$pair_id, estimand = bits[[1L]],
        component = bits[[2L]], n_small = length(es), n_large = length(el),
        rmse_small = rs, rmse_large = rl, bootstrap_se = se,
        numerical_zero_rule = numerical_zero,
        pass = numerical_zero || (valid_s && valid_l && is.finite(se) &&
          is.finite(rs) && is.finite(rl) && rl <= rs + se),
        stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, out)
}

cran07_v4_smoke_gate <- function(attempts, estimands, manifest, registry) {
  cran07_v4_validate_attempt_table(attempts)
  cran07_v4_assert_attempt_manifest_identity(attempts, manifest)
  cells <- sort(unique(manifest$cell_id))
  counts <- table(factor(attempts$cell_id, levels = cells))
  finite_by_cell <- vapply(cells, function(cell) {
    z <- estimands[estimands$cell_id == cell & estimands$applicable, , drop = FALSE]
    nrow(z) > 0L && all(is.finite(z$estimate))
  }, logical(1L))
  binomial <- attempts$family == "binomial" & !nzchar(attempts$error_class)
  binomial_pass <- all(!binomial | (attempts$n_trials_min == 10L &
    attempts$n_trials_max == 10L & attempts$diag_B_skip == "0;0;0" &
    attempts$diag_B_all_free))
  data.frame(exact_two_per_cell = all(counts == 2L),
    all_terminal = all(attempts$status != "planned"),
    six_field_identity = TRUE, finite_output_each_cell = all(finite_by_cell),
    restart_invariants = TRUE, binomial_trial_evidence = binomial_pass,
    pass = all(counts == 2L) && all(attempts$status != "planned") &&
      all(finite_by_cell) && binomial_pass)
}
