# Coevolution Kernel Article Plan

Date: 2026-05-31
Branch: `codex/kernel-c1-equivalence`
Status: planning note only; do not publish before Design 65 C2 passes.

## Purpose

The eventual public article should teach the cross-lineage coevolution
model as a worked phylogenetic example, not as a parser demonstration.
It should answer one applied question: when host and partner lineages are
linked by an association matrix `W`, can a stacked-trait model estimate
the host-by-partner trait covariance block
`Gamma = Lambda_H Lambda_P^T`?

## Placement

Preferred placement is a new Tier-1 article beside the phylogenetic
worked examples, with cross-links from the existing phylogenetic article
family. If the rendered site becomes crowded, the fallback is a section
inside the phylogenetic GLLVM article plus a short reference page for the
`kernel_*()` helpers. The article should not replace the ordinary
`phylo_*()` tutorial; coevolution is a specialised extension.

## Publication Gate

Do not publish the article until all of these are true:

- C1 is merged: `kernel_latent(K = A)` and companion modes are
  equivalent to the dense `phylo_*()` `vcv = A` paths to less than
  `1e-6`.
- C2 is merged: `extract_Gamma()` exists and the known-`Gamma` recovery
  test passes with Procrustes/sign-aligned correlation above 0.9.
- The C2 test shows null-vs-cross log-likelihood separation on
  `K_star`-structured data.
- Loading constraints for the `Gamma` slice are verified in the fitted
  object, not only assumed from the latent-factor machinery.
- A single-`W` sensitivity simulation records how association richness
  changes recovery or uncertainty.
- `docs/design/35-validation-debt-register.md` marks `KER-02` covered
  and marks `COE-02` with the exact C2 evidence path.

## Reader Path

The article should use the same reader-first pattern as the current
Tier-1 examples:

1. Start with the biological data shape: host traits, partner traits,
   host phylogeny, partner phylogeny, and the association matrix `W`.
2. Build `K_star` with `make_cross_kernel(A_H, A_P, W, rho)`.
3. Fit a null block-diagonal kernel model and the cross-kernel model.
4. Extract `Sigma` and `Gamma`.
5. Interpret the sign and magnitude of `Gamma`, then show the
   null-vs-cross likelihood comparison.
6. Close with the data-condition warning: a single association matrix is
   one realised source of coevolution information, so sparse `W` should
   be treated as weak evidence.

## Example Contract

The public article needs paired examples unless an exception is recorded
in the article itself:

- Long format: one row per observed `(association unit, trait)` value,
  with block-missing rows explicit for the lineage not observed in that
  block.
- Wide data-frame formula: `traits(...) ~ 1 + kernel_latent(...) +
  kernel_unique(...)`, using the same `K_star` and the same named kernel
  tier.

Avoid `gllvmTMB_wide()` as the main route. The article may mention it
only as a soft-deprecated migration path if needed for readers coming
from older examples.

## Figure Contract

The article needs one main figure before publication:

- a heatmap of `Gamma_hat` beside `Gamma_true` in the simulation-backed
  example, or
- for a real-data example, a heatmap of `Gamma_hat` plus a compact
  uncertainty or sensitivity panel.

Default ggplot output is not acceptable for the article. The figure
should pass a Florence-style readability check after rendering.

## Scope Boundary Wording

The first article version should say:

- IN: fitting one named dense kernel tier with `kernel_latent()` plus
  `kernel_unique()` and extracting the cross-lineage shared block with
  `extract_Gamma()`, backed by C2 recovery evidence.
- PARTIAL: precision and uncertainty depend on the density and structure
  of `W`; the article demonstrates a sensitivity check rather than a
  universal sample-size guarantee.
- PLANNED: multiple simultaneous kernel tiers and relmat-to-kernel
  soft-deprecation remain later Design 65 / cross-repo work.
