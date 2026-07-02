# After Task: Source-Specific LV Alias Guard

## Goal

Remove remaining source-specific `lv = ~ env` silent-drop paths across the
structural keyword aliases without widening source-specific LV grammar.

## Files Changed

- `R/brms-sugar.R`
- `tests/testthat/test-canonical-keywords.R`
- `docs/design/01-formula-grammar.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-01-source-specific-lv-alias-guard.md`

## Implemented

The existing fail-loud source-specific `lv` guard now covers phylo, spatial,
animal, and kernel structural keywords across scalar, unique, indep, dep,
latent, and legacy-alias spellings. This closes the previously observed silent
drop path for examples such as `phylo_indep(..., lv = ~ env)`,
`spatial_dep(..., lv = ~ env)`, `animal_dep(..., lv = ~ env)`, and
`kernel_dep(..., lv = ~ env)`.

## Validation

```sh
Rscript -e 'parse("R/brms-sugar.R"); cat("parse-ok\n")'
Rscript -e 'pkgload::load_all(quiet=TRUE); <all source-specific structural lv probe>'
Rscript -e 'pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-canonical-keywords.R")'
```

Focused evidence:

- All source-specific structural `lv = ~ env` probe cases failed loudly.
- `test-canonical-keywords.R`: 82 pass, 3 INLA skips.

## Claim Boundary

This is guard coverage only. Ordinary `latent(lv = ~ x)` remains the admitted
grammar; source-specific `phylo_*()`, `spatial_*()`, `animal_*()`, and
`kernel_*()` `lv` support remains blocked unless a future derivation, ADEMP
gate, and maintainer sign-off explicitly open it. Structural random-slope
syntax remains a separate route from predictor-informed `lv` grammar.

## Rose Verdict

PASS WITH NOTES. The silent-drop risk is closed for the audited structural
aliases. No source-specific support, PR reopen, package API widening, mixed
family interval claim, or compute launch follows from this guard hardening.
