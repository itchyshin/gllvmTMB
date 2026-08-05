# 75-clean-ladder: model-matched, 24-seed, interleaved speed/accuracy vs gllvm's VA

**Date:** 2026-08-05 · **Compute:** Totoro, `dev/va-speed/75-clean-ladder.R`, HEAD `728f4aa8`
**Cell:** T=20, q=2, `n_trials`=6, no ψ in the DGP · ours: `unique=FALSE, psi=FALSE,
eval_method="ac", collapse_variational_cov=TRUE, n_starts=1, H=15` · gllvm:
`method="VA", num.lv=2, family=binomial(link="probit"), Ntrials=6` · gllvm 2.0.13
**Grid:** N ∈ {250, 1000, 2500} × seeds 1:24 = **72 cells, all 72 present and used.**

DGP and both fitting arms are copied verbatim from `57-gllvm-scaling.R`; accuracy
extraction (rel_frob of `ΛΛᵀ` against the DGP's true `ΛΛᵀ`) is copied verbatim from
`29-head-to-head-gllvm.R`, cross-checked against `18-four-way.R`'s identical
`theta_rr` unpack pattern.

## 0. The 71-vs-72 discrepancy — resolved, not dropped

The coordinator's independent check reported 71/72 cells with N=2500 seed 21 missing.
This is confirmed to have been a **timing race at the grid's tail**, not a failure:

- `75-launch.log` shows `DONE N=2500 seed=21 exit=0` immediately followed by
  `ALL_DONE Wed Aug 5 06:02:35 AM MDT 2026` — seed 21 was **the last of all 72 cells
  to finish** (its own gllvm arm ran 821 s, the longest single arm-time in the whole
  grid; see §3).
- My own background monitor (independent of the coordinator's check) auto-detected
  `n=72 done=1` at `06:02:54`, 19 s after `ALL_DONE` — consistent with the coordinator
  having sampled in the ~20 s window before the file was flushed.
- A fresh, timestamped re-check after receiving the coordinator's message
  (`06:04:05`) found `dev/va-speed/75-ladder-cells/N2500_s21.rds`, 405 bytes,
  mtime `06:02`, and a whole-grid verification script (`75-verify.R`, §1) confirms it
  is present, error-free, and guard-passing.

**No re-run was needed or performed.** All 72 cells in the design are used; the
denominator below is 72/72, not 71/72.

## 1. Whole-grid verification (not a spot check)

`75-verify.R` iterates over all 72 expected `(N, seed)` pairs, loads every `.rds`,
and checks existence, the guard fields, both arms' error fields, and (via each
cell's `.log`) the literal warm-up line — for every cell, not one:

| check | result |
|---|---|
| cells present | **72 / 72** |
| `ours_guard_ok` TRUE (`eval_method=="ac"` AND collapse gate fired) | **72 / 72** |
| `all(eval_method == "ac")` | **TRUE** |
| `all(collapsed == TRUE)` | **TRUE** |
| `ours_err` non-NA (errored) | **0 / 72** |
| `gllvm_err` non-NA (errored) | **0 / 72** |
| degenerate accuracy (`rel_frob` ≈ 1 or > 1.5) | **0 / 72** |
| `first_ours` split per N stratum | **12 TRUE / 12 FALSE**, every N — the seed-parity rotation is exactly balanced |

The guard check is **doubly enforced**, not just read after the fact: `run_ours()`
(copied verbatim from `57-gllvm-scaling.R:59-63`) itself calls `stop("ARM MISMATCH...")`
if `eval_method` did not resolve to `"ac"` or the collapse gate did not fire — a
mismatch would surface as a non-NA `ours_err`, and there were none. Independently,
the per-cell `ours_guard_ok`/`ours_eval_method`/`ours_collapsed` fields (recorded by
the fitting script itself at fit time) were also read back and checked for all 72
cells. Both layers agree: clean on every cell.

**Warm-up confirmation:** every cell's script runs an untimed warm-up (`mk(999L,
40L)` fit through both engines) strictly before either arm's `proc.time()` timer
starts — by construction, not just by log inspection, first-call/TMB-compile costs
cannot land inside a timed block. The literal log line `"warm-up done (UNTIMED)"`
was grepped from all 72 per-cell `.log` files and found in **71/72**; the 72nd
(`N250_s1`) is the cheap-fail test cell I ran manually in the foreground before
building the batch pipeline, so its console output was never redirected to a `.log`
file — but the same line is present verbatim in that run's directly-captured
console output (`"warm-up done (UNTIMED)"`, shown before either arm's timing).
Functionally 72/72; evidenced via two different channels for one cell.

## 2. Concurrency and load — reported honestly

72 cells were run: 1 (N=250, seed=1, the cheap-fail check) sequentially first, then
the remaining 71 launched together via `xargs -P 71` (one core each, `OPENBLAS_NUM_THREADS=1`
and `OMP_NUM_THREADS=1` forced in both the R script and the shell wrapper). **Peak
concurrency was 71 single-threaded processes**, capped by construction — never all
72 at once, since the first cell ran alone beforehand.

**No oversubscription:** 71 concurrent single-threaded jobs against 384 cores is
≤19% of the box; every job could hold a dedicated core with headroom to spare. This
is a structural guarantee from the launch mechanism, independent of the load reading.

**Load profile (1-minute average, `/proc/loadavg`), my own polling every ~20 s:**

| time | load | note |
|---|---:|---|
| 05:46:15 | 0.39 | pre-launch |
| 05:46:39 (+24s) | 24.8 | ramping |
| ~05:47–05:51 | peaked ≈ 42–43 | both my own real-time observation and the coordinator's independent check agree on this peak |
| 05:51:11 | 25.5 | N=250 (24/24) + N=1000 (24/24) done, only N=2500 (24) still running |
| 05:56:52 | 14.2 | N=2500 cohort thinning as individual cells finish |
| 06:00:54 | 1.67 | tail — only the last few N=2500 cells remain |
| 06:02:54 | 0.93 | `ALL_DONE` (n=72) |
| 06:04:05 (post) | 0.32 (1-min) / 5.58 (5-min) / 8.78 (15-min) | box back to baseline; longer windows still show the recent activity rolling out |

The observed 1-minute-average peak (~43) is well below the 71-job structural cap —
consistent with (a) many N=250 jobs finishing in ~3–6 s before the smoothed average
catches up, and (b) the 1-minute average lagging a true instantaneous count. I did
not capture an exact instantaneous process-count time series, only the load average;
the 71-job concurrency cap itself is not in question (guaranteed by `xargs -P 71`).

**Effect on timings:** whatever ambient contention existed from sibling jobs applies
to **both arms of a given cell** — they run back-to-back in the same process, same
core, same wall-clock window — so within-cell ratios (the number this report
reports) are largely protected from cross-job contention even if absolute
seconds carry some inflation relative to a fully serial run. I checked this
concretely for the slowest single measurement in the grid (N=2500 seed 21, §3): it
finished **last** of all 72 cells, meaning most of its own long gllvm call (821 s)
ran during the tail when load was falling, not rising — its own recorded
`load_end` (1.21) is among the lowest in the whole N=2500 stratum. That argues
against contention as the explanation for its outlier value; see §3.

Total campaign wall-clock: launch 05:46:15 → `ALL_DONE` 06:02:35, **≈16m20s** for
71 cells (vs. an estimated ~4.3 h if run fully serially at these per-cell costs).

## 3. Results — per N, 24 seeds each, all successful (0 excluded)

**Speed (seconds). Ratio = median(gllvm) / median(ours); >1 means ours faster.**

| N | ours: min/Q1/med/Q3/max | gllvm: min/Q1/med/Q3/max | ratio (median) |
|---|---|---|---|
| 250 | 3.063 / 3.218 / **3.389** / 3.675 / 4.010 | 2.799 / 3.381 / **3.476** / 3.773 / 6.303 | **1.025x** |
| 1000 | 20.392 / 21.531 / **22.309** / 23.809 / 30.601 | 51.229 / 55.158 / **56.923** / 62.059 / 83.696 | **2.552x** |
| 2500 | 105.253 / 112.448 / **119.337** / 124.246 / 132.537 | 374.050 / 420.701 / **439.119** / 498.227 / **820.987** | **3.680x** |

n = 24 seeds per N, model-matched cell (T=20, q=2, n_trials=6), interleaved,
order-rotated. At N=250 the two engines are within measurement noise of parity
(ratio ≈ 1). At N=1000 and N=2500 ours is faster at the median by a consistent,
increasing margin.

**Spread is asymmetric between engines, at every N, not just N=2500.** Comparing
each engine's own max against its own median (n=24 each):

| N | ours max/median | gllvm max/median |
|---|---:|---:|
| 250 | 1.18x | 1.81x |
| 1000 | 1.37x | 1.47x |
| 2500 | 1.11x | **1.87x** |

Ours is tighter at every N tested; gllvm's relative spread is consistently wider,
most visibly at N=2500 in absolute terms (IQR 420.7–498.2 s, max 821.0 s). Framed
per the ledger's own discipline (existence, not a rate): **1 of 24 seeds** (seed 21)
at N=2500 exceeded 1.8x the N=2500 gllvm median; **2 of 24** (seeds 21, 8) exceeded
1.5x. This is an existence claim about a slow tail in gllvm's own time at this N —
**not** a tail rate, and not evidence about any other N/T/q/family.

**The two most extreme gllvm times at N=2500 do not share a run-order artifact.**
Seed 21 (821.0 s) ran `first_ours=TRUE` — ours first, gllvm second, i.e. gllvm ran
*after* an already-warm process, not first. Seed 8 (660.5 s) ran `first_ours=FALSE`
— gllvm first. Since both engines get their own dedicated untimed warm-up in every
job regardless of order (§1), neither ordering explains these values as a cold-start
artifact; on the current evidence this reads as genuine per-seed variance in
gllvm's own VA optimizer at this N, not a harness artifact. I did not investigate
further into gllvm's internals — that would need its own study.

**Accuracy (rel_frob of `Λ̂Λ̂ᵀ` vs. true `ΛΛᵀ`, lower is better; same estimand, same
floor, both arms):**

| N | ours: min/Q1/med/Q3/max | gllvm: min/Q1/med/Q3/max |
|---|---|---|
| 250 | 0.103 / 0.151 / 0.185 / 0.228 / 0.401 | 0.103 / 0.151 / 0.185 / 0.228 / 0.401 |
| 1000 | 0.076 / 0.131 / 0.168 / 0.189 / 0.449 | 0.076 / 0.131 / 0.168 / 0.189 / 0.449 |
| 2500 | 0.065 / 0.126 / 0.158 / 0.181 / 0.433 | 0.065 / 0.132 / 0.165 / 0.182 / 0.433 |

Per-seed, the two engines land at **virtually identical** accuracy at every N (median
difference ≈ 0), which is the expected signature of a genuinely model-matched
comparison (both fit the same VA approximation to the same likelihood). **One
exception:** N=2500 seed 11, ours = 0.1135 vs gllvm = 0.1854 — the one cell in 72
where the two arms' accuracy diverges materially (every other cell agrees to 3–4
decimal places). Reported as an isolated observation from n=1, not a claim.

**ψ is genuinely not applicable to this cell.** The DGP plants no ψ/u term and
neither arm fits a ψ tier (`unique=FALSE, psi=FALSE` ours; `num.lv=q` with no extra
variance term, gllvm). This is stated explicitly rather than omitted: the ledger
warns a loadings-only accuracy score is blind to the one failure mode (ψ collapse)
AC is known to have, and this run cannot speak to that dimension at all.

## 4. Consistency with prior measurements (not pooled)

Absolute seconds are **not** comparable across harnesses (`57`, `29`, `71`,
`18-four-way` are different code paths, different control settings, e.g. `29`'s
`ours` arm uses `eval.max=800/iter.max=400` vs this script's `2000/2000` inherited
from `57`). Only direction and rough magnitude of the ratio are compared:

- **57** (1 seed): N=250 ratio 0.94x (gllvm marginally faster) · N=1000 2.72x ·
  N=2500 3.56x.
- **This run** (24 seeds): N=250 1.025x · N=1000 2.552x · N=2500 3.680x.
- N=1000 and N=2500 agree in direction and are within ~6% and ~3% of 57's single-seed
  ratio respectively. N=250 is a near-tie in both — 57's single seed put gllvm
  marginally ahead, this run's 24-seed median puts ours marginally ahead; both sit
  close to parity, direction is not stable at this N in either measurement.
- **29** (12 seeds, self-flagged contaminated box, load median 1.1 spread 16.5):
  task-cited N=1000 ratio 1.76x. This run's clean 2.552x (and 57's clean 2.72x) sit
  well above 29's contaminated number — consistent with 29's own flag that its
  result is unreliable, not corroborating it. 29 did not measure N=2500.

## 5. Verdict — what this does and does not establish

This run supplies a properly-powered (24 seeds ≥ the ledger's ≥10 bar),
model-matched (`unique=FALSE` both sides), interleaved, quiet-Totoro, speed-**and**-
accuracy measurement — the exact structural gap between the 1-seed `57` and the
contaminated 12-seed `29` that Claim 30 (`20-CLAIMS-LEDGER.md`) says must be closed
before "our VA beats gllvm's" can be asserted.

**What it shows, for this one cell (T=20, q=2, n_trials=6, binomial-probit, no ψ):**
ours is at parity with gllvm at N=250, and progressively faster at N=1000 (2.55x
median) and N=2500 (3.68x median), at statistically indistinguishable
loadings-recovery accuracy, with tighter run-to-run spread than gllvm at every N.

**What it does not show:** Claim 30's own stated bar requires speed **and** accuracy
**and** ψ. This cell has no ψ by design (§3) — the run is silent on the one failure
mode (ψ collapse under AC) the ledger explicitly flags as unaddressed by a
loadings-only score. **I am not asserting claim 30.** This result closes the
speed+accuracy half of the bar at this cell; a companion ψ-planted run (matching
`67-ARC-E-RESULT.md`'s regime or similar, but with ≥10 seeds at this N range rather
than N=120) would be needed to close the rest. It also says nothing about other
N/T/q/families, and the N=2500 tail (§3) is an existence observation from one
seed in 24, not a characterized rate.

## Files

- Script: `dev/va-speed/75-clean-ladder.R` (Totoro, `~/gllvm_work/va-lane2-git/`)
- Verification script: `dev/va-speed/75-verify.R` (Totoro)
- Aggregation script: `dev/va-speed/75-aggregate.R` (Totoro)
- Per-cell `.rds`/`.log`: `dev/va-speed/75-ladder-cells/` (Totoro, 72 files each)
- Launch log: `dev/va-speed/75-launch.log` (Totoro)
- Aggregated results: `dev/va-speed/75-ladder-results.rds` (Totoro and copied to
  `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/75-ladder-results.rds`)
- This report: `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/75-CLEAN-LADDER-RESULT.md`

Files are written locally but **not committed** — this worktree
(`/private/tmp/gllvmtmb-va-lane2`, branch `claude/va-lane2`) has other uncommitted
work in progress (`dev/va-speed/76-*`, `trace-gllvm-va.R`) from a concurrent agent
in this session; committing was left to the coordinator's discretion rather than
risking a scope-crossing `git add`.
