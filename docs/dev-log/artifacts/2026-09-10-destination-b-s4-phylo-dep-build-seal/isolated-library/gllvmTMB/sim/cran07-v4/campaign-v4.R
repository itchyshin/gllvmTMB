# Frozen v4 identity and manifest contract for the CRAN 0.7 confirmation campaign.
# Scientific registries and DGPs remain byte-identical to v2/v3.

CRAN07_V4_CAMPAIGNS <- data.frame(
  campaign_id = c("cran07-core-recovery-v4", "cran07-silent-failure-v4",
                  "cran07-robustness-v4"),
  registry_relpath = c(
    "docs/dev-log/simulation-artifacts/2026-08-08-cran07-core-recovery/registry.csv",
    "docs/dev-log/simulation-artifacts/2026-08-08-cran07-silent-failure/registry.csv",
    "docs/dev-log/simulation-artifacts/2026-08-08-cran07-robustness/registry.csv"
  ),
  registry_sha256 = c(CRAN07_CORE_SHA256, CRAN07_SILENT_FAILURE_SHA256,
                      CRAN07_ROBUSTNESS_SHA256),
  smoke_offset = c(470800000L, 470810000L, 470820000L),
  pilot_offset = c(570800000L, 570810000L, 570820000L),
  production_offset = c(670800000L, 670810000L, 670820000L),
  stringsAsFactors = FALSE
)

CRAN07_V4_STAGE_REPS <- c(smoke = 2L, pilot = 20L, production = 1600L)
CRAN07_V4_HELD_CHALLENGE_CELLS <- c(
  "g_latent_rho_boundary98", "g_latent_psi_small", "g_latent_psi_large"
)
CRAN07_V4_PRODUCTION_ELIGIBLE <- data.frame(
  campaign_id = c(
    rep("cran07-core-recovery-v4", 15L),
    rep("cran07-silent-failure-v4", 8L),
    rep("cran07-robustness-v4", 8L)),
  cell_id = c(
    "g_indep_n60", "g_indep_n240", "g_dep_n60", "g_dep_n240",
    "g_latent_n60", "g_latent_n240", "p_latent_n100", "p_latent_n300",
    "nb2_latent_n100", "nb2_latent_n300", "b_logit_latent_n100",
    "b_logit_latent_n300", "g_latent_rho0", "g_latent_rho_pos08",
    "g_latent_rho_neg08",
    "sf_g_n60_l05_m0", "sf_g_n60_l3_m30", "sf_g_n150_l05_m30",
    "sf_g_n150_l3_m0", "sf_b_n60_l05_m30", "sf_b_n60_l3_m0",
    "sf_b_n150_l05_m0", "sf_b_n150_l3_m30",
    "rb_g_missing", "rb_g_rare", "rb_p_missing", "rb_p_rare",
    "rb_nb2_missing", "rb_nb2_rare", "rb_b_missing", "rb_b_rare"),
  stringsAsFactors = FALSE
)
CRAN07_V4_IDENTITY_COLUMNS <- c(
  "campaign_id", "registry_sha256", "source_archive_sha256",
  "cell_id", "replicate", "seed"
)
CRAN07_V4_SOURCE_RECEIPT_RELPATH <- file.path(
  "docs", "dev-log", "simulation-artifacts",
  "2026-08-08-cran07-v4-preregistration", "source-archive-binding.csv")
CRAN07_V4_PAYLOAD_MANIFEST_RELPATH <- file.path(
  "docs", "dev-log", "simulation-artifacts",
  "2026-08-08-cran07-v4-preregistration", "source-payload-manifest.csv")
CRAN07_V4_LAUNCHER_RELPATH <- file.path(
  "inst", "sim", "cran07-v4", "launch-bound-source.R")
CRAN07_V4_SHA_LEDGER_RELPATH <- file.path(
  "docs", "dev-log", "simulation-artifacts",
  "2026-08-08-cran07-v4-preregistration", "SHA256SUMS")
