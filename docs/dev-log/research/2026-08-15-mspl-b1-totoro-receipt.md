# D-139 receipt — Design 118 B1 proposed on Totoro (not launched)

**Date:** 2026-08-15
**Roles:** Gauss / Rose
**Lane:** `cursor/mspl-b1-totoro-receipt` (this file + launcher only)
**Status:** **PROPOSED, NOT STARTED.** Host = **Totoro**. Full-grid
estimate **~2,900 core-hours / ~19–21 h wall at 140–150 cores**.
This sitting did **not** SSH and did **not** start the campaign.

**Scanner:** B1 interval-calibration D-139 receipt is **filled**.
`host=Totoro`. `minutes` for the full grid is **~1,160–1,260**
(19–21 h), from B0's published conversion, **not** a B1-measured
shard. Totoro **not** occupied. DRAC **not** started. GitHub
Actions **not** used. Public MSPL `se=TRUE` / `sd_report` is
**still withheld**. This is **not** an SE-covered claim.

**Reader:** the human or next agent who will fire
`dev/mspl-b1-totoro-launch.sh`. Read the estimate caveats before
`--launch`. Default of that script is dry-run.

This file **is** the D-139 receipt for B1. The 2026-08-15
`docs/dev-log/research/2026-08-15-mspl-no-se-campaign-receipt.md`
receipt remains the SE-campaign receipt: **NONE ISSUED**, host
none. Filling *this* table does not repeal that one.

---

## Verdict

Shinichi lifted the B1 Totoro fence. B1 (Design 118 calibration
grid, F-AMD fence, reduced ≈26 M fit-equivalents) is now proposed
on **Totoro**, not as a DRAC array, at the B0-derived budget
below. The job is **>30 min**, so D-139 requires this receipt
plus the B0 pre-run (already on disk) before anyone starts it.

Nothing in this sitting starts that job.

---

## What B1 is, and what it is not

