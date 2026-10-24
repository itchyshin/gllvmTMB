## #1579: extractor help pages must not contradict behaviour.
## Reads the generated Rd so a later document() cannot reintroduce the wording.
## Same source lookup as test-1392-temporal-help-preconditions.R (R CMD check
## runs from <pkg>.Rcheck/tests/testthat).

.rd_1579 <- function(name) {
  rel <- file.path("man", paste0(name, ".Rd"))
  candidates <- c(
    testthat::test_path("..", "..", rel),
    testthat::test_path("..", "..", "00_pkg_src", "gllvmTMB", rel),
    testthat::test_path("..", "..", "..", "00_pkg_src", "gllvmTMB", rel)
  )
  found <- candidates[file.exists(candidates)]
  if (length(found) == 0L) {
    testthat::skip("Rd source not available in this check tree")
  }
  paste(readLines(found[[1L]], warn = FALSE), collapse = "\n")
}

.rd_section_1579 <- function(rd, start, end) {
  s <- regexpr(start, rd, fixed = TRUE)
  e <- regexpr(end, rd, fixed = TRUE)
  expect_true(s > 0L && e > s)
  substr(rd, s, e - 1L)
}

test_that("extract_Sigma_table @return and @param entries match behaviour", {
  rd <- .rd_1579("extract_Sigma_table")
  value <- .rd_section_1579(rd, "\\value{", "\\description{")
  expect_match(value, "validation_row", fixed = TRUE)
  expect_false(grepl("because this helper is point-estimate only", value, fixed = TRUE))
  expect_match(value, "bootstrap_Sigma", fixed = TRUE)
  expect_match(value, "interval_status", fixed = TRUE)
  args <- .rd_section_1579(rd, "\\arguments{", "\\value{")
  entries <- .rd_section_1579(args, "\\item{entries}", "\\item{link_residual}")
  expect_match(entries, "(?si)ignored.*part = \"unique\"", perl = TRUE)
})

test_that("extract_Sigma level help names kernel tiers", {
  rd <- .rd_1579("extract_Sigma")
  args <- .rd_section_1579(rd, "\\arguments{", "\\item{part}")
  expect_match(args, "(?s)kernel_\\*\\(\\).*tier", perl = TRUE)
  expect_false(grepl("For now, custom strings error", rd, fixed = TRUE))
})

test_that("extract_correlations does not claim a level for point estimates", {
  rd <- .rd_1579("extract_correlations")
  expect_false(grepl("or other-level", rd, fixed = TRUE))
})

test_that("extract_latent_scores help has no literal TeX and no Julia claim", {
  rd <- .rd_1579("extract_latent_scores")
  expect_false(grepl("times K", rd, fixed = TRUE))
  expect_false(grepl("gllvmTMB_julia", rd, fixed = TRUE))
  expect_match(rd, "n-by-K", fixed = TRUE)
})

test_that("extract_ordination @return lists row_id and the temporal extras", {
  rd <- .rd_1579("extract_ordination")
  value <- .rd_section_1579(rd, "\\value{", "\\description{")
  for (nm in c("row_id", "row_index", "temporal_sign")) {
    expect_match(value, nm, fixed = TRUE)
  }
})

test_that("extract_Gamma help carries no internal test code", {
  rd <- .rd_1579("extract_Gamma")
  expect_false(grepl("C2 recovery", rd, fixed = TRUE))
})
