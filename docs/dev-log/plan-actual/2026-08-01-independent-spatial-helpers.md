# Plan versus actual -- independent spatial helpers

Date: 2026-08-01

Plan: Ultra Plan -- independent gllvmTMB spatial helpers

## Delivered as planned

- Work was isolated on `codex/spatial-independent-helpers` in a clean worktree
  created from `origin/main`; the user's dirty checkout was not modified.
- `R/mesh.R` and `R/crs.R` were independently rewritten from the
  Lindgren-Rue-Lindstrom SPDE specification and public fmesher/sf APIs.
- New objects are `gllvmTMBmesh`; a valid legacy `sdmTMBmesh` is temporarily
  normalized with a lifecycle warning, and `sdm_spatial_id` is removed.
- The native TMB interface remains the same: the observation projection and
  `c0/g1/g2` matrices feed the existing `M0/M1/M2` precision construction.
- A post-implementation, developer-only black-box comparison against isolated
  sdmTMB 1.1.0 passed at tolerance `1e-10`; sdmTMB is neither a dependency nor
  a CRAN-test oracle.
- Citation/provenance language now requires gllvmTMB and TMB citations only,
  with a plain courtesy acknowledgement to sdmTMB and no bibliography entry.
- drmTMB future-work issue #881 was created with the planned narrow scope.

## Material deviations

### Anisotropy was narrowed to the model gllvmTMB actually fits

The plan proposed rewriting anisotropy geometry around a reported `H`. The
implementation audit found that `src/gllvmTMB.cpp` reports scalar `kappa` but
does not estimate or report `H`; changing that would violate the locked
decision to leave the TMB likelihood unchanged and defer new spatial
capabilities. The delivered `plot_anisotropy*()` contract therefore draws the
isotropic practical-range circle `sqrt(8) / kappa`, labels `H = I` as a model
assumption, and returns `anisotropy_estimated = FALSE`. It rejects non-spatial,
delta, spatiotemporal, and multi-model requests explicitly. True anisotropy
remains planned model work, not a plotting inference.

### Knot-count search became validity-first

The inherited fixed search range could produce a nominally small mesh with
non-finite FEM entries or a projection containing zero rows. The independent
search now scales its bounds to the coordinate span and accepts a candidate
only when the FEM and projection invariants hold. An exact requested count is
not guaranteed; the closest valid candidate is returned. This is a deliberate
correctness strengthening of helper behaviour, not a likelihood change.

### Compute escalation was unnecessary

The replacement matched the defined black-box FEM/projection/CRS fixtures to
`1e-10`, and a real spatial fit consumed the new helper output. The plan's
Totoro/DRAC escalation condition was therefore not triggered.

## Scope held

No TMB likelihood, family, formula keyword, spatial covariance
parameterisation, barrier feature, spatiotemporal feature, or drmTMB code was
implemented. Historical design notes that cite sdmTMB as a comparator or
sister-package boundary were retained; only false current inheritance and
citation-obligation claims were removed.

## Integration follow-through

The initial closeout correctly withheld merge readiness because three
repository-wide tests were red. At the maintainer's direction, the continuation
diagnosed and repaired all three rather than merging around them. It also fixed
the synthetic `some::wrapper()` dependency warning found by the full package
check. Current `origin/main`, including PR #885's AGHQ work, merged cleanly; a
combined focused suite confirmed that AGHQ routing and spatial mesh
normalisation coexist in `R/fit-multi.R`.

The exact combined tree passed the full no-manual package check with zero
errors. The remaining local warning was repository-network access plus the
synthetic fixture; after the fixture repair, the dependency-focused check had
zero warnings. The two remaining notes are local clock verification and macOS
`xcrun_db` detritus. Networked three-OS CI is therefore the final external gate,
not an unresolved package-level test failure.
