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

## Status (Slice 4, 2026-08-16)

Ordinary GROUP random intercepts move from deferred to admitted -- a
different axis from Slices 1-2 (source/mode of the phylogenetic surface):
this slice is about ordinary, non-phylogenetic grouping structure. (Slice 3,
the spatial mode axis, is reserved for future work and is NOT part of this
slice; every spatial cell stays BLOCKED, unchanged.)

- **Admitted:** a generic `(1 | group)` random intercept (engine kind
  `re_int`, `src/gllvmTMB.cpp`'s `re_int` block). Verified against the
  engine's own indexing: the group id is read off the AFTER-expansion
  pseudo-trait data (`R/fit-multi.R`), so every one of a multinomial
  observation's `K-1` baseline-contrast rows carries the SAME group id and
  gets the SAME additive draw. This is a **baseline-vs-rest** group effect,
  not a per-category one: the shared shift moves `P(y = baseline)` versus
  `P(y != baseline)` and leaves the odds between any two NON-baseline
  categories unchanged -- WITHIN one fit, across groups (pinned empirically:
  the log-odds between the two non-baseline categories has sd = 0 across all
  900 observations of a `G = 20`, `n_per_g = 5` fixture, tolerance 1e-6;
  `test-matrix-multinomial-unit.R`). `sigma_re`'s substantive interpretation
  is therefore **reference-category-specific**. **Correction to an earlier
  draft of this section (this task, caught by a failing test):**
  re-labelling `baseline` is **NOT** a reparameterisation of the same
  model, so it is not only `sigma_re` that changes under a different
  baseline -- the fitted response-scale probabilities change too. Under
  `baseline = 1`, `eta = (0, b0_2 + u_g, b0_3 + u_g)` constrains the
  log-odds *between categories 2 and 3* to be constant across groups (no
  `u_g` term in `eta_3 - eta_2`); under `baseline = 3` the SAME engine
  instead shares a (new) `u_g` between categories 1 and 2, constraining
  *their* log-odds to be constant instead -- a genuinely different
  parametric restriction on the model space, not the same distribution
  under two labels (unlike the fixed-effects-only case, where relabelling
  really is a reparameterisation; see `test-multinomial.R`'s existing
  baseline-invariance tests, which have no random-effect term).
- **Admitted:** the non-phylogenetic `cluster`/`cluster2` diagonal tier --
  `indep(0 + trait | g)` via the `cluster =`/`cluster2 =` arguments, and the
  soft-deprecated standalone `unique()` alias (the SAME engine path, only the
  printed label differs). `use_diag_species` (cluster) and `use_diag_cluster2`
  (cluster2) are LITERALLY IDENTICAL engine math (`eta(o) += q_sp(t,
  species_id(o))` vs `eta(o) += r_c2(t, cluster2_id(o))`,
  `src/gllvmTMB.cpp`) on two different grouping columns, so both are admitted
  together. This gives `D` independent per-CONTRAST (pseudo-trait) variances
  at that grouping -- the per-category random intercept most users actually
  want.
- **New: an OLRE guard.** For a fid-16 fit, if EVERY level of an admitted
  `(1 | g)` or cluster/cluster2 `indep()` grouping covers exactly one
  categorical observation (`.multinom_group_`), the term is an
  observation-level random effect (OLRE) in disguise: the softmax latent
  scale is fixed (no free residual-dispersion parameter, unlike a
  Gaussian/count response), so a per-observation intercept shared across its
  own `K-1` contrast rows is not identifiable from the fixed effects. This is
  a WHOLE-FIT check against `data` (needs the observation-to-group mapping,
  not just the covstruct shape), so it is a SEPARATE typed guard
  (`gllvmTMB_multinomial_olre_not_admitted`), layered on top of an
  individually-admitted classification -- mirroring how the multi-kernel
  override (Slice 1) sits on top of an individually-admitted kernel cell.
- **Stays BLOCKED:** `common = TRUE` (the `scalar()` modifier) at the
  cluster/cluster2 tier -- the generic engine has no common-pooling map for
  `use_diag_species`/`use_diag_cluster2` (unlike the unit/unit_obs
  `diag_B_common`/`diag_W_common` map tricks), so admitting it would silently
  ADMIT the term while silently IGNORING the `common = TRUE` request rather
  than actually pooling to one shared level -- refused explicitly, matching
  `phylo_scalar()`/`animal_scalar()`/`kernel_scalar()`. The `unit_obs`
  grouping tier and `latent()`/`dep()` at the cluster/cluster2 tiers also
  stay BLOCKED (no engine slot).

Recovery campaign staged at
`dev/multinomial-structured/campaign-s4-group-intercepts.R` (`--mode full`
NOT run), gated on `dev/multinomial-structured/pass-criteria-s4.md` (DRAFT,
pending sign-off). Register row FAM-20F.

## See also

- `docs/design/02-family-registry.md` — the unordered categorical family
  registry entry and its current admitted-set statement.
- `docs/design/84-*` (Tier-2a `phylo_latent()`) and the Tier-2b item 2a-ii
  shared-`latent()` cross-family work, both referenced from
  `R/families.R`'s `multinomial()` roxygen.
- `R/multinomial-fence.R` — the admission fence this design will extend.
