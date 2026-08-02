# After Task: Clarify spatial mesh geometry and current covariance syntax

**Branch**: `codex/spatial-doc-mesh-coord`  
**Date**: 2026-08-02  
**Roles (engaged)**: Ada, Pat, Rose, Grace

## 1. Goal

Correct the public spatial-model article so new users learn the current
one-shared-variance spelling and can distinguish their observed coordinate
columns from the SPDE mesh used to approximate the spatial field.

## 2. Implemented

`spatial_indep(..., common = TRUE)` now replaces `spatial_scalar()` in the
mode table, with the latter identified only as soft-deprecated compatibility
syntax. The article explains coordinates, mesh vertices, and the sparse
observation-to-mesh projection; it also standardises runnable examples on the
top-level `mesh = mesh` argument.

**Mathematical contract**: no public R API, likelihood, formula grammar,
family, NAMESPACE, generated Rd, or pkgdown navigation changed. The article
continues to describe the existing SPDE approximation and labels the broader
spatial-family evidence as partial (FG-13; SPA-02); mesh construction remains
covered (SPA-01).

## 3. Files Changed

- `vignettes/articles/spatial-models.Rmd` — public article source and examples.
- `docs/dev-log/check-log.md` — verification receipt.
- `docs/dev-log/after-task/2026-08-02-spatial-guide-mesh-coordinates.md` — this report.

Status-inventory cascade: `README.md`, `NEWS.md`, `ROADMAP.md`, design notes,
and generated Rd files were not changed because the package behaviour and API
did not change.

## 3a. Decisions and Rejected Alternatives

- **Decision**: document the current `spatial_indep(..., common = TRUE)` form
  and keep `spatial_scalar()` as a compatibility note. **Rationale**: this is
  the documented canonical new-code route. **Rejected**: teaching the
  deprecated alias as a fourth first-class mode. **Confidence**: high.
- **Decision**: use only top-level `mesh = mesh` in the article calls.
  **Rationale**: it makes the geometry supplied to the fit visible once and
  avoids two competing examples of the same interface. **Confidence**: high.

## 4. Checks Run

```sh
git diff --check
# PASS

Rscript --vanilla -e 'rmarkdown::render("vignettes/articles/spatial-models.Rmd", output_dir = tempfile("spatial-render-"), quiet = TRUE)'
# PASS

Rscript --vanilla -e 'pkgdown::check_pkgdown()'
# PASS: No problems found.

Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'
# PASS
```

No tests were added because this is an article-only correction. The successful
render evaluates the three runnable spatial fits and is the direct regression
check for the changed examples.

## 5. Tests of the Tests

No new automated test. The rendered article exercises the changed long, wide,
latent, and full-covariance calls; a bad formula or mesh hand-off would fail
the render.

## 6. Consistency Audit

```sh
rg -n 'all four spatial keywords|\\| `spatial_scalar\\(\\)` \\||spatial_scalar\\(.*Canonical name' vignettes/articles/spatial-models.Rmd
# no matches: obsolete article framing removed.

rg -n 'spatial_indep\\(.*common = TRUE|spatial_scalar\\(\\) is retained' vignettes/articles/spatial-models.Rmd
# two intentional matches: canonical new-code spelling and compatibility note.

rg -n 'gllvmTMB\\(' vignettes/articles/spatial-models.Rmd
# manually checked: every long-format call passes trait = "trait"; traits() wide call does not need it.

rg -n '\\bS_B\\b|\\bS_W\\b|\\\\bf S' vignettes/articles/spatial-models.Rmd
# no matches.

rg -n 'in prep|in preparation' vignettes/articles/spatial-models.Rmd
# no matches.

rg -n 'gllvmTMB_wide' vignettes/articles/spatial-models.Rmd
# no matches.
```

## 7. Roadmap Tick

N/A — documentation correction only; no roadmap status changed.

## 7a. GitHub Issue Ledger

Inspected open issue [#750](https://github.com/itchyshin/gllvmTMB/issues/750),
which concerns conditional redraws for a structured-covariance bootstrap and
is not affected by this article correction. No issue comment, closure, or new
issue.

## 8. What Did Not Go Smoothly

The starting checkout was behind `origin/main` and contained unrelated work,
so the change was made in a clean linked worktree. Pat also identified a
reader-facing ambiguity in the former duplicate `mesh` arguments; it was
corrected in the same narrow patch.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada**: kept the fix limited to the deployed article source and used a clean
branch from current `main`, rather than touching foreign work.

**Pat**: found that the original examples passed `mesh` both inside the keyword
and at top level, and that the article did not tell readers what supplies the
geometry. The revised text separates site labels, coordinates, and mesh.

**Rose**: confirmed the wider package has stale compatibility wording in some
reference/documentation surfaces. That is a separate consistency follow-up,
not silently bundled into this page correction.

**Grace**: `rmarkdown` rendering, `pkgdown::check_pkgdown()`, and the full
article build all passed.

## 10. Known Limitations And Next Actions

The article remains deliberately limited to isotropic Gaussian spatial fits;
anisotropy, barriers, spatiotemporal fields, and interval-calibration claims
are outside its evidence boundary. A separate future documentation sweep
should reconcile the remaining legacy scalar wording across reference and
design documentation before treating the migration as complete.
