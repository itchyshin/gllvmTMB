# Paper 2 G3 V4 marginal-curvature smoke packet

Status: one fresh replacement attempt after a telemetry-only V3 failure.

V3 is consumed and invalid as evidence.  Its fit returned, but sandbox-denied
`ps` output caused `peak_rss_kb()` to index an empty vector before the terminal
ledger could be saved.  That is not G3 admission or rejection.  V4 changes only
that telemetry guard; it preserves the frozen Paper 2 fixture, estimator,
curvature contract, thresholds, and one-attempt rule from the V3 packet.

- Source gate/root: `G3_P2_S6_C360_R3_V4`
- Attempt: `paper2-g3-marginal-curvature-v4-86302`
- Frozen fixture: seed 86302; six species; 360 cells; rank one; GBIF Poisson;
  three PA/cloglog visits; diagonal Psi.
- Estimator: one `nlminb` fit, then the exact `2^-(0:8)` G3 grid if eligible.
- Metric: validated candidate-specific `sdreport_cov_fixed`; production step
  `V %*% g`; independent half/default/double full gradient Jacobians.
- Gates: unchanged objective; convergence zero; raw gradient in
  `(1e-3, 1e-2)`; candidate raw gradient at most `1e-3`; objective
  non-increase; PD curvature; condition at most `1e8`; direction disagreement
  and step sensitivity at most 1%.
- Time estimate: 5-20 minutes. Hard stop: 30 minutes (1800 seconds).
- No retry follows a provenance-clean V4 numerical result.

Passing establishes numerical admission only, never recovery or a public
capability claim.
