# After-Task Report: random-regression Reaction-Norm Reader Scope

Date: 2026-06-19 01:17 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Start article-council step 6 by improving the internal
`random-regression-reaction-norms` draft without promoting it publicly.

## Files Touched

- `vignettes/articles/random-regression-reaction-norms.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-random-regression-reader-scope.md`

## What Changed

- Replaced the old "needs plain-language reader pass" placeholder with a
  reader/scope bridge.
- Mapped the behavioural reaction-norm question to long/wide fit equivalence,
  augmented covariance blocks, known-truth recovery, repeatability curves, and
  diagnostics.
- Removed the unused `library(dplyr)` attach from the article setup.
- Tightened the diagnostic boundary: optimizer and gradient rows must pass,
  while `sdreport` and Hessian rows warn by design because the article uses
  `se = FALSE` for quick rendering.
- Kept `unique()` only in the deliberately failing compatibility-boundary
  chunk; the fitted Gaussian examples use default `latent()` with
  `Psi_B,aug`.

## Verification

- Pre-edit lane check:
  - `gh pr list --state open` -> only draft PR #489 was open.
  - `git log --all --oneline --since="6 hours ago"` -> no recent commits.
- Article render:
  - `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/random-regression-reaction-norms", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Result: rendered `pkgdown-site/articles/random-regression-reaction-norms.html`.
- Rendered HTML review:
  - `rrn_rendered_reader_scope_review=PASS`.
  - Rendered HTML shows long/wide log-likelihood difference `0`, relative
    Frobenius error `0.132`, optimizer and gradient `PASS`, and expected
    `sdreport` / `pd_hessian` `WARN` rows.
- Rendered figure assets:
  - `recovery-plot-1.png` exists at `1248x921`.
  - `repeatability-plot-1.png` exists at `1344x921`.
  - Florence verdict: narrow pass for internal point-estimate teaching. The
    recovery plot clearly distinguishes intercept-intercept, intercept-slope,
    and slope-slope blocks against the perfect-recovery line; the
    repeatability plot distinguishes estimate versus truth across temperature.

## Still Not Claimed

- No public promotion of `random-regression-reaction-norms`.
- No calibrated intervals for slope variances, slope correlations,
  intercept-slope correlations, or repeatability curves.
- No non-Gaussian augmented diagonal `Psi` support.
- No `unique()` API removal.
- No bridge completion, release readiness, or scientific coverage completion.

## Next Safest Action

Continue article-council step 6 with `random-slopes-nongaussian`,
`mixed-family-extractors`, or `ordinal-probit`, keeping each page internal
until its reader path, diagnostics, and rendered/browser review pass.
