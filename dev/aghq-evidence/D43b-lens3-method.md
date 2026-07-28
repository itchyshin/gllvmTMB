# D-43b panel — LENS 3: STATISTICAL SOUNDNESS

Fresh reviewer, no involvement in producing this arc. Worktree
`/private/tmp/gllvmtmb-arc0-identifiability`, branch `claude/aghq-engine-20260728`, PR #801
(OPEN, not merged). Default verdict is NOT-DONE; only evidence moves it.

Everything below is recomputed from the committed CSVs. `git status dev/aghq-evidence/` is
clean, so the files I read are the files that were committed at `e35dfb79` / `4d551817` /
`1d6a82af`.

The question I am answering is not "did they work hard" — they plainly did, and the
self-criticism in `24-coverage-cell.R:1-42` and in the `decisions.md` caveats is better than
most published simulation studies. The question is whether **a hostile methods referee would
accept the four numbered claims as stated**. He would not, and four of the reasons are ones
this arc has the data to see and did not report.

---

## 0. What reproduces and what does not

| claim | quantity | reproduces? |
|---|---|---|
| (1) | Laplace binomial bias 0.347/0.176/0.113/0.038 at T=2/4/6/12 | **YES**, exactly |
| (1) | poisson AGHQ correction +0.006/−0.002/0.000/0.000 | **YES**, exactly |
| (2) | Laplace diag coverage 0.776/0.861/0.825/0.664 | **YES**, exactly |
| (3) | aghq_ridge diag 0.961/0.957/0.949/0.951 | **only on an undisclosed complete-case pool** |
| (3) | aghq_ridge offdiag 0.959/0.962/0.959/0.952 | **only on an undisclosed complete-case pool** |
| (4) | divergent rate 47% → 73%; ridge arms 0% | **YES**, exactly (7/15, 11/15, 0/15, 0/15) |

So the arithmetic is honest. The problems are inferential, and they are severe.

---

## 1. THE TRUTH-REDRAW (the question I was told is the most important — and it is)

### 1a. The mechanism is exactly what the caveat feared, and it is analytically predictable

The coverage DGP (`24-coverage-cell.R:53-59`) draws
`Lt <- matrix(rnorm(p*q, 0, lam_sd), p, q)` fresh every seed, `lam_sd = 1`
(`24-coverage-cell.R:67`). The ridge (`R/fit-multi.R:4876-4884`) adds
`0.5 * sum(theta_rr_B^2) / tau^2` with `tau = 2` (`R/gllvmTMB.R:1224`) — an iid
`N(0, tau^2 = 4)` prior on **exactly the free parameters the truth is drawn for**, differing
only by a factor 2 in scale.

Critically, the interval is a **MAP point with ML curvature**. `TMB::sdreport()` is called at
`R/fit-multi.R:5554` on `obj`, which for the AGHQ arms has been swapped to `obj_aghq` — the
**unpenalised** quadrature object (`R/fit-multi.R:5470-5474`). The penalty lives only in the
`fn`/`gr` wrapper inside `run_one()` (`R/fit-multi.R:4876-4884`) and never enters the reported
Hessian. Lens 3 of the previous panel said exactly this; it has not been fixed, it has been
measured around.

That combination has a closed form. Take the scalar caricature: truth `θ ~ N(0, s²)`, MLE
`θ̂ ~ N(θ, σ²)`, MAP `θ̃ = cθ̂` with `c = τ²/(τ²+σ²)`, reported SE `= σ`. Then

```
θ̃ − θ  ~  N(0, [σ² + r⁴s²] / (1+r²)²),      r² = σ²/τ²
```

marginalised over the redraw, and the interval `θ̃ ± zσ` **over-covers** whenever

```
        s²  <  2τ² + σ²
```

At `τ = 2` this is `s < 2.83` for any `σ`. **The run was executed at `s = 1`.** The design
therefore sits deep inside the region where this estimator is *guaranteed* to over-cover, for
reasons that have nothing to do with AGHQ, the quadrature, or the SE being right. Nominal
coverage here is not a finding; it is a corollary of the design.

### 1b. The empirical signature is unmistakable

Coverage of the SHIPPED arm (`aghq_ridge`) stratified by the magnitude of the redrawn truth,
recomputed from `24-coverage-inc.csv` on the authors' own pool:

