# check-log: temporal marker names in gllvmTMB() gates and predict(newdata=)

**Branch:** `cursor/1126fx-1922`  
**Refs:** #1921 (message), #1922

## rg (before)

```text
R/gllvmTMB.R:1491 temporal_latent.*Gaussian identity-link
R/methods-gllvmTMB.R:3506 temporal_latent.*predict.*newdata
```

## Change

`temporal_fn <- paste0("temporal_", mode)` in `gllvmTMB()` admission gates and `predict.gllvmTMB_multi()` newdata refusal; behaviour unchanged.

## Tests (intended)

```r
devtools::load_all()
testthat::test_file("tests/testthat/test-temporal-marker-name-refusals.R")
testthat::test_file("tests/testthat/test-predict-simulate-refusal-classes.R", filter = "temporal")
```

Cloud VM had no `Rscript` at commit time; CI expected to run full `R-CMD-check`.

## Deliberately not run

`devtools::check()`, campaign suites, `recertify-c17.py`.