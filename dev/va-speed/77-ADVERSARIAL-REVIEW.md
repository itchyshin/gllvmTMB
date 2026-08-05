# 77 — Adversarial review of findings 1–3 (the seed-1 blow-up, its cause, and the large-N ladder)

**Date:** 2026-08-05 · **Reviewer:** fresh-context adversarial pass, no authorship stake in 71–76
**Mandate:** refute. Default to "not established". Verdicts below are earned, not conceded.

| Finding | Verdict |
|---|---|
| **1 — the 25.5 s blow-up does not reproduce** | **SURVIVES** (upgraded: the non-reproduction is now *explained*, not just observed) |
| **2 — the cause was first-call overhead** | **SURVIVES, strengthened to a measured mechanism** — with one sentence in `76` that is flatly wrong and must be struck |
| **3 — at large N we win, and gllvm has the heavier tail** | **REFUTED as stated.** The N≥1000 win is unmatched work, not engine speed |

New measurements taken for this review (Totoro, **idle box**, load 0.45–1.27, single-threaded):
`~/gllvm_work/adv77.R` → `adv77.log` / `adv77-result.rds`; `~/gllvm_work/adv77b.R` → `adv77b.log`.

---

## FINDING 1 — the blow-up does not reproduce · **SURVIVES**

I attacked every alternative the brief named and could not break it. Then I found the original
run's artefact, which closes it.

### The original run still exists on disk, and it has THREE rows

`/tmp/split25.rds` on Totoro, written **2026-08-04 16:27:26** — three minutes before commit
`96e2f408` (16:30:11) landed `71-split25.R` + `72-THE-GAP-IS-VARIANCE.md`:

```
 seed gllvm_s ours_s  ours_status
    1   0.270 25.834      healthy
    2   0.096  0.996      healthy
    3   0.089  0.829      healthy
```

This matches the committed script exactly (`71-split25.R:22`, `SEEDS <- 1:3`; `:89`,
`saveRDS(r, "/tmp/split25.rds")`). It **does not match `72-THE-GAP-IS-VARIANCE.md`**, which
reports eight seeds and per-seed ours `25.508, 0.923, 0.780, 0.692, 0.732, 0.725, 0.729, 0.775`
with gllvm max `0.294`. Seed 1 differs (25.834 vs 25.508), seed 2 differs (0.996 vs 0.923), gllvm
seed 1 differs (0.270 vs 0.294). See **Defect 3**.

What matters for Finding 1: the blow-up appears in **both** runs, and in both it is the **first
`.va_r3_fit()` call of a fresh R session** — the only seed that could be.

### Attack 1a — "the DGP does not match, so the comparison is invalid." REFUTED.

`71-split25.R:24-32` and `73-split-instrumented.R:46-54` are line-for-line the same generator, in
the same RNG draw order (`lam` → `a` → `u` → trait intercepts → `rbinom`). 73 adds only a default
`N = N0` argument so a tiny warm-up cell can reuse it; `mk(seed)` therefore reproduces 71 exactly.
Both fit through the same call with the same arguments and the same `n_starts` default of `4L`
(`R/va-r3-proto.R:2189`) — the trace confirms 4 starts (12 `nlminb` + 4 `optim`, every fit).
71 calls `.va_r3_fit()` after `load_all`, 73 calls `gllvmTMB:::.va_r3_fit()`; same function.

### Attack 1b — "the box was under load ~25, so the numbers are contaminated." REFUTED as material.

Real but immaterial, and the write-up already declares it (`73-SPLIT-RESULT.md:21-28`). The
load-independent metric settles it: `fn_total` spans **570–666** across the 8 seeds (1.17×) and
`ms_per_fn_eval` spans **1.203–1.261** (1.05×). A 34× wall-clock blow-up is arithmetically
impossible under those two numbers — it would need either ~20,000 evaluations or ~40 ms/eval, and
neither occurs. I also re-ran the arm on an idle box (below): our N=1000 timings came in 20–24%
*faster* than under the 71-job campaign, i.e. contention inflates uniformly and mildly.

