## Sourced only by validate.R --coefficient. No fits/objective evaluations.
stopifnot(identical(normalizePath(result_dir),
  "/private/tmp/gllvm-tree-axis-latent-20260830/coefficient-standardization-7c88"),
  identical(fixture_checksum, "6c3bae640dd86491171cb20fbb56b0e4"))
ids <- c("Q2", "Q3", "QW2", "QW3")
paths <- setNames(file.path(result_dir, paste0("fit-", ids, ".rds")), ids)
receipts <- lapply(paths[file.exists(paths)], readRDS)
manifest_path <- file.path(result_dir, "provenance.json")
manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
expected_sources <- c(list.files("R", pattern = "[.]R$", full.names = TRUE), "src/gllvmTMB.cpp",
  "inst/include/gllvmTMB/detail/column_prior.hpp", "NAMESPACE", "DESCRIPTION")
stopifnot(setequal(names(manifest$source_sha256), expected_sources),
  !anyDuplicated(names(manifest$source_sha256)),
  identical(normalizePath(find.package("gllvmTMB")), manifest$library),
  identical(digest::digest(file = file.path(manifest$library, "libs/gllvmTMB.so"), algo = "sha256"), manifest$dll_sha256))
for (path in expected_sources) stopifnot(identical(
  digest::digest(file = path, algo = "sha256"), manifest$source_sha256[[path]]))
original_dir <- Sys.getenv("GLLVM_TREE_AXIS_ORIGINAL")
stopifnot(identical(normalizePath(original_dir), "/private/tmp/gllvm-tree-axis-latent-20260830/results"))
checks <- list()
for (id in names(receipts)) {
  r <- receipts[[id]]
  wide <- startsWith(id, "QW")
  n <- if (wide) 1L else 3L
  number <- as.integer(sub("^QW?", "", id))
  original <- paste0("M", number)
  model <- if (number == 2L) "community_iid" else "community_phylo"
  old <- readRDS(file.path(original_dir, paste0("fit-", original, ".rds")))
  ans <- one_fit(r)
  starts <- length(r$optimizer_calls) == n && all(vapply(seq_len(n), function(i)
    identical(r$optimizer_calls[[i]]$start, old$optimizer_calls[[i]]$start), logical(1)))
  controls <- length(r$optimizer_calls) == n && all(vapply(r$optimizer_calls, function(call)
    identical(call$control, list(eval.max = 2000, iter.max = 1500)) &&
      identical(call$argument_names, c("start", "objective", "gradient", "control")), logical(1)))
  physical <- isTRUE(r$physical_coefficients$pass) &&
    length(r$restart_snapshots$attempts) == n &&
    all(vapply(r$restart_snapshots$attempts, function(x) isTRUE(x$physical_coefficients$pass), logical(1)))
  ans$conditions <- c(ans$conditions,
    block = identical(r$validation_block, "coefficient-standardization-v1"),
    identity = identical(r$id, id) && identical(r$spec$model, model) &&
      identical(r$spec$shape, if (wide) "wide" else "long") &&
      identical(r$spec$size, "target") && identical(r$spec$original, original),
    current_source = identical(r$provenance, manifest),
    integrated_cells = isTRUE(r$integrated_gaussian_diag_B),
    standardized_coefficients = isTRUE(r$standardized_column_coef),
    physical_start = identical(r$fit$column_coef_physical_start, old$fit$tmb_params$b_phy_aug),
    physical_reports = physical,
    nlminb = is.null(r$spec$optimizer) || identical(r$spec$optimizer, "nlminb"),
    returned = length(r$optimizer_calls) == n, entries = identical(r$optimizer_entries, n),
    frozen_starts = starts, frozen_controls = controls)
  ans$pass <- all(ans$conditions %in% TRUE)
  checks[[id]] <- ans
}
stability <- lapply(receipts[intersect(c("Q2", "Q3"), names(receipts))], stability_check)
for (id in names(stability)) {
  gate <- list(schema = "tree-axis-coefficient-long-gate-v1", id = id,
    pass = isTRUE(checks[[id]]$pass) && isTRUE(stability[[id]]$pass),
    provenance_md5 = unname(tools::md5sum(manifest_path)),
    receipt_md5 = unname(tools::md5sum(paths[[id]])), checks = checks[[id]], stability = stability[[id]])
  path <- file.path(result_dir, paste0("gate-", id, ".rds"))
  if (file.exists(path)) stopifnot(identical(readRDS(path), gate)) else saveRDS(gate, path)
}
wide <- list()
for (i in 2:3) {
  pair <- c(paste0("Q", i), paste0("QW", i))
  if (all(pair %in% names(receipts))) wide[[pair[1L]]] <- wide_check(receipts[[pair[1L]]], receipts[[pair[2L]]])
}
negative <- TRUE
for (id in names(stability)) {
  r <- receipts[[id]]
  bad <- r; bad$restart_snapshots$attempts[[1L]]$convergence <- 1L
  negative <- negative && !stability_check(bad)$pass
  bad <- r; bad$restart_snapshots$attempts[[1L]]$max_gradient <- .02
  negative <- negative && !stability_check(bad)$pass
  bad <- r; bad$restart_snapshots$attempts[[2L]]$objective <- r$objective + abs(r$objective) * 1e-3
  negative <- negative && !stability_check(bad)$pass
  bad <- r; bad$restart_snapshots$attempts[[2L]]$covariance$unit$total <-
    2 * r$restart_snapshots$attempts[[1L]]$covariance$unit$total
  negative <- negative && !stability_check(bad)$pass
}
all_pass <- function(x) length(x) > 0L && all(vapply(x, function(z) isTRUE(z$pass), logical(1)))
complete <- all(ids %in% names(receipts)) && length(stability) == 2L && length(wide) == 2L
new_entries <- sum(vapply(receipts, function(r) r$optimizer_entries, integer(1)))
coefficient_ledger <- list(schema = "tree-axis-coefficient-validation-v1", ids = names(receipts),
  checks = checks, stability = stability, wide = wide,
  historical_entries = 33L, new_entries = new_entries, ceiling = 41L,
  negative_controls = negative, complete = complete,
  pass = complete && new_entries == 8L && 33L + new_entries <= 41L &&
    all_pass(checks) && all_pass(stability) && all_pass(wide) && negative)
path <- file.path(result_dir, paste0("validation-", paste(names(receipts), collapse = "-"), ".rds"))
if (file.exists(path)) stopifnot(identical(readRDS(path), coefficient_ledger)) else saveRDS(coefficient_ledger, path)
print(lapply(checks, function(x) x[c("pass", "objective", "gradient")]))
print(stability); print(wide)
if (coefficient_ledger$pass) cat("TREE_AXIS_COEFFICIENT_VALIDATION_PASS\n") else cat("TREE_AXIS_COEFFICIENT_VALIDATION_INCOMPLETE_OR_FAILED\n")
