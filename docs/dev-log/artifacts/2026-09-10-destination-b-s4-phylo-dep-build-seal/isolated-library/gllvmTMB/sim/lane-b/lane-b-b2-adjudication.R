# Strict post-launch adjudication for the frozen Lane B B2 campaign.
#
# The fit campaign is immutable.  This layer replaces its unavailable B0 hash
# with an independently regenerated exact certificate and applies the frozen
# gates within realized separation strata.  Every stratum gate is conjoined
# with the immutable cell-level v1 gate: this layer can only withhold.

lane_b_adjudication_thresholds <- function() c(
  lane_b_thresholds(), list(realized_stratum_minimum = 300L)
)

lane_b_b0_stratum <- function(registry) {
  required <- c("b0_has_complete", "b0_has_quasi_complete", "b0_has_constant",
                "b0_all_overlap", "b0_not_checked")
  if (!all(required %in% names(registry)))
    stop("The exact B0 registry lacks required status columns.")
  ifelse(registry$b0_not_checked %in% TRUE, "NOT_CHECKED",
    ifelse(registry$b0_has_constant %in% TRUE, "CONSTANT",
      ifelse(registry$b0_has_complete %in% TRUE, "COMPLETE",
        ifelse(registry$b0_has_quasi_complete %in% TRUE, "QUASI_COMPLETE",
          ifelse(registry$b0_all_overlap %in% TRUE, "OVERLAP", "NOT_CHECKED")))))
}

lane_b_b0_source_receipt <- function() {
  d <- lane_b_harness_dir()
  files <- c("lane-b-b2-common.R", "lane-b-b2-runner.R",
             "3_run_lane_b_b0_shard.R",
             "lane-b-b0-totoro-launch-v3.sh")
  setNames(vapply(file.path(d, files), lane_b_sha256_file, character(1L)), files)
}

lane_b_b0_frozen_source_receipt <- function(version = "v3") {
  if (!identical(version, "v3")) {
    stop("No immutable B0 source receipt is registered for version ", version, ".")
  }
  c(
    "lane-b-b2-common.R" =
      "72e294d40f0fa32a57d6ca0af04a4afd7f39dc28770872fb5b20882f714df051",
    "lane-b-b2-runner.R" =
      "155ed5e0ec02096501ffbc2c2980517a9c2e97aae26dc75bdedee4cbe1baee8e",
    "3_run_lane_b_b0_shard.R" =
      "4cbc571e505b6ddfc0f70b79b3569eff56b1acde90c300b44ac4a8df0523dd7d",
    "lane-b-b0-totoro-launch-v3.sh" =
      "fb2acd7844518a9f31e8c7efdb6ab79de6bd966c8983abcc1c7f38f1774a5335"
  )
}

lane_b_validate_b0_source_receipt <- function(observed, version = "v3") {
  expected <- lane_b_b0_frozen_source_receipt(version)
  if (!identical(observed, expected)) {
    stop("Exact B0 source receipt does not match the immutable ", version,
         " launch source receipt.")
  }
  invisible(TRUE)
}

lane_b_validate_b0_boolean_hash <- function(registry) {
  parsed <- strsplit(registry$b0_status_hash_exact, ";", fixed = TRUE)
  same <- function(observed, expected) identical(as.logical(observed), as.logical(expected))
  checks <- c(
    same(registry$b0_has_complete, vapply(parsed, function(x) any(x == "COMPLETE"), logical(1L))),
    same(registry$b0_has_quasi_complete,
         vapply(parsed, function(x) any(x == "QUASI_COMPLETE"), logical(1L))),
    same(registry$b0_has_constant, vapply(parsed, function(x) any(x == "CONSTANT"), logical(1L))),
    same(registry$b0_all_overlap, vapply(parsed, function(x) all(x == "OVERLAP"), logical(1L))),
    same(registry$b0_not_checked,
         vapply(parsed, function(x) any(x %in% c("NOT_CHECKED", "RANK_DEFICIENT")), logical(1L)))
  )
  if (!all(checks)) stop("Exact B0 boolean flags disagree with the stored status hashes.")
  invisible(TRUE)
}

