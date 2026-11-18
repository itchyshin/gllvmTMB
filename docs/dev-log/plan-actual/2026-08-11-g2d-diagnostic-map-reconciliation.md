# G2d diagnostic map reconciliation

| Axis | Approved diagnostic | Actual | Classification | Consequence |
| --- | --- | --- | --- | --- |
| Fit budget | One ordinary three-visit diagnostic, no profile | One `n_init = 1` fit, 3.027995 s | pass | no retry or smoke |
| Original result | Retain every result, including HOLD | `G2D_DIAGNOSTIC_MAP_HOLD` root unchanged | pass | no artefact laundering |
| Rank-one map | Six `theta_rr_B` values reconstruct six-by-one `Lambda_B` | Exact retained-object check passed | pass | loading packing aligned |
| Diagonal map | Six free `theta_diag_B` values yield six `sd_B` values | Direct `exp(theta_diag_B) == sd_B` passed | pass | Psi transform aligned |
| Extractors | Shared, unique, total Sigma equal symbolic decomposition | All three numeric identities passed | pass | extractor assembly aligned |
| Checker defect | No fit retry after checker failure | Two fresh manifest-bound no-fit audits | pass | original HOLD retained |
| Claim fence | No promotion to smoke/recovery | None attempted | pass | `G2D_SMOKE_HOLD` remains binding |

**Rose reconciliation verdict**: the private six-species TMB object confirms symbolic-to-map/extractor assembly. No engine/R likelihood repair was indicated. This is not numerical recovery evidence and does not authorise a replacement smoke, campaign, Totoro, or Paper-2 efficacy claim.

