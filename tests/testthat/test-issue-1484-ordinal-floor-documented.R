## #1484: the ordinal log(1e-300) cell-probability floor is an intentional
## underflow guard. Source-scan guard that the label stays at the floor sites
## and the family help mentions it.

test_that("ordinal log_tiny_ord floors carry the intentional-guard comment", {
  src <- gllvmTMB_pkg_file("src", "gllvmTMB.cpp")
  lines <- readLines(src, warn = FALSE)
  idx <- grep("Type log_tiny_ord", lines, fixed = TRUE)
  expect_gte(length(idx), 2L)
  for (i in idx) {
    expect_match(lines[i - 1L], "Intentional underflow guard (#1484)", fixed = TRUE)
  }
})

test_that("?ordinal_logit and ?ordinal_probit mention the underflow floor", {
  root <- testthat::test_path("..", "..")
  for (topic in c("ordinal_logit", "ordinal_probit")) {
    path <- file.path(root, "man", paste0(topic, ".Rd"))
    expect_true(file.exists(path), info = topic)
    txt <- paste(capture.output(tools::Rd2txt(
      tools::parse_Rd(path, encoding = "UTF-8"),
      options = list(underline_titles = FALSE))), collapse = " ")
    expect_match(txt, "underflow", info = topic)
  }
})
