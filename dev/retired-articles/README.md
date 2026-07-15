# Retired articles (kept, not deleted)

Source `.Rmd` files that have been **cut from the reader-facing pkgdown site** but
**deliberately preserved** in the repository. This directory is under `^dev$` in
`.Rbuildignore`, so nothing here ships in the package build or renders on the site.

Restore an article by moving it back to `vignettes/articles/` and re-adding it to
`_pkgdown.yml`.

| File | Status | Provenance |
|---|---|---|
| `animal-model.Rmd` | Cut for now (0.5 cycle); **not deleted** — maintainer decision 2026-07-15 | Verbatim last version from `3159c421:vignettes/articles/animal-model.Rmd` (removed from the article estate in `eacbd0f6`, "finalize public article estate for 0.5.0"). |

**Note on discoverability:** cutting the animal-model *article* does not remove the
`animal_*` *functions*. `animal_slope`, `animal_scalar`, `animal_indep`,
`animal_dep`, `animal_latent`, and `animal_unique` remain live exports and stay in
the pkgdown reference index (`_pkgdown.yml`, "Source-specific covariance keywords"),
and the keyword grid in `vignettes/articles/api-keyword-grid.Rmd` still documents
them. The exports are discoverable without the dedicated walkthrough.
