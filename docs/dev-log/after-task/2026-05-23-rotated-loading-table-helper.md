# After Task: Rotated Loading Table Helper

**Branch**: `codex/rotated-loadings-table-2026-05-23`
**Date**: `2026-05-23`
**Roles (engaged)**: `Ada / Emmy / Florence / Pat / Rose / Grace`

## 1. Goal

Add a report-ready rotated loading table helper so ordination figures,
Morphometrics examples, and future Florence-grade plots can use the same
rotation, ordering, sign-anchoring, and loading-scale conventions without
hand-indexing loading matrices.

## 2. Implemented

- Added exported `extract_rotated_loadings_table()` in `R/rotate-loadings.R`.
  It returns one row per trait and latent axis with `level`, `trait`, `axis`,
  `loading`, `abs_loading`, `axis_variance`, `axis_share`, `rotation`,
  `order_axes`, `sign_anchor`, `anchor_trait`, and `loading_scale`.
- Set rotated `Lambda` and score column names after matrix multiplication so
  rotated outputs keep stable `LV1`, `LV2`, ... labels.
- Added shared internal `.standardize_loadings_by_total_variance()` and reused
  it in `plot(type = "ordination")`, keeping table output and ordination-arrow
  scaling aligned.
- Added Morphometrics article usage showing a standardized tidy loading table
  beside the rotated ordination.
- Added `EXT-28` to the validation-debt register and the extractor contract.
- Added the new export to `_pkgdown.yml`, `NAMESPACE`, `NEWS.md`, and generated
  `man/extract_rotated_loadings_table.Rd`.

## 3. Files Changed

- API and internals: `R/rotate-loadings.R`, `R/plot-gllvmTMB.R`.
- Tests: `tests/testthat/test-rotate-compare-loadings.R`.
- Documentation and navigation: `man/extract_rotated_loadings_table.Rd`,
  `NAMESPACE`, `_pkgdown.yml`, `NEWS.md`.
- User article: `vignettes/articles/morphometrics.Rmd`.
- Design and validation ledger: `docs/design/06-extractors-contract.md`,
  `docs/design/35-validation-debt-register.md`.
- Process ledger: `docs/dev-log/check-log.md`,
  `docs/dev-log/after-task/2026-05-23-rotated-loading-table-helper.md`.

## 3a. Decisions and Rejected Alternatives

- Decision: `axis_variance` and `axis_share` remain raw rotated-loading
  quantities even when `loading_scale = "standardized"`.
  Rationale: these values define the axis-ordering convention and should not
  silently change when the displayed loading scale changes.
  Rejected alternative: recompute axis shares from standardized loadings, which
  would make table ordering metadata disagree with `rotate_loadings()` and the
  ordination plot metadata.
- Decision: this is a table helper, not an uncertainty helper.
  Rationale: loading intervals need a deliberate bootstrap or simulation slice;
  the current claim is point-estimate reporting only.

## 4. Checks Run

See `docs/dev-log/check-log.md` entry
`2026-05-23 -- Rotated loading table helper` for the full command ledger.
Key outcomes:

- `devtools::document(quiet = TRUE)` regenerated `NAMESPACE` and the new Rd.
- `devtools::test(filter = "rotate-compare-loadings", stop_on_failure = TRUE)`
  -> 69 passes.
- `devtools::test(filter = "plot-gllvmTMB", stop_on_failure = TRUE)`
  -> 236 passes.
- Combined focused tests -> 305 passes.
- Current-branch Morphometrics render -> wrote `articles/morphometrics.html`
  after installing the current branch locally.
- `pkgdown::check_pkgdown()` -> `No problems found.`
- `git diff --check` -> clean.
- `devtools::check(args = "--no-manual", quiet = TRUE)` -> 0 errors, 1 known
  local install warning, 3 known notes (`air.toml`, legacy NEWS headings,
  unused `nlme`).
- Post-merge #237 main CI -> success on Ubuntu, macOS, and Windows.

## 5. Tests of the Tests

- Feature-combination: tests compare the tidy table to `rotate_loadings()`,
  the ordination scaling convention, and the existing `extract_Sigma()` total
  variance path.
- Mathematical invariant: tests rebuild `Lambda` from tidy rows and assert
  varimax covariance invariance under rotation and sign flips.
- Boundary/convention: tests cover `method = "none"` metadata and explicit
  anchor-trait sign reproducibility.
- Failure-before-fix: the first focused run caught missing axis names after
  matrix multiplication; the implementation now restores stable `LV*` column
  labels.

## 6. Consistency Audit

Verbatim scans recorded in `docs/dev-log/check-log.md`.

- Scope-boundary wording scan: no comma-form `PARTIAL,` / `PLANNED,` or
  British spelling drift in the new helper docs.
- Legacy notation scan: no `diag(U)`, `U_phy`, `U_non`, `\bf S`, `S_B`, or
  `S_W` in the touched helper/article/docs.
- Rose stale API scan: only pre-existing historical/register compatibility
  mentions for `meta_known_V` and `gllvmTMB_wide`; no new helper/article
  overclaim.
- Export/reference parity: passed after adding `extract_rotated_loadings_table`
  to `_pkgdown.yml`.

## 7. Roadmap Tick

N/A. This is a narrow helper slice under the ongoing figure/reporting surface,
not a roadmap milestone transition.

## 7a. GitHub Issue Ledger

No relevant open issue was inspected or updated. This continued the maintainer's
local slice plan for rotated ordination/reporting infrastructure rather than a
GitHub issue lane.

## 8. What Did Not Go Smoothly

- The first Morphometrics article render failed before the new chunk because
  `library(gllvmTMB)` attached a stale installed package where
  `plot_correlations(style = "eye")` was not available. Installing the current
  branch locally fixed the render.
- The first `pkgdown::check_pkgdown()` failed because the new export was not in
  `_pkgdown.yml`; the reference index now includes it.
- Local `devtools::check()` still hits the known warning/notes bucket. This
  branch did not introduce those diagnostics, but they remain unresolved.

## 9. Team Learning

- Ada: kept the helper small and tied to the existing rotation path rather than
  inventing a parallel table-specific rotation implementation.
- Emmy: the return contract is explicit, exported, documented, and listed in
  `docs/design/06-extractors-contract.md`.
- Florence: the table now gives future plots a clean, auditable data source for
  rotated/anchored loadings and display-scale choices.
- Pat: Morphometrics shows the table where users are already learning rotated
  axes, without expanding the article into a new tutorial.
- Rose: `_pkgdown.yml`, NEWS scope boundaries, generated Rd, and validation row
  `EXT-28` now agree.
- Grace: focused tests, article render, `pkgdown::check_pkgdown()`, and local
  `R CMD check` were run; branch CI still needs to run after push.

## 10. Known Limitations And Next Actions

- `extract_rotated_loadings_table()` is point-estimate only; loading
  uncertainty remains planned.
- Promax remains a descriptive oblique rotation; existing tests cover linear
  predictor invariance, while covariance invariance is asserted for varimax.
- Next safest action: commit this branch, push after local review, open a PR,
  and monitor 3-OS CI.
