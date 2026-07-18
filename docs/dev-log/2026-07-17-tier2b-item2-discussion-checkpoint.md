# Item 2 — cross-family correlations for a multinomial trait — DISCUSSION CHECKPOINT

**Date:** 2026-07-17 · **Status:** 🔴 Needs maintainer decision BEFORE any code (family/likelihood-adjacent
parser change + a reporting-convention call the maintainer owns; Design 84 §7.3, brief item 2).
**Do not implement until ruled.** This memo frames the two decisions and gives a recommendation.

## What item 2 is
Let a `multinomial()` trait's K−1 baseline-contrast pseudo-traits **share a latent factor with OTHER
traits**, so the cross-covariance between the categorical trait and a partner trait lives in Λ and can be
reported. Item 1 (the `(π²/6)(I+J)` link residual, shipping now) already unblocks the **scale** side —
the categorical block is now commensurable with a single-scale trait. Item 2 is the **structure** side:
opening the fence and settling how to *report* the result.

## The two fences item 2 must open (exact sites)
1. `R/gllvmTMB.R` `expand_multinomial_response()` (~L842): aborts if `multinomial()` appears in a
   mixed-family `list(...)`. → must admit a multinomial trait alongside other-family traits.
2. `R/fit-multi.R` (~L1810): the Tier-2a fence — a fid-16 fit may carry `phylo_latent` only; any other
   latent / RE / structured tier fails loud. → must admit a **shared** latent factor spanning the
   multinomial pseudo-traits AND partner traits.

Both are deliberate "fail-loud, not silently-wrong" fences. Opening them is a Discussion-Checkpoint
likelihood/grammar change, not a doc tweak.

---

## DECISION 1 — Parser scope: how much to open, in what order
- **1a (narrow, recommended first step):** admit exactly ONE multinomial trait + ONE (or more)
  single-scale traits sharing ONE ordinary `latent()` factor. Smallest surface that produces a real
  cross-family correlation; every harder case stays fenced and loud.
- **1b (medium):** also admit the shared factor to be a *structured* tier (`phylo_latent`,
  `spatial_latent`, `kernel_latent`) — i.e. the cross-covariance is phylogenetic/spatial. Larger; needs
  item-1's tier-agnostic residual (done) plus per-tier tests.
- **1c (wide):** multiple multinomial traits + multiple structured tiers. Deferred regardless.

**Recommendation:** 1a first (its own PR), then 1b. Keep 1c fenced.

## DECISION 2 — Reporting convention: a categorical trait has a (K−1)-VECTOR of correlations with each partner
This is the genuinely maintainer-owned call. A partner trait `z` correlates with the categorical trait
through **each of the K−1 contrasts**, so the natural object is a length-(K−1) vector `r_k =
cor(contrast_k, z)`, k = 2..K vs the baseline. Options for what `extract_correlations()` returns:

- **2A — Full (K−1)-vector, explicitly labelled by category-vs-baseline.** Most honest and complete;
  nothing hidden. Cost: `extract_correlations()` output shape becomes ragged (a categorical trait
  contributes K−1 rows against each partner), and the reference category must be surfaced everywhere.
- **2B — One summary scalar per (categorical, partner) pair.** Candidates: (i) the multiple-correlation
  `R = sqrt(z' Σ_zc Σ_cc^{-1} Σ_cz / σ_z²)` (the categorical block's total linear association with `z`,
  reference-invariant); (ii) the largest canonical correlation. Reads like an ordinary correlation table;
  cost: collapses direction/among-category detail, and `R ≥ 0` has no sign.
- **2C — Both: scalar summary by default, (K−1)-vector on request** (e.g. `extract_correlations(...,
  categorical = c("summary","contrasts"))`). More code; best user ergonomics.

**Recommendation:** **2C**, defaulting to the **reference-invariant multiple-correlation** scalar (2B-i)
with the full labelled (K−1)-vector available on request (2A). Rationale: the scalar is what a
correlation *table* needs and is invariant to the arbitrary baseline choice (avoids "which reference
category" leaking onto every surface); the vector preserves the honest detail for those who want it.
Reject the raw ragged-table-only (2A-only) default — it forces a reference-category convention onto the
headline surface, which is exactly the kind of internal-identification detail we keep off reader surfaces.

## Open sub-questions for the maintainer
1. Baseline handling in the summary: confirm the multiple-correlation is preferred (reference-invariant)
   over reporting contrasts against a fixed reference.
2. Should the (K−1)-vector, when requested, be Fisher-z interval-capable (ties into the recovery arc /
   item 3 uncertainty), or point-estimate only at first?
3. Sign convention for the summary (magnitude-only R vs a signed measure) — R is unsigned; is that
   acceptable for the default table?

## Guards carried forward
Multi-seed always · Rose before any covered claim · compute local→Totoro · reader surfaces carry no
register codes and no bare reference-category identification detail.
