# Final Fisher audit: 13 rebuilt articles

**Date:** 2026-07-12  
**Lens:** equations, formula-to-DGP-to-extractor alignment, inference and
identifiability claims, fit-health interpretation, warning visibility, current
API, and evidence boundaries.  
**Surfaces checked:** each `vignettes/articles/*.Rmd` source and its forced
non-lazy render at `articles/<name>.html`. All 13 rendered pages returned HTTP
200. The four corrected pages were rendered again with `lazy = FALSE` after
the changes below. None of the 13 source files globally sets
`warning = FALSE`.

| Page | Source + render | Verdict | Fisher note |
|---|---|---|---|
| `fit-diagnostics` | checked | PASS | The rebuilt table explicitly pairs `raw_max_gradient = 1.72e-06` with `raw_gradient_threshold = 0.01`; `scaled_gradient_descriptive = 8.995e-09` is separately labelled. Optimizer/gradient rows remain point-fit diagnostics, while `sdreport`/Hessian rows govern Wald inference. |
| `convergence-start-values` | checked | PASS | The rebuilt table explicitly pairs `raw_max_gradient = 1.033e-06` with `raw_gradient_threshold = 0.01`; `scaled_gradient_descriptive = 1.603e-08` is separately labelled. The convergence lane now names the raw maximum gradient and calls the scaled gradient descriptive; curvature remains a separate Wald-inference lane. |
| `pre-fit-response-screening` | checked | PASS | Screening heuristics, denominators, non-decision boundary, and post-fit handoff are stated correctly; no convergence or identifiability guarantee is implied. |
| `pitfalls` | checked | PASS | The loadings-only example explicitly uses `latent(..., unique = FALSE)`; the DGP, `extract_Sigma()` target, and observation-residual distinction align. Rotation and Hessian boundaries are correct. |
| `profile-likelihood-ci` | checked | PASS | Direct profiles, labelled Wald fallback, Fisher-z heuristic status, natural/failed/unbounded endpoints, and coverage limitations agree with rendered outputs and current target-specific API. |
| `missing-data` | checked | PASS | Response masking, observed-data likelihood, plug-in prediction, conditional-mode imputation, MAR/ignorability assumption, and MNAR/measurement-error boundaries are correctly separated. |
| `gllvm-vocabulary` | checked | PASS | Sigma/Lambda/Psi, four taught modes, rotation equivalence, raw-gradient verdict, Hessian role, and Fisher-z approximation are correctly scoped. |
| `api-keyword-grid` | checked | PASS | The four-mode grid is current; deprecated standalone `*_unique()` functions are not taught. Current `unique =` latent arguments, source-specific Psi structure, kernel limits, and slope covariance dimensions are correctly distinguished. |
| `fixed-effect-zero-constraints` | checked | PASS | `Xcoef_fixed` is correctly presented as a prespecified mean-model equality constraint, not selection or evidence for a null; fixed-row SE and conditional-inference statements are correct. |
| `response-families` | checked | PASS | Response supports, links, variance parameterisations, ordinal threshold convention, mixed-family scale limits, hurdle boundary, and point-only mixed-family covariance guidance are coherent and current. |
| `phylogenetic-gllvm` | checked | PASS | The entire article now teaches latent decompositions: the 150-species model uses `phylo_latent(..., unique = TRUE)`, and the 500-species split pairs that term with ordinary `latent(..., unique = TRUE)`. Equations, DGP draws, long/wide formulas, and `extract_Sigma(..., part = "shared"/"unique"/"total")` align term by term. In the 150-species fit all 13 health rows pass, long/wide log likelihoods differ by `6.82e-12`, and relative errors are `0.173` (phy shared), `0.228` (phy Psi), and `0.096` (phy total). In the 500-species fit all 16 health rows pass, long/wide log likelihoods differ by `3.06e-10`, and the seven reported errors are `0.732`, `0.862`, `0.340`, `0.179`, `0.114`, `0.137`, and `0.197`. The prose explicitly says the weak phylogenetic subcomponent recovery is not rescued by optimizer/Hessian health and makes no coverage or universal sample-size claim. |
| `behavioural-syndromes` | checked | PASS | The rebuilt table explicitly pairs `raw_max_gradient = 0.00208` with `raw_gradient_threshold = 0.01`; `scaled_gradient_descriptive = 3.617e-07` is separately labelled. The prose now distinguishes point-surface failures from Hessian/`sdreport` limits on Wald inference and states that long/wide parity is not interval validation. |
| `random-regression-reaction-norms` | checked | PASS | The rebuilt health table reports raw `max_gradient = 0.001567`, and the prose compares that raw value with `0.01`. Optimizer/raw-gradient, Hessian/`sdreport`, and boundary warnings now have distinct point-fit, Wald-inference, and target-specific consequences. |

## Closeout

All Fisher blockers, including the subsequent full-page phylogenetic
latent-decomposition correction, are fixed in source and confirmed in fresh
non-lazy renders. Final Fisher verdict: **13/13 PASS**. The audit found no
remaining statistical-wording blocker in this 13-article set.