CRAN07_V4_SOURCE_RECEIPT_ID <- "cran07-v4-source-archive-binding-v1"
CRAN07_V4_AUTHORITY_ID <- "cran07-v4-simulation-authority-v1"
CRAN07_V4_AUTHORITY_PATHS <- c(
  "/private/tmp/gllvmtmb-cran07-v4-authority/launch-authority.csv",
  "/home/snakagaw/hsq_work/gllvmtmb-cran07-v4-20260808/authority/launch-authority.csv"
)
CRAN07_V4_SOURCE_RECEIPT_FIELDS <- c(
  "receipt_id", "status", "source_archive_file", "source_archive_path",
  "sha256", "source_payload_manifest_file",
  "source_payload_manifest_sha256", "source_payload_member_count",
  "sha_ledger_file", "sha_ledger_sha256",
  "launcher_file", "launcher_sha256", "launch_authorized")
CRAN07_V4_PAYLOAD_MANIFEST_FIELDS <- c(
  "path", "type", "mode", "bytes", "sha256")
CRAN07_V4_AUTHORITY_FIELDS <- c(
  "authority_id", "status", "scope", "receipt_id",
  "source_archive_file", "source_archive_sha256",
  "source_payload_manifest_file", "source_payload_manifest_sha256",
  "sha_ledger_file", "sha_ledger_sha256",
  "launcher_file", "launcher_sha256",
  "simulation_authorized", "release_authorized",
  "version_change_authorized", "publication_authorized",
  "cran_submission_authorized")
CRAN07_V4_ARCHIVE_ROOT <- "gllvmTMB"
CRAN07_V4_DETACHED_ENVELOPE_RELPATHS <- c(
  CRAN07_V4_SOURCE_RECEIPT_RELPATH,
  CRAN07_V4_PAYLOAD_MANIFEST_RELPATH,
  CRAN07_V4_LAUNCHER_RELPATH,
  CRAN07_V4_SHA_LEDGER_RELPATH)
CRAN07_V4_REQUIRED_ARCHIVE_RELPATHS <- c(
  "DESCRIPTION", "NAMESPACE", "R/fit-multi.R", "src/gllvmTMB.cpp",
  "inst/sim/cran07-v4/run-batch.R",
  "inst/sim/cran07-v4/build-source-archive.R")

cran07_v4_campaign_spec <- function(campaign_id) {
  hit <- which(CRAN07_V4_CAMPAIGNS$campaign_id == campaign_id)
  if (length(hit) != 1L) stop("Unknown or non-v4 campaign ID: ", campaign_id,
                              call. = FALSE)
  CRAN07_V4_CAMPAIGNS[hit, , drop = FALSE]
}

cran07_v4_read_campaign_registry <- function(campaign_id, repo,
                                              registry_path = NULL) {
  spec <- cran07_v4_campaign_spec(campaign_id)
  canonical <- normalizePath(file.path(repo, spec$registry_relpath), mustWork = TRUE)
  supplied <- if (is.null(registry_path)) canonical else
    normalizePath(registry_path, mustWork = TRUE)
  if (!identical(supplied, canonical)) {
    stop("V4 campaign ID is cross-wired to a non-canonical registry path.",
         call. = FALSE)
  }
  registry <- cran07_read_registry(canonical, spec$registry_sha256)
  attr(registry, "campaign_id") <- campaign_id
  registry
}

cran07_v4_seed_offset <- function(campaign_id, stage) {
  stage <- match.arg(stage, names(CRAN07_V4_STAGE_REPS))
  spec <- cran07_v4_campaign_spec(campaign_id)
  as.integer(spec[[paste0(stage, "_offset")]])
}

cran07_v4_production_cells <- function(campaign_id) {
  cran07_v4_campaign_spec(campaign_id)
  CRAN07_V4_PRODUCTION_ELIGIBLE$cell_id[
    CRAN07_V4_PRODUCTION_ELIGIBLE$campaign_id == campaign_id]
}

