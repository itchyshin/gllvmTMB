#!/usr/bin/env Rscript
# One-shot preflight and immutable input construction.  It never launches a worker.
d99_args <- commandArgs(trailingOnly = TRUE)
d99_arg <- function(flag, default = NULL) { i <- match(flag, d99_args); if (is.na(i)) default else d99_args[[i + 1L]] }
d99_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L])
d99_here <- normalizePath(file.path(dirname(d99_file), ".."), mustWork = TRUE)
d99_default_repo <- normalizePath(file.path(d99_here, "..", ".."), mustWork = TRUE)
d99_test_mode <- "--test-mode" %in% d99_args
d99_dry_run <- "--dry-run" %in% d99_args
d99_repo <- normalizePath(d99_arg("--repo-root", d99_default_repo), mustWork = TRUE)
if (!identical(d99_repo, d99_default_repo) && !d99_test_mode) stop("--repo-root is test-only", call. = FALSE)
if (d99_dry_run && !d99_test_mode) stop("--dry-run is test-only", call. = FALSE)
for (f in c("records.R", "numerics.R", "charts.R", "aghq.R", "task-graph.R")) source(file.path(d99_here, "R", f))
root <- d99_arg("--output-root"); fixture_root <- d99_arg("--fixture-root"); route_path <- d99_arg("--compute-route")
if (is.null(root) || is.null(fixture_root) || is.null(route_path)) stop("--output-root, --fixture-root, and --compute-route are required", call. = FALSE)
if (!d99_test_mode && !identical(normalizePath(root, mustWork = FALSE), normalizePath(file.path(d99_here, "results"), mustWork = FALSE))) stop("REAL_RUN output root is fixed at the Design-99 results directory", call. = FALSE)
if (!d99_test_mode && !identical(normalizePath(root, mustWork = FALSE), normalizePath(file.path(d99_here, "results"), mustWork = FALSE))) {
  stop("The real output root is fixed by the contract", call. = FALSE)
}
if (file.exists(root)) stop("Real output root must not already exist", call. = FALSE)
if (length(system2("git", c("-C", d99_repo, "status", "--porcelain"), stdout = TRUE, stderr = TRUE))) stop("A committed clean head is required", call. = FALSE)
fixture <- d99_read_json(file.path(fixture_root, "frozen-fixture.json")); route <- d99_read_json(route_path)
if (is.null(fixture) || !identical(fixture$schema, "d99-frozen-fixture-v1") || !identical(fixture$status, "FROZEN") ||
    !identical(as.integer(fixture$seed), 9902401L) || is.null(route) ||
    !identical(route$schema, "d99-compute-route-v1") || !identical(route$status, "PASS") ||
    !identical(route$mode, "NON_EVIDENCE") || isTRUE(route$test_mode) || isTRUE(route$approved_fixture_seed_used) || isTRUE(route$real_uuid_used) ||
    isTRUE(route$mock_elapsed) || !route$route %in% c("LOCAL", "TOTORO")) stop("Frozen fixture or compute-route receipt is invalid", call. = FALSE)
