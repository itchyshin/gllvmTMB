# Design 13 — extract_phylo_signal partition redesign

**Status**: planned (M2.x or post-CRAN follow-up)
**Authors**: Boole + Fisher (lead); Emmy (extractor surface); Ada (orchestration)
**Maintained by**: Fisher (phylo-signal mathematics) + Boole (API)
**Triggered by**: maintainer 2026-05-17 — "the three components don't seem
to have much sense" + the M1.7 review highlighted the gap between
`extract_phylo_signal`'s 3-component output and the canonical
phylogenetic-signal vocabulary in the comparative-biology literature.

This design captures the planned redesign of `extract_phylo_signal()`
and is **not implemented in M1**. M1.7 (PR #155) tests the current
3-component contract; this redesign happens as a discrete pre-CRAN
small PR.

## §1 — The "true $H^2$" includes $\psi_{\text{phy}}$

Phylogenetic signal canonically refers to the proportion of trait
variance correlated with the tree. In the **two-U PGLLVM** parameterisation
(Hadfield & Nakagawa 2010 sparse $A^{-1}$, ratified in
[`docs/design/03-phylogenetic-gllvm.md`](03-phylogenetic-gllvm.md)),
two distinct random-effect structures contribute to phylogenetic
variance:

- `phylo_latent(species, d = K)` — rank-$K$ factor structure on the
  phylogeny: $\Sigma^{(\text{latent})}_{\text{phy}} = \Lambda_{\text{phy}} \Lambda^\top_{\text{phy}}$.
- `phylo_unique(species)` — rank-1 (per-trait) phylogenetic
  variance: $\Sigma^{(\text{unique})}_{\text{phy}} = \mathrm{diag}(\psi_{\text{phy}})$.

The **canonical numerator** of $H^2$ should include both:

$$\Sigma_{\text{phy}} = \Sigma^{(\text{latent})}_{\text{phy}} + \Sigma^{(\text{unique})}_{\text{phy}} = \Lambda_{\text{phy}}\Lambda^\top_{\text{phy}} + \mathrm{diag}(\psi_{\text{phy}})$$

Variance correlated with the tree but trait-specific (the
$\psi_{\text{phy}}$ contribution) is still phylogenetic signal — it
just doesn't share a low-rank factor structure across traits.

**The current code already does this**: `extract_phylo_signal` reads
`extract_Sigma(level = "phy", part = "total", link_residual = "none")`,
where `part = "total"` lumps $\Lambda_{\text{phy}}\Lambda^\top_{\text{phy}}$
+ $\mathrm{diag}(\psi_{\text{phy}})$ at the phy tier. So the numerator
is right. **The redesign is about the denominator and partition shape**,
not the numerator.

## §2 — The current 3-component partition (what the redesign replaces)

For a fit with `phylo_latent + latent(species) + unique(species)`:

$$V_\eta[t] = \underbrace{\Sigma_{\text{phy}}[t,t]}_{\text{phylo, lumped}} + \underbrace{\Sigma^{(\text{latent})}_{\text{non}}[t,t]}_{\text{non-phylo factor}} + \underbrace{\psi_{\text{non}}[t]}_{\text{non-phylo unique}}$$

The function returns three proportions: $H^2_t$, $C^2_{\text{non},t}$,
$\psi_t$ summing to 1.

**Problems with this partition** (per maintainer 2026-05-17 review):

1. **Non-standard in phylo comparative biology.** Pagel's λ, Blomberg's
   K, Lynch's $\rho$, Freckleton's $H^2$ — all are 2-component
   (phylo vs non-phylo). Splitting non-phylo into "shared factor" vs
   "trait-specific unique" isn't part of the canonical vocabulary
   readers expect.
2. **$C^2_{\text{non}}$ depends on the user's choice of $d_{\text{non}}$
   in `latent(0 + trait | species, d = d_non)`.** The partition isn't
   invariant to a modeling choice that isn't biologically meaningful.
3. **Biological interpretation of $C^2_{\text{non}}$ is ambiguous.**
   "Non-phylo trait covariance among species" lumps environment,
   ecology, methodology, measurement covariance, and Type-II error
   of the phylo model.
4. **The "phylo_unique" tier is hidden inside $H^2$**, not surfaced
   as a separate component — even when the user explicitly chose to
   include it. The phylo-q-decomposition empirical work (see
   `tests/testthat/test-phylo-q-decomposition.R`) shows that
   `phylo_unique + unique(species)` IS jointly identifiable when
   there's enough site × species replication. The redesign should
   give users a way to see that decomposition when they fit for it.

## §3 — Proposed redesign: `partition = c("phylo2", "fa3", "full4")`

A new `partition` argument selects the decomposition shape:

### `partition = "phylo2"` (NEW default — canonical phylo signal)

Two-component split matching the standard phylo-signal literature:

$$H^2_t = \frac{\Sigma_{\text{phy}}[t,t]}{V_\eta[t]}, \quad (1 - H^2_t) = \frac{\Sigma_{\text{non}}[t,t] + \psi_{\text{non}}[t]}{V_\eta[t]}$$

Output columns: `trait`, `H2`, `non_phylo`, `V_eta` (per trait).
Sum to 1 by construction. Matches reader expectations from Pagel
/ Blomberg / Lynch / Freckleton.

### `partition = "fa3"` (current 3-component; opt-in)

Backward-compat: returns the current 3-component split
(`H2`, `C2_non`, `Psi`, `V_eta`) for users who want the
factor-analytic decomposition (psychometrics / SEM tradition).
Documented as "the species-level factor-analytic partition" with
a note that $C^2_{\text{non}}$ depends on $d_{\text{non}}$.

### `partition = "full4"` (NEW — four-component decomposition)

When the model includes BOTH `phylo_unique` and `unique(species)`,
the full latent-tier decomposition is identifiable (per the
2026-05-13 phylo-q-decomposition empirical work):

$$V_\eta[t] = (\Lambda_{\text{phy}}\Lambda^\top_{\text{phy}})_{tt} + \psi_{\text{phy}}[t] + (\Lambda_{\text{non}}\Lambda^\top_{\text{non}})_{tt} + \psi_{\text{non}}[t]$$

Output columns: `trait`, `H2_phy_latent`, `H2_phy_unique`,
`C2_non_latent`, `psi_non_unique`, `V_eta`. Sum to 1.

Useful for the "two-U PGLLVM" pattern documented in
`03-phylogenetic-gllvm.md`: separates phylo factor structure from
phylo trait-specific magnitude, AND non-phylo factor from non-phylo
trait-specific. Errors with a helpful message when both
`phylo_unique` and `unique(species)` are not fit:

> `partition = "full4"` requires both `phylo_unique(...)` and
> `unique(0 + trait | species)` in the formula. Refit with both
> terms, or use `partition = "fa3"` for the 3-component fallback.

## §4 — Migration plan

The change is **backward-incompatible**: callers that read
`out$H2`, `out$C2_non`, `out$Psi` will need to switch to
`partition = "fa3"` for the old shape OR adopt the new
`partition = "phylo2"` columns.

Mitigation:

1. **Soft-deprecate the no-`partition` call** for one release cycle.
   When `partition` is missing, emit a one-shot
   `lifecycle::deprecate_soft()` warning naming the upcoming default
   change + pointing at this design doc. Keep the `fa3` output as
   the current default during the deprecation window.
2. **In the deprecation message**, point users at the
   `partition = "phylo2"` default + the `"fa3"` opt-in. Note that
   `"full4"` is the new richest decomposition for users with the
   two-U PGLLVM formula.
3. **After the deprecation window** (next minor release), flip the
   default to `"phylo2"`.

## §5 — Tests required for the redesign PR

When this redesign lands as a discrete pre-CRAN PR:

1. **`partition = "phylo2"`** on a phylo + mixed-family fit:
   `H2 + non_phylo = 1` per trait; both in $[0, 1]$.
2. **`partition = "fa3"`** byte-identical to current output (the
   M1.7 test in `tests/testthat/test-m1-7-extract-omega-phylo-signal-mixed-family.R`
   continues to pass under the new `partition` argument).
3. **`partition = "full4"`** on a two-U PGLLVM fit (the
   phylo-q-decomposition fixture from `test-phylo-q-decomposition.R`):
   all four components sum to 1; phylo_unique component identifiable.
4. **`partition = "full4"` error message** when the formula doesn't
   have both `phylo_unique` and `unique(species)`.
5. **Soft-deprecation warning** fires exactly once per session when
   `partition` is missing from the call.

## §6 — Out of scope for this design

The following are NOT part of this redesign:

- **Extending `extract_phylo_signal` to ordination-style outputs**
  (e.g., per-factor phylogenetic signal). That's a separate post-
  CRAN extension if requested.
- **Profile-CI on the new partition components.** The existing CI
  path (`profile_ci_phylo_signal`) operates on $H^2$; extending it
  to $C^2_{\text{non}}$ and $\psi_{\text{non}}$ is M3 / post-CRAN
  inference-completeness work.
- **Reconciling with `extract_proportions()`.** That extractor is
  currently `blocked` (delta-family work) and operates on the full
  latent-scale observational partition (with link_residual). The
  two extractors have different scopes; cross-reference between them
  in the redesigned docstrings.

## §7 — Cross-references

- `R/extract-omega.R` — `extract_phylo_signal()` source (current implementation).
- `tests/testthat/test-m1-7-extract-omega-phylo-signal-mixed-family.R` — tests of the current 3-component partition (M1.7).
- `tests/testthat/test-phylo-q-decomposition.R` — empirical identifiability work on `phylo_unique + unique(species)`.
- `docs/design/03-phylogenetic-gllvm.md` — Hadfield & Nakagawa (2010) sparse $A^{-1}$ + the two-U PGLLVM pattern.
- `docs/dev-log/audits/2026-05-17-link-residual-design-decision.md` — parallel design audit on $\pi^2/3$ vs observation-level link residuals; same audit pattern.

## §8 — References

- Pagel M (1999). *Inferring the historical patterns of biological evolution.* Nature **401**: 877–884.
- Blomberg SP, Garland T, Ives AR (2003). *Testing for phylogenetic signal in comparative data.* Evolution **57**: 717–745.
- Hadfield JD, Nakagawa S (2010). *General quantitative genetic methods for comparative biology.* J. Evol. Biol. **23**: 494–508.
- Freckleton RP, Harvey PH, Pagel M (2002). *Phylogenetic analysis and comparative data.* Am. Nat. **160**: 712–726.
- Lynch M (1991). *Methods for the analysis of comparative data in evolutionary biology.* Evolution **45**: 1065–1080.