cran07_v4_file_sha256s <- function(paths) {
  paths <- normalizePath(paths, mustWork = TRUE)
  command <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else
    if (nzchar(Sys.which("shasum"))) "shasum" else ""
  if (!nzchar(command)) {
    stop("Neither sha256sum nor shasum is available for payload verification.",
         call. = FALSE)
  }
  prefix <- if (identical(command, "shasum")) c("-a", "256") else character()
  chunks <- split(seq_along(paths), ceiling(seq_along(paths) / 100L))
  answers <- lapply(chunks, function(index) {
    ans <- system2(command, c(prefix, shQuote(paths[index])),
                   stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(ans, "status")) || length(ans) != length(index)) {
      stop("Could not hash a complete v4 payload batch.", call. = FALSE)
    }
    ans
  })
  ans <- unlist(answers, use.names = FALSE)
  if (length(ans) != length(paths)) {
    stop("Could not hash the complete v4 payload inventory.", call. = FALSE)
  }
  hashes <- substr(ans, 1L, 64L)
  if (any(!grepl("^[0-9a-f]{64}$", hashes))) {
    stop("Could not parse every v4 payload SHA-256.", call. = FALSE)
  }
  unname(hashes)
}

cran07_v4_validate_payload_manifest <- function(manifest) {
  if (!is.data.frame(manifest) || !nrow(manifest) ||
      !identical(names(manifest), CRAN07_V4_PAYLOAD_MANIFEST_FIELDS) ||
      anyNA(manifest) || any(!nzchar(manifest$path)) ||
      anyDuplicated(manifest$path) ||
      !identical(manifest$path, sort(manifest$path, method = "radix")) ||
      any(startsWith(manifest$path, "/")) ||
      any(vapply(strsplit(manifest$path, "/", fixed = TRUE),
                 function(x) any(x == ".."), logical(1L))) ||
      any(manifest$type != "file") ||
      any(!manifest$mode %in% c("0644", "0755")) ||
      any(!is.finite(manifest$bytes) | manifest$bytes < 0 |
            manifest$bytes != floor(manifest$bytes)) ||
      any(!grepl("^[0-9a-f]{64}$", manifest$sha256)) ||
      length(setdiff(CRAN07_V4_REQUIRED_ARCHIVE_RELPATHS, manifest$path)) ||
      any(CRAN07_V4_DETACHED_ENVELOPE_RELPATHS %in% manifest$path)) {
    stop("V4 source-payload manifest is unsafe, incomplete, or non-canonical.",
         call. = FALSE)
  }
  invisible(manifest)
}