lane_b_read_exact_b0_registry <- function(root, version = "v3",
                                          manifest = lane_b_ordinary_manifest()) {
  root <- lane_b_validate_campaign_root(root)
  directory <- file.path(root, paste0("b0-exact-", version))
  receipt_path <- file.path(root, "session", paste0("b0-exact-receipt-", version, ".rds"))
  if (!file.exists(receipt_path)) stop("Exact B0 completion/provenance receipt is missing.")
  receipt <- readRDS(receipt_path)
  files <- list.files(directory, pattern = "^ordinary-.*\\.rds$", full.names = TRUE)
  expected_shards <- sum(vapply(manifest$n_rep,
                                function(n) as.integer(ceiling(n / 25)),
                                integer(1L)))
  if (length(files) != expected_shards) {
    stop("Exact B0 registry is incomplete: found ", length(files),
         " of ", expected_shards, " ordinary shards.")
  }
  required_receipt <- c("complete", "expected_shards", "observed_shards",
                        "manifest_version", "detector_version", "source_sha256",
                        "registry_sha256")
  receipt_ok <- all(required_receipt %in% names(receipt)) &&
    isTRUE(receipt$complete) &&
    isTRUE(receipt$expected_shards == expected_shards) &&
    isTRUE(receipt$observed_shards == expected_shards) &&
    identical(receipt$manifest_version, lane_b_manifest_version()) &&
    utils::compareVersion(as.character(receipt$detector_version), "0.4.0") >= 0L &&
    identical(receipt$registry_sha256,
              setNames(vapply(files, lane_b_sha256_file, character(1L)),
                       basename(files)))
  if (!receipt_ok) {
    stop("Exact B0 completion/provenance receipt does not match this adjudicator.")
  }
  lane_b_validate_b0_source_receipt(receipt$source_sha256, version)
  registry <- do.call(rbind, lapply(files, readRDS))
  key <- paste(registry$cell_id, registry$replicate_id, sep = ":")
  expected_rows <- sum(manifest$n_rep)
  if (nrow(registry) != expected_rows || anyDuplicated(key)) {
    stop("Exact B0 registry must contain one unique row per ordinary dataset.")
  }
  expected_key <- unlist(lapply(seq_len(nrow(manifest)), function(i)
    paste(manifest$cell_id[[i]], seq_len(manifest$n_rep[[i]]), sep = ":")),
    use.names = FALSE)
  if (!setequal(key, expected_key))
    stop("Exact B0 registry keys do not match the frozen ordinary manifest.")
  if (!all(registry$manifest_version == lane_b_manifest_version()))
    stop("Exact B0 registry manifest version is inconsistent.")
  lane_b_validate_b0_boolean_hash(registry)
  registry$b0_stratum <- lane_b_b0_stratum(registry)
  registry
}

lane_b_validate_attempt_ledger <- function(attempts, registry) {
  required <- c("cell_id", "replicate_id", "arm", "start_role", "table")
  if (!all(required %in% names(attempts))) stop("Attempt ledger lacks frozen key columns.")
  z <- attempts[attempts$table == "ordinary", , drop = FALSE]
  expected <- merge(
    registry[c("cell_id", "replicate_id")],
    expand.grid(arm = lane_b_arms()$arm_id,
                start_role = c("primary", "alternate"), stringsAsFactors = FALSE),
    by = NULL
  )
  key <- function(x) paste(x$cell_id, x$replicate_id, x$arm, x$start_role, sep = ":")
  observed_key <- key(z); expected_key <- key(expected)
  if (nrow(z) != nrow(expected) || anyDuplicated(observed_key) ||
      !setequal(observed_key, expected_key)) {
    stop("Ordinary attempt ledger is not exactly registry x four arms x two starts.")
  }
  invisible(TRUE)
}

lane_b_attach_exact_b0 <- function(attempts, registry) {
  required <- c("cell_id", "replicate_id", "arm", "usable")
  if (!all(required %in% names(attempts)))
    stop("Attempt table lacks columns required for exact-B0 adjudication.")
  keep <- c("cell_id", "replicate_id", "b0_status_hash_exact", "b0_stratum")
  out <- merge(attempts, registry[, keep, drop = FALSE],
               by = c("cell_id", "replicate_id"), all.x = TRUE, sort = FALSE)
  ordinary <- out$table %in% "ordinary"
  if (any(ordinary & is.na(out$b0_stratum)))
    stop("Some ordinary attempts lack an exact B0 certificate.")
  out
}

lane_b_relative_sigma_gap <- function(primary, alternate) {
  unpack <- function(x) {
    if (length(x) != 1L || is.na(x) || !nzchar(x)) return(numeric())
    lane_b_unpack_numeric(x)
  }
  a <- unpack(primary)
  b <- unpack(alternate)
  if (!length(a) || length(a) != length(b) ||
      any(!is.finite(a)) || any(!is.finite(b))) return(Inf)
  sqrt(sum((b - a)^2)) / max(1, sqrt(sum(a^2)))
}

lane_b_recompute_relative_multistart <- function(attempts) {
  required <- c("cell_id", "replicate_id", "arm", "start_role",
                "sigma_vector", "alternate_covariance_gap")
  if (!all(required %in% names(attempts)))
    stop("Attempt ledger lacks covariance vectors required for strict multistart.")
  key <- function(x)
    paste(x$cell_id, x$replicate_id, x$arm, sep = ":")
  primary <- attempts[attempts$start_role == "primary", , drop = FALSE]
  alternate <- attempts[attempts$start_role == "alternate", , drop = FALSE]
  primary_key <- key(primary)
  alternate_key <- key(alternate)
  if (anyDuplicated(primary_key) || anyDuplicated(alternate_key) ||
      !setequal(primary_key, alternate_key)) {
    stop("Primary and alternate multistart rows do not form an exact pairing.")
  }
  alternate <- alternate[match(primary_key, alternate_key), , drop = FALSE]
  gap <- mapply(lane_b_relative_sigma_gap, primary$sigma_vector,
                alternate$sigma_vector)
  gap_by_key <- setNames(gap, primary_key)
  attempts$alternate_covariance_gap <- unname(gap_by_key[key(attempts)])
  if (anyNA(attempts$alternate_covariance_gap))
    stop("Some multistart covariance gaps could not be reconstructed.")
  attempts
}

lane_b_adjudication_pair <- function(z, arm_a, arm_b) {
  columns <- c("replicate_id", "usable", "beta_squared_error",
               "covariance_squared_error", "log_loss", "sigma_rank",
               "expected_sigma_rank")
  aa <- z[z$arm == arm_a, columns, drop = FALSE]
  bb <- z[z$arm == arm_b, columns, drop = FALSE]
  names(aa)[-1L] <- paste0(names(aa)[-1L], "_a")
  names(bb)[-1L] <- paste0(names(bb)[-1L], "_b")
  merge(aa, bb, by = "replicate_id", all = FALSE)
}

