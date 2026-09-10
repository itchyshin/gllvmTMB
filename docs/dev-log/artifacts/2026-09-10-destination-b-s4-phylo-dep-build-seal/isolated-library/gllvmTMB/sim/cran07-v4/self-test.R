#!/usr/bin/env Rscript
# Adversarial pure tests-of-tests for v4. No model is fitted.
script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
script_arg <- gsub("~+~", " ", script_arg, fixed = TRUE)
script_dir <- dirname(normalizePath(script_arg, mustWork = TRUE))
core_dir <- file.path(script_dir, "../cran07-core"); v3_dir <- file.path(script_dir, "../cran07-v3")
repo <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
for (f in c(file.path(core_dir, c("schema.R", "campaign.R", "attempt-runner.R", "batch.R")),
            file.path(v3_dir, c("campaign-v3.R", "gates-v3.R")),
            file.path(script_dir, c("campaign-v4.R", "schema-v4.R",
                                    "attempt-runner-v4.R", "gates-v4.R",
                                    "summary-v4.R")))) source(f, local = .GlobalEnv)

# Standalone summarization, pilot adjudication, and closeout intentionally do
# not load the model-fitting runner. Their shared source set must therefore be
# sufficient for every gate-time truth and structural-Psi calculation.
standalone_env <- new.env(parent = baseenv())
standalone_sources <- c(
  file.path(core_dir, c("schema.R", "campaign.R", "batch.R")),
  file.path(v3_dir, c("campaign-v3.R", "gates-v3.R")),
  file.path(script_dir, c("campaign-v4.R", "schema-v4.R", "gates-v4.R",
                          "summary-v4.R"))
)
for (f in standalone_sources) sys.source(f, envir = standalone_env)
stopifnot(
  exists("cran07_v4_normalize_structural_psi", envir = standalone_env,
         inherits = FALSE),
  exists("cran07_v4_assess_estimands", envir = standalone_env,
         inherits = FALSE),
  !grepl("cran07_v4_normalize_structural_psi <- function",
         paste(readLines(file.path(script_dir, "attempt-runner-v4.R"),
                         warn = FALSE), collapse = "\n"), fixed = TRUE),
  !grepl("cran07_v4_assess_estimands <- function",
         paste(readLines(file.path(script_dir, "attempt-runner-v4.R"),
                         warn = FALSE), collapse = "\n"), fixed = TRUE)
)

sha <- paste(rep("a", 64L), collapse = "")
make_attempt <- function(n = 1L, status = "usable", cell = "cell",
                         campaign = "cran07-core-recovery-v4") {
  boundary <- status == "boundary"
  data.frame(
    campaign_id = campaign, registry_sha256 = CRAN07_CORE_SHA256,
    source_archive_sha256 = sha, cell_id = cell, replicate = seq_len(n),
    seed = seq_len(n), status = status, constructed = TRUE,
    optimizer_converged = TRUE, stationary = TRUE, pd_hessian = TRUE,
    finite_estimands = TRUE, boundary = boundary, geometry_flag = FALSE,
    detector_flagged = status != "usable", catastrophic_truth_error = FALSE,
    relative_covariance_error = 0, max_eigen_ratio = 1,
    family = "gaussian", n_trials_min = NA_integer_, n_trials_max = NA_integer_,
    diag_B_skip = "", diag_B_all_free = NA,
    error_class = "", error_message = "", elapsed_seconds = 0,
    warm_restart_attempted = FALSE, warm_restart_accepted = FALSE,
    objective_before_restart = 1, objective_after_restart = NA_real_,
    max_gradient_before_restart = 0.001, max_gradient_after_restart = NA_real_,
    convergence_code_before_restart = 0L,
    convergence_code_after_restart = NA_integer_,
    pd_hessian_before_restart = TRUE, pd_hessian_after_restart = NA,
    boundary_before_restart = FALSE, boundary_after_restart = NA,
    warm_restart_trigger_reason = "raw_gradient_below_0.01",
    stringsAsFactors = FALSE)
}

# Exact IDs, stage offsets, 34-cell smoke/pilot, and 31-cell production target.
registries <- stats::setNames(lapply(CRAN07_V4_CAMPAIGNS$campaign_id, function(id)
  cran07_v4_read_campaign_registry(id, repo)), CRAN07_V4_CAMPAIGNS$campaign_id)
stopifnot(sum(vapply(registries, nrow, integer(1L))) == 34L,
  length(intersect(unlist(CRAN07_V3_CAMPAIGNS[c("seed_offset")]),
                   unlist(CRAN07_V4_CAMPAIGNS[grep("_offset$", names(CRAN07_V4_CAMPAIGNS))]))) == 0L)
for (id in CRAN07_V4_CAMPAIGNS$campaign_id) {
  registry <- registries[[id]]
  for (stage in names(CRAN07_V4_STAGE_REPS)) {
    cells <- if (stage == "production") cran07_v4_production_cells(id) else
      registry$cell_id
    manifest <- cran07_v4_manifest(registry, id, stage, sha)
    cran07_v4_validate_manifest(manifest, registry, id, stage, sha, cells)
    stopifnot(nrow(manifest) == length(cells) * CRAN07_V4_STAGE_REPS[[stage]])
    bad <- manifest; bad$seed[[1L]] <- bad$seed[[1L]] + 1L
    stopifnot(inherits(try(cran07_v4_validate_manifest(
      bad, registry, id, stage, sha, cells), silent = TRUE), "try-error"))
  }
}
challenge_manifest <- try(cran07_v4_manifest(core <- registries[[1L]],
  "cran07-core-recovery-v4", "production", sha,
  c(cran07_v4_production_cells("cran07-core-recovery-v4"),
    "g_latent_psi_small")), silent = TRUE)
