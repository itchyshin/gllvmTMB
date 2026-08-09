# S11 ordinary-core optimizer diagnosis

Date: 2026-08-08  
Scope: read-only diagnosis of the frozen v3 production failures  
Decision: recommend one narrow default-optimizer repair; implementation awaits
explicit maintainer authorization because it changes default numerical behavior.

## Result

The three investigated failure classes do not have one common cause.

| Cell | Frozen result | Diagnosis | Release disposition |
|---|---:|---|---|
| Binomial-logit latent, `n = 300` | 368/400 stationary-usable | PORT stopping artifact just above the absolute gradient gate | Candidate for a narrow warm restart and new-ID rerun |
| Gaussian latent, `n = 60` | 350/400 usable; 50 boundaries | Genuine near-zero Psi boundary behavior | Fence below the evidenced `n = 240` regime |
| NB2 latent, `n = 100` | 348/400 usable; 40 boundaries, 11 non-PD, 1 optimizer failure | Genuine weak latent-versus-unique identification | Fence below the evidenced `n = 300` regime |

## Binomial stopping artifact

All 32 binomial `n = 300` failures had optimizer code zero, a positive-definite
Hessian, finite estimates, and raw maximum gradients from 0.0101 to 0.0175.
The raw gradients grew with the summed likelihood while objective-scaled
gradients stayed almost unchanged:

| Cell | Median objective | Median max gradient | Maximum gradient | Median objective-scaled gradient |
|---|---:|---:|---:|---:|
| `n = 100` | 2348.9 | 0.00171 | 0.00572 | `7.26e-7` |
| `n = 300` | 7061.2 | 0.00454 | 0.01752 | `6.45e-7` |

Seed `372000004` isolated the mechanism:

| Route | Objective | Maximum gradient | Code |
|---|---:|---:|---:|
| Default `nlminb` | 7053.80833184348 | 0.017336 | 0 |
| One default warm `nlminb` restart | 7053.80833157611 | 0.002287 | 0 |
| Tight warm restart | 7053.80833157172 | 0.000161 | 0 |

The ordinary warm restart took six iterations. Its maximum parameter change
was `1.83e-5`, maximum beta change `7.24e-6`, maximum total-Sigma change
`9.34e-6`, and objective improvement `2.67e-7`. Tight controls from the
original starting point returned the original stopping point; resetting PORT
at the reported optimum is the effective mechanism.

## Genuine weak-identification cases

For Gaussian latent `n = 60`, all 50 rejected fits were variance boundaries;
gradients were already small and every Hessian was positive definite. Seed
`371300010` had minimum Psi `3.64e-9`; tight `nlminb` reproduced the same point
and BFGS moved only `2.3e-9`. The `n = 240` cell had no frozen boundary failure.

For NB2 latent `n = 100`, the 40 boundary fits comprised 28 simultaneous
variance/correlation boundaries, seven correlation-only boundaries, and five
variance-only boundaries. Seed `371700001` could be moved from non-PD to PD,
but required an internal-parameter shift near one for an objective improvement
of only `0.00036`; total Sigma changed only `0.00104`. This is a flat
decomposition ridge, not a stopping artifact that should be polished away.

## Proposed narrow repair

Keep the existing optimizer and the absolute `0.01` stationarity gate. On the
native Laplace `nlminb` path only, attempt one additional warm `nlminb` pass
when the first result has:

1. optimizer code zero;
2. finite objective and AD-exact gradient; and
3. raw maximum absolute gradient at least `0.01`.

Use the same objective, gradient, bounds, scale, and controls. Accept the warm
candidate only when it retains code zero, has finite objective and gradient,
does not worsen the objective beyond a named numerical tolerance, and strictly
improves the raw maximum gradient. Otherwise retain the original result. Record
attempted/accepted status and before/after objective and gradient. Do not apply
this logic to `optim`, boundary, non-PD, or failed-code fits.

Required tests cover pure acceptance/rejection logic, deterministic binomial
seed `372000004`, objective/report/sdreport consistency, preservation of
`optArgs`/bounds/scale, no effect on already-stationary or `optim` fits,
continued honest boundary classification for Gaussian seed `371300010`, no
silent promotion of NB2 seed `371700001`, and restart-history invariants.

Any implemented repair requires a disjoint-seed, new-ID, exact-source campaign.
The raw-gradient gate must not be weakened post hoc.
