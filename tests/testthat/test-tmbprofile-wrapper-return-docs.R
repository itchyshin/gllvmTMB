test_that("tmbprofile_wrapper Rd aligns @return with Boundary behaviour", {
  rd_path <- gllvmTMB_pkg_file("man", "tmbprofile_wrapper.Rd")
  rd <- paste(readLines(rd_path, warn = FALSE), collapse = "\n")
  expect_match(rd, "transformed limit|transformed boundary", ignore.case = TRUE)
  expect_match(rd, "truncated profile search|could not be located", ignore.case = TRUE)
  expect_false(grepl("may be \\\\code\\{NA\\} when the profile is one-sided", rd, fixed = TRUE))
})
