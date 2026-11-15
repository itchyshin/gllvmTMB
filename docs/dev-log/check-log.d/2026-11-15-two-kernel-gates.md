# Check log: fixed-rho likelihood grid

The old seeded test required the planted and best positive rho fits to exceed the block-null fit by more than 100 log-likelihood units. Independent runs found that the old single-start null landed at a much worse local optimum. With three starts the planted and best gains are about 1.07 and 1.68; the test now retains their positive direction for this fixture without requiring the unsupported magnitude.

The test reconstructs the cross kernel and dense Gaussian marginal likelihood, checks a feasible null point and evaluates two wrong-rho formula controls. Dense versus package likelihood differences were below 1.24e-7 in the independent diagnostic. Parameters, design and the nuisance kernel remain shared inputs. This checks likelihood arithmetic and one optimization floor, not global optimality, general detection power or interval coverage.

On Totoro the focused target was run on base `abf3e905fb9e22f5eca9b8dd01c9ea476fde4ee2` with the test file substituted, `GLLVMTMB_HEAVY_TESTS=1`, `NOT_CRAN=true` and one BLAS/OpenMP thread. `Rscript --vanilla -` loaded the package, evaluated the `.c3_` helpers and ran the test named `fixed-rho sensitivity grid agrees with a dense likelihood`. It passed 36 expectations with no warnings or skips. The test SHA-256 was `bf539269bbc2b4da3173f42b91b45cab3674b63f1e0af7df289dafb8c75e67c8` before and after; the retained log SHA-256 is `9c23e29f930c22d8bd0a9f4250d0cad4c9d13bcc8cdc7df4b1186d21ffb1ec33`. Full-file and integrated-source checks remain open; two other failing gates in this file are unchanged.

The Rscript stdin was:

```r
library(testthat)
pkgload::load_all('.', quiet = TRUE)
source('tests/testthat/setup.R')
expr <- parse('tests/testthat/test-coevolution-two-kernel.R')
for (e in expr) if (is.call(e) && identical(e[[1]], as.name('<-')) && is.symbol(e[[2]]) && startsWith(as.character(e[[2]]), '.c3_')) eval(e, globalenv())
found <- FALSE
for (e in expr) if (is.call(e) && identical(e[[1]], as.name('test_that')) && identical(as.character(e[[2]]), 'fixed-rho sensitivity grid agrees with a dense likelihood')) { found <- TRUE; eval(e, globalenv()) }
stopifnot(found)
cat('FIXED_RHO_TARGET_COMPLETE\n')
```

## Null-grid numerical comparison

The previous null-grid check also required every phylogenetic Gamma norm to be below 0.0002. A 12-seed independent dense optimizer reproduced the better fitted result above that bound for seed 2302. With the maintainer's approval, the test now compares the package's objectives and public Gamma matrices against that independent optimizer for all 12 seeds and six deterministic starts per seed. It retains the other null and overfit gates, reports the historical bound failures, and no longer claims that every null estimate falls below 0.0002. The comparison is not a calibration, power or global-optimality guarantee.

The final targeted Totoro run used base `e39e29f0527ea0a472f7a6a6881cd359e0d6a96c` with the changed test file substituted. It passed 630 expectations with no warnings or skips; all 72 starts returned code zero. The test file SHA-256 before and after was `0e84440b03730e914b270bcaec2b9d1f5cb90b7679db8d87d68473c52edb6add`; the retained log SHA-256 is `33b027c3ec856a06eeedd7c2875d81372b482d0a7002f90d7e99a585ba654194`. The high-overlap test and full integrated-source checks remain open.
