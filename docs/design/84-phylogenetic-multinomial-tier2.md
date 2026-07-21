# Design 84 — Phylogenetic multinomial GLMM (multinomial Tier 2a)

**Status date:** 2026-07-21. **Historical status (2026-07-17):** design draft
(no code). The historical proposal is retained below. **Current 0.6 status:**
the narrow `phylo_latent()` multinomial route is implemented and **partial**.
`extract_Sigma(..., level = "phy", part = "shared", link_residual = "none")`
reports the fitted $(K-1)\times(K-1)$ among-category phylogenetic covariance $V$.
It is data-hungry, especially with one observation per species, and is not a
universal recovery or interval claim. The matrix softmax link residual
$(\pi^2/6)(I+J)$ is added only by the separate total extraction with
`link_residual = "auto"`; it is not part of fitted $V$.
This document remains the successor scope to Design 83 (whose fixed-effect
FAM-20 route is `covered`).

**Related current partial route (not phylogenetic):** one multinomial trait may
share ordinary `latent()` factors with other response families. Its $K-1$
baseline-contrast block is reported explicitly; it is not collapsed to one
categorical correlation. Default ordinary `Psi` is allowed for identified
partner traits while the current engine maps off the multinomial contrast
diagonal. That term is unidentified with one categorical draw per unit and
identifiable in principle under replication, but the current implementation
still suppresses it. Explicit multinomial `unique()`/`indep()` terms and
unlisted tiers remain fail-closed. FAM-20B Wald/bootstrap plumbing is
uncalibrated; nonlinear profile requests are withdrawn and typed-refusal tested
in `tests/testthat/test-cross-family-intervals.R`. These interval statements do
not describe the phylogenetic FAM-20A route.
**Provenance:** grounded lit check — brain note
`mizuno-et-al.-2025-phylogenetic-multinomial-glmm-jeb` + a NotebookLM deep-research pass (100
sources, anchored on the Mizuno et al. 2025 preprint):
`https://notebooklm.google.com/notebook/1fc6ce06-dff7-41a8-8832-9662c4362622`. Authoritative
source: **Mizuno, Drobniak, Williams, Lagisz & Nakagawa (2025)**, *Promoting the use of
phylogenetic multinomial generalised mixed-effects model to understand the evolution of discrete
traits*, **J. Evol. Biol.**, [10.1093/jeb/voaf116](https://doi.org/10.1093/jeb/voaf116).

## 1. The question this closes

Can gllvmTMB report the (K−1)×(K−1) correlation surface for a multinomial trait — including a
**phylogenetic** version (how category liabilities coevolve)? Design 83 deferred it ("Tier 2").
This note records the **real, principled model** and a gllvmTMB-native implementation route. It
also retires the continuation-ratio / binary-traits "reduction" as a non-solution.

## 2. The real model — phylogenetic multinomial GLMM (NOT binary simplifications)

Baseline-category softmax linear predictor with a phylogenetic random effect:
\[
\eta_{ij} = X_i\beta_j + a_{ij}, \qquad
P(y_i = j) = \frac{\exp(\eta_{ij})}{1 + \sum_{k=1}^{K-1}\exp(\eta_{ik})}, \quad j = 1,\dots,K-1,
\]
reference category pinned at \(\eta=0\). The phylogenetic random effect carries a **Kronecker
structure**
\[
G = V \otimes A,
\]
where **\(V\) is the \((K-1)\times(K-1)\) among-category (co)variance** — the interpretable
estimand, the "correlation table": does high evolutionary liability for one category predispose a
lineage toward another — and \(A\) is the phylogenetic correlation matrix.

**Reference implementations.** MCMCglmm `family="categorical"` (liability/Gibbs; phylogeny via a
sparse `ginverse` = \(A^{-1}\); `us(trait):animal` gives the full \(V\)). brms `family=categorical`
(multinomial logit via HMC; phylogeny via `(1 | ID | gr(species, cov = A))` — the `| ID |` ties the
K−1 category random effects into one correlation matrix).

**Why binary simplifications are the wrong answer (permutation invariance).** For *unordered*
categories the arbitrary state labelling must not change the result. Continuation-ratio / sequential
logits assume a hierarchy (re-ordering the categories changes the estimates — order dependence);
one-vs-rest binaries ignore mutual exclusivity, don't sum to 1, and destroy the joint covariance.
Mizuno et al. 2025 argues *against* exactly these simplifications. So the earlier "route 3" idea
(K−1 continuation-ratio binomials fed to the existing binary machinery) is **retired** — it is not
the multinomial for unordered traits.

## 3. Historical identification requirement and shipped resolution

The multinomial logit is non-identified in **location** (softmax shift; solved by the reference
pin, already done in Design 83) **and scale** (the latent residual variance is not identified from
categorical outcomes). The RE covariance is only estimable once the **latent-scale residual is
fixed**:
- MCMCglmm fixes the **R-structure** in the prior — for K>2 commonly the identity, or the
  **`0.5` on the diagonal / `0.25` off-diagonal** matrix that reflects the geometry of differencing
  against the base category. Without it the sampler/optimiser drifts.
- G-structure (\(V\otimes A\), the phylogenetic effect) vs R-structure (residual \(\Sigma_r\otimes I\))
  is the standard split.

**Shipped resolution:** the TMB route fixes the softmax residual scale by
convention rather than estimating it. Section 4 records the implemented split:
the fitted phylogenetic component is loadings-only, while the fixed
$(\pi^2/6)(I+J)$ softmax residual is added only when observation-scale
extraction is requested. No pending residual-variance implementation is implied
by this historical rationale.

## 4. The gllvmTMB-native route — a phylogenetic *factor* model (this is the good news)

Full \(V\otimes A\) is \(O(m^2)\)-costly and \(V\) grows with K. The shipped
FAM-20A route is a **loadings-only phylogenetic factor model**:
\[
\eta_{ij} = X_i\beta_j + z_i^{\top}\lambda_j, \qquad
V_{\mathrm{phy}} = \Lambda_{\mathrm{phy}}\Lambda_{\mathrm{phy}}^{\top},
\]
with \(z_i\) a **low-dimensional (\(d \ll K-1\)) phylogenetically-structured latent factor** and
\(\lambda_j\) **category-specific loadings**. Source-specific `phylo_latent()`
is loadings-only by default, and the admitted multinomial route does not fit a
free phylogenetic diagonal `Psi`. When
`extract_Sigma(..., level = "phy", link_residual = "auto")` is requested, the
fixed softmax residual $(\pi^2/6)(I+J)$ is added at extraction time; it is not
part of $V_{\mathrm{phy}}$ and is not an estimated variance component.

So the dimensional mismatch Design 83 flagged (a categorical trait wants K−1 latent dimensions, but
the Σ machinery assumes one per trait) is **resolved by the factor decomposition**: each category
contrast is a loading row on shared low-rank phylogenetic factors. gllvmTMB is unusually well-placed
here because reduced-rank latent factors + sparse-\(A^{-1}\) phylogeny + AD/Laplace are its core.

## 5. Historical implementation blueprint (partly superseded)

1. **Likelihood:** the fid-16 grouped baseline-category softmax **already exists** (Design 83) and
   is the correct base — this is why building `multinomial()` was the right first step, not a regret.
2. **Random-effect tier:** allow a latent/`phylo_latent` term on a multinomial trait's K−1
   category-contrast pseudo-traits — category-specific loadings \(\lambda_j\) on shared factors
   \(z_i\), with the phylogenetic precision on \(z_i\) (reuse the existing sparse \(A^{-1}\) engine).
3. **Scale anchorage:** fix the latent-scale residual by convention (§3) — the key identification
   step; expose/enforce it rather than estimate it.
4. **Reporting (implemented boundary):**
   `extract_Sigma(..., level = "phy", part = "shared", link_residual = "none")`
   returns the loadings-only fitted covariance
   \(V_{\mathrm{phy}} = \Lambda_{\mathrm{phy}}\Lambda_{\mathrm{phy}}^\top\).
   The admitted multinomial route fits no free phylogenetic diagonal
   \(\Psi_{\mathrm{phy}}\). The separate default total/`"auto"` output adds the
   fixed softmax residual \((\pi^2/6)(I+J)\).
5. **Validation target:** recover a known \(V\) (and phylo signal) from simulation; cross-check
   against MCMCglmm `categorical` + `ginverse` and brms `categorical` + `gr(cov=A)` on a shared toy
   dataset. Mizuno et al. 2025 is the methods reference.

**Obstruction + resolution:** the phylo-covariance inversion — resolved by the sparse \(A^{-1}\)
route (already in gllvmTMB) + AD/Laplace; VA + NNGP is the scaling frontier if needed later.

## 6. Current scope boundaries

- **IN:** fixed-effect FAM-20 recovery; the partial `phylo_latent()` V route;
  and the separate partial ordinary shared-`latent()` cross-family route, each
  with one multinomial trait per fit.
- **PARTIAL:** FAM-20A phylogenetic V recovery requires replication or large
  samples and currently supports no interval-coverage claim. Separately,
  FAM-20B cross-family Wald/bootstrap summaries are route-only and
  uncalibrated; they are not evidence for phylogenetic V intervals.
- **PLANNED/BLOCKED:** a universal categorical covariance or correlation,
  augmented slopes, explicit multinomial `unique()`/`indep()`, unlisted
  structured tiers, multiple multinomial traits, Julia parity, and nonlinear
  profile intervals. The last is withdrawn, not an available prototype.

## 7. Historical open decisions for the maintainer

1. Which residual-scale convention to fix (identity vs the 0.5/0.25 base-category-differencing form)
   and whether to expose it.
2. Rank policy for the factor decomposition (fixed d, or the existing latent-rank selection).
3. Whether Tier-2a targets the *standalone* per-trait \(V\) first, or the harder *cross-trait*
   integration (a multinomial trait correlating with other traits) — the factor route makes the
   former clean; the latter still needs a reporting convention for mixing K−1-dim and 1-dim traits.
