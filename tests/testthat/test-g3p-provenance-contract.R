source(testthat::test_path("..", "..", "dev", "isdm-package-recovery", "g3p-provenance-contract.R"))

g3p_identity_fixture <- function() list(
  commit = "commit", runner_md5 = strrep("a", 32L), fixture_md5 = strrep("b", 32L), packet_md5 = strrep("c", 32L),
  source_md5 = c(fit_multi = strrep("d", 32L), isdm_fit = strrep("e", 32L), tmb = strrep("f", 32L), dll = strrep("1", 32L)),
  runtime = list(architecture = "arm64-apple-darwin", r_version = "4.5.0", tmb_version = "1.9.17", package_version = "0.6.0"),
  dll_path = "/tmp/first/gllvmTMB.so"
)

test_that("G3P accepts an exact stable identity match", {
  expected <- g3p_identity_fixture()
  out <- g3p_compare_identity(expected, expected)
  expect_identical(out$status, "MATCH")
  expect_identical(out$terminal, FALSE)
  expect_identical(out$reason, "exact_identity_match")
  expect_true(all(out$fields$equal))
})

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
  changed_dll$source_md5[["dll"]] <- strrep("2", 32L)
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
  expect_identical(nrow(out$fields), 13L)
})

test_that("G3P rejects non-MD5 receipt values", {
  expected <- g3p_identity_fixture()
  observed <- expected
  observed$runner_md5 <- "not-an-md5"
  expect_identical(g3p_compare_identity(expected, observed)$status, "INVALID_PROVENANCE")
})

test_that("G3P binds the preflight execution context before a smoke", {
  expected <- list(
    schema = "G3P_P2_SMOKE_V2_PREFLIGHT_V1", source_gate = "G3P_P2_SMOKE_V2",
    root_id = "G3P_P2_S6_C360_R3_V2", attempt_id = "paper2-g3-smoke-v2-86302"
  )
  observed <- expected
  observed$source_gate <- "G3P_P2_OTHER_V2"
  out <- g3p_compare_execution_context(expected, observed)
  expect_identical(out$status, "INVALID_PROVENANCE")
  expect_identical(out$reason, "execution_context_mismatch")
  expect_true(out$terminal)
  expect_identical(nrow(out$fields), 4L)
})

test_that("G3P runner applies the receipt contract before optimizer entry", {
  path <- testthat::test_path("..", "..", "dev", "isdm-package-recovery", "run-g3-paper2-smoke.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(text, "source\\(provenance_contract, local = TRUE\\)")
  expect_match(text, "provenance <- g3p_compare_identity\\(receipt, observed_identity\\)")
  expect_match(text, "ledger\\$provenance <- provenance")
})

test_that("G3P runner requires explicit packet and source-gate binding for V2", {
  path <- testthat::test_path("..", "..", "dev", "isdm-package-recovery", "run-g3-paper2-smoke.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(text, 'packet_arg <- value\\("packet"\\)')
  expect_match(text, 'source_gate <- value\\("source-gate"')
  expect_match(text, 'root_id <- value\\("root-id"')
  expect_match(text, 'attempt_id <- value\\("attempt-id"')
  expect_match(text, 'time_estimate <- value\\("time-estimate"')
  expect_match(text, 'schema = paste0\\(source_gate')
  expect_match(text, 'source_gate = source_gate')
  expect_match(text, "g3p_compare_execution_context\\(receipt, observed_context\\)")
  expect_match(text, "A non-V1 source gate requires explicit packet, root, attempt, and time values")
})
