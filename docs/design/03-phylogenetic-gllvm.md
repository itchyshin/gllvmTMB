# Phylogenetic GLLVM Contract

This note records the current phylogenetic stacked-trait contract
after the long/wide reader sweep and the "two-U" naming decision.
It adapts the useful parts of the legacy phylogenetic design notes to
the current package vocabulary.

## Reader Problem

A comparative-methods user has one row unit per species and several
traits per species. They want to separate trait covariance that follows
the phylogeny from species-level covariance that does not.

The current public examples should show both:

- long data: one row per `(species, trait)` observation;
- wide data-frame data: one row per species, one column per trait,
  using `traits(...)` on the formula left-hand side.

`gllvmTMB_wide()` is not the primary shortcut for this row-phylogeny
case because that matrix wrapper treats matrix columns as the trait
axis. It is the natural matrix entry point for site-by-species or
unit-by-response matrices where the response columns are the biological
traits/species/outcomes being modelled.

## Mathematical Contract

The phylogenetic tier is

```text
g_phy ~ MVN(0, Sigma_phy x A)
```

where `A` is the phylogenetic correlation matrix or the sparse inverse
derived from the tree. The non-phylogenetic species tier is

```text
g_non ~ MVN(0, Sigma_non x I)
```

The paired decomposition is

```text
Sigma_phy = Lambda_phy Lambda_phy^T + Psi_phy
Sigma_non = Lambda_non Lambda_non^T + Psi_non
```

`Psi_phy` and `Psi_non` are diagonal matrices of trait-specific
unique variance (the Greek letter Psi, matching the factor-
analysis / SEM convention; see `docs/dev-log/decisions.md`
2026-05-14 notation reversal). The legacy nickname "two-U" may
remain in file names, function names, and task labels, but
public math uses `\boldsymbol\Psi` / `\psi_t` -- bold capital
Psi for matrices, italic lowercase psi (subscripted by trait)
for the per-trait scalars from `extract_phylo_signal()`.

When `Psi_phy` is not separately identifiable from
`Lambda_phy Lambda_phy^T` (small `n_species`, weak phylogenetic
signal, single-replicate-per-tip), the canonical fallback is the
**three-piece form**:

```text
Omega = Lambda_phy Lambda_phy^T + Lambda_non Lambda_non^T + Psi
```

with a single non-tier-specific diagonal `Psi` (the only
unique-variance matrix in the fit; comes from the species-level
`unique()` term).

## R Syntax Alignment

| Purpose | Long syntax | Wide data-frame syntax |
|---|---|---|
| Trait intercepts | `value ~ 0 + trait` | `traits(t1, t2) ~ 1` |
| Phylogenetic shared covariance | `phylo_latent(species, d = K, tree = tree)` | same |
| Phylogenetic unique diagonal | `phylo_unique(species, tree = tree)` | same |
| Non-phylogenetic unique diagonal | `unique(0 + trait \| species)` | `unique(1 \| species)` |
| Full phylogenetic fallback | `phylo_dep(0 + trait \| species, tree = tree)` | `phylo_dep(1 \| species, tree = tree)` |

Species-axis phylogenetic calls such as `phylo_latent(species, ...)`
already name their phylogenetic axis, so the `traits(...)` RHS expander
leaves them unchanged. Bar-style covariance terms such as
`unique(1 | species)` and `phylo_dep(1 | species)` expand to the
explicit trait-stacked form.

## Current Implementation Map

- `phylo_latent(species, d = K, tree = tree)` activates the
  reduced-rank phylogenetic block (`use$phylo_rr`).
- `phylo_unique(species, tree = tree)` paired with `phylo_latent()`
  activates the phylogenetic diagonal block (`use$phylo_diag`).
- `phylo_unique(species)` alone is retained as the legacy diagonal
  phylogenetic mode and is equivalent to the `phylo_indep()` /
  `phylo_unique()` diagonal intent.
- `extract_Sigma(fit, level = "phy", part = "shared")` returns
  `Lambda_phy Lambda_phy^T`.
- `extract_Sigma(fit, level = "phy", part = "unique")` returns the
  diagonal vector `s_phy`.
- `extract_Sigma(fit, level = "phy", part = "total")` returns
  `Sigma_phy`.
- `compare_dep_vs_two_U()` refits with `phylo_dep + dep` and compares
  total `Sigma_phy` and `Sigma_non`.
- `compare_indep_vs_two_U()` refits with `phylo_indep + indep` and
  compares only per-trait diagonal totals.

## Identifiability Guidance

There are three different success levels:

1. The model converges with finite likelihood.
2. The total `Sigma_phy` and `Sigma_non` are stable enough to
   interpret.
3. The split into `Lambda Lambda^T` and `S` is stable across ranks,
   starts, and reasonable comparator fits.

Level 2 is usually the biological target. Level 3 is more fragile,
especially with small trees, weak phylogenetic signal, or exploratory
rank choices. The article should therefore teach users to interpret
total covariance first and to treat the diagonal/shared split as a
rank-sensitive decomposition.

## What This Does Not Change

This note does not change the formula grammar, likelihood,
parameterisation, exported functions, or the 3 x 5 keyword grid. It
documents how the existing current-code path should be explained in
articles and examples.
