#!/usr/bin/env Rscript
# Pure tests-of-tests for corrected v3 aggregation. No model is fitted.
script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
script_dir <- dirname(normalizePath(script_arg, mustWork = TRUE))
core_dir <- normalizePath(file.path(script_dir, "../cran07-core"), mustWork = TRUE)
repo <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
source(file.path(core_dir, "schema.R"), local = .GlobalEnv)
source(file.path(core_dir, "campaign.R"), local = .GlobalEnv)
v2_offsets <- CRAN07_CAMPAIGNS$seed_offset
source(file.path(core_dir, "batch.R"), local = .GlobalEnv)
source(file.path(script_dir, "campaign-v3.R"), local = .GlobalEnv)
source(file.path(script_dir, "gates-v3.R"), local = .GlobalEnv)

make_attempts <- function(cell, n = 20L, unusable = 0L, catastrophic = 0L,
                          caught = catastrophic) {
  status <- rep("usable", n)
  if (unusable) status[seq_len(unusable)] <- "boundary"
  truth <- rep(FALSE, n)
  detector <- status != "usable"
  if (catastrophic) {
    truth[seq_len(catastrophic)] <- TRUE
    detector[seq_len(caught)] <- TRUE
  }
  data.frame(
    cell_id = cell, status = status, finite_estimands = TRUE,
    stationary = TRUE, pd_hessian = TRUE,
    catastrophic_truth_error = truth, detector_flagged = detector,
    stringsAsFactors = FALSE
  )
}

# Campaign identity, exact reused hashes, disjoint offsets, and full manifests.
stopifnot(length(intersect(v2_offsets, CRAN07_V3_CAMPAIGNS$seed_offset)) == 0L)
for (id in CRAN07_V3_CAMPAIGNS$campaign_id) {
  registry <- cran07_v3_read_campaign_registry(id, repo)
  spec <- cran07_v3_campaign_spec(id)
  stopifnot(identical(attr(registry, "sha256"), spec$registry_sha256),
            identical(attr(registry, "campaign_id"), id))
  manifest <- cran07_manifest(registry, "production", reps = 20L,
    campaign_id = id, registry_sha256 = attr(registry, "sha256"))
  cran07_v3_validate_manifest(manifest, registry, id, "pilot", registry$cell_id)
  incomplete <- manifest[-1L, ]
  stopifnot(inherits(try(cran07_v3_validate_manifest(
    incomplete, registry, id, "pilot", registry$cell_id), silent = TRUE), "try-error"))
}
stopifnot(inherits(try(cran07_v3_campaign_spec("cran07-core-recovery-v2"),
                      silent = TRUE), "try-error"),
          inherits(try(cran07_v3_campaign_spec("cran07-core-recovery-v4"),
                      silent = TRUE), "try-error"))

# Pilot boundary arithmetic: 3/20 unusable passes; 4/20 holds.
pilot3 <- cran07_v3_pilot_admission(make_attempts("cell", unusable = 3L), "cell")
pilot4 <- cran07_v3_pilot_admission(make_attempts("cell", unusable = 4L), "cell")
stopifnot(pilot3$admitted, !pilot4$admitted,
          pilot3$n_unusable == 3L, pilot4$n_unusable == 4L)
pilot_unknown <- make_attempts("cell", unusable = 3L)
pilot_unknown$status[[20L]] <- NA_character_
pilot_unknown_gate <- cran07_v3_pilot_admission(pilot_unknown, "cell")
stopifnot(pilot_unknown_gate$n_usable == 16L,
          pilot_unknown_gate$n_unusable == 4L,
          pilot_unknown_gate$n_unclassified == 1L,
          pilot_unknown_gate$unclassified_pass,
          !pilot_unknown_gate$unusable_pass, !pilot_unknown_gate$admitted)
missing <- cran07_v3_pilot_admission(make_attempts("cell", n = 19L), "cell")
stopifnot(!missing$complete_pass, !missing$admitted)

