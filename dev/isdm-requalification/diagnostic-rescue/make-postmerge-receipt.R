args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("usage: make-postmerge-receipt.R PR CI_RECEIPT OUTPUT_RDS")
pr <- as.integer(args[[1L]]); ci_path <- normalizePath(args[[2L]], mustWork = TRUE)
output <- path.expand(args[[3L]])
if (is.na(pr) || file.exists(output)) stop("invalid PR or existing output")
source_pin <- "09eca7b1eb9018958bad367be824871161a60af1"
ci <- readRDS(ci_path)
if (!is.list(ci) ||
    !identical(ci$schema, "isdm-diagnostic-ci-receipt-v1") ||
    !identical(ci$workflow_name, "R-CMD-check") ||
    !identical(ci$event, "workflow_dispatch") ||
    !identical(sort(names(ci$platforms)), c("macos", "ubuntu", "windows")) ||
    any(ci$platforms != "success")) stop("CI receipt is malformed")
system2("git", c("fetch", "--quiet", "origin", "main"))
main <- system2("git", c("rev-parse", "origin/main"), stdout = TRUE)[[1L]]
tree <- system2("git", c("rev-parse", "origin/main^{tree}"), stdout = TRUE)[[1L]]
protected <- c("R", "src", "DESCRIPTION", "NAMESPACE", "man", "vignettes",
               "README.md", "NEWS.md", "_pkgdown.yml")
if (system2("git", c("diff", "--quiet", source_pin, "origin/main", "--", protected)) != 0L)
  stop("package-code surfaces changed")
raw <- system2("gh", c("pr", "view", as.character(pr), "--json",
                        "state,mergedAt,mergeCommit,headRefOid,url"), stdout = TRUE)
info <- jsonlite::fromJSON(paste(raw, collapse = "\n"), simplifyVector = TRUE)
if (!identical(info$state, "MERGED") || !identical(info$mergeCommit$oid, main))
  stop("PR merge receipt differs from origin/main")
if (!identical(ci$head_sha, info$headRefOid))
  stop("CI receipt is not bound to the merged PR head")
lease <- system2("bash", c(
  "/Users/z3437171/Dropbox/Github Local/Shinichi/tools/lane_lease.sh",
  "--list", "gllvmTMB-isdm-identifiability-diagnostic"),
  stdout = TRUE, stderr = TRUE)
if (!is.null(attr(lease, "status"))) stop("lane lease query failed")
if (any(grepl("codex:isdm-identifiability-diagnostic", lease, fixed = TRUE)))
  stop("iJSDM closeout lease is still active")
diag <- file.path("dev", "isdm-requalification", "diagnostic-rescue")
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
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
saveRDS(list(schema = "isdm-diagnostic-postmerge-receipt-v1",
             created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
             source_pin = source_pin, feature_head = ci$head_sha,
             origin_main = main, origin_main_tree = tree, pr = pr,
             pr_url = info$url, pr_head = info$headRefOid, ci = ci,
             package_code_unchanged = TRUE,
             lease_released = TRUE,
             manifest_sha256 = stats::setNames(vapply(manifests, hash, character(1L)),
                                                basename(dirname(manifests)))),
        output, version = 3)
cat("DIAGNOSTIC_POSTMERGE_RECEIPT_WRITTEN\n")
