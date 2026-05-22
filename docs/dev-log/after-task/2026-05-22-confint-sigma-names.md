# After-Task Report: `confint()` Sigma Names

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Boole, Fisher, Rose, Grace
**Spawned subagents:** none

## Scope

Added canonical `confint()` Sigma parameter names for the unit-level covariance
targets:

- `parm = "Sigma_unit"`
- `parm = "Sigma_unit_obs"`

The legacy aliases `parm = "Sigma_B"` and `parm = "Sigma_W"` remain accepted.
Returned `parameter` labels follow the token the user requested, so existing
scripts keep their historical `Sigma_B[...]` / `Sigma_W[...]` labels while new
examples can use `Sigma_unit[...]` / `Sigma_unit_obs[...]`.

This is a naming and documentation slice. It does not change the numerical
definition of the confidence intervals.

## Files Touched

- `R/z-confint-gllvmTMB.R`
- `R/extractors.R`
- `man/confint.gllvmTMB_multi.Rd`
- `tests/testthat/test-confint-bootstrap.R`
- `tests/testthat/test-profile-ci.R`
- `docs/design/44-m3-3-inference-replacement.md`
- `NEWS.md`
- `docs/dev-log/check-log.md`

## What Changed

- Added internal `confint()` Sigma-token metadata so canonical and legacy names
  map to the same extraction targets.
- Routed canonical `Sigma_unit` / `Sigma_unit_obs` requests through canonical
  `level = "unit"` / `"unit_obs"` calls, avoiding internal legacy `B` / `W`
  warnings.
- Updated roxygen and generated Rd to lead with canonical names and document
  legacy aliases.
- Added a NEWS entry with IN / PARTIAL / PLANNED scope boundary and register
  row IDs.
- Updated tests so the primary `confint()` examples use `Sigma_unit`; added a
  regression that `Sigma_B` remains a no-warning legacy alias with equivalent
  point estimates.
- Updated the M3.3 inference design note to use
  `confint(fit, parm = "Sigma_unit", method = "bootstrap")`.
- Fixed `extract_communality(..., level = "unit", method = "bootstrap")` so the
  internal bootstrap call uses the canonical level name and does not warn.

## Validation

- `air format R/z-confint-gllvmTMB.R R/extractors.R tests/testthat/test-confint-bootstrap.R tests/testthat/test-profile-ci.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/confint.gllvmTMB_multi.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "confint-bootstrap|profile-ci|profile-targets|sigma-rename", stop_on_failure = TRUE)'`
  -> 106 passes, 0 failures, 0 warnings, 1 known skip.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-communality-bootstrap|m1-5-extract-communality-mixed-family|plot-gllvmTMB", stop_on_failure = TRUE)'`
  -> 204 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before the report/check-log entry.
- Convention-cascade scan:

  ```sh
  rg -n 'confint\([^\n]*parm\s*=\s*"Sigma_B"|parm\s*=\s*"Sigma_W"|confint\([^\n]*Sigma_B|confint\([^\n]*Sigma_W|Sigma_B", method|Sigma_W", method' README.md NEWS.md docs/design vignettes R tests/testthat
  ```

  -> only the NEWS legacy-alias sentence and the dedicated legacy-alias
  regression remained.
- Stale primary-token scan:

  ```sh
  rg -n 'gllvmTMB_multi fit|A \\code\{gllvmTMB_multi\} fit|Confidence intervals for a \\code\{gllvmTMB_multi\} fit|\{Sigma_B, Sigma_W, sigma_phy\}|parm = "Sigma_B"' R/z-confint-gllvmTMB.R man/confint.gllvmTMB_multi.Rd NEWS.md docs/design/44-m3-3-inference-replacement.md
  ```

  -> no hits.
- Register-row cross-check:

  ```sh
  rg -n 'CI-02|CI-03|EXT-01|EXT-13|CI-10|Sigma_unit|Sigma_unit_obs|method = c\("profile", "wald", "bootstrap"\)' R/z-confint-gllvmTMB.R man/confint.gllvmTMB_multi.Rd NEWS.md docs/design/35-validation-debt-register.md
  ```

  -> source/Rd/NEWS claims map to existing register rows.
- Rd spot-check:
  `tail -5 man/confint.gllvmTMB_multi.Rd && grep -c '^\\keyword' man/confint.gllvmTMB_multi.Rd`
  -> normal ending; 0 keyword entries.

## Definition-of-Done Notes

- Implementation: local branch only. Not merged, not pushed, and no 3-OS CI on
  this branch yet.
- Simulation recovery test: not applicable; this slice adds canonical aliases
  for existing CI targets and keeps old aliases working.
- Documentation: roxygen, generated Rd, NEWS, and the relevant M3.3 design note
  were updated.
- Runnable user-facing example: the `confint()` roxygen example now uses
  `parm = "Sigma_unit"`. No README or vignette examples used the old token.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Boole/Rose checks covered naming consistency and convention
  cascade; Fisher checks covered interval-scope wording; Grace checks covered
  focused tests, pkgdown, and whitespace.

## Residuals

- The S3 topic name remains `confint.gllvmTMB_multi` because that is the method
  name. This is not a user-facing argument convention.
- Full package tests, full `devtools::check()`, and 3-OS CI were not run in
  this local slice.