# Detector qualification is global, complete, and denominator-fail-closed.
global_ok <- make_attempts("all", n = 100L)
global_ok$catastrophic_truth_error[seq_len(20L)] <- TRUE
global_ok$detector_flagged[c(seq_len(19L), 21:28)] <- TRUE
global <- cran07_v3_detector_metrics_global(global_ok, expected_n = 100L)
stopifnot(global$pass, global$sensitivity == 0.95, global$specificity == 0.90)
zero_positive <- make_attempts("all", n = 100L, unusable = 8L)
stopifnot(!cran07_v3_detector_metrics_global(zero_positive, 100L)$pass,
          !cran07_v3_detector_metrics_global(global_ok, 101L)$pass)
expected_global <- do.call(rbind, lapply(seq_len(nrow(CRAN07_V3_CAMPAIGNS)), function(i) {
  registry <- cran07_v3_read_campaign_registry(CRAN07_V3_CAMPAIGNS$campaign_id[[i]], repo)
  data.frame(campaign_id = CRAN07_V3_CAMPAIGNS$campaign_id[[i]],
             cell_id = registry$cell_id, stringsAsFactors = FALSE)
}))
global_680 <- do.call(rbind, lapply(seq_len(nrow(expected_global)), function(i) {
  z <- make_attempts(expected_global$cell_id[[i]], n = 20L)
  z$campaign_id <- expected_global$campaign_id[[i]]
  z
}))
global_680$catastrophic_truth_error[seq_len(20L)] <- TRUE
global_680$detector_flagged[seq_len(19L)] <- TRUE
global_680$detector_flagged[21:86] <- TRUE
stopifnot(cran07_v3_pilot_global_gate(global_680, expected_global)$pass,
          !cran07_v3_pilot_global_gate(global_680[-1L, ], expected_global)$pass)
admission_global <- expected_global
admission_global$admitted <- TRUE
admission_global$admitted[[34L]] <- FALSE
subset_verdict <- cran07_v3_pilot_verdict(global_680, expected_global,
                                          admission_global)
stopifnot(subset_verdict$production_authorized,
          nrow(subset_verdict$admitted_cells) == 33L,
          nrow(subset_verdict$held_cells) == 1L)
global_680$catastrophic_truth_error <- FALSE
stopifnot(!cran07_v3_pilot_global_gate(global_680, expected_global)$pass)

estimand_rows <- function(cell, estimand, component, truth, estimate,
                          trait_i = NA_integer_, trait_j = NA_integer_) {
  data.frame(cell_id = cell, replicate = seq_along(estimate), estimand = estimand,
    component = component, trait_i = trait_i, trait_j = trait_j,
    applicable = TRUE, truth = rep(truth, length(estimate)), estimate = estimate,
    stringsAsFactors = FALSE)
}
rep400 <- function(value) rep(value, CRAN07_V3_PRODUCTION_REPS)
alt400 <- function(center, delta) rep(center + c(-delta, delta), 200L)

# Matrix relative Frobenius, Psi, and correlation thresholds accept and reject
# on the exact frozen boundaries.
matrix_fixture <- rbind(
  estimand_rows("m", "Sigma_total", "t1_t1", 1, rep400(1), 1L, 1L),
  estimand_rows("m", "Sigma_total", "t2_t1", 0.5, rep400(0.5), 2L, 1L),
  estimand_rows("m", "Sigma_total", "t2_t2", 1, rep400(1), 2L, 2L)
)
stopifnot(cran07_v3_matrix_bias(matrix_fixture, "m", "Sigma_total") == 0)
matrix_bad <- matrix_fixture
matrix_bad$estimate[matrix_bad$component == "t2_t1"] <- 1
stopifnot(cran07_v3_matrix_bias(matrix_bad, "m", "Sigma_total") > 0.15)
psi_ok <- estimand_rows("p", "Psi", "t1_t1", 0.01, rep400(0.019), 1L, 1L)
psi_bad <- estimand_rows("p", "Psi", "t1_t1", 0.01, rep400(0.021), 1L, 1L)
stopifnot(cran07_v3_psi_pass(psi_ok, "p", "psi_small", psi_applicable = TRUE),
          !cran07_v3_psi_pass(psi_bad, "p", "psi_small", psi_applicable = TRUE),
          !cran07_v3_psi_pass(psi_ok[0, ], "p", "base", psi_applicable = TRUE),
          cran07_v3_psi_pass(psi_ok[0, ], "p", "base", psi_applicable = FALSE))
