# Runaway classification -- the 92 effort-campaign runaways are a whole-block scale ray

Ride-along slice of the replication-axis goal. Analysis of the 92 fits with
||lambda_hat_slope|| > 100 among the effort campaign's 1,600 rows.

| test | result |
| --- | --- |
| cor(q_hat, log ||lam_slope||) among runaways | 0.799 |
| q_hat range among runaways | 3.24 to 8.51 (truth 2.554; kappa up to ~5,000) |
| log(lam) - q stability | mean 2.61, sd 1.89 (truth 0.23) -- NOT a lambda/kappa-preserving ray |
| intercept block | runs away WITH the slope block (cor 0.70; median ||lam_int|| = 81,515) |
| loud or silent? | 83/92 have conv != 0; median max|g| 13x the non-runaway median; **9/92 are silent** (conv = 0) |

**Mechanism.**  kappa -> infinity drives the SPDE prior variance to ~0 and the
field toward iid cell noise; BOTH loading blocks blow up to keep the realized
contribution finite. The runaway basin is the SPDE block degenerating into an
unstructured per-cell residual -- a scale ray of the whole block, not the
slope-only lambda/kappa ray. Confirms and extends the standing "runaway is
bimodal, not biased" finding with a mechanism at the SPDE parameterisation.

**Detector implication.**  `loading_runaway_thresh = 25` flags 92/92 runaways
but ALSO 907/1,508 healthy fits, because the TRUE intercept-loading norm at the
anchor (~25.2) sits at the threshold: absolute loading thresholds are
meaningless when loadings absorb the field scale. **Another instance of the
scale-dependent-constants class (#851).** A scale-free detector for this
parameterisation would use q_hat drift plus the joint blow-up signature
(e.g. log||lam|| - q against its start), not |lambda| alone.

Filed as classification evidence only; no detector change is made here.
