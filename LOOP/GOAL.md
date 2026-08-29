# GOAL — admit dense-kernel response-column coefficients

**IMMUTABLE for this lane.** Re-read this file before every arc.

## Deliverable

Implement, document, verify, and normally merge public Gaussian point-model
`kernel_coef()` support in long and `traits(...)` wide formats, building on the
current warning-free `kernel_slope()` endpoint and admitted coefficient engine.

## Definition of done

- `kernel_coef(formula, K, name = "kernel", rho = NULL)` accepts one labelled
  dense positive-definite kernel, fixed numeric `rho` in `[0, 1]`, or one
  estimated interior `rho` when `NULL`.
- `K_rho = rho K + (1-rho) diag(K)` preserves the supplied marginal scale.
- Long `kernel_coef(0 + x <bar> trait, rho = 1)` is exactly equivalent to
  long `kernel_slope(x <bar> trait)` for both bars without a ridge or warning.
- Wide `kernel_coef()` is exactly equivalent to its matched long fit.
- Intercept and intercept-plus-slope bases, recovery, labels, malformed inputs,
  fixed/estimated source strength, extractors, documentation, pkgdown, and
  regression gates pass.
- Existing `*_slope()` helpers remain current, warning-free, and unchanged.
- The PR is reviewed, green on Ubuntu/macOS/Windows, merged normally without
  bypass, exact-main verification succeeds, pkgdown is live, and leases release.

## Invariants

- Preserve all unrelated gllvmTMB lanes and never revert their work.
- No blanket `*_slope()` deprecation or warning.
- No wide `kernel_slope()` admission; prove replacement through the two-link gate.
- No intervals, non-Gaussian claim, multiple coefficient sources,
  `*_latent()` rho, spatial implementation, release, or version bump.
- No new TMB likelihood unless exact R-side reuse is proven insufficient and a
  scope-changing review gate is reopened.
- Do not push while another CI run is active; never bypass branch protection.

## Pre-authorisation

- Continue routine scoped edits, tests, builds, local fits under 30 minutes,
  documentation, checkpoints, local commits, one branch push, PR creation,
  CI-paced attributable repairs, and normal protected merge after exact-head
  three-OS success.
- Stop for a protection bypass, release/version bump, external compute campaign,
  destructive action outside this worktree, genuine cross-lane conflict, or
  evidence that changes the approved model contract.

## Compute boundary

Focused deterministic fits are expected to take under 30 minutes each. No
campaign is planned; anything larger requires a timing pre-run and approval.

## Later serial lanes

After exact-main kernel closure: `spatial_coef()` with `rho = 1`. Estimated
spatial rho and general `*_latent()` rho remain separate future programmes.
