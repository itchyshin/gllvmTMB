# 79-se-matched-ladder: SE-matched, n_starts-disclosed, 3-arm ladder vs gllvm's VA

**Date:** 2026-08-05 · **Compute:** Totoro, `dev/va-speed/79-se-matched-ladder.R`, HEAD `728f4aa8`
**Supersedes `75-clean-ladder.R`**, which is now known-defective (below) — do not reuse
its absolute ratios.

## 0. The defect this run corrects

`75-clean-ladder.R` called `gllvm::gllvm(...)` without `sd.errors`. gllvm 2.0.13
defaults `sd.errors = TRUE`, running an `optimHess()` standard-error pass on gllvm's
side; our `va_r3` prototype computes no SEs at all (no `sdreport`, no `optimHess`
anywhere in `R/va-r3-proto.R`). The coordinator's own pre-measurement at N=1000 on
an idle box (not part of this grid, cited for motivation only): gllvm with
`sd.errors=TRUE` 50.74s/44.65s, with `sd.errors=FALSE` 20.28s/16.59s — the SE pass
was 60–63% of gllvm's wall time. **75's reported 2.5x median win at N=1000 is
therefore not a clean measurement of the two engines' fitting cost** and must not be
reused. Second, disclosed asymmetry: 75 timed our arm at `n_starts=1`, but
`.va_r3_fit()`'s own default is `n_starts=4` (`R/va-r3-proto.R:2189`) — what a user
actually gets. This run times **three** arms per cell to put both corrections on
record:

1. `ours_n1` — exactly 75's arm (`n_starts=1`), for continuity
2. `ours_n4` — identical except `n_starts=4` (our shipped default)
3. `gllvm_nose` — `gllvm::gllvm(..., sd.errors=FALSE)`, SE-matched to ours

Same DGP, same cell (T=20, q=2, n_trials=6, no ψ), same guards on both `ours`
arms, same untimed warm-up (now covering all 3 configurations), same
back-to-back-in-one-job interleaving (now a 6-way permutation rotation instead of a
2-way flip), same accuracy scoring — all unchanged from `75-clean-ladder.R`.
Grid: N ∈ {250, 1000, 2500} × seeds 1:24 = **72 cells, all 72 present and used.**

## 1. Sanity check (N=250, seed=1) — confirmed before mass launch

All three arms returned finite output: `ours_n1` 2.67s (rf=0.249), `ours_n4` 10.77s
(rf=0.249), `gllvm_nose` 1.14s (rf=0.249) — accuracy in the same ballpark as 75's
same cell (0.249/0.249). Guards passed on both `ours` arms. **`sd.errors=FALSE`
confirmed to change gllvm's time**: 1.14s here vs 75's 2.80s for the identical cell
(same seed, same DGP draw) — well over half of gllvm's previous time was the SE
pass, consistent with the coordinator's pre-measurement.

## 2. Whole-grid verification (72/72, programmatic, not spot-checked)

`79-verify.R` loaded every cell's `.rds` and checked all fields for all 72 cells:

| check | result |
|---|---|
| cells present | **72 / 72** |
| `ours_n1_guard_ok` TRUE (`eval_method=="ac"` AND collapse fired) | **72 / 72** |
| `ours_n4_guard_ok` TRUE (same check) | **72 / 72** |
| `ours_n1_err` / `ours_n4_err` / `gllvm_nose_err` non-NA (errored) | **0 / 0 / 0** |
| degenerate accuracy (`rf` ≈ 1 or > 1.5, any arm) | **0 / 72** |
| untimed warm-up line present in cell log | **71 / 72** (72nd is the manual sanity cell above, output captured directly, not log-redirected — same situation as 75) |
| arm-order rotation balance, whole grid, each arm × each of 3 positions | **exactly 24 / 24 / 24** |
| per-N rotation balance (`ours_n1` shown; identical by construction for the other two, same seed-indexed formula at every N) | **exactly 8 / 8 / 8** each stratum |

Every 72-cell grid finished with N=2500 seed 21 last (07:01:03), same as in the
prior (75) run — a fresh, timestamped re-check (`ls`/`wc -l` = 72, then `79-verify.R`)
was run only after `ALL_DONE` to avoid the tail-race that produced an apparent
71/72 reading last time.

## 3. Concurrency and load

