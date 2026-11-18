## Fixture construction for the prospective baseline-versus-rep3 study.
## Sourceable in a repository checkout; no function here starts a model fit.

.isdm_respinfo_root <- function() {
  candidates <- c(getwd(), dirname(normalizePath(sys.frame(1)$ofile %||% ".",
                                                   mustWork = FALSE)))
  for (candidate in candidates) {
    root <- normalizePath(candidate, mustWork = FALSE)
    while (dirname(root) != root) {
      if (file.exists(file.path(root, "dev", "isdm-requalification", "fixture.R"))) {
        return(root)
      }
      root <- dirname(root)
    }
  }
  stop("cannot locate repository root", call. = FALSE)
}

.isdm_respinfo_source_dependencies <- function(root = .isdm_respinfo_root()) {
  source(file.path(root, "dev", "isdm-requalification", "response-information",
                   "contract.R"), local = .GlobalEnv)
  source(file.path(root, "dev", "isdm-requalification", "fixture.R"),
         local = .GlobalEnv)
  source(file.path(root, "dev", "isdm-requalification", "diagnostic-rescue",
                   "diagnostics.R"), local = .GlobalEnv)
  invisible(root)
}

.isdm_respinfo_fixture_abort <- function(message) {
  .isdm_respinfo_abort(message, "isdm_respinfo_fixture_contract_invalid")
}

isdm_respinfo_data_sha256 <- function(data) {
  path <- tempfile("response-information-baseline-", fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(data, path, version = 3)
  out <- system2("sha256sum", path, stdout = TRUE, stderr = TRUE)
  if (length(out) != 1L || !identical(as.integer(attr(out, "status") %||% 0L), 0L)) {
    .isdm_respinfo_fixture_abort("cannot hash baseline data")
  }
  sub("[[:space:]].*$", "", out)
}

isdm_respinfo_rep3_fixture <- function(fixture, rep3_seed_1, rep3_seed_2) {
  baseline <- fixture$data
  baseline_hash <- isdm_respinfo_data_sha256(baseline)
  seeds <- as.integer(c(rep3_seed_1, rep3_seed_2))
  if (length(seeds) != 2L || anyNA(seeds) || any(seeds < 1L) ||
      identical(seeds[[1L]], seeds[[2L]])) {
    .isdm_respinfo_fixture_abort("rep3 requires two distinct positive response seeds")
  }
  additions <- lapply(seeds, function(seed) {
    out <- baseline
    out$value <- .diagnostic_draw_response_stream(fixture, seed)
    out
  })
  combined <- do.call(rbind, c(list(baseline), additions))
  combined$replicate_id <- rep(1:3, each = nrow(baseline))
  if (!identical(combined[seq_len(nrow(baseline)), names(baseline), drop = FALSE],
                 baseline)) {
    .isdm_respinfo_fixture_abort("rep3 construction changed baseline rows")
  }
  fixture$data <- combined
  fixture$design$baseline_data_sha256 <- baseline_hash
  fixture$design$replication <- 3L
  fixture$design$replicate_seeds <- seeds
  fixture$design$replicate_seed_rule <- "immutable plan columns rep3_seed_1 and rep3_seed_2"
  fixture
}

isdm_respinfo_fixture <- function(task) {
  if (!is.data.frame(task) || nrow(task) != 1L) {
    .isdm_respinfo_fixture_abort("fixture construction requires one plan row")
  }
  required <- c("variant", "structure_seed", "observation_seed", "n_sources",
                "n_cells", "overlap", "rep3_seed_1", "rep3_seed_2")
  if (!all(required %in% names(task))) {
    .isdm_respinfo_fixture_abort("task lacks required fixture columns")
  }
  fixture <- isdm_nonspatial_fixture(
    seed = task$structure_seed[[1L]], observation_seed = task$observation_seed[[1L]],
    n_sources = task$n_sources[[1L]], n_cells = task$n_cells[[1L]],
    overlap = task$overlap[[1L]]
  )
  fixture$design$baseline_data_sha256 <- isdm_respinfo_data_sha256(fixture$data)
  variant <- as.character(task$variant[[1L]])
  if (identical(variant, "baseline")) {
    if (!is.na(task$rep3_seed_1[[1L]]) || !is.na(task$rep3_seed_2[[1L]])) {
      .isdm_respinfo_fixture_abort("baseline task may not carry added response seeds")
    }
    return(fixture)
  }
  if (!identical(variant, "rep3")) {
    .isdm_respinfo_fixture_abort("unknown replication variant")
  }
  isdm_respinfo_rep3_fixture(fixture, task$rep3_seed_1[[1L]], task$rep3_seed_2[[1L]])
}

.isdm_respinfo_source_dependencies()