### Attack 1c — "the warm-up could MASK a real effect rather than remove an artefact." REFUTED.

A warm-up at N=40, seed 999 (`73-split-instrumented.R:123-127`) can only pay one-time costs
(compile, `dyn.load`, first-call R/JIT). It cannot suppress a *data-dependent* optimisation
pathology at N=120, because such a pathology must show in the traced evaluation counts, which are
recorded per fit and are warm-up-independent. They are flat. Further, seed 1 ran **first** in the
timed loop (`run_order_position = 1`, `73-run.log:19`), so it remained the most exposed seed to any
residual first-call cost.

### Attack 1d — "8 seeds is few; a genuine 1-in-N pathology could hide." PARTLY LANDS, but not here.

True in general and I state it as the residual: nobody has looked past 8 seeds at one cell, so a
1-in-50 pathology at some other (N, T, q, family) is untested. It is *not* an escape for the
claimed one, because the claimed one is seed 1 specifically, and seed 1 is now fully accounted for
(Finding 2). The burden has moved: to revive the variance thesis someone must exhibit a blow-up
that is **not** the first fit in its session.

---

## FINDING 2 — the cause was first-call overhead · **SURVIVES, and is now measured**

Finding 2 was offered as a hypothesis. It is now a number.

### The mechanism, in source

`.va_r3_load_dll()` builds the TMB template into **`tempdir()`** —
`R/va-r3-proto.R:909`:

```r
build_dir <- file.path(tempdir(), paste0("gllvmTMB-va-r3-", stamp))
```

`tempdir()` is **per R session**. So the compiled `.so` never survives a session, and
`R/va-r3-proto.R:924-932` recompiles on the first `.va_r3_fit()` of every fresh `Rscript`. In
`71-split25.R` that call sits **inside the timed block** (`:57`, `o <- tm(tryCatch(.va_r3_fit(...`).
The compile is therefore billed to whichever seed runs first. `73-run.log:5-7` shows exactly this
compile firing mid-script.

### The number

Fresh session, idle Totoro (`~/gllvm_work/adv77b.log`):

```
COLD .va_r3_load_dll (TMB compile) : 24.77 s
WARM .va_r3_load_dll (cached .so)  :  0.23 s
tempdir: /tmp/RtmpI1Toyp
```

Now the arithmetic:

| source | seed-1 wall | that run's clean median | excess | measured compile |
|---|---:|---:|---:|---:|
| `/tmp/split25.rds` (the surviving original) | 25.834 | 0.996 / 0.829 | **24.84–25.01 s** | 24.77 s |
| `72-THE-GAP-IS-VARIANCE.md` (the reported table) | 25.508 | 0.753 | **24.76 s** | 24.77 s |

The excess matches the measured cold compile **to within 0.01 s** in the doc's own numbers. This is
not "consistent with a warm-up gap"; it is the same quantity. There is nothing left to explain.

### 🔴 One sentence in `76-gllvm-eval-counts.md` is false and must be struck

`76-gllvm-eval-counts.md:64-65`:

> "This does **not** refute our own 25.5 s blow-up — that is far too large to be warm-up."

It is exactly the size of the warm-up: 24.77 s. The author had no compile timing in hand and
guessed. Strike or correct it; as written it preserves the variance thesis on a false premise.

### The weak half of Finding 2

`76`'s gllvm-side evidence (seed 1 has the fewest evaluations, 154 vs ~188, yet the highest wall,
0.146 s vs ~0.105 s) points the same way but is **thin on its own**: it is a 41 ms difference from a
single unreplicated run, and gllvm's own first-call cost is small. The surviving artefact agrees
qualitatively (gllvm seed 1 = 0.270 s against 0.096/0.089) — a ~0.18 s first-call cost. Keep it as
corroboration; it should not be load-bearing. The compile timing is the evidence.

---

## FINDING 3 — "at large N we win" · **REFUTED as stated**

