# Covariance/Correlation Final Figure/Prose Review

**Date:** 2026-05-24
**Issue ledger:** #230
**Article:** `vignettes/articles/covariance-correlation.Rmd`
**Rendered page:** `pkgdown-site/articles/covariance-correlation.html`
**Roles:** Ada, Florence, Pat, Fisher, Rose, Grace

## Verdict

PASS for the current public covariance/correlation article.

This is a rendered-article pass, not a new statistical-validation claim. The
prepared covariance edge-case object, long/wide formulas, extractor helpers,
and matrix displays remain bounded by validation-debt rows FG-02, FG-03,
FG-06, EXT-01, EXT-04, EXT-05, EXT-18, EXT-19, EXT-25, EXT-26, and
EXT-30.

## Rendered Figures Reviewed

The rendered HTML references three current figure files:

| Figure | Purpose | Florence verdict |
|---|---|---|
| `corr-comparison-1.png` | Estimate-minus-truth comparison for the latent-only and latent + unique fits | PASS: the zero reference, signed colours, and caption make this a one-dataset truth comparison, not an interval display. |
| `sigma-table-plot-1.png` | Report-ready `Sigma_unit` off-diagonal point estimates | PASS after this slice: the caption states that open points have no finite bounds and the figure adds no uncertainty beyond the supplied rows. |
| `communality-correlation-matrix-1.png` | Matrix display of point correlations and supplied Fisher-z bounds | PASS after this slice: the caption/prose state that the matrix displays already-present extractor columns and does not bootstrap, profile, or calibrate uncertainty. |

## Prose Review

Pat verdict: PASS for the current reader path.

The article starts from the applied question, explains why `unique()` changes
the denominator of a correlation, shows both long-format and wide
`traits(...)` formulas through `gllvmTMB()`, and uses the prepared
`covariance-edge-cases-example.rds` object instead of making the reader parse
a long data-generating script first.

Fisher/Rose boundary: PASS with explicit limits.

- The truth comparison is a one-dataset teaching check, not simulation
  coverage.
- The `plot_Sigma_table()` example is point-estimate display only because the
  rows in the article have no finite interval bounds.
- The `plot_correlations()` matrix view displays Fisher-z interval columns
  already present in `corr_B`; it does not compute, bootstrap, profile, or
  calibrate uncertainty.
- Binary, count, mixed-family, phylogenetic, and spatial extensions remain
  framed as validation-row-dependent rather than advertised as finished worked
  examples.

## Fix Applied

This slice tightened the rendered figure and prose wording around uncertainty
provenance:

- the `Sigma_unit` plot caption now states that the figure does not add
  uncertainty beyond the supplied rows;
- the correlation matrix caption now says that lower cells display the
  Fisher-z interval columns already present in the extractor output;
- the prose below the matrix says to read it as a formatted table, not a new
  uncertainty calculation.

## Checks

Commands are recorded in `docs/dev-log/check-log.md` under the 2026-05-24
covariance/correlation closeout Wave 3 entry.

## Remaining Visible-Article Gaps

This closes `covariance-correlation` only. `response-families`,
`api-keyword-grid`, `convergence-start-values`, and `pitfalls` retain their
own article-gate statuses until their rendered or wording closeout checks are
done.
