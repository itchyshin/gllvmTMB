# Spatial iSDM Stage 1: third-party source map

**Status:** private design input; no fit, simulation, implementation, public
claim, or empirical analysis is authorised by this note.

## Question

What design facts must a two-source spatial iSDM demonstrate before a synthetic
recovery campaign can claim that it separates ecological spatial structure from
GBIF-only sampling bias?

## Grounded findings

| Source | What it supports here | Boundary for this programme |
| --- | --- | --- |
| Miller et al. (2019), *Methods in Ecology and Evolution*, doi:10.1111/2041-210X.13110 | Integration must retain the distinct sampling designs and use information on sampling effort and spatial autocorrelation. | It does not validate this package, this likelihood, or a two-field decomposition. |
| Pacifici et al. (2017), *Ecology*, doi:10.1002/ecy.1710 | Data fusion can model spatial autocorrelation while retaining distinct data-source quality. | Its occupancy/detection setting is not this relative-intensity estimand. |
| Fletcher et al. (2019), *Ecological Applications*, doi:10.1002/eap.1910 | Integrated SDMs require an explicit account of source-specific assumptions and sampling design. | It is a practical framework, not a recovery threshold. |
| Baker (2022), *Global Ecology and Biogeography*, doi:10.1111/geb.13491 | Bias correlated with environmental niches can alter SDM inference; correlated-bias arms are scientifically necessary rather than a cosmetic stress test. | The reported results do not set an acceptable correlation or pass rate here. |
| Conn et al. (2017), *Methods in Ecology and Evolution*, doi:10.1111/2041-210X.12803 | Preferential spatial sampling can distort distribution inference and needs diagnostic/model-based treatment. | It does not establish that independent spatial fields are identified in this model. |
| Mäkinen et al. (2024), *Global Ecology and Biogeography*, doi:10.1111/geb.13792 | An integrated model with a presence-only-data-specific spatial latent effect is a relevant precedent for explicit sampling-process spatial structure. | Its Bayesian formulation and outcome measures are not a performance comparator. |

The initial NotebookLM run was not possible: its authentication check found a
valid cookie store but `token_fetch = false` because DNS/network resolution
failed on 2026-08-12.  These primary sources were therefore checked through
the fallback literature search.  A later NotebookLM corpus may supplement this
map, but cannot overwrite its source-specific boundaries without review.

## Design consequences

1. The model needs two declared spatial processes: an ecological field observed
   by both sources and a GBIF-only bias field.  A one-field spatial control is
   not a test of their separation.
2. The DGP must vary source support and ecological--bias field alignment;
   otherwise successful separation would be built into the fixture.
3. The campaign must distinguish increasing-domain from infill sampling.  A
   larger count of tightly clustered cells is not evidence for range or
   field-separation recovery.
4. The resulting evidence is synthetic, relative-intensity evidence only.  It
   does not establish detection, occupancy, absolute abundance, empirical
   performance, or generic preferential-sampling correction.

## Repositories and package landscape

`gllvmTMB` supplies an independently authored SPDE mesh/projection layer, but
the retained iSDM route is nonspatial.  The existing `spatial_indep()` and
`spatial_latent()` terms are one-field controls; their package tests cannot be
credited as two-field iSDM evidence.  `gllvm`, `Hmsc`, `spOccupancy`,
`glmmTMB`, and `sdmTMB` are not ranked by this note.