corr_ok <- estimand_rows("r", "correlation_total", "t2_t1", 0.8,
                          rep400(0.9), 2L, 1L)
corr_bad <- estimand_rows("r", "correlation_total", "t2_t1", 0.8,
                           rep400(0.901), 2L, 1L)
stopifnot(cran07_v3_correlation_pass(corr_ok, "r", "rho_pos08"),
          !cran07_v3_correlation_pass(corr_bad, "r", "rho_pos08"))
n2 <- matrix_fixture[matrix_fixture$replicate <= 2L, ]
stopifnot(is.na(cran07_v3_matrix_bias(n2, "m", "Sigma_total")),
          !cran07_v3_psi_pass(psi_ok[1:2, ], "p", "psi_small",
                              psi_applicable = TRUE),
          !cran07_v3_correlation_pass(corr_ok[1:2, ], "r", "rho_pos08"))

# Canonical schemas are registry/DGP-derived and independent of observed keys.
core_registry <- cran07_v3_read_campaign_registry("cran07-core-recovery-v3", repo)
silent_registry <- cran07_v3_read_campaign_registry("cran07-silent-failure-v3", repo)
robust_registry <- cran07_v3_read_campaign_registry("cran07-robustness-v3", repo)
registries <- list(cran07_core_recovery_v3 = NULL)
registries <- stats::setNames(list(core_registry, silent_registry, robust_registry),
                              CRAN07_V3_CAMPAIGNS$campaign_id)
core_schema <- cran07_v3_expected_component_schema(
  core_registry, "cran07-core-recovery-v3")
silent_schema <- cran07_v3_expected_component_schema(
  silent_registry, "cran07-silent-failure-v3")
robust_schema <- cran07_v3_expected_component_schema(
  robust_registry, "cran07-robustness-v3")
stopifnot(nrow(core_schema) > 0L, nrow(silent_schema) > 0L,
          nrow(robust_schema) > 0L,
          !anyDuplicated(paste(core_schema$cell_id, core_schema$estimand,
                               core_schema$component)),
          !grepl("cran07_make_fixture|gllvmTMB::", paste(deparse(
            body(cran07_v3_expected_component_schema)), collapse = "")))
schema_estimands <- function(cell, schema, amplitude = 0.01) {
  z <- schema[schema$cell_id == cell, , drop = FALSE]
  do.call(rbind, lapply(seq_len(nrow(z)), function(i) {
    component <- z$component[[i]]
    match <- regmatches(component, regexec("^t([0-9]+)_t([0-9]+)$", component))[[1L]]
    bits <- if (length(match) == 3L) as.integer(match[2:3]) else integer()
    trait_i <- if (length(bits) == 2L && all(!is.na(bits))) bits[[1L]] else NA_integer_
    trait_j <- if (length(bits) == 2L && all(!is.na(bits))) bits[[2L]] else NA_integer_
    truth <- if (z$estimand[[i]] == "beta") 0 else
      if (grepl("correlation", z$estimand[[i]])) 0.2 else
        if (z$estimand[[i]] == "Psi") 0.1 else
          if (!is.na(trait_i) && trait_i == trait_j) 1 else 0.2
    estimand_rows(cell, z$estimand[[i]], component, truth,
                  alt400(truth, amplitude), trait_i, trait_j)
  }))
}

# Integrated production requires the exact canonical component set and 1:400.
prod_cell <- "g_latent_n60"
prod_registry <- core_registry[core_registry$cell_id == prod_cell, , drop = FALSE]
attr(prod_registry, "campaign_id") <- "cran07-core-recovery-v3"
prod_attempts <- make_attempts(prod_cell, n = 400L)
prod_estimands <- schema_estimands(prod_cell, core_schema)
prod_gate <- cran07_v3_production_gate(prod_attempts, prod_estimands,
  prod_registry, prod_cell, campaign_id = "cran07-core-recovery-v3")
stopifnot(prod_gate$cell_pass, prod_gate$component_schema_pass,
          prod_gate$sensitivity_denominator == 0L)
