#!/bin/sh
set -u
for pattern in 'observation.scale|commensurab|sampling variation|resolves with replication|makes the recovery' 'fig.alt|eval *= *FALSE|structural translation|parity' 'Sigma_B|Sigma_W|Lambda_B|Lambda_W|latent\(|unique\(|indep\(|dep\(' 'phylo\(|gr\(|meta\(|block_V\(|phylo_rr\(|in prep|in preparation'; do
  printf 'PATTERN: %s\n' "$pattern"
  rg -n "$pattern" vignettes/articles/covariance-correlation.Rmd vignettes/articles/cross-family-correlations.Rmd vignettes/articles/spatial-models.Rmd R/extract-correlations.R man/extract_cross_correlations.Rd || test "$?" -eq 1
 done
