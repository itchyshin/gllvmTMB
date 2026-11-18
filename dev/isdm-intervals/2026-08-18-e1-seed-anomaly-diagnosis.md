# E1 seed-block anomaly — diagnosis

**VERDICT: NOT A BUG (real statistical artifact). Mechanism: selection-induced
regression to the mean from the pre-registered escalation rule, amplified by
shared-seed cross-cell correlation — the same 600 seeds drive every cell in
block 1, so cells fluctuate low *together*, get escalated together, and fresh
seeds then regress upward together.**

Anomaly under diagnosis (results doc §4): on the 9 escalated cells, block 2
(seeds 1601–3000) coverage exceeds block 1 (1001–1600) in 21 of 27
cell × species differences, mean +0.0101, reported sign-test p ≈ 0.004.

Reproduced exactly from the CSVs before any diagnosis: block 1 pooled
(0.9417, 0.9409, 0.9383), block 2 (0.9475, 0.9480, 0.9556); diffs 21/27
positive, mean +0.01005. Denominator = PD & `se_ok` fits, as the scorer uses.

All analyses below are **measured** unless marked *inferred*. Analysis script:
session scratchpad `e1-anomaly.R` / `e1-anomaly2.R` (seed-set bootstrap,
per-seed trend tests, determinism comparison); not committed.

---

## Hypotheses, tests, results

### H1 — RNG / parallelism (RULED OUT)

`run_cell()` calls `set.seed(seed)` as its first statement and no RNG is used
outside it (grid construction is deterministic; `mclapply` draws nothing). No
L'Ecuyer-CMRG stream is set, but none is needed: each fit re-seeds. Verified
empirically rather than assumed — see H3: bit-for-bit reproduction under a
*different* core count (20 vs the campaign's 100) and a different grid shape
means no fork-inherited RNG state reaches anything scored.

### H2 — Sequential-seed (Mersenne-Twister) correlation (RULED OUT)

- Naive per-fit logistic regression of the coverage indicator on seed within
  block 1 looks alarming: slope +7.7e-4, **p = 9.0e-07** (16 cells).
  **That p-value is invalid**: all cells share the same seeds, and the 27–48
  indicators per seed are positively correlated — measured variance of the
  per-seed mean coverage is **4.53×** the independent-binomial expectation,
  implying average pairwise indicator correlation **0.151** at the same seed.
- At the correct unit of inference (one per-seed mean per seed):
  block 1, 16 cells: slope 4.3e-5, **p = 0.056** (permutation p = 0.056);
  block 1, 9 cells: p = 0.073 (permutation p = 0.077);
  **block 2: slope −2.6e-6, p = 0.68** — flat over 1,400 consecutive seeds.
- 200-seed window means over the whole range (9 cells): 0.9336, 0.9376,
  0.9490, 0.9586, 0.9451, 0.9610, 0.9450, 0.9362, 0.9530, 0.9544 —
  non-monotone fluctuation of the size shared-seed correlation predicts, not
  a seed-value trend. Block 1's last 200 seeds (0.9490) already match block 2
  (0.9505); block 1's first 400 seeds were the low stretch (0.9336/0.9376).
  A seed-value mechanism would have to continue into block 2; it does not.

### H3 — Non-determinism / run-shape dependence (RULED OUT)

Re-ran 20 block-1 fits on Totoro (cells 150:1:2:2 and 810:1:2:1, seeds
1001–1010) in the current environment, with `CAMPAIGN_CORES=20` and a 2-cell
grid — i.e. deliberately different chunking and memory pressure from the
16-cell, 100-core original. **All 20 rows reproduce the committed CSV exactly
on every scored column (11/11 columns, 20/20 rows: conv, pd, se_ok, all three
cov_env, lam_se_ok, lam_report_se, cov_eta_po, cov_eta_pa, sefit_ok).**
Fits are deterministic given (cell, seed); run shape is irrelevant.

### H4 — Package version between blocks (RULED OUT)

Totoro file timestamps: campaign-private library install finished 08:57:10
(`install.log` `* DONE (gllvmTMB)`; `.Rlib-campaign/gllvmTMB/DESCRIPTION`
mtime 08:57:10), `e1-n600-results.csv` written 09:06:39, `e1-escalation-
results.csv` 09:12:03, all 2026-08-18. Both blocks ran back-to-back against
the same freshly installed 0.7.0 library (`packageVersion` in that library
confirms 0.7.0). No version change between blocks was possible.

### H5 — Selection / regression to the mean (CONFIRMED, with the shared-seed
correlation as the necessary amplifier)

Block 2 exists only for the 9 cells whose block-1 verdicts were INDETERMINATE
— i.e. cells conditioned on a low block-1 coverage estimate. Quantified two
ways:

1. **Independent-binomial parametric simulation** (truth = combined per
   cell × species estimate, n = 552 usable, actual Wilson/INDET selection
   rule): expected shift **+0.0026**. Too small on its own — pure RTM under
   independence explains only ~a quarter of +0.0101.
