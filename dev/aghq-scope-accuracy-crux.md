# AGHQ-Laplace scoping — THE CRUX: does it actually buy accuracy?

**Lens:** Noether. Adversarial. This lens was written to kill the proposal.
**Verdict: it failed to kill it.** The decisive measurement went the other way, and
against my own prior derivation. That is reported below with the derivation that was
wrong and the number that corrected it.

**Status:** research scoping note. No package behaviour claimed or changed. Nothing
promoted. Files created: `dev/aghq-crux-q1-probe.R`, `dev/aghq-crux-q1-probe.R.fns`,
`dev/aghq-crux-q1-ladder.R` and their CSVs. `R/`, `src/`, `inst/`, `tests/` untouched.

Provenance markers used throughout: **MEASURED** (run here or read from this repo's
result files), **DERIVED** (algebra done here), **AGENT-INFERRED** (my inference, not
proved and not measured).

---

## 0. Headline

At **matched per-axis latent information** (T = 20 Bernoulli traits, `lambda_sd = 0.7`,
so `Lambda'Lambda = 9.8` per axis — identical to one axis of the Ayumi-scale run),
a hand-coded q = 1 AGHQ estimator was fitted alongside its own k = 1 (= exactly Laplace)
special case on the same data, three paired seeds:

| seed | attenuation, Laplace (k=1) | attenuation, AGHQ (k=15) | scale ratio `c` on Lambda |
|---:|---:|---:|---:|
| 11 | 0.8597 | 0.8991 | 1.0227 |
| 12 | 0.8879 | 0.9538 | 1.0365 |
| 13 | 0.9429 | 0.9992 | 1.0294 |
| **mean** | **0.8968** | **0.9507** | **1.0295** |

**MEASURED.** `attenuation = trace(Sigma_hat)/trace(Sigma_true)`, the same estimand as
`dev/ayumi-scale-second-opinion-helpers.R:57`. `n = 2000`, 3/3 seeds move in the same
direction, paired.

- Laplace's attenuation deficit: **10.3 pp**.
- AGHQ removes **5.4 pp of it (52%)**, leaving **4.9 pp** that the *exact* integral does
  not remove.
- AGHQ's landing point, 0.951, sits essentially on the real run's VA-GH value (0.949).

So the answer to the crux question is: **roughly half of Laplace's attenuation IS
quadrature error and AGHQ does remove it. The other half is mostly finite-`n` bias that
shrinks on its own.** Neither the optimistic nor the dismissive framing of the proposal
survives.

Two ladders then **identify** the effect rather than merely observing it (§2c, §2d):

- the AGHQ correction is **`n`-invariant** over a 16× range (`c_full` = 1.031 ± 0.015,
  6/6) — so it is *not* finite-`n` bias, optimiser slop, or a REML effect, all of which
  shrink with `n`;
- it **decays with `T`** — 13.2% at T = 5, 7.4% at T = 10, 3.0% at T = 20, 1.0% at T = 40
  (8/8) — which is what a per-unit quadrature error must do and what none of the
  alternatives can do.

**Nothing but Laplace quadrature error has both properties.** That is the identification,
and it is the load-bearing result of this note.

**Cost, MEASURED but on a contended machine (load average 44 at the time of the run) —
therefore reported as a RATIO only, never as an absolute:** AGHQ (k = 15) warm-started
from the Laplace optimum cost **1.57×, 1.72×, 1.67×** the Laplace fit on the three paired
seeds (median **1.67×**), in-process, same seeds, same optimiser. Not 5–9×. Two honest
caveats attach to that ratio (§6).

---

## 1. "A 0.02% objective change cannot produce a 38% estimate change" — refuted, with a number

The brief's central worry is that the O3 node ladder moves the objective by ~0.02% and
that this is too small to matter. This is the wrong statistic, and I can now say so with
a measurement rather than an argument.

### The general principle (DERIVED; it is design 109's `(★)`, applied one level up)

Let `l` be the exact marginal log-likelihood and `l_LA = l - G` the Laplace objective,
`G` the Laplace gap. Both maximisers are stationary, so
`grad l(theta_LA) = grad G(theta_LA)`, and expanding about the exact maximiser `theta*`:

    theta_LA - theta*  ~=  -[ -grad^2 l(theta*) ]^{-1} grad G(theta*)          (star)

