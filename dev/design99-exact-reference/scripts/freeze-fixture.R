#!/usr/bin/env Rscript
# This is the sole materializer for the prospectively approved fixture.
d99_args <- commandArgs(trailingOnly = TRUE)
d99_arg <- function(flag, default = NULL) { i <- match(flag, d99_args); if (is.na(i)) default else d99_args[[i + 1L]] }
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
for (f in c("records.R", "numerics.R", "charts.R", "fixture.R")) source(file.path(d99_here, "R", f))
root <- d99_arg("--output-root"); gate_path <- d99_arg("--gate-receipt")
if (is.null(root) || is.null(gate_path)) stop("--output-root and --gate-receipt are required", call. = FALSE)
gate <- d99_read_json(gate_path)
if (is.null(gate) || !identical(gate$schema, "d99-mechanical-gates-v1") ||
    !identical(gate$status, "PASS") || isTRUE(gate$test_mode) ||
    !identical(gate$approved_fixture_seed_used, FALSE)) {
  stop("A non-mocked passing mechanical-gate receipt is required", call. = FALSE)
}
if (file.exists(file.path(root, "frozen-fixture.json"))) {
  stop("Frozen fixture already exists and cannot be replaced", call. = FALSE)
}
fixture <- d99_fixture()
if (!identical(fixture$seed, 9902401L) || nrow(fixture$y_full) != 2048L) {
  stop("The approved N2048 fixture was not produced", call. = FALSE)
}
prefixes <- lapply(names(fixture$prefixes), function(key) {
  y <- fixture$prefixes[[key]]
  list(n = nrow(y), response_hash = d99_sha256_object(y),
       response_matrix = lapply(seq_len(nrow(y)), function(i) as.integer(y[i, ])),
       pattern_counts = as.list(d99_fixture_pattern_counts(y)),
       pattern_count_hash = d99_sha256_object(d99_fixture_pattern_counts(y)),
       starts = lapply(c("C12", "C34"), function(chart) {
         out <- lapply(c(4, 8), function(cap) as.list(d99_start_coordinates(y, chart, cap)))
         names(out) <- paste0("cap", c(4, 8)); out
       }))
})
names(prefixes) <- names(fixture$prefixes)
for (key in names(prefixes)) names(prefixes[[key]]$starts) <- c("C12", "C34")
metadata <- list(schema = "d99-frozen-fixture-v1", status = "FROZEN", seed = fixture$seed,
  rng = fixture$rng, n_full = nrow(fixture$y_full), response_hash = fixture$response_hash,
  latent_hash = fixture$latent_hash, prefix_hashes = as.list(fixture$prefix_hashes),
  pattern_count_hashes = as.list(fixture$pattern_count_hashes), prefixes = prefixes,
  gate_receipt_sha256 = d99_sha256_file(gate_path), created_at = d99_now())
d99_write_exclusive_json(file.path(root, "frozen-fixture.json"), metadata)
cat("Design-99 fixture frozen: N2048 and nested prefixes\n")
