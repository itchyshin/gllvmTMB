pin <- "09eca7b1eb9018958bad367be824871161a60af1"
tree <- "fb979daa5d9a93d0804a053ff1bb00eced47ad09"
git <- function(args) system2("git", args, stdout = TRUE, stderr = TRUE)
if (!identical(git(c("rev-parse", paste0(pin, "^{tree}")))[[1L]], tree)) {
  stop("frozen compute pin/tree mismatch")
}
protected <- c("R", "src", "NAMESPACE", "man", "DESCRIPTION", "NEWS.md",
               "docs/design")
changed_protected <- git(c("diff", "--name-only", pin, "--", protected))
if (length(changed_protected)) {
  stop("protected package/source path changed: ", changed_protected[[1L]])
}
changed <- git(c("status", "--short"))
paths <- sub("^.. ", "", changed)
allowed <- grepl("^(LOOP/|dev/isdm-requalification/diagnostic-rescue/|tests/testthat/test-isdm-diagnostic-)", paths)
if (length(paths) && any(!allowed)) stop("non-allowlisted working path: ", paths[!allowed][1L])
manifest <- file.path("dev", "isdm-requalification", "diagnostic-rescue",
                      "HARNESS_SHA256.txt")
if (!file.exists(manifest)) stop("HARNESS_SHA256.txt has not been frozen")
command <- if (nzchar(Sys.which("sha256sum"))) "sha256sum" else "shasum"
args <- if (command == "shasum") c("-a", "256", "-c", manifest) else
  c("-c", manifest)
checked <- system2(command, args, stdout = TRUE, stderr = TRUE)
status <- attr(checked, "status"); if (is.null(status)) status <- 0L
if (as.integer(status) != 0L) stop("frozen harness manifest verification failed")
cat("DIAGNOSTIC_SOURCE_VERIFIED\n")
