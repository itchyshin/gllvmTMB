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

## Status (Slice 2, 2026-08-16)

The phylo MODE axis (dep = full unstructured V, indep/standalone unique =
diagonal V) and its animal/kernel twins move from deferred to admitted, for
all three sources (phylo/animal/kernel; single-name only for kernel):

- **Admitted:** `phylo_dep()`, `animal_dep()`, `kernel_dep()` -- intercept-only
  `*_dep(0 + trait | id)`, resolving `d = n_traits` and populating the SAME
  `phylo_rr`/`theta_rr_phy` slot as `phylo_latent(d = n_traits)`. This is the
  IDENTICAL unconstrained packed-triangular parameterisation
  (`gll_unpack_rr_loadings()`, src/gllvmTMB.cpp), not merely V-equivalent --
  the genuinely `exp()`-transformed Cholesky diagonal belongs to the
  AUGMENTED `*_dep(1 + x | ...)` slope engine (`theta_dep_chol`), a different
  covstruct kind that stays BLOCKED. **Correction to the original task
  brief for this slice:** the brief characterised `*_dep()`'s diagonal as
  exp()-positive in contrast to `phylo_latent()`'s unconstrained diagonal;
  that description is only true of the blocked augmented-slope engine, not
  the intercept-only cell admitted here. Verified numerically identical to
  `phylo_latent(d = K - 1)` at the V level (tolerance 1e-4, 3 DGP seeds; see
  `test-matrix-multinomial-phylo.R` and register row FAM-20D).
- **Admitted:** `phylo_indep()`, `animal_indep()`, `kernel_indep()`, and their
  soft-deprecated standalone `*_unique()` aliases -- diagonal Lambda_phy (the
  strict lower triangle pinned to 0 via a TMB map), giving D independent
  per-contrast phylogenetic variances with NO among-category correlation.
  Confirmed on a real fit that `extract_Sigma(level = "phy")` returns the
  per-contrast diagonal explicitly (off-diagonal < 1e-8), never a collapsed
  scalar.
- **Stays BLOCKED:** `phylo_scalar()`/`animal_scalar()` (route through the
  unrelated `propto` engine, blocked since Slice 0) and `kernel_scalar()`
  (shares the SAME `phylo_rr` markers as the now-admitted `kernel_indep()`,
  distinguished only by `.kernel_mode == "scalar"` -- a load-bearing
  distinction this slice's classifier now carries explicitly). A null-DGP
  probe (`dev/multinomial-structured/probe-scalar-null.R`) evidences the
  refusal's motivation without deciding it: on `V_true = 0` data,
  `phylo_indep()` correctly recovers near-zero variance (5/5 seeds), but
  `phylo_dep()`'s `rho_hat` rails toward ±1 in 4/5 seeds despite a PD
  Hessian -- a naive scalar collapse across the (I+J) contrast geometry has
  no natural null value to check against. Augmented-slope forms,
  `*_latent(unique = TRUE)`, and multi-kernel also remain BLOCKED, along
  with everything else in the Scope section above.

Recovery campaign staged at
`dev/multinomial-structured/campaign-s2-phylo-dep-indep.R` (timing/smoke run,
`--mode full` NOT run), gated on
`dev/multinomial-structured/pass-criteria-s2.md` (DRAFT, pending sign-off).

## See also

- `docs/design/02-family-registry.md` — the unordered categorical family
  registry entry and its current admitted-set statement.
- `docs/design/84-*` (Tier-2a `phylo_latent()`) and the Tier-2b item 2a-ii
  shared-`latent()` cross-family work, both referenced from
  `R/families.R`'s `multinomial()` roxygen.
- `R/multinomial-fence.R` — the admission fence this design will extend.