I verified the ladder independently from the 72 per-cell `.rds` files
(`totoro:~/gllvm_work/va-lane2-git/dev/va-speed/75-ladder-cells/`, copied and re-read locally).
Several things the brief worried about are **fine**. The headline is not.

### What checks out

- **Guards.** 72/72 cells `ours_guard_ok = TRUE`, `eval_method == "ac"`, collapse gate fired, zero
  errors either arm, gllvm 2.0.13 throughout.
- **Arm order IS rotated.** `75-clean-ladder.R:124`, `first_ours <- (SEED0 %% 2L) == 1L`. From the
  `.rds` files: **12 / 12 split at every N**. The brief's feared systematic bias does not exist and
  I could not manufacture it. (There *is* an order **effect** — see Defect 7.)
- **Accuracy is genuinely matched.** `rf` agrees between arms to ~5 decimals in 70 of 72 cells
  (e.g. N=1000 s1: 0.17086498 vs 0.17087397). Paired Wilcoxon on `rf`: p = 0.58 / 0.10 / 0.58 at
  N = 250 / 1000 / 2500; median paired difference 0.00000 at all three. The two exceptions:
  N=2500 s11 (ours 0.1135 vs gllvm 0.1854 — **ours better**) and N=250 s8 (ours 0.1822 vs 0.1768).
  We are **not** winning by fitting something worse. That part of Finding 3 stands.
- **`H = 15L`** (vs the `H = 61L` default) is **inert** for this arm: the AC path takes no
  quadrature nodes (`inst/tmb/gllvmTMB_va_r3.cpp:357-361`, `va_r3_probit_ac_expectation(mu, v, y, n)`),
  and the branch is on `DATA`, so the unused GH branch lays down no AD nodes. Not a confound.
- **Contention is not manufacturing the win.** Idle-box re-run of N=1000 seed 1: ours 18.79 s,
  gllvm 50.74 s → **2.70×**, *larger* than the campaign's 22.516 / 55.415 = 2.46×. Contention
  inflated our arm by 20–24% and gllvm's by 9–15%, i.e. it worked **against** the claim. The
  "load ~28, 71 concurrent jobs" objection is refuted.

### 🔴 Defect 1 (CRITICAL) — gllvm is timed computing standard errors that our arm never computes

`75-clean-ladder.R:89-91`:

```r
run_gllvm <- function(cell) gllvm::gllvm(
  y = cell$Y, family = binomial(link = "probit"),
  num.lv = Q0, method = "VA", Ntrials = NTR, seed = 1L, trace = FALSE)
```

`sd.errors` is **not passed**, and `gllvm::gllvm()`'s default is **`sd.errors = TRUE`** (confirmed
in the 2.0.13 help page and body). `76-gllvm-eval-counts.md:28-29` already documents this as
gllvm's "stage 3 … `optimHess()` pass for SEs".

Our arm computes **no standard errors at all**: `R/va-r3-proto.R` contains **zero** `sdreport`
calls and no `optimHess` call (the only match at `:1479` is a comment). The `se` knob in this
package lives on `gllvmTMBcontrol()`, one layer above `.va_r3_fit()`.

Measured directly, N=1000, idle box, same DGP and same scoring as `75`:

| | seed 1 | seed 2 |
|---|---:|---:|
| ours, `n_starts = 1` | 18.79 s | 17.01 s |
| gllvm, `sd.errors = TRUE` (**what 75 timed**) | 50.74 s | 44.65 s |
| gllvm, `sd.errors = FALSE` | **20.28 s** | **16.59 s** |
| `rf` (all four fits) | 0.17086–0.17087 | 0.15986 |

**The SE pass is 60% / 63% of gllvm's wall time.** Removing that unmatched work:

- 75's reported pairing: **2.70× / 2.62×** "ours faster"
- **SE-matched: 1.08× / 0.98×** — a dead tie; on seed 2, gllvm is *faster*.

The headline "N=1000 2.51× ours" is not an engine result. It is the cost of a Hessian we declined
to compute. The `rf` values are unchanged by `sd.errors`, so nothing of substance is lost by
matching it — this is a pure harness omission.

