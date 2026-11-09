# Coverage producer for GitHub Actions (test-coverage.yaml).
#
# A coverage number is only worth publishing if it was measured on the test run
# that R-CMD-check.yaml trusts. r-lib/actions/check-r-package@v2 builds the
# tarball with `--no-manual` and runs `R CMD check --no-manual --as-cran` in
# <workspace>/check, so the suite runs from check/gllvmTMB.Rcheck/tests through
# tests/testthat.R, under the `--as-cran` environment, and many tests depend on
# that layout (../../00_pkg_src/gllvmTMB scanners, the dev/ walk-up from the
# check directory, GITHUB_WORKSPACE lookups).
#
# This script reproduces it instead of imitating it: covr instruments and
# installs the built tarball, then runs that same `R CMD check` against the
# instrumented library (`--install=skip --library=`). Only non-test sections
# (examples, vignettes, manual) are switched off. A failed or erroring test is an
# R CMD check ERROR, which fails covr's command step, which stops this script
# before any coverage file is written. The test log is then re-read and must
# show `FAIL 0` with a non-zero PASS count before cobertura.xml is produced.
#
# Known differences from R-CMD-check.yaml, all inherent to covr: compiled code is
# built with covr's `-O0 --coverage` flags, R code is installed with
# --with-keep.source and wrapped in trace counters, R_COVR=true (so the suite's
# own skip_on_covr() calls skip), and vignette outputs are not built (no test
# reads them).

fail <- function(...) stop(sprintf(...), call. = FALSE)

run_or_fail <- function(command, args) {
  status <- system2(command, args)
  if (!identical(as.integer(status), 0L)) {
    fail("`%s %s` exited with status %s", command, paste(args, collapse = " "), status)
  }
  invisible(status)
}

shard <- Sys.getenv("GLLVMTMB_TEST_SHARD")
if (!grepl("^[0-9]+/[0-9]+$", shard)) {
  fail("GLLVMTMB_TEST_SHARD must be \"k/N\" so coverage shards partition tests; got %s", sQuote(shard))
}

workspace <- normalizePath(Sys.getenv("GITHUB_WORKSPACE", getwd()), winslash = "/", mustWork = TRUE)
runner_temp <- normalizePath(Sys.getenv("RUNNER_TEMP", tempdir()), winslash = "/", mustWork = TRUE)
r_bin <- file.path(R.home("bin"), "R")
pkg <- "gllvmTMB"

check_dir <- file.path(workspace, "check")
build_dir <- file.path(runner_temp, "covr-build")
covr_src_parent <- file.path(runner_temp, "covr-src")
covr_lib <- file.path(runner_temp, "covr-lib")
for (d in c(check_dir, build_dir, covr_src_parent, covr_lib)) {
  if (file.exists(d)) fail("%s already exists; refusing to mix coverage runs", d)
}
for (d in c(build_dir, covr_src_parent)) {
  if (!dir.create(d, recursive = TRUE)) fail("could not create %s", d)
}

cat(sprintf("coverage_commit=%s\n", system2("git", c("-C", shQuote(workspace), "rev-parse", "HEAD"), stdout = TRUE)))
cat(sprintf("GLLVMTMB_TEST_SHARD=%s\n", shard))

# 1. Build the tarball as check-r-package does (`--no-manual`). check/ is
#    created only afterwards so it cannot end up inside the tarball.
owd <- setwd(build_dir)
run_or_fail(r_bin, c("CMD", "build", "--no-manual", "--no-build-vignettes", shQuote(workspace)))
setwd(owd)
built <- list.files(build_dir, pattern = sprintf("^%s_.*[.]tar[.]gz$", pkg), full.names = TRUE)
if (length(built) != 1L) fail("expected one built tarball in %s, found %d", build_dir, length(built))
if (!dir.create(check_dir)) fail("could not create %s", check_dir)
tarball <- file.path(check_dir, basename(built))
if (!file.copy(built, tarball)) fail("could not copy %s to %s", built, check_dir)