2. **Seed-set bootstrap on the real data** (treat the 2,000 seeds as
   exchangeable — justified by H2/H3; draw 600 as pseudo-block-1, apply the
   actual selection rule, score pseudo-block-2 minus pseudo-block-1 on the
   selected cells; preserves the shared-seed correlation exactly):
   - Unconditional (B = 2,000): median shift **+0.0049**, 95% interval
     (−0.0077, +0.0133); **P(shift ≥ +0.01005) = 0.113**.
     P(≥ 21/27 positive signs) = **0.30** — the reported p ≈ 0.004 assumed 27
     independent signs and is invalid under the measured 0.151 correlation.
   - Conditional on heavy selection, which is what actually happened
     (9 of 16 cells escalated; B = 4,000): n_sel ≥ 6 → median **+0.0077**,
     P(≥ obs) = 0.25; n_sel ≥ 8 → median **+0.0094**, P(≥ obs) = **0.39**,
     P(≥ 21/27 signs) = 0.64. The observed shift is the *typical* outcome of
     the design given that many cells escalated.
   - Yardstick with **no selection at all**: split block 2 in half
     (700 vs 700 seeds, same 9 cells): mean diff −0.0048, 11/27 positive —
     shared-seed noise alone produces "block effects" of half the observed
     size in either direction.

*Inferred mechanism statement:* block 1's early seeds happened to run low
across cells simultaneously (a correlated fluctuation the shared-seed design
makes ~4.5× more variable than independent cells would be); that joint low
stretch is what pushed 9 cells' Wilson lower bounds under 0.92 and triggered
escalation; fresh seeds then read higher on exactly those cells. Every
component of that chain is measured above.

Also ruled out in passing: a **denominator artifact** — the usable
(PD & se_ok) rate has no seed trend (p = 0.39 block 1, p = 0.70 block 2) and
per-seed coverage is uncorrelated with per-seed usable rate (r = 0.0014); and
a **scorer bug interacting with n** — the anomaly was recomputed here directly
from the raw CSVs without `score-e1.R`, and reproduces identically.

---

## Does the 48/48 PASS stand?

**Yes — and the check strengthens it rather than inheriting it:**

- Block-2-only verdicts on the escalated cells (selection-free, ~1,270 usable
  fits each): **27/27 PASS**, coverages 0.9389–0.9649. The 7 non-escalated
  cells (21 verdicts) passed on block 1 alone. So a selection-free scoring
  path reaches 48/48 without using any conditioned block-1 data on the
  escalated cells.
- The combined estimator does carry a small selection bias from including the
  conditioned block-1 fits: ≈ (n1/(n1+n2)) × E[p̂1 − p | selected] ≈
  **−0.0008** — *downward*, i.e. conservative against the 0.92 band floor
  that every borderline verdict sits near. Combined coverages on the
  escalated cells: 0.9387–0.9574, all inside [0.92, 0.98] with room ≫ 0.0008.

## What should change

1. **Nothing in the harness for correctness.** It is deterministic (verified
   bit-for-bit), version-pinned, and reproducible. No code bug was found.
2. **Results doc §4 should be corrected**: the sign-test p ≈ 0.004 assumes 27
   independent differences; under the measured cross-cell correlation and the
   escalation's selection, the correct tail probability is 0.11 unconditional
   and 0.25–0.39 conditional on the observed selection intensity. The
   "unexplained systematic difference" is the expected behaviour of the
   pre-registered design, not a live anomaly. (Correction not applied here —
   this lane was instructed not to edit campaign results.)
3. **Design note for future escalations** (pre-registration template): (a)
   block-1 vs block-2 comparisons on escalated cells are biased upward by
   construction — by ≈ +0.008 to +0.009 at this selection intensity — and
   should never be read as a seed effect; (b) because every cell shares one
   seed vector, cross-cell agreement is not evidence of a systematic
   mechanism — if per-cell independence is wanted for diagnostics, derive the
   seed per (cell, rep), e.g. `seed = base + rep + cell_index * 10^5`, at the
   cost of losing the common-random-numbers variance reduction for
   *between-cell* contrasts; (c) if a combined estimate must be exactly
   unbiased, score escalated cells on escalation seeds only — here the
   combined bias (−0.0008, conservative) is immaterial.

## Provenance of every number

- Reproduction, trend tests, correlation, bootstraps: computed from the two
  committed CSVs (`e1-n600-results.csv`, `e1-escalation-results.csv`) on
  2026-08-18; scripts in the diagnosing session's scratchpad.
- Determinism: `e1-repro-check.csv` on Totoro
  (`~/gllvmtmb-e1-campaign-20260818/dev/isdm-intervals/`), 20 fits, compared
  row-by-row to the committed block-1 CSV.
- Version pinning: Totoro `install.log` and file mtimes, read 2026-08-18.
