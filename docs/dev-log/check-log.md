# Check log

Append-only record of `R CMD check`, `devtools::test()`, and
`pkgdown` runs that produced meaningful evidence. Keep entries
date-stamped.

## 2026-05-10 -- drmTMB-parity match exposes unstated tidyselect

Scope:

- removed `--no-manual --ignore-vignettes` / `--no-build-vignettes`
  overrides from `.github/workflows/R-CMD-check.yaml` so R CMD check
  runs drmTMB-exact defaults;
- the strict defaults surfaced `* checking for unstated dependencies
  in 'tests' ... WARNING` (1 WARNING, 0 ERROR, 0 NOTE) on ubuntu and
  macos runs of PR #3 (run id 25640098258);
- root cause: `tidyselect` was in DESCRIPTION `Imports` (for
  `R/traits-keyword.R` and `R/gllvmTMB-wide.R`) but not in
  `Suggests` (for the test files that use `tidyselect::all_of` and
  related verbs);
- added `tidyselect` to `Suggests:` so R CMD check finds the test-
  side namespace declaration too.

Decision: the drmTMB-parity strictness is doing exactly what it
should -- surfacing real issues our skip-args were masking. Keep
the strictness; fix the underlying declarations.
