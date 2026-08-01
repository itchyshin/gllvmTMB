# After-task report -- independent spatial helpers

## Goal

Replace the formerly inherited R-side spatial helper code with independently
authored gllvmTMB code, remove the sdmTMB citation obligation, and retain a
plain courtesy acknowledgement.

## Mathematical contract

No likelihood, formula grammar, response family, or covariance parameterisation
changed. The helper still supplies the sparse observation projection `A_st` and
finite-element matrices `M0`, `M1`, and `M2` used by the existing SPDE precision
`Q = kappa^4 M0 + 2 kappa^2 M1 + M2`.

## Implementation and API

`make_mesh()` now returns `gllvmTMBmesh`. Valid legacy `sdmTMBmesh` objects are
accepted temporarily with a lifecycle warning. CRS conversion is independently
implemented through sf's public transformation API. The inherited anisotropy
surface is replaced by a clear unsupported-feature error because gllvmTMB does
not currently estimate anisotropy.

## Evidence

Focused helper tests, including FEM/projection invariants and dense-FEM
rejection, and spatial dispatch/orientation/Stage-4 integration tests passed.
`pkgdown::check_pkgdown()` and a local no-manual package check passed. The
developer-only oracle `dev/verify-sdmtmb-spatial-oracle.R` passed at `1e-10` for
selected mesh/FEM and CRS outputs against isolated sdmTMB 1.1.0; the pinned
receipt is `docs/dev-log/artifacts/2026-08-01-sdmtmb-spatial-black-box-oracle.md`.
sdmTMB was not added to package dependencies or used as implementation material.

## Documentation and provenance

Updated DESCRIPTION, CITATION, COPYRIGHTS, README, vignette, spatial design
notes, pkgdown navigation, roxygen, and generated Rd. The acknowledgement says
that sdmTMB informed the original spatial interface but no source code is
included or adapted. SPA-01 remains `covered` in the validation-debt register.

## Consistency audit

`rg -n -i 'inherited from sdmTMB|inherits sdmTMB|sdmTMB.*cite|cite.*sdmTMB|from which gllvmTMB|SPDE inheritance' AGENTS.md CLAUDE.md README.md DESCRIPTION R inst vignettes docs/design _pkgdown.yml NAMESPACE man`
returned no current inheritance/citation-obligation claims. `git diff --check`
passed.

## Tests of the tests

New tests cover malformed coordinates, native class/field contract, RNG-state
preservation, legacy migration warning, CRS scaling and invalid inputs, and
unsupported anisotropy errors. These are boundary and failure-path tests; Stage
4 supplies the R-to-TMB acceptance path.

## Team learning

Curie identified the untested helper and fit-boundary contract. Rose mapped the
provenance cascade and preserved legitimate sdmTMB scope references. Gauss's
boundary is that behavioral comparison validates outputs but never justifies
copying implementation.

## Issue ledger and roadmap

Created drmTMB issue [#881](https://github.com/itchyshin/drmTMB/issues/881) for
future independent mesh/SPDE Gaussian-intercept planning. Roadmap tick: N/A;
this is a provenance/API-quality rewrite, not a new advertised capability.

## Limitations and next action

The isolated sdmTMB oracle remains outside CRAN tests and validates behaviour,
not authorship. Anisotropy remains unsupported. The full suite completed with
the new spatial-helper tests green but two unrelated existing failures: a
`funcphylo` spatial-recovery convergence fixture and a vdiffr
correlation-ellipse snapshot. The D-43 re-review panel was unanimous DONE. The
final no-manual `devtools::check()` failed on that unrelated snapshot and
pre-existing namespace/environment warnings, so this branch is
implementation-complete but not yet merge-ready.
