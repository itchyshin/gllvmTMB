# After Task: NEWS heading repair for CRAN version-note

**Date:** 2026-06-17  
**Branch:** `codex/r-bridge-grouped-dispersion`  
**Slice:** Release-hygiene repair for #486.

## Summary

R's CRAN-style NEWS parser was still treating six topic headings under the
`gllvmTMB 0.2.0 (first CRAN release)` section as version headings. This caused
the local `--as-cran` note:

> Cannot extract version info from the following section titles

The fix is structural only: the affected topic headings are now third-level
subsections (`###`) rather than second-level version-like headings (`##`).

## Files changed

- `NEWS.md`
  - `User-facing API`
  - `Inference`
  - `Phylogenetic and spatial paths`
  - `Inherited code and citation`
  - `Source-tree notes`
  - `Relationship to a pre-0.2.0 development line`

No package API, examples, generated Rd, NAMESPACE, bridge code,
validation-register rows, likelihood code, or formula grammar changed.

## Validation

- `git diff --check`
  - clean.
- `Rscript --vanilla -e 'devtools::check(args = "--as-cran", quiet = FALSE, error_on = "never")'`
  - `0 errors | 1 warning | 1 note` in 5m37.2s.
  - The NEWS.md version-info note is gone.
  - Remaining warning: known local macOS compiler warning from
    `R_ext/Boolean.h` (`-Wfixed-enum-extension`, SDK `NA`).
  - Remaining note: `unable to verify current time`.

## Rose gate

Rose result: **PASS** for this narrow NEWS-only change.

The diff changes heading depth only. It does not alter method lists, defaults,
function names, keyword-grid wording, argument-name claims, family lists,
scope-boundary wording, validation-row references, exported functions, pkgdown
navigation, or article links.

## Definition-of-done notes

1. **Implementation:** NEWS heading structure repaired on the current branch.
2. **Simulation recovery:** Not applicable; no model, likelihood, estimator, or
   validation status changed.
3. **Documentation:** `NEWS.md` updated; no roxygen/Rd regeneration required.
4. **Runnable example:** Not applicable; no example or user workflow changed.
5. **Check-log:** Entry added in `docs/dev-log/check-log.md`.
6. **Review pass:** Rose narrow pre-publish consistency pass recorded above.

## Remaining boundaries

This does not make #489 release-ready. The bridge ordering gate remains
GLLVM.jl #95 -> GLLVM.jl #101 -> paired gllvmTMB #489 refresh, and the
power-pilot / CI-08 / CI-10 evidence remains process evidence until Fisher and
Curie scoring supports any coverage or power promotion.
