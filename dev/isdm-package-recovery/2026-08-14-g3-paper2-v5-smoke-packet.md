# Paper 2 G3 V5 marginal-curvature smoke packet

Status: one fresh replacement attempt after a sealed adapter-infrastructure
HOLD. V3 is telemetry-invalid. V4 is provenance-valid but terminated
`G3_CURVATURE_UNAVAILABLE` because TMB returned unnamed `sdreport()` fixed
parameters and covariance; no G3 trial ran.

V5 changes only the adapter rule: absent `sdreport` names are accepted when
the returned vector/matrix dimensions match the explicitly supplied ordered
`par.fixed`, and the returned numeric parameter vector exactly replays that
request before positional IDs are assigned. Supplied names must still match;
no permutation, sorting, or fuzzy name repair is allowed.

- Source gate/root: `G3_P2_S6_C360_R3_V5`
- Attempt: `paper2-g3-marginal-curvature-v5-86302`
- Fixture, estimator, metric, thresholds, time estimate, 1800-second hard
  stop, one-attempt rule, and claim boundaries are identical to V4.
- A provenance-clean numerical non-admission ends G3 for Paper 2.

Passing establishes numerical admission only, never recovery or a public
capability claim.
