# The isdm branch now passes `R CMD check`

Closes the blocker measured in `docs/dev-log/2026-08-16-totoro-check-receipt-isdm-public-door.md`.

## Before and after (Totoro, same host, same flags)

| | before (`07c39634`) | after (`b9aec91d`) |
|---|---|---|
| Status | **1 ERROR**, 2 WARNINGs | **2 WARNINGs** |
| FAIL | 46 | **0** |
| PASS | 6733 | **6736** |
| SKIP | 1406 | 1430 |
| wall | 12 m 11 s | 13 m 25 s |

**Passes went up, not down.** That is the number worth looking at: a guard that
merely silenced the failures would have moved 46 into SKIP and left PASS flat. The
+3 is the compiled cloglog tail test, which had never once run under a checked
build and now does — see cause 2.

## Cause 1 — a directory conjured by another test's side effect

The first diagnosis was "`.Rbuildignore` excludes `^dev$`, so the runner scripts are
absent." True but incomplete, and the gap is why the obvious fix would not have
worked: `isdm_dev_path()` **already** guarded on the `dev/` directory existing, and
31 test files already used it.

What defeated it: several tests write preflight output to
`dev/isdm-package-recovery/results/`, and doing so **creates**
`dev/isdm-package-recovery` inside a checked build. Measured directly — the
`.Rcheck` tree contained that directory holding `results/` and nothing else. The
directory check then passed, and the reads that followed failed on individual
runner files.

The consequence worth naming: **skipping was order-dependent.** Whether a test
skipped depended on whether some earlier test had written there first. That is why
the failures looked scattered across unrelated files.

Fix: `isdm_dev_path()` now requires at least one developer *source* in the
directory, and the specific requested path when one is named. Twenty-two
`test_that` blocks that resolved `dev/` paths by hand with no guard now call it;
two call sites that resolved the directory and then joined filenames onto it now
resolve each file through the guard.

## Cause 2 — an off-by-one in a path written for the check environment

Separate and unrelated. `test-isdm-developer-fit.R` located the production cloglog
header with two candidates, the second being
`../../../00_pkg_src/gllvmTMB/src/gllvmTMB_cloglog.h`. From `tests/testthat`, a
checked build's sources are **two** levels up, not three. Verified on the real tree:

```
../../src/...                      -> No such file
../../../00_pkg_src/...            -> No such file      <- as written
../../00_pkg_src/gllvmTMB/src/...  -> EXISTS            <- correct
```

So the fallback written *for* the check environment never resolved there, and
`header_candidates[file.exists(header_candidates)][[1L]]` raised `subscript out of
bounds` on the empty subset.

This one was **fixed rather than skipped**, deliberately. The test guards the
cloglog tail behaviour — the `eta` cap at 700 and the series expansion below −20 —
which an adversarial review found load-bearing shortly before this work. A test
protecting a load-bearing numerical guard should run under check, not be skipped
past. It now does, which is the +3.

## What was not done

No assertion was deleted or weakened. In a source tree
(`devtools::test(filter = "g2|g3|bfgs|isdm|paper1")`) every guarded test still
**runs and passes**, with only the two pre-existing skips (G2o private evidence
roots; the opt-in heavy recovery test).

The 194 tests that now skip in a built package report
`dev/isdm-package-recovery is absent from the built package`. This matches the
convention already used for `dev/lv-wald-coverage.R` and `dev/vgh/vgh-engine.R`.

## The two remaining WARNINGs

`checking files in 'vignettes'` and `checking package vignettes` — both concern the
`vignettes/articles/` tree, which pkgdown builds as articles rather than installed
vignettes. Pre-existing, untouched here, and not a blocker for `main`.

## Standing caveat on the host

Totoro lacks `DHARMa`, `ggforce`, `galamm`, `mirt`, `nadiv`, `vegan`, `vdiffr`, so
the run used `_R_CHECK_FORCE_SUGGESTS_=false` and **every check needing one of those
did not run**, including all `vdiffr` visual snapshots. This is one Linux box, not
3-OS. A clean status here is necessary for `main`, not sufficient.
