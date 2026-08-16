# Ultra-plan — cursor-mspl-phase4-nbinom2 (frozen at launch)

Binding detail for this isolated Phase-4 *prep* lane. Not a new
programme constitution. Phase 4 of

`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

says: Poisson first, then NB2; **separate mean-boundary penalties
from dispersion 0 or ∞ boundaries**; NB1 and NB2 do not inherit
each other.

## In

- Information / coercivity note: NB2 variance
  \(\operatorname{Var}=\mu+\mu^2/\theta\) is not Poisson
  \(\operatorname{Var}=\mu\); GLM weight
  \(W=\mu\theta/(\theta+\mu)\) is not \(\operatorname{diag}(\mu)\).
- Three named boundaries: all-zero / near-zero \(\mu\to 0\);
  overdispersion blow-up \(\theta\to 0\); Poisson limit
  \(\theta\to\infty\).
- Pure-R oracles + kill list.
- LOOP kit, after-task, PR.

## Out

- `R/mspl.R`, `src/`, other families.
- Registry admit (nbinom2 stays excluded; this lane does not add
  planned rows either).
- Prepare widen.
- Live `gllvmTMB(..., estimator = "mspl")` on nbinom2.
- SE, NEWS covered, campaigns, NB1, truncated/hurdle.

## Stack

Branch from `cursor/mspl-point-programme-continue` @ the #971 tip.
PR stacks on that branch so the delta is NB2-only.
