test_that("G3 smallest-smoke packets remain immutable no-run proposals", {
  root <- testthat::test_path("..", "..", "dev", "isdm-package-recovery")
  packet <- function(name) paste(readLines(file.path(root, name), warn = FALSE), collapse = "\n")
  p1 <- packet("2026-08-13-g3-paper1-smallest-smoke-packet.md")
  p2 <- packet("2026-08-13-g3-paper2-smallest-smoke-packet.md")

  expect_match(p1, "G3_P1_S3_C360_R3_V1", fixed = TRUE)
  expect_match(p1, "seed | `86301L`", fixed = TRUE)
  expect_match(p1, "`S=3`, `C=360`, `r=3`", fixed = TRUE)
  expect_match(p1, "10–15 minutes", fixed = TRUE)
  expect_match(p1, "execution not authorised", fixed = TRUE)
  expect_match(p1, "exactly nine", fixed = TRUE)

  expect_match(p2, "G3_P2_S6_C360_R3_V1", fixed = TRUE)
  expect_match(p2, "seed | `86302L`", fixed = TRUE)
  expect_match(p2, "`S=6`, `C=360`, `r=3`", fixed = TRUE)
  expect_match(p2, "15–25 minutes", fixed = TRUE)
  expect_match(p2, "execution not authorised", fixed = TRUE)
  expect_match(p2, "all nine", fixed = TRUE)

  for (text in list(p1, p2)) {
    expect_match(text, "same-objective `fn\\+gr`", perl = TRUE)
    expect_match(text, "No profile", fixed = TRUE)
    expect_match(text, "Gate-B approval", fixed = TRUE)
  }
})
