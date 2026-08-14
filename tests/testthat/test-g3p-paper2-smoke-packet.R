test_that("G3P Paper 2 packet is a no-fit provenance amendment", {
  path <- testthat::test_path("..", "..", "dev", "isdm-package-recovery", "2026-08-13-g3p-paper2-smoke-packet.md")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(text, "G3P_P2_PROVENANCE_V1", fixed = TRUE)
  expect_match(text, "path_only_difference", fixed = TRUE)
  expect_match(text, "does not authorise a replacement", fixed = TRUE)
  expect_match(text, "explicit approval", fixed = TRUE)
  expect_false(grepl("\\.gll_isdm_fit\\(|nlminb\\(|TMB::MakeADFun\\(|profile_theta\\(|Totoro|DRAC", text))
})
