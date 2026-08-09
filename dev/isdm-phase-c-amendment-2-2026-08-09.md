# Phase C prospective amendment 2: exact finite-sample bias geometry

**Frozen:** 2026-08-09 UTC (2026-08-08 MDT), before any corrected pilot or campaign rerun.

## Status of the earlier run

The earlier Phase C run is superseded for claims that require exact realised bias geometry or
global attribution to the declared `kappa`, `rho`, and `omega` treatments. Its independent
standardised GP draws did not make `x`, `g`, and every `h_j` mutually orthogonal in each finite
dataset. Consequently, realised `Var(B_j)`, `cor(B_j, x)`, and `cor(B_j, B_k)` differed from the
design values by random finite-sample amounts. The old raw files and receipts remain immutable
provenance; they are not corrected in place and do not support those exact-geometry claims.

This amendment is prospective. It was triggered by a design-to-implementation review, not by a
scientific outcome. No old outcome was used to select this repair. The scientific hypotheses,
primary endpoint, thresholds, arms, exclusions, grids, seed lists, pairing rules, and the permitted
pilot decisions are unchanged.

## Exact transformation

For one dataset let `x` be the already drawn environmental GP and let
`Z = [g, h_1, ..., h_T]` contain the already drawn bias GPs. All sample moments below use divisor
`n - 1`. First centre and standardise `x`. Centre `Z`, project it off `x`, and symmetrically whiten
the residual columns:

\[
  Z_\perp = (I - xx^\mathsf{T}/(n-1))Z,
  \qquad G = Z_\perp^\mathsf{T}Z_\perp/(n-1),
  \qquad Q = Z_\perp G^{-1/2}.
\]

Here `G^{-1/2}` is the symmetric eigen inverse square root. The first column of `Q` becomes `g`
and the remaining columns become `h_1, ..., h_T`. The instrument fails closed if the dimension is
rank-impossible, `G` is numerically rank deficient, an eigenvalue is non-finite, or the realised
Gram matrix differs from identity by more than the frozen numerical tolerance.

This deterministic transformation occurs after exactly the old draws and makes no RNG call.
Thus the design and bias seed streams, RNG ordering, and draw counts are unchanged. The same raw
draws and transformed basis are reused across `kappa`, `rho`, and `omega` (common random numbers).
`phi_x` remains fixed at `0.15`; `phi_bias` remains the sole kernel parameter for every raw bias
field, including its `0` i.i.d. boundary. The transformed columns are not claimed to be untouched
finite GP realisations: projection against `x` and whitening are the explicit price of exact
finite-sample geometry. No additional spatial parameter is introduced, and exact design-stream
identity across `phi_bias` is checked separately.

The repaired field remains

\[
 B_j = \kappa\{\rho x + \sqrt{1-\rho^2}
       [\sqrt{\omega}g + \sqrt{1-\omega}h_j]\}.
\]

Because `x`, `g`, and all `h_j` are sample-orthonormal, for every species `j` and pair `j != k`,

\[
 \operatorname{Var}_s(B_j)=\kappa^2,\qquad
 \operatorname{cor}_s(B_j,x)=\rho,\qquad
 \operatorname{cor}_s(B_j,B_k)=\rho^2+(1-\rho^2)\omega.
\]

At `kappa = 0`, the realised bias variance is exactly zero and correlations involving the constant
field are recorded as undefined; their theoretical targets remain recorded distinctly.

## Symbolic-to-implementation alignment

| Symbol | Model role | DGP operation | Recorded check | Frozen truth |
|---|---|---|---|---|
| `x` | environmental predictor | original `phi_x` GP, centred and standardised | component Gram matrix | mean 0, sample variance 1 |
| `g` | shared bias field | first column of projected, symmetrically whitened `Q` | component Gram matrix | orthogonal to `x` and every `h_j`; sample variance 1 |
| `h_j` | species-specific bias field | remaining columns of `Q` | component Gram matrix | mutually orthogonal; sample variance 1 |
| `B_j` | PO recording-bias offset | frozen linear combination above | realised variance, rho, and sharing diagnostics | exact identities above |
| bias diagnostics | provenance/result columns | theoretical and realised values stored separately | preflight strict-tolerance assertions | no theoretical/realised conflation |

## Prospective contract checks and receipts

Before any fit, structural preflight exercises `n = 100`, `T = 12`, `phi_bias` in
`{0, 0.15, 0.4}`, `rho` in `{-1, -0.8, 0, 0.6, 0.8, 1}`, and `omega` in `{0, 0.5, 1}`. It checks every
species and pair through maximum errors, checks common-random-number and cross-`phi_bias` design
stream contracts, and pairs an accepted full-rank construction with a rejected rank-impossible
construction.

All new compute receipts use schema `phase_c_compute_v2`. Campaign receipts use canonical
`stage=campaign` and `block=G1` through `G6`, retain the legacy `receipt_type` keys for readers,
and record the full seed list, configuration hash, default or explicit optimiser control,
session/package versions, expected and actual logical rows and fit attempts, structural counts,
and exact input, output, resume-part, and predecessor paths and hashes. A corrected run requires
new output and receipt paths; nothing in this amendment authorises compute by itself.

The preflight configuration hash covers the 54-case geometry grid and tolerance, CRN and
cross-`phi_bias` probes, rank acceptance/rejection pair, REF/null/smoke configurations, and all
preflight simulation and explicit fit seeds. The receipt's `seed_list` is the full inventory,
with `seed_inventory_roles` distinguishing result-bearing, geometry, CRN, stream, and
null-collapse seeds. `actual_model_fit_attempts` counts entries into the model-fit front end. Because
the package does not expose an independent hook at the low-level optimiser boundary,
`actual_optimizer_calls` is recorded as `NOT_INSTRUMENTED_MODEL_FRONTEND_ATTEMPTS_RECORDED_SEPARATELY`
rather than being inferred from front-end entry. This is an explicit instrumentation limit, not a
missing or estimated count.
