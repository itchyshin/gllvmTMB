## 1. Goal

Implement issue #1595 by routing the existing `optimizer` and `optArgs` controls through the R VA fitting route, preserving the omitted-control registry default, and giving users a switch to disable all secondary polish solvers.

## 2. Implemented

The control constructor preserves whether `optimizer` was omitted, so omission keeps the VA registry's existing `auto` choice while explicit `nlminb` selects nlminb. Explicit `optimizer = "optim"` supports BFGS and L-BFGS-B. Native controls are checked before objective construction and retain their existing nested `optArgs` structure. The selected primary solver runs for all four starts. `va_polish = TRUE` preserves the old secondary-solver policy; `FALSE` disables all secondary solvers. Attempt records contain requested and actual primary methods, polish and fallback attempts, native evaluation counts and stopping codes. Iteration counts unavailable from `stats::optim` are `NA`, not fabricated.

The change affects optimization routing and reporting only. It changes no likelihood, equation, parameterization, family, or formula grammar.

## 3a. Decisions and Rejected Alternatives

- The constructor records optimizer omission in private state. Merged controls otherwise cannot distinguish omission from explicit `nlminb`, and omission must preserve the registry default. A separate VA-only optimizer field was rejected because it would compete with the existing public control.
- BFGS remains opt-in because it has a dense-memory cost. Polish suppression is independent, so fixed-method comparisons can disable secondary stages while the default secondary stages remain familiar.
- `va_polish` defaults to `TRUE` to retain prior behavior, as specified in the issue plan. Four primary starts and the existing 3-of-4 agreement rule remain unchanged.

## 4. Files Touched

- `R/gllvmTMB.R` ; append `va_polish`, preserve explicit optimizer intent, validate VA controls, and document selection.
- `R/fit-multi.R` ; forward the existing controls into VA dispatch.
- `R/va-routing.R` ; resolve optimizer selection and validate method-native arguments.
- `R/approximation-engine.R` ; pass selected method and polish policy to the VA engine.
- `R/va-r3-proto.R` ; use selected native solver for four starts and report actual attempts and native diagnostics.
- `tests/testthat/test-va-optimizer-selection.R` ; test dispatch, forwarding, invalid controls, four starts, fixed seeded starts, and polish suppression.
- `man/gllvmTMBcontrol.Rd` ; generated help update.
- `NEWS.md` ; user-facing change note.
- `docs/dev-log/after-task/2026-10-18-issue-1595-va-optimizer-selection.md` ; updated task report included in this follow-up.

`docs/dev-log/check-log.md` was inspected but not edited: file preflight found foreign work across 263 refs. The lane-specific command/results ledger is `/tmp/cross-package-optimizers-20261018/gates/gllvmtmb.md`. The corrected report is included in the follow-up commit on PR #1599.

## 5. Checks Run

- `OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 Rscript --vanilla -e 'devtools::document()'` ; PASS; regenerated control Rd. Roxygen proposed unrelated formatting changes to three `NAMESPACE` sigma entries; those were restored, leaving `NAMESPACE` unchanged.
- `OPENBLAS_NUM_THREADS=1 Rscript -e 'devtools::test(filter = "va-optimizer-selection", stop_on_failure = TRUE)'` after the review fixes ; PASS, 52 expectations, 0 failures, 0 warnings, 0 skips. Raw output: `/tmp/cross-package-optimizers-20261018/gates/va-review-fixes-green2.log`.
- `OPENBLAS_NUM_THREADS=1 Rscript -e 'devtools::test(filter = "va-r3-prototype", stop_on_failure = TRUE)'` after the review fixes ; 643 pass, 2 fail, 0 warnings, 0 skips. Both failures are the seed-12 truncated-NB2 gate expecting four healthy starts and receiving three. Raw output: `/tmp/cross-package-optimizers-20261018/gates/va-review-fixes-neighbor2.log`.
- `OPENBLAS_NUM_THREADS=1 Rscript --vanilla -e 'devtools::test("/tmp/cross-package-optimizers-20261018/gllvm-baseline", filter = "va-r3-prototype", stop_on_failure = FALSE)'` on exact base `2020ef25a2854b254f681d5323863d47dddb66f9` ; same two seed-12 failures, 643 passes. Raw output: `/tmp/cross-package-optimizers-20261018/gates/va-review-fixes-exact-base.log`. No health threshold was weakened.
- `/tmp/cross-package-optimizers-20261018/gates/public-va-optimizer-proof.R` ; actual public fits on a fixed binomial-probit fixture (`n=120`, `p=4`, GH H=7), four starts, identical data and reset seed per optimizer, `va_polish=FALSE`. nlminb, BFGS and L-BFGS-B each returned four healthy starts. Per-start native counts and stopping codes are in `/tmp/cross-package-optimizers-20261018/gates/public-va-optimizer-proof.log`. This establishes execution and comparable objectives for this small fixture, not general optimizer superiority.
- `OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 Rscript --vanilla -e 'pkgdown::check_pkgdown()'` after adding the paired comparison example ; PASS, no problems found; pandoc emitted repeated `--mathml` deprecation notices. Raw output: `/tmp/cross-package-optimizers-20261018/gates/va-review-fixes-pkgdown.log`.
- `OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 Rscript --vanilla -e 'devtools::check(document = FALSE, args = "--no-manual")'` ; stopped at the 20-minute bound while testthat was compiling optional TMB targets. Build/install, static checks, documentation and examples passed before that phase. The full check remains INCOMPLETE. Retained files: `/private/var/folders/7x/ytfpq14s0v18frbm9v_w9f4c0000gq/T/Rtmp3ew3Mo/file1757c4bff4dd4/gllvmTMB.Rcheck/00check.log` and `/private/var/folders/7x/ytfpq14s0v18frbm9v_w9f4c0000gq/T/Rtmp3ew3Mo/file1757c4bff4dd4/gllvmTMB.Rcheck/tests/testthat.Rout`.
- `git diff --check` and `python3 ~/shinichi-brain/tools/agent_mention_check.py --text /tmp/cross-package-optimizers-20261018/gates/pr-body.md` ; PASS; no whitespace errors and no GitHub agent-mention violation.

