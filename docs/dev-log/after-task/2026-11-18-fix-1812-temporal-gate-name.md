# After Task: name the temporal keyword in the post-parse gates (refs #1812)

**Branch**: `cursor/fix-1812-temporal-gate-name-2990`
**Date**: `2026-11-18`

## Goal

Parser refusals already use `marker_name`. The three gates in `gllvmTMB()` that run after that parse still said `temporal_latent()` for `temporal_indep()` and `temporal_dep()`.

## Mathematical contract

No likelihood, grammar, admission rule, or default change. The spec records the marker name that was already parsed, and the three abort strings interpolate it. `temporal_latent()` still renders that name.

## Files

- `R/temporal.R` — `spec$marker`
- `R/gllvmTMB.R` — three gate messages
- `NEWS.md`
- `tests/testthat/test-fix-1812-temporal-gate-name.R`
- `docs/dev-log/check-log.d/2026-11-18-fix-1812-temporal-gate-name.md`
- `docs/dev-log/after-task/2026-11-18-fix-1812-temporal-gate-name.md`

No README, roxygen, Rd, design-doc, or validation-debt edit.

## Checks

R is not installed here. CI runs the new test file.

## Tests of the tests

On main, each of these errors names `temporal_latent()`:

- `temporal_indep()` / `temporal_dep()` with `family = poisson()`
- `temporal_indep()` with `aghq = 5`
- `temporal_dep()` with a non-null `phylo_tree`

The latent poisson message is pinned to the previous sentence.

## Consistency

Boole: only the function name in the message changes. Pat: the next-step sentence is unchanged. Rose: `.temporal_assert_no_iid_inference()` still says `temporal_latent()`; that abort is outside this issue's `gllvmTMB()` gates.

## Roadmap

N/A.

## GitHub issue ledger

Inspected #1812. Parser half was already merged in #1811 and left this issue open. This PR uses `refs #1812` and does not close it.

## Limitations

The iid-method abort in `R/temporal.R` still says `temporal_latent()`.