### 🔴 Defect 2 (CRITICAL) — our arm runs at 1 start; our own default is 4

`75-clean-ladder.R:77` passes `n_starts = 1L`. `.va_r3_fit()`'s default is `n_starts = 4L`
(`R/va-r3-proto.R:2189`) — the setting used by `71` and by `73`, whose trace shows all four starts
running (12 `nlminb` + 4 `optim` per fit).

Between arms this is defensible: gllvm's `control.start` default is `n.init = 1`. But the claim
being made is about *our engine*, and at our engine's shipped setting, on the same idle box:

| N=1000 | seed 1 | seed 2 |
|---|---:|---:|
| ours, `n_starts = 4` (default) | 72.22 s | 67.92 s |
| gllvm, `sd.errors = FALSE` | 20.28 s | 16.59 s |
| ratio | **0.28×** | **0.24×** |

At its default configuration our engine is **3.6–4.1× slower** than gllvm doing the same work.
`rf` is identical at 1 and 4 starts (0.1708650 vs 0.1708683), so the extra starts buy nothing here.
Any statement of Finding 3 must carry both the SE match and the start count, or it misdescribes
what a user gets.

### Defect 3 (HIGH) — `72`'s headline table has no surviving artefact and the committed script cannot produce it

Covered above. `71-split25.R:22` is `SEEDS <- 1:3`; the artefact it wrote has 3 rows and disagrees
with every seed-1 figure in `72`. The 8-seed table in `72-THE-GAP-IS-VARIANCE.md:22-30` — including
the "36.9× spread", "86.8× worst case" and "1 seed in 8" framing carried into commit `96e2f408`'s
message — is unreproducible from anything in the repo. Given Finding 2, the underlying event is
explained either way, but the *reporting* is not sound and the doc should say so.

### Defect 4 (HIGH) — claim 30's bar is not met: ψ is absent by construction, in the one regime where our AC arm is known to fail

`20-CLAIMS-LEDGER.md` claim 30 demands "model-matched (`unique=FALSE` both sides), ≥10-seed,
interleaved head-to-head on Totoro reporting speed **and** accuracy **and** ψ". `75` meets
model-matching (24 seeds, interleaved, both `unique=FALSE`) and reports speed and accuracy. It does
**not** report ψ, and `75-clean-ladder.R:17-21` is explicit that no ψ is planted and neither arm
fits a ψ tier.

The script defends this as "not applicable, not silently omitted". That is honest about the
mechanics and still misses the point of the requirement. The same ledger entry records that
ours-AC — **the exact arm `75` times** — "destroys ψ (0.0002 against a planted 0.6, where our GH
recovers 0.5417 on the same data)" and is "6 of 12 against gllvm-VA" on accuracy when ψ is present.
Choosing a DGP with no ψ removes the one dimension on which this arm is known to fail. That is a
regime selected around a weakness, and claim 30 must stay **NOT ESTABLISHED**.

Generalisation is also thinner than the headline implies: one T (20), one q (2), one family
(binomial-probit), one `Ntrials` (6), no ψ, single start, no SEs.

### Defect 5 (MEDIUM) — the three reported ratios do not reproduce from the 72 cells

Recomputed from the `.rds` files:

| N | ours med | gllvm med | median/median | median of per-cell ratios | **reported** |
|---:|---:|---:|---:|---:|---:|
| 250 | 3.389 | 3.476 | 1.025× | 1.033× | 1.04× |
| 1000 | 22.309 | 56.923 | **2.552×** | 2.523× | 2.51× |
| 2500 | 119.337 | 439.119 | **3.680×** | 3.890× | 3.82× |

The reported *medians* (22.26, 119.26, 435.73) are the **lower median** — the 12th of 24 order
statistics — not what `75-aggregate.R:53` computes (`median()`, which averages the two middle
values). The reported *ratios* match neither the lower-median pairing (2.557×, 3.654×) nor
median/median nor the median of per-cell ratios nor either mean. They are not reproducible under any
aggregation I tried. The direction of the error is mixed (2.51 understates, 3.82 overstates), so it
is sloppiness rather than spin — but the numbers as relayed are wrong.

