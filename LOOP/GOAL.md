# GOAL — admit the first structured response-column coefficient source

**IMMUTABLE for this lane.** Re-read this file before every arc.

## Deliverable

Implement, document, verify, and normally merge public Gaussian point-model
`animal_coef()` support in long and `traits(...)` wide formats, building on the
current warning-free `animal_slope()` endpoint. This is the first serial arc of
the approved animal -> kernel -> spatial coefficient programme.

## Definition of done

- `animal_coef()` accepts exactly one of `pedigree`, `A`, or `Ainv`.
- Fixed numeric `rho` in `[0, 1]` is supported with public default `rho = 1`;
  estimated `rho = NULL` remains fenced for a later evidence slice.
- Long `animal_coef(0 + x | trait, rho = 1)` is byte-equivalent to long
  `animal_slope(x | trait)` for `|` and `||`.
- Wide `animal_coef()` is byte-equivalent to its matched long fit.
- Intercept and intercept-plus-slope bases, recovery, labels, malformed inputs,
  extractors, documentation, pkgdown, and regression gates pass.
- Existing `*_slope()` helpers remain current, warning-free, and unchanged.
- The PR is reviewed, green on Ubuntu/macOS/Windows, merged normally without
  bypass, exact-main verification succeeds, pkgdown is live, and leases release.

## Invariants

- Preserve all unrelated gllvmTMB lanes and never revert their work.
- No blanket `*_slope()` deprecation or warning.
- No wide `*_slope()` admission; prove replacement through the two-link gate.
- No intervals, non-Gaussian claim, estimated animal `rho`, `*_latent()` rho,
  kernel, spatial, article expansion, release, or version bump in this lane.
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

Focused deterministic fits are expected to take under 30 minutes each. A larger
recovery campaign requires a pre-run timing result, explicit target, and fresh
approval before Totoro or DRAC use.

## Later serial lanes

After exact-main animal closure: `kernel_coef()`. After kernel closure:
`spatial_coef()` with `rho = 1`. Estimated spatial rho and general `*_latent()`
rho remain separate future programmes.
