# Claude → Claude handover — Tier-2a phylo-multinomial (Design 84)

**Date:** 2026-07-17 · **From:** Claude (Fable 5), solo. **You are the next Claude**, picking up the
phylogenetic-multinomial arc. The *capability is built + committed and honestly validated*; the one
remaining leverage item (the fixed-`R` regularization) is scoped, not started. **Full technical detail
lives in the after-task report — read it:**
`docs/dev-log/after-task/2026-07-17-tier2a-phylo-multinomial-build-recovery.md`.

## Mission / goal (why)
Design 84 Tier-2a: make gllvmTMB **report the (K−1)×(K−1) among-category correlation surface V for a
multinomial trait**, phylogenetic version, via a phylo factor decomposition on the K−1 category-contrast
pseudo-traits. Standalone per-trait first; cross-trait + Julia fenced. `multinomial()` fixed-effects
(FAM-20) already shipped (`main` `aeee1bd2`). Reference: **Mizuno, Drobniak, Williams, Lagisz &
Nakagawa (2025), JEB** `10.1093/jeb/voaf116` (the phylogenetic multinomial GLMM).

## What was accomplished (COMMITTED on `claude/tier2a-phylo-multinomial`, off `main`)
- `88d7820e` — **capability** (3 pure-R edits, NO C++) + after-task report.
- `f38b80a5` — earlier lighter handover.
- **gllvmTMB now fits a phylo multinomial and returns the (K−1)×(K−1) V** via
  `extract_Sigma(fit, level="phy")` / `extract_correlations()` over the category-contrast pseudo-traits.
  Verified by real fits.

## Current working state
- **WORKING:** the capability. Recovery **works with per-species replication** (ρ̂≈0.6 region) and is a
  **consistent estimator** one-per-species (mean ρ̂ climbs 0.43@n=2000 → 0.53@n=5000 toward 0.6, SD shrinks).
- **NOT covered (honest):** one-per-species is **too NOISY at practical N** (individual fits swing
  −0.95→+1.0, hit the ±1 boundary; multi-seed mean/SD in the after-task). Do NOT claim "covered."
- **IN-PROGRESS / NEXT (not started):** the fixed-`R=(1/K)(I+J)` **regularization** — the goal's HEADLINE.

## Key decisions & rationale
- **No C++ needed for the wiring:** `expand_multinomial_response` (`R/gllvmTMB.R:891`) makes the K−1
  contrasts **distinct pseudo-trait levels** (`diet:2`, `diet:3`), so the existing `eta` loop
  `Lambda_phy(trait_id,k)·g_phy` (`src/gllvmTMB.cpp:1902-1907`) already applies category-specific
  loadings. `Sigma_phy=Λ_phyΛ_phyᵀ` over pseudo-traits IS V. **Generalizes to ANY RE tier** (latent /
  indep / dep / spatial / re_int) — not phylo-specific (maintainer note).
- **The softmax-Laplace identifies V directly (no residual for the *math*),** BUT the realistic
  one-per-species regime is under-informed (one categorical draw carries little info about the (K−1)-dim
  liability — unlike Gaussian, which identifies V at N~500). → **regularization is needed, not optional**,
  for one-per-species. The fixed `R=(1/K)(I+J)` is MCMCglmm's device.
- **H&N sparse A⁻¹ over tips+internal nodes** (`n_aug=2n−1`, native ape+Matrix) is the engine — correct;
  the limit is data, not the algorithm.

## Files created / modified (this session)
- **Committed (arc branch `claude/tier2a-phylo-multinomial`):**
  - `R/fit-multi.R` (S1: fence at :1793 relaxed for `use_phylo_rr`)
  - `R/extract-sigma.R` (S3a: fence at :629 gated) · `R/extract-correlations.R` (S3b: fence at :439 gated)
  - `docs/dev-log/after-task/2026-07-17-tier2a-phylo-multinomial-build-recovery.md`
  - `docs/dev-log/handover/2026-07-17-tier2a-phylo-multinomial-handover.md` (+ this doc)
- **NOT committed:** plan at `~/.claude/plans/should-we-replan-what-stateful-barto.md`; scratchpad
  diagnostics `tier2a-{smoke,ladder,diag,power,bigN,campaign}.R` (session scratchpad).
- **Also this session:** PR #752 (Design 84 scoping) merged to `main` (`aeee1bd2`).

## Next immediate steps (Claude does the R-side + prose; the live compile loop works locally, slowly)
1. **Implement the fixed-`R=(1/K)(I+J)` regularization** — a multinomial-logit-normal OLRE:
   `y_i ~ Multinomial(softmax(eta_i + e_i))`, `e_i ~ N(0, R)` FIXED, marginalized by Laplace.
   **Assembly points already mapped (turnkey):**
   - `src/gllvmTMB.cpp`: add `DATA_INTEGER(use_mn_olre)`, `DATA_INTEGER(n_mn_groups)`,
     `DATA_MATRIX(Rinv_mn)`, `DATA_SCALAR(log_det_R_mn)` (near the multinom DATA, ~:291); add
     `PARAMETER_MATRIX(u_mn_olre)` (n_mn_groups × maxL); add the fixed-R MVN density; add
     `u_mn_olre(multinom_group_id(o), j)` to each `eta(o+j)` inside the softmax block (:2335-2357).
   - `R/fit-multi.R`: build `Rinv_mn = solve((1/K)*(I+J))`, `log_det_R_mn`, `n_mn_groups`,
     `use_mn_olre`; add them to `tmb_data` (the list at ~:3348, near `multinom_group_id`); add
     `u_mn_olre = matrix(0, n_mn_groups, maxL)` to `tmb_params` (~:3418); add
     `if (use_mn_olre) random <- c(random, "u_mn_olre")` in the `random` block (~:4472, before
     `MakeADFun` at :4504); map it off when `use_mn_olre==0`.
   - Then RE-RUN the multi-seed campaign (`tier2a-campaign.R`, add N=800/1600/3200 seeds) WITH
     regularization; require mean within a calibrated band + acceptable SD across seeds BEFORE "covered".