Same design as 75: 1 cell (N=250, seed=1) run sequentially as the sanity check,
then the remaining 71 launched together via `xargs -P 71` (`OPENBLAS_NUM_THREADS=1`,
`OMP_NUM_THREADS=1`). **Peak concurrency 71 single-threaded processes** against 384
cores — no oversubscription (≤19% of the box). Load: pre-launch 0.20, peaked ≈
44–47 (slightly above 75's ≈42–43, consistent with 3 timed arms per job instead of
2 — more CPU-seconds packed into the same 71-job envelope, not more concurrent
processes), declining smoothly as N=250 then N=1000 cells finished, settling at the
N=2500-only steady state (≈24–28) for most of the run, back to 1.06 at `ALL_DONE`.
Total wall-clock: launch → `ALL_DONE` ≈ **19.5 minutes** (vs. the ≈775s/cell,
≈15 min estimate — a few minutes longer, consistent with the added `ours_n4` arm's
cost). As before, contention from sibling jobs applies to all three arms of a given
cell equally (same process, same core, same window), so within-cell ratios are
largely protected from cross-job effects even where absolute seconds are not.

## 4. Results — per N, 24 seeds each, all successful (0 excluded)

**Ratio convention, stated explicitly: `gllvm_nose median ÷ ours median`. >1 means
ours faster; <1 means gllvm faster.** (This continues 75's convention; the
coordinator's brief named the pair "ours/gllvm_nose" — both requested comparisons
are reported below, unambiguously labeled.)

| N | ours_n1 median [IQR] | ours_n4 median [IQR] | gllvm_nose median [IQR] | gllvm/ours_n1 | gllvm/ours_n4 |
|---|---|---|---|---:|---:|
| 250 | 3.103s [2.921–3.326] | 12.354s [11.826–13.201] | 1.668s [1.507–1.962] | **0.538x** (gllvm 1.86x faster) | **0.135x** (gllvm 7.40x faster) |
| 1000 | 22.210s [21.068–23.711] | 88.197s [85.754–91.292] | 28.006s [25.006–31.878] | **1.261x** (ours faster) | **0.318x** (gllvm 3.14x faster) |
| 2500 | 118.834s [111.324–124.608] | 455.174s [448.264–469.659] | 151.806s [129.122–203.617] | **1.277x** (ours faster) | **0.334x** (gllvm 2.99x faster) |

n = 24 seeds per N per arm. **Headline: at our shipped default (`ours_n4`), we are
slower than gllvm's SE-matched VA at every N tested** (7.4x at N=250, 3.1x at
N=1000, 3.0x at N=2500). **At matched start counts (`ours_n1` vs gllvm's own
`n.init=1` default), we are slower at N=250 (gllvm 1.86x faster) but faster at
N=1000 and N=2500** (1.26–1.28x). `ours_n4` costs consistently ≈3.8–4.0x
`ours_n1` (3.98x, 3.97x, 3.83x at N=250/1000/2500) — close to the naive
4-independent-starts expectation, with a small sub-linear dip at N=2500.

**Spread and tails (existence, not a rate — n=24):**

- N=2500 `gllvm_nose`: median 151.8s, max 528.9s (seed 21) = **3.48x** its own
  median; 2nd-highest 370.2s (seed 8) = 2.44x. **2 of 24 seeds exceed 2x** the
  N=2500 `gllvm_nose` median.
- N=2500 `ours_n1`: median 118.8s, max 178.8s (seed 8, the SAME seed elevated for
  `gllvm_nose`) = 1.51x — tighter than gllvm's spread, but less tight than 75's own
  `ours` arm at N=2500 (there 1.11x; note 75 and this run are not pooled, this is a
  within-run observation only).
- N=1000: **seed 10 is the single slowest seed for all three arms simultaneously**
  (`ours_n1` 29.5s vs median 22.2s = 1.33x; `ours_n4` 127.4s vs median 88.2s = 1.45x;
  `gllvm_nose` 51.2s vs median 28.0s = 1.83x) — and its arm order
  (`ours_n4>gllvm_nose>ours_n1`) puts a different arm first than the other two
  elevated N=2500 seeds below, ruling out a shared run-order artifact. This reads as
  seed 10's data draw being intrinsically harder to fit at N=1000 for every
  configuration tested, not a harness effect.
- N=2500 `ours_n4`'s own max (585.8s, seed 10) and `gllvm_nose`'s max (528.9s,
  seed 21) are **different seeds** — the three arms do not share one "hard seed" at
  N=2500; seed 8 is jointly elevated for `ours_n1` and `gllvm_nose` only, seed 21
  only for `gllvm_nose`, seed 10 only for `ours_n4`. **Run-order checked for the top
  outliers**: seed 21 (`ours_n4>ours_n1>gllvm_nose`, gllvm_nose last), seed 8
  (`ours_n1>gllvm_nose>ours_n4`, gllvm_nose 2nd) — different positions, both
  elevated, so not a shared warm-up/order artifact (every arm gets its own
  dedicated untimed warm-up regardless of position, §0).

