# 78 — The variance finding is retracted, and the large-N win is not established

**Date:** 2026-08-05 · **Lane:** `claude/va-lane2` @ `728f4aa8` · **Platform:** Claude Code
**Compute:** Totoro (384 cores), model-matched, arm-order rotated · Results **local** (D-50)
**Supersedes:** `72-THE-GAP-IS-VARIANCE.md` (headline retracted, see §1)
**Evidence:** `73-SPLIT-RESULT.md` · `75-CLEAN-LADDER-RESULT.md` · `76-gllvm-eval-counts.md` ·
`77-ADVERSARIAL-REVIEW.md`

---

## Summary

Two claims went into this arc. **Both come out worse than they went in, and the reason is the same
in each case: work that was timed on one side and not the other.**

1. **The "1-in-8 catastrophic seed" was a TMB recompile inside the timing block.** Retracted.
2. **The "we beat gllvm at large N" result timed gllvm computing standard errors our arm never
   computes.** Not established; like-for-like it is a tie, and at our own shipped default we are
   ~4× slower.

Nothing here is promoted to a claim. The conditioning fix that this arc existed to justify should
**not** be built.

---

## 1. The variance finding is RETRACTED

`72-THE-GAP-IS-VARIANCE.md` reported, at N=120 T=10 q=1 binomial-probit `n_trials`=6 ψ=0.6, that our
engine spanned 0.692–**25.508** s across 8 seeds (36.9× spread) while gllvm spanned 3.4×, with one
seed costing **35× our own median** and still reporting `status = "healthy"`. It concluded the gap
"is VARIANCE, not a constant factor" and read that as ill-conditioning.

**Re-run at 8 seeds with an untimed warm-up added and run order randomised** (`73-split-instrumented.R`,
same DGP verified line-for-line against `71-split25.R`):

| | wall range | spread | seed 1 |
|---|---|---|---|
| ours, ψ=0.6 planted (as `71`) | 0.715–0.801 s | **1.12×** | 0.754 s = **1.01×** the median of the rest |
| ours, ψ=0 (correctly specified) | 0.748–0.825 s | **1.10×** | — |

Seed 1 ran **first** in both loops — the position most exposed to any residual first-call cost — and
landed dead mid-pack. Trace-based counts (load-independent) show every one of the 16 fits taking an
identical path: 12 `nlminb` calls, 4 `optim` calls, 570–666 function evaluations, ~1.2 ms per
evaluation. **There is no outlier to explain.**

### The mechanism, measured

`.va_r3_load_dll()` builds into `tempdir()` (`R/va-r3-proto.R:909`), which is **per R session**. Every
fresh `Rscript` therefore **recompiles the TMB template** — and in `71-split25.R` that recompile falls
*inside* the timed block, charged to whichever seed runs first.

Measured on an idle Totoro: **cold 24.77 s, warm 0.23 s.**
The reported excess was 25.508 − 0.753 = **24.76 s**. The original artefact `/tmp/split25.rds` still
exists and independently gives seed 1 = 25.834 s against a 0.996 s median — excess **24.84 s**. Two
independent runs, both matching the compile cost to under 0.1 s.

**The catastrophic seed was the compiler.**

### A second, separate reporting defect

`72`'s table is presented as 8 seeds. **`71-split25.R:22` as committed reads `SEEDS <- 1:3`**, and the
surviving artefact it wrote has **three rows**, disagreeing with every seed-1 figure in `72`. The
"36.9× spread", "86.8× worst case" and "1 seed in 8" framing — carried into commit `96e2f408`'s
message — is not reproducible from anything in the repo.

### What this kills

The conditioning inference rested on "seed 1 is mildly harder for gllvm (3.2×) but catastrophically
harder for us (34×)". Neither half survives: our 34× was the compiler, and gllvm shows no
degradation on seed 1 by the load-independent metric (it has the *lowest* evaluation count of the
eight). **The ~23-file loadings-diagonal reparameterisation scoped in
`docs/design/va-conditioning-audit-vs-gllvm.md` has no evidence behind it and should not be built on
this basis.** The audit itself remains valid as a description of the parameterisation difference; what
is gone is the measurement that made it urgent.

**Misspecification is not the explanation either.** ψ=0.6-planted and ψ=0 cells are statistically
indistinguishable (wall medians 0.749 vs 0.779 s, 4.1% apart; fn medians 603 vs 599). The
discriminator was worth running and it came back negative in the useful direction — there was nothing
to discriminate.

---

## 2. The large-N result is NOT ESTABLISHED

`75-clean-ladder.R` ran T=20 q=2, no ψ, model-matched, N ∈ {250, 1000, 2500} × **24 seeds** = 72
cells on Totoro. Guards passed 72/72 (`eval_method=="ac"`, collapse gate fired), arm order rotated
12/12 per stratum, accuracy matched (paired Wilcoxon p = 0.58 / 0.10 / 0.58, median difference 0.000).

As measured, it looked like a clear win — ours faster by 2.5× at N=1000 and 3.7× at N=2500. **It is
an artefact of two unmatched settings.**

### Defect A — gllvm was timed computing standard errors we never compute

`75-clean-ladder.R:89-91` does not pass `sd.errors`; gllvm 2.0.13 defaults it to **`TRUE`**, adding an
`optimHess()` pass. Our arm computes **no** standard errors — `R/va-r3-proto.R` contains zero
`sdreport` and no `optimHess` call.

Measured at N=1000 on an idle box, same DGP and scoring:

