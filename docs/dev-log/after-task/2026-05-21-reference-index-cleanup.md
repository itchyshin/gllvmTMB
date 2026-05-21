# After Task: Reference Index Cleanup And Roadmap Horizon

**Branch**: `codex/reference-cleanup-2026-05-21`
**Date**: `2026-05-21`
**Roles (engaged)**: `Ada / Pat / Rose / Grace`
**Issue ledger**: `#230`

## 1. Goal

Clean the pkgdown Reference index after the public-site reset so new users see
the actual first-line API before deprecated aliases, migration wrappers, or
advanced validation tools. Also answer the maintainer's roadmap concern by
keeping the live roadmap short but adding a compact end-to-end horizon.

## 2. Implemented

- Reorganised `_pkgdown.yml` Reference sections into a reader-first order:
  start here, core covariance keywords, advanced formula keywords, helpers,
  families, report-ready extractors, fitted-model methods, first-line
  diagnostics, advanced validation utilities, and loading/constraint helpers.
- Removed the visible `Deprecated keyword aliases` section.
- Marked `phylo_rr()`, `gr()`, `meta()`, `meta_known_V()`, and `spde()` as
  `@keywords internal` while keeping them exported for compatibility.
- Removed internal/back-compat topics from the Reference index:
  `extract_residual_split()`, `extract_ICC_site()`, and `tmbprofile_wrapper()`.
- Moved `block_V()` beside `meta_V()` as a real known-V helper rather than a
  deprecated alias.
- Added `ROADMAP.md` slices for Reference cleanup, symbol-to-syntax alignment,
  and Florence-grade plot polish.
- Added a `Long Horizon To Finish` section to explain how the deliberately
  short dashboard expands toward infrastructure, plots, diagnostics,
  restoration, pre-CRAN, and publication-quality validation.

## 3. Files Changed

Reference navigation:

- `_pkgdown.yml`

Roxygen and generated Rd:

- `R/brms-sugar.R`
- `R/spde-keyword.R`
- `man/phylo_rr.Rd`
- `man/gr.Rd`
- `man/meta.Rd`
- `man/meta_known_V.Rd`
- `man/spde.Rd`

Roadmap and logs:

- `ROADMAP.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-reference-index-cleanup.md`

## 3a. Decisions and Rejected Alternatives

Decision: hide deprecated aliases from the Reference index without removing the
exports.

Rationale: users should not start with `meta_known_V()`, `phylo_rr()`, `gr()`,
or `spde()`, but old code should still load.

Rejected alternative: delete or deprecate harder in this slice. That would turn
a navigation cleanup into an API-change PR.

Decision: keep `phylo()` and `spatial()` visible, but move them under
advanced shorthands.

Rationale: they are mode-dispatch wrappers, not the first-line 4 x 5 grid. They
remain useful for users with brms/drmTMB muscle memory.

Decision: make the roadmap longer only as a compact horizon.

Rationale: the reset deliberately avoided restoring the old sprawling roadmap,
but the live dashboard needs to show the route to the finish line.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeable --jq '.[] | [.number, .headRefName, .isDraft, .mergeable, .title] | @tsv'`
  - No open PRs returned.
- `git log --all --oneline --since='6 hours ago'`
  - Recent history: `36631ec`, `825cb9a`, `de27ecb`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  - Completed; regenerated the five Rd files listed above.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - `No problems found.`
- `Rscript --vanilla -e 'pkgdown::build_reference()'`
  - Rebuilt `pkgdown-site/reference/index.html`.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/roadmap")'`
  - Rebuilt `pkgdown-site/articles/roadmap.html`.
- `git diff --check`
  - Clean.

## 5. Tests of the Tests

No test files changed. This was a pkgdown navigation, roxygen keyword, generated
Rd, and roadmap-prose slice. The relevant regression check is the
export/reference/internal parity script plus browser-visible Reference review.

## 6. Consistency Audit

- `rg -n "Start here|Core covariance|Advanced formula|Relatedness|Deprecated keyword|meta_known_V|phylo_rr|<code><a href=\"gr.html\"|spde\\(\\)|extract_residual_split|extract_ICC_site|tmbprofile_wrapper" pkgdown-site/reference/index.html || true`
  - New sections are present; deprecated alias/internal entries are absent from
    the rendered index.
- `rg -n "First-line diagnostics|Advanced validation|Report-ready extractors|Methods and plots|Loadings" pkgdown-site/reference/index.html`
  - Curated sections are present in the rendered index.
- `rg -n "Long Horizon To Finish|Reference index cleanup|Florence-grade plot polish|current plot helpers are functional but still basic" pkgdown-site/articles/roadmap.html`
  - Roadmap HTML contains the new horizon and plot-status language.
- Export/reference/internal parity R script:
  - `PASS export/reference/internal parity`.
- Browser check:
  - `http://127.0.0.1:8765/reference/index.html` showed the curated sections
    and no visible old alias/internal topic names listed above.

## 7. Roadmap Tick

Updated `ROADMAP.md` with:

- Slice 11: Reference index cleanup.
- Slice 12: Symbol-to-syntax alignment blocks.
- Slice 13: Florence-grade plot polish.
- `Long Horizon To Finish`, explaining that the short dashboard is deliberate
  but not the whole project plan.

## 7a. GitHub Issue Ledger

- #230 commented with the Reference cleanup status and checks:
  <https://github.com/itchyshin/gllvmTMB/issues/230#issuecomment-4510578911>.

## 8. What Did Not Go Smoothly

The first internal-Rd scan used an under-escaped `rg` pattern for
`\keyword{internal}` and produced regex errors. I switched to fixed-string
matching and then used the generated Rd files plus a small R parity script.

The local `pkgdown-site/reference/index.html` was stale until
`pkgdown::build_reference()` ran, so checking the rendered page before rebuilding
would have falsely suggested the old deprecated section was still present.

## 9. Team Learning

Ada: Reference cleanup is now a real slice, not a side effect of article hiding.

Pat: A new user now sees `gllvmTMB()`, `traits()`, the core grid, and report
extractors before migration aliases or heavy diagnostics.

Rose: Exported compatibility functions stay available but are no longer
promoted as first-line API. The parity script protects against silently losing
exported public topics.

Grace: `pkgdown::check_pkgdown()`, `build_reference()`, and the browser pass
all agree.

## 10. Known Limitations And Next Actions

- The Reference page is cleaner, but individual reference topics still need
  later prose cleanup and status labels in places.
- Math was not removed as a principle. The next writing slice should restore
  useful symbolic notation as symbol table + R syntax + interpretation.
- Plots are still functional/basic. Florence-grade work remains a separate
  slice: colour-blind palettes, interval-aware displays, dominant-axis forests,
  score distributions, better ordination views, and rendered figure review.
- `devtools::test()` and `devtools::check()` were not run because no R
  implementation path changed.