lane_b_adjudication_metric_pair <- function(pair, metric) {
  z <- pair[pair$usable_a %in% TRUE & pair$usable_b %in% TRUE, , drop = FALSE]
  columns <- paste0(metric, c("_a", "_b"))
  complete <- if (nrow(z)) apply(z[columns], 1L, function(x) all(is.finite(x))) else logical()
  list(rows = z[complete, , drop = FALSE], mutually_usable = nrow(z), complete = sum(complete))
}

lane_b_ratio_stat <- function(d, metric) {
  a <- mean(d[[paste0(metric, "_a")]])
  b <- mean(d[[paste0(metric, "_b")]])
  if (b == 0) return(if (a == 0) 1 else Inf)
  sqrt(a / b)
}

lane_b_boot_pair_stat_strict <- function(x, statistic, B, seed_key) {
  if (!nrow(x)) return(c(estimate = NA, lower = NA, upper = NA))
  streams <- lane_b_substreams(seed_key)
  estimate <- statistic(x)
  boot <- lane_b_with_state(streams[[1L]], replicate(B, {
    statistic(x[sample.int(nrow(x), replace = TRUE), , drop = FALSE])
  }))
  if (any(is.na(boot))) return(c(estimate = estimate, lower = NA, upper = NA))
  c(estimate = estimate,
    lower = unname(quantile(boot, 0.025, type = 1L)),
    upper = unname(quantile(boot, 0.975, type = 1L)))
}

