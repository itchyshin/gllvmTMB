# Handover — internal fixed-rho phylogenetic coefficient engine

**Date:** 2026-08-27
**Branch:** `codex/phylo-coef-fixed-rho-plan`
**Verified base:** `0d442ce7b0ab0b5901ccbde08426f9d9c4923287`
**Lane:** `codex:phylo-coef-fixed-rho`

## Goal and boundary

The slice adds a private Gaussian fixed-rho `phylo_coef()` engine with

```text
K_rho = rho K + (1 - rho) diag(K).
```

It does not export or teach `phylo_coef()`, estimate rho, change C++, or alter
the current warning-free, non-deprecated `*_slope()` family.

For exact legacy identity, dense-VCV no-intercept `rho = 1` inherits the
released slope route's `K + 1e-8 I` conditioning. Interior rho and
intercept-bearing `rho = 1` use raw `K_rho` without a ridge. Do not claim
endpoint continuity before the public-interface decision resolves this seam.

## Current evidence

- Focused fixed-rho gate: 99 expectations, PASS without warnings.
- Exact `rho = 1` tree/dense and `|`/`||` identity verifier: PASS.
- Deterministic fixed-rho recovery verifier: PASS.
- Internal-boundary verifier: PASS.
- IID/slope/fixed-rho regression filter: 306 expectations, zero failures; two
  declared heavy skips and 17 pre-existing neighbouring fixture warnings.
- Design 131 and FG-20 now state the internal fixed-rho boundary.
- Fresh full package gate: 17,811 passes, 52 existing warnings, 879 declared
  skips, zero failures; `pkgdown::check_pkgdown()` found no problems.
- Local `R CMD check`: PASS in 19m43.9s, 0 errors, 0 warnings, 3 unchanged
  notes.
- Gauss/Noether, Rose, and Grace amended-source reviews: PASS.
- Unlazy reports 8/9 met; only protected exact-head CI/merge/exact-main G9
  remains pending.

## Next safe actions

1. Run the closeout contract, full local package test, pkgdown check, whitespace
   check, and required stale-wording/status scans.
2. Freeze an exact candidate and obtain Gauss/Noether, Rose, and Grace verdicts;
   fix only attributable findings and re-run affected gates.
3. Run final Unlazy reverify.
4. Push once with CI pacing, open one narrow PR, and retain routine plus manual
   Ubuntu/macOS/Windows evidence on the exact reviewed head.
5. Merge normally without bypass, verify exact-main R-CMD-check, release the
   lane, and begin a fresh estimated-rho/public-interface Ultra Plan.

## Protected boundaries

Do not edit `where-does-the-tree-go`, `api-keyword-grid`, or
`phylogenetic-gllvm` in this slice. Do not add warnings or lifecycle markup to
any `*_slope()` helper. Do not implement animal, kernel, or spatial coefficient
engines. Preserve all unrelated lanes.

FINDINGS-OF-RECORD: the dense-VCV no-intercept `rho = 1` endpoint inherits
`K + 1e-8 I`; public endpoint continuity remains unresolved. No other finding
extends beyond the internal fixed-rho Gaussian point route.

CARRIED-OVER: estimated rho, public long/wide `column_coef()` and
`phylo_coef()`, extractor/API documentation, the approved article cascade, and
final public release gates.