2. **link_residual wiring (R-side):** multinomial `link_residual=(1/K)(I+J)` into
   `link_residual_per_trait()` (`R/extract-sigma.R:115+`) — the multivariate analog of binomial's π²/3
   (fixes the "Link-scale residual unavailable → NA" warning; binomial-consistent correlation scale).
3. **Article — the forward-looking Mizuno-multinomial paragraph.** Add to the `multinomial()` concept
   article (PR #751, branch `docs/multinomial-article`) a short forward-looking paragraph: the
   fixed-effects `multinomial()` extends to the **phylogenetic** setting — the among-category
   correlation surface V (how category liabilities coevolve) via `phylo_latent()`, following **Mizuno
   et al. 2025 (JEB)** — with the honest fence (needs per-species replication OR large N; the regularized
   one-per-species path is forthcoming). Point to Design 84.
4. `devtools::test()` + `R CMD check`; NEWS + honesty fence; then a PR (do NOT auto-merge). Generalize
   the fence to the other RE tiers (pseudo-trait mechanism).

## Blockers / open questions
- **Regularization FORM** is the maintainer's methodological call: the OLRE-with-fixed-R above (MCMCglmm's
  device, recommended) vs. adding R to the estimated V vs. a ridge on the loadings. Confirm before large
  investment.
- **Classifier outage** intermittently gated Bash/Agent this whole session (flaps open). Compile/fit runs
  eventually catch a window; the human ran several from their terminal to unblock.
- `conv=0` (non-PD Hessian) persists even when ρ̂ recovers — investigate (loadings-only rank edge).

## Gotchas / failed approaches
- **Single-seed fits LIE.** ρ̂=0.57/0.73/0.72 at n=2000/5000/10000 looked like recovery; the multi-seed
  campaign revealed SD 0.6 with ±1 collapses. Always multi-seed (the DISCIPLINE rule "single-N ±0.25 is
  not enough").
- `unique=TRUE` (Ψ companion) did NOT fix the collapse; `d=1`/`d=2` didn't either. Only replication or
  (expected) regularization stabilizes one-per-species.
- Smoke-fit data needs a `site` column (default `unit="site"`) and a single-level `trait` column (the
  expansion reads `data[[trait_col]]`); pass `tree=` INSIDE `phylo_latent(...)`, not the deprecated
  global `phylo_tree=`.
- I mis-scoped S2 twice ("trivial" → "needs re_trait_id" → "trivial, distinct pseudo-traits") before
  reading `expand_multinomial_response`. Read it first.

## How to resume
1. `git checkout claude/tier2a-phylo-multinomial` (commits `88d7820e`, `f38b80a5`; push if not pushed).
2. Read: this doc → the after-task report → `docs/design/84-phylogenetic-multinomial-tier2.md`.
3. Confirm the **regularization form** with the maintainer, then implement per the mapped assembly points.
4. Spawn **Rose** (review lens) before any "covered" claim; run the multi-seed campaign as the gate.
5. Compute: local sufficed to n=10000 (sparse A⁻¹); the regularized multi-seed grid is a good **Totoro**
   job — never GitHub Actions (D-50).

### One-command resume (paste in an authenticated terminal, repo root)
```
claude "Rehydrate from docs/dev-log/handover/2026-07-17-claude-handover.md + the after-task report on
branch claude/tier2a-phylo-multinomial. The phylo-multinomial CAPABILITY is built + committed and
honestly validated (recovers with replication; one-per-species too noisy without regularization). NEXT:
confirm the fixed-R=(1/K)(I+J) regularization form, implement it (assembly points are mapped in the
handover), re-run the multi-seed ladder to prove recovery, wire the link_residual, and add the
forward-looking Mizuno-multinomial paragraph to the multinomial() article (PR #751). Spawn Rose before
any covered claim."
```

## Mission control
| Thread | Branch / state | Leverage |
|---|---|---|
| Capability (report V) | `claude/tier2a-phylo-multinomial` `88d7820e` — DONE, committed | ✅ pure-R, no C++ |
| Recovery validation | multi-seed done — recovers w/ replication; one-per-species too noisy | 🟡 NOT covered |
| **Fixed-R regularization** | scoped, assembly mapped — NOT started | 🔴 HEADLINE / next |
| link_residual (binomial-scale) | scoped (`extract-sigma.R`) | 🟡 R-side |
| Article Mizuno paragraph | PR #751 `docs/multinomial-article` — pending | 🟡 prose |
| Design 84 scoping | PR #752 MERGED to `main` | ✅ |