lane_b_adjudicate_stratum <- function(z, cell, stratum, B = 9999L,
                                      expected_datasets = NULL,
                                      original_promotion_pass = TRUE) {
  th <- lane_b_thresholds()
  expected_datasets <- expected_datasets %||% length(unique(z$replicate_id))
  counts <- table(factor(z$arm, levels = lane_b_arms()$arm_id))
  if (any(counts != expected_datasets))
    stop("A realized stratum does not contain one primary row per dataset and arm.")
  mspl <- z[z$arm == "mspl", , drop = FALSE]
  n_mspl <- nrow(mspl)
  success <- sum(mspl$usable %in% TRUE)
  usable_fraction <- if (n_mspl) success / n_mspl else NA_real_
  wilson <- lane_b_wilson_lower(success, n_mspl)
  usable_rows <- mspl$usable %in% TRUE
  stationary <- n_mspl > 0L && any(usable_rows) &&
    all(is.finite(mspl$scaled_gradient[usable_rows])) &&
    all(mspl$scaled_gradient[usable_rows] <= th$scaled_gradient)
  no_boundary <- n_mspl > 0L && !any(mspl$bound_or_clamp %in% TRUE)
  alternate_health <- any(usable_rows) && "alternate_healthy" %in% names(mspl) &&
    all(mspl$alternate_healthy[usable_rows] %in% TRUE)
  multistart <- alternate_health &&
    all(is.finite(mspl$alternate_objective_gap[usable_rows])) &&
    all(is.finite(mspl$alternate_covariance_gap[usable_rows])) &&
    all(abs(mspl$alternate_objective_gap[usable_rows]) <=
          th$objective_gap_scale * (1 + abs(mspl$objective[usable_rows]))) &&
    all(mspl$alternate_covariance_gap[usable_rows] <= th$covariance_multistart)

  separated <- stratum %in% c("COMPLETE", "QUASI_COMPLETE")
  separated_pass <- separated && n_mspl > 0L &&
    usable_fraction >= th$separated_usable &&
    wilson >= th$separated_wilson_lower && stationary && no_boundary && multistart

  overlap_pair <- lane_b_adjudication_pair(z, "mspl", "ml")
  overlap_beta <- lane_b_adjudication_metric_pair(overlap_pair, "beta_squared_error")
  overlap_cov <- lane_b_adjudication_metric_pair(overlap_pair, "covariance_squared_error")
  overlap_log <- lane_b_adjudication_metric_pair(overlap_pair, "log_loss")
  seed <- 1700200000 + 1000 * cell$cell_index[[1L]] +
    match(stratum, c("OVERLAP", "COMPLETE", "QUASI_COMPLETE", "CONSTANT", "NOT_CHECKED"))
  usable_ci <- lane_b_boot_pair_stat(overlap_pair,
    function(d) mean((d$usable_a %in% TRUE) - (d$usable_b %in% TRUE)), B, seed)
  beta_ci <- lane_b_boot_pair_stat_strict(overlap_beta$rows,
    function(d) lane_b_ratio_stat(d, "beta_squared_error"), B, seed + 10L)
  covariance_ci <- lane_b_boot_pair_stat_strict(overlap_cov$rows,
    function(d) lane_b_ratio_stat(d, "covariance_squared_error"), B, seed + 20L)
  logloss_ci <- lane_b_boot_pair_stat_strict(overlap_log$rows,
    function(d) mean(d$log_loss_a - d$log_loss_b), B, seed + 30L)
  overlap_metrics_complete <- overlap_beta$complete == overlap_beta$mutually_usable &&
    overlap_cov$complete == overlap_cov$mutually_usable &&
    overlap_log$complete == overlap_log$mutually_usable
  overlap_absolute_pass <- identical(stratum, "OVERLAP") && n_mspl > 0L &&
    usable_fraction >= th$overlap_usable
  overlap_pass <- overlap_absolute_pass && nrow(overlap_pair) > 0L &&
    overlap_beta$mutually_usable > 0L && overlap_metrics_complete &&
    usable_ci[["lower"]] >= th$overlap_usable_difference &&
    beta_ci[["upper"]] <= th$rmse_ratio &&
    covariance_ci[["upper"]] <= th$rmse_ratio &&
    logloss_ci[["upper"]] <= th$log_loss_difference

  ridge_pair <- lane_b_adjudication_pair(z, "mspl_ridge_internal", "mspl")
  ridge_beta_pair <- lane_b_adjudication_metric_pair(ridge_pair, "beta_squared_error")
  ridge_cov_pair <- lane_b_adjudication_metric_pair(ridge_pair, "covariance_squared_error")
  ridge_log_pair <- lane_b_adjudication_metric_pair(ridge_pair, "log_loss")
  ridge_usable <- lane_b_boot_pair_stat(ridge_pair,
    function(d) mean((d$usable_a %in% TRUE) - (d$usable_b %in% TRUE)), B, seed + 40L)
  ridge_beta <- lane_b_boot_pair_stat_strict(ridge_beta_pair$rows,
    function(d) lane_b_ratio_stat(d, "beta_squared_error"), B, seed + 50L)
  ridge_cov <- lane_b_boot_pair_stat_strict(ridge_cov_pair$rows,
    function(d) lane_b_ratio_stat(d, "covariance_squared_error"), B, seed + 60L)
  ridge_logloss <- lane_b_boot_pair_stat_strict(ridge_log_pair$rows,
    function(d) mean(d$log_loss_a - d$log_loss_b), B, seed + 70L)
  ridge_metrics_complete <- ridge_beta_pair$complete == ridge_beta_pair$mutually_usable &&
    ridge_cov_pair$complete == ridge_cov_pair$mutually_usable &&
    ridge_log_pair$complete == ridge_log_pair$mutually_usable
  collapse <- function(rank, expected) is.na(rank) | is.na(expected) | rank < expected
  ridge_rank_collapse <- if (nrow(ridge_pair))
    sum(collapse(ridge_pair$sigma_rank_a, ridge_pair$expected_sigma_rank_a)) else Inf
  mspl_rank_collapse <- if (nrow(ridge_pair))
    sum(collapse(ridge_pair$sigma_rank_b, ridge_pair$expected_sigma_rank_b)) else Inf
  ridge_no_extra_rank_collapse <- is.finite(ridge_rank_collapse) &&
    ridge_rank_collapse <= mspl_rank_collapse
  ridge_no_harm <- nrow(ridge_pair) > 0L && ridge_beta_pair$mutually_usable > 0L &&
    ridge_metrics_complete &&
    ridge_usable[["lower"]] >= -th$ridge_failure_difference &&
    ridge_beta[["upper"]] <= th$rmse_ratio &&
    ridge_cov[["upper"]] <= th$rmse_ratio &&
    ridge_logloss[["upper"]] <= th$log_loss_difference &&
    ridge_no_extra_rank_collapse
  ridge_material_benefit <- nrow(ridge_pair) > 0L && ridge_metrics_complete &&
    (ridge_usable[["lower"]] > th$material_benefit ||
       ridge_beta[["upper"]] < 1 - th$material_benefit ||
       ridge_cov[["upper"]] < 1 - th$material_benefit ||
       ridge_logloss[["upper"]] < -th$material_benefit)

  promotable <- stratum %in% c("OVERLAP", "COMPLETE", "QUASI_COMPLETE")
  pass <- if (separated) separated_pass else if (stratum == "OVERLAP") overlap_pass else FALSE
  strict_pass <- isTRUE(original_promotion_pass) && pass
  data.frame(
    cell_id = cell$cell_id, link = cell$link, q = cell$q,
    intended_prevalence = cell$prevalence, b0_stratum = stratum,
    datasets = expected_datasets, mspl_attempted = n_mspl,
    mspl_usable = success, usable_fraction = usable_fraction,
    usable_wilson_lower = wilson, stationary = stationary,
    no_boundary_or_clamp = no_boundary, alternate_health = alternate_health,
    multistart_agreement = multistart,
    multistart_relative_sigma_gap_max = if (any(usable_rows))
      max(mspl$alternate_covariance_gap[usable_rows]) else Inf,
    separated_pass = separated_pass, overlap_absolute_pass = overlap_absolute_pass,
    overlap_pair_n = nrow(overlap_pair),
    overlap_mutually_usable_n = overlap_beta$mutually_usable,
    overlap_beta_complete_n = overlap_beta$complete,
    overlap_covariance_complete_n = overlap_cov$complete,
    overlap_log_loss_complete_n = overlap_log$complete,
    overlap_metrics_complete = overlap_metrics_complete,
    overlap_usable_difference_lower = usable_ci[["lower"]],
    overlap_beta_rmse_ratio_upper = beta_ci[["upper"]],
    overlap_covariance_rmse_ratio_upper = covariance_ci[["upper"]],
    overlap_log_loss_difference_upper = logloss_ci[["upper"]],
    overlap_pass = overlap_pass, ridge_pair_n = nrow(ridge_pair),
    ridge_mutually_usable_n = ridge_beta_pair$mutually_usable,
    ridge_metrics_complete = ridge_metrics_complete,
    ridge_no_extra_rank_collapse = ridge_no_extra_rank_collapse,
    ridge_no_harm = ridge_no_harm, ridge_material_benefit = ridge_material_benefit,
    original_promotion_pass = isTRUE(original_promotion_pass),
    promotable = promotable, promotion_pass = promotable && strict_pass,
    stringsAsFactors = FALSE
  )
}