cran07_v4_validate_source_binding <- function(receipt, archive_path,
                                               payload_manifest_path,
                                               sha_ledger_path,
                                               launcher_path) {
  archive <- normalizePath(archive_path, mustWork = TRUE)
  payload_manifest_path <- normalizePath(payload_manifest_path, mustWork = TRUE)
  sha_ledger_path <- normalizePath(sha_ledger_path, mustWork = TRUE)
  launcher_path <- normalizePath(launcher_path, mustWork = TRUE)
  if (dir.exists(archive) || file.info(archive)$size <= 0) {
    stop("V4 source archive must be one nonempty regular file.", call. = FALSE)
  }
  if (!is.data.frame(receipt) || nrow(receipt) != 1L ||
      !identical(names(receipt), CRAN07_V4_SOURCE_RECEIPT_FIELDS) ||
      !identical(receipt$receipt_id[[1L]], CRAN07_V4_SOURCE_RECEIPT_ID) ||
      !identical(receipt$status[[1L]], "READY") ||
      !is.logical(receipt$launch_authorized) ||
      !identical(receipt$launch_authorized[[1L]], TRUE) ||
      !identical(receipt$source_archive_file[[1L]], basename(archive)) ||
      !is.character(receipt$source_archive_path) ||
      !nzchar(receipt$source_archive_path[[1L]]) ||
      !identical(normalizePath(receipt$source_archive_path[[1L]], mustWork = TRUE),
                 archive) ||
      !grepl("^[0-9a-f]{64}$", receipt$sha256[[1L]]) ||
      !identical(receipt$source_payload_manifest_file[[1L]],
                 basename(payload_manifest_path)) ||
      !grepl("^[0-9a-f]{64}$",
             receipt$source_payload_manifest_sha256[[1L]]) ||
      !is.numeric(receipt$source_payload_member_count) ||
      length(receipt$source_payload_member_count) != 1L ||
      !is.finite(receipt$source_payload_member_count[[1L]]) ||
      receipt$source_payload_member_count[[1L]] < 1 ||
      receipt$source_payload_member_count[[1L]] !=
        floor(receipt$source_payload_member_count[[1L]]) ||
      !identical(receipt$sha_ledger_file[[1L]], basename(sha_ledger_path)) ||
      !grepl("^[0-9a-f]{64}$", receipt$sha_ledger_sha256[[1L]]) ||
      !identical(receipt$launcher_file[[1L]], basename(launcher_path)) ||
      !grepl("^[0-9a-f]{64}$", receipt$launcher_sha256[[1L]])) {
    stop("Canonical source binding is not READY, authorized, or exact.",
         call. = FALSE)
  }
  actual <- cran07_sha256(archive)
  if (!identical(actual, receipt$sha256[[1L]])) {
    stop("Computed source-archive SHA-256 differs from the frozen receipt.",
         call. = FALSE)
  }
  if (!identical(cran07_sha256(payload_manifest_path),
                 receipt$source_payload_manifest_sha256[[1L]]) ||
      !identical(cran07_sha256(sha_ledger_path),
                 receipt$sha_ledger_sha256[[1L]]) ||
      !identical(cran07_sha256(launcher_path), receipt$launcher_sha256[[1L]])) {
    stop("Detached payload manifest, SHA ledger, or launcher differs from the binding.",
         call. = FALSE)
  }
  payload_manifest <- utils::read.csv(payload_manifest_path,
    stringsAsFactors = FALSE,
    colClasses = c(path = "character", type = "character", mode = "character",
                   bytes = "numeric", sha256 = "character"))
  cran07_v4_validate_payload_manifest(payload_manifest)
  if (!identical(nrow(payload_manifest),
                 as.integer(receipt$source_payload_member_count[[1L]]))) {
    stop("Bound payload member count differs from its manifest.", call. = FALSE)
  }
  actual
}

