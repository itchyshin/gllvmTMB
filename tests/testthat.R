options(Matrix.warnDeprecatedCoerce = 2)

library(testthat)
library(gllvmTMB)

full_suite <- isTRUE(as.logical(Sys.getenv("NOT_CRAN", ""))) ||
  identical(Sys.getenv("GITHUB_ACTIONS"), "true")

cran_sentinels <- paste0(
  "^(cran-sentinels|release-core-sentinels|formula-grammar-smoke|",
  "traits-keyword|integration-tour|canonical-keywords|kernel-equivalence|",
  "animal-keyword|family-constructor-contract|family-gamma|family-lognormal|",
  "cran-family-sentinels|cran-missing-data-sentinels|missing-response-nongaussian|",
  "unused-grouping-slots|sigma-rename|bootstrap-Sigma|bootstrap-lv-effects|",
  "spatial-latent-unique-fold|lv-missing-response|",
  "link-residual-15-family-fixture|extract-sigma|extractors|extractors-extra|",
  "plot-covariance-tables|plot-gllvmTMB|predict-se|tidy-predict|fitted-multi)$"
)

test_check("gllvmTMB", filter = if (full_suite) NULL else cran_sentinels)
