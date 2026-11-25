# After Task: Keep a loaded VA template when a test asks to rebuild it

**Branch**: `cursor/fix-1803-ci-va-dll-bd4e`
**Date**: 2026-11-17
**Roles (engaged)**: Grace, Curie

## 1. Goal

PR #1803 failed Ubuntu shard 2 of R-CMD-check run 44015758495 and coverage run 44015758237. The process died in one test. This slice makes that reload safe and keeps the oracle comparison.

## 2. Implemented

`.va_r3_load_dll()` no longer calls `dyn.unload()` on `gllvmTMB_va_r3`. When that DLL is already loaded from the source-checksum build, `rebuild = TRUE` returns the loaded library. When the name is loaded from a different build, the loader stops and names the restart, because two copies cannot share the DLL name. When the DLL is absent, `rebuild = TRUE` still compiles and loads it.

`tests/testthat/test-va-all-family-compiled.R` still compares all 18 scalar cells with the same tolerances. The first cell no longer passes `rebuild = TRUE`. A new test builds one objective, asks for a rebuild, and checks that the same objective still returns its previous value.

## 3. Files Changed

- `R/va-r3-proto.R`
- `tests/testthat/test-va-all-family-compiled.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-11-17-fix-1803-va-dll-unload.md`

No README, NEWS, ROADMAP, vignette, design-doc, or `man/*.Rd` change. The likelihood and the formula grammar are unchanged.

## 3a. Decisions and Rejected Alternatives

Decision: stop unloading a live VA DLL, and stop the oracle test from requesting that unload.

Rationale: TMB's unload hook frees ADFun external pointers that earlier tests in the same process still hold. The next `MakeADFunObject` then segfaults. The build directory is already the source MD5, so a loaded copy is the current template.

Rejected alternative: only delete `rebuild = TRUE` from this one test. Earlier commits on #1803 did that for other files, and the crash moved to the next caller. `test-loading-unpack-contract.R` and `test-va-mixed-family.R` still pass `rebuild = TRUE`.

Confidence: high on the failing stack. The local file run is recorded in section 4.

## 4. Checks Run

On R 4.6.2, the same version as the failing runner:

`R_LIBS_USER=$HOME/R/lib46 NOT_CRAN=true OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla -e 'res <- testthat::test_file("tests/testthat/test-va-all-family-compiled.R", reporter="summary", load_package="source")'`

Result: `FAILED 0 PASSED 112 SKIPPED 0`, exit 0. The VA template compiled once. No segmentation fault.

`rg -n "dyn\\.unload" R/va-r3-proto.R` returned no match. `rg -n "rebuild = first" tests/testthat/test-va-all-family-compiled.R` returned no match.

## 5. Tests of the Tests

The new test calls `obj$fn()` before and after `.va_r3_load_dll(rebuild = TRUE)`. The old unload path frees the external pointer that `fn()` uses, so this assertion fails closed (the process dies) if the unload returns. The 18-cell tolerances are the same numbers as before.

## 6. Consistency Audit

`rg -n "dyn\\.unload" R/va-r3-proto.R` — no match.

`rg -n "rebuild = first" tests/testthat/test-va-all-family-compiled.R` — no match.

## 7. Roadmap Tick

N/A. No roadmap row changes.

## 7a. GitHub Issue Ledger

Inspected PR #1803 and the failing runs 44015758495 and 44015758237. No issue opened or closed. The draft PR says `refs #1803` only.

## 8. Mathematical Contract

No public API, likelihood, grammar, or family change. The VA oracle still compares the compiled scalar expectation with the independent arithmetic expectation at the existing tolerances.

## 9. What did not go smoothly

`KNOWN_ERROR_OBJECTIVE` in the shard log is a `cat()` from `test-coevolution-known-fixed-error.R`. The `standard_errors()` line is a fit message from another test in the same Rout file. The traceback names the VA oracle test.

Adding that coevolution file shifted later test indexes by one. `test-va-all-family-compiled.R` moved from main's shard 1 to this branch's shard 2, where `test-fix-1365-free-p.R` had already loaded `gllvmTMB_va_r3`. Main run 43984220547 at `fc80be9ee232692a64dfef7f8570ce7a1528b861` passed all four shards, including a VA reload that printed "external pointers will be removed". The crash shows up in the shifted shard, where that reload follows a live objective.

## 10. Team learning

Grace: shard membership is `(index %% 4)`. One new test file moves every later file into the next shard, so a DLL-lifetime bug can fail a test the diff did not edit.

Curie: `rebuild = TRUE` is not an assertion. The assertion is the objective value after that call.

## 11. Design-doc updates

None. The loader's contract is the comment in `R/va-r3-proto.R`.

## 12. pkgdown / documentation updates

None.

## 13. Known limitations and next actions

The EVA loader in `R/eva-proto.R` still unloads a loaded DLL. This run's stack is the VA loader. `test-eva-gate1.R` still passes `rebuild = TRUE`. A later file-order shift can put that call after a live EVA objective.

The local file run used R 4.6.2. It is one file, not the full shard 2 process. The draft PR still needs the exact-head shard 2 check.

G5 increasing-sample-size recovery and G6 interval calibration for the two-kernel route stay unvalidated. This slice does not change that evidence.
