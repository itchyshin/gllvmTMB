# Check-log: auto-Psi skip note for multinomial traits (#1580)

**Goal:** Confirm the note printed when the default between-unit Psi is skipped no longer names `theta_diag_B[t]` / `s_B`, and names only the kind of trait that was skipped.

**Commands** (R 4.3.3, Ubuntu 24.04, `NOT_CRAN=true`, package installed from this branch, `testthat::test_file(..., load_package = "installed")`):

    test-issue-1580-message-text.R            pass 33  fail 0   (on main @ 902c069c: pass 10  fail 23)
    test-cross-family-multinomial.R           pass 42  fail 0
    test-degenerate-laplace-optima.R          pass 154 fail 0
    test-issue-1574-explicit-ordinal-indep.R  pass 8   fail 0
    test-multinomial-fence.R                  pass 79  fail 0  (3 warnings, as on main)
    test-print-covstruct-labels-1580.R        pass 9   fail 0
    test-issue-1580-vcov-sigma-notes.R        pass 7   fail 0

Stale-wording scan: `rg "categorical-contrast / single-observation|theta_diag_B\[t\]" R tests vignettes NEWS.md` finds the umbrella wording only in `.auto_psi_skip_message()` (mixed fits) and the pinned bin+ordinal test (`test-degenerate-laplace-optima.R:309`, unchanged). The two other `Mapped {.code theta_diag_*[t]}` strings (W-tier OLRE note and the explicit-`indep()` ordinal warning, `R/fit-multi.R`) are outside this slice and were not touched.

**Not run:** full `devtools::test()`, `devtools::check()`, `pkgdown::check_pkgdown()`. CI on the draft PR covers them.

**Claim boundary:** Message text only. Which traits get a between-unit Psi, the fitted model, defaults and exports are unchanged. #1580 stays open (its remaining text items are done on main; this was the last unchecked box).
