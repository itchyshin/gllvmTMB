# Independent pre-fit method review

Reviewer: Sol/high method gate  
Date: 2026-08-28  
Verdict: model routes pass; evidence design fails until the five amendments
below are explicitly approved and frozen.

1. **Target availability.** The original plan could pass recovery on a selected
   extractable subset. Every named target now needs availability at least 0.85
   on all attempts. Every coefficient is gated separately; bias/RMSE use only
   available records and missing records never pass.
2. **Disconnected support.** Disjoint cells do not mathematically guarantee
   non-identifiability. The slice is reclassified as a retained stress test
   whose degradation and diagnostics are reported, not a required refusal and
   not promotion evidence.
3. **Coordinate holdout.** All species and source rows at a held-out coordinate
   must leave training. Withholding individual long rows would leak the field.
4. **Coverage unit.** Wilson intervals are applied separately to each species
   over independent replicates. All species must pass. Coverage is conditional
   among available finite ordered intervals; availability is a separate gate.
5. **Quantile identity.** Link/response identity uses type-1 order-statistic
   quantiles. Default interpolated quantiles do not commute exactly through a
   nonlinear inverse link.

Additional freezes:

- score total ordinary covariance with
  `extract_Sigma(..., part = "total")`, not shared-only `report$Sigma_B`;
- obtain `Psi` as fitted `sd_B^2` because TMB stores log standard deviations;
- draw the required marginal covariance from a block of the full inverse joint
  precision, never by inverting the matching precision submatrix;
- describe the later interval only as pointwise marginal latent-mean/intensity
  uncertainty at preregistered in-hull sentinels.

No fit was run for this review. These corrections do not change the likelihood,
formula grammar, or public scope. They do change the approved adjudication
contract, so production remains blocked pending maintainer acceptance.

