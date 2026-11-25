# After Task: kernel grouping follows a named unit argument (refs #1805)

**Branch**: `cursor/fix-1805-kernel-named-unit-2990`
**Date**: `2026-11-18`

## Goal

`kernel_indep(K = K, unit = g)` with `cluster` omitted treated `K` as the grouping column because `.gllvmTMB_kernel_bare_groups()` read the first argument by position.

## Mathematical contract

No public API, likelihood, grammar, family, estimand, or default change. The same kernel model is fit; only the column the omitted `cluster` is taken from is corrected when `unit` is named.

## Files

- `R/kernel-keywords.R` — match `unit` by name, then fall back to position
- `R/gllvmTMB.R` — cluster-argument help text
- `man/gllvmTMB.Rd` — same sentence
- `NEWS.md`
- `tests/testthat/test-fix-1805-kernel-named-unit.R`
- `docs/dev-log/check-log.d/2026-11-18-fix-1805-kernel-named-unit.md`
- `docs/dev-log/after-task/2026-11-18-fix-1805-kernel-named-unit.md`

No README, design-doc, article, or validation-debt edit.

## Checks

R is not installed here. The new test file was not run. CI is the check. See the check-log file.

## Tests of the tests

- The fit comparison errors on main before the fix (the call aborts while resolving `K` as the grouping).
- The missing-column test expects `groups by g` and fails on main, where the message names `K`.

## Consistency

Rose: the new help sentence matches the helper. The positional kernel call and an explicit `cluster` stay as they were. Boole: named `unit` is the same column the keyword already documents as its first argument.

## Roadmap

N/A.

## GitHub issue ledger

Inspected #1805. This PR uses `refs #1805` and does not close it.

## Limitations

Bar-form kernel slopes (`1 + x | g`) are still not collected as a bare grouping. That is the existing rule.
