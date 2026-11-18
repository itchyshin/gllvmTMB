# Paper 1 spatial Gate-B2: receipt-to-estimand alignment

**Status:** private replacement-smoke contract.  It changes neither the spatial
likelihood nor the DGP; it adds a fresh seed and a durable record around one
already-authorised local fit.

| Estimand component | Frozen implementation route | Immutable receipt / ledger field | No-fit check |
| --- | --- | --- | --- |
| Ecological field | intercept of `spatial_latent(1 + isdm_gbif | cell_id, d = K)` | `source_map$shared_ecological`; `field_outputs$ecological` | distinct ecological and GBIF draw seeds; zero DGP cross-field correlation |
| GBIF-only bias field | `isdm_gbif` slope of the same spatial term | `source_map$gbif_only`; `field_outputs$gbif_bias` | GBIF bias covariate is `NA` on PA rows |
| Shared residual covariance | `indep(0 + trait | cell_id)` | `source_map$psi` | retained as a named, non-SPDE component |
| Numerical attempt | one `n_init = 1` fit | raw start, selected start, terminal status, objective, code, gradient, Hessian, flags, warnings and versions | terminal schema is validated even for `FIT_ERROR` |
| Operational telemetry | downstream machine probe | `peak_rss_kb`, separately saved telemetry | all-attempt ledger is saved by `on.exit()` before telemetry runs |

The only permitted inference from a successful B2 smoke is that this named
fixture and implementation completed its single recorded attempt.  It is not a
recovery result, a comparison, an empirical result, or evidence for a second
SPDE implementation.