```
diag,  aghq_ridge, coverage by |true Sigma_tt| quintile
                     n=100  n=200  n=400  n=1600
 [0.000, 0.418]      0.867  0.873  0.906  0.942
 (0.418, 0.947]      0.974  0.983  0.974  0.966
 (0.947, 1.84 ]      0.992  0.992  0.950  0.963
 (1.84 , 3.11 ]      0.996  0.983  0.958  0.954
 (3.11 , 17.5 ]      0.979  0.954  0.958  0.933

offdiag, aghq_ridge
 [0.001, 0.206]      0.998  0.993  0.986  0.980
 (0.206, 0.488]      0.979  0.980  0.969  0.962
 (0.488, 0.880]      0.949  0.953  0.941  0.938
 (0.880, 1.563]      0.937  0.955  0.945  0.950
 (1.563, 7.16 ]      0.933  0.937  0.955  0.936
```

The headline "0.961" at `n=100` is the average of **0.867 and 0.996**. The off-diagonal
"0.959" is the average of **0.998 (near the prior mean) and 0.933 (in the tail)** — the
textbook monotone shrinkage signature: a near-zero covariance is covered essentially always
because the shrunken interval straddles the prior mean.

**There is no `n` and no true `Sigma` at which this procedure delivers 0.95.** It delivers
0.87–0.99 depending on where the truth is, and the redraw distribution is what averages that
to 0.95. A referee asked to accept "reaches NOMINAL coverage" will ask for coverage at a fixed
parameter, and this table is what he will be shown.

### 1c. Quantified: the nominal result is a knife-edge at `lam_sd = 1`

Importance-reweighting the *same fitted intervals* to a different truth scale `s` (diagonal
truth is `s²·χ²₂`, i.e. `Exp(mean 2s²)`; this holds the conditional coverage function fixed and
changes only the truth distribution):

```
aghq_ridge, diag coverage under truth scale s
   s     n=100  n=200  n=400  n=1600
  0.5    0.906  0.912  0.925  0.952
  1.0    0.962  0.957  0.949  0.952     <- the run as executed
  1.5    0.971  0.964  0.953  0.901
  3.0    0.980  0.976  0.959  0.669
```

Halve the true loading scale and the shipped arm under-covers by 3–4 points at every `n ≤ 400`.
Treble it — the `lam_sd = 3` condition that the 7550-fit factorial *does* contain but that has
no coverage cell — and `n = 1600` collapses to 0.67, right where the analytic boundary
`s = 2.83` predicts. (Caveat, mine not theirs: minimum effective sample size across reweighted
cells is 11, so the `s = 3` column is a weak extrapolation and the refits would themselves
differ. The `s = 0.5` and `s = 1.5` columns are better supported and already make the point.)

### 1d. Is the comparison to Laplace still valid?

**Partly, and only in one direction.** Both arms face the same DGP, so the *contrast* is not
meaningless. But the DGP is not neutral between them: it rewards shrinkage toward zero, and
only the ridge arms shrink. Reading the same stratified table for the shipped default:

```
diag, laplace, coverage by |true Sigma_tt| quintile
 lowest  quintile:  0.817  0.863  0.887  0.879
 highest quintile:  0.529  0.589  0.473  0.241
```

Laplace's collapse is concentrated entirely in the large-truth region and worsens with `n`
there. That **is** a real signal and it is not an artefact of the redraw — it is the redraw
that made it *visible*, by supplying large-truth cells. So the Laplace-vs-AGHQ contrast
survives as a **bias diagnostic**. What does not survive is the absolute statement that the
AGHQ+ridge arm *is calibrated*.

**Verdict on question 1: the DGP is structurally favourable to the ridge arms specifically,
the arc's own caveat (a) understates it, and claim (3) as worded is not supportable.**

---

## 2. THE SE ROUTE — is "SE/SD → 0 is mechanical evidence of bias" correct?

**The argument is correct in form, but the evidence offered for it does not establish it, and
the conclusion drawn from it is too strong.**

*Correct in form.* If `θ̂ → g(θ) ≠ θ`, then under the redraw `err = θ̂ − θ → g(θ) − θ`, a
deterministic function of the redrawn truth, so `sd(err)` tends to a non-zero constant while
`SE → 0`. The ratio must go to zero. Note this holds **only because the truth is redrawn**;
at a fixed truth a biased estimator's `sd(err)` shrinks with `n` like the SE and the ratio
stays near 1. So the diagnostic the authors invoke is an artefact of the same design feature
that inflates their coverage — it cannot be used as independent support.