missing_beta_name <- core_schema$component[
  core_schema$cell_id == prod_cell & core_schema$estimand == "beta"][[1L]]
prod_missing_beta <- prod_estimands[!(prod_estimands$estimand == "beta" &
  prod_estimands$component == missing_beta_name), ]
stopifnot(!cran07_v3_production_gate(prod_attempts, prod_missing_beta,
  prod_registry, prod_cell, campaign_id = "cran07-core-recovery-v3")$cell_pass)
prod_unexpected <- rbind(prod_estimands,
  estimand_rows(prod_cell, "beta", "unexpected_beta", 0, alt400(0, 0.1)))
stopifnot(!cran07_v3_production_gate(prod_attempts, prod_unexpected,
  prod_registry, prod_cell, campaign_id = "cran07-core-recovery-v3")$cell_pass)
prod_n2 <- prod_estimands[prod_estimands$replicate <= 2L, ]
stopifnot(!cran07_v3_production_gate(prod_attempts, prod_n2,
  prod_registry, prod_cell, campaign_id = "cran07-core-recovery-v3")$cell_pass)

# RMSE iterates the frozen schema, so deleting the same beta on both sides HOLDs.
pair_cells <- sort(unique(c(CRAN07_V3_RMSE_PAIRS$small_cell,
                            CRAN07_V3_RMSE_PAIRS$large_cell)))
rmse_fixture <- do.call(rbind, lapply(pair_cells, function(cell) {
  pair <- CRAN07_V3_RMSE_PAIRS[
    CRAN07_V3_RMSE_PAIRS$small_cell == cell |
      CRAN07_V3_RMSE_PAIRS$large_cell == cell, ]
  amplitude <- if (cell == pair$small_cell) 1 else 0.5
  schema_estimands(cell, core_schema, amplitude)
}))
rmse_gate <- cran07_v3_rmse_pair_gate(rmse_fixture, core_registry, B = 50L)
stopifnot(all(rmse_gate$pass))
both_missing <- rmse_fixture[!(rmse_fixture$estimand == "beta" &
  rmse_fixture$component == missing_beta_name &
  rmse_fixture$cell_id %in% c("g_latent_n60", "g_latent_n240")), ]
missing_gate <- cran07_v3_rmse_pair_gate(both_missing, core_registry,
  pairs = CRAN07_V3_RMSE_PAIRS[CRAN07_V3_RMSE_PAIRS$pair_id == "gaussian_latent", ],
  B = 50L)
stopifnot(any(!missing_gate$pass & missing_gate$estimand == "beta" &
                missing_gate$component == missing_beta_name))
rmse_n2 <- rmse_fixture[rmse_fixture$replicate <= 2L, ]
stopifnot(all(!cran07_v3_rmse_pair_gate(rmse_n2, core_registry, B = 50L)$pass))

# Broad closeout consumes all three campaign summaries; absent evidence HOLDs.
silent_cell <- silent_registry$cell_id[[1L]]
robust_cell <- robust_registry$cell_id[[1L]]
fake_pilot <- list(production_authorized = TRUE,
  admitted_cells = (admitted_fixture <- rbind(
    data.frame(campaign_id = "cran07-core-recovery-v3", cell_id = pair_cells),
    data.frame(campaign_id = "cran07-silent-failure-v3", cell_id = silent_cell),
    data.frame(campaign_id = "cran07-robustness-v3", cell_id = robust_cell))),
  held_cells = expected_global[!paste(expected_global$campaign_id,
    expected_global$cell_id, sep = "::") %in% paste(admitted_fixture$campaign_id,
    admitted_fixture$cell_id, sep = "::"), , drop = FALSE])
