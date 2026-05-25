# Joint SDM Rendered Figure QA

**Date**: 2026-05-25
**Role lane**: Boole / Grace / Pat, with Florence figure gate
**Scope**: Rendered-learning-path and figure QA for
`vignettes/articles/joint-sdm.Rmd` as a future Tier-1 public page.

## Commands Run

```sh
git status --short --branch
gh pr list --state open --json number,title,headRefName,files --jq '.[] | {number,title,headRefName,files:[.files[].path]}'
git log --all --oneline --since="6 hours ago"
test -f docs/design/46-visualization-grammar.md && sed -n '1,260p' docs/design/46-visualization-grammar.md || printf 'MISSING\n'
sed -n '1,620p' vignettes/articles/joint-sdm.Rmd
Rscript --vanilla -e 'pkgdown::build_article("joint-sdm", lazy = FALSE)'
Rscript --vanilla -e 'pkgdown::build_article("articles/joint-sdm", lazy = FALSE)'
find pkgdown-site/articles/joint-sdm_files -type f -maxdepth 4 -print -exec file {} \;
Rscript --vanilla -e 'library(gllvmTMB); set.seed(2025); T <- 8; n_sites <- 100; Lam_true <- matrix(c(-1.2,-1.0,-1.1,-0.9,+1.0,+1.2,+1.1,+0.9,-1.0,-1.2,+1.1,+0.9,-1.0,-1.1,+1.0,+1.2), nrow=T, ncol=2); sim <- simulate_site_trait(n_sites=n_sites, n_species=6, n_traits=T, mean_species_per_site=5, Lambda_B=Lam_true, psi_B=rep(0.4,T), sigma2_eps=0.01, seed=2025); df <- sim$data; df$value <- as.integer(df$value > 0); fit_jsdm <- gllvmTMB(value ~ 0 + trait + (0 + trait):env_1 + latent(0 + trait | site, d = 2), data=df, trait="trait", family=binomial()); print(fit_jsdm$sdr$pdHess); print(max(abs(fit_jsdm$report$Lambda_B))); print(round(range(extract_Sigma_table(fit_jsdm, level="unit", part="shared", entries="all")$estimate), 3)); print(table(df$trait, df$value))'
Rscript --vanilla -e 'library(gllvmTMB); library(ggplot2); set.seed(2025); T <- 8; n_sites <- 100; Lam_true <- matrix(c(-1.2,-1.0,-1.1,-0.9,+1.0,+1.2,+1.1,+0.9,-1.0,-1.2,+1.1,+0.9,-1.0,-1.1,+1.0,+1.2), nrow=T, ncol=2); sim <- simulate_site_trait(n_sites=n_sites, n_species=6, n_traits=T, mean_species_per_site=5, Lambda_B=Lam_true, psi_B=rep(0.4,T), sigma2_eps=0.01, seed=2025); df <- sim$data; df$value <- as.integer(df$value > 0); fit_jsdm <- gllvmTMB(value ~ 0 + trait + (0 + trait):env_1 + latent(0 + trait | site, d = 2), data=df, trait="trait", family=binomial()); p <- plot(fit_jsdm, type="ordination", level="unit", rotation="varimax", sign_anchor="auto", standardize_loadings=TRUE); print(attr(p,"gllvmTMB_meta")); print(names(attr(p,"gllvmTMB_data"))); print(head(attr(p,"gllvmTMB_data")$loadings));'
```

Render note: `pkgdown::build_article("joint-sdm", lazy = FALSE)` failed with
`Can't find article 'joint-sdm'`. The valid pkgdown article name in this
checkout is `articles/joint-sdm`.

Rendered output:

- HTML: `pkgdown-site/articles/joint-sdm.html`
- Sigma heatmap: `pkgdown-site/articles/joint-sdm_files/figure-html/jsdm-sigma-1.png`
- Ordination biplot: `pkgdown-site/articles/joint-sdm_files/figure-html/jsdm-biplot-1.png`

## Coordination Notes

Open PR ownership checked before writing this audit. PR #261 owns
`README.md`, `ROADMAP.md`, `docs/dev-log/check-log.md`, `vignettes/gllvmTMB.Rmd`,
and `vignettes/articles/convergence-start-values.Rmd`; PR #265 owns
`ROADMAP.md`, `_pkgdown.yml`, `docs/dev-log/check-log.md`, diagnostics files,
and generated docs; PR #267 owns `docs/dev-log/audits/2026-05-25-set-c-joint-sdm-gate-matrix.md`
and coordination docs. This audit uses a new file path and does not edit those
owned files.

The working tree already had uncommitted edits in protected files:
`docs/design/04-random-effects.md` and `vignettes/articles/joint-sdm.Rmd`.
Those were treated as someone else's active edits and were not modified.

## Blocker Verdict

**FAIL for public Tier-1 publication in the current rendered form.**

