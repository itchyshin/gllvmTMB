# Corrected v3 aggregation and preregistered gates.  Pure functions only.

CRAN07_V3_PILOT_REPS <- 20L
CRAN07_V3_PRODUCTION_REPS <- 400L
CRAN07_V3_RMSE_BOOT_B <- 2000L
CRAN07_V3_RMSE_BOOT_SEED <- 370830001L

cran07_v3_status_counts <- function(attempts, expected_cells, expected_n) {
  known_terminal <- setdiff(cran07_attempt_status_levels, "planned")
  do.call(rbind, lapply(expected_cells, function(cell) {
    z <- attempts[attempts$cell_id == cell, , drop = FALSE]
    status_known <- !is.na(z$status) & z$status %in% known_terminal
    data.frame(
      cell_id = cell,
      n_expected = expected_n,
      n_attempts = nrow(z),
      n_terminal = sum(status_known),
      n_usable = sum(z$status == "usable", na.rm = TRUE),
      n_unusable = nrow(z) - sum(z$status == "usable", na.rm = TRUE),
      n_unclassified = sum(!status_known),
      n_nonfinite_core = sum(z$status == "nonfinite" |
        (!is.na(z$finite_estimands) & !z$finite_estimands), na.rm = TRUE),
      n_stationary_usable = sum(z$status == "usable" & z$stationary, na.rm = TRUE),
      n_pd_hessian = sum(z$pd_hessian, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }))
}

cran07_v3_detector_metrics_global <- function(attempts, expected_n = NULL) {
  required <- c("catastrophic_truth_error", "detector_flagged")
  if (!all(required %in% names(attempts)) || !nrow(attempts) ||
      anyNA(attempts[required]) ||
      (!is.null(expected_n) && nrow(attempts) != expected_n)) {
    return(data.frame(
      true_positive = NA_integer_, false_negative = NA_integer_,
      false_positive = NA_integer_, true_negative = NA_integer_,
      sensitivity_denominator = NA_integer_, specificity_denominator = NA_integer_,
      sensitivity = NA_real_, specificity = NA_real_, pass = FALSE
    ))
  }
  tp <- sum(attempts$catastrophic_truth_error & attempts$detector_flagged)
  fn <- sum(attempts$catastrophic_truth_error & !attempts$detector_flagged)
  fp <- sum(!attempts$catastrophic_truth_error & attempts$detector_flagged)
  tn <- sum(!attempts$catastrophic_truth_error & !attempts$detector_flagged)
  pos <- tp + fn
  neg <- tn + fp
  sensitivity <- if (pos > 0L) tp / pos else NA_real_
  specificity <- if (neg > 0L) tn / neg else NA_real_
  data.frame(
    true_positive = tp, false_negative = fn, false_positive = fp,
    true_negative = tn, sensitivity_denominator = pos,
    specificity_denominator = neg, sensitivity = sensitivity,
    specificity = specificity,
    pass = pos > 0L && neg > 0L && is.finite(sensitivity) &&
      is.finite(specificity) && sensitivity >= 0.95 && specificity >= 0.90
  )
}

cran07_v3_pilot_global_gate <- function(attempts, expected_campaign_cells) {
  required_expected <- c("campaign_id", "cell_id")
  required_attempt <- c(required_expected, "catastrophic_truth_error",
                        "detector_flagged")
  if (!is.data.frame(expected_campaign_cells) ||
      !all(required_expected %in% names(expected_campaign_cells)) ||
      nrow(expected_campaign_cells) != 34L ||
      anyDuplicated(paste(expected_campaign_cells$campaign_id,
                          expected_campaign_cells$cell_id)) ||
      !setequal(unique(expected_campaign_cells$campaign_id),
                CRAN07_V3_CAMPAIGNS$campaign_id) ||
      !all(required_attempt %in% names(attempts))) {
    return(cran07_v3_detector_metrics_global(data.frame(), expected_n = 680L))
  }
  expected_key <- paste(expected_campaign_cells$campaign_id,
                        expected_campaign_cells$cell_id, sep = "::")
  observed_key <- paste(attempts$campaign_id, attempts$cell_id, sep = "::")
  counts <- table(factor(observed_key, levels = expected_key))
  if (length(observed_key) != 680L || any(!observed_key %in% expected_key) ||
      any(counts != 20L)) {
    return(cran07_v3_detector_metrics_global(data.frame(), expected_n = 680L))
  }
  cran07_v3_detector_metrics_global(attempts, expected_n = 680L)
}

cran07_v3_pilot_verdict <- function(attempts, expected_campaign_cells,
                                    cell_admission) {
  required <- c("campaign_id", "cell_id", "admitted")
  expected_key <- paste(expected_campaign_cells$campaign_id,
                        expected_campaign_cells$cell_id, sep = "::")
  if (!is.data.frame(cell_admission) || !all(required %in% names(cell_admission)) ||
      nrow(cell_admission) != 34L ||
      anyDuplicated(paste(cell_admission$campaign_id, cell_admission$cell_id,
                          sep = "::")) ||
      !setequal(paste(cell_admission$campaign_id, cell_admission$cell_id, sep = "::"),
                expected_key) || anyNA(cell_admission$admitted)) {
    stop("Cell-admission ledger is not a complete 34-cell pilot decision.",
         call. = FALSE)
  }
  detector <- cran07_v3_pilot_global_gate(attempts, expected_campaign_cells)
  admitted <- cell_admission[cell_admission$admitted,
    c("campaign_id", "cell_id"), drop = FALSE]
  held <- cell_admission[!cell_admission$admitted,
    c("campaign_id", "cell_id"), drop = FALSE]
  list(
    detector_global = detector,
    detector_qualified = isTRUE(detector$pass),
    admitted_cells = admitted,
    held_cells = held,
    production_authorized = isTRUE(detector$pass) && nrow(admitted) > 0L
  )
}

cran07_v3_pilot_admission <- function(attempts, expected_cells) {
  required <- c("cell_id", "status", "finite_estimands", "stationary", "pd_hessian")
  if (!all(required %in% names(attempts))) {
    stop("Pilot attempts are missing required gate columns.", call. = FALSE)
  }
  x <- cran07_v3_status_counts(attempts, expected_cells, CRAN07_V3_PILOT_REPS)
  x$complete_pass <- x$n_attempts == 20L
  x$unusable_pass <- x$n_unusable <= 3L
  x$unclassified_pass <- x$n_unclassified <= 1L
  x$nonfinite_core_pass <- x$n_nonfinite_core == 0L
  x$admitted <- with(x, complete_pass & unusable_pass & unclassified_pass &
                       nonfinite_core_pass)
  x
}

cran07_v3_validate_estimands <- function(estimands) {
  required <- c("cell_id", "replicate", "estimand", "component", "applicable",
                "truth", "estimate", "trait_i", "trait_j")
  absent <- setdiff(required, names(estimands))
  if (length(absent)) {
    stop("Estimand ledger is missing columns: ", paste(absent, collapse = ", "),
         call. = FALSE)
  }
  invisible(TRUE)
}

cran07_v3_component_groups <- function(estimands, cell, estimand) {
  z <- estimands[estimands$cell_id == cell & estimands$estimand == estimand,
                 , drop = FALSE]
  split(z, z$component, drop = TRUE)
}

cran07_v3_complete_component <- function(z, expected_n = CRAN07_V3_PRODUCTION_REPS) {
  nrow(z) == expected_n && !anyDuplicated(z$replicate) &&
    identical(sort(as.integer(z$replicate)), seq_len(expected_n)) &&
    all(z$applicable) && all(is.finite(z$estimate)) && all(is.finite(z$truth))
}

cran07_v3_expected_beta_components <- function(cell) {
  n <- as.integer(cell$n_traits)
  n_unit <- max(3L, as.integer(cell$n_unit))
  dat <- expand.grid(rep = 1L, trait_idx = seq_len(n),
                     unit_idx = seq_len(n_unit), KEEP.OUT.ATTRS = FALSE)
  dat$trait <- factor(paste0("t", dat$trait_idx),
                      levels = paste0("t", seq_len(n)))
  dat$x <- as.numeric(scale(seq_len(n_unit)))[dat$unit_idx]
  scenario <- if ("scenario" %in% names(cell)) as.character(cell$scenario) else
    "ordinary"
  if (identical(scenario, "rare_level")) {
    habitat <- rep(c("common_a", "common_b", "rare"), length.out = n_unit)
    dat$habitat <- factor(habitat[dat$unit_idx],
                          levels = c("common_a", "common_b", "rare"))
    fixed <- ~ 0 + trait + trait:x + trait:habitat
  } else fixed <- ~ 0 + trait + trait:x
  colnames(stats::model.matrix(fixed, dat))
}

cran07_v3_expected_component_schema <- function(registry, campaign_id) {
  cran07_v3_campaign_spec(campaign_id)
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    cell <- registry[i, , drop = FALSE]
    n <- as.integer(cell$n_traits)
    lower <- which(lower.tri(matrix(0, n, n), diag = TRUE), arr.ind = TRUE)
    off <- which(lower.tri(matrix(0, n, n)), arr.ind = TRUE)
    matrix_components <- paste0("t", lower[, 1L], "_t", lower[, 2L])
    correlation_components <- paste0("t", off[, 1L], "_t", off[, 2L])
    mode <- as.character(cell$mode)
    pieces <- list(
      data.frame(estimand = "beta",
                 component = cran07_v3_expected_beta_components(cell)),
      if (mode != "indep") data.frame(estimand = "Sigma_shared",
                                       component = matrix_components),
      if (mode != "dep") data.frame(estimand = "Psi",
                                     component = paste0("t", seq_len(n), "_t", seq_len(n))),
      data.frame(estimand = "Sigma_total", component = matrix_components),
      data.frame(estimand = "correlation_total", component = correlation_components),
      if (mode != "indep") data.frame(estimand = "correlation_shared",
                                       component = correlation_components)
    )
    ans <- do.call(rbind, pieces)
    ans$cell_id <- as.character(cell$cell_id)
    ans[, c("cell_id", "estimand", "component")]
  })
  ans <- do.call(rbind, rows)
  rownames(ans) <- NULL
  if (anyDuplicated(paste(ans$cell_id, ans$estimand, ans$component, sep = "::"))) {
    stop("Frozen expected component schema contains duplicate keys.", call. = FALSE)
  }
  ans
}

