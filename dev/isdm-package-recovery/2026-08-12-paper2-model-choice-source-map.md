# Paper 2 private iJSDM: model-choice source map

**Status:** A1 evidence map only; not a performance ranking or a comparator
study.  Sources accessed 2026-08-12.

## Question answered

Which modelling problem does each package principally address, and therefore
which one is a useful conceptual neighbour of the retained private G2 route?
The G2 route is a nonspatial, synthetic, two-source *relative-intensity* model:
GBIF Poisson observations and repeated PA cloglog observations share a
species-by-cell ecological predictor, with a rank-one shared component and
free diagonal Psi.  It has neither an occupancy/detection layer nor a spatial
field, and it is not validated recovery evidence.

| Package | Grounded model focus | Relation to the G2 estimand | Deliberate non-claim |
| --- | --- | --- | --- |
| [`gllvm`](https://jenniniku.github.io/gllvm/) | Multivariate GLLVM/JSDM fitting, with Laplace or variational approximation documented in its reference. | Closest frequentist latent-variable/JSDM neighbour for discussing multivariate residual structure. | No parity, accuracy, speed, or implementation-equivalence claim. |
| [Hmsc](https://github.com/hmsc-r/HMSC) | Bayesian hierarchical community/JSDM framework connecting occurrences or abundances to covariates, traits, phylogeny, and optional spatiotemporal sampling context. | Conceptual community-model neighbour; its hierarchical framing helps distinguish a JSDM from separate stacked SDMs. | It does not validate the private TMB likelihood, its Psi allocation, or a source-integration claim. |
| [`spOccupancy`](https://doserlab.com/files/spoccupancy-web/reference/spoccupancy-package) | Bayesian occupancy models, including multi-species, integrated, spatial, and imperfect-detection formulations via MCMC/Pólya-Gamma augmentation. | The appropriate reference if a later question is explicitly occupancy, detection, or multi-source occupancy integration. | The retained G2 PA-cloglog observations do **not** estimate detection or occupancy; no occupancy comparison is made. |
| [`glmmTMB`](https://glmmtmb.github.io/glmmTMB/reference/glmmTMB.html) | Generalized linear mixed models and extensions through TMB, with formula, zero-inflation, dispersion, and covariance components. | TMB/GLMM engineering neighbour and the intended package for ordinary single-response models. | No multivariate iJSDM or arbitrary-source integration support is implied. |
| [`sdmTMB`](https://sdmtmb.github.io/sdmTMB/) | Spatial and spatiotemporal SPDE/GMRF GLMMs through TMB/fmesher. | Reference point for a later, separately designed spatial SDM question. | The present route has no spatial field; it supplies no spatial claim or validation. |

## Reading consequence

The source map is a choice aid, not a league table.  It tells a reader to use
an occupancy framework when latent occupancy and detection are the estimand; a
spatial GLMM when spatial or spatiotemporal fields are the estimand; a
single-response GLMM for a single response; and a multivariate latent-variable
framework when the scientific question is residual cross-species structure.
The retained G2 evidence occupies only the last conceptual neighbourhood and
only at its stated, private synthetic scope.

## Source notes

- The [gllvm reference](https://search.r-project.org/CRAN/refmans/gllvm/html/gllvm.html)
  documents multivariate GLLVM fitting and its Laplace/VA methods.
- The [Hmsc repository](https://github.com/hmsc-r/HMSC) describes the framework
  and the optional traits, phylogeny, and spatiotemporal sampling information.
- The [spOccupancy package reference](https://doserlab.com/files/spoccupancy-web/reference/spoccupancy-package)
  documents MCMC/Pólya-Gamma occupancy, multi-species, and integrated models.
- The [glmmTMB reference](https://glmmtmb.github.io/glmmTMB/reference/glmmTMB.html)
  defines the TMB GLMM interface.
- The [sdmTMB site](https://sdmtmb.github.io/sdmTMB/) describes its spatial and
  spatiotemporal TMB/GMRF GLMM focus.

These sources describe package scope, not comparative performance.  No package
was fitted or benchmarked for this map.