**The displacement depends on the GRADIENT of the gap, not on its LEVEL.** A gap of any
size that is flat in `theta` returns the exact maximiser; a gap of any size with slope in
one coordinate biases that coordinate. `docs/design/109-bound-tightness-vs-recovery.md`
proves this for VA bounds; the identical algebra applies to Laplace, because `(star)`
never used the bound property.

Therefore quoting the gap as a *percentage of the objective* is meaningless: the objective
contains the enormous `N·T` data term, which is exactly the part that cancels in `(star)`.

### The measured amplification

In the q = 1 probe at `n = 2000, T = 20`, evaluated at the Laplace optimum:

- total Laplace gap `G` = **15.1 / 18.5 / 20.3 nats** (three seeds) — about **0.0086 nats
  per unit**, and **~7e-4 (0.07%) of the objective**, the same order as the O3 ladder's
  0.02%;
- yet the induced displacement is **+2.9% in the Lambda scale, +5.9% in `trace(Sigma_B)`**.

**A ~0.07% objective correction produced a ~6% estimate correction: roughly 90-fold
amplification.** MEASURED. The O3 ladder's smallness is therefore *not* evidence against
the proposal. It is not evidence *for* it either — it is simply the wrong statistic, and
the brief should stop quoting it in either direction.

---

## 2. Where does Laplace's attenuation come from? (the single most important question)

### 2a. What it is NOT — three eliminations

**(i) The ML-vs-REML distinction. ELIMINATED, DERIVED.** The fixed effects here are the
`T = 20` trait intercepts, each informed by all `n = 5397` units. The REML correction to a
variance component is `O(p_fixed / n) = 20/5397 = 0.37%`. The measured deficit is 12.5%.
REML is off by a factor of 34 and cannot be the explanation. (Same conclusion at any `n` in
this design: the intercepts are essentially known.)

**(ii) A metric artefact / regression dilution. ELIMINATED, DERIVED.** `attenuation` is
`trace(Sigma_hat)/trace(Sigma_true)` — a ratio of traces, rotation-invariant, so the
rank-2 rotational non-identifiability of `Lambda` does not enter, and there is no
"regress the true on the fitted" dilution anywhere. Moreover estimation noise pushes this
statistic the *wrong way*: `E[sum_tk lambda_hat^2] = sum_tk lambda^2 + sum_tk Var(lambda_hat)
> trace(Sigma_true)`. **Noise inflates the trace. It cannot manufacture attenuation.**

**(iii) Optimiser non-convergence — the `grad_max = 1.4e-2` red herring. ELIMINATED
subject to one one-line check, DERIVED.** The brief flags that Laplace reported
`grad_max = 1.42e-2` (`dev/ayumi-scale-second-opinion-results.csv`) against VA's `4.8e-4`,
"142x the tolerance the VA gate enforces". Two problems:

1. *A raw gradient is not a distance.* The parameter displacement implied by a residual
   gradient `g` is `H^{-1} g`, not `g`. Per-loading information here is roughly
   `n · E[sigma'] · E[u^2 | y] ~= 5397 × 0.186 × 0.355 ~= 356`. A gradient of `1.4e-2` then
   implies a displacement of about **`4e-5`** — five orders of magnitude below the `0.064`
   displacement that the 12.5% attenuation represents.
2. *Gradient tolerances are not comparable across engines.* Laplace and VA maximise
   different objectives on different scales at different `n`. "142× the VA gate" compares
   two numbers that do not live on the same axis. This is a category error, not a finding.

**Required check before anything else (TEST 0, §5):** compute `sqrt(g' Sigma_theta g)` and
`max |Sigma_theta g|` from the sdreport that already exists for arm A. Prediction: below
`1e-3` in every coordinate. If it is not, stop — nothing else in this note is interpretable.

### 2b. What it IS — decomposed, MEASURED

The probe decomposes the deficit directly, because k = 1 and k = 15 are the *same
estimator with the same optimiser on the same data*:

| component | size (pp of attenuation) | share | AGHQ fixes it? |
|---|---:|---:|---|
| Laplace quadrature error | 5.4 | 52% | **yes** |
| residual at the exact integral | 4.9 | 48% | **no** |

### 2c. The n-ladder settles which half is which — MEASURED

`dev/aghq-crux-q1-nladder.csv`, T = 20, 2 paired seeds per `n`, full AGHQ refit:

| n | seed | attenuation, Laplace | attenuation, AGHQ | `c_full` |
|---:|---:|---:|---:|---:|
| 500 | 11 | 0.8596 | 0.9146 | 1.0315 |
| 500 | 12 | 1.2816 | 1.4528 | 1.0647 |
| 2000 | 11 | 0.8597 | 0.8991 | 1.0227 |
| 2000 | 12 | 0.8879 | 0.9538 | 1.0365 |
| 8000 | 11 | 0.8912 | 0.9325 | 1.0229 |
| 8000 | 12 | 0.9527 | 1.0110 | 1.0301 |

Three things fall out, and they matter more than the headline table.

**(1) The AGHQ correction is `n`-INVARIANT. This is the decisive result.** `c_full` is
`1.031, 1.065, 1.023, 1.036, 1.023, 1.030` — **mean 1.031, sd 0.015, positive on 6/6, and
flat across a 16× range in `n`**. It shows no decay whatsoever. That is exactly the
signature of a per-unit approximation error: it does not vanish as `n -> infinity`, because
the per-unit information stays fixed at `T = 20`. **It therefore cannot be finite-`n` bias,
cannot be optimiser noise, and cannot be a REML effect — all three shrink with `n`. It is
quadrature error, and AGHQ is the thing that removes quadrature error.**

**(2) The residual after AGHQ DOES shrink with `n`** — mean post-AGHQ attenuation
0.926 at `n = 2000`, 0.972 at `n = 8000` (deficit 7.4 pp → 2.8 pp for a 4× increase,
roughly `1/n`). So the 4.9 pp residual of §0 is largely **finite-`n` ML bias**, and at
Ayumi's `n = 5397` it should already be around 3–4 pp and falling. **The ceiling on
AGHQ's benefit is therefore not capped by a competing fixed-`T` bias.** (2 seeds per cell;
directional, not a rate estimate.)

**(3) The attenuation *level* is seed-dominated and the statistic is upward-biased.**
`atten_LA` at `n = 500` was 0.860 and **1.282** — the second is above 1, i.e. gross
*over*-estimation, and AGHQ pushed it further to 1.453. The mechanism is the one from
§2a(ii): `E[sum lambda_hat^2] = sum lambda^2 + sum Var(lambda_hat)`, and at `n = 500` that
noise inflation is roughly `40 / (500 × 0.066) / 8 ~= +15%`. Two consequences:

- **Single-seed attenuation numbers must not be read to three decimals.** That includes
  the real run's own `0.8747` and `0.949` — both are one seed
  (`dev/ayumi-scale-second-opinion-results.csv`, seed 20260727).
- At `n = 5397` the same noise inflation is about **+1.4%**, so the real run's 0.875 if
  anything **understates** Laplace's true attenuation. That makes AGHQ's job harder, not
  easier, and should be stated when the target is set.

**The reliable statistic in all of this is the PAIRED `c_full`, not the level.**

### 2d. The T-ladder confirms it is quadrature error — and reframes the whole proposal

`dev/aghq-crux-q1-tladder.csv`, `n = 2000`, 2 paired seeds per `T`, full AGHQ refit:

| T | attenuation, Laplace (mean) | attenuation, AGHQ (mean) | `c_full` (mean) |
|---:|---:|---:|---:|
| 5 | 0.718 | 0.921 | **1.132** |
| 10 | 0.835 | 0.966 | **1.074** |
| 20 | 0.874 | 0.926 | **1.030** |
| 40 | 0.950 | 0.969 | **1.010** |

**`c_full - 1` decays monotonically with `T`, on 8/8 fits, roughly as `T^{-1.24}`.** A
quadrature error in a `T`-observation-per-unit Laplace approximation *must* decay with `T`;
finite-`n` bias, REML, metric artefacts and optimiser slop *cannot* — none of them knows
what `T` is. Together with the `n`-invariance of §2c(1), this is as clean an
identification as this kind of question admits:

> **The part of Laplace's attenuation that AGHQ removes is `n`-invariant and decays with
> `T`. It is the Laplace quadrature error. Nothing else in the candidate list has both
> properties.** MEASURED.

