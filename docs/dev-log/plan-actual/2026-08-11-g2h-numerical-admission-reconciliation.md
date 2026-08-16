# G2h numerical-admission reconciliation

| Goal requirement | Evidence | Status |
| --- | --- | --- |
| Retained-artifact-only analysis | `fit.rds`, restart/profile/decision ledgers, root receipt, manifest | met |
| Frozen G2h and G2c--G2g records unchanged | clean pre-edit branch; no artifact writes or runs | met |
| Exact maximum-gradient parameter block | repeated AD gradient: `theta_rr_B[2] = lambda_sp2`, `0.001290534` | met |
| Boundary versus gradient distinction | `theta_diag_B[1]` has `sd_B=1.402126e-4`, gradient `5.239760e-7` | met |
| Hessian/local-curvature evidence | saved `cov.fixed`, `pdHess=TRUE`; loading curvature `261.7304` | met |
| Cutoff assessment | frozen `1e-3` remains binding; stored generic/scaled stationarity passes | met |
| One recommendation | conditional same-objective polish guard, no threshold relaxation | met |
| New fit, profile, retry, campaign, Totoro/DRAC | none | preserved |

The G2h receipt remains `G2H_SMOKE_HOLD`. This diagnosis identifies a narrowly scoped optimizer-control repair candidate; it does not reclassify the smoke or authorise its replacement.