stopifnot(inherits(challenge_manifest, "try-error"))
all_cells <- cran07_v4_expected_campaign_cells(registries)
stopifnot(nrow(all_cells) == 34L,
  sum(!all_cells$cell_id %in% CRAN07_V4_HELD_CHALLENGE_CELLS) == 31L)
receipt_dir <- file.path(repo, "docs/dev-log/simulation-artifacts",
                         "2026-08-08-cran07-v4-preregistration")
eligible_receipt <- utils::read.csv(file.path(receipt_dir,
  "production-eligible.csv"), stringsAsFactors = FALSE)
order_keys <- function(x) {
  x <- x[order(x$campaign_id, x$cell_id), c("campaign_id", "cell_id"), drop = FALSE]
  rownames(x) <- NULL; x
}
stopifnot(identical(order_keys(eligible_receipt),
                    order_keys(CRAN07_V4_PRODUCTION_ELIGIBLE)))
manifest_receipt <- utils::read.csv(file.path(receipt_dir,
  "manifest-template.csv"), stringsAsFactors = FALSE)
source_binding <- utils::read.csv(file.path(receipt_dir,
  "source-archive-binding.csv"), stringsAsFactors = FALSE)
stopifnot(nrow(manifest_receipt) == 9L,
  sum(manifest_receipt$stage == "smoke") == 3L,
  sum(manifest_receipt$stage == "pilot") == 3L,
  sum(manifest_receipt$stage == "production") == 3L,
  sum(manifest_receipt$cell_count[manifest_receipt$stage == "production"]) == 31L,
  all(manifest_receipt$source_archive_binding ==
        "DETACHED_CANONICAL_BINDING_REQUIRED"),
  identical(names(source_binding), CRAN07_V4_SOURCE_RECEIPT_FIELDS),
  identical(source_binding$receipt_id[[1L]], CRAN07_V4_SOURCE_RECEIPT_ID))
if (source_binding$status[[1L]] %in%
    c("HOLD_PENDING_SOURCE_ARCHIVE", "HOLD_PENDING_EXTERNAL_AUTHORITY")) {
  stopifnot(identical(source_binding$launch_authorized[[1L]], FALSE))
  if (identical(source_binding$status[[1L]],
                "HOLD_PENDING_EXTERNAL_AUTHORITY")) {
    bound_manifest_path <- file.path(repo, CRAN07_V4_PAYLOAD_MANIFEST_RELPATH)
    bound_sha_path <- file.path(repo, CRAN07_V4_SHA_LEDGER_RELPATH)
    bound_launcher_path <- file.path(repo, CRAN07_V4_LAUNCHER_RELPATH)
    internally_ready <- source_binding
    internally_ready$status <- "READY"
    internally_ready$launch_authorized <- TRUE
    stopifnot(identical(cran07_v4_validate_source_binding(
      internally_ready, internally_ready$source_archive_path[[1L]],
      bound_manifest_path, bound_sha_path, bound_launcher_path),
      internally_ready$sha256[[1L]]))
  }
} else if (identical(source_binding$status[[1L]], "READY")) {
  bound_manifest_path <- file.path(repo, CRAN07_V4_PAYLOAD_MANIFEST_RELPATH)
  bound_sha_path <- file.path(repo, CRAN07_V4_SHA_LEDGER_RELPATH)
  bound_launcher_path <- file.path(repo, CRAN07_V4_LAUNCHER_RELPATH)
  stopifnot(identical(cran07_v4_validate_source_binding(
    source_binding, source_binding$source_archive_path[[1L]],
    bound_manifest_path, bound_sha_path, bound_launcher_path),
    source_binding$sha256[[1L]]))
  bound_authority <- cran07_v4_read_external_authority()
  invisible(cran07_v4_validate_external_authority(
    bound_authority, source_binding, bound_launcher_path))
  bound_manifest <- utils::read.csv(bound_manifest_path, stringsAsFactors = FALSE,
    colClasses = c(path = "character", type = "character", mode = "character",
                   bytes = "numeric", sha256 = "character"))
  invisible(cran07_v4_validate_archive_payload(
    source_binding$source_archive_path[[1L]], bound_manifest))
} else {
  stop("Canonical v4 source binding has an unknown status.", call. = FALSE)
}
core <- registries[["cran07-core-recovery-v4"]]
manifest <- cran07_v4_manifest(core, "cran07-core-recovery-v4", "smoke", sha)
stopifnot(inherits(try(cran07_v4_validate_manifest(manifest[-1L, ], core,
  "cran07-core-recovery-v4", "smoke", sha, core$cell_id), silent = TRUE), "try-error"))
wrong_source <- manifest; wrong_source$source_archive_sha256[[1L]] <- paste(rep("b", 64L), collapse = "")
stopifnot(inherits(try(cran07_v4_validate_manifest(wrong_source, core,
  "cran07-core-recovery-v4", "smoke", sha, core$cell_id), silent = TRUE), "try-error"))

# Source payload identity uses a detached exact manifest and regular-file-only
# archive. Missing, extra, link, and arbitrary-root substitutions fail closed.
member_stage <- tempfile("cran07-v4-member-stage-")
member_paths <- sort(CRAN07_V4_REQUIRED_ARCHIVE_RELPATHS, method = "radix")
for (rel in member_paths) {
  path <- file.path(member_stage, "gllvmTMB", rel)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(rel, path)
  Sys.chmod(path, "0644")
}
member_files <- file.path(member_stage, "gllvmTMB", member_paths)
member_info <- file.info(member_files)
member_manifest <- data.frame(
  path = member_paths, type = "file",
  mode = sprintf("%04o", as.integer(member_info$mode)),
  bytes = as.numeric(member_info$size),
  sha256 = cran07_v4_file_sha256s(member_files), stringsAsFactors = FALSE)
