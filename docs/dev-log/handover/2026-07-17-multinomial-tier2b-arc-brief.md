# Multinomial Tier-2b — the 1.0 arc (new Claude lane brief)

**Date:** 2026-07-17 · **From:** Claude (Fable 5). This opens a **fresh lane** for the multinomial 1.0
arc. The 0.6 work is DONE and merged to `main`; this brief scopes what remains and carries the settled
context so the new lane starts with **no re-discovery**. You are the next Claude, picking up Tier-2b.

## Where 0.6 landed (do NOT redo)
A `phylo_latent()` term on a `multinomial()` trait reports the standalone (K−1)×(K−1) among-category
covariance V via `extract_Sigma(fit, level = "phy")` / `extract_correlations()`, **fenced**: recovery is
data-hungry (needs per-species replication or large N; one-per-species point estimates are high-variance
and rail at ρ = ±1). Merged: capability **#753**, article **#751**, McFadden citation **#755**,
reference-page deprecation labels **#756**. Detail:
- `docs/dev-log/handover/2026-07-17-claude-handover-regularization-negative.md`
- `docs/dev-log/after-task/2026-07-17-tier2a-regularization-negative-result.md`
- `docs/design/84-phylogenetic-multinomial-tier2.md`

## Settled context (so you don't re-derive)
- **Regularization is a NEGATIVE result.** The fixed-`R = (1/K)(I+J)` OLRE is **inert** (proven active but
  zero effect on recovery; 3/3 adversarial lenses; reverted) — do NOT re-attempt it. The **fixed-Ψ ridge**
  is a genuine but *insufficient* regularizer (halves the ±1 collapse at v=1.0 but ~half the seeds still
  rail) — a candidate for item 3 combined with larger N; recipe preserved in the after-task.
- **Why one-per-species fails:** weak information — one categorical draw barely constrains the (K−1)-dim
  liability, so the reduced-rank ΛΛᵀ MLE rails when a loading → 0. MCMCglmm recovers via its
  **parameter-expanded prior on G + full-rank `us(trait):species` + posterior-MEAN reporting** — that is
  the model for item 3, not any fixed additive residual.
- **`link_residual` convention RESOLVED:** the softmax's observation-scale residual is
  **`(π²/6)(I+J)`** — **π²/3 on the diagonal** (each contrast is a logit, as `binomial`), **π²/6
  off-diagonal** (shared-baseline coupling); reduces to binomial's π²/3 at K=2. Refs: McFadden (1974,
  *Frontiers in Econometrics*) for the random-utility Gumbel origin; Nakagawa & Schielzeth (2010, *Biol.
  Rev.* 85, 935–956) and Nakagawa, Johnson & Schielzeth (2017, *J. R. Soc. Interface* 14, 20170213) for
  the per-contrast link variance. Documented in the `extract_Sigma` roxygen + the multinomial article.
  It is NOT MCMCglmm's arbitrary `(1/K)(I+J)` identification residual, nor its Bayesian `c²` correction.
- **The independence null of V is `(I+J)`-structured** — a *diagonal* V is not independence.

## The 1.0 arc — three deliverables, by leverage
1. **Apply the `(π²/6)(I+J)` matrix `link_residual`.** `link_residual_per_trait()`
   (`R/extract-sigma.R:~115`) returns a scalar per trait; the multinomial needs the (K−1)×(K−1) block
   added to its pseudo-trait block of Σ before observation-scale correlations are computed. Moderate
   R-side change; it is what makes a categorical trait *commensurable* with single-scale traits.
   `extract_Sigma()` currently returns the latent-scale V and warns.
2. **Cross-family correlations (the headline).** Open the `fit-multi.R` fence so a multinomial trait's
   K−1 pseudo-traits can share a latent factor with OTHER traits (the cross-covariance then lives in Λ),
   and settle the **reporting convention** for the (K−1)-vector of correlations a categorical trait has
   with each partner — which reference category, how to summarize. **Discussion Checkpoint** (parser
   fence + reporting convention; Design 84 §7 "harder open problem"). The link variance (item 1) already
   unblocks the *scale* side.
3. **Genuine one-per-species recovery.** A prior/penalty on the phylo loadings + posterior-mean or
   interval reporting (Bayesian, or penalized-likelihood with proper uncertainty), cross-checked vs
   MCMCglmm on the reconciled scale. Compute campaign (local → Totoro). Ridge + N is a calibration
   candidate. This is the deepest item.

## Guards
- **Discussion Checkpoint** before the item-2 parser/reporting change (family/likelihood-adjacent + a
  reporting-convention call the maintainer owns).
- **Spawn Rose before any "covered" claim.** **Multi-seed discipline** — single seeds lie (the whole
  regularization arc turned on this: ρ̂=0.57 looked like recovery; multi-seed SD was 0.6 with ±1 collapses).
- Compute **local → Totoro**, never GitHub Actions; results stay local (D-50).
- Reader surfaces carry no internal register codes; honest fencing until proven.

## How to resume (one command — paste in an authenticated terminal at the repo root)
```
claude "Rehydrate from docs/dev-log/handover/2026-07-17-multinomial-tier2b-arc-brief.md on main. The multinomial 0.6 capability is merged + fenced; this is the Tier-2b 1.0 arc. Start with item 1 (apply the (pi^2/6)(I+J) matrix link_residual in extract_Sigma/extract_correlations), then item 2 (cross-family correlations — Discussion Checkpoint first: parser fence + the (K-1)-vector reporting convention), then item 3 (genuine recovery: prior + posterior-mean, cross-check vs MCMCglmm, Totoro). Spawn Rose before any covered claim; multi-seed always."
```

## Mission control
| Thread | State | Leverage |
|---|---|---|
| 0.6 capability (report V, fenced) | MERGED (#753) | ✅ done |
| Matrix `link_residual` `(π²/6)(I+J)` | convention resolved + documented; **not applied** | 🟡 item 1 (R-side) |
| Cross-family correlations | fenced to standalone-only; scale side unblocked | 🔴 item 2 (Discussion Checkpoint) |
| Genuine recovery (prior + posterior-mean) | negative result on fixed regularizers; model identified (MCMCglmm) | 🔴 item 3 (compute) |
