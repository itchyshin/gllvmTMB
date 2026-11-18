# Check-log: vcov profile hint and extract_Sigma part notes (#1580)

**Goal:** Confirm `vcov()` no longer names `method = "profile"` and
that `extract_Sigma(part = "shared")` does not print a residual note.

**Commands:**

    Rscript -e 'devtools::test(filter = "issue-1580-vcov-sigma-notes")'
    rg -n "route = NULL" R/vcov-coef.R

**Results:** recorded after the focused test run.

**Claim boundary:** Refs #1580 (two remaining items). Does not close
the other message items on that issue. No full suite, no `R CMD check`.
