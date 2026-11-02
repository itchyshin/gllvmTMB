## #1484: the ordinal log(1e-300) cell-probability floor is an intentional
## underflow guard. Source-scan guard that the label stays at the floor sites
## and the family help mentions it.

test_that("ordinal log_tiny_ord floors carry the intentional-guard comment", {
  src <- testthat::test_path("..", "..", "src", "gllvmTMB.cpp")
  skip_if_not(file.exists(src), "src/gllvmTMB.cpp not available (installed package)")
  lines <- readLines(src, warn = FALSE)
  idx <- grep("Type log_tiny_ord", lines, fixed = TRUE)
  expect_gte(length(idx), 2L)
  for (i in idx) {
    expect_match(lines[i - 1L], "Intentional underflow guard (#1484)", fixed = TRUE)
  }
})

test_that("?ordinal_logit and ?ordinal_probit mention the underflow floor", {
  for (topic in c("ordinal_logit", "ordinal_probit")) {
    txt <- paste(capture.output(tools::Rd2txt(
      utils:::.getHelpFile(help(topic, package = "gllvmTMB")),
      options = list(underline_titles = FALSE))), collapse = " ")
    expect_match(txt, "underflow", info = topic)
  }
})