## 5. Accuracy

Per-seed `rel_frob(Λ̂Λ̂ᵀ, ΛΛᵀ)` is **virtually identical across all three arms** at
every N (medians agree to 3 decimal places; N=250/1000/2500 medians 0.185/0.168/0.158
for all three). **`n_starts` 1 vs 4 does not change accuracy**, checked at all three
N (previously checked only at N=1000): median `|n1_rf − n4_rf|` = 9e-7 / 1.6e-6 /
4.3e-6 at N=250/1000/2500; **worst case across all 72 cells** is 2.4e-5 (N=2500) —
negligible against `rf` values of order 0.1–0.4, and the "identical to several
significant figures" finding holds at every N, not only the previously-checked one.

**One accuracy exception, and it replicates exactly from 75**: N=2500 seed 11 —
`ours` (both n1 and n4) rf ≈ 0.1135, `gllvm_nose` rf = 0.1854. This is the *same*
seed, *same* direction, and *same* magnitude of divergence found in 75's
independent 2-arm run (which also used `sd.errors=TRUE` gllvm) — the only cell in
144 arm-comparisons (72 cells × 2 runs) where the two engines' accuracy meaningfully
disagrees. Reported as a specific, replicated observation, not a general claim.

**ψ is not applicable to this cell** (no ψ/u term in the DGP; neither `ours` arm
fits a ψ tier; `gllvm_nose` has no extra variance term either) — stated explicitly
per the ledger's own caution against a loadings-only score being read as covering
the ψ-collapse failure mode.

## 6. Non-pooling

Absolute seconds here are **not** compared to `57`, `29`, `71`, `18-four-way`, or
`75`. **`75` in particular carries a known defect (§0), not just a different code
path** — its absolute ratios must not be reused for any purpose, including as a
sanity check on this run's magnitudes. The only same-cell comparison drawn above is
the N=250 seed=1 sanity check (§1), used solely to confirm the `sd.errors` flag has
an effect, not as an accuracy/speed baseline.

## 7. Verdict — what this run does and does not establish

**What it shows, for this cell (T=20, q=2, n_trials=6, binomial-probit, no ψ), 24
seeds, SE-matched, guards verified on every cell:** once gllvm's standard-error pass
is removed to match our arm (which never computes SEs), our previously-reported
speed advantage **mostly does not survive**. At our own shipped default
(`n_starts=4`), we are **slower than gllvm at every N tested, by 3.0–7.4x**. At
matched start counts (`n_starts=1` both sides), the picture is mixed: gllvm is
faster at N=250 (1.86x) and we are modestly faster at N=1000/N=2500 (1.26–1.28x) —
a real but narrow advantage, not the 2.5–3.7x margin reported in the (defective)
75 run. Accuracy is statistically indistinguishable between `n_starts=1` and
`n_starts=4`, and between `ours` and `gllvm_nose`, at every N, with one replicated
single-seed exception (§5).

**What it does not show:** this does not establish claim 30 (`20-CLAIMS-LEDGER.md`)
either for or against — the bar there also requires a ψ report, and this cell plants
none (§5). It also does not extend to other N/T/q/families, and the N=2500/N=1000
tail observations (§4) are existence claims from one or two seeds in 24, not
characterized rates. **The one clear, load-bearing conclusion: "our VA beats
gllvm's" is NOT supported by the corrected, SE-matched comparison at the
configuration users actually get (`n_starts=4`)** — it is slower there at every N
measured. The narrower claim "our VA is modestly faster than gllvm's at matched
start counts, at N≥1000" is supported by this run but is a materially smaller and
more qualified claim than what 75 (defective) appeared to show.

## Files

- Script: `dev/va-speed/79-se-matched-ladder.R` (Totoro, `~/gllvm_work/va-lane2-git/`)
- Verification/aggregation: `dev/va-speed/79-verify.R`, `dev/va-speed/79-aggregate.R` (Totoro)
- Per-cell `.rds`/`.log`: `dev/va-speed/79-ladder-cells/` (Totoro, 72 files each)
- Launch log: `dev/va-speed/79-launch.log` (Totoro)
- Aggregated results: `dev/va-speed/79-se-matched-results.rds` (Totoro and copied to
  `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/79-se-matched-results.rds`)
- This report: `/private/tmp/gllvmtmb-va-lane2/dev/va-speed/79-SE-MATCHED-LADDER.md`

Files written locally but **not committed** — this worktree
(`/private/tmp/gllvmtmb-va-lane2`, branch `claude/va-lane2`) has other uncommitted,
concurrent work in progress from another agent in this session; committing was left
to the coordinator's discretion.
