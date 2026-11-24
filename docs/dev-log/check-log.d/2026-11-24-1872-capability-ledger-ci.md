# Check-log: PR #1872 capability-ledger CI correction

**Goal:** Fix the validation-ledger mapping regression reported by PR #1872's Ubuntu test shards.

**Commands:**

    Rscript --vanilla dev/gapclose/build-capability-status.R
    Rscript --vanilla dev/gapclose/build-capability-status.R --check
    Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-gapclose-parity-ledger.R")'
    OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla -e 'devtools::test(filter = "paired-exact-marginal-gaussian|gapclose-parity-ledger", reporter = "summary")'
    git diff --check

**Results:** The generator wrote the 82-row summary (255 mapped rows, 38 intentionally unmapped, 0 unmapped); its `--check` exited 0 with 0 unmapped register rows. The focused ledger test exited 0 with 32 passes, 0 failures, 0 warnings, and 0 skips. The combined exact-zero plus ledger test command completed successfully with exit 0. `git diff --check` passed.

**Not run:** Full GitHub Actions rerun, the three-OS manual matrix, and merge are pending this correction being pushed and the current-head checks settling. No simulation, recovery, interval, or fit campaign was run. Stale-wording scans were not run because this internal R-vs-Julia capability mapping correction adds no reader-facing prose.

**Claim boundary:** These checks fix the register-to-ledger accounting and verify the focused exact-zero test file locally. They do not establish full package CI, three-OS support, scientific recovery, or interval calibration.
