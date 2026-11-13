# After Task: one-grouping kernel call when cluster is omitted (#1752)

**Branch**: `cursor/fix-1752-kernel-indep-unit-cd08`
**Date**: `2026-11-10`
**Roles (engaged)**: Ada, Boole, Curie, Pat, Rose

## 1. Goal

Make the documented unreplicated call `kernel_indep(unit, K = K, name = "known")`, and the matching `kernel_latent()` form, fit when `cluster` is omitted. The fit uses the grouping column named in the kernel term. A `K` that still does not match that column names `K` and the column. Phylogenetic checks, and the replicated `?kernel_latent` example that passes `cluster = "site"`, stay as they were.

## Mathematical contract

No likelihood, formula-grammar, or family change. `src/gllvmTMB.cpp` is untouched. When `cluster` is omitted and every bare `kernel_*()` term names the same column, that column is the cluster slot, so the model is the one already fitted by passing `cluster` equal to that column. On the seed-11 layout in the new test, the two `logLik` values agree to `1e-8`.

## 2. Implemented

`gllvmTMB()` reads bare `kernel_indep()`, `kernel_dep()`, `kernel_latent()`, `kernel_unique()`, and `kernel_scalar()` terms before it synthesises a placeholder `species` column. One shared grouping column that exists in `data` becomes `cluster`. An explicit `cluster`, including the deprecated `species` alias, is left alone. A bar form (`1 + x | g`) is not used to choose `cluster`. Two different bare groupings abort and name those columns and `cluster` (`gllvmTMB_kernel_grouping`).

On the single-kernel dense path, a missing or misaligned `K` names `K` and the grouping column (`gllvmTMB_kernel_K_levels`). The phylogenetic abort text is unchanged: the extra arguments on `.gllvm_abort_uncovered_species_levels()` default to the previous species / tree wording.

## 3. Files Changed

- `R/gllvmTMB.R` — adopt the kernel grouping when `cluster` is omitted.
- `R/kernel-keywords.R` — bare-group walker, kernel function name from mode, and the `unit` help sentence.
- `R/fit-multi.R` — kernel wording on the single-kernel dense path.
- `man/gllvmTMB.Rd`, `man/kernel_latent.Rd`, `man/kernel_scalar.Rd`, `man/kernel_unique.Rd` — the same sentences. `kernel_indep` and `kernel_dep` share `kernel_latent.Rd`.
- `NEWS.md` — one development bullet.
- `tests/testthat/test-fix-1752-kernel-indep-unit.R` — new.
- `docs/dev-log/check-log.d/2026-11-10-fix-1752-kernel-indep-unit.md` — check evidence.
- This report.

Not changed: `src/`, vignettes (the keyword-grid article already shows the call), the replicated `kernel_latent` example, `DESCRIPTION`, `NAMESPACE`, `ROADMAP.md`, and the validation-debt register.

## 3a. Decisions and Rejected Alternatives

Decision: use the kernel's own bare grouping when `cluster` is not given. That is the behaviour requested for issue #1752, matching `vignettes/articles/api-keyword-grid.Rmd`.

Rejected here: requiring `cluster = unit` in the article, and inventing a multi-group kernel API. Distinct bare groupings still abort.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-10-fix-1752-kernel-indep-unit.md` for the commands and counts.

Stale-wording scans:

```sh
rg -n "FAM-|FG-|MIX-" NEWS.md
rg -n "nocov" tests/testthat/test-fix-1752-kernel-indep-unit.R R/gllvmTMB.R R/fit-multi.R R/kernel-keywords.R
```

`NEWS.md` has no register codes. The new test and the edited R files have no `nocov`.

`roxygen2::roxygenise()` rewrote only the four Rd files above, plus a roxygen2 8.1.1 formatting change in `DESCRIPTION` and `NAMESPACE`. Those two files were restored.

## 5. Tests of the Tests

The new file fails on the installed unfixed package: both one-grouping fits error with the `phylo_vcv` / `placeholder` message, and the bad-`K` assertions fail because that message names `phylo_vcv` and `tree`. The phylogenetic pin in the same file passes before and after, so the wording change is confined to the kernel path. After the fix the file passes 24 assertions, including `logLik` equality with `cluster = "unit"`.

## 6. Consistency Audit

The keyword-grid article already writes `kernel_indep(unit_id, K = K, name = "known")` without `cluster`. The replicated example in `R/kernel-keywords.R` still passes `unit = "obs"` and `cluster = "site"`. Help for `cluster` and for `unit` now says which of those two paths is which.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed.

## 7a. GitHub Issue Ledger

Inspected #1752 (open). This PR fixes it. Not closed from this branch. Open PRs at the lane check (#1761, #1760, #1756, #1754, #1749, #1747, #1745, #1700, #1506, #1283, #1065, #981) do not edit these files. `codex/*` branches were not touched.

## 8. What Did Not Go Smoothly

`graft` is not installed in this environment, so the call sites were found with search rather than the graph. `roxygen2` 8.1.1 rewrote `NAMESPACE` import layout and bumped `Config/roxygen2/version`; that churn was reverted. Neighbour tests that use `traits()` or `ape` needed `tidyr` and `ape` installed locally before they could run.

## 9. Team Learning

Boole: the kernel keyword names the grouping, but the dense engine indexes `K` by the cluster slot. Omitting `cluster` has to fill that slot before the placeholder is built, or the documented call cannot fit.

Curie: the new file fails on the unfixed install and passes after, and the phylogenetic pin in the same file guards the unchanged wording. Neighbour kernel, temporal, unused-slot, and species-level tests were not loosened.

Pat: a mismatched `K` now names `K` and the grouping column, and tells the reader the mismatch is not fixed by `droplevels()`. The replicated example still shows an explicit `cluster`.

Rose: reader-facing text has no register codes. The NEWS bullet states the omitted-`cluster` rule, the explicit-`cluster` exception, the two-grouping refusal, and that phylogenetic checks are unchanged.

## 10. Known Limitations And Next Actions

Different kernel groupings in one fit stay refused. A kernel slope written only as `1 + x | g` does not choose `cluster`. CI on this pull request has not run yet.
