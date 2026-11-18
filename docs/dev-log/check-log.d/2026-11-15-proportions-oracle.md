# Check log: proportion interval arithmetic

The old test required Wald and percentile-bootstrap bounds to agree within 0.1 on a fixture whose final Bernoulli draw was not actually seeded. With the fixture's existing seed applied to the whole data generation, the maximum gap was 0.3094 with 50 finite refits; an independent 200-refit batch gave 0.2444. With the maintainer's approval, the test now checks reproducibility, delta-method arithmetic and percentile bookkeeping while retaining the gap as a descriptive result. It no longer asserts the 0.1 closeness claim and does not establish coverage.

The test preserves the original schema, point, method and bound checks. It records all replicate positions and failures, including trailing missing results, and saves partial outcomes if the bootstrap aborts. Independent review checked the arithmetic, parameter and trait alignment, random-state restoration and synthetic controls. Finite returned refits do not establish their individual Hessian health.

The focused heavy test file ran on Totoro using base `abf3e905fb9e22f5eca9b8dd01c9ea476fde4ee2` with the modified test substituted, one numerical thread and a 15-minute cap. It reported 76 passes, zero failures, errors, warnings or skips; all 50 refits returned finite values for each trait. The test SHA-256 was `6adbac2759f4eadbd0476dc8c11f403a9da7f9b747ac022b14859d9e854a918e` before and after, and the log SHA-256 was `f9184eee708bedd066c1ad38847219729192b613ef30b92ef23f885659233d65`. Full integrated-source and release checks remain open.

From `/home/snakagaw/proportions-oracle-integration-20261115/source`, the command was:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 MAKEFLAGS=-j1 R_LIBS_USER=/home/snakagaw/R/lib GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true GLLVMTMB_PROPORTIONS_EVIDENCE_DIR=/home/snakagaw/proportions-oracle-integration-20261115 timeout --kill-after=10s 900s Rscript --vanilla ../run-candidate.R > ../candidate.log 2>&1
```

The retained harness `run-candidate.R` has SHA-256 `ec41a7737b395d9543ec832d16822ee87033c1d1dc1039bd6516d3659430e318`; it loads the package, runs `testthat::test_file()` and reports every pass, failure, error, skip and warning.
