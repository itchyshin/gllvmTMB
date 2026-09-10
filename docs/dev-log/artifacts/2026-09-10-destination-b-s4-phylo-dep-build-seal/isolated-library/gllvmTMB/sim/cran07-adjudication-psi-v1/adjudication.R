# Post-production adjudication overlay for the frozen v3 summaries.
# No fit, fixture, attempt, registry, threshold, or raw result is changed.

CRAN07_ADJUDICATION_ID <- "cran07-v3-production-psi-schema-adjudication-v1"
CRAN07_ADJUDICATION_INPUTS <- data.frame(
  role = c("core", "silent", "robustness", "pilot"),
  campaign_id = c("cran07-core-recovery-v3", "cran07-silent-failure-v3",
                  "cran07-robustness-v3", "cran07-v3-pilot-gate"),
  sha256 = c(
    "29480d0b2fe296a989841f5c405042e900d87a70d527d8061a0c8d5badd2a114",
    "01c768ba62c4c02d2febe59bffa580e987d714fcfdde6691c8f77e74f9d8834a",
    "e3cb437a4f154876adc2890cf3ba9afe106052224af897df4524a1b7b235fc05",
    "350de2efe1304102f18fd184e4156508ca3b61c3418beda8669af8109fba3f2b"
  ),
  stringsAsFactors = FALSE
)
CRAN07_ADJUDICATION_SOURCE_SHA256 <-
  "c0372f037738a902c0c6d7ecd60f4170fcfc9d1d163709456eb0cd9f91615996"
CRAN07_ADJUDICATION_NUMERICAL_ZERO_TOL <- 64 * .Machine$double.eps

cran07_adjudication_normalize_psi <- function(estimands) {
  cran07_v3_validate_estimands(estimands)
  structural <- estimands$estimand == "Psi" & estimands$applicable &
    estimands$trait_i != estimands$trait_j
  if (any(structural)) {
    z <- estimands[structural, , drop = FALSE]
    if (anyNA(z[, c("truth", "estimate")]) ||
        any(z$truth != 0) || any(z$estimate != 0)) {
      stop(paste(
        "Applicable off-diagonal Psi rows are not exact structural zeros;",
        "adjudication cannot normalize them."), call. = FALSE)
    }
    estimands$applicable[structural] <- FALSE
  }
  attr(estimands, "psi_structural_rows_normalized") <- sum(structural)
  estimands
}

cran07_adjudication_apply_numerical_zero <- function(gate, estimands, pairs) {
  gate$numerical_zero_rule <- FALSE
  failed <- which(!gate$pass & gate$expected_component &
                    gate$estimand == "correlation_shared" &
                    gate$n_small == 400L & gate$n_large == 400L)
  for (i in failed) {
    pair <- pairs[pairs$pair_id == gate$pair_id[[i]], , drop = FALSE]
    if (nrow(pair) != 1L) next
    rows <- lapply(c(pair$small_cell, pair$large_cell), function(cell) {
      estimands[estimands$cell_id == cell & estimands$applicable &
        estimands$estimand == gate$estimand[[i]] &
        estimands$component == gate$component[[i]], , drop = FALSE]
    })
    complete <- all(vapply(rows, cran07_v3_complete_component, logical(1L)))
    fixed_rank1 <- complete && all(vapply(rows, function(z)
      max(abs(abs(z$truth) - 1)) <=
        CRAN07_ADJUDICATION_NUMERICAL_ZERO_TOL, logical(1L)))
    numerical_zero <- fixed_rank1 && all(vapply(rows, function(z)
      max(abs(z$estimate - z$truth)) <=
        CRAN07_ADJUDICATION_NUMERICAL_ZERO_TOL, logical(1L)))
    if (numerical_zero) {
      gate$pass[[i]] <- TRUE
      gate$numerical_zero_rule[[i]] <- TRUE
    }
  }
  gate
}

cran07_adjudication_mark_dispersion <- function(gate, estimands, registry) {
  family <- registry$family[match(gate$cell_id, registry$cell_id)]
  is_nb2 <- family %in% c("nbinom2", "nb2")
  has_dispersion <- vapply(gate$cell_id, function(cell) {
    z <- estimands[estimands$cell_id == cell &
      estimands$estimand == "dispersion" & estimands$applicable, , drop = FALSE]
    nrow(z) == CRAN07_V3_PRODUCTION_REPS &&
      cran07_v3_complete_component(z)
  }, logical(1L))
  gate$dispersion_evidence_pass <- !is_nb2 | has_dispersion
  gate$dispersion_evidence_reason <- ifelse(
    !is_nb2, "not_applicable",
    ifelse(has_dispersion, "complete", "primary_estimand_absent"))
  gate$cell_pass <- gate$cell_pass & gate$dispersion_evidence_pass
  gate
}

