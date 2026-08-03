# Design 108 recovery campaign — PILOT findings

Status: **Job 1 complete and analysed. Jobs 2–4 are ON HOLD** pending a separate adversarial
diagnostic into the finding below (an agent that did not build the harness is checking an
estimand/scale-convention mismatch, an `S_i`-vs-`Sigma_B` conflation, a genuine `q=1`
identifiability limit, a truth-extraction/`rel_frob` defect, and a diagonal-dominance metric
floor). **`SD(d)` and the N-ladder floor are NOT reported here and must not be inferred from
anything below — they are blocked on that diagnostic, not merely pending more seeds.**

Scripts: `dev/design108-recovery/pilot-results/job1_floor_sweep.R` (run; `job2_sd_d.R`,
`job3_tips_only_wall.R`, `job4_bridge.R` written but **not run**, per the hold). Raw per-cell
output: `dev/design108-recovery/pilot-results/job1_floor_sweep.{rds,csv}`,
`job1_full.rds` (LOCAL only, per D-50 — not committed, never a GitHub artifact).

Fixed pilot design (deliberately cheaper than the eventual campaign grid): `T = 20`
(PROTOCOL.md §Design grid's Part A floor trait count), `q = 1`, `lambda_sd = 0.7`
("mild" `sigma_lambda`), `n_trials = 6` (multi-trial — avoids the shipped engine's Bernoulli
Psi-identifiability skip caught while building the harness), `n_starts = 1`, `H = 15`
(cheapest admitted quadrature order — deliberate speed choices for calibration, not the
eventual grid's settings), `gauss_sd = 0.4` (PROTOCOL.md's proposed `gaussian_control`
residual SD). Job 1 fit the `gaussian_control` arm only (Laplace engine, identity link,
Gaussian response on the same realized `eta`) — no VA arm has been fit yet in this pilot.

---

## Headline: the positive control plateaus — it does not converge to truth

Design was: sweep N over {100, 250, 500, 1000} at T=20, q=1, 3 seeds each, fitting
`gaussian_control` only, and read the smallest N at which it recovers cleanly. **The intended
floor calibration did not produce a floor**, because the control's `rel_frob` does not trend
toward zero with N — it improves once (100 → 250) and then stalls:

| N | mean rel_frob tier 1 | mean rel_frob tier 2 | s/cell (mean) |
|---|---|---|---|
| 100  | 0.584 | 0.554 | 21  |
| 250  | 0.418 | 0.373 | 59  |
| 500  | 0.348 | 0.402 | 130 |
| 1000 | 0.394 | 0.419 | 280 |

Per-seed detail (12 rows) is in `dev/design108-recovery/pilot-results/job1_floor_sweep.csv`.

At N=1000, T=20 that is 20,000 observations estimating on the order of 40 parameters (per-trait
loadings/psi for two tiers); a consistent estimator's sampling error at that ratio should be
in the low single digits of percent, not 35–47%. **The control's error stops shrinking with N.
A plateau, not a decaying curve, is the signature of a systematic mismatch (the estimand
`rel_frob` compares, or the metric itself, does not track the recovery it is meant to measure)
— it is not the signature of finite-sample noise, which would keep shrinking.** This is treated
as a stop condition, not a data point to average over: the N-ladder floor this pilot was meant
to calibrate **cannot be set** until the plateau is explained, because "clean at N" was never
observed at any tested N — only "less bad."

**The degeneracy gate this campaign inherited from `analyse-silent-divergence.R`
(`rel_frob > 10 AND convergence == 0 AND pdHess == TRUE`) passes every one of these 12 cells**
(`rel_frob` never exceeded 0.82; `pdHess` was `TRUE` throughout; `convergence` was 0 in 5/12
rows and 1 in 7/12, with no visible relationship to `rel_frob`). That gate answers "did the fit
blow up," and the answer is no. It is silent on the question this campaign actually needs
answered — "did the fit land near truth" — where the honest answer at every N tested is "no,
not closely, and not improvingly." Both gates are reported here on purpose: passing the
degeneracy gate while failing the precision trend is exactly the gap non-negotiable 3 exists to
catch, and reusing only the inherited gate would have missed it.

**What this does NOT mean, stated so it cannot be misread downstream.** The design is paired
(non-negotiable 2): `d = rel_frob_VA − rel_frob_Laplace` is a within-seed, within-cell
difference, so a large *common* control error does not by itself prevent detecting a
VA-vs-Laplace *difference* — shared DGP-and-sampling noise cancels in `d` the way it does not
in either arm's raw `rel_frob`. **The control's plateau bounds ABSOLUTE claims** ("VA recovers
`Sigma_B` to within X of truth") **and does NOT automatically invalidate the PAIRED claim**
("VA recovers better than Laplace by `d`"). Conflating those two is the same class of error as
conflating `S_i` with `Sigma_B` (Design 109's own stated trap for this problem) — keep them
separate in every later write-up.

**But `SD(d)` is still blocked here, and deliberately not measured this round**, for a
different reason than the paired-cancellation argument above: if the plateau turns out to be an
**estimand mismatch** — `Sigma_hat` and `Sigma_true` denoting different objects, rather than the
same object measured noisily — then `rel_frob` is mis-specified for *every* arm, not just
`gaussian_control`, and `d` becomes a difference of two mis-specified quantities. Its `SD` would
then be a precise measurement of the wrong thing, and the whole grid would be sized off it. That
is why Job 2 (which measures exactly this `SD(d)`) is on hold pending the diagnostic, not run
opportunistically on the reasoning that pairing protects it — the reasoning only protects `d`
against *noise* cancelling, not against a *definitional* mismatch shared by both arms.

---

## Cost curve (feeds grid affordability regardless of how the diagnostic resolves)

Mean wall-clock per cell, `gaussian_control` arm only, Laplace/glm engine, T=20, q=1:

| N | mean s/cell |
|---|---|
| 100  | 21.5  |
| 250  | 58.8  |
| 500  | 130.3 |
| 1000 | 280.3 |

Log-log fit across all 12 rows: `elapsed_s ~ N^1.12` (`exponent = 1.119`, fit on individual
rows; `1.118` fit on the 4 per-N means — the two agree to 3 significant figures, so the
per-row scatter is not distorting the estimate). Ratio check: N=100→1000 is a 10x increase in N
against a **13.0x** increase in cost (`10^1.12 ≈ 13.2`, consistent); N=250→1000 (4x) gives
**4.76x** cost. **The scaling is mildly superlinear, not quadratic** — this is the
`gaussian_control`/Laplace arm only; VA and `va_tips_only` have not been timed in this pilot and
are expected to scale differently (Job 3 exists specifically to measure `va_tips_only`'s O(N²)
inner solve once unblocked).

At this exponent, a naive projection to N=5,000 (envelope floor) would be
`280.3 * (5000/1000)^1.12 ≈ 1,730 s` (~29 min) **per `gaussian_control` cell alone**, before
Laplace's substantive-family fit, before any VA arm, and before seed replication. This is a
projection from 4 points at small N, not a measurement at that N, and is reported only to make
clear that the eventual grid's affordability is not free even before the plateau is explained.

---

## Informativeness labelling (applied to what Job 1 already collected — no refit)

PROTOCOL.md's "GAP FOUND 2026-08-02 — the uninformative-cell trap" section defines
`INFORMATIVE := any(arm tier-2 rel_frob <= <stated level>)`, stipulating the level rather than
deriving it. **Important scope caveat: Job 1 fit only the `gaussian_control` arm** (by design,
to keep the floor sweep cheap) — Laplace and both VA arms have not been fit at any of these
cells yet. So the label below is a **single-arm proxy**, not the full precondition (which is
defined over the committed arm set); it will need re-deriving once Job 2's paired Laplace/VA
data exists for these cells. Stipulated level: **0.5** (matching the `rel_frob` gate already
used elsewhere in this pilot and in `.d108_positive_control_gate()`'s default — a stipulation,
not a derived constant).

| N | seed | tier-2 rel_frob (gaussian_control) | informative (level 0.5, control-only) |
|---|---|---|---|
| 100  | 1 | 0.572 | NO  |
| 100  | 2 | 0.359 | YES |
| 100  | 3 | 0.731 | NO  |
| 250  | 1 | 0.345 | YES |
| 250  | 2 | 0.230 | YES |
| 250  | 3 | 0.545 | NO  |
| 500  | 1 | 0.285 | YES |
| 500  | 2 | 0.582 | NO  |
| 500  | 3 | 0.337 | YES |
| 1000 | 1 | 0.369 | YES |
| 1000 | 2 | 0.416 | YES |
| 1000 | 3 | 0.473 | YES |

Counts: **8/12 INFORMATIVE, 4/12 UNINFORMATIVE** by this single-arm proxy (N=100: 1/3;
N=250: 2/3; N=500: 2/3; N=1000: 3/3). Read cautiously: because `gaussian_control` itself is the
arm whose recovery is in question here (the plateau above), an "informative" label under this
proxy means only "the control's own tier-2 error happened to fall under 0.5 at this seed," not
"the phylogenetic signal is estimable by the engines under test" — that requires Laplace/VA
data this pilot has not yet collected. The one directional signal worth noting: the
INFORMATIVE fraction rises with N (1/3 → 2/3 → 2/3 → 3/3), consistent with *some* N-dependent
improvement existing even though the mean `rel_frob` plateaus — a mean can plateau while the
fraction clearing a fixed threshold still creeps up, and both are reported here rather than
picking one.

---

## What is explicitly BLOCKED, and why

- **`SD(d)` (Job 2): BLOCKED.** Not run. See "Headline" above — measuring it now would size the
  grid off a quantity (`rel_frob`) that may be mis-specified for every arm, not just the control.
- **N-ladder floor: BLOCKED / NOT SET.** No N in {100, 250, 500, 1000} produced a clean control
  by the trend criterion (decaying toward a small value); the mean plateaus at 0.35–0.42 from
  N=250 onward. A floor cannot be honestly picked from these numbers, and none is proposed here.
- **Job 3 (`va_tips_only` affordability wall): NOT RUN**, per the hold — no VA fitting of any
  kind has occurred in this pilot yet.
- **Job 4 (joint-vs-profiled bridge): NOT RUN**, same reason.

All four scripts (`job2_sd_d.R`, `job3_tips_only_wall.R`, `job4_bridge.R`) are written, smoke-
tested for syntax only (not executed), and ready to run once the diagnostic clears — see
`dev/design108-recovery/pilot-results/`.

---

## Raw Job 1 table (all 12 cells, for reference)

See `dev/design108-recovery/pilot-results/job1_floor_sweep.csv` /
`job1_full.rds` (LOCAL only, not committed). Columns: `N, T, q, seed, status, convergence,
pdHess, rel_frob_tier1, rel_frob_tier2, elapsed_s, total_s, clean` (`clean` uses the inherited
degeneracy-style gate — `rel_frob <= 0.5` both tiers, `pdHess == TRUE`, `convergence == 0` — and
is retained in the file for transparency even though the headline finding here is the trend
plateau, not this pointwise flag).

---

## Operational note for the grid launcher (found 2026-08-02, orchestrator)

**The shared VA-template DLL cache is NOT wired into the fit path.** `harness.R:140-152`
defines the compile-then-persist helper and it works (verified across two separate processes:
18 s cold compile -> 0.36 s warm load), but there is **no call site in `run_cell()`**. A fresh
`Rscript` therefore recompiles the template from scratch — directly observed in a clean run
after the confound fix, which spent its first ~25 s in `clang++` despite a populated cache at
`~/.cache/gllvmtmb-va-r3-dll/<md5>/`.

Consequence for **S5**: at ~25 s per worker on Totoro's Linux toolchain this is trivial if
workers are persistent and paid once each, and material if the launcher spawns a fresh R
session per cell — thousands of cells x 25 s is hours of pure compilation. **The launcher must
seed the cache before fanning out**, or call the helper at worker startup. This is a launcher
requirement, not a harness defect.

Note the cache is keyed on the md5 of `inst/tmb/gllvmTMB_va_r3.cpp`, so it survives changes to
`harness.R` (as here) but correctly invalidates if the template itself changes.

---

## JOB 1b — the corrected control curve (supersedes Job 1, which is VOID)

Job 1 was measured on a broken instrument. Four defects were corrected between them
(`132aa79b`, `c20fb681`, `37531e09`, and the control's loadings extraction). Job 1's numbers
must not be cited.

**HEADLINE = loadings estimand.** Means over 3 seeds, T=20, tree spanned by seeds.

| N | q | tier-1 loadings | tier-2 loadings | s/cell |
|---|---|---|---|---|
| 100 | 1 | 0.333 | 0.811 | 22 |
| 250 | 1 | 0.171 | 0.692 | 54 |
| 500 | 1 | 0.114 | 0.476 | 105 |
| 1000 | 1 | **0.092** | **0.380** | 248 |
| 100 | 2 | 0.305 | 0.584 | 32 |
| 250 | 2 | 0.145 | 0.517 | 89 |
| 500 | 2 | 0.093 | 0.486 | 213 |
| 1000 | 2 | **0.105** | **0.432** | 414 |

### 1. The plateau is GONE, and it was never real

Tier 1 falls monotonically 0.333 -> 0.171 -> 0.114 -> 0.092 at q=1, against the broken
curve's 0.35-0.42 which refused to move between N=500 and N=1000. The apparent "instrument
floor" was entirely the estimand mismatch plus the DGP/model Psi-structure contradiction.
**Nothing real remains underneath it on tier 1.**

### 2. The PHYLO tier converges far more slowly -- and this is the campaign's tier

Tier 2 is descending but is still **0.38-0.43 at N=1000**, roughly **4x** tier 1 at the same
N. The control -- the arm that MUST recover, on the easiest possible family -- does not reach
clean recovery on the phylogenetic tier at any N tested.

**This is a substantive result, not a defect**, and it constrains the campaign directly:

- **The floor cannot be set from tier 2 within the tested range.** At a stipulated 0.5 gate,
  tier 2 clears only at N >= 500 (q=1) and is marginal at q=2. At any stricter gate it clears
  nowhere below N=1000.
- **It is consistent with, and sharpens, Design 72's warning** that the structural question
  needs "adequate n" -- adequate is evidently well above 1000 for the phylo tier, not the
  n >= 30 identifiability floor.
- It is the same tier flagged in the diagnostic as possibly carrying a genuine limit, with
  within-N spread far exceeding tier 1's. This curve does NOT settle whether the residual is
  finite-sample or structural; it only shows it is still shrinking at N=1000.

### 3. `q` matters, and not in one direction

At small N, q=2 recovers tier 2 BETTER than q=1 (0.584 vs 0.811 at N=100); by N=1000 the
order reverses (0.432 vs 0.380). Reporting a q-pooled rate would have averaged over a
crossing interaction and shown neither. This is exactly the failure #897 was overturned for,
and is why `q` is a grid column.

### 4. Cost

Control-only, roughly N^1.1 at q=1 (22/54/105/248 s) and steeper at q=2 (32/89/213/414 s).
q=2 costs ~1.7x q=1 at N=1000. **VA cost is still unmeasured** -- Job 2b.

---

## JOB 2d/2e — the external check: our VA is CORRECT, and more accurate than gllvm's

Prompted by the maintainer: measure whether gllvm's VA is trustworthy HERE rather than
transferring a degeneracy rate from a different method under different conditions, and
whether OUR VA has bugs. Both were open questions dressed up as settled ones.

**Design.** One-tier regime (`phylo_scale = 0`, which the DGP's anchor test proves reduces
EXACTLY), binomial-probit, N=250, T=20, q=1. Both engines fit the SAME single-tier model on
the SAME data, scored against planted truth. An earlier attempt was flawed and is not cited:
it kept our 198-level structured tier at `phylo_scale = 0`, so ours fitted a strictly larger
model and the cost comparison was meaningless.

| engine | median time | median `rel_frob` | degenerate |
|---|---|---|---|
| gllvm VA (mature reference) | **0.79 s** | 0.357 | **0/6** |
| **our VA** | 47.3 s | **0.283** | 0/3 |
| our Laplace | 114.5 s | **0.170** | 0/6 |

### 1. Our VA is NOT buggy -- it is the MORE accurate of the two VAs

Ours beats gllvm's on **3/3 paired seeds** (0.314/0.283/0.250 vs 0.357/0.342/0.361), a 21%
median improvement. Stage 7's KL verification (direct-algebra oracle to 2.26e-16, iid
reduction exactly 0.000e+00) is borne out END-TO-END, which it had never been before: every
prior check was of the objective, not of recovery.

### 2. gllvm's VA is trustworthy here -- the 68% figure does NOT transfer

0/6 degenerate, converged every time, `rel_frob` nowhere near the >10 threshold. The
68%-degenerate record is gllvm's **EVA**, from a different grid under different conditions.
Transferring it would have been the same error this project forbids elsewhere (Bernoulli-logit
evidence does not transfer to probit). It was a lead, not evidence.

### 3. CORRECTION: "VA is slower than Laplace at every tested n" does not hold here

Our VA is **2.4x FASTER than our own Laplace** at this cell (47 s vs 114 s). The 640-cell
grid's headline was a different configuration. The claim is configuration-dependent and was
repeated here without that qualifier; it should not be cited unqualified again.

### 4. The cost problem DECOMPOSES -- which makes it tractable

- **base VA, single tier: 60x slower than gllvm.** Target of the two unbuilt borrowings from
  the 2026-07-27 plan: #3 block-diagonal/low-rank variational covariance (gllvm
  `Ab.struct="blockdiagonal"`, `Ab.struct.rank=1`) and #4 two-stage warm-up (`diag.iter=1`).
  We hold a proof gllvm does not cite: **Design 106 Proposition 2** shows a zero off-diagonal
  block of `S` is **exactly optimal, not an approximation**, under stated conditions -- so we
  know both that it is safe and precisely where it stops being.
- **the structured phylo tier adds ~56x on top** (>3600 s, never finished, vs 47 s without
  it). This is OUR unique capability, gllvm cannot express it, and its cost has never been
  profiled. R3 fixed the OUTER problem (memory, constant in N); this lives in the INNER solve
  -- exactly where Proposition 2 applies, and where Stage 7 measured `nnz/dim` staying FLAT.
  Sparsity is right; wall-clock is not. That gap is the single most informative unopened box.
- **the n>=2500 wall remains unexplained** (the L-BFGS-B memory hypothesis was measured and
  REFUTED). Now diagnosable against a reference implementation that does not have it.

### 5. What this does to the campaign's verdict

The strong form -- "VA loses, drop Stages 3/5" -- rested on VA being both slower and no more
accurate. On this evidence it is MORE accurate than the mature competitor and FASTER than our
own Laplace in the base configuration. **That verdict is withdrawn.** The narrower, supported
statement: VA's cost problem is real, now decomposed, and has named unbuilt fixes; the
structured-tier question is gated on those, not on VA being a dead end.

---

## JOB 2f — EVA is NOT AVAILABLE for Ayumi's families, and both EVA records were off-target

Maintainer asked for EVA alongside VA. Measured, and the answer is structural:

> `gllvm::gllvm(..., method = "EVA")` -> **"Binomial distribution not yet supported with the
> EVA method."** Both logit and probit. gllvm's EVA cannot fit binomial at all.

**Consequence: neither EVA record on file applies to the north star.**

- Design 108 §2: *"gllvm's already-shipped EVA beats GH-VA on BOTH the objective (+23 to +126
  nats) and wall clock (2.5-20.5x) at every evaluable cell."* The qualifier **"evaluable"**
  was load-bearing and easy to read past. Not binomial.
- The 640-cell grid's **68% degenerate, all reporting converged**. Also on families EVA
  supports. Not binomial.

Both are true; neither is evidence about Ayumi's binomial columns, which are the gate. This
is the THIRD recorded number this session that did not transfer to the cell that matters
(after the EVA degeneracy rate, and the logit-regime "VA slower at every n"). The pattern is
not that the records are wrong -- it is that their **scope qualifiers get dropped on recall**.

Our own EVA is a Design 86 Gate-1 prototype: unexported, Codex-owned, cut from 0.6 to 0.7.
Not reachable from this lane without a lane reassignment, so it is untested here.

### Four-way result (4 seeds, identical single-tier model, identical data, planted truth)

| engine | median time | median `rel_frob` |
|---|---|---|
| gllvm VA | **0.70 s** | 0.359 |
| **our VA** | 45.6 s | **0.298** |
| gllvm EVA | — | **N/A — binomial unsupported** |
| our Laplace | 114.5 s | **0.170** |

Ours beats gllvm's VA on **4/4** seeds. 65x slower, consistently ~17-21% more accurate.

### A vacuous statistic I nearly reported

The run printed `EVA degenerate (>10): 0/4`. That zero came from every value being `NA`, not
from nothing degenerating -- a count over an all-NA column with no denominator check. It is
the same shape as the vacuous control gate caught earlier today. **Any rate computed with
`na.rm = TRUE` needs its denominator reported beside it**, or a fully-failed arm reads as a
clean one.

---

## CORRECTION to Job 2f (2026-08-03) — my EVA test was wrong, not EVA

The maintainer asked "wrong tests??" and was right. Commit `a66d3643` claims *"gllvm's EVA
cannot fit binomial at all -- logit or probit."* **That is FALSE.** Measured:

| call | result |
|---|---|
| EVA, Bernoulli (binary 0/1), logit, no `Ntrials` | **OK -- fits** |
| EVA, Bernoulli, **probit** | **OK -- fits** |
| EVA, binomial `Ntrials = 6` (what I tested) | ERROR: "Binomial distribution not yet supported" |

gllvm's EVA rejects **multi-trial binomial only**. It fits Bernoulli, including probit.

**How the error happened, because the chain matters.** I set `n_trials = 6` earlier in this
same session to dodge the silent Psi-drop that Bernoulli triggers in our Laplace arm. That fix
put every EVA call into the one configuration EVA refuses, and I read a narrow refusal as a
blanket incapability -- generalising from a single failed call without varying the parameter
that caused it. Exactly the shape of the `H = 11` and `n_starts = 2` false alarms earlier
today: an invalid argument of mine surfacing as a defect in the thing under test. Third
instance. The fix is not "be careful" -- it is **never conclude a capability is absent from
one failed call; vary the argument first** (the project's own rule: to check a capability is
present, USE it; a negative probe cannot prove absence).

### What this restores

1. **The EVA-for-probit arm (P0c) is TESTABLE** on Bernoulli-probit. It is not blocked.
2. **The 68% degeneracy record is back ON-target**, not off it. It was measured on
   Bernoulli-logit -- a real binomial case. My claim that "both EVA records were off-target"
   is withdrawn for that one; only the "every evaluable cell" claim keeps its caveat.
3. **A NEW question the maintainer's challenge exposes:** are Ayumi's binomial columns
   **Bernoulli or multi-trial?** If Bernoulli, EVA is available for her model. If multi-trial,
   EVA is unavailable regardless of how good it is. This was never checked and it gates P0c.

### What does NOT change

The 2026-07-31 misuse probe stands, and it was rigorous: it defaulted to "we are at fault",
checked the reconstruction byte-for-byte against gllvm's own `getLoadings()`, and still
concluded **GENUINE METHOD BEHAVIOUR** -- EVA's own objective prefers a runaway solution
(attenuation 8.8e+08) at -327.4 over the TRUE parameters at -618.6, by 291 nats, and MORE
restarts make it WORSE (n.init 5 -> 3.8e+08, 10 -> 6.3e+08) because gllvm selects the restart
with the best EVA objective and the degenerate mode has it.

That is the "surrogate, not a bound" property biting: a surrogate that is not a bound can
score a degenerate solution ABOVE truth. So EVA's risk is real and mechanistic -- but it is a
risk to be MEASURED at our dimensions, not a reason the arm cannot run.

---

## THE CAMPAIGN'S CORE MEASUREMENT — first structured two-tier run, and what it does NOT answer

Structured two-tier (198-node phylo tier), **gaussian**, N=150, T=10, q=1, 4 seeds, both arms
on the SAME data, scored against PLANTED TRUTH on the loadings estimand.

| | median time | tier-1 `rel_frob` | tier-2 `rel_frob` |
|---|---|---|---|
| VA (structured, `profile_variational=TRUE`) | **10.7 s** | 0.769 | **NOT EXTRACTED** |
| Laplace | 18.7 s | **0.382** | 1.182 |

### What it shows

**Laplace recovers tier 1 about 2x better than VA** (0.382 vs 0.769), consistent across all
four seeds. VA is FASTER here (10.7 s vs 18.7 s) — the first structured fit where VA beats
Laplace on time, which is `profile_variational = TRUE` working as R3 designed.

### TWO REASONS THIS IS NOT THE CAMPAIGN'S ANSWER — stated so nobody cites it as one

1. **VA's tier-2 was never extracted.** The script pulled `report$Lambda`, which is tier 1's
   loadings, and no phylo-tier equivalent. So the actual headline question — *does structured
   VA recover the PHYLOGENETIC tier better than Laplace* — has **no VA number**. That is a
   defect in the measurement script, not a property of the engines, and it must be fixed before
   this cell is re-run.
2. **N=150 is below the size where tier 2 is interpretable at all.** Laplace's tier-2
   `rel_frob` is **1.182** (range 0.79-2.73) — error exceeding the truth's own norm, i.e.
   essentially no recovery. That matches the corrected control curve, where tier 2 was still
   0.38-0.43 at **N=1000**. **This cell FAILS the informativeness precondition** recorded above:
   a cell where no arm recovers tier 2 cannot discriminate the engines, and `d ~ 0` there is not
   evidence of equivalence.

### Scope limit that was designed in, not discovered

**Gaussian, not Ayumi's probit.** Gaussian is the one family whose VA expectation is EXACT, so
this isolates the structured-tier question from the GH cost that blocks probit — now measured
at **8.8x on this exact model** (structured tier, `profile=TRUE`, N=100/T=8: gaussian 22.8 s vs
binomial-probit 199.7 s).

### Reconciliation of the >3600 s claim — RESOLVED, nothing retracted

The earlier ">3600 s with `profile_variational = TRUE`" was **iteration count without an
iteration cap, compounded by GH** — not a failure of the profiled route. With `iter.max = 100`
both families finish. The profiler's `N^0.9` scaling was real. **Both prior measurements were
true; neither needed retracting.** They differed in the iteration cap and the family.

### Where that leaves the campaign

The structured-tier question remains **OPEN and unmeasured**. What is now known is that it is
*runnable*: the structural cost was the default `profile_variational = FALSE`, and with the
profiled route the gaussian structured fit takes ~11 s at N=150. The blockers are now (a) fix
the tier-2 extraction, and (b) reach an N where tier 2 is informative — which the control curve
puts well above 1000.

---

# THE CAMPAIGN'S ANSWER (2026-08-03) — VA does NOT recover the structured phylo tier

Structured two-tier (198-node phylo tier), **gaussian**, **N=1000**, T=10, q=1, 3 seeds, both
arms on the SAME data, BOTH tiers extracted, scored against PLANTED TRUTH (loadings estimand).

| seed | VA tier-1 | **VA tier-2** | LAP tier-1 | **LAP tier-2** |
|---|---|---|---|---|
| 1 | 0.747 | **16.89** | 0.186 | 0.704 |
| 2 | 0.783 | **48.68** | 0.087 | 0.543 |
| 3 | 0.839 | **1.000** | 0.094 | 0.540 |
| **median** | 0.783 | **16.89** | **0.094** | **0.543** |

## Verdict

**LAPLACE BETTER on both tiers.** Tier 1 by **8x**. Tier 2 — the phylogenetic tier, the
campaign's actual target — by **31x**.

And VA does not merely lose: it **FAILS on 3/3 seeds**. Two runaways (16.89, 48.68, both past
the `rel_frob > 10` degeneracy threshold) and one at exactly **1.000**, the signature of a
collapse to zero (`||0 - truth|| / ||truth|| = 1`). Runaway or collapse, never recovery.

## Verdict on Stages 3/5

The handover's own criterion: *"if VA ties or loses, ~7 days of Stages 3/5 come off the board."*
**VA loses decisively**, on the structured tier Design 72 named as its untested Phase 2.
**Stages 3/5 are NOT worth the 7 days on this evidence.**

## Four caveats that bound the claim

1. **Gaussian, not Ayumi's probit** — a DESIGNED scope limit, stated in the script, not
   discovered afterwards. Gaussian's VA expectation is exact, isolating the structured-tier
   question from probit's measured **8.8x** GH penalty on this same model.
2. **Three seeds.** Sufficient for a 31x gap and a 3/3 failure pattern; NOT sufficient for a
   rate, and no MCSE is claimed.
3. **Informativeness is MARGINAL.** Laplace's 0.543 sits just above the stipulated 0.5
   threshold, so this cell barely clears the precondition. That bounds fine discrimination; it
   does not threaten a 31x separation.
4. **This measures VA AS IT IS, not as it could be.** The degeneracy may be the same immaturity
   the speed arc addresses -- `n_starts = 1`, unrefined starting values, and an engine still
   missing its closed-form evaluator. **A mature VA could plausibly change this result.** That
   is precisely why the arc remains worth running despite a negative campaign verdict, and why
   this verdict must not be cited as "VA cannot do structured phylogenetics" -- only as "this
   engine, in this state, does not."

## What was fixed to get here

The earlier N=150 run had two defects, both recorded: VA's tier-2 was never extracted, and
N=150 sat below the informativeness threshold. Both are closed -- tier 2 now comes from the
harness's own `.d108_va_tier_sigma(par, layout, 3L, 4L, T)`, and N=1000 is the largest rung the
corrected control curve reached.

---

# TOTORO GRID (80 cells, 20 seeds) — the verdict WITH MCSE, and a correction

Run on Totoro, 40 cores. Structured two-tier, **gaussian**, N in {500,1000} x q in {1,2} x 20
seeds, T=10. Both arms same data, both tiers, planted truth, loadings estimand.
Results LOCAL (D-50).

## 1. THE PRIMARY FINDING — completion, not accuracy

| arm | cells returning a number |
|---|---|
| **VA** | **27/80 (34%)** |
| Laplace | **80/80 (100%)** |

**VA failed to return an estimate in two-thirds of the grid.** This is the most robust result
here — a completion rate over 80 cells, not an accuracy margin over a handful.

**BUT it is also the most attackable**, and is under adversarial review: if the failures come
from `n_starts = 1`, an iteration cap, or unrefined starting values, this measures the HARNESS,
not the estimator. Do not cite it until that returns.

## 2. Paired contrast `d = VA - Laplace`, tier 2, WITH MCSE

| cell | n | mean d | MCSE | 2*MCSE band | verdict |
|---|---:|---:|---:|---|---|
| N=500 q=1 | 8 | 2.302 | 1.149 | [0.004, 4.600] | **Laplace better** |
| N=500 q=2 | 7 | 10.052 | 2.792 | [4.468, 15.637] | **Laplace better** |
| N=1000 q=1 | 6 | 10.159 | 5.347 | [-0.536, 20.853] | **INDETERMINATE** |
| N=1000 q=2 | 6 | 23.544 | 11.820 | [-0.095, 47.184] | **INDETERMINATE** |

### CORRECTION to the 3-seed verdict recorded above

The earlier entry called this **"Laplace better 31x, decisive"**. **With MCSE, two of four cells
are INDETERMINATE** — the mean differences at N=1000 are large but so is the variance, because
VA's runaways inflate it. **The strong form is withdrawn.**

Worse for the claim: **the two cells that DO exclude zero are both at N=500**, the *smaller*
size — the opposite of what "at realistic size" requires.

Medians are cleaner (VA 1.450 / 3.860 / 8.520 / 10.816 vs Laplace 0.737 / 0.561 / 0.764 /
0.614 — Laplace better in all four), but a median is not what the 2*MCSE band was computed on.
Which summary is right for a heavy-tailed paired contrast is under adversarial review.

## 3. VA tier-2 degeneracy (`rel_frob > 10`), Wilson intervals

| cell | k/n | Wilson 95% |
|---|---|---|
| N=500 q=1 | 1/8 | [0.02, 0.47] |
| N=500 q=2 | 2/7 | [0.08, 0.64] |
| N=1000 q=1 | 2/6 | [0.10, 0.70] |
| N=1000 q=2 | 3/6 | [0.19, 0.81] |

Rising with N and with q, but **the intervals are wide and overlap** — this is not a precise
rate and must not be quoted as one.

## 4. Informativeness — the cells FAIL the precondition

Laplace's tier-2 medians are **0.561-0.764**, against the stipulated **0.5** threshold. So by
the precondition recorded earlier in this file, **no arm achieves acceptable tier-2 recovery in
any cell**. That bounds what the comparison can support and is a live question for the review:
does it invalidate the contrast, or only limit it?

## 5. Standing scope limits

**Gaussian**, not Ayumi's probit (probit adds a measured 8.8x GH penalty). **T=10**, not 20-30.
**N <= 1000**, not 5397. Whatever the verdict, it is a verdict about *this* regime.

---

# ⛔ RETRACTION — the campaign verdict DOES NOT HOLD (adversarial review, 2026-08-03)

Full review: `dev/design108-recovery/ADVERSARIAL-REVIEW.md`. **Everything above claiming a
VA-vs-Laplace comparison is RETRACTED.** The measurement was invalid.

## The error: the two arms fitted DIFFERENT MODELS

The DGP is **binomial-probit** (`dgp.R:167`). The Laplace arm fitted that correctly —
`binomial(link="probit")` on raw `y` (`harness.R:404`), achievable floor **0**. But the campaign
script **inlined** the VA arm as `family="gaussian_anchor", link="identity"` on
`scale(sim$data$y)` (`/tmp/totoro_grid.R:15,19-23`), **bypassing the harness's own
`.d108_fit_va()`**, which correctly uses `binomial_probit` on raw `y` (`harness.R:302-303`).

A gaussian-identity fit on standardised counts targets `D Sigma D` with per-trait attenuation
`k_t` in **[0.37, 0.77]** — a **2.08x spread**, so not a correctable scalar.

**Measured VA oracle floor (tier 2): 0.709 / 0.772 / 0.717 / 0.782**, against Laplace's
*observed* 0.561-0.764. **In 3 of 4 cells a PERFECT VA loses anyway.** The test could not
return "VA wins".

**Tier 1 REVERSES.** VA's excess-over-floor is 0.034-0.096 against Laplace's 0.101-0.186 —
**smaller in all four cells**. So "Laplace better on tier 1 by 8x" is an artefact of the
scoring, not a result.

**How it happened, recorded because the lesson is the point:** the gaussian choice was made
deliberately, to isolate the structured-tier question from probit's GH cost. That reasoning was
sound. What was NOT checked is that changing the VA arm's family while leaving the Laplace arm
on probit makes the two arms incommensurable. It is the same apples-to-oranges failure this
file records catching in the Bernoulli-Psi case — committed by the same author, later the same
day, in the opposite direction.

## The 34% completion rate is a HARNESS property, NOT a VA property

The grid ran `mclapply(mc.cores = 40L)` calling `.va_r3_fit()` directly, **never invoking the
DLL-seeding protocol the harness documents as required for every worker**
(`harness.R:103-110`, `.d108_build_va_r3_dll_stash` / `.d108_seed_va_r3_dll`). Laplace used the
already-loaded main DLL — hence 80/80.

Reproduced: N=500 q=1 seeds 2, 3, 4 are **NA in the campaign CSV but all complete
single-threaded** (va_t2 = 1.000, 9.193, 16.535), and seed 1 reproduces the campaign value
exactly, confirming a faithful replica. Failures are **seed-random** and the completion rate is
**flat in size** (0.375 at N=500 vs 0.300 at N=1000, Fisher **p=0.637**; q **p=1.0**) — which
rules out OOM/time and fits a startup race. *The mechanism is inferred; the reproduction is not.*

## Attacks that FAILED — recorded so the review is not read as one-sided

- **Selection bias: absent.** Wilcoxon **p=0.863** on Laplace performance, survived vs failed cells.
- **Median/sign test STRENGTHENS the measured direction** — 26/27, **p=4.17e-07**.
- **`n_starts=1` is NOT the culprit.** `n_starts=4` reproduces the same numbers at 4x the cost,
  with the health gate rejecting the fits even at four starts.
- **PR #919 raises no objection.** It corrects a claim about `Lambda`'s diagonal; `Lambda Lambda'`
  is sign/rotation-invariant, so the Frobenius comparison is sound.

## What CAN be said — the narrowed claim, publishable as written

> In a mixed-family pilot (N <= 1000, T = 10, q in {1,2}, 20 seeds) the VA prototype produced
> degenerate estimates of the structured phylogenetic tier in every fit that returned — nine of
> 27 collapsed to zero and the remaining 18 exceeded the error of estimating nothing, a pattern
> that multi-start does not repair and that the engine's own health gate rejects — so the
> prototype does not currently recover a structured phylo tier. The pilot does **not**, however,
> support a comparison against the Laplace engine: the two arms were fitted under different
> response models with different achievable error floors (so a perfect VA would have "lost" in
> three of four cells), and the VA arm's non-completions trace to an unseeded TMB DLL under a
> 40-way fork rather than to the estimator.

## Consequence for Stages 3/5

**The ~7 days CANNOT be retired on this evidence** — that would be retiring an arc on a
confound. Nor does the evidence clear VA. **The corrected re-run is ~1 day, not 7:** use
`.d108_fit_va()` so both arms fit the same model, seed the DLL per worker, and log failure
REASONS rather than `NA`.

---

## Second adversarial panel (same day) — five more defects, and one change to the re-run

A later session re-dispatched the review as **five fresh adversaries in independent contexts**
(the original had not yet landed). All five returned REFUTED and **converged with the retraction
above** — the scale mismatch was found independently by two of them, the collapse-scoring defect
by two others. Full detail: `ADVERSARIAL-REVIEW.md` **§APPENDIX A1–A9**. Only the items that
change what someone should *do* are repeated here.

**① The re-run should also raise `T`.** The retraction's fix list (same model, seed the DLL, log
reasons) is necessary but not sufficient — at T=10 the cells fail the informativeness
precondition. **They are not doomed to:** the campaign's own `job1b_floor_corrected.rds` — same
DGP, same estimand, same N, **T=20** — gives tier-2 medians **0.460 / 0.416 / 0.382 / 0.449**,
clearing 0.5 in **all four cells**. `§5`'s scope-limit line ("T=10, not 20–30") did not notice
that T=20 is exactly where its own control cleared the gate `§4` declares unmet. **Add "raise T"
to the re-run spec.** (A4)

