# Preview-banner register citations

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Rose, Pat, Grace
**Spawned subagents:** none

## Scope

Tightened Preview banners in four touched public articles before updating
draft PR #233:

- `vignettes/articles/functional-biogeography.Rmd`
- `vignettes/articles/choose-your-model.Rmd`
- `vignettes/articles/lambda-constraint.Rmd`
- `vignettes/articles/psychometrics-irt.Rmd`

The change replaces generic validation-register references with concrete row
IDs and updates stale binary-IRT wording now that LAM-03 is `covered`.

## Validation

- `rg -n "latent\\(|unique\\(|phylo_|spatial_|meta_V|FG-|MET-|SP|PHY|LAM-|MIX-|FAM-" docs/design/35-validation-debt-register.md`
  confirmed the row IDs and current statuses used in the banners.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); for (article in c("articles/functional-biogeography", "articles/choose-your-model", "articles/lambda-constraint", "articles/psychometrics-irt")) pkgdown::build_article(article, quiet = TRUE, new_process = FALSE)'`
  rendered all four affected articles.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned
  `No problems found.`
- `git diff --check` was clean after edits.
- Stale preview wording scan returned no hits:
  ```sh
  rg -n 'LAM-03 `partial`|walks to `covered` after|Each individual covariance component.*`covered`|machinery is partly `partial`|R ≥' vignettes/articles/functional-biogeography.Rmd vignettes/articles/choose-your-model.Rmd vignettes/articles/lambda-constraint.Rmd vignettes/articles/psychometrics-irt.Rmd
  ```

## Deliberately Not Run

- Full `devtools::check()` was not rerun for this prose-only Rose fix. The
  touched articles rendered, pkgdown checked clean, and the PR branch will
  receive 3-OS CI after push.

## Verdict

Rose: pass for the corrected banners.
Pat: safer for applied readers because the banner now distinguishes covered,
partial, and planned work before the article proceeds.
Grace: pkgdown clean.
