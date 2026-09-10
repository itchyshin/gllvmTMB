# Frozen v3 identity overlay for the CRAN 0.7 campaign.
#
# The DGP, registry bytes, attempt schema, and fit machinery remain the frozen
# v2 implementation.  V3 changes only seed identity and gate aggregation.

CRAN07_V3_CAMPAIGNS <- data.frame(
  campaign_id = c(
    "cran07-core-recovery-v3",
    "cran07-silent-failure-v3",
    "cran07-robustness-v3"
  ),
  registry_relpath = c(
    "docs/dev-log/simulation-artifacts/2026-08-08-cran07-core-recovery/registry.csv",
    "docs/dev-log/simulation-artifacts/2026-08-08-cran07-silent-failure/registry.csv",
    "docs/dev-log/simulation-artifacts/2026-08-08-cran07-robustness/registry.csv"
  ),
  registry_sha256 = c(
    CRAN07_CORE_SHA256,
    CRAN07_SILENT_FAILURE_SHA256,
    CRAN07_ROBUSTNESS_SHA256
  ),
  seed_offset = c(370800000L, 370810000L, 370820000L),
  stringsAsFactors = FALSE
)

cran07_v3_campaign_spec <- function(campaign_id) {
  hit <- which(CRAN07_V3_CAMPAIGNS$campaign_id == campaign_id)
  if (length(hit) != 1L) {
    stop("Unknown or non-v3 campaign ID: ", campaign_id, call. = FALSE)
  }
  CRAN07_V3_CAMPAIGNS[hit, , drop = FALSE]
}

cran07_v3_read_campaign_registry <- function(campaign_id, repo,
                                              registry_path = NULL) {
  spec <- cran07_v3_campaign_spec(campaign_id)
  canonical <- normalizePath(file.path(repo, spec$registry_relpath), mustWork = TRUE)
  supplied <- if (is.null(registry_path)) canonical else
    normalizePath(registry_path, mustWork = TRUE)
  if (!identical(supplied, canonical)) {
    stop("V3 campaign ID is cross-wired to a non-canonical registry path.",
         call. = FALSE)
  }
  registry <- cran07_read_registry(canonical, spec$registry_sha256)
  attr(registry, "campaign_id") <- campaign_id
  registry
}

# The immutable v2 attempt machinery resolves this name dynamically.  Once the
# overlay is sourced, v2 and unknown IDs therefore fail closed in both manifest
# construction and attempt execution.
cran07_campaign_seed_offset <- function(campaign_id) {
  as.integer(cran07_v3_campaign_spec(campaign_id)$seed_offset)
}

cran07_v3_manifest_sha256 <- function(manifest) {
  required <- c("campaign_id", "registry_sha256", "cell_number", "cell_id",
                "replicate", "seed")
  absent <- setdiff(required, names(manifest))
  if (length(absent)) {
    stop("Manifest is missing identity columns: ", paste(absent, collapse = ", "),
         call. = FALSE)
  }
  canonical <- manifest[order(manifest$campaign_id, manifest$cell_number,
                              manifest$replicate), required, drop = FALSE]
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  utils::write.table(canonical, tmp, sep = ",", row.names = FALSE,
                     col.names = TRUE, quote = TRUE, na = "NA", eol = "\n")
  cran07_sha256(tmp)
}

cran07_v3_validate_manifest <- function(manifest, registry, campaign_id,
                                         stage = c("pilot", "production"),
                                         expected_cells = NULL) {
  stage <- match.arg(stage)
  if (!is.data.frame(manifest) || !nrow(manifest)) {
    stop("V3 manifest must be a non-empty data frame.", call. = FALSE)
  }
  required <- c("campaign_id", "registry_sha256", "cell_number", "cell_id",
                "replicate", "seed")
  absent <- setdiff(required, names(manifest))
  if (length(absent)) {
    stop("V3 manifest is missing columns: ", paste(absent, collapse = ", "),
         call. = FALSE)
  }
  spec <- cran07_v3_campaign_spec(campaign_id)
  if (!identical(attr(registry, "sha256"), spec$registry_sha256) ||
      !identical(attr(registry, "campaign_id"), campaign_id)) {
    stop("Registry attributes do not match the selected frozen v3 campaign.",
         call. = FALSE)
  }
  if (anyNA(manifest[required]) || any(manifest$campaign_id != campaign_id) ||
      any(manifest$registry_sha256 != spec$registry_sha256)) {
    stop("Manifest identity does not match the selected frozen v3 campaign.",
         call. = FALSE)
  }
  key <- paste(manifest$campaign_id, manifest$cell_id, manifest$replicate, sep = "::")
  if (anyDuplicated(key)) stop("Manifest contains duplicate attempt keys.", call. = FALSE)
  registry_key <- stats::setNames(registry$cell_number, registry$cell_id)
  if (any(!manifest$cell_id %in% names(registry_key)) ||
      any(manifest$cell_number != unname(registry_key[manifest$cell_id]))) {
    stop("Manifest cells or cell numbers contradict the canonical registry.",
         call. = FALSE)
  }
  selected <- sort(unique(manifest$cell_id))
  expected_cells <- if (is.null(expected_cells)) {
    if (stage == "pilot") sort(registry$cell_id) else selected
  } else sort(unique(as.character(expected_cells)))
  if (!identical(selected, expected_cells) ||
      any(!expected_cells %in% registry$cell_id)) {
    stop("Manifest cell set is incomplete or not the declared admitted set.",
         call. = FALSE)
  }
  required_reps <- if (stage == "pilot") 20L else 400L
  counts <- table(factor(manifest$cell_id, levels = expected_cells))
  if (any(counts != required_reps)) {
    stop("V3 ", stage, " requires exactly ", required_reps,
         " manifest rows for every selected cell.", call. = FALSE)
  }
  for (cell in expected_cells) {
    z <- manifest[manifest$cell_id == cell, , drop = FALSE]
    if (!identical(sort(as.integer(z$replicate)), seq_len(required_reps))) {
      stop("Manifest replicates must be the complete 1:", required_reps,
           " sequence for cell ", cell, ".", call. = FALSE)
    }
    expected_seed <- vapply(seq_len(required_reps), function(r) {
      cran07_seed(registry_key[[cell]], r, cran07_campaign_seed_offset(campaign_id))
    }, integer(1L))
    actual_seed <- z$seed[match(seq_len(required_reps), z$replicate)]
    if (!identical(as.integer(actual_seed), expected_seed)) {
      stop("Manifest seeds contradict the frozen v3 seed rule for cell ", cell,
           ".", call. = FALSE)
    }
  }
  invisible(TRUE)
}
