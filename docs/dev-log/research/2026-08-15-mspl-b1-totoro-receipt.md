# D-139 receipt — Design 118 B1 (Totoro canary + Totoro full)

**Date:** 2026-08-15 (proposed) · **updated 2026-08-16 overnight**
**Roles:** Gauss / Rose
**Lane:** overnight Cursor sitting after Shinichi G0
(`--mode=canary`, then full B1; prefer DRAC; Totoro full only if
DRAC impossible)

**Status:** **CANARY DONE. FULL B1 RUNNING ON TOTORO.**
Host used = **Totoro**. DRAC full array **not started** (impossible
tonight: `/project` quota exceeded; `MaxArraySize=10000` < 26400
tasks at `--outer-per-shard 3`). GitHub Actions **not** used.
Public MSPL `se=TRUE` / `sd_report` is **still withheld**. This is
**not** an SE-covered claim.

**Scanner:** `host=Totoro`. Canary `minutes≈2`. Full-grid estimate
still **~1,160–1,260** min @ 140 cores (B0 conversion); full job
started `2026-08-16T01:53:53Z` pid `2779264` workers=140.
DRAC started? **no**. Actions campaign? **no**. SE covered? **no**.

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
timing probe, not B1. **Overnight 2026-08-16 ran it on Totoro
and it was healthy** (see the update below).

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
receipt. The 2026-08-15 sitting filled it **before** any SSH.
The 2026-08-16 overnight sitting updates the live table below.

---

## Overnight update — 2026-08-16 (Shinichi G0: canary, then DRAC full, Totoro full only if DRAC impossible)

### Totoro canary — HEALTHY

Host `totoro`. Command:

```sh
MSPL_B1_PACKAGE_ROOT=/home/snakagaw/gllvmtmb-b1-timing-a3b31e62 \
MSPL_B1_OUT_ROOT=/home/snakagaw/gllvmtmb-local-artifacts/b1-canary-20260816 \
MSPL_B1_WORKERS=140 \
MSPL_B1_CONFIRM=yes \
  ~/mspl-b1-totoro-launch.sh --on-totoro --mode=canary
```

Checkout: `#981` @ `a3b31e62` (harness not on `main`).
Cell B010, 1 outer, 5 bootstrap reps. Wall **≈1–2 min**
(finished 2026-08-15 19:50:26 MDT). Wrote
`shards/B010-shard-001.csv` (3 rows, `status=ok`), 65
profile-trace rows, 10 bootstrap-replicate rows. One coordinate
was screen-refused (`constant_response`) with typed NA profile
bounds — fence behaviour, not a crash. Reap complete (D-142).
Not B1. Not coverage. Not SE-covered.

### DRAC full — NOT STARTED (impossible tonight)

`sbatch-b1.sh` on #981 is a **template**, not a ready launcher
(array bounds commented; `/project` paths required). Fir SSH
works (`login2`, `sbatch` present, account `def-snakagaw_cpu`
used by the earlier arc3 array). Staging failed:

- `mkdir /project/def-snakagaw/snakagaw/gllvmtmb-mspl-b1-20260816`
  → **Disk quota exceeded**. Touch inside the existing arc3
  tree also failed. `/project` used 29.59G with write refused.
- `MaxArraySize=10000` on fir; `--outer-per-shard 3` map is
  **26400** tasks (header+26400 from `--print-map`). Would need
  three arrays even after quota is freed.
- `/scratch` write works, but Design 118 / D-50 keepers stay on
  `/project`, never `/scratch`.

Exact DRAC command **after Shinichi frees `/project` quota**
and a one-time `R CMD INSTALL` of `a3b31e62` into `$ROOT/Rlib`
(setup job, not a login-node fit):

```sh
# On fir, after quota is free and setup INSTALL has finished:
ROOT=/project/def-snakagaw/snakagaw/gllvmtmb-mspl-b1-20260816
# Split 26400 tasks across MaxArraySize=10000:
#   sbatch --array=1-10000   sbatch-b1-filled.sh   # task-id 1..10000
#   sbatch --array=1-10000   sbatch-b1-filled.sh   # remap +10000
#   sbatch --array=1-6400    sbatch-b1-filled.sh   # remap +20000
# Each filled script must set:
#   MSPL_B1_PACKAGE_ROOT=$ROOT/source/gllvmTMB
#   MSPL_B1_R_LIB=$ROOT/Rlib:/home/snakagaw/R/lane_b_4.5
#   MSPL_B1_OUT_ROOT=$ROOT/out          # must be /project/*
#   #SBATCH --account=def-snakagaw_cpu
#   #SBATCH --time=02:30:00
#   --outer-per-shard 3 --reps 600 --bootstrap-reps 500
# Unset GLLVM_TMB_PILOT_SOURCE after INSTALL so 26400 tasks
# do not race load_all.
```

Do **not** submit that until `/project` accepts writes.
Do **not** put keepers on `/scratch`.

### Totoro full — STARTED (DRAC impossible)

Because DRAC could not be staged, the G0 fallback fired:

```sh
MSPL_B1_PACKAGE_ROOT=/home/snakagaw/gllvmtmb-b1-timing-a3b31e62 \
MSPL_B1_OUT_ROOT=/home/snakagaw/gllvmtmb-local-artifacts/b1-full-20260816 \
MSPL_B1_WORKERS=140 \
MSPL_B1_CONFIRM=yes \
  ~/mspl-b1-totoro-launch.sh --on-totoro --mode=full
```

Started **2026-08-16T01:53:53Z**, pid `2779264`, workers=140
(D-143 cap 150). 129 shard CSVs within 28 s; load rose to ~58
on a 384-core box. Estimate still ~19–21 h @ 140 cores from
the B0 conversion. If it overruns ~21 h, stop and re-report.

```sh
# Morning peek
ssh totoro 'tail -20 ~/gllvmtmb-local-artifacts/b1-full-20260816/logs/full-launch.log
ls ~/gllvmtmb-local-artifacts/b1-full-20260816/shards | wc -l
ps -p 2779264 -o pid,etime || echo finished'
```

---

## Live receipt table (2026-08-16 overnight)

| Field | Value |
|---|---|
| Status | **CANARY DONE · FULL B1 RUNNING** |
| Host actually used | **Totoro** |
| Canary minutes | **≈2** (B010, 1 outer, 5 boot; healthy) |
| Full estimate (min) | **~1,160–1,260** @ 140 cores (B0 conversion; still uncertain) |
| Full started | **2026-08-16T01:53:53Z** pid `2779264` |
| DRAC started? | **no** — `/project` quota exceeded; exact command recorded above |
| Actions campaign? | **no** |
| SE covered? | **no** |
| Public `sd_report`? | **still withheld** |

### Continuation peek — 2026-08-16T03:23Z

| Field | Value |
|---|---|
| pid `2779264` | **ALIVE** elapsed 1h29 |
| shards | **2095** (of 7,920 tasks) |
| task logs | 2253 |
| R workers | 282 |
| load | ≈140 / 140 / 141 |
| `Error\|FATAL\|Killed` in task logs | **0** |
| Second Totoro full? | **no** |
| Restart? | **no** (not a spawn-fail; first 10 min closed) |
| SE covered? | **no** |

Job was not silently restarted. If it later dies, write the
reason here; do not relaunch a 20 h full unless the death is
an obvious spawn fail (that window is over).

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
