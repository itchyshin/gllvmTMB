# B0 fence-ROC results — Design 118 §5.3, run 2026-08-15 on Totoro

**Run:** 240/240 shards · 7,200/7,200 rows `ok` · 32 s wall at 140-way parallel ·
harness commit `86014f1a` on `claude/mspl-b0-prereqs` · fresh seeds
(`118,000,000 + case_number·1,000,000`, disjoint from the 2026-08-14 archive) ·
Totoro cleaned after retrieval (D-142). Raw shards retained locally (3.7 MB,
240 CSVs; session scratchpad `b0-results/`, to be archived with the Phase-B
artefacts).

## Pre-registered gates, evaluated AS WRITTEN

| Gate (Design 118) | Threshold | Measured | Verdict |
|---|---|---|---|
| P5 — probe attractor prediction (C011 t3, n=189) | 1.715161 / 1.466704 to 4 dp | **1.715161 / 1.466704** (exact to 6 dp) | **PASS** |
| Probe false-refusal on anchors C001/C004/C005/C008 (n=2,400) | ≤ 0.05 | 0.0147 | **PASS** |
| Probe detection on C011 target-3 diseased rows (n=192) | ≥ 0.90 | **0.0000** | **FAIL** |
| Route A/B switch rule — corr(log\|S\|, log\|S_surr\|), n=7,134 | ≥ 0.95 | 0.8744 | **FAIL** (FD probe stays; surrogate cannot replace it) |

## The fence, measured by label class (7,200 coordinates)

| Class | n | Screen (line 1) catch | Probe s_j ≥ 1.0 (line 2) catch |
|---|---:|---:|---:|
| L1 saturated & L2 at-attractor | 497 | **100%** | (redundant — already refused) |
| L1 saturated only | 12 | **100%** | — |
| **L1 NOT saturated, L2 at-attractor** | **782** | **0%** | **0%** (s_j 0.03–0.41, some NA) |
| healthy | 5,909 | 0% flagged (correct) | false-refusal 1.5% on anchors |

**What this means.** The screen is perfect on fully saturated columns — the C011-class
catastrophe cannot reach a user. But **10.9% of all fitted coordinates sit at a
count-attractor value without their column being saturated** (top cells: C011 178,
C003 151, C002 137 — including logit), and the pre-registered two-line fence catches
none of them. The probe's mechanism is vindicated (P5 exact) while its **threshold
role fails**: penalty-determined movement per e-fold is ≈0.25–0.4 SE at the attractors,
never ≥1.0. The s_j ≥ 1.0 refusal tier, fixed a priori by interpretation, is
mis-calibrated against the measured disease by a factor ~2.5–3.

## Why there is a principled fix on the table (not post-hoc tuning)

The count-attractor roots depend only on the observed per-column success count k, the
design (n, T), c_n, and the link — **all fit-time observables** (A1b Task 1: the roots
are analytic). "Estimate within tolerance of its own column's k-attractor root" is
therefore a legitimate fit-time refusal statistic, and it is the exact quantity whose
disease-defining role A1b established *before* B0 ran. Adopting it as fence line 2
(replacing the s_j threshold) is a **§8-recorded deviation requiring maintainer
sign-off** — it changes the pre-registered fence — but it is not data-dredged: the
statistic predates the measurement, and B0's L2 label *is* this statistic (782/782
escapes are by definition caught by it; its false-positive rate on healthy rows is
0/5,909 at the harness tolerance).

Open question the maintainer's call should weigh: whether the 782 near-attractor,
non-saturated coordinates actually break interval coverage is **measured by B1's
per-cell coverage gates**, not by B0. Options range from refusing them outright
(conservative) to flagging them and letting B1 measure the consequence.

## Timing (D-139 input for B1/B2)

Totoro: 1.04–1.51 s per outer dataset (3 fits + penalised Hessian + screen) by cell;
mean ≈ 1.2 s. Reduced Phase B (≈26 M fit-equivalents, D2) at ≈0.4 s/fit-equivalent ⇒
**≈2,900 core-hours** — comfortable for DRAC job arrays (e.g. ~500 cores × ~6 h), with
B0's harness pattern (per-shard CSV, fresh-seed discipline) carrying over.

## Deviations ledger entries proposed (for Design 118 §8, pending sign-off)

1. Probe detection gate (≥0.90) FAILED as written; mechanism understood; P5 passed.
2. Route A/B switch rule FAILED (0.874 < 0.95): the FD probe is not replaceable by the
   free surrogate wherever a probe is used.
3. Proposed fence amendment: line 2 becomes the attractor-proximity statistic; the
   s_j probe is retained for §6.1 penalty-sensitivity *reporting* (its validated,
   mechanism-true role), not for refusal.