*Not established by their evidence.* Their quoted ratios (`decisions.md` §3: laplace
0.24/0.11/0.07/0.02) are computed on raw `est − truth`, which in this run is dominated by
runaway fits: I get `sd(err) = 2524` at `n=100` and `321` at `n=1600` for the laplace diagonal.
A ratio of 0.02 against a standard deviation of 321 is uninterpretable; it distinguishes
nothing.

*So I derived it properly.* Stratifying finely on the truth (deciles of `log Sigma_tt`) removes
the bias-spread contribution and isolates SE calibration. On the **log scale the CI actually
uses** (`22-sigma-se-delta.R:106-110`):

```
                 median within-stratum quantities, diagonal
 arm            n     bias_w     sd_w      SE     SE/SD_w   |bias|/SE
 laplace       100    -0.308    0.995    0.959     1.020      0.465
 laplace       200    -0.184    0.625    0.656     1.102      0.511
 laplace       400    -0.197    0.519    0.461     0.973      0.750
 laplace      1600    -0.260    0.349    0.227     0.716      1.163
 aghq          100    -0.020    1.316    1.196     1.006      0.160
 aghq         1600     0.025    0.367    0.333     0.991      0.112
 aghq_ridge    100     0.297    0.889    1.060     1.260      0.368
 aghq_ridge   1600     0.018    0.336    0.327     1.024      0.127
```

**The delta SE is not broken on the Laplace arm.** `SE/SD_w` is 1.02 / 1.10 / 0.97 at
`n = 100/200/400`. The within-stratum bias is persistent and does not shrink
(−0.31 / −0.18 / −0.20 / −0.26 in log units) while the SE does, so `|bias|/SE` grows
0.47 → 1.16. That is the "consistent for the wrong value" signature, and it survives the test
I built specifically to kill it.

**So claim (2) survives — on evidence this arc did not produce.** I credit the substance and
withhold credit for the argument: the stated defence (SE/sd(err) = 0.02) is a rationalisation
that happens to point at a true conclusion.

**But the sole-cause attribution is wrong at `n = 1600`.** There `SE/SD_w = 0.716` — the SE
is ~28% too small. Decomposing (normal approximation, `bias = −0.260`, `sd_w = 0.349`,
`se = 0.227`):

```
 both defects            → predicted coverage 0.680   (observed 0.664 — good match)
 bias only, correct width → 0.884
 width only, no bias      → 0.798
```

Neither dominates. Claim (2)'s "the signature of an estimator consistent for the WRONG value"
attributes the whole of 0.664 to displacement; with a correctly-sized interval and the same
bias it would be 0.88. The claim needs "and a modestly undersized SE at large n."

---

## 3. Claim (2)'s "worse as n grows" — logic and arithmetic

Arithmetic reproduces (0.7758 / 0.8608 / 0.8250 / 0.6642) but the sequence **is not
monotone**: `n = 100 → 200` improves by 8.5 points. Two of three steps move against the
claim's shape; the pattern is "flat at 0.78–0.86 through `n = 400`, then a collapse at 1600."
"Worse as n grows" rests on a single 4× jump in `n` at one end of the ladder.

Alternative explanations tested and their disposition:

* *Delta SE degrading with n* — **partly true and material** (§2: `SE/SD_w` 0.97 → 0.72 from
  `n=400` to `n=1600`; accounts for roughly the 0.88 → 0.68 difference). Not disclosed.
* *Divergent fits entering the pool differently by n* — **ruled out for Laplace.** Non-finite-SE
  entry rates on the laplace arm are 0.0008 / 0 / 0.0008 / 0 (diag); the pool composition is
  effectively constant across `n`.
* *Genuine bias* — **confirmed** by §2's within-stratum decomposition, and localised by §1d to
  the large-truth region (top quintile 0.529 → 0.241).

Net: the *direction* of claim (2) is real and it is the most defensible thing in the arc. Its
*wording* ("worse as n grows", bias as sole cause) is not what the data show.

---

## 4. Claim (4) — the paired 2×2

Full 2×2, `20-shipped4-inc.csv`, **15 seeds**, paired on shared seeds. Effect on
`|frob_rat − 1|` (negative = improvement), with paired 95% CIs:

```
 n = 100
  QUADRATURE at tau=Inf   +0.555  [+0.170, +0.940]   p_t=0.008   HARMFUL
  QUADRATURE at tau=2     +0.032  [−0.102, +0.166]   p_t=0.615   indistinguishable from 0
  RIDGE at k=1           −10.350  [−17.36, −3.34 ]   p_t=0.007   helpful
  RIDGE at k=9           −10.873  [−17.59, −4.16 ]   p_t=0.004   helpful
 n = 1600
  QUADRATURE at tau=Inf   −0.023  [−0.144, +0.097]   p_t=0.685   indistinguishable
  QUADRATURE at tau=2     +0.285  [−0.611, +1.182]   p_t=0.506   indistinguishable
```

