# After Task: Covariance/Correlation Closeout Wave 3

**Branch**: `codex/covariance-article-closeout-wave3-2026-05-24`
**Date**: `2026-05-24`
**Roles (engaged)**: `Ada / Florence / Pat / Fisher / Grace / Rose / Shannon`
**Spawned subagents**: none

## 1. Goal

Close the final rendered figure/prose gate for the visible
`covariance-correlation` article without changing package behavior.

## 2. Implemented

- Tightened the `Sigma_unit` point-display caption so it says the figure
  does not add uncertainty beyond the supplied rows.
- Tightened the correlation matrix caption and prose so readers see it as a
  formatted display of already-present Fisher-z interval columns, not a new
  uncertainty calculation.
- Added
  `docs/dev-log/audits/2026-05-24-covariance-correlation-final-figure-prose-review.md`.
- Updated `ROADMAP.md` and the article gate matrix to mark only
  `covariance-correlation` as final rendered figure/prose audit passed.

## 3. Files Changed

- `vignettes/articles/covariance-correlation.Rmd`
- `ROADMAP.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/audits/2026-05-24-covariance-correlation-final-figure-prose-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/recovery-checkpoints/2026-05-24-142116-ada-checkpoint.md`
- `docs/dev-log/after-task/2026-05-24-covariance-correlation-closeout-wave3.md`

No R source, likelihood, formula grammar, family, roxygen, generated Rd,
NAMESPACE, NEWS, `_pkgdown.yml`, or validation-debt status changed.

## 3a. Decisions and Rejected Alternatives

Decision: close only the covariance/correlation final rendered article gate.

Rationale: the article already had the prepared example object, paired
long/wide fit path, symbol-to-syntax table, and row-first extractors. The
remaining closeout gap was rendered figure/prose clarity around uncertainty
provenance, especially the matrix display.

Rejected alternative: change `plot_correlations()` globally. The current issue
was article-level interpretation, not a broken plotting API.

Rejected alternative: promote all remaining visible pages. That would
overclaim; `response-families`, `api-keyword-grid`,
`convergence-start-values`, and `pitfalls` still have their own gates.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json ...`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> recent Wave 1 / Wave 2 commits only; no competing open PR.
- `Rscript --vanilla -e 'devtools::install(quick = TRUE, dependencies = FALSE, build_vignettes = FALSE, quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", quiet = FALSE, new_process = FALSE)'`
  -> completed.
- `view_image("pkgdown-site/articles/covariance-correlation_files/figure-html/sigma-table-plot-1.png")`
  -> point-estimate plot rendered legibly.
- `view_image("pkgdown-site/articles/covariance-correlation_files/figure-html/communality-correlation-matrix-1.png")`
  -> matrix plot rendered legibly and the in-figure caption now uses
  supplied Fisher-z bounds wording.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/roadmap", quiet = FALSE, new_process = FALSE)'`
  -> completed.
- Additional checks are recorded in `docs/dev-log/check-log.md`.

## 5. Tests of the Tests

No tests were added or modified. This is an article render and status slice.
The executable guard is the targeted covariance/correlation render, which
would fail if the example object, fitted model, extractor calls, or plot calls
were broken.

## 6. Consistency Audit

Rose verdict: PASS for the touched public article and status ledger.

- `covariance-correlation` now has one audit path in the roadmap and gate
  matrix:
  `docs/dev-log/audits/2026-05-24-covariance-correlation-final-figure-prose-review.md`.
- The matrix display is described as a display of extractor-supplied interval
  columns, not interval calibration evidence.
- Other visible pages remain pending where their closeout checks are not done.
- No convention change occurred, so no roxygen/Rd/example cascade was
  required.

## 7. Roadmap Tick

`ROADMAP.md` and the public article gate matrix now mark
`covariance-correlation` as final rendered figure/prose audit passed. No other
article status was promoted.

## 7a. GitHub Issue Ledger

#230 remains open. This wave advances the visible article closeout lane but
does not close the broader article-surface reset.

## 8. What Did Not Go Smoothly

The rendered site directory still contained an old unused
`communality-correlation-plot-1.png` from a previous build. The rendered HTML
reference scan showed that the current page links only three active figures,
so the stale file was not treated as an article figure.

## 9. Team Learning

Ada kept the lane to one article and held push/PR work until the Wave 2
main-branch R-CMD-check and downstream pkgdown gates passed.

Florence treated figure captions as part of the figure, not decoration.

Pat kept the explanation tied to the practical question: why `unique()`
changes correlations and communality.

Fisher kept interval provenance explicit: display helper first, calibration
claim only when separate evidence exists.

Grace verified the deploy-facing path with targeted article renders and
pkgdown checks.

Rose checked that status promotion is limited to `covariance-correlation`.

Shannon's coordination view: no open PRs were present before local Wave 3
edits began. The branch was held locally until the active Wave 2 main
R-CMD-check and downstream pkgdown run passed.

## 10. Known Limitations And Next Actions

- This wave does not add new snapshots, extractor tests, or uncertainty
  calibration evidence.
- `response-families`, `api-keyword-grid`, `convergence-start-values`, and
  `pitfalls` still need their own closeout passes.
- Next safest slice after this PR: final wording audit for
  `convergence-start-values` or the requested balanced prose pass for
  `pitfalls`.
