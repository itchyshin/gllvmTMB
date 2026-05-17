## data-raw/mixed-family-fixture.R
## ================================
## Regenerate inst/extdata/mixed-family-fixture.rds for the M1
## mixed-family extractor-rigour fixture.
##
## The RDS caches the DGP *data* and *truth* for the 3-family
## (Gaussian + binomial + Poisson) and 5-family (+ Gamma + nbinom2)
## fixtures. Fits are NOT saved; tests rebuild them on demand via
## gllvmTMB:::fit_mixed_family_fixture() — see R/data-mixed-family.R
## for the rationale (TMB obj pointers are not portable across R
## sessions).
##
## Re-run from the repo root:
##   Rscript data-raw/mixed-family-fixture.R
##
## Output: inst/extdata/mixed-family-fixture.rds (a 2-element named
## list with `three` and `five` keys; each value is the fixture list
## returned by .build_mixed_family_fixture()).

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

OUT_PATH <- file.path("inst", "extdata", "mixed-family-fixture.rds")

fixture_3 <- gllvmTMB:::.build_mixed_family_fixture(n_families = 3L)
fixture_5 <- gllvmTMB:::.build_mixed_family_fixture(n_families = 5L)

cached <- list(three = fixture_3, five = fixture_5)

attr(cached, "created_at") <- format(Sys.time(), tz = "UTC", usetz = TRUE)
attr(cached, "gllvmTMB_version") <-
  as.character(utils::packageVersion("gllvmTMB"))

if (!dir.exists(dirname(OUT_PATH))) {
  dir.create(dirname(OUT_PATH), recursive = TRUE)
}
saveRDS(cached, OUT_PATH)

cat(sprintf("[data-raw] saved -> %s (%d bytes)\n",
            OUT_PATH, file.size(OUT_PATH)))