cran07_v4_read_external_authority <- function() {
  links <- Sys.readlink(CRAN07_V4_AUTHORITY_PATHS)
  present <- CRAN07_V4_AUTHORITY_PATHS[
    file.exists(CRAN07_V4_AUTHORITY_PATHS) | (!is.na(links) & nzchar(links))]
  if (length(present) != 1L) {
    stop("Exactly one fixed external v4 campaign-authority record must exist.",
         call. = FALSE)
  }
  if (nzchar(Sys.readlink(present))) {
    stop("External v4 campaign authority cannot be a symbolic link.",
         call. = FALSE)
  }
  parent <- dirname(present)
  parent_info <- file.info(parent)
  parent_mode <- sprintf("%04o", as.integer(parent_info$mode))
  if (!dir.exists(parent) || nzchar(Sys.readlink(parent)) ||
      !identical(parent_mode, "0555")) {
    stop("External v4 campaign-authority directory must be a fixed non-symlink 0555 directory.",
         call. = FALSE)
  }
  info <- file.info(present)
  mode <- sprintf("%04o", as.integer(info$mode))
  if (!file_test("-f", present) || is.na(info$size) || info$isdir ||
      info$size <= 0 || !identical(mode, "0444")) {
    stop("External v4 campaign authority must be one nonempty, read-only regular file.",
         call. = FALSE)
  }
  path <- normalizePath(present, mustWork = TRUE)
  authority <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (!is.data.frame(authority) || nrow(authority) != 1L ||
      !identical(names(authority), CRAN07_V4_AUTHORITY_FIELDS) ||
      anyNA(authority) ||
      !identical(authority$authority_id[[1L]], CRAN07_V4_AUTHORITY_ID) ||
      !identical(authority$status[[1L]], "AUTHORIZED") ||
      !identical(authority$scope[[1L]], "simulation_execution_only") ||
      !identical(authority$receipt_id[[1L]], CRAN07_V4_SOURCE_RECEIPT_ID) ||
      any(!grepl("^[0-9a-f]{64}$", unlist(authority[c(
        "source_archive_sha256", "source_payload_manifest_sha256",
        "sha_ledger_sha256", "launcher_sha256")], use.names = FALSE))) ||
      !is.logical(authority$simulation_authorized) ||
      !identical(authority$simulation_authorized[[1L]], TRUE) ||
      !is.logical(authority$release_authorized) ||
      !identical(authority$release_authorized[[1L]], FALSE) ||
      !is.logical(authority$version_change_authorized) ||
      !identical(authority$version_change_authorized[[1L]], FALSE) ||
      !is.logical(authority$publication_authorized) ||
      !identical(authority$publication_authorized[[1L]], FALSE) ||
      !is.logical(authority$cran_submission_authorized) ||
      !identical(authority$cran_submission_authorized[[1L]], FALSE)) {
    stop("External v4 campaign authority is malformed or exceeds simulation-only scope.",
         call. = FALSE)
  }
  attr(authority, "path") <- path
  attr(authority, "sha256") <- cran07_sha256(path)
  authority
}

cran07_v4_validate_external_authority <- function(authority, receipt,
                                                   launcher_path) {
  if (!is.data.frame(authority) || nrow(authority) != 1L ||
      !identical(names(authority), CRAN07_V4_AUTHORITY_FIELDS) ||
      anyNA(authority) ||
      !identical(authority$authority_id[[1L]], CRAN07_V4_AUTHORITY_ID) ||
      !identical(authority$status[[1L]], "AUTHORIZED") ||
      !identical(authority$scope[[1L]], "simulation_execution_only") ||
      !is.logical(authority$simulation_authorized) ||
      !identical(authority$simulation_authorized[[1L]], TRUE) ||
      !is.logical(authority$release_authorized) ||
      !identical(authority$release_authorized[[1L]], FALSE) ||
      !is.logical(authority$version_change_authorized) ||
      !identical(authority$version_change_authorized[[1L]], FALSE) ||
      !is.logical(authority$publication_authorized) ||
      !identical(authority$publication_authorized[[1L]], FALSE) ||
      !is.logical(authority$cran_submission_authorized) ||
      !identical(authority$cran_submission_authorized[[1L]], FALSE) ||
      !is.data.frame(receipt) || nrow(receipt) != 1L ||
      !identical(names(receipt), CRAN07_V4_SOURCE_RECEIPT_FIELDS)) {
    stop("V4 authority validation requires canonical authority and receipt rows.",
         call. = FALSE)
  }
  pairs <- c(
    receipt_id = "receipt_id",
    source_archive_file = "source_archive_file",
    sha256 = "source_archive_sha256",
    source_payload_manifest_file = "source_payload_manifest_file",
    source_payload_manifest_sha256 = "source_payload_manifest_sha256",
    sha_ledger_file = "sha_ledger_file",
    sha_ledger_sha256 = "sha_ledger_sha256",
    launcher_file = "launcher_file",
    launcher_sha256 = "launcher_sha256"
  )
  matches <- vapply(names(pairs), function(receipt_name)
    identical(receipt[[receipt_name]][[1L]],
              authority[[pairs[[receipt_name]]]][[1L]]), logical(1L))
  if (!all(matches) ||
      !identical(cran07_sha256(launcher_path),
                 authority$launcher_sha256[[1L]])) {
    stop("External v4 authority does not authenticate the bound receipt and launcher.",
         call. = FALSE)
  }
  invisible(TRUE)
}