Spreads *do* check out: N=2500 ours 1.26×, gllvm 2.19× (reported 2.20×).

### Defect 6 (MEDIUM) — one cell was run outside the harness, on an idle box, and pooled

`75-joblist.txt` has **71** entries and `75-launch.log` records 71 completions — **N=250 seed 1 is
absent from both**. Its `.rds` exists; its `.log` does not (72 `.rds`, 71 `.log`). Its recorded load
is `load_start = 0.60, load_end = 0.71`, against `28.47 / 31.96` for every other N=250 cell. It was
run separately, on a quiet box, and pooled into the stratum.

Consequences: (a) `75-verify.R:27`'s warm-up check — "the per-cell `.log` literally contains
`warm-up done (UNTIMED)`" — **cannot pass** for this cell, so that verification covers 71/72, not
72/72; (b) `75-aggregate.R:21`'s `stopifnot(nrow(r) == 72L)` passes only because the stray cell
happens to fill the gap the joblist left. The medians barely move (N=250 ratio 1.025× either way),
so this is provenance hygiene, not a numerical error — but it is exactly the kind of cell that
should not silently join a stratum.

Worth noting what that cell *says*: it is the **only** ladder cell measured without contention, and
in it **gllvm is faster** (ours 3.063 s vs gllvm 2.799 s).

### Defect 7 (MEDIUM) — N=250 is a tie, and the order effect is larger than the difference claimed

Paired Wilcoxon at N=250: **p = 0.169**; ours faster in **15/24** cells; per-cell ratios span
0.883–1.771. There is no N=250 result. Meanwhile the arm-order effect, computed from `first_ours`:

| N | ours: first vs second | gllvm: first vs second |
|---:|---:|---:|
| 250 | −12.6% | +2.5% |
| 1000 | +6.3% | +3.6% |
| 2500 | +9.1% | +4.7% |

3–13%, sign-unstable on our arm — several times the ~2.5% being reported at N=250. Rotation
prevents this from biasing the *pooled* estimate, but it sets the resolution floor, and the N=250
number is well below it. Report N=250 as "no detectable difference", not as "1.04× ours".

### What survives of Finding 3

Stripped to what the data support:

> At N ≥ 1000, T=20, q=2, binomial-probit with no ψ and single-start, our AC+collapse arm reaches
> the **same accuracy** as gllvm's VA (rf identical to 5 decimals, 24 paired seeds) — and, when
> gllvm's default standard-error pass is disabled to match ours, at **essentially the same speed**
> at N=1000 (1.08× / 0.98×, 2 seeds). At our engine's own default `n_starts = 4` we are ~3.6×
> **slower**. gllvm's wall-clock spread is genuinely wider (2.19× vs 1.26× at N=2500) and is
> seed-linked rather than random — seeds 8 and 21 are its two slowest at both N=250 and N=2500 —
> but that tail was measured with the SE pass included and has not been re-measured without it.

The N=2500 stratum has **not** been re-measured SE-matched (see below). Until it is, no large-N
speed claim should be made in any direction.

---

## Defects ranked

