# R2 mathematical-closure gate

**Date:** 2026-07-20
**Lens:** Noether (symbolic alignment) with Rose (claim boundary)
**Scope:** internal q=1/q=2 fixed-coordinate AGHQ reference harness only

## Initial verdict: STOP

The R2 harness correctly reconstructed fixed-coordinate objectives and fenced
tensor AGHQ at `q >= 3`, but its first merged receipt was not sufficient to
admit R3.

1. The data generator drew latent scores with scale `0.7` at `q = 1` and
   diagonal scales `0.7, 0.45` at `q = 2`, while the stored truth labelled
   `Sigma_B = Lambda_B Lambda_B^T`. The live fitted model assumes
   `u_i ~ N(0, I)`. The receipt therefore had to standardise the score draw and
   fold those scales into the effective loading matrix, or explicitly store the
   effective covariance.
2. The harness recorded objectives, modes, and curvature, but not normalized
   AGHQ posterior means and covariances. Design 85 Gate 2 needs those quantities
   as the independent reference for the later VA posterior-moment comparison.
3. Design 85 omitted three decisions from the approved arc: a Gaussian
   exactness anchor, rank zero in ML rank selection with a not-applicable stop,
   and a quantitative practical-advantage plus predictive-scoring rule at
   `q = 4/6`.

## Required closure

- Use `u_i ~ N(0, I)` in the receipt truth and preserve the intended linear
  predictor by moving the former score scales into `Lambda_B`.
- At the terminal node order, normalize adaptive-GHQ weights on the log scale
  and report each unit's posterior mean and covariance.
- Write posterior moments to a raw local receipt table with fixture, unit,
  rank, node order, normalization, and source provenance.
- Test normalization, symmetry/positive semidefiniteness, finite values,
  dimension, permutation invariance, and direct agreement with a separately
  evaluated weighted-node calculation.
- Freeze the three missing Design 85 decisions before R3 code or compute.

## Admission rule

R3 remains **NO-GO** until the targeted closure tests, a source-package check,
and a fresh three-OS workflow matrix pass on the closure commit. Passing this
gate authorises only an internal R3 prototype. It does not authorise a public
VA/AGHQ API, `q >= 3` tensor AGHQ, likelihood/AIC interpretation of an ELBO,
non-Gaussian REML, interval claims, or a package-release claim.

## Final verdict

**PASS.** The corrected truth map, normalized posterior moments, raw
provenance, 1,438 targeted expectations, and vignette-complete source package
check all pass. Full-matrix workflow run
[`29748324495`](https://github.com/itchyshin/gllvmTMB/actions/runs/29748324495)
passed on Windows, macOS, and Ubuntu at exact closure commit `c70538a2`. PR
[#776](https://github.com/itchyshin/gllvmTMB/pull/776) merged the closure as
`0ae825fe`. R3 is admitted under the internal-only boundaries above.
