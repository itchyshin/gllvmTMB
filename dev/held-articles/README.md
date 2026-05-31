# Held draft articles

Draft articles moved out of the pkgdown build path because they currently break
or dominate the site build. They are preserved here intact and are **not** part
of the R package or the rendered site.

## lambda-constraint.Rmd -- RESOLVED 2026-05-31 (split + restored)

Originally moved 2026-05-31: the pkgdown "Build site" step spent ~34 min
knitting this article and then failed pandoc conversion with `error 5` on the
very large rendered document, blocking the **entire** site deploy.

**Resolution.** The article was split into two knittable children and restored to
`vignettes/articles/` (both registered under the `internal` group in
`_pkgdown.yml`):

1. `lambda-constraint.Rmd` -- the confirmatory walkthrough (kept the original
   slug, so the inbound cross-links from psychometrics-irt, data-shape-flowchart,
   choose-your-model, animal-model, and gllvm-vocabulary resolve unchanged).
2. `lambda-constraint-suggest.Rmd` -- the `suggest_lambda_constraint()` fallback
   (the data-driven conventions and the non-PD vs PD identifiability lesson).

Two root causes were fixed:

- **Pandoc template failure.** The YAML title carried inline LaTeX
  (`$\boldsymbol{\Lambda}$`); the `{` broke pkgdown's HTML template compile
  ("unexpected `{`"). Both children now use a plain-text title (`Lambda`).
- **Cold-cache refit blow-up.** The dominant cost was the
  `varimax-confidence-eye` chunk, which profiled *every* free loading entry of a
  non-PD refit (~250 partial refits). In the suggest child it now profiles a
  restricted set of 4 representative entries at a coarse grid (20 refits) and
  inverts the curve inline, preserving the teaching point.

Per-child cold `pkgdown::build_article()` wall-times verified locally: confirmatory
~505 s (6 figures), suggest ~62 s. No OOM. This directory now holds only this
note; the article files live under `vignettes/articles/`.
