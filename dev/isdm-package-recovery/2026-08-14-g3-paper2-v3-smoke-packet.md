# Paper 2 G3 V3 marginal-curvature smoke packet

Status: approved one-attempt private numerical-admission packet.  This packet
authorises one fresh local fit only after the committed implementation and
preflight receipts match.  It authorises no retry, profile, recovery campaign,
map, empirical analysis, or public capability claim.

- Source gate: `G3_P2_S6_C360_R3_V3`
- Root: `G3_P2_S6_C360_R3_V3`
- Attempt: `paper2-g3-marginal-curvature-v3-86302`
- Frozen fixture: seed 86302; six species; 360 cells; rank one; GBIF Poisson;
  three PA/cloglog visits; diagonal Psi.
- Estimator: the sole `nlminb` fit followed, when raw-eligible, by the exact
  nine-alpha `2^-(0:8)` G3 grid using `sdreport_cov_fixed`.
- Numerical gates: unchanged objective; convergence code zero; unique raw
  maximum gradient in `(1e-3, 1e-2)`; validated marginal curvature; objective
  non-increase; candidate maximum raw gradient at most `1e-3`; candidate
  curvature PD with condition at most `1e8`.
- Curvature validation: exact `V %*% g` production direction; independent full
  central Jacobians of the exact gradient at half/default/double coordinate
  steps; covariance-direction and step sensitivity at most 1%; symmetry,
  positive-definiteness, and condition gates retained.
- Time estimate: 5-20 minutes.  Hard stop: 30 minutes (1800 seconds).
- Attempts: exactly one fresh root and no rerun after a provenance-clean
  numerical non-admission.

Passing this packet establishes numerical admission only.  Psi recovery and
all-attempt recovery remain separate later gates.