cran07_v4_validate_archive_members <- function(archive_path) {
  archive <- normalizePath(archive_path, mustWork = TRUE)
  members <- utils::untar(archive, list = TRUE)
  members <- sub("/$", "", members)
  if (!length(members) || anyNA(members) || any(!nzchar(members)) ||
      anyDuplicated(members) || any(grepl("^/", members)) ||
      any(grepl("(^|/)\\.\\.(/|$)", members)) ||
      any(grepl("\\\\", members)) ||
      any(grepl("(^|/)\\._", members)) ||
      any(grepl("(^|/)\\.DS_Store$", members)) ||
      any(!startsWith(members, paste0(CRAN07_V4_ARCHIVE_ROOT, "/")))) {
    stop("V4 source archive member inventory is unsafe or non-canonical.",
         call. = FALSE)
  }
  required <- file.path(CRAN07_V4_ARCHIVE_ROOT,
                        CRAN07_V4_REQUIRED_ARCHIVE_RELPATHS)
  detached <- file.path(CRAN07_V4_ARCHIVE_ROOT,
                        CRAN07_V4_DETACHED_ENVELOPE_RELPATHS)
  if (length(setdiff(required, members)) || any(detached %in% members)) {
    stop("V4 source archive is incomplete or embeds its detached launch envelope.",
         call. = FALSE)
  }
  verbose <- system2("tar", c("-tvf", shQuote(archive)),
                     stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(verbose, "status")) || length(verbose) != length(members) ||
      any(substr(verbose, 1L, 1L) != "-")) {
    stop("V4 source archive contains a link, device, directory, or unreadable member.",
         call. = FALSE)
  }
  invisible(members)
}

cran07_v4_validate_live_payload <- function(repo_root, manifest) {
  repo <- normalizePath(repo_root, mustWork = TRUE)
  cran07_v4_validate_payload_manifest(manifest)
  observed <- list.files(repo, recursive = TRUE, all.files = TRUE,
                         include.dirs = FALSE, no.. = TRUE)
  observed <- gsub("\\\\", "/", observed)
  observed <- sort(setdiff(observed, CRAN07_V4_DETACHED_ENVELOPE_RELPATHS),
                   method = "radix")
  if (!identical(observed, manifest$path)) {
    stop("Live v4 source tree differs from the bound payload inventory.",
         call. = FALSE)
  }
  files <- file.path(repo, manifest$path)
  info <- file.info(files)
  modes <- sprintf("%04o", as.integer(info$mode))
  if (anyNA(info$size) || any(info$isdir) || any(nzchar(Sys.readlink(files))) ||
      !identical(as.numeric(info$size), as.numeric(manifest$bytes)) ||
      !identical(modes, manifest$mode) ||
      !identical(cran07_v4_file_sha256s(files), manifest$sha256)) {
    stop("Live v4 source bytes, modes, or types differ from the bound payload.",
         call. = FALSE)
  }
  invisible(TRUE)
}

cran07_v4_validate_archive_payload <- function(archive_path, manifest) {
  members <- cran07_v4_validate_archive_members(archive_path)
  cran07_v4_validate_payload_manifest(manifest)
  expected <- file.path(CRAN07_V4_ARCHIVE_ROOT, manifest$path)
  if (!identical(members, expected)) {
    stop("V4 archive members differ from the exact bound payload manifest.",
         call. = FALSE)
  }
  stage <- tempfile("cran07-v4-verify-")
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)
  status <- system2("tar", c("-xf", shQuote(normalizePath(archive_path)),
                              "-C", shQuote(stage)))
  if (!identical(status, 0L)) stop("V4 archive extraction failed.", call. = FALSE)
  cran07_v4_validate_live_payload(file.path(stage, CRAN07_V4_ARCHIVE_ROOT),
                                  manifest)
  invisible(members)
}

