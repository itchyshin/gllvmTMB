receipt_path <- path.expand(Sys.getenv(
  "ISDM_DIAG_POSTMERGE_RECEIPT",
  unset = "/Users/z3437171/local-scratch/receipts/gllvmTMB-isdm-identifiability-diagnostic-postmerge.rds"))
if (!file.exists(receipt_path)) stop("postmerge receipt is missing")
x <- readRDS(receipt_path)
required <- c("schema", "source_pin", "feature_head", "origin_main",
              "origin_main_tree", "pr", "pr_head", "ci", "package_code_unchanged",
              "lease_released", "manifest_sha256")
if (!is.list(x) || !all(required %in% names(x)) ||
    !identical(x$schema, "isdm-diagnostic-postmerge-receipt-v1") ||
    !identical(x$source_pin, "09eca7b1eb9018958bad367be824871161a60af1") ||
    !isTRUE(x$package_code_unchanged) || !isTRUE(x$lease_released) ||
    !identical(x$ci$schema, "isdm-diagnostic-ci-receipt-v1") ||
    !identical(x$ci$workflow_name, "R-CMD-check") ||
    !identical(x$ci$event, "workflow_dispatch") ||
    !identical(x$feature_head, x$pr_head) ||
    !identical(x$ci$head_sha, x$pr_head) ||
    !identical(sort(names(x$ci$platforms)), c("macos", "ubuntu", "windows")) ||
    any(x$ci$platforms != "success")) stop("postmerge receipt is malformed")
if (system2("git", c("fetch", "--quiet", "origin", "main")) != 0L)
  stop("origin/main fetch failed")
main <- system2("git", c("rev-parse", "origin/main"), stdout = TRUE)[[1L]]
tree <- system2("git", c("rev-parse", "origin/main^{tree}"), stdout = TRUE)[[1L]]
if (!identical(main, x$origin_main) || !identical(tree, x$origin_main_tree))
  stop("origin/main moved after receipt")
raw_pr <- system2("gh", c("pr", "view", as.character(x$pr), "--json",
                           "state,mergeCommit,headRefOid"),
                  stdout = TRUE, stderr = TRUE)
if (!is.null(attr(raw_pr, "status")) ||
    !requireNamespace("jsonlite", quietly = TRUE)) stop("PR query failed")
info <- jsonlite::fromJSON(paste(raw_pr, collapse = "\n"), simplifyVector = TRUE)
if (!identical(info$state, "MERGED") ||
    !identical(info$mergeCommit$oid, x$origin_main) ||
    !identical(info$headRefOid, x$pr_head)) stop("merged PR binding changed")
diag <- file.path("dev", "isdm-requalification", "diagnostic-rescue")
source(file.path(diag, "verify-remote-receipt.R"), local = TRUE)
for (bundle in c("qualification", "smoke", "experiment"))
  isdm_diag_verify_bundle_manifest(file.path(diag, "evidence", bundle))
manifests <- file.path(diag, "evidence", c("qualification", "smoke", "experiment"),
                       "MANIFEST.sha256")
hash <- function(path) {
  raw_hash <- system2("shasum", c("-a", "256", path),
                      stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(raw_hash, "status")) || length(raw_hash) != 1L)
    stop("manifest hash command failed: ", path)
  value <- sub("[[:space:]].*$", "", raw_hash[[1L]])
  if (!grepl("^[[:xdigit:]]{64}$", value)) stop("invalid SHA-256: ", path)
  tolower(value)
}
observed <- stats::setNames(vapply(manifests, hash, character(1L)),
                            basename(dirname(manifests)))
if (!identical(observed, x$manifest_sha256)) stop("retained manifest hash changed")
lease <- system2("bash", c(
  shQuote("/Users/z3437171/Dropbox/Github Local/Shinichi/tools/lane_lease.sh"),
  "--list", "gllvmTMB-isdm-identifiability-diagnostic"),
  stdout = TRUE, stderr = TRUE)
if (!is.null(attr(lease, "status"))) stop("lane lease query failed")
if (any(grepl("codex:isdm-identifiability-diagnostic", lease, fixed = TRUE)))
  stop("iJSDM closeout lease is active")
cat("DIAGNOSTIC_POSTMERGE_VERIFIED\n")