lane_b_adjudicate_ordinary <- function(attempts, registry,
                                       manifest = lane_b_ordinary_manifest(),
                                       original_metrics,
                                       B = lane_b_thresholds()$paired_bootstrap_repetitions) {
  lane_b_validate_attempt_ledger(attempts, registry)
  if (missing(original_metrics) ||
      !all(c("cell_id", "promotion_pass") %in% names(original_metrics)) ||
      anyDuplicated(original_metrics$cell_id) ||
      !setequal(original_metrics$cell_id, manifest$cell_id))
    stop("Strict adjudication requires one immutable v1 promotion gate per cell.")
  all_attempts <- lane_b_attach_exact_b0(
    attempts[attempts$table == "ordinary", , drop = FALSE], registry)
  alternate <- all_attempts[all_attempts$start_role == "alternate" &
                              all_attempts$arm == "mspl", , drop = FALSE]
  alternate$alternate_healthy <- alternate$status == "success" &
    alternate$optimizer_success %in% TRUE & alternate$usable %in% TRUE &
    is.finite(alternate$scaled_gradient) &
    alternate$scaled_gradient <= lane_b_thresholds()$scaled_gradient &
    is.finite(alternate$objective) & !(alternate$bound_or_clamp %in% TRUE) &
    !is.na(alternate$sigma_rank) &
    alternate$sigma_rank == alternate$expected_sigma_rank
  health <- alternate[c("cell_id", "replicate_id", "alternate_healthy",
                        "sigma_vector")]
  names(health)[names(health) == "sigma_vector"] <- "alternate_sigma_vector"
  attempts <- all_attempts[all_attempts$start_role == "primary", , drop = FALSE]
  attempts <- merge(attempts, health, by = c("cell_id", "replicate_id"),
                    all.x = TRUE, sort = FALSE)
  attempts$alternate_covariance_gap <- mapply(
    lane_b_relative_sigma_gap,
    attempts$sigma_vector,
    attempts$alternate_sigma_vector
  )
  keys <- unique(registry[c("cell_id", "b0_stratum")])
  out <- lapply(seq_len(nrow(keys)), function(i) {
    cell <- manifest[manifest$cell_id == keys$cell_id[[i]], , drop = FALSE]
    z <- attempts[attempts$cell_id == keys$cell_id[[i]] &
                    attempts$b0_stratum == keys$b0_stratum[[i]], , drop = FALSE]
    expected <- sum(registry$cell_id == keys$cell_id[[i]] &
                      registry$b0_stratum == keys$b0_stratum[[i]])
    original_pass <- original_metrics$promotion_pass[
      match(keys$cell_id[[i]], original_metrics$cell_id)]
    lane_b_adjudicate_stratum(z, cell, keys$b0_stratum[[i]], B = B,
      expected_datasets = expected, original_promotion_pass = original_pass)
  })
  ans <- do.call(rbind, out)
  rownames(ans) <- NULL
  ans[order(ans$cell_id, ans$b0_stratum), , drop = FALSE]
}

lane_b_ordinary_family_gate <- function(metrics,
                                        manifest = lane_b_ordinary_manifest(),
                                        minimum_n = lane_b_adjudication_thresholds()$realized_stratum_minimum) {
  groups <- unique(manifest[c("link", "q")])
  out <- lapply(seq_len(nrow(groups)), function(i) {
    link <- groups$link[[i]]; q <- groups$q[[i]]
    cells <- manifest[manifest$link == link & manifest$q == q, , drop = FALSE]
    overlap_cells <- cells$cell_id[cells$prevalence == "balanced"]
    overlap <- metrics[metrics$cell_id %in% overlap_cells &
                         metrics$b0_stratum == "OVERLAP", , drop = FALSE]
    complete <- metrics[metrics$cell_id %in% cells$cell_id &
                          metrics$b0_stratum == "COMPLETE" &
                          metrics$datasets >= minimum_n, , drop = FALSE]
    complete_manifest <- merge(
      complete[c("cell_id", "promotion_pass")],
      cells[c("cell_id", "loading_sd")], by = "cell_id", all.x = TRUE
    )
    overlap_pass <- nrow(overlap) == length(overlap_cells) &&
      all(overlap$datasets >= minimum_n) && all(overlap$promotion_pass)
    complete_pass <- nrow(complete_manifest) >= 2L &&
      setequal(complete_manifest$loading_sd, c(0.5, 1.5)) &&
      all(complete_manifest$promotion_pass)
    data.frame(link = link, q = q,
      overlap_required_cells = length(overlap_cells),
      overlap_observed_cells = nrow(overlap),
      overlap_passing_cells = sum(overlap$promotion_pass %in% TRUE),
      complete_core_cells = nrow(complete_manifest),
      complete_passing_cells = sum(complete_manifest$promotion_pass %in% TRUE),
      complete_loading_regimes = paste(sort(unique(complete_manifest$loading_sd)),
                                       collapse = ";"),
      pass = overlap_pass && complete_pass,
      stringsAsFactors = FALSE)
  })
  do.call(rbind, out)
}

