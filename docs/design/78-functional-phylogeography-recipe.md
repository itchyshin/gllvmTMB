# Design 78 — Functional-phylogeography recipe (spatial focus, phylo control)

**Status:** recipe **validated** (2026-07-09) — fits + routes correctly, and the spatial ordination
recovers to truth under a real-signal recovery study (Arc B). This doc is the canonical, user-facing
recipe for the flagship functional-phylogeography model plus the tier-routing rules a user could not
guess.

## The model

**Functional phylogeography** here means: *the spatial structure of multivariate traits is the object
of inference; phylogeny is a nuisance that must be controlled for.* Therefore the reduced-rank
**ordination** (latent axes) belongs at the **site / spatial** level, and phylogeny enters as a
**diagonal per-trait control**, not as an ordination.

```r
value ~ 0 + trait +
  spatial_latent(0 + trait | coords, d = 1) +      # spatial trait ordination  ← the focus (reduced-rank)
  latent(0 + trait | site, d = 1) +                 # non-spatial between-site ordination (reduced-rank)
  latent(0 + trait | site_species, d = 1) +         # within-site residual
  phylo_indep(0 + trait | species, tree = tree) +   # phylogeny CONTROL (per-trait, diagonal)
  indep(0 + trait | species)                        # non-phylo species variance (diagonal)
# gllvmTMB(..., unit = "site", unit_obs = "site_species", cluster = "species", mesh = mesh)
```

Data columns: `site` (between-unit), `site_species` (globally-unique within-unit cell), `species`
(the cluster/phylo axis, tip labels matching `tree`), `lon`/`lat` (coords for the mesh), `trait`,
`value`. `mesh <- make_mesh(df, c("lon","lat"), cutoff = ...)`.

## Why this shape — the tier-slot architecture

The engine exposes **four reduced-rank (ΛΛᵀ) grouping slots**: `unit`/B, `unit_obs`/W, `cluster`
(reduced-rank there is **phylo/animal only**), and `spde`. The fifth grouping tier, `cluster2`, is
**diagonal-only** (hard-rejects `latent()`/`rr()` — `R/fit-multi.R:1690-1700`). So **latent ordination
axes can live at only one of {site, species}; the other must be diagonal** — you pick by science:

| Question | Ordination at | Control at | Recipe |
|---|---|---|---|
| **Spatial trait structure** (this doc) | site (`spatial_latent` + `latent(site)`) | species (diagonal `phylo_indep` + `indep`) | above |
| Phylogenetic trait ordination | species (`phylo_latent` + `latent(species)`) | site (diagonal `indep(site)` + `spatial_indep`) | Design 76 §7 / after-task 2026-07-09 |

Reduced-rank ordination at **both** levels at once is **not** possible today (one reduced-rank
between-unit slot); it is a post-1.0 engine feature (generic multi-tier reduced-rank).

## The routing rule (not guessable — document it)

A structured + non-structured pair co-located on ONE grouping column works because the
**phylo/animal term keys its loadings on `cluster`'s relatedness (A / tree)**, while a co-located
plain `latent` rides the **`unit`** slot on the same column — two separate parameter vectors. Rule:

- **`cluster =` must point at the factor whose A-matrix / tree you supply** (here `species`).
- In the *phylo-focus* variant the diagonal **site** control is routed to **`cluster2 = "site"`**
  (because `cluster` is reserved for the tree match).

## Modelling caveat (state it honestly)

Diagonal `phylo_indep` controls each trait's phylogenetic **variance** (phylo signal per trait) but
**not** the cross-trait phylo **covariance** (correlated evolution). If co-evolving traits could
masquerade as spatial covariance, the fuller control is `phylo_dep` (full phylo covariance) — heavier
and usually unnecessary when phylogeny is a genuine nuisance. For "control for phylogenetic
non-independence," the diagonal form is the standard, defensible choice.

## Identifiability requirements

- Sites sampled across a **range of pairwise distances** (nugget-vs-range) so `spatial_latent`
  separates from the non-spatial `latent(site)`.
- **Within-cell replication** (multiple records per site×species) so the within/residual tier
  separates from the observation residual.
- `A ≠ I` with real relatedness variation and enough tips for the phylo control to be meaningful.
- Recovery-to-truth across an n / distance-spread / signal ladder is the arbiter — never
  `isTRUE(pdHess)`.

## Evidence

- **Fits + routes correctly:** verified from `opt$par` (distinct Λ blocks; `opt$convergence = 0`) —
  after-task `docs/dev-log/after-task/2026-07-09-multilatent-capability-findings.md`.
- **Real-signal recovery — validated** (`tests/testthat/test-funcphylo-spatial-recovery.R` +
  `dev/funcphylo-spatial-recovery.R`, 12 seeds, n_site=50, n_sp=28, Gaussian): **12/12 converged**;
  the spatial ordination — the object of inference — recovers with **spatial-loading-direction cosine
  median 0.993 (min 0.728)** and **rank-1 correlation-structure max-abs error 0.000 across all
  seeds**. The diagonal **phylo control** recovers meaningful signal across all traits (median H²
  0.72 / 0.71 / 0.54 at n_sp=28), improving with more species. Recovery is checked on rotation/
  scale-invariant quantities only (loading direction + correlation structure), never raw loadings.

## Related
Design 76 (structured × X_lv / phylo), after-task 2026-07-09 (multi-latent capability),
issue #588 (cluster2 Sigma-table extraction — fixed 35fe3513).
