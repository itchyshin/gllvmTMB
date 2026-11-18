# Paper 1 G3 V2 marginal-curvature smoke packet

Status: approved one-attempt private numerical-admission packet.

- Source gate/root: `G3_P1_S3_C360_R3_V2`
- Attempt: `paper1-g3-marginal-curvature-v2-86301`
- Frozen fixture: seed 86301; spatial two-field iJSDM; 360 cells; three
  species; rank one; ecological field plus GBIF-only bias field.
- Estimator: one frozen `nlminb` fit and, only when raw-eligible, the exact
  `2^-(0:8)` G3 grid using candidate-specific `sdreport_cov_fixed`.
- Curvature: production `V %*% g`; independent half/default/double central
  Jacobians of the exact marginal gradient; symmetry `1e-10`, direction and
  step disagreement 1%, PD, and condition `1e8` gates.
- Numerical admission: unchanged objective, convergence zero, objective
  non-increase, candidate maximum raw gradient at most `1e-3`, and valid
  candidate curvature.
- Time estimate: 5-20 minutes. Hard stop: 30 minutes (1800 seconds).
- Exactly one fresh root; no retry after a provenance-clean numerical result.

Passing establishes numerical admission only. It does not establish field-map
recovery, source separation, uncertainty calibration, or a public claim.
