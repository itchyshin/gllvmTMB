receipt_path <- path.expand(Sys.getenv(
  "ISDM_DIAG_POSTMERGE_RECEIPT",
  unset = "/Users/z3437171/local-scratch/receipts/gllvmTMB-isdm-identifiability-diagnostic-postmerge.rds"))
if (!file.exists(receipt_path)) stop("postmerge receipt is missing")
x <- readRDS(receipt_path)
required <- c("schema", "source_pin", "feature_head", "origin_main",
              "origin_main_tree", "pr", "ci", "package_code_unchanged",
              "lease_released", "manifest_sha256")
if (!is.list(x) || !all(required %in% names(x)) ||
    !identical(x$schema, "isdm-diagnostic-postmerge-receipt-v1") ||
    !identical(x$source_pin, "09eca7b1eb9018958bad367be824871161a60af1") ||
    !isTRUE(x$package_code_unchanged) || !isTRUE(x$lease_released) ||
    !identical(sort(names(x$ci$platforms)), c("macos", "ubuntu", "windows")) ||
    any(x$ci$platforms != "success")) stop("postmerge receipt is malformed")
system2("git", c("fetch", "--quiet", "origin", "main"))
main <- system2("git", c("rev-parse", "origin/main"), stdout = TRUE)[[1L]]
tree <- system2("git", c("rev-parse", "origin/main^{tree}"), stdout = TRUE)[[1L]]
if (!identical(main, x$origin_main) || !identical(tree, x$origin_main_tree) ||
    system2("git", c("merge-base", "--is-ancestor", x$feature_head,
                     "origin/main")) != 0L) stop("origin/main moved after receipt")
diag <- file.path("dev", "isdm-requalification", "diagnostic-rescue")
manifests <- file.path(diag, "evidence", c("qualification", "smoke", "experiment"),
                       "MANIFEST.sha256")
hash <- function(path) sub("[[:space:]].*$", "", system2(
  "shasum", c("-a", "256", path), stdout = TRUE)[[1L]])
observed <- stats::setNames(vapply(manifests, hash, character(1L)),
                            basename(dirname(manifests)))
if (!identical(observed, x$manifest_sha256)) stop("retained manifest hash changed")
lease <- system2("bash", c(
  "/Users/z3437171/Dropbox/Github Local/Shinichi/tools/lane_lease.sh",
  "--list", "gllvmTMB-isdm-identifiability-diagnostic"),
  stdout = TRUE, stderr = TRUE)
if (any(grepl("codex:isdm-identifiability-diagnostic", lease, fixed = TRUE)))
  stop("iJSDM closeout lease is active")
cat("DIAGNOSTIC_POSTMERGE_VERIFIED\n")