member_manifest_file <- tempfile(fileext = ".csv")
utils::write.csv(member_manifest, member_manifest_file, row.names = FALSE)
member_list <- tempfile(fileext = ".txt")
writeLines(file.path("gllvmTMB", member_paths), member_list)
member_archive <- tempfile(fileext = ".tar")
stopifnot(identical(system2("tar", c("-cf", shQuote(member_archive), "-C",
  shQuote(member_stage), "-T", shQuote(member_list))), 0L))
invisible(cran07_v4_validate_archive_payload(member_archive, member_manifest))

member_launcher <- tempfile(fileext = ".R"); writeLines("# launcher", member_launcher)
member_ledger <- tempfile(fileext = ".txt"); writeLines("# ledger", member_ledger)
archive_hash <- cran07_sha256(member_archive)
ready_binding <- data.frame(
  receipt_id = CRAN07_V4_SOURCE_RECEIPT_ID, status = "READY",
  source_archive_file = basename(member_archive),
  source_archive_path = normalizePath(member_archive, mustWork = TRUE),
  sha256 = archive_hash,
  source_payload_manifest_file = basename(member_manifest_file),
  source_payload_manifest_sha256 = cran07_sha256(member_manifest_file),
  source_payload_member_count = nrow(member_manifest),
  sha_ledger_file = basename(member_ledger),
  sha_ledger_sha256 = cran07_sha256(member_ledger),
  launcher_file = basename(member_launcher),
  launcher_sha256 = cran07_sha256(member_launcher),
  launch_authorized = TRUE, stringsAsFactors = FALSE)
stopifnot(identical(cran07_v4_validate_source_binding(
  ready_binding, member_archive, member_manifest_file, member_ledger,
  member_launcher),
  archive_hash))
bad_bindings <- list(
  transform(ready_binding, receipt_id = "copied-binding"),
  transform(ready_binding, status = "HOLD_PENDING_SOURCE_ARCHIVE"),
  transform(ready_binding, launch_authorized = FALSE),
  transform(ready_binding, source_archive_file = "another.tar"),
  transform(ready_binding, source_archive_path = tempfile(fileext = ".tar")),
  transform(ready_binding, sha256 = sha),
  transform(ready_binding, source_payload_manifest_sha256 = sha),
  transform(ready_binding, source_payload_member_count = nrow(member_manifest) - 1L),
  transform(ready_binding, sha_ledger_sha256 = sha),
  transform(ready_binding, launcher_sha256 = sha))
for (binding in bad_bindings) {
  stopifnot(inherits(try(cran07_v4_validate_source_binding(
    binding, member_archive, member_manifest_file, member_ledger,
    member_launcher),
    silent = TRUE), "try-error"))
}

authority_fixture <- data.frame(
  authority_id = CRAN07_V4_AUTHORITY_ID,
  status = "AUTHORIZED",
  scope = "simulation_execution_only",
  receipt_id = ready_binding$receipt_id,
  source_archive_file = ready_binding$source_archive_file,
  source_archive_sha256 = ready_binding$sha256,
  source_payload_manifest_file = ready_binding$source_payload_manifest_file,
  source_payload_manifest_sha256 = ready_binding$source_payload_manifest_sha256,
  sha_ledger_file = ready_binding$sha_ledger_file,
  sha_ledger_sha256 = ready_binding$sha_ledger_sha256,
  launcher_file = ready_binding$launcher_file,
  launcher_sha256 = ready_binding$launcher_sha256,
  simulation_authorized = TRUE,
  release_authorized = FALSE,
  version_change_authorized = FALSE,
  publication_authorized = FALSE,
  cran_submission_authorized = FALSE,
  stringsAsFactors = FALSE)
invisible(cran07_v4_validate_external_authority(
  authority_fixture, ready_binding, member_launcher))
bad_authorities <- list(
  transform(authority_fixture, status = "PENDING"),
  transform(authority_fixture, scope = "release"),
  transform(authority_fixture, source_archive_sha256 = sha),
  transform(authority_fixture, launcher_sha256 = sha),
  transform(authority_fixture, simulation_authorized = FALSE),
  transform(authority_fixture, release_authorized = TRUE),
  transform(authority_fixture, version_change_authorized = TRUE),
  transform(authority_fixture, publication_authorized = TRUE),
  transform(authority_fixture, cran_submission_authorized = TRUE))
for (authority in bad_authorities) {
  stopifnot(inherits(try(cran07_v4_validate_external_authority(
    authority, ready_binding, member_launcher), silent = TRUE), "try-error"))
}

missing_archive <- tempfile(fileext = ".tar")
missing_list <- tempfile(fileext = ".txt")
writeLines(file.path("gllvmTMB", member_paths[-length(member_paths)]), missing_list)
stopifnot(identical(system2("tar", c("-cf", shQuote(missing_archive), "-C",
  shQuote(member_stage), "-T", shQuote(missing_list))), 0L),
  inherits(try(cran07_v4_validate_archive_payload(
    missing_archive, member_manifest), silent = TRUE), "try-error"))
extra_path <- file.path(member_stage, "gllvmTMB", "unexpected.txt")
writeLines("unexpected", extra_path)
extra_list <- tempfile(fileext = ".txt")
writeLines(c(file.path("gllvmTMB", member_paths), "gllvmTMB/unexpected.txt"),
           extra_list)
extra_archive <- tempfile(fileext = ".tar")
stopifnot(identical(system2("tar", c("-cf", shQuote(extra_archive), "-C",
  shQuote(member_stage), "-T", shQuote(extra_list))), 0L),
  inherits(try(cran07_v4_validate_archive_payload(
    extra_archive, member_manifest), silent = TRUE), "try-error"))

