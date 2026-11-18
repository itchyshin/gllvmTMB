# S2 source map — integrated JSDM comparison

**Status:** source map for a future local-only article. It is not a benchmark,
implementation comparison, or evidence of package superiority.

| Package | Documented model | Difference from this private iJSDM | Article wording |
| --- | --- | --- | --- |
| `gllvm` | Multivariate generalized latent-variable models, fitted with Laplace or variational approximations. | Closest latent-variable/JSDM comparison, but the same GBIF-Poisson plus replicated PA-cloglog likelihood is not established here. | “Use for general multivariate GLLVM/JSDM analyses; do not treat the likelihoods as interchangeable.” |
| Hmsc | Hierarchical JSDMs relating occurrence/abundance to environment, traits, and phylogeny. | Broad community framework, not evidence of the private two-source relative-intensity estimand. | “Use when its hierarchical Bayesian community formulation answers the question.” |
| `spOccupancy` | Single/multi-species integrated occupancy models with imperfect detection, fitted with MCMC. | Closest alternative when occupancy and detection probability—not relative ecological intensity—are the estimands. | “Choose occupancy when repeated visits identify detection and latent occupancy.” |
| `glmmTMB` | Flexible GLMMs with optional zero inflation and reduced-rank covariance. | Useful component/control model, not a documented one-call version of this two-source joint likelihood. | “A zero-inflation formula is a specified observation model, not an automatic iJSDM cure.” |
| `sdmTMB` | Spatial and spatiotemporal GLMMs with TMB and SPDE/GMRF fields. | Relevant later spatial control, not a shared-ecological-plus-GBIF-bias two-field iJSDM. | “Use for spatial GLMM questions; this private core is nonspatial.” |

## Sources to cite

- `gllvm`: <https://search.r-project.org/CRAN/refmans/gllvm/html/gllvm.html>
- Hmsc: <https://search.r-project.org/CRAN/refmans/Hmsc/html/Hmsc-package.html>
- `spOccupancy`: <https://search.r-project.org/CRAN/refmans/spOccupancy/html/spOccupancy-package.html>
- Doser et al. (2022): <https://doi.org/10.1111/2041-210X.13897>
- `glmmTMB`: <https://glmmtmb.github.io/glmmTMB/reference/glmmTMB.html>
- `sdmTMB`: <https://sdmtmb.github.io/sdmTMB/>

## Claim fence

The future article may compare likelihoods, estimands, and intended use. It
must not claim speed, accuracy, novelty, empirical performance, or superiority
without a separately approved benchmark. It must state that this iJSDM core is
private, nonspatial, relative-intensity only, and not yet public package
capability.
