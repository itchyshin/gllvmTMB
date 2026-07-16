# After-task — multinomial recovery-band calibration + Tier-1 backlog close (FAM-20)

**Date:** 2026-07-16 · **Author:** Claude (Fable 5) · **Branch:** `agent/lane-c-multinomial`
(worktree, local/unpushed). Closes the recovery + honesty gaps the 2026-07-16 D-43 re-audit
raised (`2026-07-16-multinomial-fam20-reaudit.md`). FAM-20 **stays `partial`** — this addresses
the gaps; it does not promote.

## Scope (the authorized Tier-1 backlog)
1. Calibrate the recovery bands (they were borrowed from ordinal by analogy, never calibrated).
2. Make the K=3 (and K=4) recovery cells seed-robust (the audit found the K=3 single-seed cell
   passed only on a lucky `seed=1L`).
3. Reconcile the K=2 byte-identity contradiction in Design 83 §6.
4. Correct the residual honesty over-claims in Design 83.

## 1–2. Recovery-band calibration → seed-robust cells
- **`dev/multinomial-recovery.R`** (new): sweeps N seeds for K=3 (n=300, n=600) and K=4 (n=600)
  on the exact test DGP, reporting convergence/PD rate, per-coefficient **bias**, SD, and abs-error
  quantiles, plus per-band pass rates. **Run locally at 500 seeds** (~2 min; each fit ~0.1s — this
  is *not* a Totoro/DRAC-scale campaign, and running it locally gives immediate feedback; never
  GitHub Actions, D-50).
- **Result (500 seeds, all cells 500/500 converged PD):** the softmax MLE is **unbiased** —
  |bias| ≤ 0.023 for every coefficient. The problem the audit found was pure sampling **variance**:
  | cell | per-fit SD (max) | band 0.40 all-pass | band 0.50 all-pass |
  |---|---|---|---|
  | K3 n=300 (old cell) | 0.228 | **0.85** | 0.94 |
  | K3 n=600 | 0.160 | 0.96 | 0.99 |
  | K4 n=600 (old cell) | 0.167 | 0.95 | 0.99 |
  So the old K3 n=300/abs-0.40 single-seed cell failed on ~15% of seeds; `seed=1L` was favorable.
- **Fix (`test-multinomial.R`):** the K=3 and K=4 single-seed cells are replaced by **20-seed
  aggregate cells at n=600** asserting the **seed-mean within a calibrated abs-0.15 band**. The
  seed-mean SD over 20 fits is ≈ 0.036, so 0.15 is ~4 SD from truth — **tighter than the retired
  0.40 band AND essentially non-flaky**, and it tests *unbiased recovery* rather than one lucky
  draw. The supplementary 5-seed n=400 aggregate cell (band 0.30) is retained.
- **Note on assertion count:** `test-multinomial.R` moved 48→39 non-skipped expectations because the
  recovery cells no longer repeat per-fit shape checks (`s3_class`, `family_id_vec==16`, length) —
  those are covered by the dedicated fid-16 dispatch cell, and each recovery loop still filters on
  `family_id_vec==16` + PD convergence. No structural coverage was lost. Verified **39/0/0** under
  `NOT_CRAN` (11.2s).

## 3. K=2 byte-identity contradiction — reconciled (no hollow test)
Design 83 §6 promised a "K=2 byte-identity to `binomial(logit)` to 1e-6" recovery cell, but §2 also
**fences K=2** (`multinomial()` errors and redirects to `binomial()`). These contradict: there is no
K=2 multinomial fit to run a byte-identity test against. Honest resolution (doc, not a hollow test):
K=2 reduces to binomial *by construction* (the single non-baseline contrast's 0/1 indicator
likelihood *is* the binomial logit); the fence redirects users to `binomial()`; and the softmax's
correctness at every K — including that K=2 limit — is already established by the `nnet::multinom`
cross-check (objective agreement to 1.66e-9, from the D-43 likelihood lens), which subsumes K=2.
Adding a fence-bypassing white-box K=2 fit would be high-coupling for near-zero marginal confidence.

## 4. Honesty corrections (Design 83 §3/§6 + register)
- `extract_Sigma()` (capital S; there is no `extract_sigma`) returns **NULL** on a multinomial fit;
  `extract_repeatability()` **errors** on the absent variance components — both the **generic**
  behaviour of any fixed-effects-only fit, not a multinomial-specific abort. Only
  `extract_correlations()` is a real typed multinomial hard-refuse. None is silent-wrong. §3 line 115
  and the register corrected.
- The phantom test-file names in Design 83 §6 (`test-multinomial-recovery.R`, `-unit.R`,
  `-matrix-...-unit.R`) retired → the real `test-multinomial.R`.

## Checks
- `test-multinomial.R` **39 PASS / 0 FAIL / 0 SKIP** under `NOT_CRAN` (11.2s).
- Calibration: 500 seeds/cell, 500/500 PD, unbiased — see `dev/multinomial-recovery.R`.

## FAM-20 status
Both re-audit NOT-DONE gaps (recovery, honesty) are now **addressed**; the K=2 contradiction is
reconciled. FAM-20 **stays `partial`** — the remaining promotion gates are the maintainer's
`extract_Sigma` abort-vs-NULL design call and a **fresh D-43 re-audit of these fixes** (they were
not re-verified by independent lenses), plus sign-off. No public surface advertises multinomial.

## Follow-ups
- Maintainer: decide `extract_Sigma` on a structureless/multinomial fit — abort (consistency) vs NULL.
- If promoting: run a fresh 3-lens D-43 re-audit of these fixes, then flip FAM-20 + NEWS/README.
- Tier 2a (correlated category random effects → the (K−1)×(K−1) table) is a separate future arc.
