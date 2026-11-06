# AGHQ summary check log, 2026-11-05

Local candidate: fixed-prior feature branch plus AGHQ conditional-prediction and summary repairs. Clean archive SHA-256 `09aed9069d8a8ab290866f4bc184d3c5d2701160f8779bf1333ea1833c0abd25`.

- `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet=TRUE,compile=FALSE); testthat::test_file("tests/testthat/test-aghq-summary-predictions.R",stop_on_failure=TRUE)'`: 19 passes, no warnings. The two primary assertions and legacy-edge assertions were first shown to fail without their fixes.
- Affected AGHQ, diagnostic, link-residual and warning test files passed together; see the after-task report for the file list and scope. A disposable combination with PRs #1715 and #1692 passed their affected test files with six heavy tests skipped. PR #1734's two changed test files passed in a separate disposable combination.
- `R CMD check --no-manual --ignore-vignettes gllvmTMB_0.8.0.9000.tar.gz` with `NOT_CRAN=true` and one BLAS/OpenMP thread: 29,714 passes, seven failures, 64 warnings and 1,279 skips; 1 ERROR and 2 NOTEs. The failure locations match the previous candidate. The four non-visual assertions also failed on exact main `58c46f8ec01e7e3070d9eea6817c89153d7dbf8a`; the three visual tests explicitly skip on CI. A CI result is not implied by the local run.
- `rg -n '\\$report\\$eta' R`: identified the raw predictor consumers and the two summary paths repaired here. `rg -n 'fid ==|fid %in%|eta\\[' R/extract-sigma.R`: reviewed the eight eta-dependent family branches.
- Not run: cross-platform CI, AGHQ interval calibration, heavy recovery tests in the other lanes, or a merge. The separately owned AGHQ extractor PR remains open.