cran07_v4_verify_bound_source <- function(repo_root) {
  repo <- normalizePath(repo_root, mustWork = TRUE)
  receipt_file <- normalizePath(file.path(repo,
    CRAN07_V4_SOURCE_RECEIPT_RELPATH), mustWork = TRUE)
  canonical <- normalizePath(file.path(repo,
    "docs/dev-log/simulation-artifacts/2026-08-08-cran07-v4-preregistration",
    "source-archive-binding.csv"), mustWork = TRUE)
  if (!identical(receipt_file, canonical)) {
    stop("V4 source binding did not resolve to the canonical receipt path.",
         call. = FALSE)
  }
  receipt <- utils::read.csv(receipt_file, stringsAsFactors = FALSE)
  payload_manifest_path <- normalizePath(file.path(repo,
    CRAN07_V4_PAYLOAD_MANIFEST_RELPATH), mustWork = TRUE)
  sha_ledger_path <- normalizePath(file.path(repo,
    CRAN07_V4_SHA_LEDGER_RELPATH), mustWork = TRUE)
  launcher_path <- normalizePath(file.path(repo, CRAN07_V4_LAUNCHER_RELPATH),
                                 mustWork = TRUE)
  archive_path <- receipt$source_archive_path[[1L]]
  actual <- cran07_v4_validate_source_binding(
    receipt, archive_path, payload_manifest_path, sha_ledger_path, launcher_path)
  authority <- cran07_v4_read_external_authority()
  cran07_v4_validate_external_authority(authority, receipt, launcher_path)
  manifest <- utils::read.csv(payload_manifest_path, stringsAsFactors = FALSE,
                              colClasses = c(path = "character", type = "character",
                                             mode = "character", bytes = "numeric",
                                             sha256 = "character"))
  if (!identical(nrow(manifest),
                 as.integer(receipt$source_payload_member_count[[1L]]))) {
    stop("Bound source-payload member count differs from its manifest.",
         call. = FALSE)
  }
  cran07_v4_validate_archive_payload(archive_path, manifest)
  cran07_v4_validate_live_payload(repo, manifest)
  actual
}

cran07_v4_manifest <- function(registry, campaign_id, stage,
                               source_archive_sha256, cells = NULL) {
  stage <- match.arg(stage, names(CRAN07_V4_STAGE_REPS))
  if (length(source_archive_sha256) != 1L || is.na(source_archive_sha256) ||
      !grepl("^[0-9a-f]{64}$", source_archive_sha256)) {
    stop("V4 source archive identity must be one lowercase SHA-256.", call. = FALSE)
  }
  eligible <- cran07_v4_production_cells(campaign_id)
  if (stage == "production") {
    if (is.null(cells)) cells <- eligible
    if (any(!cells %in% eligible)) {
      stop("V4 production cells must belong to the immutable 31-cell surface.",
           call. = FALSE)
    }
  }
  if (!is.null(cells)) registry <- registry[registry$cell_id %in% cells, , drop = FALSE]
  if (!nrow(registry)) stop("No registry cells selected.", call. = FALSE)
  nrep <- unname(CRAN07_V4_STAGE_REPS[[stage]])
  offset <- cran07_v4_seed_offset(campaign_id, stage)
  do.call(rbind, lapply(seq_len(nrow(registry)), function(i) data.frame(
    campaign_id = campaign_id,
    registry_sha256 = attr(registry, "sha256"),
    source_archive_sha256 = source_archive_sha256,
    cell_number = as.integer(registry$cell_number[[i]]),
    cell_id = as.character(registry$cell_id[[i]]),
    replicate = seq_len(nrep),
    seed = vapply(seq_len(nrep), function(r)
      cran07_seed(registry$cell_number[[i]], r, offset), integer(1L)),
    stringsAsFactors = FALSE
  )))
}