**And this reframes the proposal.** At Ayumi's `T = 20` the payoff is modest (+3.0% on
`Lambda`, ~+6% on the trace). At `T = 5` it is **+13.2% on `Lambda`**, lifting attenuation
from 0.72 to 0.92 — the difference between an unusable and a usable variance-component
estimate. The strongest case for AGHQ-LA is therefore **not** "close the Ayumi gap"; it is
**"rescue the short-profile regime, where Laplace is worst and where a great many
gllvmTMB users actually sit."** If this proposal is scoped against Ayumi's `T = 20` cell
alone it will be judged on its weakest evidence.

### 2f. Point prediction for Ayumi's cell

Applying the measured, `n`-invariant `c_full = 1.031` to the real run's Laplace value:

    predicted post-AGHQ attenuation  =  0.875 × 1.031^2  =  0.930

i.e. **AGHQ-LA closes ~44% of the 12.5 pp deficit and lands at ~0.93 — short of VA-GH's
0.949.** AGENT-INFERRED (q = 1 → q = 2 transfer is not established; see §7.1).

### 2e. My own derivation was wrong by 3x — reported because it is the informative failure

Before measuring, I derived the leading-order Laplace bias. For the scalar case with `T`
traits, common loading `lambda`, near-balanced prevalence
(`sigma'' = 0`, `sigma' = 1/4`, `sigma''' = -1/8`), and `H = 1 + T lambda^2 / 4`:

    G_i        = T lambda^4 / (64 H^2)                       (Tierney-Kadane, 2 terms)
    dG_i/dlam  = T lambda^3 / (16 H^3)
    I_lam      = 2 lambda^2 T^2 / (psi + T lambda^2)^2 = lambda^2 T^2 / (8 H^2),  psi = 1/sigma'

and hence, via `(star)`,

    **Delta lambda / lambda  ~=  -1 / (2 T H)**                                 DERIVED

The sign is unambiguous: `dG/dlambda > 0`, so **Laplace under-estimates `Lambda`** —
attenuation, not inflation. **That prediction was confirmed: `c_full > 1` on 3/3 seeds.**

The magnitude was not. At `T = 20`, `E[sigma'] ~= 0.214` and `H = 1 + 20(0.49)(0.214) = 3.10`,
the formula gives `-0.81%` on `lambda`. **Measured: `-3.0%` — 3.7× larger.** The T-ladder
lets me score the formula across four cells:

| T | `1/(2TH)` predicted | measured `c_full - 1` | ratio |
|---:|---:|---:|---:|
| 5 | 6.6% | 13.2% | 2.0 |
| 10 | 2.4% | 7.4% | 3.0 |
| 20 | 0.8% | 3.0% | 3.7 |
| 40 | 0.2% | 1.0% | 4.2 |

**The expansion gets the sign right (3/3 and 8/8 confirmations), gets the qualitative
`T`-decay right, and is wrong on both magnitude (2–4× low) and rate (it predicts `~T^{-2}`;
measured is `~T^{-1.24}`).** The reason is visible in the formula: the expansion parameter
is `1/H`, which is 0.66 at `T = 5` and still 0.32 at `T = 20` — the two-term
Tierney–Kadane expansion is truncating a series it does not dominate.

**Consequence that matters for scoping: do not size this effect from the asymptotic
expansion.** It understates it 2–4× in the regime the model actually sits in, and it
understates it *increasingly badly as `T` grows*. Any analytic pre-screen of AGHQ's value
in this package will be biased **against** AGHQ. Only measurement is reliable — which is
why §5 is a measurement plan, not an algebra plan.

---

## 3. Why did VA-GH (a lower bound) beat Laplace?

`docs/design/109-bound-tightness-vs-recovery.md` established, for the JJ-vs-GH pair, that
bound tightness does not predict recovery, citing Rainforth et al. (2018). The brief asks
whether that reasoning also explains VA-GH beating Laplace. **It does not transfer, and
the reason it does not is important for the proposal.**

**Design 109's argument is about two members of the same bound family.** Its point is that
`G_1 <= G_2` pointwise implies nothing about `||grad G_1||` vs `||grad G_2||`, so ordering
bounds by tightness orders nothing. That is correct and it applies to JJ vs GH.

