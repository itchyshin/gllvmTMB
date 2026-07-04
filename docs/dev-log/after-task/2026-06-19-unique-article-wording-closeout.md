# Unique Deprecation Article Wording Closeout

Date: 2026-06-19 04:25 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Continue the post-coevolution `unique()` deprecation lane by tightening live
article wording that still made `unique()` or `phylo_unique()` sound like a
first-line new-user recommendation.

## Implementation

- In `vignettes/articles/api-keyword-grid.Rmd`, the wide-form shorthand note now
  teaches `indep()`, `dep()`, and supported source-specific shorthand first.
  It names explicit `unique()` as soft-deprecated compatibility syntax for old
  formulas.
- In `vignettes/articles/choose-your-model.Rmd`, the phylogenetic
  `phylo_latent() + phylo_unique() + latent()` row is no longer labelled as a
  generally recommended canonical path. It now names the row as explicit
  phylogenetic-Psi compatibility spelling and says to use it only when the
  phylogenetic diagonal component is separately identifiable.

## Article-Tier Audit

This is a narrow wording repair, not a tier change. Both articles keep their
current internal/article-council status; no public promotion is claimed.

## Files Touched

- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/choose-your-model.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-19-unique-article-wording-closeout.md`

## Verification

- `Rscript --vanilla -e 'rmarkdown::render("vignettes/articles/api-keyword-grid.Rmd", output_dir = tempdir(), quiet = TRUE)'`
  -> passed.
- `Rscript --vanilla -e 'rmarkdown::render("vignettes/articles/choose-your-model.Rmd", output_dir = tempdir(), quiet = TRUE)'`
  -> passed.
- `rg -n 'same shorthand applies to \`unique\\(\\)\`|Canonical paired phylogenetic decomposition|recommended when traits can be both phylogenetically' vignettes/articles/api-keyword-grid.Rmd vignettes/articles/choose-your-model.Rmd`
  -> no matches.
- `git diff --check`
  -> clean.

## Not Claimed

- No keyword removal.
- No escalation from `deprecate_soft()` to `deprecate_warn()` for the
  `unique()` family.
- No source-specific paired-Psi fold.
- No expansion of `kernel_unique()` for Paper 2.