fake_summary <- function(id, cells, estimands = data.frame()) {
  spec <- cran07_v3_campaign_spec(id)
  list(v3_identity = list(campaign_id = id, stage = "production",
    registry_sha256 = spec$registry_sha256,
    manifest_sha256 = paste(rep("a", 64L), collapse = ""),
    expected_cells = sort(cells), expected_attempts = length(cells) * 400L,
    observed_attempts = length(cells) * 400L, complete = TRUE),
    v3_gate = data.frame(cell_id = sort(cells), cell_pass = TRUE,
                         component_schema_pass = TRUE),
    estimands = estimands)
}
core_summary <- fake_summary("cran07-core-recovery-v3", pair_cells, rmse_fixture)
silent_summary <- fake_summary("cran07-silent-failure-v3", silent_cell)
robust_summary <- fake_summary("cran07-robustness-v3", robust_cell)
closeout_pass <- cran07_v3_production_closeout(core_summary, silent_summary,
  robust_summary, fake_pilot, registries, B = 50L)
stopifnot(identical(closeout_pass$release_verdict, "PASS"),
          all(closeout_pass$campaign_gate$all_admitted_cells_pass),
          all(closeout_pass$family_pair_gate$verdict == "PASS"))
closeout_no_silent <- cran07_v3_production_closeout(core_summary, NULL,
  robust_summary, fake_pilot, registries, B = 50L)
closeout_no_robust <- cran07_v3_production_closeout(core_summary, silent_summary,
  NULL, fake_pilot, registries, B = 50L)
stopifnot(closeout_no_silent$release_verdict == "HOLD",
          closeout_no_robust$release_verdict == "HOLD",
          closeout_no_silent$campaign_gate$reason[
            closeout_no_silent$campaign_gate$campaign_id ==
              "cran07-silent-failure-v3"] == "summary_absent",
          closeout_no_robust$campaign_gate$reason[
            closeout_no_robust$campaign_gate$campaign_id ==
              "cran07-robustness-v3"] == "summary_absent")

# Full attempt/manifest bijection rejects each identity-coordinate mismatch.
id_registry <- data.frame(cell_number = 1L, cell_id = "id_cell")
id_attempt <- data.frame(campaign_id = "cran07-core-recovery-v3",
  registry_sha256 = CRAN07_CORE_SHA256, cell_id = "id_cell",
  replicate = 1L, seed = 123L, stringsAsFactors = FALSE)
id_manifest <- data.frame(campaign_id = "cran07-core-recovery-v3",
  registry_sha256 = CRAN07_CORE_SHA256, cell_number = 1L,
  cell_id = "id_cell", replicate = 1L, seed = 123L,
  stringsAsFactors = FALSE)
cran07_v3_assert_attempt_manifest_identity(id_attempt, id_manifest, id_registry)
for (field in c("campaign_id", "registry_sha256", "cell_id", "replicate", "seed")) {
  bad <- id_manifest
  bad[[field]] <- if (is.numeric(bad[[field]])) bad[[field]] + 1L else paste0(bad[[field]], "x")
  stopifnot(inherits(try(cran07_v3_assert_attempt_manifest_identity(
    id_attempt, bad, id_registry), silent = TRUE), "try-error"))
}
bad_cell_number <- id_manifest
bad_cell_number$cell_number <- 2L
stopifnot(inherits(try(cran07_v3_assert_attempt_manifest_identity(
  id_attempt, bad_cell_number, id_registry), silent = TRUE), "try-error"))

runner <- readLines(file.path(script_dir, "run-batch.R"), warn = FALSE)
stopifnot(any(grepl("non-v3 campaign", readLines(file.path(script_dir,
  "campaign-v3.R")), fixed = TRUE)),
  any(grepl("--reps are forbidden", runner, fixed = TRUE)))

cat(paste(
  "v3_identity=OK", "v2_unknown_ids=rejected", "manifest_complete=fail_closed",
  "pilot_3_of_20=PASS", "pilot_4_of_20=HOLD",
  "unknown_counts_as_unusable=OK", "qualified_subset=authorized",
  "global_detector=qualified", "zero_detector_denominator=fail_closed",
  "production_components_400_exact=OK", "mode_aware_Psi=OK",
  "canonical_component_schema=OK", "missing_beta_both_sides=HOLD",
  "matrix_psi_correlation_thresholds=OK", "rmse_400_direction=OK",
  "missing_rmse_components=fail_closed", "three_campaign_closeout=OK",
  "absent_silent_robust=HOLD", "family_pair_HOLD=OK",
  "full_identity_bijection=OK", "fits_run=0", sep = " "), "\n")
