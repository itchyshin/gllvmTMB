# G2i local recovery pre-run decision record

G2i S7 runs one fresh known-truth replicate on the unchanged G2h 360-cell,
six-species, three-visit fixture and G2i final-polish estimator.  The frozen
pre-run seed is `86122L`; it is distinct from the G2h/G2i smoke seed `86121L`.

The pre-run retains the smoke admission requirements: three restarts, six
finite/converged five-offset `theta_diag_B` profiles, a valid GBIF-only source
gate, and final selected-estimator gradient at most `1e-3`.  It additionally
summarizes known-truth recovery using the frozen G2d metric thresholds:

| Metric | Threshold |
| --- | ---: |
| maximum absolute environmental-slope error | `<= 0.30` |
| maximum absolute GBIF-bias error | `<= 0.30` |
| minimum ecological-map correlation | `>= 0.70` |
| relative Frobenius error of `Lambda Lambda^T` | `<= 0.50` |
| maximum diagonal-Psi variance error | `<= 0.20` |

The recovery classification is `PRE_RUN_RECOVERY_PASS` only when every
admission and recovery metric criterion passes.  Any missing artifact, error,
invalid profile, failed source gate, or failed metric is
`PRE_RUN_RECOVERY_HOLD`; it is not a retry authorization.

This one pre-run is not a recovery campaign, coverage result, spatial or
detection extension, public claim, or Totoro authority.
