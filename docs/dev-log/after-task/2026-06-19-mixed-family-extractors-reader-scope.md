# After-Task Report: mixed-family-extractors Reader Scope

Date: 2026-06-19 01:20 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Continue article-council step 6 by aligning the internal
`mixed-family-extractors` draft with the Tier 3 reader/scope gate.

## Files Touched

- `vignettes/articles/mixed-family-extractors.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-mixed-family-extractors-reader-scope.md`

## What Changed

- Added explicit Tier 3 YAML.
- Added a reader/scope bridge for per-row family dispatch, diagnostic metadata,
  latent-scale Sigma rows, point-estimate heatmap correlations, Fisher-z /
  bootstrap correlation examples, and `bootstrap_Sigma()` rows.
- Kept `CI-10` partial and `MIX-10` blocked. Delta and hurdle mixed-family
  latent-scale correlations remain out of scope because they do not share one
  latent scale.

## Verification

- Pre-edit lane check:
  - `gh pr list --state open` -> only draft PR #489 was open.
  - `git log --all --oneline --since="6 hours ago"` -> no recent commits.
- Article render:
  - `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/mixed-family-extractors", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Result: rendered `pkgdown-site/articles/mixed-family-extractors.html`.
- Rendered HTML review:
  - `mixed_rendered_reader_scope_review=PASS`.
  - Rendered HTML includes the reader/scope bridge, delta/hurdle shared-scale
    boundary, `fit_health_status`, compact PASS/WARN counts, bootstrap
    examples, and no stale `gllvmTMB_wide` / `meta_known_V` hits.
- Figure asset review:
  - `mixed_png_asset=PASS`.
  - `pkgdown-site/articles/mixed-family-extractors_files/figure-html/corr-1.png`
    exists with dimensions `1113x921`.
  - Florence verdict: pass as an internal point-estimate heatmap with readable
    labels and an explicit link-residual subtitle; it does not display
    intervals.

## Still Not Claimed

- No public promotion of `mixed-family-extractors`.
- No broad NB/beta/delta/hurdle mixed-response tutorial.
- No calibrated mixed-family interval coverage.
- No delta/hurdle latent-scale correlation target.
- No bridge completion, release readiness, or scientific coverage completion.

## Next Safest Action

Continue article-council step 6 with `ordinal-probit`.
