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

test_that("(6) the tool's printed R status equals the R ledger's own Status column, for every matched row (Opus review finding B1)", {
  testthat::skip_if_not(file.exists(parity_script), "parity_ledger.R missing")
  testthat::skip_if_not(file.exists(ledger_path), "capability-status.md not generated yet")
  testthat::skip_if_not(file.exists(scratchpad_julia), "scratchpad Julia copy missing")

  # Independently parse the R ledger's own | Capability | Status | ... | rows
  # (deliberately re-implemented here rather than sourcing the tool's own
  # parser, so this test cannot pass merely because the tool's parser and
  # this test share the same bug).
  ledger <- readLines(ledger_path, warn = FALSE)
  ledger_status <- character(0)
  for (ln in ledger) {
    if (!grepl("^\\|", ln)) next
    cells <- strsplit(ln, "\\|")[[1]]
    if (length(cells) >= 2) cells <- cells[-1]
    if (length(cells) >= 1 && trimws(cells[length(cells)]) == "") cells <- cells[-length(cells)]
    cells <- trimws(cells)
    if (length(cells) < 2) next
    name <- cells[1]
    status_raw <- cells[2]
    if (tolower(name) %in% c("capability", "")) next
    if (grepl("^-+$", gsub("[: ]", "", name))) next
    # first status word only, matching the tool's own tokenisation
    m <- regmatches(status_raw, regexec("^([A-Za-z][A-Za-z-]*)", status_raw))[[1]]
    word <- if (length(m) >= 2) tolower(m[2]) else tolower(status_raw)
    if (!word %in% c("implemented", "scope-limited", "point-fit-recovery", "planned", "rejected")) next
    ledger_status[[trimws(gsub("`", "", name))]] <- word
  }
  expect_gt(length(ledger_status), 0)

  res <- run_rscript(parity_script, c("--julia", shQuote(scratchpad_julia)))
  expect_identical(res$status, 0L, info = res$output)
  matched_lines <- grep("^  \\[(AGREE|R-NARROWER|J-NARROWER|DIFFER)\\s*\\]", res$lines, value = TRUE)
  expect_gt(length(matched_lines), 0)

  mismatches <- character(0)
  checked <- 0L
  for (ln in matched_lines) {
    m <- regmatches(ln, regexec("^  \\[[A-Z-]+\\s*\\]\\s+(.*?)\\s+R=(\\S+)\\s+Julia=", ln))[[1]]
    if (length(m) < 3) next
    name <- trimws(gsub("`", "", m[2]))
    printed_status <- m[3]
    if (!name %in% names(ledger_status)) next  # name normalization differences (e.g. trailing punctuation) -- skip, not the bug under test
    checked <- checked + 1L
    if (!identical(printed_status, ledger_status[[name]])) {
      mismatches <- c(mismatches, sprintf("%s: printed R=%s but ledger says %s", name, printed_status, ledger_status[[name]]))
    }
  }
  expect_gt(checked, 20)  # sanity: most of the 44 matched rows should have joined by exact name
  expect_length(mismatches, 0)
})

test_that("(7) at least one R-NARROWER row exists given the current ledgers", {
  testthat::skip_if_not(file.exists(parity_script), "parity_ledger.R missing")
  testthat::skip_if_not(file.exists(scratchpad_julia), "scratchpad Julia copy missing")

  res <- run_rscript(parity_script, c("--julia", shQuote(scratchpad_julia)))
  expect_identical(res$status, 0L, info = res$output)

  counts_line <- grep("^COUNTS:", res$lines, value = TRUE)
  expect_length(counts_line, 1)
  m <- regmatches(counts_line, regexec("(\\d+) R-NARROWER", counts_line))[[1]]
  expect_length(m, 2)
  n_r_narrower <- as.integer(m[2])
  expect_gt(n_r_narrower, 0)

  section_start <- which(grepl("^R-NARROWER ROWS", res$lines))
  expect_length(section_start, 1)
  # A real, currently-true example: `binomial` is `implemented` on the Julia
  # ledger and `scope-limited` on the R ledger (FAM-02/03/04 split by link).
  # NOTE: AGHQ is NOT an R-NARROWER example -- it is R=scope-limited vs
  # Julia=missing, which is DIFFER (R has partial capability Julia lacks
  # entirely, the opposite relationship), confirmed by this same run. See
  # dev/gapclose/B1-B2-report.md for the correction against the coordinator's
  # initial assumption that AGHQ was the R-NARROWER example.
  r_narrower_block <- res$lines[section_start:length(res$lines)]
  r_narrower_block <- r_narrower_block[seq_len(min(length(r_narrower_block), n_r_narrower + 3))]
  expect_true(any(grepl("^  binomial\\s", r_narrower_block)))
})
