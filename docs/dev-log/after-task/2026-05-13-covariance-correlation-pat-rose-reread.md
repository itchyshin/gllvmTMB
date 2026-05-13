# Covariance-correlation Pat/Rose reread

Date: 2026-05-13
Agent: Codex
Branch: `codex/covariance-correlation-pat-rose-reread`

## Goal

Re-read `vignettes/articles/covariance-correlation.Rmd` after PR #61
as a Tier-1 user article, then make the smallest fixes needed for
Pat readability and Rose pre-publish consistency.

## Coordination

- The coordination board assigns
  `vignettes/articles/covariance-correlation.Rmd` to Codex for this
  docs/navigation pass.
- The open-PR check found PR #68 touching only
  `docs/dev-log/coordination-board.md`; no open PR touched the article.
- Pat and Rose were used as bounded read-only reviewers before the
  final edits.

## Changes

- Replaced the abstract opening with a behavioural-syndrome use case.
- Added early `gllvmTMB()` snippets showing the latent-only model and
  the `latent() + unique()` fix.
- Added the equivalent wide data-frame form using `traits(...)`, not
  `gllvmTMB_wide()`.
- Defined `level` before using `Sigma_level`.
- Softened broad prose claims and kept the public notation on `S` /
  `s`.
- Added `unit_obs = "obs_id"` to two-level and OLRE guidance.
- Renamed the OLRE heading from future-work wording to current-support
  wording.
- Replaced stale See also links with current references to `?unique`,
  `?extract_Sigma`, and `?suggest_lambda_constraint`.

## Checks

- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", new_process = FALSE)'`
  completed. It emitted the known `../logo.png` pkgdown image warning.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed.
- `git diff --check` passed.
- Targeted stale-term scan over the article and rendered HTML found no
  hits for the old wording this lane was meant to remove.

## Not run

- Full `devtools::test()` and `devtools::check()` were not run because
  the code surface did not change.

## Follow-up

- The article is now narrow enough to keep, not rewrite wholesale.
- The next Codex docs lane remains `_pkgdown.yml` navbar restructuring
  once the coordination board branch is merged or rebased cleanly.
