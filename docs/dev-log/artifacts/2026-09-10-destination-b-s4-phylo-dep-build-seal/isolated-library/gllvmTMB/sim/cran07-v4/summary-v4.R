cran07_v4_summarize <- function(output_dir, manifest, registry, campaign_id,
                                stage, source_archive_sha256,
                                pilot_gate = NULL) {
  stage <- match.arg(stage, names(CRAN07_V4_STAGE_REPS))
  expected_cells <- if (stage == "production") {
    if (!is.list(pilot_gate) || !isTRUE(pilot_gate$production_authorized) ||
        !identical(pilot_gate$source_archive_sha256, source_archive_sha256)) {
      stop("Production summary requires the matching authorized pilot receipt.",
           call. = FALSE)
    }
    cells <- pilot_gate$admitted_cells$cell_id[
      pilot_gate$admitted_cells$campaign_id == campaign_id]
    if (!length(cells)) stop("Pilot admitted no cells for this campaign.",
                             call. = FALSE)
    cells
  } else registry$cell_id
  cran07_v4_validate_manifest(manifest, registry, campaign_id, stage,
                              source_archive_sha256, expected_cells)
  paths <- sort(list.files(output_dir, pattern = "\\.rds$", full.names = TRUE))
  results <- lapply(paths, readRDS)
  attempts <- if (length(results)) do.call(rbind, lapply(results, `[[`, "attempt")) else
    data.frame()
  if (!nrow(attempts)) stop("V4 summary has no attempt output.", call. = FALSE)
  cran07_v4_validate_attempt_table(attempts)
  cran07_v4_assert_attempt_manifest_identity(attempts, manifest)
  estimands_list <- Filter(Negate(is.null), lapply(results, `[[`, "estimands"))
  estimands <- if (length(estimands_list)) do.call(rbind, estimands_list) else data.frame()
  if (nrow(estimands)) {
    cran07_v4_validate_estimand_identity(estimands, attempts, manifest, registry,
                                         campaign_id)
  } else if (any(attempts$finite_estimands)) {
    stop("Finite attempts exist without an identity-bound estimand ledger.",
         call. = FALSE)
  }
  cran07_v4_validate_truth_metrics(attempts, estimands)
  identity <- list(
    campaign_id = campaign_id, stage = stage,
    registry_sha256 = attr(registry, "sha256"),
    source_archive_sha256 = source_archive_sha256,
    manifest_sha256 = cran07_v4_manifest_sha256(manifest),
    expected_cells = sort(expected_cells), expected_attempts = nrow(manifest),
    observed_attempts = nrow(attempts), complete = TRUE
  )
  gate <- switch(stage,
    smoke = cran07_v4_smoke_gate(attempts, estimands, manifest, registry),
    pilot = cran07_v4_pilot_admission(attempts, expected_cells),
    production = cran07_v4_production_gate(attempts, estimands, registry,
                                            expected_cells, campaign_id, manifest))
  list(attempts = attempts, estimands = estimands, v4_identity = identity,
       v4_gate = gate)
}