# 2. Unpack a private copy of the same tarball for covr to instrument.
if (!identical(as.integer(utils::untar(tarball, exdir = covr_src_parent)), 0L)) {
  fail("could not unpack %s into %s", tarball, covr_src_parent)
}
covr_src <- file.path(covr_src_parent, pkg)
if (!file.exists(file.path(covr_src, "DESCRIPTION")) || !file.exists(file.path(covr_src, "tests", "testthat.R"))) {
  fail("%s is not a package source tree with tests/testthat.R", covr_src)
}

# 3. `--as-cran` runs the tests against a private library holding only the
#    declared dependency closure (tools:::setRlibs) plus .Library. The
#    instrumented package records its trace through covr, and covr's load hook
#    runs inside try(): if covr is unreachable the tests still pass but their
#    coverage is silently dropped. Make covr's own closure loadable from
#    .Library, and prove it from a process with the same library settings.
#    Everything else the tests can see is unchanged.
installed <- utils::installed.packages()
covr_closure <- unique(c("covr", unlist(tools::package_dependencies(
  "covr", db = installed, which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE
))))
Sys.setenv(`_R_CHECK_NO_RECOMMENDED_` = "TRUE")
test_libs_env <- tools:::setRlibs(pkgdir = covr_src, suggests = TRUE)
Sys.unsetenv("_R_CHECK_NO_RECOMMENDED_")
test_lib <- sub("^R_LIBS=", "", grep("^R_LIBS=", test_libs_env, value = TRUE))
if (length(test_lib) != 1L || !dir.exists(test_lib)) fail("could not reproduce R CMD check's test library")
reachable <- c(list.files(test_lib), rownames(utils::installed.packages(lib.loc = .Library)))
to_add <- setdiff(covr_closure, reachable)
cat(sprintf("added to .Library so covr loads under R CMD check: %s\n",
            if (length(to_add)) paste(sort(to_add), collapse = ", ") else "(none)"))
for (p in to_add) {
  from <- find.package(p, quiet = TRUE)
  if (length(from) != 1L) fail("covr dependency %s is not installed", p)
  copied <- if (file.access(.Library, 2L) == 0L) {
    isTRUE(file.copy(from, .Library, recursive = TRUE, copy.date = TRUE))
  } else {
    identical(as.integer(system2("sudo", c("-n", "cp", "-a", shQuote(from), shQuote(.Library)))), 0L)
  }
  if (!copied || !file.exists(file.path(.Library, p, "DESCRIPTION"))) fail("could not copy %s into %s", p, .Library)
}
probe <- system2(
  file.path(R.home("bin"), "Rscript"),
  c("--vanilla", "-e", shQuote("loadNamespace('covr'); cat('covr', format(packageVersion('covr')), 'loads from', dirname(find.package('covr')), '\\n')")),
  env = test_libs_env,
  stdout = TRUE, stderr = TRUE
)
cat(probe, sep = "\n")
if (!identical(as.integer(attr(probe, "status") %||% 0L), 0L)) {
  fail("covr is not loadable from R CMD check's test library")
}
unlink(test_lib, recursive = TRUE)

# 4. Inside covr's command step, run R CMD check on the tarball against the
#    instrumented library. check-r-package sets these two variables before
#    rcmdcheck(), and rcmdcheck clears covr's R_TESTS for the check process.
check_args <- c(
  "CMD", "check",
  "--install=skip", paste0("--library=", shQuote(covr_lib)),
  "--no-manual", "--as-cran",
  "--no-examples", "--no-vignettes", "--no-build-vignettes", "--ignore-vignettes",
  shQuote(basename(tarball))
)
code <- c(
  sprintf("setwd(%s)", deparse(check_dir)),
  "Sys.unsetenv(\"R_TESTS\")",
  "if (!nzchar(Sys.getenv(\"_R_CHECK_FORCE_SUGGESTS_\"))) Sys.setenv(`_R_CHECK_FORCE_SUGGESTS_` = \"false\")",
  "if (!nzchar(Sys.getenv(\"_R_CHECK_CRAN_INCOMING_\"))) Sys.setenv(`_R_CHECK_CRAN_INCOMING_` = \"false\")",
  sprintf("status <- system2(%s, %s)", deparse(r_bin), paste(deparse(check_args), collapse = "")),
  "if (!identical(as.integer(status), 0L)) stop(\"R CMD check against the instrumented library failed with status \", status)"
)

