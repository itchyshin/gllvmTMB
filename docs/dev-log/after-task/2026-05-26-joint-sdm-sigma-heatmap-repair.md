# After-task: joint-SDM figure and fixture repair

**Date:** 2026-05-26
**Branch:** `codex/joint-sdm-sigma-heatmap-repair-2026-05-26`
**Spawned subagents:** none. Ada coordinated with Florence visual QA.

## Task Goal

Repair the remaining joint-SDM matrix figure blocker from the rendered QA and
replace the dormant wide-format sketch with a runnable fixture-backed
equivalence check.

The article now uses a shipped complete binary Site x Species teaching fixture,
fits the same JSDM through both long and wide `traits(...)` calls, and uses the
long fit for report-ready residual species correlations and ordination.

## Files Changed

- `vignettes/articles/joint-sdm.Rmd`
  - Loads `inst/extdata/examples/joint-sdm-example.rds` instead of building a
    bespoke simulation inside the article.
  - Runs both the long and wide formulas from that fixture and prints
    `all.equal(logLik(fit_jsdm), logLik(fit_jsdm_wide), tolerance = 1e-8)`.
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
- `data-raw/examples/make-joint-sdm-example.R`
  - Regenerates a portable complete binary Site x Species teaching fixture.
- `inst/extdata/examples/joint-sdm-example.rds`
  - Stores long data, wide data, truth, formulas, fit arguments, story, and the
    symbol-to-extractor alignment table.
- `tests/testthat/test-example-joint-sdm.R`
  - Checks the example-object contract, long/wide likelihood equality, bounded
    loadings, Fisher-z correlation extraction, and correlation / ordination plot
    buildability.
- `docs/design/52-example-object-contract.md`
  - Adds the joint-SDM fixture and test to the active teaching-fixture contract.

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
- Follow-up fixture generation:
  `Rscript --vanilla data-raw/examples/make-joint-sdm-example.R`
  -> wrote `inst/extdata/examples/joint-sdm-example.rds`.
- Formatter:
  `air format data-raw/examples/make-joint-sdm-example.R tests/testthat/test-example-joint-sdm.R`
  -> completed.
- New fixture test:
  `Rscript --vanilla -e 'devtools::test(filter = "example-joint-sdm", reporter = "summary")'`
  -> PASS.
- Article render after fixture activation:
  `Rscript --vanilla -e 'pkgdown::build_article("articles/joint-sdm", lazy = FALSE)'`
  -> wrote `pkgdown-site/articles/joint-sdm.html`; the rendered wide chunk
  prints `#> [1] TRUE`.
- Rendered fit smoke:
  `Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); jsdm <- readRDS("inst/extdata/examples/joint-sdm-example.rds"); fit <- gllvmTMB(jsdm$formula_long, data=jsdm$data_long, trait=jsdm$fit_args$trait, unit=jsdm$fit_args$unit, family=jsdm$fit_args$family); ...'`
  -> convergence `0`, `max(abs(Lambda_B)) = 1.208245`, correlation range
  `[-0.289, 0.218]`, finite Fisher-z bounds.
- Visual inspection after fixture activation:
  `pkgdown-site/articles/joint-sdm_files/figure-html/jsdm-correlation-heatmap-1.png`
  and `pkgdown-site/articles/joint-sdm_files/figure-html/jsdm-biplot-1.png`
  -> heatmap and ordination remained readable at pkgdown size.

## Florence Gate

**Verdict:** PASS for the matrix-figure and fixture-backed wide-path repair.

The new figure uses a bounded correlation scale, names the estimand, keeps the
interval bounds in the preceding table, carries non-empty alt text, and avoids
the raw-covariance scale pathology that made the previous heatmap unsuitable
for teaching.

This pass does **not** promote the full article to public Tier 1. The core
figure and long/wide infrastructure blockers are repaired, but the article
order and public restoration decision remain separate maintainer decisions.

## Definition of Done

- **Implementation:** article fit path, article figures, and teaching fixture
  changed; no package runtime API changed.
- **Simulation recovery test:** not applicable as a deep recovery claim; the
  new example-object test checks fixture contract, long/wide likelihood
  equality, bounded fitted loadings, Fisher-z correlations, and plot
  buildability.
- **Documentation:** article prose, caption, alt text, and the example-object
  contract updated.
- **Runnable user-facing example:** article renders locally and through
  `pkgdown::build_article("articles/joint-sdm", lazy = FALSE)`.
- **Check-log entry:** appended in this branch.
- **Review pass:** Florence visual QA applied to the rendered heatmap and
  ordination after fixture activation.

## Known Limitations and Next Actions

- `joint-sdm` remains an internal article.
- The wide-format JSDM chunk now runs and prints likelihood equality.
- Public restoration still needs a maintainer HTML review and article-order
  decision.
- No `diagnostic_table()` cross-link was added.
- No r200 dispatch was run.