cran07_v4_campaign_production_evidence <- function(summary, pilot_gate,
                                                    registry, campaign_id) {
  admitted <- pilot_gate$admitted_cells
  expected <- sort(unique(admitted$cell_id[admitted$campaign_id == campaign_id]))
  eligible <- sort(cran07_v4_production_cells(campaign_id))
  base <- list(campaign_id = campaign_id, admitted_cells = expected, valid = FALSE,
               reason = "summary_absent", cell_gate = data.frame())
  if (is.null(summary)) return(base)
  id <- summary$v4_identity
  spec <- cran07_v4_campaign_spec(campaign_id)
  valid_identity <- length(expected) > 0L && all(expected %in% eligible) &&
    is.list(id) && identical(id$campaign_id, campaign_id) &&
    identical(id$stage, "production") && isTRUE(id$complete) &&
    identical(id$registry_sha256, spec$registry_sha256) &&
    grepl("^[0-9a-f]{64}$", id$source_archive_sha256) &&
    identical(id$source_archive_sha256, pilot_gate$source_archive_sha256) &&
    grepl("^[0-9a-f]{64}$", id$manifest_sha256) &&
    identical(id$expected_attempts, id$observed_attempts) &&
    identical(id$expected_attempts, as.integer(length(expected) * 1600L)) &&
    identical(sort(id$expected_cells), expected)
  if (!valid_identity) { base$reason <- "summary_identity_invalid"; return(base) }
  canonical_manifest <- cran07_v4_manifest(registry, campaign_id, "production",
                                            id$source_archive_sha256, expected)
  if (!identical(id$manifest_sha256,
                 cran07_v4_manifest_sha256(canonical_manifest))) {
    base$reason <- "manifest_hash_not_canonical"
    return(base)
  }
  ledger_valid <- tryCatch({
    cran07_v4_validate_attempt_table(summary$attempts)
    cran07_v4_assert_attempt_manifest_identity(summary$attempts,
                                                canonical_manifest)
    cran07_v4_validate_estimand_identity(summary$estimands, summary$attempts,
      canonical_manifest, registry, campaign_id)
    TRUE
  }, error = function(e) FALSE)
  if (!ledger_valid) {
    base$reason <- "attempt_or_estimand_ledger_invalid"
    return(base)
  }
  gate <- cran07_v4_production_gate(summary$attempts, summary$estimands,
    registry, expected, campaign_id, canonical_manifest)
  stored_gate <- summary$v4_gate
  order_gate <- function(x) {
    x <- x[order(x$cell_id), , drop = FALSE]
    rownames(x) <- NULL
    x
  }
  if (!is.data.frame(stored_gate) ||
      !identical(order_gate(stored_gate), order_gate(gate))) {
    base$reason <- "stored_production_gate_differs_from_recomputation"
    return(base)
  }
  if (!is.data.frame(gate) || !setequal(gate$cell_id, expected) ||
      anyDuplicated(gate$cell_id) ||
      !all(c("cell_pass", "component_schema_pass", "phi_nbinom2_bias_pass") %in%
           names(gate))) {
    base$reason <- "cell_gate_identity_invalid"; return(base)
  }
  base$valid <- TRUE
  base$reason <- if (all(gate$cell_pass)) "all_admitted_cells_pass" else
    "one_or_more_admitted_cells_failed"
  base$cell_gate <- gate
  base
}

cran07_v4_public_pair_status <- function(pair_id, evidence_pair_verdict) {
  fenced <- pair_id %in% c("gaussian_latent", "nb2_latent")
  list(
    publicly_promotable = identical(evidence_pair_verdict, "PASS") && !fenced,
    verdict = if (fenced) "CHARACTERIZATION_ONLY" else evidence_pair_verdict
  )
}

