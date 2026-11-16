# Two-kernel separation guard, 15 November 2026

The guard now checks each declared trait against source-aligned, symmetrized kernels after the species-level ridge. A masked trait or a rank-deficient same-trait kernel pattern stops with an error. The prior error class for an actually empty factor level remains intact.

The red controls are retained in `/tmp/two-kernel-fully-masked-red.log`, `/tmp/two-kernel-ridge-red.log` and `/tmp/two-kernel-symmetry-red.log`. The earlier staged-build guard file passed 94 assertions and the empty-factor test passed seven. On the repinned build under `/tmp/gllvmtmb-separation-repin.7675k0/`, the same guard file passed 94 assertions; five fixed-point likelihood and gradient comparisons passed; and the independent fitted-object covariance and dense-likelihood audit passed. The library hash and source manifest are in that directory. The fit reached the uniqueness boundary and is not recovery evidence.

Commands and output are retained in `/tmp/gllvmtmb-separation-repin.7675k0/`. The source directory was `/tmp/gllvmtmb-separation-repin.7675k0/source` and the library was `/tmp/gllvmtmb-separation-repin.7675k0/lib`. The oracle commands were `Rscript --vanilla dev/two-kernel-gaussian/check-oracle.R` and `TWO_KERNEL_STAGED_LIBRARY=/tmp/gllvmtmb-separation-repin.7675k0/lib Rscript --vanilla dev/two-kernel-gaussian/run-native.R`. The saved-fit audit was `Rscript --vanilla /tmp/gllvmtmb-separation-repin.7675k0/independent-extraction.R`. The installed guard was run through `testthat::test_file()` with an environment inheriting from the installed package namespace; its invocation and output are recorded in the task transcript and `guard-retry.log`. Numerical-library threads were set to one. The installation completed, but its shell wrapper then failed by assigning zsh's reserved `status` variable; a first guard-test invocation failed because the library environment variable was unset. Both failures and the passing retry remain in the evidence directory.

The full Linux package check and the multi-PR scratch tests are running. Windows, three-OS CI, interval calibration and final-source recovery were not run. The existing optimizer restart accounting defect is recorded in the after-task report and was reported to the coevolution chat.

The targeted scratch-union tests finished with 1,410 passes, no reported failures, errors, warnings or skips, and matching pre/post source identities. Full command and receipts: `/home/snakagaw/hsq_work/two-kernel-separation-union.SRGM95/`. This is a scratch compatibility result, not a full package check or evidence of recovery.

Exact installed-guard invocation from the staged source directory:

```sh
TASK_LIB=/tmp/gllvmtmb-separation-repin.7675k0/lib OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 NOT_CRAN=true Rscript --vanilla -e 'lib <- Sys.getenv("TASK_LIB"); library(gllvmTMB, lib.loc=lib); stopifnot(normalizePath(find.package("gllvmTMB")) == normalizePath(file.path(lib,"gllvmTMB"))); z <- testthat::test_file("tests/testthat/test-coevolution-known-fixed-error.R", env=new.env(parent=asNamespace("gllvmTMB")), reporter="summary"); a <- as.data.frame(z); print(colSums(a[c("passed","failed","error","warning","skipped")])); if(any(a$failed>0|a$error|a$warning>0|a$skipped>0)) quit(status=1); cat("INSTALLED_GUARD_PASS\n")'
```