if (d99_test_mode) {
  mocked_prelock <- d99_arg("--mock-prelock-receipt")
  if (is.null(mocked_prelock) || !file.exists(mocked_prelock)) stop("--mock-prelock-receipt is required in test mode", call. = FALSE)
  scan <- "TEST_RUNTIME_SCAN_PASS"; compare <- "TEST_COMPARE_PASS"; prelock <- paste(readLines(mocked_prelock, warn = FALSE), collapse = "\n")
} else {
  python <- Sys.which("python3"); if (!nzchar(python)) stop("python3 is required for provenance preflight", call. = FALSE)
  scanner <- file.path(d99_here, "provenance", "scan-design99-runtime.py")
  inventory <- file.path(d99_here, "provenance", "generate-protected-inventory.py")
  d99_run <- function(args) {
    old <- setwd(d99_repo); on.exit(setwd(old), add = TRUE)
    out <- system2(python, args, stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(out, "status"))) stop(paste(out, collapse = "\n"), call. = FALSE)
    paste(out, collapse = "\n")
  }
  scan <- d99_run(c(scanner, "--scope", "lane"))
  compare <- d99_run(c(inventory, "compare", "--scope", "lane"))
  prelock <- d99_run(c(inventory, "prelock", "--scope", "lane"))
}
rules <- lapply(c(9L, 15L, 21L, 31L), d99_gh_rule); names(rules) <- paste0("H", c(9L, 15L, 21L, 31L))
source_files <- sort(c(list.files(file.path(d99_here, "R"), full.names = TRUE), list.files(file.path(d99_here, "scripts"), full.names = TRUE)))
source_hashes <- as.list(vapply(source_files, d99_sha256_file, character(1))); names(source_hashes) <- sub(paste0("^", d99_repo, "/"), "", source_files)
contract <- file.path(d99_repo, "docs", "design", "99-exact-q2-reference-stabilization.md")
if (!file.exists(contract)) stop("The committed contract is missing", call. = FALSE)
contract_hash <- d99_sha256_file(contract)
run_id <- paste0(format(Sys.time(), tz = "UTC", format = "%Y%m%dT%H%M%S"), "-", Sys.getpid(), "-", substr(d99_sha256_object(list(contract_hash, fixture$response_hash, route$route)), 1L, 8L))
manifest <- list(schema = "d99-real-preflight-v1", preflight_status = "PASS", mode = "REAL_RUN", run_id = run_id,
  head = system2("git", c("-C", d99_repo, "rev-parse", "HEAD"), stdout = TRUE), contract_hash = contract_hash,
  fixture_sha256 = d99_sha256_file(file.path(fixture_root, "frozen-fixture.json")), compute_route_sha256 = d99_sha256_file(route_path), compute_route = route$route,
  provenance = list(runtime_scan_sha256 = d99_sha256_raw(charToRaw(scan)), compare_sha256 = d99_sha256_raw(charToRaw(compare)), prelock_sha256 = d99_sha256_raw(charToRaw(prelock))), created_at = d99_now())
stage <- paste0(root, ".stage-", Sys.getpid(), "-", substr(d99_sha256_object(run_id), 1L, 8L))
if (file.exists(stage)) stop("Preflight staging path already exists", call. = FALSE)
on.exit(if (file.exists(stage)) unlink(stage, recursive = TRUE), add = TRUE)
d99_write_exclusive_json(file.path(stage, "preflight.json"), manifest)
graph <- d99_build_task_graph(run_id)
for (task in graph) {
  key <- paste0("N", if (is.null(task$n)) 2048L else task$n)
  prefix <- fixture$prefixes[[key]]
  input <- d99_input_for_task(task, contract_hash, source_hashes, list(rules = rules),
    list(prefix_hashes = fixture$prefix_hashes, pattern_count_hashes = fixture$pattern_count_hashes,
      counts = lapply(fixture$prefixes, function(x) unlist(x$pattern_counts, use.names = FALSE)), response_hash = fixture$response_hash))
  optimizer_phase <- task$task_class %in% c("A-H9", "A-H15", "A-H31", "B-H15", "B-H31")
  input$start_coordinates <- if (optimizer_phase) prefix$starts[[task$chart]][[task$guard]] else list()
  input$mode <- "REAL_RUN"; input$preflight_hash <- d99_sha256_file(file.path(stage, "preflight.json")); input$compute_route <- route$route
  d99_write_task_input(stage, input)
}
if (!identical(length(list.files(file.path(stage, "inputs"), pattern = "\\.json$")), 208L)) stop("Staging did not produce 208 immutable inputs", call. = FALSE)
if (!file.rename(stage, root)) stop("Could not atomically adopt the validated staging root", call. = FALSE)
if (!d99_dry_run) d99_create_real_run(root, manifest)
cat(if (d99_dry_run) "Design-99 dry-run prepared 208 immutable inputs\n" else "Design-99 REAL_RUN prepared with 208 immutable inputs\n")