cran07_v4_validate_manifest <- function(manifest, registry, campaign_id, stage,
                                         source_archive_sha256,
                                         expected_cells = NULL) {
  stage <- match.arg(stage, names(CRAN07_V4_STAGE_REPS))
  required <- c(CRAN07_V4_IDENTITY_COLUMNS, "cell_number")
  if (!is.data.frame(manifest) || !nrow(manifest) ||
      length(setdiff(required, names(manifest)))) {
    stop("V4 manifest is empty or missing frozen identity columns.", call. = FALSE)
  }
  spec <- cran07_v4_campaign_spec(campaign_id)
  if (!identical(attr(registry, "sha256"), spec$registry_sha256) ||
      !identical(attr(registry, "campaign_id"), campaign_id) ||
      anyNA(manifest[required]) || any(manifest$campaign_id != campaign_id) ||
      any(manifest$registry_sha256 != spec$registry_sha256) ||
      any(manifest$source_archive_sha256 != source_archive_sha256)) {
    stop("V4 manifest identity does not match campaign, registry, or source archive.",
         call. = FALSE)
  }
  registry_number <- stats::setNames(registry$cell_number, registry$cell_id)
  if (any(!manifest$cell_id %in% names(registry_number)) ||
      any(manifest$cell_number != unname(registry_number[manifest$cell_id]))) {
    stop("V4 manifest cell numbers contradict the canonical registry.", call. = FALSE)
  }
  cells <- sort(unique(manifest$cell_id))
  eligible <- cran07_v4_production_cells(campaign_id)
  if (stage == "production" && any(!cells %in% eligible)) {
    stop("V4 production manifest contains a pilot-only or unknown cell.",
         call. = FALSE)
  }
  expected_cells <- sort(unique(if (is.null(expected_cells)) {
    if (stage == "production") eligible else registry$cell_id
  } else as.character(expected_cells)))
  if (stage == "production" && any(!expected_cells %in% eligible)) {
    stop("Declared v4 production set contains an ineligible cell.", call. = FALSE)
  }
  if (!identical(cells, expected_cells) || any(!expected_cells %in% registry$cell_id)) {
    stop("V4 manifest cell set is incomplete or differs from the declared set.",
         call. = FALSE)
  }
  nrep <- unname(CRAN07_V4_STAGE_REPS[[stage]])
  counts <- table(factor(manifest$cell_id, levels = expected_cells))
  if (any(counts != nrep)) stop("V4 ", stage, " requires exactly ", nrep,
                                " rows per cell.", call. = FALSE)
  if (anyDuplicated(do.call(paste, c(manifest[CRAN07_V4_IDENTITY_COLUMNS],
                                     list(sep = "::"))))) {
    stop("V4 manifest contains duplicate six-field identities.", call. = FALSE)
  }
  offset <- cran07_v4_seed_offset(campaign_id, stage)
  for (cell in expected_cells) {
    z <- manifest[manifest$cell_id == cell, , drop = FALSE]
    if (!identical(sort(as.integer(z$replicate)), seq_len(nrep))) {
      stop("V4 replicates must be the complete 1:", nrep, " sequence for ", cell,
           ".", call. = FALSE)
    }
    expected_seed <- vapply(seq_len(nrep), function(r)
      cran07_seed(registry_number[[cell]], r, offset), integer(1L))
    if (!identical(as.integer(z$seed[match(seq_len(nrep), z$replicate)]),
                   expected_seed)) {
      stop("V4 manifest seeds contradict the stage-specific rule for ", cell,
           ".", call. = FALSE)
    }
  }
  invisible(TRUE)
}

cran07_v4_manifest_sha256 <- function(manifest) {
  required <- c(CRAN07_V4_IDENTITY_COLUMNS, "cell_number")
  if (length(setdiff(required, names(manifest)))) {
    stop("Cannot hash an incomplete v4 manifest.", call. = FALSE)
  }
  canonical <- manifest[order(manifest$campaign_id, manifest$cell_number,
                              manifest$replicate), required, drop = FALSE]
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  utils::write.table(canonical, tmp, sep = ",", row.names = FALSE,
                     col.names = TRUE, quote = TRUE, na = "NA", eol = "\n")
  cran07_sha256(tmp)
}
