# After-Task Report: Diagnostic Reference Docs

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Pat, Fisher, Grace, Rose
**Spawned subagents:** none

## Scope

Cleaned the diagnostics and uncertainty reference cluster:

- `confint_inspect()`
- `profile_targets()`
- `bootstrap_Sigma()`
- `check_gllvmTMB()`
- `gllvmTMB_diagnose()`
- `sanity_multi()`
- `check_identifiability()`
- `coverage_study()`
- `gllvmTMB_check_consistency()`

This is a reference-documentation slice. It does not change fitting,
likelihoods, interval calculations, or plotting geometry.

## Files Touched

- `R/confint-inspect.R`
- `R/profile-targets.R`
- `R/bootstrap-sigma.R`
- `R/diagnose.R`
- `R/methods-gllvmTMB.R`
- `R/check-identifiability.R`
- `R/coverage-study.R`
- `R/check-consistency.R`
- `man/confint_inspect.Rd`
- `man/profile_targets.Rd`
- `man/bootstrap_Sigma.Rd`
- `man/check_gllvmTMB.Rd`
- `man/gllvmTMB_diagnose.Rd`
- `man/sanity_multi.Rd`
- `man/check_identifiability.Rd`
- `man/coverage_study.Rd`
- `man/gllvmTMB_check_consistency.Rd`
- `docs/dev-log/check-log.md`

## What Changed

- Reframed `check_gllvmTMB()`, `gllvmTMB_diagnose()`, and
  `sanity_multi()` as the first-line fit-health tools users should run after
  fitting.
- Marked `confint_inspect()` and `profile_targets()` as advanced profile-CI
  diagnostics rather than normal first-use workflow.
- Reframed `bootstrap_Sigma()` as the practical simulate-refit fallback when
  Hessian, Wald, or profile intervals are unsafe, while saying explicitly that
  `pdHess = FALSE` or skipped `sdreport()` is an inference warning, not
  automatic proof that point estimates are unusable.
- Marked `check_identifiability()`, `coverage_study()`, and
  `gllvmTMB_check_consistency()` as advanced validation helpers.
- Added explicit IN / PARTIAL / PLANNED scope-boundary wording with validation
  row IDs for the edited public reference pages.
- Replaced a stale internal simulation comment that described bootstrap
  variability as "true posterior uncertainty" with "parametric simulate-refit
  uncertainty."
- Ran `air format` on the touched R files, so several diffs include formatter
  normalization around the documentation blocks as well as the prose edits.

## Validation

- Pre-edit lane check:
  `git status --short --branch`
  -> `codex/reference-function-audit-2026-05-22`, clean, ahead 6.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,updatedAt`
  -> no open PRs.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> recent local work is the current reference-audit lane on top of
  `origin/main` commit `c1dc2e4`.
- `air format R/confint-inspect.R R/profile-targets.R R/bootstrap-sigma.R R/diagnose.R R/methods-gllvmTMB.R R/check-identifiability.R R/coverage-study.R R/check-consistency.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated the affected diagnostic Rd files.
- `Rscript --vanilla -e 'devtools::test(filter = "confint-inspect|profile-targets|bootstrap-Sigma|sanity-multi|gllvmTMB-diagnose|coverage-study|check-identifiability|check-consistency|gllvmTMBcontrol", stop_on_failure = TRUE)'`
  -> 221 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before the report/check-log entry.
- Stale first-line wording scan:

  ```sh
  rg -n 'gllvmTMB_multi fit|gllvmTMB_multi object|A \\code\\{gllvmTMB_multi\\} fit|posterior uncertainty|full posterior|Switch to bootstrap|Empirical coverage-rate study for a fitted gllvmTMB_multi|Parametric bootstrap for Sigma|Profile-likelihood target inventory for a \\code\\{gllvmTMB_multi\\} fit|Machine-readable convergence|One-call diagnostic' R/confint-inspect.R R/profile-targets.R R/bootstrap-sigma.R R/diagnose.R R/methods-gllvmTMB.R R/check-identifiability.R R/coverage-study.R R/check-consistency.R man/confint_inspect.Rd man/profile_targets.Rd man/bootstrap_Sigma.Rd man/check_gllvmTMB.Rd man/gllvmTMB_diagnose.Rd man/sanity_multi.Rd man/check_identifiability.Rd man/coverage_study.Rd man/gllvmTMB_check_consistency.Rd
  ```

  -> only the internal source header `R/methods-gllvmTMB.R:1` remains; no touched
  reference page exposes the old class-first or posterior wording.
