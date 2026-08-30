receipt_path <- path.expand(Sys.getenv(
  "ISDM_DIAG_CI_RECEIPT",
  unset = "/Users/z3437171/local-scratch/receipts/gllvmTMB-isdm-identifiability-diagnostic-ci.rds"))
if (!file.exists(receipt_path)) stop("three-OS CI receipt is missing")
receipt <- readRDS(receipt_path)
head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]]
if (!is.list(receipt) ||
    !identical(receipt$schema, "isdm-diagnostic-ci-receipt-v1") ||
    !identical(receipt$head_sha, head) ||
    !identical(sort(names(receipt$platforms)), c("macos", "ubuntu", "windows")) ||
    any(receipt$platforms != "success"))
  stop("three-OS CI receipt differs from final branch HEAD")
test <- system2(file.path(R.home("bin"), "Rscript"), c(
  "--vanilla", "-e",
  shQuote("devtools::test(filter = 'isdm-diagnostic', stop_on_failure = TRUE)")),
  stdout = TRUE, stderr = TRUE)
status <- attr(test, "status"); if (is.null(status)) status <- 0L
if (status != 0L || !any(grepl("FAIL 0.*WARN 0.*SKIP 0.*PASS 139", test)))
  stop("checkout-focused diagnostic suite did not pass 139 expectations")
cat("DIAGNOSTIC_FINAL_CHECKS_VERIFIED\n")
