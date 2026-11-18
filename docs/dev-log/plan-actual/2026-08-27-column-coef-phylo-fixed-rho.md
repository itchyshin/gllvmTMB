# Plan versus actual — fixed-rho phylogenetic coefficient engine

## Planned

Begin from merged IID main, wait for the overlapping LV lane, rebase once,
claim only declared paths, implement a private Gaussian fixed-rho
`phylo_coef()` engine, prove exact `rho = 1` identity to `phylo_slope()`, and
close through review, three-OS CI, normal merge, and exact-main verification.

## Actual

- The lane waited for PR #1218 and resumed from exact verified main
  `0d442ce7b0ab0b5901ccbde08426f9d9c4923287` after its explicit release.
- The plan branch rebased exactly once; no LV work was imported or reverted.
- The implementation remained R-side and private. It added no TMB parameter,
  export, Rd topic, article, or lifecycle change.
- `rho = 1` no-intercept calls hard-dispatch to the released slope route.
  Interior rho uses `K_rho = rho K + (1 - rho) diag(K)` and validates the
  source covariance before inversion.
- Dense-VCV no-intercept `rho = 1` inherits released `phylo_slope()`
  conditioning `K + 1e-8 I`; raw interior mixtures have no ridge. Exact review
  added an explicit endpoint oracle and pre-dispatch source validation.
- Focused, endpoint-identity, internal-boundary, deterministic recovery, and
  slope/IID regression gates passed. Fresh full package/pkgdown and local
  `R CMD check` passed, and amended-source Gauss/Noether, Rose, and Grace
  reviews passed. Unlazy is 8/9 met; CI, merge, and exact-main G9 remains to be
  appended at terminal closure.

## Variance from plan

The branch name retained its `-plan` suffix after the one authorized rebase;
this changes no scope. The source validator was strengthened during local
review to reject an indefinite supplied covariance even when its mixed
`K_rho` happened to be positive definite. No public article work was pulled
forward. The existing `phylogenetic-gllvm` article remains untouched by the
maintainer's explicit choice.

Exact-candidate review also found that augmented sparse inputs needed full
finite, symmetry, and positive-definiteness validation before inversion. That
guard and its malformed augmented-node tests were added within the declared
source-validation scope.

## Deferred unchanged

Estimated rho; public exports and extractors; long/wide article teaching;
animal, kernel, and spatial coefficient engines; intervals; non-Gaussian
regimes; and any `*_slope()` deprecation remain outside this slice.