link_stage <- tempfile("cran07-v4-link-stage-")
dir.create(file.path(link_stage, "gllvmTMB"), recursive = TRUE)
for (rel in member_paths) {
  to <- file.path(link_stage, "gllvmTMB", rel)
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  file.copy(file.path(member_stage, "gllvmTMB", rel), to)
}
link_target <- file.path(link_stage, "gllvmTMB", "R/fit-multi.R")
stopifnot(file.remove(link_target))
stopifnot(file.symlink("../../../../outside-R-code", link_target))
link_archive <- tempfile(fileext = ".tar")
stopifnot(identical(system2("tar", c("-cf", shQuote(link_archive), "-C",
  shQuote(link_stage), "-T", shQuote(member_list))), 0L),
  inherits(try(cran07_v4_validate_archive_members(link_archive), silent = TRUE),
           "try-error"))

fake_parent <- tempfile("cran07-v4-fake-root-")
dir.create(fake_parent)
stopifnot(identical(system2("tar", c("-xf", shQuote(member_archive), "-C",
  shQuote(fake_parent))), 0L))
fake_repo <- file.path(fake_parent, "gllvmTMB")
fake_receipt <- file.path(fake_repo, CRAN07_V4_SOURCE_RECEIPT_RELPATH)
fake_manifest <- file.path(fake_repo, CRAN07_V4_PAYLOAD_MANIFEST_RELPATH)
fake_ledger <- file.path(fake_repo, CRAN07_V4_SHA_LEDGER_RELPATH)
fake_launcher <- file.path(fake_repo, CRAN07_V4_LAUNCHER_RELPATH)
dir.create(dirname(fake_receipt), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(fake_launcher), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(transform(ready_binding,
  source_payload_manifest_file = basename(fake_manifest),
  sha_ledger_file = basename(fake_ledger),
  launcher_file = basename(fake_launcher)), fake_receipt, row.names = FALSE)
stopifnot(file.copy(member_manifest_file, fake_manifest),
          file.copy(member_ledger, fake_ledger),
          file.copy(member_launcher, fake_launcher))
stopifnot(inherits(try(cran07_v4_verify_bound_source(fake_repo), silent = TRUE),
                     "try-error"))
writeLines("not in payload", file.path(fake_repo, "substitution.txt"))
stopifnot(inherits(try(cran07_v4_verify_bound_source(fake_repo), silent = TRUE),
                     "try-error"))

# Warm-restart acceptance and rejection halves, including every trigger field.
no_restart <- list(warm_restart_attempted = FALSE, warm_restart_accepted = FALSE,
  objective_before_restart = 10, objective_after_restart = NA_real_,
  max_gradient_before_restart = 0.001, max_gradient_after_restart = NA_real_,
  convergence_code_before_restart = 0L, convergence_code_after_restart = NA_integer_,
  pd_hessian_before_restart = TRUE, pd_hessian_after_restart = NA,
  boundary_before_restart = FALSE, boundary_after_restart = NA,
  warm_restart_trigger_reason = "raw_gradient_below_0.01")
accepted <- list(warm_restart_attempted = TRUE, warm_restart_accepted = TRUE,
  objective_before_restart = 10, objective_after_restart = 10,
  max_gradient_before_restart = 0.02, max_gradient_after_restart = 0.002,
  convergence_code_before_restart = 0L, convergence_code_after_restart = 0L,
  pd_hessian_before_restart = TRUE, pd_hessian_after_restart = TRUE,
  boundary_before_restart = FALSE, boundary_after_restart = FALSE,
  warm_restart_trigger_reason = "eligible_raw_gradient_at_or_above_0.01")
rejected <- accepted; rejected$warm_restart_accepted <- FALSE
rejected$convergence_code_after_restart <- 1L
invisible(cran07_v4_restart_evidence(no_restart))
invisible(cran07_v4_restart_evidence(accepted))
invisible(cran07_v4_restart_evidence(rejected))
bad_accept <- accepted; bad_accept$warm_restart_attempted <- FALSE
bad_objective <- accepted; bad_objective$objective_after_restart <- 10 + 1e-6
bad_gradient <- accepted; bad_gradient$max_gradient_after_restart <- 0.02
bad_after <- no_restart; bad_after$objective_after_restart <- 10
below_trigger <- accepted; below_trigger$max_gradient_before_restart <- 0.001
negative_gradient <- accepted; negative_gradient$max_gradient_before_restart <- -1
bad_before_code <- accepted; bad_before_code$convergence_code_before_restart <- 1L
bad_before_pd <- accepted; bad_before_pd$pd_hessian_before_restart <- FALSE
bad_before_boundary <- accepted; bad_before_boundary$boundary_before_restart <- TRUE
bad_after_pd <- accepted; bad_after_pd$pd_hessian_after_restart <- FALSE
bad_after_boundary <- accepted; bad_after_boundary$boundary_after_restart <- TRUE
bad_reason <- no_restart; bad_reason$warm_restart_trigger_reason <- "made_up"
for (x in list(NULL, bad_accept, bad_objective, bad_gradient, bad_after,
               below_trigger, negative_gradient, bad_before_code, bad_before_pd,
               bad_before_boundary, bad_after_pd, bad_after_boundary, bad_reason)) {
  stopifnot(inherits(try(cran07_v4_restart_evidence(x), silent = TRUE), "try-error"))
}
fit_adapter <- list(warm_restart_provenance = accepted)
stopifnot(cran07_v4_restart_record_from_fit(fit_adapter)$warm_restart_accepted,
  inherits(try(cran07_v4_restart_record_from_fit(list()), silent = TRUE), "try-error"))

# Attempt schema and every coordinate of the six-field bijection fail closed.
attempt <- make_attempt()
cran07_v4_validate_attempt_table(attempt)
id_manifest <- data.frame(campaign_id = attempt$campaign_id,
  registry_sha256 = attempt$registry_sha256,
  source_archive_sha256 = attempt$source_archive_sha256, cell_number = 1L,
  cell_id = attempt$cell_id, replicate = attempt$replicate, seed = attempt$seed)
cran07_v4_assert_attempt_manifest_identity(attempt, id_manifest)
for (field in CRAN07_V4_IDENTITY_COLUMNS) {
  bad <- id_manifest
  bad[[field]] <- if (is.numeric(bad[[field]])) bad[[field]] + 1L else
    paste0(bad[[field]], "x")
  stopifnot(inherits(try(cran07_v4_assert_attempt_manifest_identity(attempt, bad),
                         silent = TRUE), "try-error"))
}

# Exact structural-zero Psi normalization accepts zero and rejects any drift.
psi <- data.frame(cell_id = "p", replicate = 1L, seed = 1L, estimand = "Psi",
  component = c("t1_t1", "t2_t1"), trait_i = c(1L, 2L), trait_j = c(1L, 1L),
  applicable = TRUE, truth = c(1, 0), estimate = c(1, 0))
normalized <- cran07_v4_normalize_structural_psi(psi)
psi_inactive <- psi
psi_inactive$applicable[[2L]] <- FALSE
psi_inactive$estimate[[2L]] <- NA_real_
normalized_inactive <- cran07_v4_normalize_structural_psi(psi_inactive)
stopifnot(identical(normalized$applicable, c(TRUE, FALSE)),
  identical(normalized_inactive$applicable, c(TRUE, FALSE)))
psi_bad <- psi; psi_bad$estimate[[2L]] <- .Machine$double.eps
psi_hidden_bad <- psi; psi_hidden_bad$applicable[[2L]] <- FALSE
psi_hidden_bad$truth[[2L]] <- psi_hidden_bad$estimate[[2L]] <- 999
stopifnot(inherits(try(cran07_v4_normalize_structural_psi(psi_bad), silent = TRUE),
                     "try-error"),
  inherits(try(cran07_v4_normalize_structural_psi(psi_hidden_bad), silent = TRUE),
           "try-error"))

# Pilot: exact 3/20 accepts, 4/20 rejects, and any unclassified result rejects.
pilot_attempts <- function(unusable = 0L, unknown = FALSE) {
  z <- data.frame(cell_id = "cell", status = rep("usable", 20L),
    finite_estimands = TRUE, stationary = TRUE, pd_hessian = TRUE)
  if (unusable) z$status[seq_len(unusable)] <- "boundary"
  if (unknown) z$status[[20L]] <- NA_character_
  z
}
stopifnot(cran07_v4_pilot_admission(pilot_attempts(3L), "cell")$admitted,
  !cran07_v4_pilot_admission(pilot_attempts(4L), "cell")$admitted,
  !cran07_v4_pilot_admission(pilot_attempts(0L, TRUE), "cell")$admitted)

# Global detector denominators and immutable challenge-cell exclusion.
global <- do.call(rbind, lapply(seq_len(nrow(all_cells)), function(i) data.frame(
  campaign_id = all_cells$campaign_id[[i]], cell_id = all_cells$cell_id[[i]],
  status = "usable", finite_estimands = TRUE, stationary = TRUE,
  pd_hessian = TRUE, catastrophic_truth_error = FALSE, detector_flagged = FALSE,
  stringsAsFactors = FALSE)[rep(1L, 20L), ]))
global$catastrophic_truth_error[1:20] <- TRUE
global$detector_flagged[1:19] <- TRUE
global$detector_flagged[21:86] <- TRUE
stopifnot(cran07_v4_pilot_global_gate(global, all_cells)$pass,
  !cran07_v4_pilot_global_gate(global[-1L, ], all_cells)$pass)
verdict <- cran07_v4_pilot_verdict(global, all_cells)
stopifnot(verdict$production_authorized, nrow(verdict$admitted_cells) == 31L,
  nrow(verdict$held_cells) == 3L,
  setequal(verdict$held_cells$cell_id, CRAN07_V4_HELD_CHALLENGE_CELLS))
forged <- verdict$cell_admission
bad_cell <- all_cells$cell_id[[1L]]
global$status[global$cell_id == bad_cell] <- "boundary"
global$detector_flagged[global$cell_id == bad_cell] <- TRUE
forged$admitted[forged$cell_id == bad_cell] <- TRUE
stopifnot(inherits(try(cran07_v4_pilot_verdict(global, all_cells, forged),
                      silent = TRUE), "try-error"),
  !cran07_v4_pilot_verdict(global, all_cells)$cell_admission$admitted[
    cran07_v4_pilot_verdict(global, all_cells)$cell_admission$cell_id == bad_cell])
global$catastrophic_truth_error <- FALSE
stopifnot(!cran07_v4_pilot_global_gate(global, all_cells)$pass)

# Stored pilot decisions cannot override retained attempts.
core_pilot_manifest <- cran07_v4_manifest(core, "cran07-core-recovery-v4",
                                          "pilot", sha)
core_pilot_attempts <- make_attempt(nrow(core_pilot_manifest))
for (nm in CRAN07_V4_IDENTITY_COLUMNS) {
  core_pilot_attempts[[nm]] <- core_pilot_manifest[[nm]]
}
core_pilot_gate <- cran07_v4_pilot_admission(core_pilot_attempts, core$cell_id)
core_pilot_summary <- list(v4_identity = list(
  campaign_id = "cran07-core-recovery-v4", stage = "pilot", complete = TRUE,
  registry_sha256 = CRAN07_CORE_SHA256, source_archive_sha256 = sha,
  manifest_sha256 = cran07_v4_manifest_sha256(core_pilot_manifest),
  expected_cells = sort(core$cell_id), expected_attempts = nrow(core_pilot_manifest),
  observed_attempts = nrow(core_pilot_manifest)), attempts = core_pilot_attempts,
  v4_gate = core_pilot_gate)
invisible(cran07_v4_validate_pilot_summary(core_pilot_summary, core,
                                           "cran07-core-recovery-v4"))
corrupt_summary <- core_pilot_summary
corrupt_summary$v4_gate$admitted[[1L]] <- !corrupt_summary$v4_gate$admitted[[1L]]
stopifnot(inherits(try(cran07_v4_validate_pilot_summary(corrupt_summary, core,
  "cran07-core-recovery-v4"), silent = TRUE), "try-error"))

# Every estimand component is joined to a six-field attempt and manifest key.
join_cell <- "g_indep_n60"
join_registry <- core[core$cell_id == join_cell, , drop = FALSE]
attr(join_registry, "sha256") <- attr(core, "sha256")
attr(join_registry, "campaign_id") <- "cran07-core-recovery-v4"
join_manifest <- cran07_v4_manifest(core, "cran07-core-recovery-v4", "smoke",
                                    sha, join_cell)
join_attempts <- make_attempt(nrow(join_manifest), cell = join_cell)
for (nm in CRAN07_V4_IDENTITY_COLUMNS) join_attempts[[nm]] <- join_manifest[[nm]]
join_schema <- cran07_v4_expected_component_schema(join_registry,
                                                   "cran07-core-recovery-v4")
join_estimands <- do.call(rbind, lapply(seq_len(nrow(join_manifest)), function(i) {
  z <- join_schema
  for (nm in CRAN07_V4_IDENTITY_COLUMNS) z[[nm]] <- join_manifest[[nm]][[i]]
  z$applicable <- TRUE; z$truth <- 1; z$estimate <- 1
  component_match <- regmatches(z$component,
    regexec("^t([0-9]+)_t([0-9]+)$", z$component))
  z$trait_i <- vapply(component_match, function(x)
    if (length(x) == 3L) as.integer(x[[2L]]) else NA_integer_, integer(1L))
  z$trait_j <- vapply(component_match, function(x)
    if (length(x) == 3L) as.integer(x[[3L]]) else NA_integer_, integer(1L))
  z
}))
cran07_v4_validate_estimand_identity(join_estimands, join_attempts, join_manifest,
                                     join_registry, "cran07-core-recovery-v4")
cran07_v4_validate_truth_metrics(join_attempts, join_estimands)
bad_seed_estimands <- join_estimands; bad_seed_estimands$seed[[1L]] <-
  bad_seed_estimands$seed[[1L]] + 1L
missing_estimand <- join_estimands[-1L, , drop = FALSE]
unexpected_estimand <- join_estimands
unexpected_estimand$component[[1L]] <- "unexpected"
for (z in list(bad_seed_estimands, missing_estimand, unexpected_estimand)) {
  stopifnot(inherits(try(cran07_v4_validate_estimand_identity(
    z, join_attempts, join_manifest, join_registry,
    "cran07-core-recovery-v4"), silent = TRUE), "try-error"))
}

# A full 1,600-attempt production ledger cannot forge catastrophic Sigma as benign.
truth_manifest <- cran07_v4_manifest(core, "cran07-core-recovery-v4",
  "production", sha, join_cell)
truth_attempts <- make_attempt(nrow(truth_manifest), cell = join_cell)
for (nm in CRAN07_V4_IDENTITY_COLUMNS) {
  truth_attempts[[nm]] <- truth_manifest[[nm]]
}
truth_estimands <- do.call(rbind, lapply(seq_len(nrow(truth_manifest)), function(i) {
  z <- join_schema
  for (nm in CRAN07_V4_IDENTITY_COLUMNS) z[[nm]] <- truth_manifest[[nm]][[i]]
  component_match <- regmatches(z$component,
    regexec("^t([0-9]+)_t([0-9]+)$", z$component))
  z$trait_i <- vapply(component_match, function(x)
    if (length(x) == 3L) as.integer(x[[2L]]) else NA_integer_, integer(1L))
  z$trait_j <- vapply(component_match, function(x)
    if (length(x) == 3L) as.integer(x[[3L]]) else NA_integer_, integer(1L))
  diagonal <- !is.na(z$trait_i) & z$trait_i == z$trait_j
  z$applicable <- TRUE
  z$truth <- z$estimate <- 0
  z$truth[z$estimand %in% c("Psi", "Sigma_total") & diagonal] <- 1
  z$estimate <- z$truth
  z
}))
cran07_v4_validate_estimand_identity(truth_estimands, truth_attempts,
  truth_manifest, join_registry, "cran07-core-recovery-v4")
cran07_v4_validate_truth_metrics(truth_attempts, truth_estimands)
forged_benign <- truth_estimands
catastrophic_sigma <- forged_benign$estimand == "Sigma_total" &
  forged_benign$trait_i == forged_benign$trait_j
forged_benign$estimate[catastrophic_sigma] <- 100
stopifnot(nrow(truth_attempts) == 1600L,
  all(!truth_attempts$catastrophic_truth_error),
  inherits(try(cran07_v4_validate_truth_metrics(truth_attempts, forged_benign),
               silent = TRUE), "try-error"),
  inherits(try(cran07_v4_production_gate(truth_attempts, forged_benign,
    join_registry, join_cell, "cran07-core-recovery-v4", truth_manifest),
    silent = TRUE), "try-error"))

# NB2 schema, 1:1600 completeness, bias boundary, and catastrophic ratio.
nb2_registry <- core[core$cell_id %in% c("nb2_latent_n100", "nb2_latent_n300"), ]
attr(nb2_registry, "sha256") <- attr(core, "sha256")
schema <- cran07_v4_expected_component_schema(nb2_registry,
                                              "cran07-core-recovery-v4")
stopifnot(all(c("t1", "t2", "t3") %in% schema$component[
  schema$estimand == "phi_nbinom2"]))
phi_rows <- function(est = 6, n = 1600L) do.call(rbind, lapply(paste0("t", 1:3),
  function(component) data.frame(cell_id = "nb2_latent_n100",
    replicate = seq_len(n), estimand = "phi_nbinom2", component = component,
    trait_i = as.integer(sub("t", "", component)),
    trait_j = as.integer(sub("t", "", component)), applicable = TRUE,
    truth = 5, estimate = est,
    campaign_id = "cran07-core-recovery-v4",
    registry_sha256 = CRAN07_CORE_SHA256,
    source_archive_sha256 = sha,
    seed = 670800000L + 9L * 100000L + seq_len(n))))
stopifnot(cran07_v4_phi_pass(phi_rows(6), "nb2_latent_n100", TRUE, 3L),
  !cran07_v4_phi_pass(phi_rows(6.01), "nb2_latent_n100", TRUE, 3L),
  !cran07_v4_phi_pass(phi_rows(6, 1599L), "nb2_latent_n100", TRUE, 3L))
sigma <- data.frame(cell_id = "x", replicate = 1L, seed = 1L,
  estimand = "Sigma_total", component = "t1_t1", trait_i = 1L, trait_j = 1L,
  applicable = TRUE, truth = 1, estimate = 1)
phi_cat <- data.frame(cell_id = "x", replicate = 1L, seed = 1L,
  estimand = "phi_nbinom2", component = "t1", trait_i = 1L, trait_j = 1L,
  applicable = TRUE, truth = 5, estimate = 50.0001)
stopifnot(cran07_v4_assess_estimands(rbind(sigma, phi_cat))$catastrophic_truth_error)

# Unequal named phi values are reordered by exact names; permutations cannot hide.
aligned <- cran07_v4_align_phi_nbinom2(c(t3 = 30, t2 = 20, t1 = 10),
                                       c("t1", "t2", "t3"))
stopifnot(identical(unname(aligned), c(10, 20, 30)),
  identical(names(aligned), c("t1", "t2", "t3")),
  inherits(try(cran07_v4_align_phi_nbinom2(c(t3 = 30, x = 20, t1 = 10),
    c("t1", "t2", "t3")), silent = TRUE), "try-error"))
engine_trait <- factor(c("t1", "t2", "t3", "t1"),
                       levels = c("t1", "t2", "t3"))
unnamed <- cran07_v4_align_phi_nbinom2(c(10, 20, 30), levels(engine_trait),
  engine_trait_id = as.integer(engine_trait) - 1L, data_trait = engine_trait)
stopifnot(identical(unname(unnamed), c(10, 20, 30)),
  inherits(try(cran07_v4_align_phi_nbinom2(c(10, 20, 30),
    levels(engine_trait)), silent = TRUE), "try-error"))

# Rank-one numerical zero is narrowly accepted; substantive error is not.
rank1 <- function(cell, error) data.frame(cell_id = cell, replicate = 1:1600,
  estimand = "correlation_shared", component = "t2_t1", trait_i = 2L,
  trait_j = 1L, applicable = TRUE, truth = 1, estimate = 1 + error,
  campaign_id = "cran07-core-recovery-v4",
  registry_sha256 = CRAN07_CORE_SHA256, source_archive_sha256 = sha,
  seed = 1:1600)
stopifnot(cran07_v4_numerical_zero(rank1("s", 2 * .Machine$double.eps),
                                   rank1("l", 3 * .Machine$double.eps)),
  !cran07_v4_numerical_zero(rank1("s", 2 * .Machine$double.eps),
                            rank1("l", 1e-8)))

# Closeout distinguishes scientific evidence from public promotion and cannot
# turn a subset into a broad PASS.
ids <- CRAN07_V4_CAMPAIGNS$campaign_id
pair_cells <- unique(c(CRAN07_V4_RMSE_PAIRS$small_cell,
                       CRAN07_V4_RMSE_PAIRS$large_cell))
subset_admitted <- rbind(
  data.frame(campaign_id = ids[[1L]], cell_id = pair_cells),
  data.frame(campaign_id = ids[[2L]], cell_id = registries[[ids[[2L]]]]$cell_id[[1L]]),
  data.frame(campaign_id = ids[[3L]], cell_id = registries[[ids[[3L]]]]$cell_id[[1L]]))
fake_summary <- function(id, admitted) {
  cells <- sort(admitted$cell_id[admitted$campaign_id == id])
  n <- as.integer(length(cells) * 1600L)
  canonical_manifest <- cran07_v4_manifest(registries[[id]], id, "production",
                                            sha, cells)
  list(v4_identity = list(campaign_id = id, stage = "production",
    complete = TRUE, registry_sha256 = cran07_v4_campaign_spec(id)$registry_sha256,
    source_archive_sha256 = sha,
    manifest_sha256 = cran07_v4_manifest_sha256(canonical_manifest),
    expected_attempts = n, observed_attempts = n, expected_cells = cells),
    v4_gate = data.frame(cell_id = cells, cell_pass = TRUE,
      component_schema_pass = TRUE, phi_nbinom2_bias_pass = TRUE),
    attempts = data.frame(catastrophic_truth_error = rep(FALSE, n),
      detector_flagged = rep(FALSE, n)), estimands = data.frame())
}
fake_pilot <- function(admitted) list(admitted_cells = admitted,
  held_cells = CRAN07_V4_PRODUCTION_ELIGIBLE[!paste(
    CRAN07_V4_PRODUCTION_ELIGIBLE$campaign_id,
    CRAN07_V4_PRODUCTION_ELIGIBLE$cell_id) %in%
    paste(admitted$campaign_id, admitted$cell_id), , drop = FALSE],
  production_authorized = TRUE, source_archive_sha256 = sha)
cran07_v4_rmse_pair_gate <- function(estimands, registry, pairs, B, seed)
  data.frame(pair_id = rep(pairs$pair_id, each = 1L), estimand = "mock",
    component = "mock", pass = TRUE)
subset_summaries <- stats::setNames(lapply(ids, fake_summary,
                                            admitted = subset_admitted), ids)
subset_summaries[[ids[[1L]]]]$attempts$catastrophic_truth_error[1:100] <- TRUE
subset_summaries[[ids[[1L]]]]$attempts$detector_flagged[1:100] <- TRUE
subset_closeout <- cran07_v4_production_closeout(subset_summaries,
  fake_pilot(subset_admitted), registries, B = 2L)
fenced_pairs <- subset_closeout$family_pair_gate$pair_id %in%
  c("gaussian_latent", "nb2_latent")
stopifnot(!subset_closeout$production_eligible_complete,
  subset_closeout$subset_execution_verdict == "HOLD",
  subset_closeout$release_verdict == "HOLD",
  all(subset_closeout$family_pair_gate$verdict[fenced_pairs] ==
        "CHARACTERIZATION_ONLY"),
  all(!subset_closeout$family_pair_gate$publicly_promotable[fenced_pairs]))
gaussian_public <- cran07_v4_public_pair_status("gaussian_latent", "PASS")
nb2_public <- cran07_v4_public_pair_status("nb2_latent", "PASS")
poisson_public <- cran07_v4_public_pair_status("poisson_latent", "PASS")
stopifnot(gaussian_public$verdict == "CHARACTERIZATION_ONLY",
  !gaussian_public$publicly_promotable,
  nb2_public$verdict == "CHARACTERIZATION_ONLY",
  !nb2_public$publicly_promotable,
  poisson_public$verdict == "PASS", poisson_public$publicly_promotable)

# CLI cannot override frozen sizes/cells and production requires pilot authority.
runner <- readLines(file.path(script_dir, "run-batch.R"), warn = FALSE)
launcher_source <- readLines(file.path(script_dir, "launch-bound-source.R"),
                             warn = FALSE)
stopifnot(any(grepl("--reps", runner, fixed = TRUE)),
  any(grepl("--cells", runner, fixed = TRUE)),
  any(grepl("--pilot-gate", runner, fixed = TRUE)),
  any(grepl("--load-all", runner, fixed = TRUE)),
  any(grepl("--source-archive", runner, fixed = TRUE)),
  any(grepl("--source-receipt", runner, fixed = TRUE)),
  any(grepl("cran07_v4_verify_bound_source", runner, fixed = TRUE)),
  any(grepl("GLLVMTMB_V4_BOUND_LIBRARY", runner, fixed = TRUE)),
  any(grepl("GLLVMTMB_V4_AUTHORITY_SHA", runner, fixed = TRUE)),
  any(grepl("GLLVMTMB_V4_LAUNCH_PARENT_PID", runner, fixed = TRUE)),
  any(grepl("GLLVMTMB_V4_LAUNCHER_PATH", runner, fixed = TRUE)),
  any(grepl("GLLVMTMB_V4_LAUNCHER_COMMAND_TOKEN", runner, fixed = TRUE)),
  any(grepl("launcher_uses_expression", runner, fixed = TRUE)),
  any(grepl("launcher_file_arguments", runner, fixed = TRUE)),
  any(grepl("wrapper_parent_pid", runner, fixed = TRUE)),
  any(grepl("unrecognized launcher-process intermediary", runner,
            fixed = TRUE)),
  any(grepl("authenticated detached launcher", runner, fixed = TRUE)),
  any(grepl("--verify-authority-only", runner, fixed = TRUE)),
  any(grepl("cran07_v4_read_external_authority", runner, fixed = TRUE)),
  any(grepl("Sys.readlink(present)", launcher_source, fixed = TRUE)),
  any(grepl("0555", launcher_source, fixed = TRUE)),
  any(grepl("complete extracted-payload batch", launcher_source,
            fixed = TRUE)),
  any(grepl("R CMD build", launcher_source, fixed = TRUE)) ||
    any(grepl("CMD\", \"build", launcher_source, fixed = TRUE)),
  any(grepl("R CMD install", launcher_source, fixed = TRUE)) ||
    any(grepl("CMD\", \"INSTALL", launcher_source, fixed = TRUE)),
  any(grepl("launch-bound-source", launcher_source, fixed = TRUE)))

cat(paste("v4_campaign_ids=OK", "stage_offsets=OK", "smoke_34x2=OK",
  "pilot_34x20=OK", "production_target_31x1600=OK",
  "six_field_identity=fail_closed", "restart_accept_reject=OK",
  "missing_restart_provenance=fail_closed", "structural_Psi_zero=OK",
  "pilot_3_of_20=PASS", "pilot_4_of_20=HOLD",
  "unclassified=HOLD", "global_detector=qualified",
  "challenge_cells=pilot_only", "NB2_phi_schema_bias_catastrophic=OK",
  "components_1600_exact=OK", "rank1_numerical_zero=bounded",
  "pilot_recomputed=OK", "estimands_six_field_join=OK",
  "truth_metrics_recomputed=forged_benign_rejected",
  "external_authority_scope=simulation_only",
  "public_fences=CHARACTERIZATION_ONLY", "broad_subset=HOLD",
  "canonical_source_binding=fail_closed",
  paste0("launch=", source_binding$status[[1L]]),
  "fits_run=0", sep = " "), "\n")
