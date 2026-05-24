# Morphometrics Final Figure/Prose Review

**Date:** 2026-05-24
**Issue ledger:** #230
**Article:** `vignettes/articles/morphometrics.Rmd`
**Rendered page:** `pkgdown-site/articles/morphometrics.html`
**Roles:** Ada, Florence, Pat, Darwin, Fisher, Grace, Rose

## Verdict

PASS for the current public Morphometrics article.

This is a rendered-article pass, not a new statistical-validation claim. The
Gaussian example object, long/wide formulas, extractor helpers, and cached
bootstrap display fixture remain bounded by validation-debt rows FG-02,
FG-03, FG-06, FAM-01, EXT-01, EXT-05, EXT-09, EXT-19, EXT-23, EXT-25,
EXT-26, and MIS-22.

## Rendered Figures Reviewed

The rendered HTML references four current figure files:

| Figure | Purpose | Florence verdict |
|---|---|---|
| `corr-comparison-1.png` | Estimate minus truth for pairwise correlations | PASS: clear zero reference, explicit error scale, and caption states this is not uncertainty. |
| `ci-correlation-eye-1.png` | Cached bootstrap correlation confidence-eye display | PASS: hollow estimates, pale compatibility shapes, and caption/prose state that this is not posterior density or calibration evidence. |
| `ci-correlation-ellipse-1.png` | Cached bootstrap correlation ellipse display | PASS: labels, stars, borders, and legend are legible at article size. |
| `ordi-1.png` | Latent-score ordination biplot with standardized loading arrows | PASS after this slice: the clipped caption was replaced with a shorter rotation-honest caption and the figure height was increased. |

## Prose Review

Pat/Darwin verdict: PASS for the current public path.

The article opens with the applied question, shows long and wide fits through
the single `gllvmTMB()` entry point, explains `unit = "individual"`, and keeps
the advanced complexity ladder under audit rather than routing readers to
immature pages as recommended next steps.

Fisher/Rose boundary: PASS with explicit limits.

- The one-dataset truth-vs-fit comparison is described as a teaching check,
  not simulation coverage.
- The cached bootstrap correlation fixture is described as a lightweight
  rendered plotting example, not interval-calibration evidence.
- Rotation ambiguity is stated near the ordination section; Sigma,
  correlation, communality, and uniqueness remain the primary
  rotation-invariant summaries.

## Fix Applied

The rendered ordination figure previously clipped the final line of its
built-in caption. The article now overrides the plot caption with three short
lines:

- grey points and standardized loading arrows;
- varimax rotation with sign anchors on mass and wing;
- Sigma/correlation summaries as the rotation-invariant interpretation path.

The chunk height was increased from 5.0 to 5.6 inches.

## Checks

Commands are recorded in `docs/dev-log/check-log.md` under the 2026-05-24
visible article closeout Wave 2 entry.

## Remaining Visible-Article Gaps

This closes Morphometrics only. `covariance-correlation`,
`response-families`, `api-keyword-grid`, `convergence-start-values`, and
`pitfalls` retain their own article-gate statuses until their rendered
closeout checks are done.
