## #1580: auto-Psi skip notes must not blanket-label multinomial-only fits
## or expose internal parameter names.

test_that("multinomial-only Psi skip uses a multinomial headline (#1580)", {
  msg <- gllvmTMB:::.auto_psi_skip_message(multinomial_labs = c("cat:2", "cat:3"))
  text <- paste(unname(msg), collapse = "\n")
  expect_match(text, "multinomial contrast trait", fixed = TRUE)
  expect_false(grepl("single-trial binomial", text, fixed = TRUE))
  expect_false(grepl("binary / categorical-contrast", text, fixed = TRUE))
  expect_false(grepl("theta_diag_B", text, fixed = TRUE))
  expect_match(text, "not estimated", fixed = TRUE)
})

test_that("binomial-only Psi skip does not use the multinomial blanket (#1580)", {
  text <- paste(unname(gllvmTMB:::.auto_psi_skip_message(
    binomial_labs = "bin"
  )), collapse = "\n")
  expect_match(text, "1 single-trial binomial trait", fixed = TRUE)
  expect_false(grepl("binary / categorical-contrast", text, fixed = TRUE))
})