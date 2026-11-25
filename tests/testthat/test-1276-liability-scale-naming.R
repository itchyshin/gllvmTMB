## #1276: link_residual = "auto" summaries are liability-scale; "none" stays latent-scale.
## Reads generated Rd (same lookup pattern as test-issue-1579-extractor-help-text.R).

.rd_1276 <- function(name) {
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

.rd_section_1276 <- function(rd, start, end) {
  s <- regexpr(start, rd, fixed = TRUE)
  e <- regexpr(end, rd, fixed = TRUE)
  expect_true(s > 0L && e > s)
  substr(rd, s, e - 1L)
}

.roxygen_1276 <- function(r_file) {
  src <- gllvmTMB_pkg_file("R", r_file)
  if (!file.exists(src)) {
    testthat::skip(paste("R source missing:", r_file))
  }
  lines <- readLines(src, warn = FALSE)
  paste(lines[grepl("^#'", lines)], collapse = "\n")
}

test_that("extract_Sigma help distinguishes liability (auto) from latent (none)", {
  rd <- .rd_1276("extract_Sigma")
  expect_match(rd, "(?i)liability", perl = TRUE)
  expect_match(rd, "link_residual", fixed = TRUE)
  args <- .rd_section_1276(rd, "\\arguments{", "\\value{")
  lr <- .rd_section_1276(args, "\\item{link_residual}", "\\item{.skip_warn}")
  expect_match(lr, "(?i)liability", perl = TRUE)
  expect_match(lr, "(?i)latent scale", perl = TRUE)
  details <- .rd_section_1276(rd, "\\details{", "\\examples{")
  expect_match(details, "Villemereuil", fixed = TRUE)
  expect_match(details, "Eq\\. 4", perl = TRUE)
  expect_match(details, "Eq\\. 24", perl = TRUE)
})

test_that("extract_repeatability help names the liability-scale estimand", {
  rd <- .rd_1276("extract_repeatability")
  section <- .rd_section_1276(
    rd,
    "\\section{Latent versus liability scale}{",
    "\\section{Interval calibration}{"
  )
  expect_match(section, "(?i)liability scale", perl = TRUE)
  expect_match(section, "Eq\\. 24", perl = TRUE)
  expect_match(section, "Eq\\. 4", perl = TRUE)
  expect_match(section, "link_residual = \"none\"", fixed = TRUE)
})

test_that("bootstrap_Sigma link_residual help documents both scales", {
  rd <- .rd_1276("bootstrap_Sigma")
  args <- .rd_section_1276(rd, "\\arguments{", "\\value{")
  expect_match(args, "\\item{link_residual}", fixed = TRUE)
  expect_match(args, "(?i)liability", perl = TRUE)
  expect_match(args, "(?i)latent-scale", perl = TRUE)
})

test_that("extract_residual_split roxygen keeps liability wording for sigma2_d", {
  block <- .roxygen_1276("extract-omega.R")
  expect_match(block, "(?i)liability", perl = TRUE)
  expect_match(block, "sigma2_d", fixed = TRUE)
})