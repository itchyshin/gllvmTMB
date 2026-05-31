# Held draft articles

Draft articles moved out of the pkgdown build path because they currently break
or dominate the site build. They are preserved here intact and are **not** part
of the R package or the rendered site.

## lambda-constraint.Rmd

Moved 2026-05-31. The pkgdown "Build site" step spent ~34 min knitting this
article and then failed pandoc conversion with `error 5` (out of memory) on the
very large rendered document, blocking the **entire** site deploy. Held until it
is slimmed or split into smaller articles.

To restore once slimmed:

1. `git mv dev/held-articles/lambda-constraint.Rmd vignettes/articles/`
2. Re-add `- articles/lambda-constraint` under the `internal` group in `_pkgdown.yml`.

Cross-links to `lambda-constraint.html` from other articles (psychometrics-irt,
data-shape-flowchart, choose-your-model, animal-model, gllvm-vocabulary) were
left in place so they resolve again as soon as the article returns.