cran07_v3_component_schema_pass <- function(estimands, cell, expected_schema) {
  expected <- expected_schema[expected_schema$cell_id == cell, , drop = FALSE]
  observed <- estimands[estimands$cell_id == cell & estimands$applicable,
                        c("estimand", "component"), drop = FALSE]
  expected_key <- sort(unique(paste(expected$estimand, expected$component, sep = "::")))
  observed_key <- sort(unique(paste(observed$estimand, observed$component, sep = "::")))
  length(expected_key) > 0L && identical(observed_key, expected_key)
}

cran07_v3_beta_pass <- function(estimands, cell) {
  groups <- cran07_v3_component_groups(estimands, cell, "beta")
  if (!length(groups)) return(FALSE)
  all(vapply(groups, function(z) {
    if (!cran07_v3_complete_component(z)) return(FALSE)
    sd_est <- stats::sd(z$estimate)
    is.finite(sd_est) && sd_est > 0 &&
      abs(mean(z$estimate - z$truth)) / sd_est <= 0.10
  }, logical(1L)))
}

cran07_v3_matrix_bias <- function(estimands, cell, estimand,
                                  expected_n_traits = NULL) {
  z <- estimands[estimands$cell_id == cell & estimands$estimand == estimand &
                  estimands$applicable, , drop = FALSE]
  if (!nrow(z)) return(NA_real_)
  components <- unique(z$component)
  if (!is.null(expected_n_traits) &&
      length(components) != expected_n_traits * (expected_n_traits + 1L) / 2L) {
    return(NA_real_)
  }
  means <- lapply(components, function(component) {
    g <- z[z$component == component, , drop = FALSE]
    if (!cran07_v3_complete_component(g) || length(unique(g$truth)) != 1L)
      return(NULL)
    c(estimate = mean(g$estimate), truth = unique(g$truth),
      trait_i = unique(g$trait_i), trait_j = unique(g$trait_j))
  })
  if (any(vapply(means, is.null, logical(1L)))) return(NA_real_)
  means <- do.call(rbind, means)
  if (any(!is.finite(means[, c("trait_i", "trait_j")]))) return(NA_real_)
  n_trait <- max(means[, c("trait_i", "trait_j")])
  truth <- estimate <- matrix(0, n_trait, n_trait)
  idx <- cbind(means[, "trait_i"], means[, "trait_j"])
  truth[idx] <- means[, "truth"]
  estimate[idx] <- means[, "estimate"]
  truth <- truth + t(truth) - diag(diag(truth))
  estimate <- estimate + t(estimate) - diag(diag(estimate))
  denom <- sqrt(sum(truth^2))
  if (!is.finite(denom) || denom <= 0) return(NA_real_)
  sqrt(sum((estimate - truth)^2)) / denom
}

