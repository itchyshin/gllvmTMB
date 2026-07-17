# Design 84 — Phylogenetic multinomial GLMM (multinomial Tier 2a)

**Status date:** 2026-07-17. **Status:** design draft (no code). Successor scope to Design 83
(the shipped fixed-effects-only `multinomial()`, FAM-20, `covered`).
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

## 3. Identification — the one hard requirement

The multinomial logit is non-identified in **location** (softmax shift; solved by the reference
pin, already done in Design 83) **and scale** (the latent residual variance is not identified from
categorical outcomes). The RE covariance is only estimable once the **latent-scale residual is
fixed**:
- MCMCglmm fixes the **R-structure** in the prior — for K>2 commonly the identity, or the
  **`0.5` on the diagonal / `0.25` off-diagonal** matrix that reflects the geometry of differencing
  against the base category. Without it the sampler/optimiser drifts.
- G-structure (\(V\otimes A\), the phylogenetic effect) vs R-structure (residual \(\Sigma_r\otimes I\))
  is the standard split.

**Implication for a TMB build:** we must **fix the latent-scale residual by convention** (not
estimate it), or the Laplace/ML optimisation will fail to identify the scale. This is the load-
bearing design decision.

## 4. The gllvmTMB-native route — a phylogenetic *factor* model (this is the good news)

Full \(V\otimes A\) is \(O(m^2)\)-costly and \(V\) grows with K. The scalable state of the art is a
**phylogenetic factor model** — and it is **exactly gllvmTMB's native decomposition**:
\[
\eta_{ij} = X_i\beta_j + z_i^{\top}\lambda_j, \qquad
V \approx \Lambda\Lambda^{\top} + \operatorname{diag}(\psi),
\]
with \(z_i\) a **low-dimensional (\(d \ll K-1\)) phylogenetically-structured latent factor** and
\(\lambda_j\) **category-specific loadings**. That is `Sigma = Lambda Lambda^T + diag(psi)` under a
phylogenetic latent — i.e. `phylo_latent()` — applied to the K−1 category-contrast pseudo-traits.

So the dimensional mismatch Design 83 flagged (a categorical trait wants K−1 latent dimensions, but
the Σ machinery assumes one per trait) is **resolved by the factor decomposition**: each category
contrast is a loading row on shared low-rank phylogenetic factors. gllvmTMB is unusually well-placed
here because reduced-rank latent factors + sparse-\(A^{-1}\) phylogeny + AD/Laplace are its core.

## 5. What it would take to build (blueprint)

1. **Likelihood:** the fid-16 grouped baseline-category softmax **already exists** (Design 83) and
   is the correct base — this is why building `multinomial()` was the right first step, not a regret.
2. **Random-effect tier:** allow a latent/`phylo_latent` term on a multinomial trait's K−1
   category-contrast pseudo-traits — category-specific loadings \(\lambda_j\) on shared factors
   \(z_i\), with the phylogenetic precision on \(z_i\) (reuse the existing sparse \(A^{-1}\) engine).
3. **Scale anchorage:** fix the latent-scale residual by convention (§3) — the key identification
   step; expose/enforce it rather than estimate it.
4. **Reporting:** `extract_correlations()` / `extract_Sigma()` would then return the reduced-rank
   \(V \approx \Lambda\Lambda^\top + \operatorname{diag}(\psi)\) among category liabilities (and its
   phylogenetic version) — the table the fence currently declines.
5. **Validation target:** recover a known \(V\) (and phylo signal) from simulation; cross-check
   against MCMCglmm `categorical` + `ginverse` and brms `categorical` + `gr(cov=A)` on a shared toy
   dataset. Mizuno et al. 2025 is the methods reference.

**Obstruction + resolution:** the phylo-covariance inversion — resolved by the sparse \(A^{-1}\)
route (already in gllvmTMB) + AD/Laplace; VA + NNGP is the scaling frontier if needed later.

## 6. Scope boundaries

- This is a **new modelling arc** (random effects on a categorical trait), a Discussion-Checkpoint
  likelihood change — not a doc tweak. Design + maintainer sign-off before code.
- The shipped fixed-effects `multinomial()` (Design 83) stays the default fixed-effects interface;
  this adds the RE/phylo tier on top. Complementary, not a replacement.
- Julia parity is a later arc.

## 7. Open decisions for the maintainer

1. Which residual-scale convention to fix (identity vs the 0.5/0.25 base-category-differencing form)
   and whether to expose it.
2. Rank policy for the factor decomposition (fixed d, or the existing latent-rank selection).
3. Whether Tier-2a targets the *standalone* per-trait \(V\) first, or the harder *cross-trait*
   integration (a multinomial trait correlating with other traits) — the factor route makes the
   former clean; the latter still needs a reporting convention for mixing K−1-dim and 1-dim traits.
