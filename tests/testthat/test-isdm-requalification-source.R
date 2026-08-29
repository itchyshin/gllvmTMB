qualify_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "qualify-source.R"
)
verify_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "verify-source-contract.R"
)
if (!all(file.exists(c(qualify_path, verify_path)))) {
  test_that("developer-only iSDM qualification sources are available", {
    skip("dev/isdm-requalification is absent from the built package")
  })
} else {
source(qualify_path, local = TRUE, chdir = TRUE)
source(verify_path, local = TRUE, chdir = TRUE)

.source_identity <- function(root = tempfile("installed-package-")) {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  writeLines("Package: gllvmTMB", file.path(root, "DESCRIPTION"))
  identity <- list(
    source_sha = paste(rep("a", 40L), collapse = ""),
    source_tree = paste(rep("b", 40L), collapse = ""),
    worktree_status = character(), source_hashes = c(a = "source-hash"),
    package_path = normalizePath(root), library_paths = "/library",
    package_version = "0.0.0.9000", dll_path = "/installed/gllvmTMB.so",
    dll_sha256 = paste(rep("c", 64L), collapse = "")
  )
  identity$package_hashes <- isdm_installed_package_hashes(identity$package_path)
  identity
}

.ci_receipt <- function(identity) list(
  schema = "isdm-ci-receipt-v1", verified = TRUE, conclusion = "success",
  head_sha = identity$source_sha,
  run_url = "https://github.com/example/gllvmTMB/actions/runs/12345",
  platform_conclusions = c(linux = "success", macos = "success",
                           windows = "success")
)

.install_receipt <- function(identity, hashes) list(
  schema = "isdm-install-receipt-v1", source_sha = identity$source_sha,
  source_tree = identity$source_tree, package_path = identity$package_path,
  package_version = identity$package_version, package_hashes = hashes,
  dll_path = identity$dll_path, dll_sha256 = identity$dll_sha256
)

test_that("CI receipt is verified and bound to exact head and run URL", {
  identity <- .source_identity()
  receipt <- .ci_receipt(identity)
  expect_invisible(isdm_validate_ci_receipt(receipt, identity$source_sha))
  expect_error(isdm_validate_ci_receipt(within(receipt, verified <- FALSE),
                                        identity$source_sha),
               "independently verified")
  expect_error(isdm_validate_ci_receipt(within(receipt, head_sha <- "wrong"),
                                        identity$source_sha),
               "exact source SHA")
  expect_error(isdm_validate_ci_receipt(
    within(receipt, run_url <- "https://example.test/green"),
    identity$source_sha), "GitHub Actions run URL")
  receipt$platform_conclusions[["windows"]] <- "failure"
  expect_error(isdm_validate_ci_receipt(receipt, identity$source_sha),
               "Windows jobs")
})

test_that("install receipt binds source, tree, package files, and DLL", {
  identity <- .source_identity()
  hashes <- isdm_installed_package_hashes(identity$package_path)
  receipt <- .install_receipt(identity, hashes)
  expect_invisible(isdm_validate_install_receipt(receipt, identity))
  expect_error(isdm_validate_install_receipt(
    within(receipt, source_tree <- "wrong"), identity), "exact source/tree")
  receipt$package_hashes[[1L]] <- "wrong"
  expect_error(isdm_validate_install_receipt(receipt, identity),
               "installed package/DLL hashes")
})

test_that("qualification consumes receipts and verification detects drift", {
  identity <- .source_identity()
  hashes <- isdm_installed_package_hashes(identity$package_path)
  ci_path <- tempfile(fileext = ".rds")
  install_path <- tempfile(fileext = ".rds")
  output <- tempfile(fileext = ".rds")
  saveRDS(.ci_receipt(identity), ci_path)
  saveRDS(.install_receipt(identity, hashes), install_path)

  contract <- isdm_qualify_source(
    output, ci_path, install_path, identity_fn = function() identity,
    origin_main_fn = function() identity$source_sha
  )
  expect_identical(contract$schema, "isdm-source-contract-v2")
  expect_identical(readRDS(output)$package_hashes, hashes)

  verified <- isdm_verify_source_contract(
    output, identity_fn = function() identity,
    origin_main_fn = function() identity$source_sha
  )
  expect_identical(verified$source_sha, identity$source_sha)

  drifted <- identity
  drifted$dll_sha256 <- paste(rep("d", 64L), collapse = "")
  expect_error(isdm_verify_source_contract(
    output, identity_fn = function() drifted,
    origin_main_fn = function() identity$source_sha
  ), "install receipt")
})

test_that("unreadable qualification inputs fail closed", {
  expect_error(isdm_read_qualification_receipt(tempfile(), "CI"),
               "existing RDS")
  path <- tempfile(fileext = ".rds")
  writeLines("not RDS", path)
  expect_error(isdm_read_qualification_receipt(path, "CI"), "unreadable")
})
}
