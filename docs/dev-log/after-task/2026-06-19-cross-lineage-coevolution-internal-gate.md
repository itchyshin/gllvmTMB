# Cross-Lineage Coevolution Internal Gate

Date: 2026-06-19 01:40 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice aligned `vignettes/articles/cross-lineage-coevolution.Rmd` with the
current Paper 2 coevolution evidence. It did not promote the article to a
public worked example and did not change model code, formula grammar, or
keyword lifecycle behaviour.

## What Changed

- Added explicit Tier 3 YAML and an internal article gate.
- Added the Paper 2 two-source covariance identity:
  `C_phy Gamma_phy + C_tip Gamma_tip`.
- Added a fixed-kernel screening section for raw reciprocal dependence
  `W_recip = sqrt(p(j|i) p(i|j))` versus a residualized tip candidate.
- Tied the article wording to the COE-04 diagnostic gate:
  raw reciprocal tip kernels require sensitivity, while near-orthogonal
  residualized candidates may support component-specific claims.
- Updated the article-council ledger row for `cross-lineage-coevolution`.

## Checks

- `gh pr list --state open`
  - only draft PR #489 on `codex/r-bridge-grouped-dispersion`.
- `git log --all --oneline --since="6 hours ago"`
  - no recent commits.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/cross-lineage-coevolution", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - rendered `pkgdown-site/articles/cross-lineage-coevolution.html`.
- Rendered HTML scope review:
  - `cross_lineage_rendered_scope_review=PASS`.
- Figure asset check:
  - `pkgdown-site/articles/cross-lineage-coevolution_files/figure-html/gamma-plot-1.png`
    exists at `1382 x 844`.

## Definition Of Done Status

- Implementation: not applicable; article/status slice only.
- Simulation recovery: not added here; the linked evidence is the existing
  COE-04 reciprocal-dependence diagnostic gate.
- Documentation: article and article-council ledger updated.
- Runnable example: unchanged; heavy fit chunks remain `eval = FALSE` by
  design, and light matrix/fixture chunks rendered.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Rose-style scope boundary applied; Fisher/Noether caveats kept
  explicit.

## Not Claimed

- No in-engine `rho` estimation.
- No `rho` profile intervals.
- No calibrated `Gamma` or module intervals.
- No formal null/Type-I threshold.
- No public article promotion.
- No release readiness or scientific coverage completion.
