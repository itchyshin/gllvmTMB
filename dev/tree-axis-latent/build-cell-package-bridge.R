#!/usr/bin/env Rscript
# Immutable evidence bridge for the two package-compatibility repairs only.
# Sourcing defines the validator without writing; executing builds one receipt.
# This establishes unchanged article inputs/starts, not package-check success.
.cell_bridge_root <- "/private/tmp/gllvm-tree-axis-latent-20260830/cell-integration-7c88"
.cell_bridge_path <- file.path(.cell_bridge_root, "package-source-bridge-v2.rds")

.cell_bridge_validate <- function(bridge = NULL) {
  root <- .cell_bridge_root
  sha <- function(path) digest::digest(file = path, algo = "sha256")
  paths <- c(list.files("R", pattern = "[.]R$", full.names = TRUE),
    "src/gllvmTMB.cpp", "inst/include/gllvmTMB/detail/column_prior.hpp", "NAMESPACE", "DESCRIPTION")
  parent_path <- file.path(root, "provenance-v2.json")
  parent <- jsonlite::read_json(parent_path, simplifyVector = TRUE)
  stopifnot(length(paths) == 118L, setequal(names(parent$source_sha256), paths),
    !anyDuplicated(names(parent$source_sha256)))
  current <- list(library = normalizePath(find.package("gllvmTMB")),
    dll_sha256 = sha(file.path(find.package("gllvmTMB"), "libs/gllvmTMB.so")),
    fixture_md5 = unname(tools::md5sum("dev/tree-axis-latent/fixture.R")),
    source_sha256 = as.list(setNames(vapply(paths, sha, character(1)), paths)))
  stopifnot(identical(current$fixture_md5, "6c3bae640dd86491171cb20fbb56b0e4"),
    identical(parent$fixture_md5, current$fixture_md5))
  changed <- paths[!vapply(paths, function(path)
    identical(current$source_sha256[[path]], parent$source_sha256[[path]]), logical(1))]
  stopifnot(setequal(changed, c("R/fit-multi.R", "R/init-warmstart.R")), length(changed) == 2L)

  # The rebuilt DLL has a different whole-file hash because build metadata
  # changes. Recompute the binary audit, not merely its stored verdict: every
  # loadable section, dyld payload and all bytes outside named metadata match.
  binary_path <- file.path(root, "package-dll-equivalence-1.json")
  binary_script <- "dev/tree-axis-latent/check-cell-dll-equivalence.py"
  binary_output <- system2("python3", c(shQuote(binary_script), "--verify", shQuote(binary_path)),
                           stdout = TRUE, stderr = TRUE)
  stopifnot(is.null(attr(binary_output, "status")) || attr(binary_output, "status") == 0L)
  binary <- jsonlite::read_json(binary_path, simplifyVector = FALSE)
  stopifnot(identical(binary$schema, "tree-axis-cell-mach-o-equivalence-v1"),
    isTRUE(binary$equivalent), length(binary$sections) == 15L, length(binary$dyld) == 5L,
    binary$model_evaluations == 0L, binary$outer_optimizer_calls == 0L,
    identical(binary$old_file$sha256, parent$dll_sha256),
    identical(binary$new_file$sha256, current$dll_sha256),
    identical(binary$auditor_sha256, sha(binary_script)))

  comparison_path <- file.path(root, "package-continuity-compare-1.rds")
  comparison <- readRDS(comparison_path)
  old_dir <- file.path(root, "package-continuity-old-1")
  new_dir <- file.path(root, "package-continuity-new-1")
  old <- readRDS(file.path(old_dir, "receipt.rds"))
  new <- readRDS(file.path(new_dir, "receipt.rds"))
  ids <- c("G1", "G2", "G3", "GW1", "GW2", "GW3")
  check_names <- c("data", "parameters", "map", "random", "rng", "reconstructed_starts", "retained_starts")
  stopifnot(isTRUE(comparison$pass), identical(names(comparison$checks), ids),
    identical(old$ids, ids), identical(new$ids, ids),
    identical(comparison$old_metadata, old$metadata), identical(comparison$new_metadata, new$metadata),
    identical(comparison$old_receipt_sha256, sha(file.path(old_dir, "receipt.rds"))),
    identical(comparison$new_receipt_sha256, sha(file.path(new_dir, "receipt.rds"))),
    identical(old$metadata$R, new$metadata$R), identical(new$metadata$R, R.version.string),
    identical(old$metadata$TMB, new$metadata$TMB),
    identical(new$metadata$TMB, as.character(utils::packageVersion("TMB"))),
    identical(parent$library, old$metadata$library),
    identical(parent$dll_sha256, old$metadata$dll_sha256),
    identical(current$library, new$metadata$library),
    identical(current$dll_sha256, new$metadata$dll_sha256),
    identical(new$metadata$fit_function_sha256,
      digest::digest(getFromNamespace("gllvmTMB_multi_fit", "gllvmTMB"), algo = "sha256")))
  for (receipt in list(comparison, old, new)) {
    count <- if (is.null(receipt$optimizer_entries)) receipt$outer_optimizer_calls else receipt$optimizer_entries
    stopifnot(identical(count, 0L), identical(receipt$tapes_constructed, 0L))
  }
  count_starts <- 0L
  payload_hashes <- setNames(vector("list", length(ids)), ids)
  for (id in ids) {
    # Recheck the payloads and all original starts; a stored TRUE is not proof.
    a_path <- file.path(old_dir, paste0(id, ".rds"))
    b_path <- file.path(new_dir, paste0(id, ".rds"))
    a <- readRDS(a_path)
    b <- readRDS(b_path)
    retained_path <- file.path(root, paste0("fit-", id, ".rds"))
    retained <- readRDS(retained_path)
    stopifnot(identical(retained$provenance, parent),
      identical(a$retained_receipt_sha256, sha(retained_path)),
      identical(b$retained_receipt_sha256, sha(retained_path)),
      identical(names(comparison$checks[[id]]), check_names),
      all(comparison$checks[[id]]), a$intercepted_entries == 1L, b$intercepted_entries == 1L)
    retained_fields <- c(data = "tmb_data", parameters = "tmb_params", map = "tmb_map", random = "random")
    for (field in names(retained_fields)) {
      stopifnot(identical(a$payload[[field]], retained$fit[[retained_fields[[field]]]]))
    }
    for (field in c("data", "parameters", "map", "random", "rng")) {
      stopifnot(identical(a$payload[[field]], b$payload[[field]]))
    }
    stopifnot(identical(a$reconstructed_starts, b$reconstructed_starts),
      length(a$reconstructed_starts) == length(retained$optimizer_calls))
    for (i in seq_along(retained$optimizer_calls)) {
      stopifnot(identical(a$reconstructed_starts[[i]], retained$optimizer_calls[[i]]$start))
      count_starts <- count_starts + 1L
    }
    payload_hashes[[id]] <- list(old = sha(a_path), new = sha(b_path), retained = sha(retained_path))
  }
  stopifnot(count_starts == 12L)
  validated <- list(schema = "tree-axis-cell-package-source-bridge-v2",
    parent_manifest_sha256 = sha(parent_path), continuity_compare_sha256 = sha(comparison_path),
    dll_equivalence_receipt_sha256 = sha(binary_path), binary_auditor_sha256 = sha(binary_script),
    current_manifest = current, changed_source_paths = sort(changed),
    installed_fit_function_sha256 = new$metadata$fit_function_sha256,
    payload_sha256 = payload_hashes, payloads_identical = 6L, starts_identical = count_starts,
    retained_payload_bindings = 24L, file_backed_sections_identical = 15L, dyld_payloads_identical = 5L,
    outer_optimizer_calls = 0L, tapes_constructed = 0L,
    meaning = "Frozen article input and start continuity; not package-check acceptance")
  if (!is.null(bridge)) stopifnot(identical(bridge, validated))
  validated
}

if (sys.nframe() == 0L) {
  library(gllvmTMB)
  stopifnot(!file.exists(.cell_bridge_path))
  bridge <- .cell_bridge_validate()
  saveRDS(bridge, .cell_bridge_path)
  # Exercise the same strict read-back validation used by the current checker.
  invisible(.cell_bridge_validate(readRDS(.cell_bridge_path)))
  cat("CELL_PACKAGE_SOURCE_BRIDGE_PASS 118 sources; exactly two R repairs; six payloads and twelve starts identical; 24 retained bindings; DLL sections identical\n",
      "No fits/tapes/optimizers; package-check status remains separate.\n", sep = "")
}
