# Tier-2b multinomial 0.6 arc — session plan (item 1 + stage 2/3)

**Date:** 2026-07-17 · **Lane:** `claude/multinomial-tier2b` (worktree `/private/tmp/gtmb-tier2b`,
off `origin/main` `8a6367dd`). **Framed as 0.6, not 1.0** (maintainer instruction). Brief:
`docs/dev-log/handover/2026-07-17-multinomial-tier2b-arc-brief.md` (merged #757).

## Session goal (agreed)
Ship **item 1** end-to-end — the `(π²/6)(I+J)` matrix `link_residual` for multinomial traits —
then **stage** (not execute) items 2 and 3.

Item 1 done *correctly* (tier-agnostic block builder) discharges the maintainer's three additions:
- **other structural dependencies** — block added to whatever tier Σ `extract_Sigma` builds
  (phylo / spatial / kernel / ordinary latent), not phylo-only;
- **normal random effects** — block placed only in the multinomial pseudo-columns; Gaussian/normal-RE
  traits stay diagonal and become commensurable with the categorical block;
- **mixed distribution** — unit-tested now via synthetic mixed layouts; the *live* multinomial+gaussian
  fit is gated behind item 2's parser fence (flagged, not silently skipped).

## Slices
- **S1** `fid==16` diagonal π²/3 in `link_residual_per_trait` — DONE.
- **S2** `.multinomial_link_residual_offdiag()` pure helper + wire into `extract_Sigma` `part="total"`.
- **S3** roxygen "warns"→"applies" + notes text; `devtools::document()`.
- **S4** multi-seed integration (auto−none == (π²/6)(I+J) across seeds/Ks) + blast-radius check
  (omega/repeatability/communality/proportions/profile-derived unaffected) + broad `devtools::test()`.
  **Rose before any "covered" claim; multi-seed always.**
- **S5** after-task report + commit + PR vs `main` (low-risk → self-merge allowed).

## Stage (do not execute)
- **C2** item-2 Discussion Checkpoint memo — parser fence + (K−1)-vector reporting convention
  (Design 84 §7.3). Maintainer decision; no code until ruled.
- **C3** item-3 ultra-plan — Totoro recovery campaign (prior + posterior-mean vs MCMCglmm, multi-seed).
  Written, launch-ready. **Workflow fan-out fires here**, when maintainer approves.

## Guards
Rose before covered claims · multi-seed always · compute local→Totoro never Actions (D-50) ·
reader surfaces carry no register codes · Discussion Checkpoint before item-2 code.

## Math (settled, do not re-derive)
Softmax observation-scale residual over the K−1 baseline contrasts = `(π²/6)(I+J)`:
π²/3 diagonal (each contrast is a logit, as binomial-logit), π²/6 off-diagonal (shared baseline
couples contrasts). Reduces to binomial π²/3 at K=2. McFadden (1974); Nakagawa & Schielzeth (2010);
Nakagawa, Johnson & Schielzeth (2017). NOT MCMCglmm's `(1/K)(I+J)` identification residual or its `c²`.
