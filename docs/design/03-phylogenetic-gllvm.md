# Phylogenetic GLLVM Contract

**Maintained by:** Boole (formula API + parser owner) and Noether
(math-vs-implementation alignment).
**Reviewers:** Gauss (numerical correctness), Darwin (comparative-
methods audience), Rose (consistency audit).

This note records the current phylogenetic stacked-trait contract
after the long/wide reader sweep and the 2026-05-14 PIC / "two-U"
retirement decision (see `docs/dev-log/decisions.md`).
It adapts the useful parts of the legacy phylogenetic design notes to
the current package vocabulary.

**Status discipline**: this document was written before Phase 0A's
4-state vocabulary (`covered / claimed / reserved / planned`) was
introduced. Until Phase 0B verifies the contract end-to-end via
the smoke-test pass, treat every assertion below as **claimed
(Phase 0B verification pending)** unless explicitly cross-linked
to a test file. The cross-references to
`docs/design/01-formula-grammar.md` (the canonical syntax contract)
and `docs/design/35-validation-debt-register.md` (the validation
ledger, forthcoming Phase 0A step 7) anchor every claim that needs
verification.

## Reader Problem

A comparative-methods user has one row unit per species and several
traits per species. They want to separate trait covariance that follows
the phylogeny from species-level covariance that does not.

The current public examples should show both:

- long data: one row per `(species, trait)` observation;
- wide data-frame data: one row per species, one column per trait,
  using `traits(...)` on the formula left-hand side.

**The matrix-in entry point `gllvmTMB_wide(Y, ...)` is removed in
0.2.0** (maintainer 2026-05-16 decision; see
`docs/design/01-formula-grammar.md`). The formula API path
`gllvmTMB(traits(t1, t2, ...) ~ ..., data = df_wide)` is the
canonical wide-format entry point for phylogenetic GLLVMs and
everything else.

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
2026-05-14 notation reversal). The legacy "two-U" task label has
been retired entirely (2026-05-14 PIC / "two-U" retirement
decision); public math uses `\boldsymbol\Psi` / `\psi_t` -- bold
capital Psi for matrices, italic lowercase psi (subscripted by
trait) for the per-trait scalars from `extract_phylo_signal()`.

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
- `compare_dep_vs_two_psi()` refits with `phylo_dep + dep` and
  compares total `Sigma_phy` and `Sigma_non` against the paired-Psi
  fit; canonical gold-standard cross-check.
- `compare_indep_vs_two_psi()` refits with `phylo_indep + indep`
  and compares only per-trait diagonal totals; cheap fallback when
  `T >= 30` and the unstructured fit is intractable.
- PIC-MOM cross-checks (`extract_two_U_via_PIC()`,
  `compare_PIC_vs_joint()`) were retired 2026-05-14; the
  `check_identifiability()` diagnostic (Phase 1b deliverable) is
  the planned general-purpose replacement.

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
parameterisation, exported functions, or the 3 × 5 keyword grid. It
documents how the existing current-code path should be explained in
articles and examples.

## Cross-references

- `docs/design/00-vision.md` — package vision, "What makes
  gllvmTMB different" lists phylogenetic GLLVMs as one of the
  five differentiating capabilities.
- `docs/design/01-formula-grammar.md` — canonical formula grammar
  contract; defines the `phylo_*` keywords + their `tree = ` /
  `vcv = ` keyword arguments; defines the unit / unit_obs /
  cluster grouping-factor convention (with cluster = `species`
  as the default for phylogenetic keywords).
- `docs/design/35-validation-debt-register.md` (forthcoming,
  Phase 0A step 7) — the validation ledger that every claim in
  this doc must reference once Phase 0B has verified.
- `docs/dev-log/decisions.md` 2026-05-14 PIC / "two-U" retirement
  entry — historical context for the `Psi` notation and the
  retirement of the PIC-MOM cross-check path.

## Persona-active engagement

When this doc was originally drafted (post-2026-05-14 PIC
retirement), Noether validated the math-vs-implementation
alignment for $\boldsymbol{\Psi}_\text{phy}$ / $\boldsymbol{\Psi}_\text{non}$
and Gauss reviewed the three-piece fallback's numerical
identifiability. Boole owns the `phylo_*` keyword surface and
revises this doc whenever the formula grammar changes (AGENTS.md
Design Rule #3 applies via the cross-reference to
`01-formula-grammar.md`).
