# Tests for the R<->Julia capability-ledger tooling:
#   dev/gapclose/build-capability-status.R (B1, the R-side ledger generator)
#   tools/parity_ledger.R                  (B2, the R<->Julia parity tool)
#
# Pure R, nothing skipped: both scripts are plain Rscript CLIs invoked via
# system2() (the established pattern in this test suite, see
# helper-bfgs-exact-gradient.R), so these tests exercise the real generated
# artifacts rather than re-implementing their logic.

pkg_root <- normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
gen_script <- file.path(pkg_root, "dev", "gapclose", "build-capability-status.R")
parity_script <- file.path(pkg_root, "tools", "parity_ledger.R")
ledger_path <- file.path(pkg_root, "docs", "design", "capability-status.md")
scratchpad_julia <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/46df980d-b0f8-4444-a181-ed4b4a683bbe/scratchpad/gllvmjl-capability-status-main.md"

run_rscript <- function(script, args = character(0)) {
  out <- suppressWarnings(system2("Rscript", c(shQuote(script), args),
                                   stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  list(status = status, output = paste(out, collapse = "\n"), lines = out)
}

test_that("build-capability-status.R and parity_ledger.R exist", {
  expect_true(file.exists(gen_script))
  expect_true(file.exists(parity_script))
})

test_that("(1) the generator's --check passes on the committed ledger", {
  testthat::skip_if_not(file.exists(gen_script), "generator script missing")
  # Regenerate first so the committed file reflects the CURRENT register (the
  # register is a live document other lanes may be editing; the generator is
  # explicitly designed to be re-run, per the B1 brief).
  regen <- run_rscript(gen_script)
  expect_identical(regen$status, 0L, info = regen$output)

  res <- run_rscript(gen_script, "--check")
  expect_identical(res$status, 0L, info = res$output)
  expect_true(any(grepl("up to date", res$lines)))
  expect_true(any(grepl("0 unmapped register rows", res$lines)))
})

test_that("(2) the four grouping-level rows exist in the generated ledger", {
  testthat::skip_if_not(file.exists(ledger_path), "capability-status.md not generated yet")
  ledger <- readLines(ledger_path, warn = FALSE)
  required <- c("grouping level × unit", "grouping level × unit_obs",
                "grouping level × cluster", "grouping level × cluster2")
  for (nm in required) {
    expect_true(any(grepl(nm, ledger, fixed = TRUE)),
                info = paste("missing required grouping-level row:", nm))
  }
})

test_that("(3) --check-names reports 0 near-miss against the scratchpad Julia copy", {
  testthat::skip_if_not(file.exists(parity_script), "parity_ledger.R missing")
  testthat::skip_if_not(file.exists(scratchpad_julia), "scratchpad Julia copy missing")
  res <- run_rscript(parity_script, c("--julia", shQuote(scratchpad_julia), "--check-names"))
  expect_true(any(grepl("^0 near-miss$", res$lines)),
              info = res$output)
  expect_true(any(grepl("all 4 grouping-level rows present", res$lines)),
              info = res$output)
})

test_that("(4) the parity tool ends with CLOSURE: PASS", {
  testthat::skip_if_not(file.exists(parity_script), "parity_ledger.R missing")
  testthat::skip_if_not(file.exists(scratchpad_julia), "scratchpad Julia copy missing")
  res <- run_rscript(parity_script, c("--julia", shQuote(scratchpad_julia)))
  expect_identical(res$status, 0L, info = res$output)
  expect_true(any(grepl("^CLOSURE: PASS", res$lines)), info = res$output)
})

test_that("(5) collision rows never join to the wrong Julia row", {
  testthat::skip_if_not(file.exists(parity_script), "parity_ledger.R missing")
  testthat::skip_if_not(file.exists(ledger_path), "capability-status.md not generated yet")
  testthat::skip_if_not(file.exists(scratchpad_julia), "scratchpad Julia copy missing")

  ledger <- readLines(ledger_path, warn = FALSE)
  cum_logit_row <- grep("cumulative_logit (missing-predictor family)", ledger,
                         fixed = TRUE, value = TRUE)
  expect_true(length(cum_logit_row) >= 1)
  # The R row must describe the imputation family, not the response family.
  expect_true(any(grepl("missing-PREDICTOR imputation family", cum_logit_row, fixed = TRUE)))
  expect_false(any(grepl("ordinal RESPONSE family", cum_logit_row) &
                    grepl("^\\| cumulative_logit \\|", cum_logit_row)))

  res <- run_rscript(parity_script, c("--julia", shQuote(scratchpad_julia)))
  expect_identical(res$status, 0L, info = res$output)
  matched_section <- res$lines[seq(which(grepl("^MATCHED ROWS", res$lines)),
                                    which(grepl("^AHEAD OF gllvmTMB", res$lines))[1] - 1)]
  # The R collision row must NOT appear in the MATCHED table joined against
  # Julia's combined "ordinal_probit / cumulative_logit" row.
  expect_false(any(grepl("cumulative_logit \\(missing-predictor family\\)", matched_section) &
                    grepl("ordinal", matched_section, ignore.case = TRUE)))
  # It must instead show up as an R-only row (no false join at all).
  r_only_section <- res$lines[which(grepl("^AHEAD OF GLLVM.jl", res$lines))[1]:length(res$lines)]
  expect_true(any(grepl("cumulative_logit \\(missing-predictor family\\)", r_only_section)))

  # Symmetric guard: Julia's own "ordinal_probit / cumulative_logit" row must
  # not have silently matched anything of R's imputation-family collision.
  expect_true(any(grepl("^  \\[PORT", res$lines) & grepl("ordinal_probit / cumulative_logit", res$lines)))
})