**Laplace vs AGHQ is not that comparison.** AGHQ is not a tighter bound on the same
objective — it is *the exact objective*, approached to machine precision as `k` grows
(O3 spike: converged by 9 nodes at q = 1). For AGHQ the gap `G -> 0` uniformly, and the
`(star)` displacement therefore goes to zero. **The Rainforth caution does not apply to
error elimination; it applies to swapping one biased surrogate for another.** This is the
single strongest structural argument in the proposal's favour, and it is the one the brief
under-states.

**On VA-GH's 0.949 specifically.** My exact-integral q = 1 arm landed at 0.951. Two readings:

- *(a)* VA-GH's `Sigma_B` bias happens to be near-zero in this cell, so it is tracking the
  exact MLE. Then VA-GH's advantage over Laplace is real but is not a virtue of the bound —
  it is Laplace's quadrature error being visible and VA's not being visible *here*.
- *(b)* Coincidence across two different designs (q = 1 probe vs q = 2 run).

I cannot separate these. But one thing is settled and cuts against treating 0.949 as a
target: **VA-GH's `Sigma_B` bias flips sign across cells in this repo.** Design 109 was
forced to conclude GH *over*-estimates `Sigma_B` (from JJ beating GH 20/20 at n∈{150,400},
T = 8); at the Ayumi cell GH *under*-estimates it (0.949 < 1). A bias that changes sign
across design points is a design-point property, not an engine property.

**Therefore: the correct benchmark for AGHQ-LA is the TRUTH, not VA-GH's answer.** Framing
the target as "close the 0.167 → 0.103 gap to VA-GH" imports VA-GH's own unquantified bias
into the acceptance criterion. State the goal as "reduce attenuation deficit against
`Sigma_true`", which is what the probe measures and what `(star)` predicts.

---

## 4. Correction to the proposal's cost claim

> "cost linear in the node count ... so it should keep Laplace's n^0.98 scaling"

The `n` claim is right and important — AGHQ-LA has **no variational parameters**, it
integrates rather than parameterises the latent variables, so the 27,000-parameter block
that makes VA scale at `n^1.9`–`n^2.7` genuinely does not exist. That is the proposal's
best feature and nothing here challenges it.