| # | Severity | Defect |
|---|---|---|
| 1 | **CRITICAL** | `75-clean-ladder.R:89-91` times gllvm with `sd.errors = TRUE` (its default) against an arm that computes no SEs at all (`R/va-r3-proto.R`: 0 `sdreport`, 0 `optimHess`). Measured: 60–63% of gllvm's N=1000 wall. SE-matched the win becomes 1.08× / 0.98×. |
| 2 | **CRITICAL** | `75-clean-ladder.R:77` runs our arm at `n_starts = 1L` against its own default `4L` (`R/va-r3-proto.R:2189`). At the default we are 3.6–4.1× **slower** than an SE-free gllvm, with identical `rf`. |
| 3 | **HIGH** | `72-THE-GAP-IS-VARIANCE.md`'s 8-seed headline table is unreproducible: the committed script is `SEEDS <- 1:3` (`71-split25.R:22`) and the surviving `/tmp/split25.rds` has 3 rows disagreeing with every seed-1 figure. |
| 4 | **HIGH** | Ledger claim 30's ψ requirement is unmet, and the no-ψ cell excludes ours-AC's one documented failure mode. Claim 30 stays NOT ESTABLISHED. |
| 5 | **MEDIUM** | Reported ratios 1.04× / 2.51× / 3.82× reproduce under no aggregation of the 72 cells (correct: 1.025–1.033× / 2.523–2.552× / 3.680–3.890×). Reported medians are lower medians, not `75-aggregate.R`'s `median()`. |
| 6 | **MEDIUM** | N=250 seed 1 ran outside `75-run-cell.sh` on an idle box (load 0.6 vs 28.5), has no `.log`, and was pooled anyway; `75-verify.R:27` therefore verifies 71/72 while `75-aggregate.R:21` passes on 72. |
| 7 | **MEDIUM** | N=250 is a statistical tie (paired Wilcoxon p = 0.169, 15/24) and the arm-order effect (3–13%) exceeds the 2.5% being reported. |
| 8 | **LOW** | `76-gllvm-eval-counts.md:64-65` asserts the 25.5 s blow-up is "far too large to be warm-up". It is 24.77 s of warm-up. Strike it. |
| 9 | **LOW** | The whole Finding-3 evidence base (`75-clean-ladder.R`, `75-aggregate.R`, `75-verify.R`, `75-joblist.txt`, `75-run-cell.sh`, 72 cells, 71 logs) exists **only** on Totoro and is not in the lane's git tree. `73/74/76` are likewise untracked (`git status`). |
| 10 | **LOW (design)** | `tempdir()`-scoped TMB builds (`R/va-r3-proto.R:909`) make every fresh session pay 24.77 s, billed to the first timed fit. Every harness in this lane must warm up or it will re-manufacture this artefact. `71` did not; `57-gllvm-scaling.R:74-78` and `75` do. |

---

## The one repair that changes the conclusion

Re-run `75-clean-ladder.R` with two edits and nothing else:

1. `run_gllvm()`: add `sd.errors = FALSE`.
2. Report both `n_starts = 1L` and `n_starts = 4L` for our arm.

Then re-decide. Everything else about the harness — rotation, guards, warm-up, shared-floor
accuracy scoring, 24 seeds, single-threaded, interleaved — is sound and does not need rebuilding.

---

## What I could not check

- **N=2500 SE-matched.** I measured the `sd.errors` confound only at N=1000, 2 seeds. The N=2500
  stratum is ~10 min of single-core work per cell and I was instructed not to launch heavy jobs.
  gllvm's N=1000→2500 scaling (7.7×) exceeds ours (5.35×), which *suggests* the SE pass grows
  faster than the fit, i.e. the confound is likely worse at N=2500 — but that is inference, not
  measurement, and the reverse is possible.
- **Whether gllvm's heavy N=2500 tail (seed 21 at 821 s, seed 8 at 660 s) is an optimisation tail
  or an SE-pass tail.** Untested. The "gllvm has the heavier tail" claim inherits Defect 1.
- **The original 71 session's actual state.** I infer the DLL was cold from arithmetic that matches
  to 0.01 s, and from `71-split25.R:57` putting `.va_r3_fit()` inside `tm()`. No session log
  survives; I did not observe it.
- **Anything outside T=20, q=2, binomial-probit, `Ntrials`=6, no ψ** (Finding 3) or **N=120, T=10,
  q=1** (Findings 1–2). Neither result generalises on this evidence.
- **Whether gllvm's SE output and ours would be comparable if we computed SEs.** Disabling gllvm's
  SEs is the right *speed* match; whether our engine could produce equivalent SEs at comparable
  cost is a separate, unasked question.