The quadrature's marginal contribution **is indistinguishable from zero at both `n`, at the
shipped `tau = 2`**, and is significantly *harmful* at `tau = Inf` at `n = 100`. The previous
lens 3 found the same on prototype data; it reproduces on the shipped engine.

The quoted headline statistic is weaker than the paired test: 47% → 73% is 7/15 vs 11/15, and
**McNemar on the paired table gives p = 0.134**. So the specific number claim (4) cites is not
statistically distinguishable; only the continuous paired metric supports harm.

---

## 5. Is the divergence metric still circular? — **YES, and the circularity is exact**

The penalty is `0.5·Σ theta_rr_B² / τ² = 0.5·‖Λ̂‖_F² / τ² = 0.5·tr(Σ̂)/τ²`
(`R/fit-multi.R:4879-4884`; the identity is noted at `R/fit-multi.R:4871-4873`). The divergence
metric thresholds `‖Λ̂‖_F/‖Λ‖_F > 2`. The penalty's objective **is** the metric's argument. A
term that charges `‖Λ̂‖_F²` driving `P(‖Λ̂‖_F large)` to 0 is not a finding. This is worse than
"correlated with"; it is the same functional. The continuous `|frob_rat − 1|` metric used in §4
inherits the problem at small `n`, where the unpenalised estimate is biased *upward* (the arc's
own account), so any downward shrinkage improves it mechanically.

**Does claim (4) survive?** Its *attribution* does, but only on evidence outside the circle.
I re-ran the paired 2×2 on `rho_absd` — mean absolute correlation error, which the penalty does
not directly minimise:

```
 n = 100 (15 seeds)         mean effect       95% CI            p
  QUADRATURE at tau=Inf      −0.0195   [−0.0465, +0.0075]     0.143
  QUADRATURE at tau=2        −0.0084   [−0.0259, +0.0091]     0.319
  RIDGE at k=1               −0.0468   [−0.0816, −0.0119]     0.012
  RIDGE at k=9               −0.0357   [−0.0681, −0.0033]     0.033
```

On a non-circular metric the ridge helps and the quadrature does not. So **claim (4)'s
substance holds**, but the evidence the claim actually cites (the 47%→73%/0% divergence rates)
does not support it, and a referee will say so.

Two further notes: at `n = 1600` **all four arms** have identical divergence (0.067), so "both
ridge arms reach 0%" is a small-`n`-only statement (the claim does scope it correctly); and at
`n = 1600` the quadrature is *worse* on `rho_absd` (+0.019, +0.013), which sits awkwardly beside
the arc's separate large-`n` narrative.

---

## 6. Two defects the arc did not report, which are individually disqualifying

### 6a. Claim (3)'s numbers exist only on an undisclosed complete-case pool

`decisions.md` states: *"All 3199 fits returned an interval — availability 100%, so no
missingness correction was needed."* At the **fit** level that is true (all 3199 rows have
`status == "ok"`). At the **entry** level — which is the unit coverage is computed on — it is
false, and the missingness is strongly arm-dependent:

```
fraction of Sigma entries with a non-finite SE (no interval), diagonal
       aghq   aghq_ridge   laplace   laplace_ridge
 100  0.0850    0.0183     0.0008       0.0175
 200  0.0567    0.0117     0.0000       0.0050
 400  0.0433    0.0142     0.0008       0.0075
1600  0.0050    0.0025     0.0000       0.0000
```

The AGHQ arms lose 20–100× more entries than the shipped default. `sigma_se_delta()` returns
`NA` when the delta variance is non-finite or negative (`22-sigma-se-delta.R:97`) — i.e.
precisely at near-singular Hessians, where coverage would be worst. That is **informative**
missingness, and dropping it favours the arm that drops more.

Two conventions, two answers:

```
aghq_ridge, diagonal            n=100   n=200   n=400   n=1600
 complete-case (the quoted)     0.962   0.957   0.949   0.951
 refusal counted as non-cover   0.944   0.946   0.936   0.949
aghq_ridge, off-diagonal
 complete-case (the quoted)     0.959   0.963   0.959   0.953
 refusal counted as non-cover   0.934   0.952   0.947   0.951
```