cran07_v3_psi_pass <- function(estimands, cell, truth_profile,
                               expected_n_traits = NULL,
                               psi_applicable = TRUE) {
  z <- estimands[estimands$cell_id == cell & estimands$estimand == "Psi" &
                  estimands$applicable & estimands$trait_i == estimands$trait_j, , drop = FALSE]
  groups <- split(z, z$component, drop = TRUE)
  if (!length(groups)) return(!psi_applicable)
  if (!psi_applicable) return(FALSE)
  if (!is.null(expected_n_traits) && length(groups) != expected_n_traits) return(FALSE)
  all(vapply(groups, function(g) {
    if (!cran07_v3_complete_component(g) || length(unique(g$truth)) != 1L)
      return(FALSE)
    bias <- abs(mean(g$estimate - g$truth))
    if (identical(truth_profile, "psi_small")) bias <= 0.01 else
      abs(unique(g$truth)) > 0 && bias / abs(unique(g$truth)) <= 0.20
  }, logical(1L)))
}

cran07_v3_correlation_pass <- function(estimands, cell, truth_profile,
                                       expected_n_traits = NULL,
                                       shared_applicable = TRUE) {
  z <- estimands[estimands$cell_id == cell &
                  estimands$estimand %in% c("correlation_total", "correlation_shared") &
                  estimands$applicable, , drop = FALSE]
  groups <- split(z, interaction(z$estimand, z$component, drop = TRUE))
  if (!length(groups)) return(FALSE)
  if (!is.null(expected_n_traits)) {
    per_matrix <- expected_n_traits * (expected_n_traits - 1L) / 2L
    expected <- per_matrix * (1L + as.integer(shared_applicable))
    if (length(groups) != expected) return(FALSE)
  }
  tolerance <- if (identical(truth_profile, "rho_boundary98")) 0.15 else 0.10
  all(vapply(groups, function(g) {
    cran07_v3_complete_component(g) && length(unique(g$truth)) == 1L &&
      abs(mean(g$estimate - g$truth)) <= tolerance
  }, logical(1L)))
}

