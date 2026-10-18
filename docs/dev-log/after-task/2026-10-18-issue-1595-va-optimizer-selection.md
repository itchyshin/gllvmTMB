# After Task: VA optimizer selection (issue #1595)

**Branch**: `codex/optimizer-selection-20261018`
**Date**: 2026-10-18
**Roles (engaged)**: none; implementation completed in assigned lane, independent review pending.

## 1. Goal

Honor the existing `optimizer` and `optArgs` controls on the variational approximation (VA) route while retaining the omitted-control auto route and legacy polish behavior. Add an explicit switch to disable all secondary polish solvers.

## 2. Implemented

The VA route now distinguishes omitted optimizer from explicit `nlminb`, supports explicitly selected `optim` BFGS and L-BFGS-B methods with native nested controls, and rejects unsupported selections or malformed controls before objective construction. The selected primary optimizer is used for all four starts. `va_polish = FALSE` disables every secondary solver; its default `TRUE` preserves existing behavior. Attempt records report the requested and actual primary methods, polish attempts, native evaluation counts and stopping codes; `optim` iteration counts are unavailable and recorded as `NA`.

## 3. Mathematical Contract

No likelihood, equation, parameterization, formula grammar, or family changed. This change concerns VA optimization routing and reporting only.

## 3a. Decisions and Rejected Alternatives

Decision: represent omission using a private constructor attribute so explicit `optimizer = "nlminb"` is distinguishable from omitted controls after control merging. Rationale: omission must preserve the existing registry auto route. Rejected alternative: a second public VA-only optimizer field, which would compete with the existing `optimizer` API. Confidence: high for the exercised R VA route; Julia admission remains a separately fenced limitation.

## 3b. Files Changed

- `R/gllvmTMB.R`
- `R/fit-multi.R`
- `R/va-routing.R`
- `R/approximation-engine.R`
- `R/va-r3-proto.R`
- `tests/testthat/test-va-optimizer-selection.R`
- `NEWS.md`
- `man/gllvmTMBcontrol.Rd` (generated)
- `docs/dev-log/after-task/2026-10-18-issue-1595-va-optimizer-selection.md`

`docs/dev-log/check-log.md` was not modified because the route/file preflight showed extensive foreign branch work on that path. The lane-specific acceptance ledger is `/tmp/cross-package-optimizers-20261018/gates/gllvmtmb.md`.

## 4. Checks Run