| | seed 1 | seed 2 |
|---|---:|---:|
| ours, `n_starts=1` | 18.79 s | 17.01 s |
| gllvm, `sd.errors=TRUE` — **what was timed** | 50.74 s | 44.65 s |
| gllvm, `sd.errors=FALSE` | **20.28 s** | **16.59 s** |

The SE pass is **60–63% of gllvm's wall time**. Matching it turns the reported 2.70× / 2.62× win into
**1.08× / 0.98× — a tie, with gllvm faster on seed 2.** Accuracy (`rf`) is unchanged by the flag, so
nothing of substance is lost by matching it. This is a pure harness omission.

### Defect B — our arm ran at 1 start; our shipped default is 4

`75-clean-ladder.R:77` passes `n_starts = 1L`; `.va_r3_fit()`'s default is `4L`
(`R/va-r3-proto.R:2189`). Defensible *between* arms — gllvm's `n.init` default is 1 — but the claim is
about our engine, and at the setting a user actually gets:

| N=1000 | seed 1 | seed 2 |
|---|---:|---:|
| ours, `n_starts=4` (default) | 72.22 s | 67.92 s |
| gllvm, `sd.errors=FALSE` | 20.28 s | 16.59 s |
| ratio | **0.28×** | **0.24×** |

**At its default configuration our engine is 3.6–4.1× slower than gllvm doing the same work**, and the
extra starts buy nothing here (`rf` identical to 7 significant figures).

### Smaller defects, recorded

- The three reported ratios (1.04 / 2.51 / 3.82×) do not reproduce under any aggregation of the 72
  cells; they are lower medians, not `median()`. Correct: 1.025–1.033 / 2.523–2.552 / 3.680–3.890.
- **N=250 is a tie**, not a 1.04× edge — paired Wilcoxon p = 0.169, ours faster in 15 of 24. The
  arm-order effect (3–13%) is larger than the 2.5% difference claimed.
- N=250 seed 1 was run outside the harness on an idle box, has no `.log`, and was pooled anyway. It
  is the only uncontended cell — and gllvm wins it.

### Cleared under attack

Contention was **refuted** as an explanation (an idle re-run gives 2.70× against the campaign's
2.46×); arm order is genuinely rotated; accuracy is genuinely matched; `H=15` is inert for the AC tier.

---

## 3. Claim 30 — adjudicated: stays **NOT ESTABLISHED**

The ledger's bar is "model-matched (`unique=FALSE` both sides), ≥10-seed, interleaved head-to-head on
Totoro reporting speed **and** accuracy **and** ψ." This run satisfies model-matching, 24 seeds,
interleaving, Totoro, speed and accuracy. It fails on **ψ** — and not incidentally: the no-ψ cell
**excludes the one documented failure mode of our AC arm** (claim 13: AC collapses a real ψ to 0.0001
against a planted 0.6). A head-to-head that omits ψ omits the regime where we are known to break.

With Defects A and B, the speed half does not support a win either. **Claim 30 remains NOT
ESTABLISHED — do not claim.** This is the third attempt (after retracted claims 16 and 18) and the
first to fail for a reason other than being underpowered.

**Reconciling the two prior measurements**, as this arc owed: `57-gllvm-scaling.R` (1 seed) and
`29-head-to-head-gllvm.R` (12 seeds, load-flagged) disagreed by ~55% at N=1000. The 24-seed clean run
sits close to `57` (2.55× vs 2.72×) and above `29`'s 1.76×, consistent with `29`'s own contamination
flag. But the reconciliation is moot for the purpose it was wanted: **all three share Defect A**, since
`75` inherited its arms from `57`. None of them is a like-for-like engine comparison.

---

## 4. What this changes

**Do not build** the loadings-diagonal reparameterisation on conditioning grounds. Its motivating
measurement is retracted.

**Do fix the harness, and treat it as a lane-wide hazard.** The `tempdir()` recompile means *any*
benchmark in this lane that ran one fit per fresh `Rscript` has paid ~25 s somewhere. Every timing
script needs an untimed warm-up; `71-split25.R` lacked one and `57-gllvm-scaling.R:74-78` has one, so
the lane is inconsistent. A persistent DLL cache would remove the hazard at the source.

**Re-run the ladder SE-matched and at both start counts** before any statement about how we compare to
gllvm. That is a small, well-specified job: pass `sd.errors = FALSE`, run `n_starts` ∈ {1, 4}, and
report both. Until then the honest summary is:

> At N=1000, T=20, q=2, binomial-probit, model-matched and SE-matched, our VA engine is
> **about level with `gllvm` at one start (1.08× / 0.98×, 2 seeds)** and **3.6–4.1× slower at our own
> default of four starts**, with indistinguishable accuracy. Two seeds, one cell — indicative, not
> settled.

**Open and unmeasured:** N=2500 SE-matched (heavy, not run); whether gllvm's N=2500 tail is
optimisation or the SE pass; anything outside these two cells.

---

## 5. Provenance

Every number here was produced this session on a verified checkout (`git rev-parse HEAD` =
`728f4aa82b387b2b93e27009a484f40e28a3d582`, stamped into the result `.rds` metadata), with `gllvm`
2.0.13 on both the local and Totoro sides. Guard assertions, warm-up presence, arm-order balance and
cell counts were checked across all cells rather than spot-checked. Figures from different harnesses
(`71`, `18-four-way`, `29`, `57`, `75`) are **not** pooled anywhere in this document.

The seed counts are small where they are small, and said so: §1 is 8 seeds, §2's headline grid is 24
seeds but its **corrections are 2 seeds on one cell**, which is why §2 downgrades a claim rather than
replacing it with a new one.