cran07_v4_production_closeout <- function(summaries, pilot_gate, registries,
                                          B = CRAN07_V4_RMSE_BOOT_B,
                                          seed = CRAN07_V4_RMSE_BOOT_SEED) {
  ids <- CRAN07_V4_CAMPAIGNS$campaign_id
  if (!is.list(summaries) || !all(ids %in% names(summaries)) ||
      !is.list(registries) || !all(ids %in% names(registries)) ||
      !isTRUE(pilot_gate$production_authorized)) {
    stop("V4 closeout requires all campaigns and an authorized pilot.",
         call. = FALSE)
  }
  evidence <- stats::setNames(lapply(ids, function(id)
    cran07_v4_campaign_production_evidence(summaries[[id]], pilot_gate,
                                           registries[[id]], id)), ids)
  source_hashes <- unique(vapply(summaries, function(x)
    x$v4_identity$source_archive_sha256, character(1L)))
  if (length(source_hashes) != 1L ||
      !identical(source_hashes, pilot_gate$source_archive_sha256)) {
    stop("V4 pilot and production must share one source-archive identity.",
         call. = FALSE)
  }
  expected_eligible <- CRAN07_V4_PRODUCTION_ELIGIBLE[
    order(CRAN07_V4_PRODUCTION_ELIGIBLE$campaign_id,
          CRAN07_V4_PRODUCTION_ELIGIBLE$cell_id), , drop = FALSE]
  admitted <- pilot_gate$admitted_cells[
    order(pilot_gate$admitted_cells$campaign_id,
          pilot_gate$admitted_cells$cell_id), , drop = FALSE]
  rownames(expected_eligible) <- rownames(admitted) <- NULL
  eligible_complete <- identical(admitted, expected_eligible)
  attempts <- do.call(rbind, lapply(summaries, `[[`, "attempts"))
  expected_n <- sum(vapply(evidence, function(x) length(x$admitted_cells), integer(1L))) *
    CRAN07_V4_PRODUCTION_REPS
  detector <- cran07_v4_detector_metrics_global(attempts, expected_n)
  core <- evidence[["cran07-core-recovery-v4"]]
  eligible <- CRAN07_V4_RMSE_PAIRS[
    CRAN07_V4_RMSE_PAIRS$small_cell %in% core$admitted_cells &
      CRAN07_V4_RMSE_PAIRS$large_cell %in% core$admitted_cells, , drop = FALSE]
  rmse <- if (core$valid && nrow(eligible)) cran07_v4_rmse_pair_gate(
    summaries[["cran07-core-recovery-v4"]]$estimands,
    registries[["cran07-core-recovery-v4"]], eligible, B, seed) else data.frame()
  pair_gate <- do.call(rbind, lapply(seq_len(nrow(CRAN07_V4_RMSE_PAIRS)), function(i) {
    pair <- CRAN07_V4_RMSE_PAIRS[i, ]
    both <- all(c(pair$small_cell, pair$large_cell) %in% core$admitted_cells)
    cell_ok <- core$valid && both && all(core$cell_gate$cell_pass[
      match(c(pair$small_cell, pair$large_cell), core$cell_gate$cell_id)])
    component_ok <- both && nrow(rmse[rmse$pair_id == pair$pair_id, ]) > 0L &&
      all(rmse$pass[rmse$pair_id == pair$pair_id])
    evidence_verdict <- if (cell_ok && component_ok) "PASS" else "HOLD"
    public <- cran07_v4_public_pair_status(pair$pair_id, evidence_verdict)
    data.frame(pair_id = pair$pair_id, small_cell = pair$small_cell,
      large_cell = pair$large_cell,
      evidence_pair_verdict = evidence_verdict,
      publicly_promotable = public$publicly_promotable,
      verdict = public$verdict,
      reason = if (!both) "one_or_both_pair_cells_not_admitted" else
        if (!cell_ok) "production_cell_gate_failed" else
          if (!component_ok) "rmse_component_gate_failed" else "all_gates_pass",
      stringsAsFactors = FALSE)
  }))
  campaign_gate <- do.call(rbind, lapply(evidence, function(x) data.frame(
    campaign_id = x$campaign_id, admitted_n = length(x$admitted_cells),
    valid = x$valid, all_admitted_cells_pass = x$valid && nrow(x$cell_gate) > 0L &&
      all(x$cell_gate$cell_pass), reason = x$reason, stringsAsFactors = FALSE)))
  evidence_pass <- eligible_complete && all(campaign_gate$all_admitted_cells_pass) &&
    all(pair_gate$evidence_pair_verdict == "PASS") && isTRUE(detector$pass)
  list(campaign_evidence = evidence, campaign_gate = campaign_gate,
       detector_global = detector, rmse_component_gate = rmse,
       family_pair_gate = pair_gate, admitted_cells = pilot_gate$admitted_cells,
       held_cells = pilot_gate$held_cells,
       production_eligible_complete = eligible_complete,
       subset_execution_verdict = if (evidence_pass) "PASS" else "HOLD",
       public_release_verdict = "HOLD",
       release_verdict = "HOLD")
}
