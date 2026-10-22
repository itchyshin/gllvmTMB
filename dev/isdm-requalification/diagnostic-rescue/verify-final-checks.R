receipt_path <- path.expand(Sys.getenv(
  "ISDM_DIAG_CI_RECEIPT",
  unset = "/Users/z3437171/local-scratch/receipts/gllvmTMB-isdm-identifiability-diagnostic-ci.rds"))
if (!file.exists(receipt_path)) stop("three-OS CI receipt is missing")
receipt <- readRDS(receipt_path)
head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]]
if (!is.list(receipt) ||
    !identical(receipt$schema, "isdm-diagnostic-ci-receipt-v1") ||
    !identical(receipt$workflow_name, "R-CMD-check") ||
    !identical(receipt$event, "workflow_dispatch") ||
    !identical(receipt$head_sha, head) ||
    !identical(sort(names(receipt$platforms)), c("macos", "ubuntu", "windows")) ||
    any(receipt$platforms != "success"))
  stop("three-OS CI receipt differs from final branch HEAD")
fresh_path <- tempfile(fileext = ".rds")
fresh_status <- system2(file.path(R.home("bin"), "Rscript"), c(
  "--vanilla", "dev/isdm-requalification/diagnostic-rescue/make-ci-receipt.R",
  format(receipt$run_id, scientific = FALSE), shQuote(fresh_path)))
if (fresh_status != 0L || !file.exists(fresh_path))
  stop("live three-OS CI receipt query failed")
fresh <- readRDS(fresh_path)
unlink(fresh_path)
receipt$created_at <- fresh$created_at <- NULL
if (!identical(receipt, fresh)) stop("live CI state differs from retained receipt")
test <- system2(file.path(R.home("bin"), "Rscript"), c(
  "--vanilla", "-e",
  shQuote("devtools::test(filter = 'isdm-diagnostic', stop_on_failure = TRUE)")),
  stdout = TRUE, stderr = TRUE)
status <- attr(test, "status"); if (is.null(status)) status <- 0L
if (status != 0L || !any(grepl("FAIL 0.*WARN 0.*SKIP 0.*PASS 139", test)))
  stop("checkout-focused diagnostic suite did not pass 139 expectations")
cat("DIAGNOSTIC_FINAL_CHECKS_VERIFIED\n")
