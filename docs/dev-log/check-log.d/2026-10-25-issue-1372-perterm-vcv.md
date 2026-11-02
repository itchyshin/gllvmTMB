# Check-log: refuse conflicting per-term vcv (#1372)

**Goal:** Confirm a same-size `vcv =` / `phylo_vcv =` mismatch aborts,
and that matching matrices still fit.

**Commands:**

    Rscript -e 'devtools::test(filter = "issue-1372-perterm-vcv")'
    rg -n "gllvmTMB_phylo_vcv_conflict" R tests NEWS.md
    rg -n "Using the global .arg phylo_vcv" R/fit-multi.R

**Results:** `test-issue-1372-perterm-vcv.R` FAIL 0 / PASS 7 / SKIP 0.
`rg -n "gllvmTMB_phylo_vcv_conflict"` hits the harvest abort, the test, NEWS, and this slice's notes.
`rg -n "Using the global .arg phylo_vcv" R/fit-multi.R` has no remaining vcv-harvest hit.

**Claim boundary:** Closes the verified VCV silent-drop in #1372. Does
not change likelihood, formula grammar, or the tree-harvest path. Does
not run the full suite or `R CMD check`.
