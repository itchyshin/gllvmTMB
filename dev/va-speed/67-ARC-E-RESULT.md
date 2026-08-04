# Arc E — the gllvm head-to-head: claim 30 is settled, and mostly against us

**Date:** 2026-08-04 · **Compute:** Totoro, serial, single-threaded, arm order rotated per replicate
**Cell:** N=120, T=10, q=1, `n_trials`=6, `psi_true`=0.6, **12 seeds**, 2 reps each (120 rows)
**Script:** `18-four-way.R` → `66-arcE-aggregate.R` · **Data:** `dev/va-speed/arcE/fw2-s*.rds`

Ledger **claim 30** says *"we have a better VA than gllvm"* is **NOT ESTABLISHED**, and records
that two attempts to claim it — claim 16 (1 seed) and claim 18 (6 seeds) — were both **RETRACTED**
for being underpowered. The ledger names the settling arc: model-matched, **≥10 seeds**,
interleaved, reporting speed **and** accuracy **and** ψ. This is that run.

## Results, 12 seeds

| arm | accuracy `rel_frob` (median, lower better) | speed s (median) | ψ (truth 0.6) |
|---|---:|---:|---:|
| **ours-LA** | **0.2056** | 4.749 | — |
| ours-GH | 0.2721 | 11.156 | **0.5417** |
| gllvm-LA | 0.2743 | 0.441 | — |
| gllvm-VA | 0.3759 | **0.197** | — |
| ours-AC | 0.3772 | 5.047 | **0.0002** |

**The medians alone would mislead.** Every arm's per-seed `rel_frob` spans roughly 0.15–0.49 —
the ranges overlap almost completely. That overlap is exactly what made 1-seed and 6-seed
comparisons worthless. So the ranking below is taken from the **paired per-seed** comparison, not
the medians.

## Paired, per seed — the thing claims 16 and 18 lacked

| comparison | result |
|---|---|
| ours-GH beats gllvm-VA on accuracy | **11 of 12 seeds** |
| ours-LA beats gllvm-VA on accuracy | **11 of 12 seeds** |
| ours-LA beats gllvm-LA on accuracy | 9 of 12 seeds |
| **ours-AC beats gllvm-VA on accuracy** | **6 of 12 — a coin flip** |
| ours-LA faster than gllvm-LA | **0 of 12** (gllvm ~10× faster) |
| ours-AC faster than gllvm-VA | **0 of 12** (gllvm ~25× faster) |
| ours-GH faster than gllvm-VA | **0 of 12** (gllvm ~50× faster) |

## Verdict

**Claim 30 remains NOT ESTABLISHED as written, and this run is the reason to stop trying to make
it.** Three findings, stated separately because they point in different directions:

1. **ACCURACY — a real, narrow win.** Our **GH** tier beats gllvm's VA on **11 of 12** paired
   seeds. That is not a coin flip and it is the first properly powered version of this comparison.
   The defensible sentence is *"our GH tier is more accurate than gllvm's VA on this cell"* —
   **not** "we have a better VA".

2. **SPEED — we lose, decisively, at this cell.** 0 of 12 on every comparison, by 10–50×.
   ⚠ **Regime matters and this cell is small.** N=120 is far below the measured VA-vs-LA crossover
   (~N≈2500, ledger claim 46's reconciliation). Our VA's speed case was always a *large-N* case,
   and this run does not test it. **This does not establish that gllvm is faster at large N** — it
   establishes that it is faster here, which is where many users actually are.

3. **The AC tier — the arc's own headline — does NOT beat gllvm on accuracy.** 6 of 12 is a coin
   flip, and it **destroys ψ**: 0.0002 against a planted 0.6, while our GH tier recovers 0.5417 on
   the same data. The Albert–Chib closed form buys speed over our own GH tier (5.0 s vs 11.2 s) and
   pays for it in both accuracy and variance recovery at `n_trials = 6`.

## What must NOT be claimed from this

- **Not** "we have a better VA than gllvm." The VA tier that is more accurate (GH) is our *slowest*
  arm, and the tier this arc was built around (AC) is a coin flip that collapses ψ.
- **Not** anything about large N, other families, other `n_trials`, or q>1. One cell, one family.
- **Not** a speed verdict that transfers past N≈120.

## Regime and caveats

Single cell; q=1; Gaussian-free (binomial-probit responses, `n_trials`=6); `psi_true`=0.6 chosen
deliberately because it is where AC is known to collapse — a run at `psi_true`=0 would measure
AC's most favourable corner and flatter it. Serial with arm order rotated per replicate, so machine
drift is spread across arms rather than landing on one (the discipline Arc D's own harness lacked).

**Sizing note, recorded because it was my error:** this arc was first launched at N=250/T=20, where
`ours-AC` alone took **196 s** per arm and the full 12 seeds would have taken 5–12 hours. The
estimate behind that launch extrapolated from an N=60/T=6 smoke and ignored the superlinear scaling
this lane had already measured. Re-scoped to N=120/T=10, which trades cell size for the thing
claim 30 actually requires — **seed count**.
