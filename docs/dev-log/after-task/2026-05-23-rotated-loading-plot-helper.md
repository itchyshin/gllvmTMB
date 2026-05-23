# After Task: Rotated Loading Plot Helper

**Branch**: `codex/rotated-loading-plot-2026-05-23`
**Date**: `2026-05-23`
**Roles (engaged)**: `Ada / Florence / Emmy / Pat / Grace / Rose`
**Spawned subagents**: none

## 1. Goal

Add the first report-ready visual layer over the rotated loading table helper:
a loading-matrix plot that ordinary users can call without hand-pivoting
`Lambda`, while keeping the rotation/sign/scale caveat visible.

The visual target came from the maintainer-supplied GLLVM overview material:
the local `GLLVM_overview` folder's four-panel figure code includes ordination,
loading matrix, correlation matrix, and communality/uniqueness panels. This
slice packages the loading-matrix panel only; correlation variants and
communality/uniqueness polish stay as later slices.

## 2. Implemented

- Added exported `plot_rotated_loadings()` in
  `R/plot-rotated-loadings.R`.
- The helper accepts either:
  - a fitted `gllvmTMB` multivariate model, in which case it calls
    `extract_rotated_loadings_table()`; or
  - a data frame already returned by `extract_rotated_loadings_table()`.
- The plot defaults to standardized loadings for figure use, while still
  allowing raw loadings.
- The display includes a diverging loading scale, optional numeric tile labels,
  axis-share labels for single-level tables, trait sorting by dominant loading,
  and a caption that states the rotation convention and point-estimate-only
  status.
- The returned object carries `gllvmTMB_meta` and `gllvmTMB_data`, matching the
  existing plot-helper contract.
- Added `EXT-29` to the validation-debt register and updated the visualization
  grammar so the loading-matrix target is no longer listed as only planned.
- Added the export to `_pkgdown.yml`, `NAMESPACE`, `NEWS.md`, and generated
  `man/plot_rotated_loadings.Rd`.

## 3. Files Changed

- API and plot helper: `R/plot-rotated-loadings.R`.
- Tests: `tests/testthat/test-rotate-compare-loadings.R`.
- Documentation and navigation: `man/plot_rotated_loadings.Rd`,
  `NAMESPACE`, `_pkgdown.yml`, `NEWS.md`.
- Design and validation ledger: `docs/design/35-validation-debt-register.md`,
  `docs/design/46-visualization-grammar.md`.
- Process ledger: `docs/dev-log/check-log.md`,
  `docs/dev-log/after-task/2026-05-23-rotated-loading-plot-helper.md`.

## 3a. Decisions and Rejected Alternatives

- Decision: keep this helper as a loading-matrix heatmap, not a multi-panel
  Figure 4 assembler.
  Rationale: the overview figure has four distinct scientific tasks. Package
  helpers should expose clean panels that articles can compose, not hide a
  large layout inside one function.
- Decision: default `loading_scale = "standardized"` for fitted-model plot
  calls.
  Rationale: figures often compare traits on different scales; raw loadings
  remain available when the fitted scale is the intended message.
- Decision: no loading uncertainty is displayed.
  Rationale: loading intervals require a separate bootstrap or simulation
  convention that respects rotation, ordering, and sign anchoring.

## 4. Checks Run

See `docs/dev-log/check-log.md` entry
`2026-05-23 -- Rotated loading plot helper` for the full command ledger.
Key outcomes:

- `devtools::document(quiet = TRUE)` regenerated `NAMESPACE` and the new Rd.
- `devtools::test(filter = "rotate-compare-loadings", stop_on_failure = TRUE)`
  -> 84 passes, 0 failures, 0 warnings, 0 skips.
- Synthetic visual QA render:
  `/tmp/gllvmtmb-rotated-loadings/rotated-loading-matrix.png`.
- Florence visual inspection -> pass for clean row spacing, readable numeric
  labels, axis-share x labels, and honest rotation caption.
- `pkgdown::check_pkgdown()` -> `No problems found.`
- Export/reference parity -> `export/pkgdown parity ok`.
- `git diff --check` -> clean.
- Stale wording scan -> no hits for the scanned stale terms.
- `devtools::check(args = "--no-manual", quiet = TRUE)` -> 0 errors, 1 known
  local install warning, 3 known notes (`air.toml`, legacy NEWS headings,
  unused `nlme`).

## 5. Tests of the Tests

- Data-frame path: tests assert a `ggplot` return object, plot metadata, data
  attribute, axis-share labels, and rotation status.
- Fitted-model path: tests fit a small reduced-rank model and confirm the plot
  consumes `extract_rotated_loadings_table()` rows with the requested loading
  scale.
- Failure path: tests cover missing columns, invalid `show_values`, and invalid
  colour-scale limits.

## 6. Consistency Audit

- `_pkgdown.yml`, `NAMESPACE`, NEWS, generated Rd, validation row `EXT-29`, and
  visualization grammar now all mention the exported helper.
- The helper repeats the rotation-honesty principle: rotated axes are for
  readable interpretation, while `Sigma`, correlations, communality, and
  uniqueness remain the rotation-invariant summaries.
- The GLLVM overview code was used as visual reference only; no upstream code
  was ported into the package.

## 7. Roadmap Tick

No roadmap phase was moved. This is a narrow visualization-capability slice
under the ongoing Florence plot surface.

## 7a. GitHub Issue Ledger

No relevant open issue was inspected or updated. This continued the
maintainer's local visualization slice plan rather than a GitHub issue lane.

## 8. What Did Not Go Smoothly

- The broad local `devtools::check()` still exits non-zero because warnings are
  treated as failure. The diagnostics match the known local warning/notes
  bucket and are not introduced by this branch.
- The #238 post-merge `main` CI run was still in progress while this local
  slice was prepared. It later passed on Ubuntu, macOS, and Windows; Windows
  took 34m5s.

## 9. Team Learning

- Ada: kept the work as one panel helper after merging #238, instead of
  widening into a full gallery/article rewrite.
- Florence: the helper now has a package-level version of the overview
  loading-matrix panel with better metadata and scope captioning.
- Emmy: the plot consumes the row-first extractor contract rather than
  re-indexing matrices internally.
- Pat: users can now get a readable loading panel from a fit in one call.
- Rose: scope boundaries, validation row, reference index, and generated help
  agree.
- Grace: focused tests, pkgdown check, export parity, whitespace check, visual
  QA, and local `R CMD check` were run; branch CI remains pending until push.

## 10. Known Limitations And Next Actions

- `plot_rotated_loadings()` is point-estimate only.
- No article was changed in this slice.
- Next safest action: push this branch, open a narrow PR, and monitor branch
  CI.
- Next visualization slice: matrix-style correlation plot options, using the
  overview correlation panel as a reference point and adding lower/upper/full
  triangle plus number-display controls.
