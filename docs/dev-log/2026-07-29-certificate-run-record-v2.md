# Run record v2 — fresh-seed 20k campaign, Gaussian `Sigma_unit` diagonal profile

Companion to `2026-07-29-certificate-gate-preregistration-v2.md` (commit `8121f377`), which is
immutable after launch. As-run parameters and results are recorded here.

## Invocation

```
CORES=90 NSIM=40000 NBOOT=10 FAMILY=gaussian NUNITS=150 \
  REPSTART=20001 REPEND=40000 \
  OUTDIR=/home/snakagaw/gllvm_work/profile_rescore/run20k-v2-20260729 \
  bash dev/totoro-profile-rescore.sh grid
```

`NSIM=40000` is not a typo and is load-bearing: `rep_index_start/rep_index_end` must lie inside
`1:n_reps`, so the window `[20001, 40000]` requires `n_sim = 40000`. **The smoke caught this.**
With `NSIM=20000` every shard would have aborted with
`rep_index_start/rep_index_end must define a non-empty range inside 1:n_reps`, and the run would
have consumed ~3 hours of 90 cores producing nothing.

## Seed disjointness — verified, not asserted

This is the defect that withheld v1, so it was checked empirically **before** launch rather than
argued from the formula:

| | rep index | `rep_seed` | first truths |
|---|---|---|---|
| v1 | 1, 2 | 101002, 101003 | 1.9587, 2.8653, 2.5403 |
| v2 | 20001, 20002 | 121002, 121003 | 0.7815, 1.9894, 2.0957 |

Seed overlap: **0**. The truths differ, so these are genuinely different simulated datasets, not a
re-score. `rep_seed = seed_base + 1000*d + 100000*family_index + r`, so a disjoint `r` window with
the same `seed_base` yields disjoint seeds within a cell.

## Results — 180/180 shards, 0 errors

| cell | ci_method | coverage | n_reps | n_attempted | n_failed | convergence |
|---|---|---|---|---|---|---|
| d1-n150 | **profile_total** | **0.9467169** | 19,372 | 20,000 | 628 | 96.86% |
| d1-n150 | wald_t_logsd (diagnostic) | 0.9469131 | 19,372 | 20,000 | 628 | |
| d1-n150 | bootstrap (baseline) | 0.7774210 | 20,000 | 20,000 | 628 | |
| d2-n150 | **profile_total** | **0.9467216** | 19,888 | 20,000 | 112 | 99.44% |
| d2-n150 | wald_t_logsd (diagnostic) | 0.9463153 | 19,888 | 20,000 | 112 | |
| d2-n150 | bootstrap (baseline) | 0.7810036 | 20,000 | 20,000 | 112 | |

Bands against the pre-registered gate (`coverage - 2*MCSE`, `MCSE = sqrt(p(1-p)/n_reps)`):

| cell | MCSE | band | gate 0.94 |
|---|---|---|---|
| d1-n150 | 0.001613681 | **0.9434895** | clears by 0.0035 |
| d2-n150 | 0.001592543 | **0.9435365** | clears by 0.0035 |

`n_failed` is now reported (628 / 112) rather than the false `0` v1 printed, and agrees across the
`profile_total` and `bootstrap` subsets — the cross-check that makes the fix trustworthy.

## Independent replication of v1

v1's numbers came from data that was 75% historical, so it could not corroborate anything. v2's
20,000 datasets per cell have never been used.

| cell | v1 | v2 | difference | in SE of the difference |
|---|---|---|---|---|
| d1 | 0.9479297 | 0.9467169 | −0.0012128 | **−0.54** |
| d2 | 0.9464714 | 0.9467216 | +0.0002502 | **+0.11** |

Both well within noise. The pre-registered trigger *"coverage materially different from v1's
0.9465–0.9479"* does not fire — and unlike v1's version of that trigger, this one was capable of
firing, because the data are new.

Convergence rates also replicate: 96.86% / 99.44% here against 96.97% / 99.33% in v1, and the
d1-worse-than-d2 asymmetry persists on fresh data.

Bootstrap remains ~0.78 on both cells, confirming again that it is the wrong route for this
estimand.

## Wall-clock

~2h50m on 90 cores, matching v1.

## Data handling

Raw stays **LOCAL on Totoro** (D-50) at `run20k-v2-20260729/`. **Retain it.** v1's raw at
`run20k-20260729/` is also retained — it is the evidence for the seed-reuse finding and must not be
deleted.

## Status

**No certificate is claimed by this document.** The result goes to a fresh D-43 panel, which
defaults to NOT-DONE; two withholds block. No public surface has been touched: `NEWS.md` still
states that no cell's interval coverage is certified.
