## data-raw/cv-fixture.R
## =======================
## Regenerate inst/extdata/cv-fixture.rds, the canonical cross-
## validation fixture.
##
## The RDS caches the DGP *data* and *truth* for four family variants
## (gaussian, binomial, poisson, nbinom2) that share identical latent
## structure (site/species layout, predictors, Lambda_B/psi_B draws);
## only the response draw differs per family. Fits are NOT saved; test
## code rebuilds them on demand via `gllvmTMB:::load_cv_fixture()` --
## see R/data-cv-fixture.R for the rationale (TMB obj pointers are not
## portable across R sessions).
##
## Re-run from the repo root:
##   Rscript data-raw/cv-fixture.R
##
## Output: inst/extdata/cv-fixture.rds (a 4-element named list keyed
## by family; each value is one element of the list returned by
## .build_cv_fixture()).

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

OUT_PATH <- file.path("inst", "extdata", "cv-fixture.rds")

cached <- gllvmTMB:::.build_cv_fixture()

attr(cached, "created_at") <- format(Sys.time(), tz = "UTC", usetz = TRUE)
attr(cached, "gllvmTMB_version") <-
  as.character(utils::packageVersion("gllvmTMB"))

if (!dir.exists(dirname(OUT_PATH))) {
  dir.create(dirname(OUT_PATH), recursive = TRUE)
}
saveRDS(cached, OUT_PATH)

cat(sprintf("[data-raw] saved -> %s (%d bytes)\n",
            OUT_PATH, file.size(OUT_PATH)))
