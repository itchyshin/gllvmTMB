# After-task — Tier-2b item 2a-ii: cross-family correlations with a nominal (multinomial) trait

**Date:** 2026-07-18 · **Author:** Claude (Opus 4.8) · **Branch:** `claude/multinomial-tier2b-item2`
(worktree `/private/tmp/gtmb-item2`, off `main`). **Framed as 0.6.**

## What shipped
A `multinomial()` trait can now share an ordinary latent ordination
(`latent(0 + trait | unit, d, unique = FALSE)`) with **other-family** traits, so its K−1
baseline-contrast pseudo-traits load on the shared factor and the **cross-family (nominal ↔ Gaussian /
binary / count / ordinal)** covariance lives in Λ. `extract_Sigma` / `extract_correlations` report the
cross-block, and a new `extract_cross_correlations()` gives the decision-2C summary (reference-invariant
multiple correlation + optional (K−1)-vector).

The maintainer's Discussion-Checkpoint rulings were followed: parser scope 1a→1b (narrow first); reporting
2C (reference-invariant multiple correlation default, (K−1)-vector on request).

## Commits (this branch)
- `0c942f77` — cross-family latent sharing + 2C reporting: lift the Tier-2a fence for `use_rr_B`/`use_lv_B`
  (keep `use_diag_B`/SPDE/phylo-slope/re_int fenced); broaden the `extract_Sigma`/`extract_correlations`
  refusal from `phylo_rr`-only to any latent tier; new `extract_cross_correlations()`.
- `ad31e8c0` — automate subset-expansion: `expand_multinomial_response()` expands ONLY the multinomial
  trait's rows inside a mixed-family long dataset (others pass through, tagged `.multinom_group_ = -1`),
  so the user-facing call is clean (raw long data + a `family_var` column, no hand-built columns).

## Key engineering finding
**No C++ change was needed.** The softmax likelihood (fid 16) already composes with a shared latent
factor — a single-multinomial + `latent()` spike converged, and the pseudo-traits are ordinary traits in
the long format that receive their Λ_B loading and LV η contribution generically. Item 2a-ii is therefore
R-side only (fence-lift + subset-expand + reporting).

## Verification — multi-seed 5-family recovery (5/5 converged)
One fit, five families sharing a 3-factor latent (N=500 units × 6 reps, `dev/cross-family-5family-demo.R`
and `-multiseed.R`). Recovered latent cross-correlations vs known truth:

| pair | true | mean ρ̂ (5 seeds) | MCSE |
|---|---|---|---|
| g ~ b (gaussian~binary) | +0.908 | +0.909 | 0.008 |
| p ~ o (count~ordinal) | +0.718 | +0.712 | 0.013 |
| g ~ cat:2 (gaussian~nominal) | +0.941 | +0.938 | 0.006 |
| b ~ cat:2 (binary~nominal) | +0.989 | +0.989 | 0.003 |
| o ~ cat:2 (ordinal~nominal) | +0.787 | +0.768 | 0.020 |
| p ~ cat:3 (count~nominal) | +0.712 | +0.681 | 0.025 |
| g ~ cat:3 (gaussian~nominal) | −0.323 | −0.368 | 0.028 |

All cross-family correlations — Gaussian, binary, count, ordinal, **and** nominal — recover close to truth
with small MCSE. The weaker/near-zero `g~cat:3` pair is the noisiest (as expected). `extract_cross_correlations`
2C multiple_r (observation scale): cat~g 0.62, cat~b 0.28, cat~p 0.40, cat~o 0.29.

Focused test suite `tests/testthat/test-cross-family-multinomial.R`: 17 pass (auto-expand, no-refusal
reporting, 2C shape + reference-invariance, multi-seed recovery). `test-multinomial.R`: 43 pass.

## NOT covered (explicit)
- Loadings-only for the nominal trait (`unique = FALSE`); a per-contrast Psi tier on a categorical
  response is deferred (still fenced).
- One multinomial trait per fit only.
- Interval coverage for the cross-family correlations is not yet calibrated.
- One-per-unit nominal recovery is data-hungry (rails at ±1); the demo uses replication (reps per unit)
  and large N. See `2026-07-17-tier2b-item3-recovery-launch.md` for the depth of that caveat.

## Guards honored
Multi-seed (5/5) for the recovery claim · smoke-first on every fit · fail-loud fences preserved for the
deferred tiers · reader surfaces carry no register codes · results local (D-50) · Rose adversarial review
dispatched before the covered claim (finish workflow).
