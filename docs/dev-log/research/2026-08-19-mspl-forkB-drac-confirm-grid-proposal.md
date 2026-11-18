# DRAC confirm grid proposal — Design 125 fork B (post-T1; not a T\* freeze)

- **Date:** 2026-08-19
- **Lane:** `cursor-mspl-fork-B-drac-confirm`
- **Status:** **LOCKED** for kit-docs sitting. Declares the confirm panel so
  multi-seed stability can be *measured*. Does **not** freeze T\*. Does **not**
  launch DRAC from the kit sitting alone.
- **calibrated:** FALSE
- **public_confint:** refused
- **MSPL-04:** stays `blocked`
- **#1077:** stays draft

## Why this panel exists

T1 ([#1173](https://github.com/itchyshin/gllvmTMB/pull/1173)) recorded **800
hold-out fits** on Totoro in **15.3 s** at 16 cores — too small to justify the
full DRAC fleet, but large enough to inform a T\* **discussion packet**
(`docs/dev-log/research/2026-08-19-mspl-forkB-tstar-discussion-packet.md`).

The confirm panel is where DRAC earns its keep: **multi-seed arrays** across
Fir / Nibi / Rorqual, not a repeat of the T1 hold-out.

## Inherited numbers (do not rewrite)

| Source | Highlight |
|---|---|
| L1 #1128 | cov_eff **0.880** on `L1-anchor-n80-T8` / seed 20260818 |
| L2 #1162 | Seed B/C **0.900**; near-tail **0.780** |
| T1 #1173 | Anchors **0.940** / **0.975**; near **0.710**; far **0.580** |

## Locked confirm grid

| cell_id | n | T | prevalence | seed_base | n_rep | role | fits |
|---|---:|---:|---|---:|---:|---|---:|
| `T1-confirm-n80-T8` | 80 | 8 | `anchor` | 20260834 | 200 | L1 DGP, new seed, scale only | 200 |
| `T1-anchor-n160-T8` | 160 | 8 | `anchor` | 20260831 | 200 | T1 seed A (inherit for continuity) | 200 |
| `T1-anchor-n160-T8` | 160 | 8 | `anchor` | 20260835 | 200 | new seed B | 200 |
| `T1-anchor-n160-T8` | 160 | 8 | `anchor` | 20260836 | 200 | new seed C | 200 |

**Total: 800 fits.** Estimand **E1**. Fork **B**. Same DGP vectors as T1/L1
harness (`dev/mspl-forkB-l1-ademp.R`).

Seed **20260831** is the T1 n160 draw — included so the multi-seed block
connects to T1; seeds **20260835** / **20260836** are fresh.

## Compute target

| Step | Machine | Why |
|---|---|---|
| Local 1-rep × 2 blocks | laptop ≤10 cores | runner proof |
| Optional smoke | Totoro ≤16 cores | SSH/deploy check |
| **Primary 800** | **DRAC SLURM arrays** | multi-seed → arrays |

**DRAC fan-out (recommended):**

| Cluster | Block | tasks |
|---|---|---|
| Fir | `T1-confirm-n80-T8` × 200 | array 1–200 |
| Nibi | `T1-anchor-n160-T8` seed 20260831 × 200 | array 1–200 |
| Rorqual | seeds 20260835 + 20260836 × 200 each | array 1–400 |

Per-task: `--cpus-per-task=1`, `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`,
`--time=01:00:00`, account from live `sacctmgr`. R + gcc + package install on
login node; rsync checkout to `/project` or home; pull RDS keepers back (D-50).

Skip Killarney / Vulcan / tamIA (GPU/AI). Not GitHub Actions (D-50).

## Wall estimate

Optimistic T1 clock ≈ **0.20 s/rep** on n80 after `R CMD INSTALL`. n160 ≈ 0.44 s/rep.

| Block | Serial (opt) | Notes |
|---|---:|---|
| confirm 200 | ~0.7 min | same cell as L1 topology |
| n160 × 600 | ~4.4 min | dominates |
| **800 total** | **~5 min serial** | queue + first deploy dominates |

On DRAC (1 core × 800 tasks), fit wall ≈ slowest single rep + queue. Budget
**first deploy 15–45 min** honestly.

## What to record

Same ADEMP columns as T1: dual coverage, refusal-by-reason, Wilson, MCSE.
**RECORD only.** `tstar_status: NOT-FROZEN` unless Shinichi signs separately.

## Out of scope

- Re-walking T1 hold-out seeds 20260830 / 20260832 / 20260833
- Far-tail or near-tail new cells (T1 already recorded them)
- T\* FAIL band application from this sitting
- Public interval doors
