#!/usr/bin/env Rscript

# Read-only provenance gate for the EVA Gate-1 / VA engine spine.
# Usage: Rscript dev/va-eva-engine-spine/check-sealed-sources.R [repo-root]

args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[[1]], mustWork = TRUE) else getwd()

run_git <- function(args, fail = TRUE) {
  output <- suppressWarnings(system2("git", c("-C", root, args), stdout = TRUE, stderr = TRUE))
  status <- attr(output, "status") %||% 0L
  if (fail && status != 0L) stop(paste(c("git", args, output), collapse = "\n"), call. = FALSE)
  list(output = output, status = status)
}
`%||%` <- function(x, y) if (is.null(x)) y else x

failures <- character()
check <- function(condition, message) {
  if (isTRUE(condition)) {
    message("PASS: ", message)
  } else {
    message("FAIL: ", message)
    failures <<- c(failures, message)
  }
}

sealed_commit <- "3b479354285a8dcd69ab43cc26d98f98e6b98041"
prohibited_commit <- "2392996be293401cc28e8c9bff9542b9f2d3bfe3"
sealed <- c(
  "R/eva-proto.R" = "a029dbe76b127b3f9a9eca08145fbfc58546f6a4",
  "inst/tmb/gllvmTMB_eva.cpp" = "680d7a576365e2265dcfa3f197a14a207f1aee56",
  "docs/design/86-eva-gate1-parameters.json" = "12b0da289d65b47a858e5a3694b00bb3f79a7c90",
  "tests/testthat/test-eva-gate1.R" = "7bcc75c290cc36c964e5b08764832efc96ad89c2"
)
va_spine <- c(
  "R/va-r3-proto.R",
  "inst/tmb/gllvmTMB_va_r3.cpp",
  "tests/testthat/test-va-r3-prototype.R"
)
engine_spine <- c(
  "R/approximation-engine.R",
  "dev/va-eva-comparator.R",
  "dev/va-eva-comparison-runner.R",
  "dev/va-eva-executable-comparisons.sh",
  "dev/va-eva-engine-spine/check-executable-comparison.R"
)

invisible(run_git(c("rev-parse", "--verify", sealed_commit)))
invisible(run_git(c("rev-parse", "--verify", prohibited_commit)))

for (path in names(sealed)) {
  expected <- sealed[[path]]
  commit_blob <- trimws(run_git(c("rev-parse", paste0(sealed_commit, ":", path)))$output)
  check(identical(commit_blob, expected), paste0(path, " has the recorded sealed blob"))

  full_path <- file.path(root, path)
  check(file.exists(full_path), paste0(path, " is present in the working tree"))
  if (file.exists(full_path)) {
    actual <- trimws(run_git(c("hash-object", "--", full_path))$output)
    check(identical(actual, expected), paste0(path, " exactly matches ", sealed_commit))
  }
}

for (path in va_spine) {
  tracked <- run_git(c("ls-files", "--error-unmatch", "--", path), fail = FALSE)$status == 0L
  check(tracked, paste0(path, " is tracked at HEAD"))
  if (tracked) {
    clean <- run_git(c("diff", "--quiet", "HEAD", "--", path), fail = FALSE)$status == 0L
    check(clean, paste0(path, " matches HEAD"))
  }
  untracked <- run_git(c("ls-files", "--others", "--exclude-standard", "--", path))$output
  check(!length(untracked), paste0(path, " has no untracked replacement"))
}

prohibited_paths <- run_git(c("diff-tree", "--no-commit-id", "--name-only", "-r", prohibited_commit))$output
bernoulli_paths <- prohibited_paths[grepl("^dev/va-bernoulli", prohibited_paths)]
check(length(bernoulli_paths) > 0L, "prohibited commit exposes its dev/va-bernoulli inputs")
for (path in bernoulli_paths) {
  check(!file.exists(file.path(root, path)), paste0("prohibited input remains absent: ", path))
}

for (path in engine_spine) {
  check(file.exists(file.path(root, path)), paste0(path, " is present in the private engine spine"))
}

watched <- c(names(sealed), va_spine, engine_spine)
for (path in watched[file.exists(file.path(root, watched))]) {
  lines <- readLines(file.path(root, path), warn = FALSE, encoding = "UTF-8")
  ## A statement that the paths are excluded is desirable.  Inspect executable
  ## text only, so such a comment is not mistaken for an import.
  text <- paste(sub("#.*$", "", lines), collapse = "\n")
  has_prohibited_import <- grepl("va-bernoulli|gate[-_ ]?2r?|gate2", text, ignore.case = TRUE, perl = TRUE)
  check(!has_prohibited_import, paste0(path, " contains no prohibited Bernoulli or Gate-2/Gate-2R import reference"))
}

eva_text <- paste(readLines(file.path(root, "R/eva-proto.R"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
check(
  !grepl("\\.va_r3_gh_rule", eva_text) || file.exists(file.path(root, "R/va-r3-proto.R")),
  "EVA's permitted VA-R3 quadrature-helper dependency has its pinned source present"
)

if (length(failures)) {
  message("\nSOURCE PROVENANCE CHECK FAILED (", length(failures), " assertion(s)).")
  quit(status = 1L)
}
message("\nSOURCE PROVENANCE CHECK PASSED.")
