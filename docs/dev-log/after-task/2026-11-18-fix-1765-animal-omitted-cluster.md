# After Task: omitted cluster adopts the animal grouping column (refs #1765)

**Branch**: `cursor/fix-1765-animal-omitted-cluster-2990`
**Date**: `2026-11-18`

## Goal

`animal_latent(individual, ...)` with `cluster` omitted built a placeholder `species` factor and checked the relatedness matrix against `"placeholder"`.

## Mathematical contract

No likelihood, grammar, or default change. When `cluster` is omitted and one animal term names a column that is present, that column is the cluster. The fitted model is the one an explicit `cluster` already fit.

## Files

- `R/animal-keyword.R` — `.gllvmTMB_animal_bare_groups()`
- `R/gllvmTMB.R` — adopt that column; help text
- `man/gllvmTMB.Rd`
- `NEWS.md`
- `tests/testthat/test-fix-1765-animal-omitted-cluster.R`
- `docs/dev-log/check-log.d/2026-11-18-fix-1765-animal-omitted-cluster.md`
- `docs/dev-log/after-task/2026-11-18-fix-1765-animal-omitted-cluster.md`

No README, design-doc, article, or validation-debt edit.

## Checks

R is not installed here. CI runs the new test file.

## Tests of the tests

- `animal_latent(individual)` without `cluster` errors on main (placeholder versus `A`) and fits after the fix.
- A missing `individual` column expects `groups by individual` and fails on main.
- `cluster = "trait"` is a guard that an explicit cluster is not rewritten. It errors on main and after the fix.

## Consistency

Boole: the adopted column is the one written in the keyword. Rose: a kernel term that already set `cluster` is not overwritten.

## Roadmap

N/A.

## GitHub issue ledger

Inspected #1765. This PR uses `refs #1765` and does not close it.

## Limitations

Two animal terms that name different columns, with `cluster` omitted, stop and ask for `cluster`.
