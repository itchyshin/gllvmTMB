# Paper 1 G3 V3 marginal-curvature smoke packet

Status: one fresh replacement after an invalid terminal-writer failure.

Paper 1 V2 is consumed and invalid as evidence. The model fit and G3 core
returned `G3_RAW_INELIGIBLE`, but the direct `on.exit` writer used parent-scope
assignment and failed before saving the ledger. V3 changes only those local
finalizer assignments. It preserves the V2 fixture, estimator, thresholds,
curvature contract, 5-20 minute estimate, 1800-second hard stop, and claim
boundaries.

- Source gate/root: `G3_P1_S3_C360_R3_V3`
- Attempt: `paper1-g3-marginal-curvature-v3-86301`
- Exactly one fresh root. A provenance-clean numerical result ends G3 for
  Paper 1.

Passing establishes numerical admission only, never field recovery or a
public capability claim.