**② The "~7 days" figure is itself wrong by 3–5×.** The retraction says it cannot be retired;
stronger — it was never 7 days. `docs/design/108-va-parity-programme.md:195,197` costs Stage 3 at
**0.5 d** and Stage 5 at **1–2 d** — **1.5–2.5 d total** — and the handover that states "~7 days"
sizes both stages the same way eight lines later. No derivation of 7 exists anywhere
(`git log --all -S`, `docs/`, `~/.claude/plans/`). Stage 3 is 0.5 d and EXACT. (A5)

**③ Two analyses the PROTOCOL mandated were not run**, and each flips the INDETERMINATE cells
independently of the scale problem: the per-cell **sign test** (`PROTOCOL.md:664`) and **`d_prop`**
rather than raw `d` (`PROTOCOL.md:894` — "**not** `SD(d)` in raw `rel_frob` units"). On `d_prop`
all four bands exclude zero. (A1)

**④ The 2·MCSE band was also mis-calibrated.** At n=6 it has **0.898** coverage, not 0.95. Under
the correct `t(7,.975)`, N=500 q=1 — the cell reported as "Laplace better" on a lower bound of
**0.004** — becomes **[−0.415, 5.019], including zero**. A false positive, in the opposite
direction from the false negatives. (A2)

**⑤ Housekeeping with teeth.** The 0.5 gate's cited ancestry is **false** —
`PROTOCOL.md:69-73` says it is implemented at `analyse-silent-divergence.R:78-85`; that file has
no `rel_frob` gate and `grep -c "0\.5"` returns 0 (A3). The driver `/tmp/totoro_grid.R` is
**untracked scratch and not in the repo**, so no headline number is reproducible from the
worktree — **commit it** (A6). `.d108_positive_control_gate()` filters the *total* columns while
the analysis reads the *loadings* columns, so the anti-vacuity fix at `harness.R:506-517` is not
consumed by the gate it was written for (A7). The medians line mixes n=6–8 VA against n=20
Laplace and is in a different cell order from the table above it (A8).

**Verified CLEAN and not worth re-auditing** (A9): the DGP's `Ψ_phy ⊗ A` Kronecker structure (the
old iid bug has **not** recurred — matches `ape::vcv(corr=TRUE)` to 4.7e-14); all 16 `score()`
pairings inside `run_cell()`; the tier index arithmetic `(3L, 4L)`; and the PR #919 question,
re-derived independently — `ΛΛ'` is invariant under sign flip and rotation, difference **exactly
0** over all `2^q` modes.