- Register-row cross-check:

  ```sh
  rg -n 'Scope boundary|DIA-01|DIA-02|DIA-03|DIA-05|DIA-07|DIA-08|DIA-10|MIS-15|EXT-13|CI-02|CI-03|CI-08|CI-10' R/confint-inspect.R R/profile-targets.R R/bootstrap-sigma.R R/diagnose.R R/methods-gllvmTMB.R R/check-identifiability.R R/coverage-study.R R/check-consistency.R man/confint_inspect.Rd man/profile_targets.Rd man/bootstrap_Sigma.Rd man/check_gllvmTMB.Rd man/gllvmTMB_diagnose.Rd man/sanity_multi.Rd man/check_identifiability.Rd man/coverage_study.Rd man/gllvmTMB_check_consistency.Rd docs/design/35-validation-debt-register.md
  ```

  -> each edited page has a scope boundary, and the cited row IDs exist in the
  validation-debt register.
- Rose stale-terminology scan:

  ```sh
  rg -n '\\bS_B\\b|\\bS_W\\b|\\\\bf S|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|U_phy|U_non|meta_known_V|gllvmTMB_wide|full.*posterior|profile-likelihood default|trio' R/confint-inspect.R R/profile-targets.R R/bootstrap-sigma.R R/diagnose.R R/methods-gllvmTMB.R R/check-identifiability.R R/coverage-study.R R/check-consistency.R man/confint_inspect.Rd man/profile_targets.Rd man/bootstrap_Sigma.Rd man/check_gllvmTMB.Rd man/gllvmTMB_diagnose.Rd man/sanity_multi.Rd man/check_identifiability.Rd man/coverage_study.Rd man/gllvmTMB_check_consistency.Rd
  ```

  -> no hits.
- Rd spot-check:
  `tail -5 man/confint_inspect.Rd man/profile_targets.Rd man/bootstrap_Sigma.Rd man/check_gllvmTMB.Rd man/gllvmTMB_diagnose.Rd man/sanity_multi.Rd man/check_identifiability.Rd man/coverage_study.Rd man/gllvmTMB_check_consistency.Rd`
  -> normal endings.
- Rd keyword check:
  `grep -Hc '^\\keyword' man/confint_inspect.Rd man/profile_targets.Rd man/bootstrap_Sigma.Rd man/check_gllvmTMB.Rd man/gllvmTMB_diagnose.Rd man/sanity_multi.Rd man/check_identifiability.Rd man/coverage_study.Rd man/gllvmTMB_check_consistency.Rd`
  -> all 0 keyword entries.

## Definition-of-Done Notes

- Implementation: local branch only. Not merged, not pushed, and no 3-OS CI on
  this branch yet.
- Simulation recovery test: not applicable; this slice changes reference prose
  and one non-user-facing comment only.
- Documentation: roxygen and generated Rd were updated together.
- Runnable user-facing example: examples were not changed except
  `bootstrap_Sigma()` now demonstrates canonical `level = "unit"` rather than
  legacy `level = "B"`.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Pat/Fisher/Rose/Grace checks covered first-use guidance,
  uncertainty wording, validation row IDs, focused tests, pkgdown, stale scans,
  and Rd spot-checks.

## Residuals

- The underlying output list names for `bootstrap_Sigma()` still include
  `Sigma_B`, `Sigma_W`, `R_B`, and `R_W` for compatibility. This slice only
  changes the reference prose and example input level.
- Full package tests, full `devtools::check()`, and 3-OS CI were not run in
  this local reference slice.