B1 is the Design 118 §5 calibration campaign: 132 cells × 600
reps, `--outer-per-shard 10` → **7,920** shard tasks, fence line 2
= F-AMD (attractor-proximity; DEV-3), bootstrap on a
deterministic 1-in-3 of bootstrap-bearing cells. Harness and
launch spec live on open PR
[#981](https://github.com/itchyshin/gllvmTMB/pull/981)
(`claude/mspl-b0-prereqs`): `inst/sim/b1-calibration/`,
`docs/dev-log/2026-08-15-b1-launch-spec.md`. They are **not** on
`origin/main` as of `fe867e40`.

B1 is **not**:

- a calibrated SE campaign, a `vcov()` / `confint()` / `sdreport()`
  admission, or an MSPL-04 register promotion;
- a repair of Bernoulli \(Q_0\) (min eigenvalue **−0.774** on the
  #979 first cell);
- permission to treat public `se=TRUE` as covered.

The no-SE receipt still governs those. A later conductor who
reads only this file and occupies Totoro "to get SEs" is
misreading it.

---

## Time estimate (D-139 — from B0, stated before any SSH)

**Pre-run already shown:** B0 on Totoro, 2026-08-15
(`docs/dev-log/2026-08-15-b0-fence-roc-results.md` on #981):
240/240 shards, 7,200/7,200 rows `ok`, **32 s wall at 140-way
parallel**, then cleaned (D-142). Per-outer (3 fits + penalised
Hessian + screen): **1.04–1.51 s** by cell, mean **≈1.2 s**.
Published conversion: **≈0.4 s/fit-equivalent**. Reduced Phase B
(≈26 M fit-equivalents, D2) ⇒ **≈2,900 core-hours**.

| Quantity | Number | Source |
|---|---|---|
| B0 wall | 32 s / 140 cores / 7,200 fits | B0 results, Totoro |
| Seconds per B0 outer | 1.04–1.51 (mean ≈1.2) | same |
| Fit-equivalent used for B1 | ≈0.4 s | same, "Timing (D-139 input for B1/B2)" |
| B1 fit-equivalents | ≈26 M (D2 reduced) | Design 118 §6.2; B0 results |
| B1 core-hours | **≈2,900** | 26e6 × 0.4 / 3600 |
| Totoro wall @ 150 cores | **≈19.3 h** | 2900 / 150; D-143 ceiling |
| Totoro wall @ 140 cores | **≈20.7 h** | B0's own parallelism |
| Totoro wall @ 120 cores | **≈24.2 h** | quieter shared-box choice |
| Shard tasks | 7,920 | 132 × ceil(600/10); B1 README |
| Mean seconds/task @ 0.4 s | ≈1,313 s (22 min) | 26e6 / 7920 × 0.4 |

**Honest uncertainty — this is an extrapolation, not a B1
shard.** B0 timed 3-fit + Hessian + screen. B1 adds a widened
penalised-profile walk (`level = 0.99`, `max_widen_rounds = 3`)
and a 500-rep bootstrap on one-third of datasets. The 0.4
s/fit-equivalent figure is the B0 note's own conversion for
Phase B; the B1 harness README still marks `--time` as
**PROVISIONAL, local-only, EXTRAPOLATED** and says the
definitive calibration is a Totoro job. If the true mean
fit-equivalent is 1.2 s (B0's per-outer mean, no bootstrap
discount), wall at 140 cores becomes **~62 h**. Worst-corner
cells (cloglog × π=0.97 × `n_site=12`, B010 in the #981 grid)
can be several times the mean; one *full* registered shard of
that cell may itself exceed 30 min.

**If the run overruns this estimate:** stop and re-report
(D-139). Do not quietly continue past ~21 h at 140 cores
without a new number.

**Canary (optional, ≤30 min intended):** one reduced shard of
B010 (`--outer-per-shard 1 --bootstrap-reps 5`). That is a
timing probe, not B1. The launcher `--mode=canary` prints that
command. This sitting does not run it.

---

## Receipt table

| Field | Value |
|---|---|
| Status | **PROPOSED — not launched this sitting** |
| Host | **Totoro** (Shinichi lifted the B1 Totoro fence) |
| Estimate (min) | **~1,160–1,260** full grid @ 140–150 cores (B0 conversion); **uncertain** if B1 profile+bootstrap is slower than 0.4 s/fit-eq |
| Pre-run test + result | B0 Totoro 7,200/7,200 ok, 32 s wall @ 140-way; P5 exact to 6 dp; probe-detection gate FAIL as written (DEV-1); F-AMD signed (DEV-3) |
| Why local pin is insufficient | B1 is the signed 132-cell / 600-rep calibration grid (≈26 M fit-eq), not the #979 two-cell Hessian pin |
| Shinichi approval | B1 launch authorized 2026-08-15 (*"Approve"*, *"Gate is open"*) on the reduced budget under F-AMD (Design 118 §8). Totoro host fence **lifted** this sitting (conductor instruction). D3's written placement was DRAC; this receipt records the host amendment. |
| Core / array request | **140 workers** default (B0's measured parallelism), hard-capped at **150** (D-143). Not a DRAC array. |
| What happens if it overruns | stop and re-report; do not extend past the estimate |
| Totoro started? | **no** |
| DRAC started? | **no** |
| Actions campaign? | **no** |
| SE covered? | **no** |

Filling this table after a job has started would not have been a
receipt. This sitting fills it **before** any SSH.

---

## Placement note (D3 vs this receipt)

Design 118 §6.4 and D3 placed B0 on Totoro and B1/B2 on **DRAC
job arrays**. The B1 launch spec on #981 still describes a
~500-task / `--time=03:00:00` Narval array at the same 2,900
core-hour budget. Shinichi lifted the Totoro fence for B1, so
this receipt proposes **host=Totoro** at ≤150 cores. That is a
host choice, not a grid change. DRAC remains legal if a later
conductor prefers the array; this receipt does not launch
either.

---

## Exact fire command (next agent / human — not this sitting)

Dry-run (safe; default; this sitting's only allowed invocation):

```sh
# From this branch, or from a #981 checkout that has the harness:
dev/mspl-b1-totoro-launch.sh --mode=full
```

The script prints the remote plan and exits 0. It does not SSH.

To actually occupy Totoro (**forbidden in this sitting**; D-139
already has the estimate above):

```sh
# 1. Harness must exist: merge or check out #981 (claude/mspl-b0-prereqs).
# 2. Point at a Totoro checkout and an output root *outside* the repo.
# 3. Two keys required — --launch alone is refused.
MSPL_B1_PACKAGE_ROOT=~/gllvmtmb-mspl-b1 \
MSPL_B1_OUT_ROOT=~/gllvmtmb-local-artifacts/b1-calibration \
MSPL_B1_WORKERS=140 \
MSPL_B1_CONFIRM=yes \
  dev/mspl-b1-totoro-launch.sh --mode=full --launch
```

Optional ≤30 min timing canary (still not this sitting):

```sh
MSPL_B1_CONFIRM=yes \
  dev/mspl-b1-totoro-launch.sh --mode=canary --launch
```

Never GitHub Actions (D-50). Never `NWORKERS>150` without a
fresh, explicit, per-run yes (D-143). Reap the `xargs` process
group when done (D-142).

---

## What this receipt does not authorise

- Starting Totoro or DRAC from *this* sitting.
- Claiming SE covered, `planned` → `admitted`, or NEWS
  "covered".
- Public `vcov()` / `confint()` / `sdreport()` on MSPL.
- Editing `src/`.
- Merging #981 on CI green alone (`src/gllvmTMB.cpp` is
  high-risk).
- Treating the 0.4 s/fit-equivalent number as a B1-measured
  shard time.

## Sources

- Design 118: `docs/design/118-mspl-interval-calibration-protocol.md`
  (§5 grid, §6.2–6.4 budget/placement, §8 DEV-1..4 + B1
  authorization)
- PR #981: https://github.com/itchyshin/gllvmTMB/pull/981
  (`claude/mspl-b0-prereqs`) — harness, B0 results, B1 launch spec
- B0 timing: `docs/dev-log/2026-08-15-b0-fence-roc-results.md` on #981
- B1 launch spec: `docs/dev-log/2026-08-15-b1-launch-spec.md` on #981
- SE receipt (still NONE ISSUED):
  `docs/dev-log/research/2026-08-15-mspl-no-se-campaign-receipt.md`
- Compute policy:
  `docs/dev-log/research/2026-08-15-mspl-compute-totoro-drac.md`
- D-50 / D-139 / D-142 / D-143: `shinichi-brain/memory/decisions`
