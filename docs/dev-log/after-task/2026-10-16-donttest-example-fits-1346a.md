# Wrap gllvmTMB() help-example fits in `\donttest{}` (#1346, part A follow-up)

**Branch**: `claude/b16-L6-runnable-examples-1346a` (PR #1561)
**Date**: `2026-10-16`
**Roles (engaged)**: Rose (R-review item), Grace (document + CI)

## 1. Goal

The R review on #1561 asked to wrap the `gllvmTMB()` fits on the 24 brms-sugar
help pages in `\donttest{}` and keep only the data set-up bare, so default
`R CMD check` / CRAN does not fit several 60-species models on each page.

## 2. Implemented

Each of the 24 `@examples` blocks in `R/brms-sugar.R` now puts the
`gllvmTMB()` call(s) and any follow-up that needs a fit (`extract_Sigma()`,
`logLik()`) inside `\donttest{}`. Simulate / tree / mesh / `V` construction
stays outside. Commented-out error demos stay outside. `spatial_slope` was
not in this slice and is unchanged.

`devtools::document(roclets = "rd")` regenerated the 24 matching `man/*.Rd`
files. `NAMESPACE` was not rewritten (#1558).

The forcing test still passes: it already treats `\donttest` as runnable
(`commentDonttest = FALSE`; static scan counts `\donttest` as code).

## 3. Files Changed

- `R/brms-sugar.R` (24 `@examples` blocks)
- `man/{dep,gr,indep,kernel_slope,latent,meta,meta_V,meta_known_V,phylo,phylo_dep,phylo_indep,phylo_latent,phylo_rr,phylo_scalar,phylo_slope,phylo_unique,scalar,slope,spatial,spatial_dep,spatial_indep,spatial_latent,spatial_scalar,spatial_unique}.Rd`
- `docs/dev-log/after-task/2026-10-16-runnable-examples-1346a.md` (R-review outcome)
- `docs/dev-log/after-task/2026-10-16-donttest-example-fits-1346a.md` (this file)
- `docs/dev-log/check-log.md`

## 3a. Decisions and Rejected Alternatives

- **Decision:** wrap fits only, not the whole `\examples` block. Rationale: the
  R review asked for data set-up to stay bare, and a whole-block wrap would
  make default `R CMD check` skip even `simulate_*` / `make_mesh`.
- **Rejected:** leave fits bare because timings are under 5 s. That was the
  previous answer on the PR; this slice follows the R review instead.
- **Confidence:** high. `document()` and the existing forcing test both agree.

## 4. Checks Run

- `devtools::document(roclets = "rd")` with roxygen2 8.0.0: wrote exactly the
  24 Rd files; `NAMESPACE` unchanged versus the pre-document snapshot.
- `devtools::test(filter = "examples-run-1346a")`: 48 blocks, failed=0,
  skipped=0, error=0, warning=0.
- `rg -n '\\\\donttest\\{' R/brms-sugar.R`: 24 hits, one per page in this
  slice. `spatial_slope` has none.
- `rg -n '\\\\dontrun' R/brms-sugar.R man/{dep,gr,indep,kernel_slope,latent,meta,meta_V,meta_known_V,phylo,phylo_dep,phylo_indep,phylo_latent,phylo_rr,phylo_scalar,phylo_slope,phylo_unique,scalar,slope,spatial,spatial_dep,spatial_indep,spatial_latent,spatial_scalar,spatial_unique}.Rd`:
  0 hits (no `\dontrun` reintroduced).

Not run: full `devtools::test()`, `R CMD check`, pkgdown. Reason: examples-only
wrap; the forcing test already evaluates the `\donttest` bodies.

## 5. Tests of the Tests

No new test. The existing `test-examples-run-1346a.R` is the coverage: a
whole-block `\dontrun` still fails the static check; a `\donttest` wrap still
runs under `commentDonttest = FALSE`.

## 6. Consistency Audit

- `\\\\donttest\\{` in `R/brms-sugar.R`: 24, matches the page list. Verdict: pass.
- `\\\\dontrun` on those 24 Rd files: 0. Verdict: pass.
- Rd diffs lie only inside `\examples` (`git diff --stat man/` is +2 lines per
  page except `phylo.Rd` +4 for moving `Cphy` into set-up). Verdict: pass.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed.

## 7a. GitHub Issue Ledger

- Inspected: #1346 (this slice), #1561 (R review), #1551 (red proof), #1558
  (`document()` / `NAMESPACE`).
- No new issue. The wrap is the requested docs change, not a new defect.

## 8. What Did Not Go Smoothly

R was not on `PATH` at session start. `apt-get install r-base-core` plus a
user-library pin of roxygen2 8.0.0 made `document()` possible. Compiling
`src/` for `load_all()` produced the usual Eigen attribute warnings; they
are unrelated.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Rose:** the R review's CRAN-time request overrides the earlier "under 5 s,
  leave bare" answer on this branch.
- **Grace:** `document(roclets = "rd")` avoids the #1558 `NAMESPACE` revert.

## 10. Known Limitations And Next Actions

- Default `R CMD check` now skips the fits; `R CMD check --run-donttest` and
  `devtools::test(filter = "examples-run-1346a")` still run them.
- Red proof #1551 is unchanged (test-only on base). CI on #1561 must re-run
  after this push because examples in the installed Rd changed.
- Env-var gating of the dynamic test remains deferred.
