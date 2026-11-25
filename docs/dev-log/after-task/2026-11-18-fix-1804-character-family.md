# After Task: resolve character families before the temporal gate (refs #1804)

**Branch**: `cursor/fix-1804-character-family-2990`
**Date**: `2026-11-18`

## Goal

`family = "gaussian"` with `temporal_latent()` stopped with `$ operator is invalid for atomic vectors`. The same character name already fit on ordinary models.

## Mathematical contract

No likelihood, grammar, estimand, or default change. `family = "gaussian"` becomes `gaussian()` before any `$family` gate, using the lookup `family_to_id()` already used.

## Files

- `R/gllvmTMB.R` — `.gllvmTMB_family_from_character()` and the entry resolver
- `R/fit-multi.R` — `family_to_id()` calls that helper
- `NEWS.md`
- `tests/testthat/test-fix-1804-character-family.R`
- `docs/dev-log/check-log.d/2026-11-18-fix-1804-character-family.md`
- `docs/dev-log/after-task/2026-11-18-fix-1804-character-family.md`

No README, roxygen, Rd, design-doc, or validation-debt edit. The accepted character names did not change.

## Checks

R is not installed here. CI runs the new test file.

## Tests of the tests

- The temporal fit with `family = "gaussian"` errors on main with `$ operator is invalid for atomic vectors` before any parameter comparison.
- The unknown-name test expects "Unsupported family" and fails on main for the same `$` error.

## Consistency

Rose: the abort text moved with the lookup and was not rewritten. Gauss: no density or link change. Boole: `family = gaussian()` and `family = gaussian` stay on their existing paths.

## Roadmap

N/A.

## GitHub issue ledger

Inspected #1804. This PR uses `refs #1804` and does not close it.

## Limitations

A character vector longer than one name is still refused later, as before.