cran07_v3_production_gate <- function(attempts, estimands, registry,
                                      admitted_cells, campaign_id = NULL) {
  cran07_v3_validate_estimands(estimands)
  x <- cran07_v3_status_counts(attempts, admitted_cells,
                               CRAN07_V3_PRODUCTION_REPS)
  detector <- cran07_detector_metrics(attempts)
  x <- merge(x, detector, by = "cell_id", all.x = TRUE, sort = FALSE)
  x$production_complete <- x$n_attempts == 400L & x$n_terminal == 400L
  x$stationary_usable_pass <- x$n_stationary_usable / 400 >= 0.95
  x$pd_hessian_pass <- x$n_pd_hessian / 400 >= 0.90
  x$unclassified_pass <- x$n_unclassified == 0L
  x$specificity_pass <- !is.na(x$specificity_denominator) &
    (x$specificity_denominator == 0L |
       (!is.na(x$specificity) & x$specificity >= 0.90))
  x$catastrophic_but_healthy_pass <-
    !is.na(x$catastrophic_but_healthy_upper_95) &
    x$catastrophic_but_healthy_upper_95 < 0.02
  x$beta_bias_pass <- vapply(x$cell_id, function(cell)
    cran07_v3_beta_pass(estimands, cell), logical(1L))
  x$sigma_shared_relative_bias <- vapply(x$cell_id, function(cell)
    cran07_v3_matrix_bias(estimands, cell, "Sigma_shared",
      registry$n_traits[match(cell, registry$cell_id)]), numeric(1L))
  x$sigma_total_relative_bias <- vapply(x$cell_id, function(cell)
    cran07_v3_matrix_bias(estimands, cell, "Sigma_total",
      registry$n_traits[match(cell, registry$cell_id)]), numeric(1L))
  reg <- registry[match(x$cell_id, registry$cell_id), , drop = FALSE]
  if (is.null(campaign_id)) campaign_id <- attr(registry, "campaign_id")
  if (is.null(campaign_id) || length(campaign_id) != 1L) {
    stop("Production gate requires the frozen v3 campaign identity.", call. = FALSE)
  }
  expected_schema <- cran07_v3_expected_component_schema(registry, campaign_id)
  x$component_schema_pass <- vapply(x$cell_id, function(cell)
    cran07_v3_component_schema_pass(estimands, cell, expected_schema), logical(1L))
  x$sigma_shared_bias_pass <- reg$mode == "indep" |
    (!is.na(x$sigma_shared_relative_bias) & x$sigma_shared_relative_bias <= 0.15)
  x$sigma_total_bias_pass <- !is.na(x$sigma_total_relative_bias) &
    x$sigma_total_relative_bias <= 0.15
  x$psi_bias_pass <- mapply(cran07_v3_psi_pass,
    cell = x$cell_id, truth_profile = reg$truth_profile,
    expected_n_traits = reg$n_traits, psi_applicable = reg$mode != "dep",
    MoreArgs = list(estimands = estimands))
  x$correlation_bias_pass <- mapply(
    cran07_v3_correlation_pass, cell = x$cell_id,
    truth_profile = reg$truth_profile, expected_n_traits = reg$n_traits,
    shared_applicable = reg$mode != "indep",
    MoreArgs = list(estimands = estimands))
  x$cell_pass <- with(x, production_complete & stationary_usable_pass &
    pd_hessian_pass & unclassified_pass & specificity_pass &
    catastrophic_but_healthy_pass & beta_bias_pass &
    component_schema_pass &
    sigma_shared_bias_pass & sigma_total_bias_pass & psi_bias_pass &
    correlation_bias_pass)
  x
}

