# After-task — Arc B: functional-phylogeography validated, extractable, documented (2026-07-09)

**Scope.** Turn the flagship functional-phylogeography capability from "fits (structure verified)"
into **validated + extractable + documented** — the v1.0 Arc B goal. Model per the maintainer's
framing: the **spatial** structure of traits is the object of inference; **phylogeny is a diagonal
control** (not an ordination).

## Outcome

### Validated (real-signal recovery)
New `tests/testthat/test-funcphylo-spatial-recovery.R` (gated, `skip_on_cran`) + multi-seed study
`dev/funcphylo-spatial-recovery.R`. Fitting the spatial-focus recipe on Gaussian data with known
signal (12 seeds, n_site=50, n_sp=28):

- **12/12 converged** (scale-free verdict `fit_health$converged`).
- **Spatial ordination (the focus) recovers:** spatial-loading-direction cosine vs truth **median
  0.993, min 0.728**; rank-1 correlation-structure **max-abs error 0.000 across all seeds**.
- **Phylo control works:** diagonal `phylo_indep` recovers signal across all traits (median H²
  0.72 / 0.71 / 0.54 at n_sp=28), improving with more species.
- Recovery is asserted on **rotation/scale-invariant** quantities only (loading direction +
  correlation structure) — raw loadings are rotation-identified and the SPDE reparameterises scale.

The validated recipe (`unit="site", unit_obs="site_species", cluster="species", mesh=mesh`):
```r
value ~ 0 + trait +
  spatial_latent(0 + trait | coords, d = 1) +   # spatial ordination — the focus
  latent(0 + trait | site, d = 1) +             # non-spatial between-site ordination
  latent(0 + trait | site_species, d = 1) +     # within-site residual
  phylo_indep(0 + trait | species, tree = tree) + indep(0 + trait | species)  # phylo control (diagonal)
```

### Extractable
Issue **#588** (`extract_Sigma_table` could not reach the `cluster2` tier) was **already fixed on
`main`** by `35fe3513` (2026-07-05, after the issue was filed), with coverage in
`test-extract-sigma-table.R:173`. Verified and **closed** the stale issue with evidence.

### Documented
New **`docs/design/78-functional-phylogeography-recipe.md`** — the canonical recipe, the tier-slot
architecture (4 reduced-rank slots; `cluster2` diagonal-only), the non-obvious **routing rule**
(`cluster` keys the A/tree; the co-located plain `latent` rides `unit`), the honest
diagonal-vs-cross-trait phylo-control caveat, the identifiability requirements, and the recovery
evidence.

## Checks
- `devtools::test(filter = "funcphylo-spatial-recovery")` — **PASS** (converged + spatial cosine +
  correlation structure), warnings only (deprecation notes; now using `level = "spatial"`).
- `dev/funcphylo-spatial-recovery.R` — 12/12 converged, recovery numbers above.
- No engine/R source changed (validation + docs only).

## Follow-up (post-1.0 / other arcs)
- **Generic multi-tier reduced-rank** (RR at `cluster2` / arbitrary tiers) — an L-sized TMB
  likelihood change; lets the ordination live at more than one grouping factor. Named in the plan.
- **QG animal-model** variant (`animal_latent(id) + latent(id) + latent(record) + indep(nest)`) —
  fit + routing verified (after-task 2026-07-09-multilatent-capability-findings), real-signal
  recovery not yet run; carries structural aliases (`nest≡mother`, G-vs-common-env) needing a
  decoupled design.
- Phylo control recovers better with n_species → ~100; the diagonal control captures per-trait phylo
  variance, not cross-trait phylo covariance (use `phylo_dep` if the latter matters).
