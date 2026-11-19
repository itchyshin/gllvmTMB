# Check-log: merge main and the bare-abort next step (#1782, PR #1785)

**Goal:** Bring `cursor/fix-1782-predict-missing-unit-382a` up to `origin/main` (`e2450b05`) and clear the shard 3 failure on the last CI of head `80ee4ae2` (runs 43940646454 and 43940646321).

**Commands:**

```sh
gh run view 43940646454 --repo itchyshin/gllvmTMB --log-failed
gh run view 43940646321 --repo itchyshin/gllvmTMB --log-failed
git merge origin/main
Rscript --vanilla -e 'source("dev/gapclose/count-bare-aborts.R"); cat(length(count_bare_aborts("R")), "\n")'
# NOT_CRAN=true, installed package in /tmp/r-lib
Rscript --vanilla /tmp/run-focused-tests.R
# shard 3 file list at 80ee4ae2 (radix, 197 files), then the four files that
# failed only because test_file(package=) does not attach the package:
# test-examples-run-1346a.R, test-examples-run-1346e.R,
# test-issue-1360-rd-examples-self-contained.R, test-isdm-diagnostic-receipts.R
```

**Results:** Both failed jobs stop on `test-gapclose-next-steps.R:238`: `length(hits)` was 771, ceiling 770. The only hit present on this branch and absent on `origin/main` is the new unit-column `cli_abort` in `R/methods-gllvmTMB.R`. Its `"i"` bullet is not a next step under `dev/gapclose/count-bare-aborts.R`. Changing that bullet to `">"` leaves the words the same and returns the count to 770, equal to main. The species-column abort from #1787 stays as it is on main.

`test-1782-predict-missing-unit.R`: FAIL 0 / PASS 6. `test-1787-predict-missing-species.R`: FAIL 0 / PASS 7. `test-gapclose-next-steps.R` with `NOT_CRAN=true`: FAIL 0 / PASS 33. After `tidyr` and `ggplot2` were installed, `test-predict-wide-newdata-error.R` FAIL 0 / PASS 3 and `test-predictive-diagnostics.R` FAIL 0 / PASS 158.

The CI shard 3 file list (197 files at `80ee4ae2`): first local pass FAIL 47 / ERROR 1 / WARN 14 / SKIP 204 / PASS 7261. Those 48 results were `could not find function "simulate_unit_trait"` (and the same for other exported helpers) because `test_file(package = "gllvmTMB")` loads the namespace and does not attach it. `tests/testthat.R` calls `library(gllvmTMB)` before `test_check()`. Re-run of those four files after `library(gllvmTMB)`: FAIL 0 / PASS 120, 40, 31, and 20.

**Not run:** full `R CMD check`, `pkgdown::check_pkgdown()`, and the other three shards. `GLLVMTMB_HEAVY_TESTS` was left unset, so heavy recovery tests stayed skipped.

**Claim boundary:** The missing-unit stop is unchanged in behaviour. The bullet name is what the bare-abort ratchet reads. No tolerance, cap, timeout, or API default moved. No validation-debt row changes.