lane_b_validate_permutation_attempt_ledger <- function(
    attempts, manifest = lane_b_permutation_manifest()) {
  required <- c("cell_id", "replicate_id", "arm", "start_role", "table",
                "order_role")
  if (!all(required %in% names(attempts)))
    stop("Permutation attempt ledger lacks frozen key columns.")
  z <- attempts[attempts$table == "permutation", , drop = FALSE]
  datasets <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    data.frame(cell_id = manifest$audit_cell_id[[i]],
               replicate_id = seq_len(manifest$audit_attempts[[i]]),
               stringsAsFactors = FALSE)
  }))
  expected <- merge(
    datasets,
    expand.grid(
      arm = lane_b_arms()$arm_id,
      start_role = c("primary", "alternate"),
      order_role = c("original", "reverse", "random"),
      stringsAsFactors = FALSE
    ),
    by = NULL
  )
  key <- function(x) paste(x$cell_id, x$replicate_id, x$arm,
                           x$start_role, x$order_role, sep = ":")
  observed_key <- key(z)
  expected_key <- key(expected)
  if (nrow(z) != nrow(expected) || anyDuplicated(observed_key) ||
      !setequal(observed_key, expected_key)) {
    stop(paste(
      "Permutation attempt ledger is not exactly manifest x replicates x",
      "three orders x four arms x two starts."
    ))
  }
  invisible(TRUE)
}

lane_b_adjudicate_permutation <- function(
    attempts, manifest = lane_b_permutation_manifest()) {
  lane_b_validate_permutation_attempt_ledger(attempts, manifest)
  metrics <- lane_b_permutation_metrics(attempts)
  expected <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    expand <- expand.grid(
      replicate_id = seq_len(manifest$audit_attempts[[i]]),
      comparison = c("reverse", "random"),
      stringsAsFactors = FALSE
    )
    expand$cell_id <- manifest$audit_cell_id[[i]]
    expand
  }))
  key <- function(x) paste(x$cell_id, x$replicate_id, x$comparison, sep = ":")
  if (!all(c("cell_id", "replicate_id", "comparison", "pass") %in%
           names(metrics)) ||
      nrow(metrics) != nrow(expected) || anyDuplicated(key(metrics)) ||
      !setequal(key(metrics), key(expected))) {
    stop("Permutation invariance metrics are incomplete.")
  }
  metrics
}

lane_b_permutation_family_gate <- function(
    metrics, manifest = lane_b_permutation_manifest()) {
  expected_cells <- manifest$audit_cell_id
  if (!all(c("cell_id", "pass") %in% names(metrics)) ||
      !setequal(unique(metrics$cell_id), expected_cells)) {
    stop("Permutation family gate requires every frozen audit cell.")
  }
  cell_gate <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    id <- manifest$audit_cell_id[[i]]
    z <- metrics[metrics$cell_id == id, , drop = FALSE]
    expected <- 2L * manifest$audit_attempts[[i]]
    data.frame(
      cell_id = id, link = manifest$link[[i]], q = manifest$q[[i]],
      comparisons = nrow(z), passing_comparisons = sum(z$pass %in% TRUE),
      pass = nrow(z) == expected && all(z$pass %in% TRUE),
      stringsAsFactors = FALSE
    )
  }))
  groups <- unique(manifest[c("link", "q")])
  family_gate <- do.call(rbind, lapply(seq_len(nrow(groups)), function(i) {
    link <- groups$link[[i]]
    q <- groups$q[[i]]
    ids <- manifest$audit_cell_id[manifest$link == link & manifest$q == q]
    z <- cell_gate[cell_gate$cell_id %in% ids, , drop = FALSE]
    data.frame(
      link = link, q = q, required_cells = length(ids),
      passing_cells = sum(z$pass %in% TRUE),
      pass = nrow(z) == length(ids) && all(z$pass %in% TRUE),
      stringsAsFactors = FALSE
    )
  }))
  list(cell_gate = cell_gate, family_gate = family_gate,
       pass = nrow(family_gate) > 0L && all(family_gate$pass %in% TRUE))
}

lane_b_final_promotion_labels <- function(ordinary_gate, spatial_gate,
                                          permutation_gate) {
  permutation_pass <- is.list(permutation_gate) &&
    isTRUE(permutation_gate$pass)
  ordinary_pass <- nrow(ordinary_gate) > 0L &&
    all(ordinary_gate$pass %in% TRUE) && permutation_pass
  spatial_pass <- nrow(spatial_gate) > 0L &&
    all(spatial_gate$pass %in% TRUE) && permutation_pass
  list(
    ordinary_pass = ordinary_pass,
    spatial_pass = spatial_pass,
    overall_pass = ordinary_pass && spatial_pass,
    ordinary_label = if (ordinary_pass) "ORDINARY-PROMOTION-PASS" else
      "ORDINARY-PROMOTION-WITHHELD",
    spatial_label = if (spatial_pass) "SPATIAL-PROMOTION-PASS" else
      "SPATIAL-PROMOTION-WITHHELD",
    overall_label = if (ordinary_pass && spatial_pass)
      "LANE-B-PROMOTION-PASS" else "LANE-B-PROMOTION-WITHHELD"
  )
}

lane_b_authenticate_spatial_v1 <- function(attempts, stored_metrics) {
  recomputed <- lane_b_spatial_promotion_metrics(attempts)
  if (!is.data.frame(stored_metrics) ||
      !identical(recomputed, stored_metrics)) {
    stop(paste(
      "Stored immutable spatial v1 metrics disagree with the",
      "SHA-256-authenticated attempts."
    ))
  }
  recomputed
}

