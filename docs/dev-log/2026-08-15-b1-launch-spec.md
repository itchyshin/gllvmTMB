# B1 launch spec — ready on either fence branch (NOT launched; D-139 gate open)

**Status:** launch-ready specification. Nothing here runs until Shinichi (a) calls the
§8 fence question and (b) authorizes the DRAC array. Default: no launch.

## The two conditional arms (pre-decided, so the fence call does not force a redesign)

| Arm | Fence line 2 | What B1 reports for the 782-class band |
|---|---|---|
| F-REG (as pre-registered) | s_j ≥ 1.0 probe threshold | Coverage of near-attractor non-saturated coordinates measured UNGUARDED — their miscoverage, if any, lands in the per-cell gates |
| F-AMD (proposed §8 deviation) | attractor-proximity: \|estimate − root_k\| < tol, roots analytic from (k, n, T, c_n, link) | Same coordinates REFUSED; coverage reported on the surviving set; refusal rate per cell recorded |

The harness difference is one flag: both statistics are already computed per
coordinate by the B0 library (`lib-b0-fence-roc.R`: `s_j`, `label_l2` = the proximity
statistic at harness tolerance). B1 inherits that library.

## Grid (Design 118 §5, unchanged by the fence call)

Registered cells incl. the two c_n/N_eff de-confounding arms (C-ID1: N_eff=288 fixed,
c_n varying; C-ID2: c_n fixed, N_eff varying), continuous prevalence levels, all three
links; hold-out blocks declared before calibrator fitting: **all of probit**, both
near-extreme prevalence levels, largest N. n = 600 reps/cell, one-shot escalation to
2,000 for hold-out cells on an INDETERMINATE verdict. Reduced budget (D2): bootstrap
on 1/3 of datasets, ≈26 M fit-equivalents.

## DRAC job-array shape (from B0 measured timing)

- ≈0.4 s/fit-equivalent (Totoro-core; DRAC cores comparable) ⇒ **≈2,900 core-hours**.
- Array: one task per (cell × shard), `--outer-per-shard 10`, same per-shard CSV
  contract as B0; `$SLURM_ARRAY_TASK_ID` maps to the (cell, shard) pair.
- Suggested: `--time=03:00:00`, ~500 concurrent tasks, `OPENBLAS_NUM_THREADS=1`,
  output root on `/project` (never `/scratch` for keepers), `sbatch` only — never a
  login node. Seeds: `b1_seed_base` disjoint from both the 2026-08-14 archive
  (1.9e9+) and B0 (1.18e8–1.30e8) — reserve `218,000,000 + cell_index·1,000,000`.
- Pre-launch smoke ON DRAC (D-139): one task of the array (`--array=1-1`), verify
  non-empty CSV + no NA before releasing the full array.

## What launch needs from Shinichi (verbatim decision points)

1. Fence: **F-AMD (recommended)** or F-REG.
2. "Launch B1" — authorizes the ≈2,900 core-hour array on the chosen arm.
3. (Optional, flagged by B0) whether to add a dedicated near-saturated-band cell axis
   so the 782-class coverage is measured by design rather than incidentally — this is
   a §8 grid amendment; if wanted, it must be recorded BEFORE launch.