cran07_adjudication_assert_inputs <- function(paths) {
  if (length(paths) != 4L || is.null(names(paths)) ||
      !setequal(names(paths), CRAN07_ADJUDICATION_INPUTS$role)) {
    stop("Adjudication requires named core, silent, robustness, and pilot paths.",
         call. = FALSE)
  }
  actual <- vapply(CRAN07_ADJUDICATION_INPUTS$role, function(role)
    cran07_sha256(paths[[role]]), character(1L))
  expected <- stats::setNames(CRAN07_ADJUDICATION_INPUTS$sha256,
                              CRAN07_ADJUDICATION_INPUTS$role)
  if (!identical(actual, expected)) {
    stop("Adjudication input SHA-256 mismatch; no verdict produced.", call. = FALSE)
  }
  actual
}

cran07_adjudicate_production <- function(paths, registries) {
  input_hashes <- cran07_adjudication_assert_inputs(paths)
  summaries <- lapply(paths[c("core", "silent", "robustness")], readRDS)
  pilot <- readRDS(paths[["pilot"]])
  ids <- CRAN07_V3_CAMPAIGNS$campaign_id
  observed_ids <- vapply(summaries, function(x) x$v3_identity$campaign_id,
                         character(1L))
  if (!identical(unname(observed_ids), ids) ||
      !all(ids %in% names(registries)) ||
      !isTRUE(pilot$production_authorized)) {
    stop("Input campaign identities or pilot authority are not the frozen v3 set.",
         call. = FALSE)
  }

  normalized <- lapply(summaries, function(x) {
    x$estimands <- cran07_adjudication_normalize_psi(x$estimands)
    x
  })

  original_rmse <- cran07_v3_rmse_pair_gate
  corrected_rmse <- function(estimands, registry,
                             pairs = CRAN07_V3_RMSE_PAIRS,
                             B = CRAN07_V3_RMSE_BOOT_B,
                             seed = CRAN07_V3_RMSE_BOOT_SEED) {
    gate <- original_rmse(estimands, registry, pairs, B, seed)
    cran07_adjudication_apply_numerical_zero(gate, estimands, pairs)
  }
  assign("cran07_v3_rmse_pair_gate", corrected_rmse, envir = .GlobalEnv)
  on.exit(assign("cran07_v3_rmse_pair_gate", original_rmse,
                 envir = .GlobalEnv), add = TRUE)

  corrected <- lapply(seq_along(ids), function(i) {
    x <- normalized[[i]]
    admitted <- x$v3_identity$expected_cells
    x$v3_gate <- cran07_v3_production_gate(
      x$attempts, x$estimands, registries[[ids[[i]]]], admitted,
      campaign_id = ids[[i]])
    x$v3_gate <- cran07_adjudication_mark_dispersion(
      x$v3_gate, x$estimands, registries[[ids[[i]]]])
    x
  })
  closeout <- cran07_v3_production_closeout(
    corrected[[1L]], corrected[[2L]], corrected[[3L]], pilot, registries)
  production_identity <- lapply(seq_along(ids), function(i) {
    identity <- summaries[[i]]$v3_identity
    spec <- cran07_v3_campaign_spec(ids[[i]])
    data.frame(
      role = CRAN07_ADJUDICATION_INPUTS$role[[i]],
      sha256_pass = TRUE,
      campaign_identity_pass = identical(identity$campaign_id, ids[[i]]) &&
        identical(identity$stage, "production"),
      registry_identity_pass = identical(identity$registry_sha256,
                                          spec$registry_sha256),
      manifest_identity_pass = length(identity$manifest_sha256) == 1L &&
        grepl("^[0-9a-f]{64}$", identity$manifest_sha256),
      completeness_pass = isTRUE(identity$complete) &&
        identical(identity$expected_attempts, identity$observed_attempts),
      scientific_component_schema_pass =
        all(corrected[[i]]$v3_gate$component_schema_pass),
      stringsAsFactors = FALSE)
  })
  identity_gate <- do.call(rbind, c(production_identity, list(data.frame(
    role = "pilot", sha256_pass = TRUE,
    campaign_identity_pass = setequal(pilot$campaign_ids, ids),
    registry_identity_pass = NA, manifest_identity_pass = NA,
    completeness_pass = nrow(pilot$cell_admission) == 34L &&
      nrow(pilot$admitted_cells) + nrow(pilot$held_cells) == 34L,
    scientific_component_schema_pass = NA,
    stringsAsFactors = FALSE))))
  list(
    adjudication_id = CRAN07_ADJUDICATION_ID,
    source_tarball_sha256 = CRAN07_ADJUDICATION_SOURCE_SHA256,
    input_hashes = input_hashes,
    correction = paste(
      "Exact-zero off-diagonal Psi rows are reclassified non-applicable in a",
      "derived ledger; the frozen diagonal-Psi scientific schema is unchanged."
    ),
    identity_gate = identity_gate,
    psi_structural_rows_normalized = vapply(normalized, function(x)
      attr(x$estimands, "psi_structural_rows_normalized"), integer(1L)),
    numerical_zero_tolerance = CRAN07_ADJUDICATION_NUMERICAL_ZERO_TOL,
    thresholds_changed = FALSE,
    fits_run = 0L,
    production_gates = stats::setNames(lapply(corrected, `[[`, "v3_gate"), ids),
    closeout = closeout
  )
}
