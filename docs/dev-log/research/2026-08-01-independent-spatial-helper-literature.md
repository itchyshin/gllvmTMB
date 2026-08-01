# Independent spatial-helper literature and API specification

Date: 2026-08-01  
NotebookLM notebook: `c0994d01-a66e-4530-96c1-934aaac0fd82`  
Notebook title: *gllvmTMB spatial helpers — curated literature specification*

## Question and authorship boundary

This review specifies gllvmTMB's R-side mesh, finite-element, projection, CRS,
and range-plot helpers from primary literature and public package APIs. It was
completed before the final implementation audit. sdmTMB source code was not a
NotebookLM source and was not used to specify the implementation. An isolated
installed sdmTMB package was consulted only after implementation as a
black-box behavioural comparator.

## Curated sources

All six sources were verified `ready` in the notebook.

1. Lindgren, Rue, and Lindstrom (2011), *An explicit link between Gaussian
   fields and Gaussian Markov random fields: the stochastic partial
   differential equation approach* ([record](https://www.research.ed.ac.uk/en/publications/an-explicit-link-between-gaussian-fields-and-gaussian-markov-rand/));
   NotebookLM source `2e4fdade-2f1c-4167-b47d-7be776aa896a`.
2. fmesher, [`fm_fem()` public API](https://inlabru-org.github.io/fmesher/reference/fm_fem.html);
   source `9e0cd764-4cfd-4123-b6ed-5cd8b255649c`.
3. fmesher, [INLA-to-fmesher conversion guide](https://inlabru-org.github.io/fmesher/articles/inla_conversion.html);
   source `516d8db7-c038-45e2-8908-21c44f1158a0`.
4. fmesher, [`fm_mesh_2d()` public API](https://inlabru-org.github.io/fmesher/reference/fm_mesh_2d.html);
   source `7406b1d1-1a3c-479c-b8c7-4793a642c156`.
5. sf, [`st_transform()` public API](https://r-spatial.github.io/sf/reference/st_transform.html);
   source `f6a13d55-72c4-4912-af73-33060005d478`.
6. Fuglstad et al., *Exploring a New Class of Non-stationary Spatial Gaussian
   Random Fields with Varying Local Anisotropy*
   ([arXiv:1304.6949](https://arxiv.org/abs/1304.6949)); source
   `65bddaba-999f-48e9-89d2-3ba7e8e249bf`.

## Specification extracted from the sources

The SPDE approach represents a continuous Gaussian field through a sparse
finite-element/GMRF approximation on a triangulation. For gllvmTMB's existing
isotropic Matérn route, the R helper must therefore deliver a triangular mesh,
the finite-element matrices used in

\[
Q(\kappa) = \kappa^4 M_0 + 2\kappa^2 M_1 + M_2,
\]

and a sparse basis/projection matrix from observation coordinates to mesh
vertices. The public fmesher mapping used here is `fm_fem(order = 2)` for
`c0`, `g1`, and `g2`, and `fm_basis(loc = ...)` for the observation basis.
This mapping is an API contract; the literature establishes the weak
finite-element/SPDE construction but does not prescribe gllvmTMB's R object
field names or mesh-search algorithm.

The helper-level invariants are consequently: finite sparse square FEM
matrices with conformable dimensions; a finite sparse projection with one row
per observation; and projection row sums equal to one. A requested knot count
is subordinate to these invariants. If consolidation yields a degenerate mesh
or zero-row projection, the search must return the closest valid mesh rather
than an exact but unusable vertex count.

For CRS conversion, `sf::st_transform()` owns the transformation semantics.
gllvmTMB owns validation of longitude/latitude columns, conventional UTM-zone
selection, output names, and kilometre/metre scaling. The sf documentation
does not specify how a package should choose one UTM zone for data spanning
zones or hemispheres, so this remains an explicit gllvmTMB helper policy with
warnings.

Directional anisotropy requires a direction-dependent operator or matrix such
as `H`; unequal ellipse axes must be derived from that estimated structure.
The current gllvmTMB TMB engine reports only scalar `kappa` (or the shared
random-slope equivalent) and therefore specifies an isotropic model. Setting
`H = I` is a model assumption, not an anisotropy estimate. The honest plotting
contract is thus a circle of radius `sqrt(8) / kappa`, clearly labelled as
isotropic, while true anisotropy remains deferred until the likelihood itself
estimates the required matrix.

## NotebookLM synthesis and media receipt

NotebookLM was asked separately about the mesh/FEM mapping, CRS boundary, and
anisotropy boundary, and its cited answers were reconciled against the source
pages above. The following requested artefacts completed:

- Report `7924abe5-1b48-44a0-ba91-0527085f8328`, *Briefing on the SPDE
  Approach and the fmesher Framework for Spatial Modeling*.
- Audio `3cc75065-3888-49cd-baec-c83d5c70ed98`, *Scaling Spatial Modeling
  with SPDE and fmesher*.
- Video `339ddde9-ffd4-4823-ac0d-b8f56f8d6c50`, *Spatial Modeling Pipeline*.

NotebookLM is a synthesis aid, not the authority. The primary literature,
public API documentation, repository equations, and executable invariant
tests are the load-bearing evidence.