The **node-count** claim is wrong at q > 1. A tensor product grid is `k^q`, not `k` — the
O3 spike says this explicitly ("A tensor grid grows as `n_q^q`; even the modest 9-node rule
is 81 points per unit at q = 2"). At Ayumi's q = 2 with k = 5 that is **25 integrand
evaluations per unit**, not 5.

But the measured *fit-time* multiplier is far smaller than either number, because the
mode-finding, the Hessian, the optimiser iterations and the R/TMB overhead are shared:
**median 1.67× at k = 15, q = 1, warm-started from Laplace.** MEASURED (contended machine —
ratio only). Two caveats that both push the true multiplier up:

1. The AGHQ arm was **warm-started at the Laplace optimum**, so it needed fewer optimiser
   iterations than a cold start. (This is also how one would deploy it, so the ratio is
   fair for the intended use, but it is not a cold-start number.)
2. Arms ran LA-then-AGHQ in a fixed order rather than interleaved. There is no visible
   first-fit penalty (the three LA times are 44.6 / 42.7 / 46.0 s, not decreasing), but
   this does not meet the "interleave and take medians of ≥3" bar and should be redone
   properly before any timing is quoted anywhere.

**AGENT-INFERRED:** at q = 2 the per-unit integrand cost rises `k^2 = 25×` at k = 5, but
the shared overheads that produced 1.67× at q = 1 remain shared, so I would expect a
multiplier in the **2–5×** range rather than the brief's 5–9× — with genuine uncertainty,
because the balance of integrand-vs-overhead flips as the integrand gets 25× heavier. This
must be measured, not projected.

---

## 5. The cheap decisive tests, specified

These are ordered. Each is a kill gate. **None requires building the AGHQ estimator.**

### TEST 0 — is Laplace's answer even converged? (seconds)

From the existing arm-A `sdreport`: compute `d = Sigma_theta g` where `g` is the reported
fixed-effect gradient and `Sigma_theta` the fixed-effect covariance. Report `max|d|` and
`sqrt(g' Sigma_theta g)`.
**Prediction:** `max|d| < 1e-3`. **Kill rule:** if `max|d|` is of order the loading values
(~0.5), the 0.167-vs-0.103 comparison is an optimiser artefact and the whole scoping
exercise is void. Do this first; it is nearly free and it retires the `grad_max` worry
one way or the other.

### TEST A — the scale line search (the (star) test in one dimension; ~minutes)

*Inputs already on disk:* `beta_hat`, `Lambda_hat` from arm A, and (as warm start) the
conditional modes `u_hat_i` from the TMB random-effect report.

*Procedure.* Build the q = 2 adaptive-quadrature objective from the O3 spike machinery
(`dev/aghq-o3-q2-coupled-spike.R` already computes `u = m + sqrt(2) R^{-1} x` with
`R'R` the conditional Hessian, and already validates the k = 1 = Laplace identity). Then
evaluate

    f_AGHQ( beta_hat, c * Lambda_hat ; k )   for c in seq(0.95, 1.15, by = 0.01),
                                             for k in {1, 5, 9}

*Validation gate.* The `k = 1` curve **must** peak at `c_hat = 1.000`. (My probe gets
`1.00003`, `1.00003`, `1.00003` — this is a genuine and sensitive check that the objective
and the fit agree.) If it does not, the objective is not the one that was optimised and
nothing downstream means anything.

*Readout.* `c_hat_k` from a parabolic fit about the grid minimum. Predicted post-AGHQ
attenuation `= 0.875 * c_hat_k^2`.

*Calibration of the shortcut, MEASURED.* Because `beta` is held fixed, this line search
**under-predicts** the full refit: `c_LS / c_full` = 1.020/1.023, 1.023/1.036, 1.023/1.029
→ it recovers ~80–90% of the true move. **It is therefore a conservative screen: an
ALIVE reading is strengthened by the bias, and a DEAD reading needs the margin below.**

*Decision rule.*
| `c_hat_9` | predicted attenuation | verdict |
|---|---|---|
| ≤ 1.008 | ≤ 0.889 | **DEAD.** Even after inflating by the shortcut's 1.2× under-prediction, AGHQ closes <15% of the deficit. Stop. |
| 1.008 – 1.030 | 0.889 – 0.929 | Inconclusive → TEST B |
| ≥ 1.030 | ≥ 0.929 | **ALIVE.** ≥50% of the deficit. Proceed to TEST B then scope the estimator. |

*Cost.* One objective evaluation is `5397 units × 81 nodes × 20 traits ≈ 8.7M` logistic
evaluations at k = 9, plus one 2-d Newton mode solve per unit *per `c`* (not per node),
warm-startable from the previous `c`. ~60 evaluations total. Minutes in vectorised R.

### TEST B — the full one-Newton-step displacement (~minutes; strictly better than A)

`(star)` applied in all 60 coordinates rather than only the scale direction:

    Delta_theta = -[ grad^2 f_LA(theta_LA) ]^{-1} grad f_AGHQ(theta_LA)

Two facts make this cheap. The Hessian is **already computed** — it is the fixed-effect
joint precision behind the existing `sdreport` (`pdHess = TRUE`). And by Laplace
stationarity `grad f_AGHQ(theta_LA) = grad G(theta_LA)` exactly, so the finite-difference
gradient of `f_AGHQ` (60 forward evaluations) *is* the gap gradient — no cancellation of
large terms. Then report `trace(Sigma_B)` at `theta_LA + Delta_theta`.

This yields the predicted post-AGHQ attenuation with no direction restriction and no
refit, and it is the exact quantity the proposal turns on. **If TEST 0 passes, I would run
TEST B directly and treat TEST A as its sanity check.**

### TEST C — the q = 2 transfer check (the one that closes my biggest blocker)

Re-run `dev/aghq-crux-q1-probe.R` with `q = 2` at `n = 2000, T = 20` (tensor grid, k = 9),
5 paired seeds. **Prediction:** `c_full` in the 1.02–1.04 band, as at q = 1. This directly
tests whether my q = 1 result transfers, at ~25× the q = 1 integrand cost — still under an
hour. **Kill rule:** if q = 2 `c_full < 1.01`, the headline does not transfer and the
proposal is dead regardless of TEST A/B.

---

## 6. Probability verdict

Conditional on TEST 0 passing (Laplace genuinely converged — which I expect):

| outcome | my probability |
|---|---:|
| **At Ayumi's cell (T = 20, q = 2, n = 5397)** | |
| AGHQ-LA raises `trace(Sigma_B)` by ≥ 3% (attenuation ≥ 0.90) | **0.85** |
| AGHQ-LA closes ≥ 40% of the attenuation deficit | **0.60** |
| AGHQ-LA reaches attenuation ≥ 0.95, i.e. matches VA-GH | **0.25** |
| AGHQ-LA essentially reproduces Laplace's answer (< 1% move) | **0.07** |
| **At short profiles (T ≈ 5, q = 2)** | |
| AGHQ-LA raises `trace(Sigma_B)` by ≥ 15% | **0.75** |
| **Cost** | |
| multiplier over Laplace at q = 2, k = 5 lands in 2–5× | **0.60** (5–9×: 0.25; > 9×: 0.15) |

**So: AGHQ-LA is much more likely to move the estimate materially than to reproduce
Laplace's answer. This lens set out to kill the proposal and could not.** But the claim it
supports is smaller and differently shaped than the brief's:

- ✅ **The mechanism is real and identified.** The `n`-invariance plus the `T`-decay is a
  two-sided fingerprint that no competing explanation matches. Laplace's attenuation is
  substantially quadrature error, and AGHQ is the operation that removes it.
- ✅ **The "0.02% objective ⇒ no estimate change" objection is refuted quantitatively**
  (~90× amplification, measured).
- ✅ **The Rainforth / design-109 caution does not apply**, because AGHQ is not a tighter
  bound — it is the exact objective. That distinction is the proposal's strongest
  structural argument and the brief under-uses it.
- ❌ **"Closes the 0.167 → 0.103 gap" is not supported.** Predicted landing is ~0.93
  attenuation, not 0.949; ~44% of the deficit, not all of it.
- ❌ **"Cost linear in node count" is wrong** at q > 1 (`k^q`), though the measured
  *fit-time* multiplier is far below either the linear or the tensor count.
- ⚠️ **VA-GH's 0.949 is the wrong target.** Its `Sigma_B` bias flips sign across this
  repo's own cells. Score against `Sigma_true`.

**Honest one-line framing:** *AGHQ-LA removes the `n`-invariant, `T`-decaying part of
Laplace's variance-component attenuation — modest at `T = 20` (~+6% on the trace), large
at `T = 5` (0.72 → 0.92) — at a measured 1.7× cost at q = 1 and an unmeasured cost at
q = 2, on the route that keeps Laplace's `n^0.98` scaling because it has no variational
parameters.*

That is a good trade and worth building. It is a different and smaller claim than the one
the brief is built on, and if it is scoped and judged against Ayumi's `T = 20` cell alone
it will be evaluated on its weakest evidence.

---

## 7. What I could not establish

1. **q = 1 → q = 2 transfer. My largest blocker.** Everything measured here is q = 1. The
   Laplace error at q = 2 involves a 2-dimensional expansion with cross terms I did not
   derive and did not measure, and the tensor grid makes the q = 2 integrand 25× heavier at
   k = 5. TEST C closes this and should be run **before** TEST A/B are trusted.
2. **Seed count.** 3 seeds for the headline, 2 per ladder cell. The *paired* statistic
   `c_full` is tight and directionally unanimous (14/14 fits with `c_full > 1` across both
   ladders and the main run), so I am confident in the sign and the qualitative
   `n`/`T` structure. I am **not** confident in `1.031` to three digits, and the point
   prediction 0.930 in §2f should be read as "roughly 0.92–0.94".
3. **The magnitude of the Laplace bias analytically.** My two-term expansion understated
   the measured effect 2–4× and got the `T`-rate wrong. I know why (`1/H` is not small) but
   I do not have a corrected analytic bound.
4. **Bernoulli vs probit, and phylogeny.** Ayumi's real model is probit with a phylogeny
   and missingness. Everything here — the real run included — is Bernoulli-logit, complete
   cells, no phylogeny, per that run's own honesty section. None of this validates her
   fitted model and none of it should be quoted as if it did.
5. **Timing to the repo's own standard.** The 1.67× ratio is warm-started, fixed-order, and
   from a machine at load average 44. It is a ratio and an order of magnitude, not a
   timing, and must be redone interleaved with medians of ≥3 before it is quoted.
6. **Whether VA-GH's 0.949 is near the exact-MLE answer or a coincidence.** My q = 1
   exact-integral arm landed at 0.951; the q = 2 VA-GH run landed at 0.949. Different
   designs, one seed each. Suggestive only, and §3 explains why I would not build on it.