## 6. Tests of the Tests

The initial review-fix regression run failed 9 assertions and passed 43 against the pre-fix source; raw red output is `/tmp/cross-package-optimizers-20261018/gates/va-review-fixes-red.log`. After the fixes, the focused selector suite passed 52 expectations. Spies observe actual `stats::optim(method=...)` execution rather than requested-method metadata alone, including when default fitting could converge. Tests exercise malformed scales and fractional counts, selected method forwarding to each of four starts, identical internal starting vectors after a seed reset, bounded polish, primary-versus-final solver metadata, and no secondary optimizer attempts when polish is disabled. A neighbor rerun first exposed a legacy vector request shape; the scalar guard fixed it. The final neighbor run matches the known exact-base seed-12 failures, with 643 passes and the same 2 failures.

## 7a. Issue Ledger

- **#1595** ; read live before PR creation; OPEN. This PR implements the R VA solver-selection, actual-method diagnostics, unsupported-control refusal, and fixed-start comparison criteria. PR #1599 references it. No issue comment or closure was made.
- **#1347** ; separate Julia bridge control work; explicitly outside this implementation. The R boundary refuses nondefault `va_polish` on non-VA routes, so this PR does not claim Julia optimizer-selection support.

## 8. Consistency Audit

- `rg -n 'optimizer_explicit|va_polish|\.va_route_optimizer_spec|actual_primary|primary_method' R tests/testthat/test-va-optimizer-selection.R man/gllvmTMBcontrol.Rd NEWS.md` ; constructor intent, resolver, actual-method records, tests, generated help and news use the same names.
- `rg -n 'va_polish' R tests/testthat/test-va-optimizer-selection.R man/gllvmTMBcontrol.Rd NEWS.md` ; default, VA gate, non-VA refusal, tests and documentation agree.
- `rg -n 'optimizer|optArgs' R/gllvmTMB.R R/fit-multi.R R/va-routing.R R/approximation-engine.R R/va-r3-proto.R tests/testthat/test-va-optimizer-selection.R` ; existing public selector is forwarded to each VA primary start and validated natively.
- `rg -n 'gllvmTMB\(' R vignettes README.md NEWS.md docs/design` ; no model-formula examples or call sites changed; this change adds control syntax only.
- Existing Laplace/AGHQ selector tests were included in the neighbor filter; the only failures were the two seed-12 health assertions also present on exact base.

## 9. What Did Not Go Smoothly

The first follow-up neighbor run exposed a vector-valued legacy `optimizer_request` and failed before completing its tests. The polish-control branch now applies optim-specific controls only for a scalar explicit BFGS or L-BFGS-B request; the final neighbor run completed and reproduced the two exact-base seed-12 health failures. The initial auto L-BFGS-B route also passed nlminb-specific `iter.max` and `eval.max` names into `optim`; the route now translates those limits into `maxit` while preserving supported controls. Full package check exceeded its time bound during compilation in the full test phase. The shared check-log path was left untouched because preflight showed extensive foreign branch work.

## 10. Known Residuals

- Full installed-package testthat and `devtools::check()` result are incomplete; only pre-test check phases passed.
- Public numerical comparison covers one small binomial-probit fixture. It does not recommend one optimizer or establish broad accuracy/performance claims.
- Dense BFGS can require substantial memory and remains opt-in.
- Julia VA optimizer selection remains tracked separately by #1347; no Julia implementation is claimed here.
- The existing 3-of-4 seed-12 neighboring health-gate failure remains unresolved and is identical on the exact base.

## 11. Team Learning

**Memory receipt:** Loaded the `gllvmTMB` LOAD-FIRST manifest with `python3 ~/shinichi-brain/tools/route.py gllvmTMB` and followed its instruction to diff assigned paths against `origin/main` and active lanes before editing. The lane preflight and ownership lease shaped the narrow scope; the 263-ref collision on `docs/dev-log/check-log.md` is why that shared file was not changed. No hub cross-repo guard or sibling-project discovery was used.

**Golden Set:** `tools/memory_regression.py` was not run; this task did not touch a known Golden Set failure class. No new durable package decision was made beyond the API contract recorded in this report.

**Learning:** Optimizer routing tests should observe the native method call and native diagnostics. Requested-method metadata alone cannot prove that the desired solver actually ran.

## 12. Cross-Product Coverage

| Surface | Coverage |
|---|---|
| R public VA route with omitted controls | ✓ existing family registry selection and default polish preserved |
| R public VA route with explicit nlminb, BFGS or L-BFGS-B | ✓ selected solver used for each of four starts; native controls validated |
| Secondary polish stage | ✓ default enabled; `va_polish = FALSE` disables all secondary solvers |
| Native Laplace and AGHQ routes | ✓ selector regression covered by neighbor tests; controls retain existing routing |
| Julia VA route | ✗ does NOT cover Julia optimizer selection; separate issue #1347 remains |
| EVA route | ✗ does NOT cover EVA optimizer selection or likelihood implementation |
| General optimizer quality or performance | ✗ does NOT cover broad optimizer ranking; only one bounded fixture was fitted |
