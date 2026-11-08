# Coverage producer for GitHub Actions (test-coverage.yaml).
#
# covr installs an instrumented copy and runs tests from that library, not from
# an R CMD check tree. Help/source scanners in this package look for man/ and
# R/ via ../../00_pkg_src/gllvmTMB (the check-tree layout). This script plants
# that layout and copies original R/*.R + man/ into the installed tree so those
# scanners see the checkout. It does not change tests/.
#
# test_check() uses stop_on_failure = FALSE so a covr-only numeric mismatch
# (instrumentation can change which warning fires) still writes cobertura.
# R-CMD-check remains the test oracle.

shard <- Sys.getenv("GLLVMTMB_TEST_SHARD")
if (!nzchar(shard)) {
  stop("GLLVMTMB_TEST_SHARD must be set so coverage shards partition tests")
}

src_root <- normalizePath(".", winslash = "/")
install_path <- file.path(
  normalizePath(Sys.getenv("RUNNER_TEMP"), winslash = "/"),
  "package"
)
dir.create(file.path(install_path, "00_pkg_src"), recursive = TRUE, showWarnings = FALSE)
src_link <- file.path(install_path, "00_pkg_src", "gllvmTMB")
if (!file.exists(src_link)) {
  file.symlink(src_root, src_link)
}

cat(sprintf("coverage_commit=%s\n", system("git rev-parse HEAD", intern = TRUE)))
cat(sprintf("GLLVMTMB_TEST_SHARD=%s\n", shard))
cat(sprintf("coverage_src_root=%s\n", src_root))

code <- c(
  sprintf("src_root <- %s", deparse(src_root)),
  "pkgdir <- find.package(\"gllvmTMB\", quiet = TRUE)",
  "dir.create(file.path(pkgdir, \"00_pkg_src\"), recursive = TRUE, showWarnings = FALSE)",
  "pkg_src_link <- file.path(pkgdir, \"00_pkg_src\", \"gllvmTMB\")",
  "if (!file.exists(pkg_src_link)) file.symlink(src_root, pkg_src_link)",
  "man_dest <- file.path(pkgdir, \"man\")",
  "if (!dir.exists(man_dest)) {",
  "  dir.create(man_dest, showWarnings = FALSE)",
  "  file.copy(list.files(file.path(src_root, \"man\"), full.names = TRUE), man_dest, recursive = TRUE)",
  "}",
  "r_dest <- file.path(pkgdir, \"R\")",
  "dir.create(r_dest, showWarnings = FALSE)",
  "invisible(file.copy(",
  "  list.files(file.path(src_root, \"R\"), pattern = \"[.]R$\", full.names = TRUE),",
  "  r_dest,",
  "  overwrite = TRUE",
  "))",
  "options(Matrix.warnDeprecatedCoerce = 2)",
  "library(testthat)",
  "test_dir <- system.file(\"tests\", \"testthat\", package = \"gllvmTMB\")",
  "source(file.path(src_root, \"tests\", \"testthat\", \"helper-shard-util.R\"), local = TRUE)",
  "gllvm_shard <- gllvm_shard_filter(dir = test_dir)",
  "if (is.null(gllvm_shard)) {",
  "  testthat::test_check(\"gllvmTMB\", stop_on_failure = FALSE, stop_on_warning = FALSE)",
  "} else {",
  "  testthat::test_check(\"gllvmTMB\", filter = gllvm_shard, stop_on_failure = FALSE, stop_on_warning = FALSE)",
  "}"
)

cov <- covr::package_coverage(
  path = src_root,
  quiet = FALSE,
  clean = FALSE,
  type = "none",
  code = code,
  install_path = install_path
)
print(cov)
pct <- covr::percent_coverage(cov)
cat(sprintf(
  paste0(
    "shard_percent_coverage=%.4f (shard %s only; Codecov merges ",
    "complementary shards after a trusted main upload)\n"
  ),
  pct, shard
))
writeLines(
  sprintf("shard_percent_coverage=%.4f", pct),
  "coverage-percent.txt"
)
covr::to_cobertura(cov, filename = "cobertura.xml")