The article is promising as the binary JSDM worked example, but the rendered
figures do not yet pass the Florence gate and the learning path still starts
with a large notation block before the reader sees the biological workflow.
The article should stay out of the public Tier-1 restoration path until the
figure surface and fit example are stabilized.

## Blockers

1. **The fitted example produces extreme latent covariance values.**
   The rendered Sigma heatmap spans approximately -578 to 7865 for the shared
   covariance. A diagnostic reproduction gave `max(abs(Lambda_B)) = 88.6` and
   `range(shared Sigma) = [-577.937, 7864.786]`. That scale makes the heatmap a
   numerical pathology display, not a teaching figure.

2. **The Sigma figure answers the wrong first visual question.**
   For a binary JSDM reader, the first matrix view should show interpretable
   latent-liability species correlations, not raw shared and total covariance
   matrices dominated by the diagonal and by arbitrary loading scale. Keep the
   shared-vs-total Sigma distinction in prose or a compact table, but make the
   public figure a correlation heatmap or lower-triangle matrix backed by
   `extract_correlations(..., link_residual = "auto")`.

3. **The ordination biplot is hand-built and default-looking.**
   The chunk manually extracts `fit_jsdm$report$Lambda_B`, hand-scales arrows,
   uses fixed tomato/steelblue colours, and ends with `theme_minimal()`. The
   rendered labels overlap around the origin, the plot has no title, caption,
   or alt text, and the rotation caveat appears only after the image.

4. **Rotation honesty is present in prose but not attached to the biplot.**
   Design 46 requires loadings displays to state that loading sign and rotation
   are not identifiable and that the rotation-invariant target is implied
   Sigma. The current rendered `<img>` for `jsdm-biplot` has empty alt text and
   no figure caption, so the caveat is too easy to miss.

5. **Wide-format teaching is visible but not runnable.**
   The article correctly shows long and `traits(...)` wide syntax side by side,
   but the wide chunk is `eval = FALSE` and uses a placeholder `df_wide`.
   For final Tier-1 status, either make the wide data construction and
   equivalence check runnable, or explicitly mark this as a staged limitation
   before the figure workflow.

6. **The section order is still too notation-first for a public worked example.**
   A Tier-1 reader should move from biological question to data/model to fit to
   interpretation, then notation. This article opens with several covariance
   subsections before setup and fitting. The notation is useful, but should be
   moved after the first successful model and first interpretable plot.

## Recommended Plot Surface Before Publication

- Use `extract_correlations(fit_jsdm, tier = "unit", link_residual = "auto")`
  as the main table source for the species association figure.
- Use `plot_correlations(..., style = "heatmap", matrix_layout = "estimate")`
  or an equivalent lower-triangle point-estimate heatmap for the main article
  figure. Do not put full Fisher-z interval strings inside every matrix cell at
  eight species; they are cramped and unreadable.
- Put uncertainty in a companion table or interval forest for the top
  biologically discussed pairs, using the same extracted correlation rows.
- Use `plot(fit_jsdm, type = "ordination", level = "unit", rotation = "varimax",
  sign_anchor = "auto", standardize_loadings = TRUE)` for the biplot instead
  of hand-building it. In the test render, this helper exposed
  `gllvmTMB_meta$rotation_status = "varimax_ordered_sign_anchored"` and
  returned inspectable `gllvmTMB_data` for scores, loadings, and rotation.
- If helper output is still too crowded, fix the helper/data surface rather than
  adding article-local geoms. The article should demonstrate package plot
  helpers, not teach readers to reach into `fit$report`.

## Visual QA Checklist for Restoration PR

- Render `pkgdown::build_article("articles/joint-sdm", lazy = FALSE)` and record
  the output path.
- Confirm the fitted example has a healthy diagnostic status before plotting:
  convergence code, Hessian/diagnostic summary where available, finite loading
  scale, and no extreme Sigma range used as a teaching default.
- Confirm the first plot answers the biological question: which species show
  residual co-occurrence after `env_1`?
- Confirm every rendered figure has a caption and non-empty alt text.
- Confirm the Sigma/correlation plot names its estimand, level, part, scale,
  and interval method/status.
- Confirm the biplot caption states rotation/sign ambiguity and names Sigma or
  correlations as the rotation-invariant interpretation.
- Confirm plotted data are inspectable through `attr(p, "gllvmTMB_data")` and
  metadata through `attr(p, "gllvmTMB_meta")`.
- Confirm labels remain readable at pkgdown width and do not overlap.
- Confirm colours are colourblind-safe and print-readable; avoid unmodified
  `theme_minimal()` article-local plots.
- Confirm wide-format and long-format examples either both run or the limitation
  is explicitly visible without sounding like package incompleteness.

## Smallest Next Visual Task

Replace the hand-built `jsdm-biplot` chunk with the existing ordination helper
call, add `fig.cap` and `fig.alt`, and rerender the article. That is the
smallest visual task because it removes direct `fit$report$Lambda_B` access,
adds rotation metadata, and makes the article exercise the public plotting API
without changing likelihood code or formula grammar.