Note also that the second row is what the CSV's own `covered` column already computes
(`covered <- is.finite(lo) & is.finite(hi) & ...`, `24-coverage-cell.R:92-93`) — the script
writes the conservative answer to disk and the decision entry reports the permissive one,
without saying a filter was applied.

**And under the project's own precedent this fails either way.** The 2026-07-19 B3b decision
withheld a certificate at 0.9486–0.9529 because the 2·MCSE lower bands were below 0.95. Seed-
clustered 2·MCSE lower bands here (200 seeds):

```
aghq_ridge diag:     0.926  0.930  0.916  0.934
aghq_ridge offdiag:  0.919  0.940  0.935  0.937
```

**Every one of the eight is below 0.95.** By the repo's own standing rule, claim (3) is
withheld before any of the above is considered.

### 6b. Claim (1)'s poisson "correctness control" is not a control — AGHQ never moved

This is the finding I would lead a referee report with. Claim (1) rests the correctness case on
poisson: *"AGHQ (fully active, `aghq_used` TRUE on 100% of fits) correctly changes the answer by
+0.006/−0.002/0.000/0.000."* Per-seed, on the exact slice the claim is quoted from
(`q=1, lam_sd=1, n=1600`):

```
fraction of seeds where |frob_rat(aghq) − frob_rat(laplace)| < 1e-8
   T =        2       4       6      12
 poisson    0.267   0.600   0.733   1.000
 binomial   0.000   0.000   0.000   0.000
```

**At T = 12, 15 of 15 poisson AGHQ fits return the Laplace answer bit-for-bit.** At T = 6, 11
of 15. Across the whole factorial the poisson figures are 0.215 / 0.367 / 0.615 / 0.878.
The AGHQ adaptation loop stalls (`R/fit-multi.R:5379-5383`, "stalled (no honest descent at cap
1 after backtracking)") and returns `par_best`, which is still the Laplace warm start
(`R/fit-multi.R:5148`, `aghq_starts[[1]] = opt$par`). `aghq_info$used` is set whenever the
object was swapped in (`R/fit-multi.R:5476`), **not** when the parameters moved — so
"`aghq_used` TRUE on 100% of fits" is true and evidentially empty.

The claim's own rhetoric refutes it. It rejects Gaussian exactness as a control because *"a
Gaussian integrand IS the GH kernel after adaptation, so any correctly-normalised rule
reproduces it and AGHQ is effectively inactive."* Here AGHQ is *demonstrably* inactive —
identical output to 8+ digits — and for a worse reason: an optimiser stall rather than a
mathematical identity. A control in which the treatment arm returns the control arm's numbers
unchanged is not a stronger control than Gaussian exactness; it is not a control at all.

### 6c. The O(1/T) law holds in one cell of the 7550 and not in the others

`bias × T` should be constant under `O(1/T)`. Binomial / laplace / q=1, medians of 15 seeds:

```
 lam_sd=0.5 n=1600 : 0.574  0.304  0.536  0.397      not constant (clean large-n cell)
 lam_sd=1   n= 400 : 0.428  0.610  0.608 −0.009      not constant
 lam_sd=1   n=1600 : 0.694  0.705  0.679  0.460      constant for T=2,4,6  <- THE QUOTED CELL
 lam_sd=3   n=1600 : 0.680 −16.4  −10.2  −0.260      runaway-dominated
```

The law is quoted from `(binomial, q=1, lam_sd=1, n=1600)`. The `lam_sd = 3` cells are fairly
excused as runaway-dominated, and the small-`n` cells by the arc's own noise-masking argument —
but `lam_sd = 0.5, n = 1600` is a *clean, large-`n`* cell in which `bias × T` is non-monotone and
not constant. Claim (1) states the law as a property of Laplace; the arc's own factorial
contains the cells that show it is a property of one condition.

### 6d. The "7550 + 3199 fits" framing overstates the base for claims (1) and (4)

The claim opens by attaching 10,749 fits to all four numbered findings. Claim (1)'s headline
ladder is **120 fits** (15 seeds × 4 arms × 2 families at one `(q, lam_sd, n)`); claim (4) is
**120 fits** (15 seeds × 4 arms × 2 `n`), from which two 15-seed proportions are quoted. Only
claim (3) draws on a large `N`. A referee reading "7550 + 3199" and then finding a 15-seed
McNemar underneath will not be charitable about the rest.

---

## 7. What I am *not* objecting to

Recording these so the arc gets credit where it is due, and so a re-run does not over-correct:

* Claim (2)'s **direction and mechanism** are real and survive an adversarial test the arc did
  not run (§2). This is a genuine, consequential finding about the shipped default.
* Claim (4)'s **attribution** survives on a non-circular metric (§5), even though the cited
  statistic does not.
* Claim (1)'s **binomial** ladder reproduces exactly and the 1/T fit within its cell is tight
  (predicted 0.174/0.116/0.058 vs observed 0.176/0.113/0.038).
* Nothing is exported; Laplace remains the default; PR #801 is unmerged. The *packaging* half
  of the claim's first sentence is accurate and I verified it.
* `sigma_se_delta()`'s index-map guard (`22-sigma-se-delta.R:79-83`) and the log-scale choice
  for the variance (`22-sigma-se-delta.R:23-30`) are both correct calls, and the log scale is
  load-bearing — a raw-variance Wald would have manufactured undercoverage.

---

## 8. Disposition

| claim | verdict |
|---|---|
| (1) binomial O(1/T) ladder | **NOT SUPPORTED AS STATED** — holds in one cell of the factorial (§6c) |
| (1) poisson null control | **FAILS** — AGHQ returns the Laplace answer bit-for-bit on 100% of T=12 fits (§6b) |
| (2) shipped default under-covers | **SUPPORTED IN DIRECTION**, over-attributed to bias, "worse as n grows" non-monotone (§2, §3) |
| (3) AGHQ+ridge reaches nominal at every n | **NOT SUPPORTED** — complete-case artefact (§6a), fails the repo's own 2·MCSE rule (§6a), and is a prior-averaging artefact with conditional coverage 0.87–0.99 (§1) |
| (4) the ridge not the quadrature | **SUPPORTED IN SUBSTANCE**, on evidence other than the circular metric it cites (§4, §5) |

Claim (3) is the one the arc is built to deliver, and it is the one that fails hardest. Claim
(1)'s poisson control — presented as the correctness argument — is not a control. Two
independently disqualifying defects, both visible in the committed CSVs, neither reported.

**VERDICT: NOT-DONE**

---

## SMALLEST EVIDENCE THAT WOULD CHANGE MY VERDICT

Three items. They are small, and two of them need **no new fits**.

1. **A FIXED-TRUTH coverage cell (new fits — the only expensive item).** One `Lambda`, held
   constant across seeds, at `p=6, q=2, binomial`, 200 seeds, `n ∈ {100, 1600}`, four arms.
   Run it at **three** truth scales — `‖Λ‖` corresponding to `lam_sd ∈ {0.5, 1, 3}` — because
   the analytic boundary in §1a is `s² < 2τ² + σ²` and `lam_sd = 3` straddles it. Report the
   2·MCSE band. This is ~4800 fits, i.e. 1.5× the coverage cell already run, and it is the only
   thing that can turn "coverage marginalised over a matched prior" into a coverage claim.
   If `aghq_ridge` clears 0.95 at the 2·MCSE lower band at **all three scales**, claim (3) is
   made and my §1 objection is answered outright.

2. **A did-the-quadrature-move flag (no new fits; one column).** Record
   `max|par_aghq − par_laplace|` (or reuse the existing `aghq_stop` string) and re-tabulate
   claim (1)'s poisson row **restricted to fits where AGHQ actually moved**. If the poisson null
   still holds on the moved subset — even with a much smaller `n` — the control is rehabilitated
   and §6b dissolves. If it does not, claim (1)'s correctness argument must be withdrawn, not
   reworded. This is a ten-line change to `21-wide-factorial.R` and one re-run of the poisson
   cells; the binomial 7550 need not be touched.

3. **Report the missingness, and pick the conservative convention (no new fits at all).**
   Publish the per-entry interval-availability table from §6a beside every coverage number, and
   quote the "refusal counted as non-covering" row as primary — that is what the CSV's `covered`
   column already contains, and it is what `24-coverage-cell.R:38-42` says the run intended.
   Correct `decisions.md`'s "availability 100%" line. This does not rescue claim (3) (the
   2·MCSE bands still fail), but without it the arc is quoting a filtered pool while asserting
   no filter was applied, and that alone would sink it with a referee.

Items 2 and 3 cost hours. Item 1 is the real gate, and until it exists the honest form of the
headline is: *"under a Gaussian prior on Lambda matched in form to the ridge, AGHQ+ridge
intervals are calibrated on average; conditional coverage ranges 0.87–0.99 and no fixed-truth
result exists."* That sentence I would sign. The one under review I would not.
