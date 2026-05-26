# After-task: joint-SDM Sigma heatmap repair

**Date:** 2026-05-26
**Branch:** `codex/joint-sdm-sigma-heatmap-repair-2026-05-26`
**Spawned subagents:** none. Ada coordinated with Florence visual QA.

## Task Goal

Repair the remaining joint-SDM matrix figure blocker from the rendered QA:
replace the raw shared/total covariance heatmap with a latent-liability
residual species correlation heatmap that answers the first biological
question: which species show residual co-occurrence after `env_1`?

## Files Changed

- `vignettes/articles/joint-sdm.Rmd`
  - Replaced the `jsdm-sigma` raw shared/total Sigma heatmap with a
    `jsdm-correlation-heatmap` chunk.
  - Reuses `corr_rows <- extract_correlations(..., method = "fisher-z",
    link_residual = "auto")` so the preceding table carries the interval
    bounds and the figure shows point estimates only.
  - Uses `plot_correlations(..., style = "heatmap")` instead of article-local
    `geom_tile()` code or direct report-slot access.
  - Adds `fig.cap` and `fig.alt` for the correlation heatmap.
  - Suppresses the plot-internal caption so the rendered PNG does not clip
    caption text; the R Markdown figure caption carries the explanatory text.

## Checks Run

- `gh pr list --state open --limit 20 --json number,title,headRefName,mergeable,isDraft,statusCheckRollup,url`
  -> no open PRs before editing.
- `git log --all --oneline --since="6 hours ago"`
  -> no recent commits in the 6-hour window at branch start.
- `git status --short --branch`
  -> clean `main` before branch creation.
- `sed -n '1,180p' docs/dev-log/audits/2026-05-25-joint-sdm-rendered-figure-qa.md`
  -> confirmed the Sigma heatmap blocker and intended replacement surface.
- `Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); ...; corr_rows <- extract_correlations(fit_jsdm, tier="unit", method="fisher-z", link_residual="auto"); p <- plot_correlations(corr_rows, style="heatmap", matrix_layout="by_level", label_type="estimate", label_digits=2, include_diagonal=TRUE); print(attr(p,"gllvmTMB_meta")); print(range(corr_rows$correlation)); print(all(is.finite(corr_rows$lower), is.finite(corr_rows$upper)))'`
  -> metadata reported `type = "correlations_heatmap"`,
  `source = "extract_correlations"`, and
  `rotation_status = "rotation_invariant"`; correlation range stayed inside
  `[-1, 1]`; Fisher-z bounds were finite.
- `Rscript --vanilla -e 'rmarkdown::render("vignettes/articles/joint-sdm.Rmd", output_file="/tmp/gllvmTMB-joint-sdm-sigma-repair.html", quiet=TRUE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/joint-sdm", lazy = FALSE)'`
  -> wrote `pkgdown-site/articles/joint-sdm.html`.
- `rg -n "jsdm-sigma|jsdm-correlation-heatmap|Residual species correlations|Heatmap of pairwise|Shared and total latent-liability" pkgdown-site/articles/joint-sdm.html vignettes/articles/joint-sdm.Rmd`
  -> rendered HTML references the new figure and alt text; the old
  `jsdm-sigma` chunk no longer renders.
- Visual inspection of
  `pkgdown-site/articles/joint-sdm_files/figure-html/jsdm-correlation-heatmap-1.png`
  -> heatmap labels, legend, and title are readable at pkgdown size; no clipped
  caption remains.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.

## Florence Gate

**Verdict:** PASS for the matrix-figure repair.

The new figure uses a bounded correlation scale, names the estimand, keeps the
interval bounds in the preceding table, carries non-empty alt text, and avoids
the raw-covariance scale pathology that made the previous heatmap unsuitable
for teaching.

This pass does **not** promote the full article to public Tier 1. The wide
format chunk remains dormant until the binary absence-fill fixture exists, and
the article order / public restoration decision remain separate work.

## Definition of Done

- **Implementation:** one article figure section changed.
- **Simulation recovery test:** not applicable; no likelihood, family,
  formula grammar, or estimator changed.
- **Documentation:** article prose, caption, and alt text updated.
- **Runnable user-facing example:** article renders locally and through
  `pkgdown::build_article("articles/joint-sdm", lazy = FALSE)`.
- **Check-log entry:** appended in this branch.
- **Review pass:** Florence visual QA applied to the rendered heatmap.

## Known Limitations and Next Actions

- `joint-sdm` remains an internal article.
- The wide-format JSDM chunk remains `eval = FALSE`.
- Public restoration still needs a maintainer HTML review and a decision on
  whether to leave the wide chunk dormant or add the binary long-vs-wide
  absence-fill fixture first.
- No `diagnostic_table()` cross-link was added.
- No r200 dispatch was run.
