# Approved findings and direct corrections

Baseline: da6398a9d8df78c04dc4645dfa3fd4c3bd8d75e3 (same target bytes as audit 255cedd6).

| Requirement | Before | After and direct evidence |
|---|---|---|
| F1 spatial partition | spatial-models 309–359 treated LL' as identified after rotation | Correlated-spatial section preserves rank2/three traits, gives two loading matrices and distinct positive Psi companions with the same total; shared axes/communality decomposition-sensitive; total spatial Sigma target without numerical-stability claim. Noether exact algebra PASS. |
| F2 summary scale | cross-family 378–414 and extractor help called residual augmentation observation scale and commensurable | Residual-augmented latent-liability/model-scale association explicitly not observed-response correlation; automatic commensurability removed; ordinal-probit refusal, classes, calculations unchanged. Ordinary extractor help and extract_Sigma help unchanged. |
| F3 ICC | covariance 443–454,490–513 required latent at each level | Appropriate covariance at each level, latent for shared structure and indep for diagonal levels; worked two-latent illustration remains that specific choice. Adjacent summary preamble corrected. |
| F4 residual types | covariance 464–488,515–535 conflated Psi, OLRE and family/link residual | Names between-unit Psi, observation-tier random effect and fixed link convention separately; removes universal-identifiability/double-counting claim and NB/Tweedie OLRE support implication. Recap follows correction. |
| F5 seeded evidence | cross-family description,320–333,416–428 treated one realization as recovery, sampling-only discrepancy and guaranteed replication/N resolution | One seeded known-truth teaching check; sampling/estimation/optimization can contribute; no repeat-simulation or increasing-N guarantee. Final nominal-boundary caveat explicitly restricted. |
| R1 notation | cross-family z_i/u_i drift near102 | z_i consistently denotes shifted latent score; e_i innovation remains distinct. |
| R2 accessibility | covariance chunks279,364,422 and cross-family327 lacked useful alt | Explicit fig.alt for correlation-error comparison, Sigma dotplot, correlation matrix and known-v-estimated scatter; rendered attributes gate pending. |
| R3 wide syntax | absent alternate-form examples or unlabeled parity implication | Added eval=FALSE covariance loadings-only and two-level, spatial latent/dep, nonordinal cross-family summary; explicit structural-translation labels and no parity claim. Existing evaluated covariance/spatial pairs and long-only cross-family fits preserved. |

Static invariants: `Rscript --vanilla dev/covariance-teaching/verify-invariants.R`;
all evaluated expressions AST-identical, exact diagnostic string whitelisted,
no src/API/likelihood/fixtures/tests changed. Mechanical negative controls detect
both model-expression edits and accidentally evaluated illustration chunks.

Deferred outside scope: unchanged R/extract-sigma.R softmax commensurability wording
conflicts with that help topic's qualified family-aware introduction (Noether report).
No file added to this lane for that follow-up, no new fit or public capability claim.
