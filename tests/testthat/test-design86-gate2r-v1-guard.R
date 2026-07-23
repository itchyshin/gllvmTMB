test_that("Design 86 Gate-2R V1 remains unsigned without a Gate-B record", {
  skip_if_not_installed("jsonlite")
  source(test_path("..", "..", "dev", "design86-gate2-eva-runner.R"), local = TRUE)
  parameters <- .eva_read_gate2_parameters()
  authorization <- .d86_gate2r_authorization(.d86_root(), parameters, required = FALSE)
  expect_identical(parameters$gate2r$version, "G2R-V1")
  expect_identical(parameters$gate2r$one_seed_smoke_seed, 86200002L)
  expect_false(authorization$signed)
  expect_equal(sum(grepl("^\\*\\*Maintainer:\\*\\* PENDING$",
                         readLines(authorization$amendment, warn = FALSE))), 1L)
  expect_match(parameters$provenance$output_root, "gate2r-v1-one-seed$")
})

test_that("Design 86 Gate-2R V1 changes only prospective authorization fields", {
  skip_if_not_installed("jsonlite")
  root <- test_path("..", "..")
  historical <- jsonlite::fromJSON(
    file.path(root, "docs", "design", "86-eva-gate2-anchor-parameters.json"),
    simplifyVector = FALSE
  )
  candidate <- jsonlite::fromJSON(
    file.path(root, "docs", "design", "86-eva-gate2r-v1-parameters.json"),
    simplifyVector = FALSE
  )
  historical[c("status", "fixture_checksum_recorded_in", "maintainer_signoff")] <- NULL
  candidate[c("status", "fixture_checksum_recorded_in", "maintainer_signoff", "gate2r")] <- NULL
  historical$provenance[c("input_manifest_path", "output_root")] <- NULL
  candidate$provenance[c("input_manifest_path", "output_root", "amendment_path")] <- NULL
  expect_equal(candidate, historical)
  expect_identical(candidate$replicates$seed_array_checksum_sha256,
                   "9ab57cfb07f29e16a648088bbdfb4ebe6bb848a42b43ff3c48e7c76a67c4e29a")
})
