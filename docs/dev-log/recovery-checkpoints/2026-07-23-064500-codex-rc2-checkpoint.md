# RC.2 honesty correction checkpoint

## State

- Branch: `claude/0.6-m1-close-20260722`, clean and pushed at
  `e4fdc370dfe5545035d858ecfb3c3014271127e0`.
- The candidate changes 12 release surfaces: the intended eleven public claim
  / generated-Rd files plus `cran-comments.md`.  The latter now records that
  a 0.6.0 release and CRAN distribution are separate maintainer decisions.
- No tag has been created. `v0.6.0-rc.1` is untouched.

## Completed evidence

- `devtools::document(quiet = TRUE)`: regenerated only the four expected Rd
  pages.
- `pkgdown::check_pkgdown()`: passed.
- `urlchecker::url_check()`: passed (with the sandbox network restriction
  lifted for the check).
- `devtools::test(reporter = "summary")`: completed with no failures/errors;
  the ordinary suite retained 779 documented skips.  The ungated
  cross-family profile test was slow but passed; prior exact-head evidence
  recorded 117 passes in 470.6 seconds for that focused group.
- `git diff --check`: passed before commit. A case-insensitive scan for
  `calibration is established|is calibrated|cleared the coverage gate` across
  shipped claim surfaces found no matches.
- `R CMD build .`: passed at the candidate commit and produced
  `gllvmTMB_0.6.0.tar.gz` in this worktree: 3.1 MB, 595 entries,
  SHA-256 `1ad3b0ebde2e8a3624cffe492c91246dcad9641eab4c7a58cc416f0a677eed1b`.

## Still required before any candidate tag

1. Run the frozen-tarball incoming-style check (`R CMD check --as-cran
   --run-donttest`) and retain its complete log, required-Suggests receipt,
   inventory/forbidden-path scan, and clean-status proof.
2. Rebuild only if that check or any record edit changes the exact commit.
3. Create/push annotated `v0.6.0-rc.2` only after those receipts, then prove
   tag -> commit -> tarball identity and collect exact-tag CI evidence.

## CRAN boundary

The source authority is
`docs/design/75-inference-route-truth-matrix.md:96-99`: no interval cell is
empirical-coverage-calibrated.  A fresh RC.2 R-devel win-builder result is
needed only to call this package **CRAN submission-ready**.  Shinichi may
release 0.6.0 outside CRAN; do not submit to CRAN or cut final `v0.6.0`.