- `OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 Rscript --vanilla -e 'devtools::test(filter = "va-optimizer-selection", stop_on_failure = TRUE)'`: 41 passed, 0 failed, 0 warnings, 0 skipped after final documentation regeneration.
- `OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 Rscript --vanilla -e 'devtools::test(filter = "va-control-exposure|va-r3-prototype|va-routing-oracle", stop_on_failure = TRUE)'`: 713 passed, 2 failed, 0 warnings, 0 skipped. Both failures are the seed-12 truncated-NB2 health gate expecting four healthy starts but observing three.
- Exact base comparison at `2020ef25a2854b254f681d5323863d47dddb66f9`, same focused `va-r3-prototype` test, and the same R/library environment: 643 passed, the same two seed-12 assertions failed (3 healthy starts rather than 4), 0 warnings. This is a pre-existing neighboring failure; no health criterion was weakened.
- Public seeded binomial-probit VA fits (`n=120`, `p=4`, GH H=7, four starts, `va_polish=FALSE`, same seed/data per method) completed with all four starts healthy under nlminb, BFGS and L-BFGS-B. Per-method objectives agreed within each method's existing four-start agreement gate. Actual methods, native counts, convergence codes, and outputs are retained in `/tmp/cross-package-optimizers-20261018/gates/public-va-optimizer-proof.log`; `optim` iterations are NA because native `optim` does not report them.
- `OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 Rscript --vanilla -e 'devtools::document()'`: PASS; regenerated `man/gllvmTMBcontrol.Rd`. An unrelated Roxygen version formatting change to three `NAMESPACE` sigma entries was restored, leaving NAMESPACE unchanged.
- `OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: PASS, no problems found (pandoc emitted repeated `--mathml` deprecation warnings).
- `OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 Rscript --vanilla -e 'devtools::check(document = FALSE, args = "--no-manual")'`: stopped at the 20-minute lane bound during testthat; build/install, static checks, Rd validation and examples passed, but testthat was still recompiling optional TMB targets. Full package check is incomplete, not a pass. Check log: `/private/var/folders/7x/ytfpq14s0v18frbm9v_w9f4c0000gq/T/Rtmp3ew3Mo/file1757c4bff4dd4/gllvmTMB.Rcheck/00check.log`; test output: `/private/var/folders/7x/ytfpq14s0v18frbm9v_w9f4c0000gq/T/Rtmp3ew3Mo/file1757c4bff4dd4/gllvmTMB.Rcheck/tests/testthat.Rout`.

Primary retained evidence: selector red baseline `/tmp/cross-package-optimizers-20261018/gates/` (red output retained in the orchestrator's session transcript); fixed-seed public fits `/tmp/cross-package-optimizers-20261018/gates/public-va-optimizer-proof.R` and `public-va-optimizer-proof.log`; adjacent current and exact-base comparison outputs are retained in the lane run transcript; route matrix and command ledger `/tmp/cross-package-optimizers-20261018/gates/gllvmtmb.md`; pkgdown output in the check session transcript.

## 5. Tests of the Tests

The corrected selector test was run before implementation and failed on the absent constructor intent state, route resolver, native dispatch, validation refusals, and control forwarding. Direct spies observe actual `stats::optim(method=...)` calls even when a default optimizer would converge. Tests also cover malformed inputs, method/control mismatches, all four starts, no-polish behavior, and identical internal starts under a reset seed.

## 6. Consistency Audit

- `rg -n 'optimizer_explicit|va_polish|\.va_route_optimizer_spec|actual_primary|primary_method' R tests/testthat/test-va-optimizer-selection.R man/gllvmTMBcontrol.Rd NEWS.md` — confirmed the constructor marker, route validation, actual method records, tests, help page, and release note use the same control names.
- `rg -n 'va_polish' R tests/testthat/test-va-optimizer-selection.R man/gllvmTMBcontrol.Rd NEWS.md` — confirmed the default, VA polish gate, non-VA refusal for nondefault use, tests, and generated help are aligned.
- `rg -n 'gllvmTMB\(' R vignettes README.md NEWS.md docs/design` — no formula or long-format call examples changed; this control-only change adds no new call sites requiring trait syntax review.
- `rg -n 'optimizer|optArgs' R/gllvmTMB.R R/fit-multi.R R/va-routing.R R/approximation-engine.R R/va-r3-proto.R tests/testthat/test-va-optimizer-selection.R` — confirmed the existing public selector is forwarded through the VA route and each primary start.

## 7. Roadmap Tick

N/A; no roadmap row changed.

## 7a. GitHub Issue Ledger

Issue #1595 is the implementation target and remains open. Its live description was read with `gh issue view 1595 --repo itchyshin/gllvmTMB --json number,title,state,body,url`; it requests direct VA solver selection, honest solver records, an actual-call test, and a fixed-start comparison. Issue #1347 concerns the separate Julia bridge and remains outside this change. No comments or closures were made.

## 8. What Did Not Go Smoothly

The first default L-BFGS-B run exposed warnings because nlminb control names were passed through unchanged. The auto-route translation now maps its legacy iteration/evaluation caps to `maxit` and preserves the remaining supported controls. The adjacent seed-12 test has the same 3-of-4 result at base and on this branch, so it remains recorded as an unrelated failure rather than changing its gate.

## 9. Team Learning

No standing reviewer role engaged. The useful process observation is that an optimizer selector needs tests that observe the native solver call, not only the requested-method metadata; the four-start seeded spy test now guards this behavior.

## 10. Known Limitations And Next Actions

The public fit proof covers one small binomial-probit fixture and establishes method execution and comparable objectives, not broad optimizer performance or recommendation. Dense BFGS has a memory cost and remains opt-in. Julia does not yet implement VA optimizer selection; unsupported nondefault `va_polish` is refused at the public boundary. The full package check is incomplete because testthat was still compiling TMB targets at the 20-minute limit. Selector/neighbour tests, exact base comparison, documentation generation and pkgdown validation provide focused review evidence. Merge remains outside this lane.
