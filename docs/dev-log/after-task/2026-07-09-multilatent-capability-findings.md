# After-task — multi-latent tier capability + functional-phylo / QG recipes (2026-07-09)

**Scope.** A design investigation (no engine change) into how many reduced-rank (ΛΛᵀ) latent effects
gllvmTMB can carry across grouping levels, driven by two target models: a **functional
phylogeography** model (spatial + phylo + residual) and a **quantitative-genetics animal model**
(G + PE + maternal/common-environment). Evidence = code reads + fitted-object inspection on toy data
(a 5-lens workflow, adversarially verified). This note is the durable hand-off record so the next
session/tool resumes without re-deriving.

## Outcome (verified)

### Reduced-rank tier architecture
The engine exposes **4 distinct reduced-rank grouping slots** today, each a single-instance `ΛΛᵀ`
block gated by a scalar `use_rr_*` flag (no tier loop in `src/gllvmTMB.cpp`):

| Slot | Param | Grouping via | Reduced-rank source |
|---|---|---|---|
| B (`unit`) | `theta_rr_B` | `unit=` | plain `latent()` |
| W (`unit_obs`) | `theta_rr_W` | `unit_obs=` | plain `latent()` |
| cluster | `theta_rr_phy` | `cluster=` | **phylo/animal only** (`phylo_latent`/`animal_latent`); a *plain* `latent()` on that column routes to **B**, not cluster |
| spde | `theta_rr_spde_lv` | `coords`/`mesh` | `spatial_latent()` |

Plus intercept **and slope** RR per structured tier (`Lambda_*_slope`) and the Design-65 `kernel_*`
N-tier `Lambda_kernel` array. So **5+ ΛΛᵀ blocks with 2 structured is reachable in specific configs**;
what is **not** possible is reduced-rank at **5 distinct plain grouping factors** — the 5th plain tier
`cluster2` is **diagonal-only and hard-rejects `rr()`/`latent()`/`dep()`** before optimization
(`R/fit-multi.R:1690-1700`). The limit is **TMB-hard** for classic tiers (a new RR block needs a new
`PARAMETER_VECTOR` + recompile); only the `kernel_*` path is a data-driven N-tier loop.

### Co-location routing rule (the key mechanism)
A **structured + non-structured** pair on ONE grouping column composes because the **phylo/animal
term keys its loadings on `cluster`'s relatedness (A / tree)** while the co-located **plain `latent`
rides the `unit` slot** on the same column — two separate parameter vectors, never one covstruct
claimed twice. Practical rule: **`cluster=` must point at the factor whose A-matrix/tree you supply;
the co-located plain latent goes via `unit=`.**

### Verified fits-today recipes (distinct Λ blocks confirmed in `opt$par`, not just convergence)
**Functional phylogeography** (4 RR blocks; `unit="species", unit_obs="site_species", mesh=mesh`):
```r
value ~ 0 + trait +
  phylo_latent(0 + trait | species, d = 1, tree = tree) +  # Lambda_phy
  latent(0 + trait | species, d = 1) +                     # Lambda_B (non-phylo)
  latent(0 + trait | site_species, d = 1) +                # Lambda_W (residual)
  spatial_latent(0 + trait | coords, d = 1)                # Lambda_spde
```
`phylo_latent(species)` and `latent(species)` land as two **distinct** blocks (`rr_B` + `phylo_rr`
both TRUE) — neither ignored nor merged.

**QG animal model** (G + PE co-located on `id`; `unit="id", unit_obs="record", cluster="id",
cluster2="nest"`; pedigree via `pedigree_to_A()`, repeated records so PE ≠ residual):
```r
value ~ 0 + trait +
  animal_latent(0 + trait | id, d = 1, pedigree = ped) +   # G  -> theta_rr_phy (keyed on cluster A)
  latent(0 + trait | id, d = 1) +                          # PE -> theta_rr_B (keyed on unit)
  latent(0 + trait | record, d = 1) +                      # residual -> theta_rr_W
  indep(0 + trait | nest)                                  # c^2 -> cluster2 diagonal
```
**No collision** despite `unit==cluster==id`: G (`theta_rr_phy`) and PE (`theta_rr_B`) are numerically
distinct blocks.

**Caveat:** verified on pure-noise toy DGPs, so `Lambda_phy`/`Lambda_animal` correctly shrank to 0
(a free block at zero, not a dropped block). **Structure + routing are verified; nonzero
signal-recovery is NOT yet shown** — that is the follow-up validation.

## Semantics guard (a correction banked this session)
`phylo_latent(..., unique = TRUE)` = `Λ_phy Λ_phyᵀ + diag(ψ)` — a structured latent **plus a
DIAGONAL** per-trait residual, **NOT** a non-phylo ordination. The genuine "structured + non-structured
ordination" decomposition is **two separate `latent` terms** (as in the recipes above). Likewise
`animal_latent()` is **just G**; **PE is the separate `latent(...|id)`**, and PE separates from
residual only with **repeated records**. Do not equate `diag(ψ)` with a reduced-rank `ΛΛᵀ`. Apply the
`symbolic-alignment` skill before any "term X = concept Y" claim; `extract_phylo_signal` (H²) is the
ground-truth decomposition to read, not analogy.

## Identifiability (conditional — separate structural aliasing from weak identifiability)
- **Functional-phylo:** estimable under a Gaussian design with sites across a **range of pairwise
  distances** (nugget-vs-range), **A ≠ I** with real relatedness variation, and **within-cell
  replication** (multiple records per site×species) to split interaction from residual. Binary/sparse
  needs ~order-of-magnitude more data.
- **QG animal model:** carries **structural aliases no data fixes** — `nest ≡ mother` when each mother
  maps 1:1 to a nest (only their sum is identified); **G-vs-common-environment** without
  **cross-fostering**. These are "no without a decoupled design," not "practically hard."
- Arbiter = **recovery-vs-truth across an n / distance-spread / signal-strength ladder**, never
  `isTRUE(pdHess)`.

## Impact on the v1.0 plan
- **Arc B rescoped** (was "build cluster2 tier"): now **validation + docs** — (1) recovery-gate both
  recipes with a **real-signal DGP**; (2) fix **#588** (`extract_Sigma`/`extract_Sigma_table` cannot
  reach the cluster2 tier → cannot read the site/nest variance out); (3) per-family cluster2-diagonal
  validation (#356); (4) **document** the two recipes + the `cluster`-keys-the-A / `unit`-keys-the-plain
  routing rule.
- **Post-1.0:** **generic multi-tier reduced-rank** (RR at `cluster2` / arbitrary tiers) — an L-sized
  TMB likelihood change, best built on the existing `kernel_*` N-tier loop, gated off by default.
- Also confirmed post-1.0: reduced-rank ordination at *both* site and species simultaneously (same
  slot limit).

## Checks
- Fits verified live (`devtools::load_all`, `NOT_CRAN=true`, Gaussian, toy data): both recipes
  converge (`fit_health$converged = TRUE`); distinct Λ blocks confirmed from `opt$par`.
- No source files changed by this investigation (design/validation only).

## Follow-up
Real-signal recovery test for both recipes + the `#588` cluster2 extraction fix (Arc B). Julia parity
and the paper remain post-1.0 (R-first to CRAN).