lane_b_validate_spatial_attempt_ledger <- function(attempts,
                                                   manifest = lane_b_spatial_manifest()) {
  required <- c("cell_id", "replicate_id", "arm", "start_role", "table")
  if (!all(required %in% names(attempts)))
    stop("Spatial attempt ledger lacks frozen key columns.")
  z <- attempts[attempts$table == "spatial", , drop = FALSE]
  datasets <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    data.frame(cell_id = manifest$cell_id[[i]],
               replicate_id = seq_len(manifest$attempts[[i]]),
               stringsAsFactors = FALSE)
  }))
  expected <- merge(
    datasets,
    expand.grid(arm = lane_b_arms()$arm_id,
                start_role = c("primary", "alternate"),
                stringsAsFactors = FALSE),
    by = NULL
  )
  key <- function(x)
    paste(x$cell_id, x$replicate_id, x$arm, x$start_role, sep = ":")
  observed_key <- key(z)
  expected_key <- key(expected)
  if (nrow(z) != nrow(expected) || anyDuplicated(observed_key) ||
      !setequal(observed_key, expected_key)) {
    stop("Spatial attempt ledger is not exactly manifest x four arms x two starts.")
  }
  invisible(TRUE)
}

lane_b_adjudicate_spatial <- function(attempts, original_metrics,
                                      manifest = lane_b_spatial_manifest()) {
  lane_b_validate_spatial_attempt_ledger(attempts, manifest)
  required_metrics <- c("cell_id", "pass")
  if (missing(original_metrics) ||
      !all(required_metrics %in% names(original_metrics)) ||
      anyDuplicated(original_metrics$cell_id) ||
      !setequal(original_metrics$cell_id, manifest$cell_id)) {
    stop("Strict spatial adjudication requires one immutable v1 gate per cell.")
  }
  z <- attempts[attempts$table == "spatial" & attempts$arm == "mspl",
                , drop = FALSE]
  th <- lane_b_thresholds()
  out <- lapply(seq_len(nrow(manifest)), function(i) {
    cell <- manifest[i, , drop = FALSE]
    d <- z[z$cell_id == cell$cell_id, , drop = FALSE]
    primary <- d[d$start_role == "primary", , drop = FALSE]
    alternate <- d[d$start_role == "alternate", , drop = FALSE]
    if (nrow(primary) != cell$attempts || nrow(alternate) != cell$attempts ||
        anyDuplicated(primary$replicate_id) || anyDuplicated(alternate$replicate_id) ||
        !setequal(primary$replicate_id, alternate$replicate_id)) {
      stop("Spatial MSPL primary/alternate rows do not match the frozen cell.")
    }
    alternate$alternate_healthy <- alternate$status == "success" &
      alternate$optimizer_success %in% TRUE & alternate$usable %in% TRUE &
      is.finite(alternate$scaled_gradient) &
      alternate$scaled_gradient <= th$scaled_gradient &
      is.finite(alternate$objective) & !(alternate$bound_or_clamp %in% TRUE) &
      !is.na(alternate$sigma_rank) &
      alternate$sigma_rank == alternate$expected_sigma_rank
    health <- alternate[c("replicate_id", "alternate_healthy", "sigma_vector")]
    names(health)[names(health) == "sigma_vector"] <- "alternate_sigma_vector"
    primary <- merge(primary, health, by = "replicate_id", all.x = TRUE,
                     sort = FALSE)
    primary <- primary[order(primary$replicate_id), , drop = FALSE]
    primary$alternate_covariance_gap <- mapply(
      lane_b_relative_sigma_gap,
      primary$sigma_vector,
      primary$alternate_sigma_vector
    )
    usable <- primary$usable %in% TRUE
    stationary <- any(usable) && all(is.finite(primary$scaled_gradient[usable])) &&
      all(primary$scaled_gradient[usable] <= th$scaled_gradient)
    no_boundary <- nrow(primary) > 0L &&
      !any(primary$bound_or_clamp %in% TRUE) &&
      !any(primary$spatial_boundary_contact %in% TRUE)
    alternate_health <- any(usable) &&
      all(primary$alternate_healthy[usable] %in% TRUE)
    multistart <- alternate_health &&
      all(is.finite(primary$alternate_objective_gap[usable])) &&
      all(is.finite(primary$alternate_covariance_gap[usable])) &&
      all(abs(primary$alternate_objective_gap[usable]) <=
            th$objective_gap_scale * (1 + abs(primary$objective[usable]))) &&
      all(primary$alternate_covariance_gap[usable] <= th$covariance_multistart)
    original_pass <- isTRUE(original_metrics$pass[
      match(cell$cell_id, original_metrics$cell_id)])
    data.frame(
      cell_id = cell$cell_id, link = cell$link,
      structure = cell$structure, q = cell$q,
      n_unit = cell$n_unit,
      prevalence_profile = cell$prevalence_profile,
      range_fraction_domain = cell$range_fraction_domain,
      attempted = nrow(primary), usable = sum(usable),
      stationary = stationary,
      no_boundary_or_clamp = no_boundary,
      alternate_health = alternate_health,
      multistart_agreement = multistart,
      multistart_relative_sigma_gap_max = if (any(usable))
        max(primary$alternate_covariance_gap[usable]) else Inf,
      original_promotion_pass = original_pass,
      promotion_pass = original_pass && stationary && no_boundary && multistart,
      stringsAsFactors = FALSE
    )
  })
  ans <- do.call(rbind, out)
  rownames(ans) <- NULL
  ans[order(ans$cell_id), , drop = FALSE]
}

