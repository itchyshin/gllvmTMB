# After-task: MSPL cloglog y = 0 kink (#1020)

## Scope

`gll_mspl_bernoulli_loglik()` in `src/gllvmTMB.cpp`, cloglog branch only. The y = 0 term log(1 - p) = -exp(eta) was built from `eta_direct`, which is floored at log(1e-4) for the y = 1 direct branch. Below that floor a y = 0 row contributed a constant -1e-4 with zero gradient and curvature. At low prevalence the conditional modes of all-zero sites sit on that kink, the inner Newton solve stops on either side of it, and the penalty-off provenance tape could land on the other side from the primary tape. That is the O(1) decomposition residual reported in #1020. The y = 0 term now uses its own eta, capped only above at 690 where the existing tail takes over. This is the formula the ML cloglog path already uses.

Not touched: logit and probit MSPL kernels, the y = 1 cloglog branch, the eta > 690 tail and its counter, the R-side decomposition check and its tolerance, the ML path (`estimator_id == 0`), and defaults.

## Outcome

Both B1 campaign cells from the issue (B124 outer 1 and B048 outer 2) now return a fit whose decomposition residual is within tolerance, whose inner gradient is below 1e-6, and whose objective does not move when the inner solve restarts from zero. This is a likelihood change on an experimental estimator: cloglog MSPL estimates move wherever a y = 0 row has eta below log(1e-4). The issue measured the separation fixture in `test-mspl-api.R` moving from 34.522110 to 34.519592; that file still passes.

## Checks

See `docs/dev-log/check-log.d/2026-11-19-1020-mspl-cloglog-kink.md`. New test `tests/testthat/test-mspl-cloglog-kink-1020.R`: red before the fix (kernel slope block and both end-to-end fits), 16/16 after.

## Definition of done

1. Implementation: draft PR, awaiting CI and maintainer review (likelihood change, high-risk by the merge-authority rule).
2. Simulation recovery: not applicable. No new family, keyword or estimator. The issue records that the patched B124 fits are degenerate, so these cells are not recovery evidence.
3. Documentation: NEWS bullet. `docs/design/03-likelihoods.md` does not describe the MSPL cloglog stable kernel.
4. Runnable example: not applicable (internal kernel).
5. Check-log fragment: added.
6. Review: Gauss/Noether should confirm the y = 0 branch is now exactly -exp(eta) for eta <= 690 (the kernel test checks the gradient ratio to 1e-8 and the value difference to 1e-10).

## Follow-up

- The comment near the penalty-off tape in `R/fit-multi.R` saying ML keeps a "historical probability-clamp path" is stale per the issue; left untouched to keep this slice to `src/`.
- The issue's separately noticed ML `gll_log_cloglog_p` precision for y = 1 rows at -20 < eta < -12 is not addressed here.
