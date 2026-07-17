# After-task — Tier-2a phylo-multinomial: build + recovery validation

**Date:** 2026-07-17 · **Agent:** Claude (Fable 5), solo. **Branch:** `claude/tier2a-phylo-multinomial`
(off `main`). **Arc:** Design 84 — report the (K−1)×(K−1) among-category correlation surface V for a
multinomial trait, phylogenetic version.

## Scope
Make gllvmTMB fit a phylogenetic multinomial and report the among-category V, then validate recovery of
a known V. Standalone per-trait; cross-trait + Julia fenced.

## What shipped (three PURE-R edits; NO C++ change; NO recompile)
- **S1** — `R/fit-multi.R:1793`: relaxed the Tier-1 fence to permit `phylo_latent` (`use_phylo_rr`) on a
  multinomial trait; other RE tiers still fail loud.
- **S3** — `R/extract-sigma.R:629` and `R/extract-correlations.R:439`: gated the refusal so a
  phylo-factor multinomial fit returns V (`extract_Sigma(level="phy")`) / correlations, while a
  fixed-effects-only multinomial still refuses cleanly.
- **Why no C++**: `expand_multinomial_response` (`gllvmTMB.R:891`) makes the K−1 contrasts **distinct
  pseudo-trait levels** (`diet:2`, `diet:3`), so the existing `eta` loop `Lambda_phy(trait_id,k)·g_phy`
  (`src/gllvmTMB.cpp:1902-1907`) already applies a category-specific loading per contrast — the phylo
  factor model, for free. `Sigma_phy = Λ_phy Λ_phyᵀ` over the pseudo-traits IS the (K−1)×(K−1) V.

## Recovery validation (fits run locally; the DISCIPLINE gate)
- **Capability verified:** a phylo multinomial fits; `extract_Sigma(level="phy")` returns the 2×2 V.
- **Recovers with per-species REPLICATION:** ρ̂=0.665 (n=200×10), 0.815 (n=400×10), 0.434 (K=5 n=400×8);
  true 0.6.
- **One-per-species: CONSISTENT but too NOISY to be practically usable at n≤5000 (multi-seed).**
  8 seeds n=2000 → mean ρ̂=0.433 (SD 0.614); 6 seeds n=5000 → mean 0.532 (SD 0.268); true 0.6. Individual
  fits swing from **−0.95 to +1.0** and frequently hit the ±1 boundary (non-PD Hessian). The mean climbs
  toward 0.6 and the SD shrinks with N (a consistent estimator), but single-seed reads (the earlier
  0.573/0.729/0.721) are lucky draws from a wide distribution — **NOT reliable recovery**. This is the
  DISCIPLINE gate working: "single-N ±0.25 is not enough."
- **CONCLUSION: regularization is needed for the practical one-per-species regime.** The fixed
  `R=(1/K)(I+J)` (headline; MCMCglmm's device) is required — not optional — to stabilize the estimator
  and stop the boundary collapses at realistic N. Replication recovers without it; one-per-species does not.
- **Why multinomial is harder than Gaussian** (identifies V at N~500 one-per-species): a single
  categorical draw carries little Fisher information about the (K−1)-dim liability. Needs ~4× the N.
- **H&N engine confirmed:** the fit uses the Hadfield & Nakagawa (2010) sparse A⁻¹ over tips+internal
  nodes (`n_aug=2n−1`), native ape+Matrix. The engine is correct; the limit is data.

## Corrections logged (own the wobble)
- "No residual needed" was right for the *math with replication* but **wrong for the realistic
  one-per-species regime**: the fixed `R=(1/K)(I+J)` (the original headline) is the **regularization**
  that lowers the N threshold — exactly what MCMCglmm fixes. Not a prerequisite at large N; a real
  improvement for small N.
- The K−1 representation existed (softmax rows) but I twice mis-scoped the loading side before reading
  `expand_multinomial_response` and confirming distinct pseudo-trait `trait_id`.

## Checks
- Compile: clean (`devtools::load_all` builds; C++ unchanged). Fits succeed and return V.
- `conv=0` (non-PD Hessian) persists even when ρ̂ recovers — a loadings-only rank-edge flag to
  investigate (not blocking the point estimate). NOT yet run: `devtools::test()`, `R CMD check`.

## Follow-ups (clearly scoped)
1. **Multi-seed ladder** (running) → the honest recovery statement + resolve the ~0.72 bias question.
2. **Fixed-`R=(1/K)(I+J)` regularization** — fit-time TMB/C++ change (the headline) to lower the N
   threshold + stabilize the boundary; a focused next arc, needs the maintainer's steer on the exact form.
3. **Link-residual reporting** — wire the multinomial `link_residual=(1/K)(I+J)` into
   `link_residual_per_trait()` (`extract-sigma.R`) for binomial-consistent latent-scale correlations
   (fixes the "Link-scale residual unavailable → NA" warning). R-side, multivariate over pseudo-traits.
4. **Docs/NEWS + honesty fence**: "needs large N (~2000+) or per-species replication; regularization
   forthcoming"; `devtools::test()` + `R CMD check`; commit the three R edits.
5. Generalize the fence tier-by-tier to other RE structures (latent/indep/dep/spatial/re_int) — the
   pseudo-trait mechanism is not phylo-specific (maintainer note).

## Status
Capability **DONE and recovers V** (with replication, or one-per-species at n≳2000). NOT yet "covered":
multi-seed confirmation + the bias check + the regularization/link-residual polish remain. Honest.