cov <- covr::package_coverage(
  path = covr_src,
  type = "none",
  code = code,
  install_path = covr_lib,
  quiet = FALSE
)

# 5. Independent read-back of the test result. covr only gets here if the check
#    exited 0; this also refuses a run in which the tests did not actually run.
rcheck <- file.path(check_dir, paste0(pkg, ".Rcheck"))
check_log <- file.path(rcheck, "00check.log")
test_rout <- file.path(rcheck, "tests", "testthat.Rout")
if (file.exists(paste0(test_rout, ".fail"))) fail("%s.fail exists: the test step failed", test_rout)
if (!file.exists(check_log)) fail("missing %s", check_log)
if (!file.exists(test_rout)) fail("missing %s: the test step did not run", test_rout)

log_lines <- readLines(check_log, warn = FALSE)
status_line <- grep("^Status: ", log_lines, value = TRUE)
if (length(status_line) != 1L || grepl("ERROR", status_line)) {
  fail("R CMD check status is not clean: %s", paste(status_line, collapse = " | "))
}
if (!any(grepl("^\\* checking tests \\.\\.\\.", log_lines))) fail("00check.log has no tests section")

rout_lines <- readLines(test_rout, warn = FALSE)
summary_re <- "^\\[ FAIL ([0-9]+) \\| WARN ([0-9]+) \\| SKIP ([0-9]+) \\| PASS ([0-9]+) \\]$"
summary_line <- utils::tail(grep(summary_re, rout_lines, value = TRUE), 1L)
if (length(summary_line) != 1L) fail("no testthat summary line in %s", test_rout)
counts <- as.integer(regmatches(summary_line, regexec(summary_re, summary_line))[[1L]][-1L])
names(counts) <- c("FAIL", "WARN", "SKIP", "PASS")
cat(sprintf("shard_test_summary=%s\n", summary_line))
if (counts[["FAIL"]] != 0L) fail("testthat reported %d failures", counts[["FAIL"]])
if (counts[["PASS"]] == 0L) fail("testthat reported zero passing expectations")

# 6. The test process must have recorded R coverage. Loading the package (the
#    only thing the static checks do) executes no line of R/gllvmTMB.R; every
#    shard's tests fit models through gllvmTMB().
tally <- covr::tally_coverage(cov)
r_rows <- grepl("^R/", tally$filename)
main_hits <- sum(tally$value[tally$filename == "R/gllvmTMB.R"] > 0)
cat(sprintf("covered_lines R/gllvmTMB.R=%d, R/ total=%d of %d\n",
            main_hits, sum(tally$value[r_rows] > 0), sum(r_rows)))
if (main_hits == 0L) fail("no line of R/gllvmTMB.R was traced: the test run did not record R coverage")

# 7. Only now write the coverage outputs.
pct <- covr::percent_coverage(cov)
if (!is.finite(pct) || pct <= 0) fail("covr reported non-positive coverage: %s", pct)
print(cov)
cat(sprintf(
  paste0(
    "shard_percent_coverage=%.4f (shard %s only; Codecov merges ",
    "complementary shards after a trusted main upload)\n"
  ),
  pct, shard
))
out_dir <- workspace
writeLines(summary_line, file.path(out_dir, "coverage-tests.txt"))
writeLines(sprintf("shard_percent_coverage=%.4f", pct), file.path(out_dir, "coverage-percent.txt"))
covr::to_cobertura(cov, filename = file.path(out_dir, "cobertura.xml"))
if (!file.exists(file.path(out_dir, "cobertura.xml"))) fail("cobertura.xml was not written")