CRAN07_V3_RMSE_PAIRS <- data.frame(
  pair_id = c("indep", "dep", "gaussian_latent", "poisson_latent",
              "nb2_latent", "binomial_latent"),
  small_cell = c("g_indep_n60", "g_dep_n60", "g_latent_n60",
                 "p_latent_n100", "nb2_latent_n100", "b_logit_latent_n100"),
  large_cell = c("g_indep_n240", "g_dep_n240", "g_latent_n240",
                 "p_latent_n300", "nb2_latent_n300", "b_logit_latent_n300"),
  stringsAsFactors = FALSE
)

cran07_v3_bootstrap_rmse_se <- function(error_small, error_large, B, seed) {
  if (length(error_small) < 2L || length(error_large) < 2L ||
      any(!is.finite(error_small)) || any(!is.finite(error_large)) ||
      B < 2L) return(NA_real_)
  old <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
    get(".Random.seed", envir = .GlobalEnv) else NULL
  on.exit({
    if (is.null(old)) {
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
        rm(".Random.seed", envir = .GlobalEnv)
    } else assign(".Random.seed", old, envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(seed)
  delta <- vapply(seq_len(B), function(i) {
    small <- sample(error_small, length(error_small), replace = TRUE)
    large <- sample(error_large, length(error_large), replace = TRUE)
    sqrt(mean(large^2)) - sqrt(mean(small^2))
  }, numeric(1L))
  stats::sd(delta)
}

cran07_v3_rmse_pair_gate <- function(estimands,
                                      registry,
                                      pairs = CRAN07_V3_RMSE_PAIRS,
                                      B = CRAN07_V3_RMSE_BOOT_B,
                                      seed = CRAN07_V3_RMSE_BOOT_SEED) {
  cran07_v3_validate_estimands(estimands)
  if (!is.data.frame(pairs) || !all(c("pair_id", "small_cell", "large_cell") %in%
                                    names(pairs)) ||
      any(!pairs$pair_id %in% CRAN07_V3_RMSE_PAIRS$pair_id)) {
    stop("RMSE pair selection is not a frozen v3 pair subset.", call. = FALSE)
  }
  expected_schema <- cran07_v3_expected_component_schema(
    registry, "cran07-core-recovery-v3")
  out <- list()
  k <- 0L
  for (p in seq_len(nrow(pairs))) {
    pair <- pairs[p, ]
    frozen_pair_number <- match(pair$pair_id, CRAN07_V3_RMSE_PAIRS$pair_id)
    small <- estimands[estimands$cell_id == pair$small_cell & estimands$applicable,
                       , drop = FALSE]
    large <- estimands[estimands$cell_id == pair$large_cell & estimands$applicable,
                       , drop = FALSE]
    expected_small <- expected_schema[expected_schema$cell_id == pair$small_cell, ]
    expected_large <- expected_schema[expected_schema$cell_id == pair$large_cell, ]
    expected_small_key <- sort(paste(expected_small$estimand,
                                     expected_small$component, sep = "::"))
    expected_large_key <- sort(paste(expected_large$estimand,
                                     expected_large$component, sep = "::"))
    if (!identical(expected_small_key, expected_large_key)) {
      stop("Frozen small/large component schemas differ for pair ", pair$pair_id,
           ".", call. = FALSE)
    }
    observed_keys <- sort(unique(c(
      paste(small$estimand, small$component, sep = "::"),
      paste(large$estimand, large$component, sep = "::"))))
    keys <- sort(unique(c(expected_small_key, observed_keys)))
    if (!length(keys)) stop("Frozen RMSE schema is empty for pair ", pair$pair_id,
                            ".", call. = FALSE)
    for (key in keys) {
      k <- k + 1L
      bits <- strsplit(key, "::", fixed = TRUE)[[1L]]
      s <- small[small$estimand == bits[[1L]] & small$component == bits[[2L]],
                 , drop = FALSE]
      l <- large[large$estimand == bits[[1L]] & large$component == bits[[2L]],
                 , drop = FALSE]
      valid_s <- cran07_v3_complete_component(s)
      valid_l <- cran07_v3_complete_component(l)
      es <- if (valid_s) s$estimate - s$truth else numeric()
      el <- if (valid_l) l$estimate - l$truth else numeric()
      component_seed <- seed + frozen_pair_number * 10000L + match(key, keys)
      se <- cran07_v3_bootstrap_rmse_se(es, el, B, component_seed)
      rs <- if (length(es)) sqrt(mean(es^2)) else NA_real_
      rl <- if (length(el)) sqrt(mean(el^2)) else NA_real_
      out[[k]] <- data.frame(pair_id = pair$pair_id, estimand = bits[[1L]],
        component = bits[[2L]], n_small = length(es), n_large = length(el),
        rmse_small = rs, rmse_large = rl, bootstrap_se = se,
        expected_component = key %in% expected_small_key,
        pass = key %in% expected_small_key && valid_s && valid_l && is.finite(se) &&
          is.finite(rs) && is.finite(rl) && rl <= rs + se)
    }
  }
  ans <- do.call(rbind, out)
  rownames(ans) <- NULL
  ans
}

cran07_v3_campaign_production_evidence <- function(summary, pilot_gate, registry,
                                                    campaign_id) {
  admitted <- pilot_gate$admitted_cells
  held <- pilot_gate$held_cells
  admitted_cells <- if (is.data.frame(admitted)) sort(unique(admitted$cell_id[
    admitted$campaign_id == campaign_id])) else character()
  held_cells <- if (is.data.frame(held)) sort(unique(held$cell_id[
    held$campaign_id == campaign_id])) else character()
  base <- list(campaign_id = campaign_id, admitted_cells = admitted_cells,
               held_pilot_cells = held_cells, valid = FALSE,
               reason = "summary_absent", cell_gate = data.frame())
  if (is.null(summary)) return(base)
  identity <- summary$v3_identity
  required_identity <- c("campaign_id", "stage", "registry_sha256",
                         "manifest_sha256",
                         "expected_cells", "expected_attempts",
                         "observed_attempts", "complete")
  spec <- cran07_v3_campaign_spec(campaign_id)
  if (is.null(identity) || !all(required_identity %in% names(identity)) ||
      !identical(identity$campaign_id, campaign_id) ||
      !identical(identity$stage, "production") || !isTRUE(identity$complete) ||
      !identical(identity$registry_sha256, spec$registry_sha256) ||
      length(identity$manifest_sha256) != 1L ||
      is.na(identity$manifest_sha256) ||
      !grepl("^[0-9a-f]{64}$", identity$manifest_sha256) ||
      !identical(identity$expected_attempts, identity$observed_attempts) ||
      !identical(identity$expected_attempts,
                 as.integer(length(identity$expected_cells) * 400L))) {
    base$reason <- "summary_identity_invalid"
    return(base)
  }
  if (!isTRUE(pilot_gate$production_authorized) || !length(admitted_cells) ||
      !identical(sort(identity$expected_cells), admitted_cells) ||
      any(!admitted_cells %in% registry$cell_id)) {
    base$reason <- "production_set_differs_from_pilot_admission"
    return(base)
  }
  cell_gate <- summary$v3_gate
  if (!is.data.frame(cell_gate) ||
      !setequal(cell_gate$cell_id, admitted_cells) || anyDuplicated(cell_gate$cell_id) ||
      !all(c("cell_pass", "component_schema_pass") %in% names(cell_gate)) ||
      any(!cell_gate$component_schema_pass)) {
    base$reason <- "cell_gate_identity_invalid"
    return(base)
  }
  base$valid <- TRUE
  base$reason <- if (all(cell_gate$cell_pass)) "all_admitted_cells_pass" else
    "one_or_more_admitted_cells_failed"
  base$cell_gate <- cell_gate
  base
}

cran07_v3_production_closeout <- function(core_summary, silent_summary,
                                          robustness_summary, pilot_gate,
                                          registries,
                                          B = CRAN07_V3_RMSE_BOOT_B,
                                          seed = CRAN07_V3_RMSE_BOOT_SEED) {
  ids <- CRAN07_V3_CAMPAIGNS$campaign_id
  summaries <- list(core_summary, silent_summary, robustness_summary)
  if (!is.list(registries) || !all(ids %in% names(registries)) ||
      !isTRUE(pilot_gate$production_authorized)) {
    stop("Broad closeout requires all three registries and an authorised pilot receipt.",
         call. = FALSE)
  }
  evidence <- lapply(seq_along(ids), function(i)
    cran07_v3_campaign_production_evidence(
      summaries[[i]], pilot_gate, registries[[ids[[i]]]], ids[[i]]))
  names(evidence) <- ids
  core <- evidence[["cran07-core-recovery-v3"]]
  admitted_core <- core$admitted_cells
  eligible <- CRAN07_V3_RMSE_PAIRS[
    CRAN07_V3_RMSE_PAIRS$small_cell %in% admitted_core &
      CRAN07_V3_RMSE_PAIRS$large_cell %in% admitted_core, , drop = FALSE]
  rmse <- if (isTRUE(core$valid) && nrow(eligible))
    cran07_v3_rmse_pair_gate(core_summary$estimands,
      registry = registries[["cran07-core-recovery-v3"]], pairs = eligible,
      B = B, seed = seed) else data.frame()
  pair_rows <- lapply(seq_len(nrow(CRAN07_V3_RMSE_PAIRS)), function(i) {
    pair <- CRAN07_V3_RMSE_PAIRS[i, ]
    small_in <- pair$small_cell %in% admitted_core
    large_in <- pair$large_cell %in% admitted_core
    both <- small_in && large_in
    z <- rmse[rmse$pair_id == pair$pair_id, , drop = FALSE]
    components_pass <- both && nrow(z) > 0L && all(z$pass)
    cell_pass <- isTRUE(core$valid) && both && all(core$cell_gate$cell_pass[
      match(c(pair$small_cell, pair$large_cell), core$cell_gate$cell_id)])
    data.frame(
      pair_id = pair$pair_id, small_cell = pair$small_cell,
      large_cell = pair$large_cell, small_admitted = small_in,
      large_admitted = large_in,
      verdict = if (components_pass && cell_pass) "PASS" else "HOLD",
      reason = if (!both) "one_or_both_pair_cells_not_admitted" else
        if (!cell_pass) "production_cell_gate_failed" else
          if (!components_pass) "rmse_component_gate_failed" else "all_gates_pass",
      stringsAsFactors = FALSE
    )
  })
  pair_gate <- do.call(rbind, pair_rows)
  campaign_gate <- do.call(rbind, lapply(evidence, function(x) data.frame(
    campaign_id = x$campaign_id, admitted_n = length(x$admitted_cells),
    held_pilot_n = length(x$held_pilot_cells), valid = x$valid,
    all_admitted_cells_pass = x$valid && nrow(x$cell_gate) > 0L &&
      all(x$cell_gate$cell_pass), reason = x$reason, stringsAsFactors = FALSE)))
  release_verdict <- if (all(campaign_gate$all_admitted_cells_pass) &&
                           all(pair_gate$verdict == "PASS")) "PASS" else "HOLD"
  list(
    campaign_evidence = evidence,
    campaign_gate = campaign_gate,
    admitted_cells = pilot_gate$admitted_cells,
    held_pilot_cells = pilot_gate$held_cells,
    rmse_component_gate = rmse,
    family_pair_gate = pair_gate,
    release_verdict = release_verdict
  )
}

cran07_v3_assert_attempt_manifest_identity <- function(attempts, manifest, registry) {
  identity_columns <- c("campaign_id", "registry_sha256", "cell_number",
                        "cell_id", "replicate", "seed")
  attempt_required <- setdiff(identity_columns, "cell_number")
  if (!all(attempt_required %in% names(attempts)) ||
      !all(identity_columns %in% names(manifest))) {
    stop("Attempt or manifest identity columns are incomplete.", call. = FALSE)
  }
  observed_identity <- attempts[, attempt_required, drop = FALSE]
  cell_number <- stats::setNames(registry$cell_number, registry$cell_id)
  observed_identity$cell_number <- unname(cell_number[observed_identity$cell_id])
  observed_identity <- observed_identity[, identity_columns, drop = FALSE]
  expected_identity <- manifest[, identity_columns, drop = FALSE]
  order_identity <- function(x) x[order(x$campaign_id, x$registry_sha256,
    x$cell_number, x$cell_id, x$replicate, x$seed), , drop = FALSE]
  observed_identity <- order_identity(observed_identity)
  expected_identity <- order_identity(expected_identity)
  rownames(observed_identity) <- rownames(expected_identity) <- NULL
  if (!identical(observed_identity, expected_identity)) {
    stop("Attempt output is not a full-identity bijection with the frozen manifest.",
         call. = FALSE)
  }
  invisible(TRUE)
}

cran07_v3_summary <- function(output_dir, manifest, registry, campaign_id,
                              stage = c("pilot", "production"),
                              admitted_cells = NULL) {
  stage <- match.arg(stage)
  expected_cells <- if (stage == "pilot") registry$cell_id else admitted_cells
  cran07_v3_validate_manifest(manifest, registry, campaign_id, stage, expected_cells)
  summary <- cran07_summarize(output_dir, manifest)
  if (length(summary$missing_attempt_keys)) {
    stop("Saved summary is incomplete relative to the full frozen manifest.",
         call. = FALSE)
  }
  cran07_v3_assert_attempt_manifest_identity(summary$attempts, manifest, registry)
  summary$v3_identity <- list(
    campaign_id = campaign_id,
    stage = stage,
    registry_sha256 = attr(registry, "sha256"),
    manifest_sha256 = cran07_v3_manifest_sha256(manifest),
    expected_cells = sort(expected_cells),
    expected_attempts = nrow(manifest),
    observed_attempts = nrow(summary$attempts),
    complete = TRUE
  )
  summary$v3_gate <- if (stage == "pilot")
    cran07_v3_pilot_admission(summary$attempts, expected_cells) else
      cran07_v3_production_gate(summary$attempts, summary$estimands,
                                registry, expected_cells)
  summary
}
