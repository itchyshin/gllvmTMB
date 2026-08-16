# Design 122 — the full multinomial() structured-dependency surface

**Status: STUB.** Filed as part of Slice 0 (covstruct-keyed admission fence,
2026-08-16), which closed the leaks in the *current* two-cell admitted set
(`R/multinomial-fence.R`: fixed effects, a shared unit-tier `latent()`
ordination, `phylo_latent()`). This document reserves the design number for
the consolidation slice that decides, cell by cell, which of the remaining
deferred keywords (`dep()`, explicit `unique()`/`indep()`, `phylo_dep()`,
`phylo_indep()`, `phylo_unique()`, `phylo_scalar()`, `animal_*()`,
`kernel_*()`, `spatial_*()`, the `cluster`/`cluster2`/`unit_obs` grouping
tiers, and `mi()` predictor terms combined with a multinomial trait) should
be admitted next, and what each cell's identifiability story is once a
categorical response spans \(K-1\) latent liability dimensions rather than
one.

## Scope (to follow)

A per-cell table (source x mode, mirroring the canonical 5 x 3 keyword grid)
recording: engine feasibility, identifiability requirements (replication,
category count, baseline stability), and priority. Not written yet — this
stub only claims the design number so Slice 0's admission-table comment in
`R/multinomial-fence.R` has somewhere to point.

## Status (Slice 1, 2026-08-16)

Two more cells moved from deferred to admitted, both loadings-only
(`unique = FALSE`) and both pure engine sugar over the already-admitted
`phylo_latent()` `phylo_rr` route (no engine/C++ change):

- `animal_latent(species, A = A, d = k)` — admitted. Numerically verified
  identical to `phylo_latent()` (matched TMB objective, matched `V`); see
  `tests/testthat/test-matrix-multinomial-phylo.R` and register row FAM-20C.
- Single-name `kernel_latent(species, K = K, d = k, name = nm)` — admitted.
  Same verification. Multiple `kernel_latent()` names in one fit
  (multi-kernel) stay BLOCKED — that check is whole-fit, not per-cell.

`unique = TRUE` on either keyword and every other `animal_*`/`kernel_*` mode
(`*_indep`, `*_dep`, `*_scalar`, `kernel_unique`) remain deferred, along with
everything else this stub's Scope section lists. See
`R/multinomial-fence.R`'s `.mn_admission_table` for the authoritative
per-cell status.

## See also

- `docs/design/02-family-registry.md` — the unordered categorical family
  registry entry and its current admitted-set statement.
- `docs/design/84-*` (Tier-2a `phylo_latent()`) and the Tier-2b item 2a-ii
  shared-`latent()` cross-family work, both referenced from
  `R/families.R`'s `multinomial()` roxygen.
- `R/multinomial-fence.R` — the admission fence this design will extend.
