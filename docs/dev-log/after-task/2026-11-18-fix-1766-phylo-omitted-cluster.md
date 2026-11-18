# After Task: omitted cluster adopts the phylo grouping column (refs #1766)

**Branch**: `cursor/fix-1766-phylo-omitted-cluster-2990`
**Date**: `2026-11-18`

## Goal

`phylo_latent(taxon, ...)` with `cluster` omitted built a placeholder `species` factor and checked the phylogenetic matrix against `"placeholder"`.

## Mathematical contract

No likelihood, grammar, or default change. When `cluster` is omitted and one phylo term names a column that is present and is not the default name `species`, that column is the cluster. The fitted model is the one an explicit `cluster` already fit.

## Files

- `R/brms-sugar.R` — `.gllvmTMB_phylo_bare_groups()`
- `R/gllvmTMB.R` — adopt that column; help text
- `man/gllvmTMB.Rd`
- `NEWS.md`
- `tests/testthat/test-fix-1766-phylo-omitted-cluster.R`
- `docs/dev-log/check-log.d/2026-11-18-fix-1766-phylo-omitted-cluster.md`
- `docs/dev-log/after-task/2026-11-18-fix-1766-phylo-omitted-cluster.md`

No README, design-doc, article, or validation-debt edit. `phylo_slope()` is not part of this rule.

## Checks

R is not installed here. CI runs the new test file.

## Tests of the tests

- `phylo_latent(taxon)` without `cluster` errors on main (placeholder versus the matrix) and fits after the fix.
- A missing `taxon` column expects `groups by taxon` and fails on main, where the message names `phylo_vcv` and `placeholder`.
- The `species` + bad-matrix test is a guard: it already passed on main and must keep the `phylo_vcv` wording.

## Consistency

Boole: the adopted column is the one already written in the keyword. Rose: the kernel block still runs first and is not overwritten. Pat: a missing `species` column keeps the old message.

## Roadmap

N/A.

## GitHub issue ledger

Inspected #1766. This PR uses `refs #1766` and does not close it.

## Limitations

Two phylo terms that name different columns, with `cluster` omitted, stop and ask for `cluster`. `phylo_slope()` is unchanged.