lane_b_spatial_family_gate <- function(metrics,
                                       manifest = lane_b_spatial_manifest()) {
  if (!all(c("cell_id", "promotion_pass") %in% names(metrics)) ||
      anyDuplicated(metrics$cell_id) ||
      !setequal(metrics$cell_id, manifest$cell_id)) {
    stop("Spatial family gate requires one strict metric row per manifest cell.")
  }
  groups <- unique(manifest[c("link", "structure", "q")])
  out <- lapply(seq_len(nrow(groups)), function(i) {
    group <- groups[i, , drop = FALSE]
    cells <- manifest[
      manifest$link == group$link & manifest$structure == group$structure,
      , drop = FALSE
    ]
    observed <- metrics[metrics$cell_id %in% cells$cell_id, , drop = FALSE]
    design_complete <- nrow(observed) == nrow(cells) &&
      setequal(observed$n_unit, c(100L, 300L)) &&
      setequal(observed$prevalence_profile, c("balanced", "mixed_extremes")) &&
      setequal(observed$range_fraction_domain, c(0.15, 0.60))
    data.frame(
      link = group$link, structure = group$structure, q = group$q,
      required_cells = nrow(cells), observed_cells = nrow(observed),
      passing_cells = sum(observed$promotion_pass %in% TRUE),
      design_complete = design_complete,
      pass = design_complete && all(observed$promotion_pass),
      stringsAsFactors = FALSE
    )
  })
  ans <- do.call(rbind, out)
  rownames(ans) <- NULL
  ans
}

lane_b_adjudicate_quasi_multistart <- function(attempts,
                                               manifest = lane_b_quasi_manifest()) {
  z <- attempts[attempts$arm == "mspl", , drop = FALSE]
  th <- lane_b_thresholds()
  out <- lapply(seq_len(nrow(manifest)), function(i) {
    cell <- manifest[i, , drop = FALSE]
    d <- z[z$cell_id == cell$cell_id, , drop = FALSE]
    primary <- d[d$start_role == "primary", , drop = FALSE]
    alternate <- d[d$start_role == "alternate", , drop = FALSE]
    if (nrow(primary) != cell$n_rep || nrow(alternate) != cell$n_rep ||
        anyDuplicated(primary$replicate_id) || anyDuplicated(alternate$replicate_id) ||
        !setequal(primary$replicate_id, alternate$replicate_id)) {
      stop("Quasi MSPL primary/alternate rows do not match the frozen cell.")
    }
    alternate$alternate_healthy <- alternate$status == "success" &
      alternate$optimizer_success %in% TRUE & alternate$usable %in% TRUE &
      is.finite(alternate$scaled_gradient) &
      alternate$scaled_gradient <= th$scaled_gradient &
      is.finite(alternate$objective) & !(alternate$bound_or_clamp %in% TRUE) &
      !is.na(alternate$sigma_rank) &
      alternate$sigma_rank == alternate$expected_sigma_rank
    health <- alternate[c("replicate_id", "alternate_healthy", "sigma_vector")]
    names(health)[names(health) == "sigma_vector"] <- "alternate_sigma_vector"
    primary <- merge(primary, health, by = "replicate_id", all.x = TRUE,
                     sort = FALSE)
    primary <- primary[order(primary$replicate_id), , drop = FALSE]
    gap <- mapply(lane_b_relative_sigma_gap, primary$sigma_vector,
                  primary$alternate_sigma_vector)
    usable <- primary$usable %in% TRUE
    pass <- any(usable) && all(primary$alternate_healthy[usable] %in% TRUE) &&
      all(is.finite(primary$alternate_objective_gap[usable])) &&
      all(abs(primary$alternate_objective_gap[usable]) <=
            th$objective_gap_scale * (1 + abs(primary$objective[usable]))) &&
      all(is.finite(gap[usable])) &&
      all(gap[usable] <= th$covariance_multistart)
    data.frame(cell_id = cell$cell_id, strict_relative_sigma_gap_max =
      if (any(usable)) max(gap[usable]) else Inf,
      strict_multistart_pass = pass, stringsAsFactors = FALSE)
  })
  ans <- do.call(rbind, out)
  rownames(ans) <- NULL
  ans
}

lane_b_quasi_multistart_family_gate <- function(metrics,
                                                manifest = lane_b_quasi_manifest()) {
  if (!all(c("cell_id", "strict_multistart_pass") %in% names(metrics)) ||
      anyDuplicated(metrics$cell_id) ||
      !setequal(metrics$cell_id, manifest$cell_id)) {
    stop("Quasi multistart family gate requires one strict row per manifest cell.")
  }
  joined <- merge(
    manifest[c("cell_id", "link", "q", "loading_sd")],
    metrics[c("cell_id", "strict_multistart_pass")],
    by = "cell_id", all = TRUE
  )
  groups <- unique(joined[c("link", "q")])
  out <- lapply(seq_len(nrow(groups)), function(i) {
    d <- joined[joined$link == groups$link[[i]] & joined$q == groups$q[[i]],
                , drop = FALSE]
    data.frame(
      link = groups$link[[i]], q = groups$q[[i]], cells = nrow(d),
      passing_cells = sum(d$strict_multistart_pass %in% TRUE),
      loading_regimes = paste(sort(unique(d$loading_sd)), collapse = ";"),
      pass = nrow(d) == 2L && setequal(d$loading_sd, c(0.5, 1.5)) &&
        all(d$strict_multistart_pass),
      stringsAsFactors = FALSE
    )
  })
  ans <- do.call(rbind, out)
  rownames(ans) <- NULL
  ans
}
