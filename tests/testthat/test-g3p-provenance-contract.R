source(testthat::test_path("..", "..", "dev", "isdm-package-recovery", "g3p-provenance-contract.R"))

g3p_identity_fixture <- function() list(
  commit = "commit", runner_md5 = "runner", fixture_md5 = "fixture", packet_md5 = "packet",
  source_md5 = c(fit_multi = "fit", isdm_fit = "isdm", tmb = "tmb", dll = "dll"),
  runtime = list(architecture = "arm64-apple-darwin", r_version = "4.5.0", tmb_version = "1.9.17", package_version = "0.6.0"),
  dll_path = "/tmp/first/gllvmTMB.so"
)

test_that("G3P accepts equal stable identity across temporary DLL paths", {
  expected <- g3p_identity_fixture()
  observed <- expected
  observed$dll_path <- "/tmp/second/gllvmTMB.so"
  out <- g3p_compare_identity(expected, observed)
  expect_identical(out$status, "MATCH")
  expect_identical(out$terminal, FALSE)
  expect_identical(out$reason, "path_only_difference")
  expect_identical(out$fields$binding, c(rep(TRUE, 12L), FALSE))
})

test_that("G3P rejects content or ABI identity drift", {
  expected <- g3p_identity_fixture()
  changed_dll <- expected
  changed_dll$source_md5[["dll"]] <- "different-dll"
  changed_abi <- expected
  changed_abi$runtime$architecture <- "x86_64-apple-darwin"
  for (observed in list(changed_dll, changed_abi)) {
    out <- g3p_compare_identity(expected, observed)
    expect_identical(out$status, "INVALID_PROVENANCE")
    expect_identical(out$terminal, TRUE)
    expect_identical(out$reason, "binding_identity_mismatch")
  }
})

test_that("G3P rejects malformed identity before a smoke", {
  expected <- g3p_identity_fixture()
  observed <- expected
  observed$runtime$tmb_version <- NA_character_
  out <- g3p_compare_identity(expected, observed)
  expect_identical(out$status, "INVALID_PROVENANCE")
  expect_identical(out$reason, "malformed_or_incomplete_identity")
  expect_identical(out$fields$field, "identity")
})
