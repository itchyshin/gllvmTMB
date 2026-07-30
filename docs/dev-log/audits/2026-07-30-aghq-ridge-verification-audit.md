# Audit — AGHQ and the loading ridge: what is verified, what is not, and four defects

**2026-07-30 · Claude (Fable 5) · read-only verification, no package code changed**

Triggered by a maintainer question: *"is all the ridge stuff implemented and tested?"* and then
*"is AGHQ implemented correctly?"* This records the answers, because they were established in a
session and would otherwise be lost. Every claim below is cited to `file:line` or to a command whose
output was observed; claims that could not be established say so.

**Scope note.** Nothing here changes package code. Two of the four defects are filed as issues; the
other two are recorded here pending a decision.

---

## 1 · Headline

**The AGHQ integrator is correct. The AGHQ estimator is not established.** Those are different
claims and the distinction carries the whole document.

- **F(θ) — the objective — is correct at high confidence.** Verified six independent ways (below).
- **θ̂ — where the optimiser lands — is not established at any n, for any family.** No test compares
  an AGHQ point estimate to a known truth or to an oracle *maximiser*.

The repo had already reached the same line and withheld the capability claim accordingly
(`docs/dev-log/decisions.md:2075`): *"The engineering is sound. The claims are not."* Three D-43
panels, nine lens verdicts, every one withheld. `man/gllvmTMBcontrol.Rd:105-107` says *"Opt-in and
experimental: no capability claim is made for quadrature-fitted models"*, and `NEWS.md` mentions
AGHQ nowhere. **No public over-claim exists.** This audit does not contradict that governance; it
documents what sits underneath it.

---

## 2 · The integrator is correct — six checks

| check | expected | observed |
|---|---|---|
| Gaussian family, q=1 (Laplace is exact) | 0 | **1.1e-13** |
| Gaussian family, q=2 (tensor product + determinant) | 0 | **4.5e-13** |
| Binomial k-ladder at fixed θ, k = 3→41 | converges | steps −0.563, −0.101, +0.0101, −0.00044, **−3.0e-06** |
| Independent hand-written re-implementation | agrees | 2.4e-10 at Λ×10 |
| `stats::integrate` oracle, cross-checked by a disjoint Simpson rule | agrees | powered ~2600× |
| AD gradient vs central differences at loading scale ×200 | agrees | 5.1e-08 |

The classic AGHQ bug family is individually **excluded by measurement**, not by reading: the
√2 probabilists'/physicists' convention, a missing `|det L|`, a missing `exp(+u'u/2)` un-weighting,
per-dimension instead of full Cholesky, and overflow in the collapse (`src/gllvmTMB.cpp:2648-2659`
is an explicit max-subtracted log-sum-exp; every exponent ≤ 0).

Getting a Gaussian integrand exact requires the adaptive centring, the Cholesky scaling, the
Jacobian and the un-weighting to be **simultaneously** right, so that check is strong rather than
incidental.

---

## 3 · Why AGHQ is worse than Laplace at small n — measured, not asserted

Since AGHQ at k=41 is essentially exact, `Laplace − AGHQ` **is** Laplace's error. Scaling the
loadings at fixed everything else:

| ‖Λ‖ | 1.27 | 2.54 | 3.82 | 5.09 | 7.63 | 10.17 |
|---|---|---|---|---|---|---|
| Laplace − AGHQ (nll) | −0.11 | +0.13 | +0.30 | +0.45 | +0.85 | **+1.21** |

**Laplace's error grows monotonically, roughly linearly, with ‖Λ‖ — an implicit penalty of about
0.14 nll per unit.** Corroborated at larger scale by the audit's own oracle sweep (+0.68 / +1.94 /
+3.47 / +5.02 / +6.66 / +8.47 at Λ×1…×32) and reproduced by an independent implementation, so it is
a property of Laplace-vs-AGHQ at finite k, not of this code.

The shapes explain the campaign pattern. Laplace's implicit penalty is **~linear** in ‖Λ‖: it slows
runaway but cannot stop it (47%). AGHQ removes it (73%). The explicit ridge is **quadratic**
(`0.5‖θ‖²/τ²`) and does stop it (0%). At large n the data identifies the model, the ridge is
redundant, and Laplace's implicit penalty becomes pure bias.

**This is a consistent explanation, not an established one.** It is a statement about F(θ) at a
given θ; the runaway observation is about where the optimiser lands. A third explanation is live and
untested — see §4, D1.

---

## 4 · Four defects

### D1 — AGHQ multi-start is disabled under `aghq_ridge = Inf`, on superseded evidence (filed)

**This is a deliberate design choice, not a coding slip — the distinction matters.**
`R/fit-multi.R:5297-5305` selects the alternative start built at `:5294` only when
`is.finite(aghq_ridge_tau) && aghq_ridge_tau > 0`. Under `aghq_ridge = Inf` that is FALSE, and the
in-source comment says so on purpose: *"Without a penalty there is nothing to choose on, so the
Laplace warm start is kept as before."* The reasoning is sound on its own terms — an unpenalised
objective genuinely cannot rank a runaway against a good fit.

The problem is the evidence the comment rests on: *"an investigation of 40 seeds showed the runaway
IS the maximum-likelihood solution — refitting from the TRUE parameters ties the objective in 40/40
and then walks back out."* That investigation ran on `dev/aghq-r-reference.R`, which
`docs/dev-log/decisions.md:1706-1709` later **invalidated**: *"the reference reproduces the shipped
LAPLACE arm but not the shipped AGHQ arm."* No shipped-engine truth-start has ever been run.

So the design decision may well be right; its justification has been withdrawn and not replaced.
`aghq_ridge = Inf` is **exactly the `aghq` arm in every campaign**, so that arm is single-start,
seeded at the Laplace optimum.

Compounding it: `19-warmstart-vs-flatness.R:16-19` shows that sweeping k = 5/9/15/21 at a converged
optimum moves the objective **< 0.01 nll** while the argmin's ‖Σ_B‖_F wanders **13.3 / 45.5 / 119.3
/ 38.6**. A near-flat objective plus one start plus a frozen-node surrogate-gradient convergence test
is a live alternative explanation for the n=100 result.

**Consequence: every "AGHQ alone" number in the evidence base is single-start.**

### D2 — `aghq = "auto"` k-ladder is dead code (filed)

`R/fit-multi.R:6344-6350` calls `.aghq_resolve(family, "B", ...)` inside `try()` with a fallback of
`return(9L)`. The live call site passes a family **object**; `.aghq_start_index()` does
`tolower(as.character(family))` then `vapply(..., logical(1))`, which errors, so **k = 9 is always
returned** regardless of family or tier. Passing the string `"gaussian"` returns the documented
k = 5. The one adaptive path does not adapt.

### D3 — the ridge is scale-dependent and harmful above τ (recorded)

τ is fixed at 2 — a prior claim that loadings are about 2. From `21-wide-inc.csv`, median σ by true
`lam_sd`:

| true lam_sd | 0.5 | 1 | 3 |
|---|---|---|---|
| laplace | 1.030 | 0.993 | 0.959 |
| laplace + ridge | 1.028 | 0.993 | **0.920** |
| aghq | 1.052 | 1.019 | 1.000 |
| aghq + ridge | 1.054 | 1.016 | **0.976** |

At `lam_sd = 3` the ridge makes **both** engines worse. It does nothing at 0.5 or 1. And on the AGHQ
path it is **on at τ = 2 unconditionally, with no warning** (`R/fit-multi.R:5255`, comment at
`:5369`: *"Default tau = 2 -- ON whenever AGHQ is on."*).

### D4 — penalised-fit disclosure is partial and sometimes false (recorded)

- `logLik()` is silent — returns `-object$opt$objective` (`R/methods-gllvmTMB.R:741`) with attributes
  but no condition.
- `AIC()`/`BIC()` warn, but `.frequency = "once"` per session (`R/aghq-report.R:93-101`).
- `summary()` discloses nothing.
- No NEWS entry, no vignette, no `man` mention of MAP-vs-MLE.
- **False on uncovered tiers:** `penalised` is set from the *request*, not from whether the penalty
  fired (`R/fit-multi.R:5163`). A W-tier or phylo fit reports `penalised = TRUE` and warns "this is
  not AIC" for parameters that were provably never touched (verified: `identical(opt$par)` TRUE,
  objective delta exactly 0).
- **Engine-dependent meaning:** the Laplace path minimises `fn + penalty`, so `opt$objective` is the
  *penalised* value; the AGHQ path records the *unpenalised* objective at the penalised optimum
  (`R/fit-multi.R:5676-5679`). `logLik()` returns different quantities depending on engine.

---

## 5 · Two facts that reframe the whole evidence base

### 5a — every AGHQ number was measured on a NON-DEFAULT grammar

`R/fit-multi.R` comment, verbatim:

> *"Every fit in this lane's 10,749-fit evidence base used the soft-deprecated `unique = FALSE`
> syntax, so the evidence describes a NON-DEFAULT grammar and nothing warned anyone of the gap
> (D-43, 2026-07-28)."*

Ordinary `latent()` carries per-trait Ψ, which puts `s_B` in the random vector; AGHQ Stage 1a
requires `z_B` as the only random block. The reason is the curse of dimensionality: the grid is
`k^d` where d is the per-cluster random dimension. Loadings-only with q=2, k=9 → 81 nodes. Default
grammar with q=2 **and p=6** → d=8 → 9⁸ ≈ 43 million nodes per site.

**It is tractable in principle and not built.** Conditional on `z_B` the `s_B` terms are independent
across traits, so the integral factorises into a q-dimensional outer quadrature and p **one-
dimensional** inner ones — `k^q × p·k`, not `k^(q+p)`. The name "Stage 1a" implies a Stage 1b was
intended. Ψ competes with ΛΛ' for the same variance, which is the mechanism behind runaway, so the
picture on the default grammar should not be assumed to match.

The gap is disclosed in-source and the warning now fires (`.frequency = "once"`). It was found, not
hidden.

### 5b — for two of four tested families, AGHQ mostly does not move the answer

`docs/dev-log/2026-07-29-flat-regime-campaign-results.md`, 432,000 fits: the rate at which
`aghq = k` returns the Laplace warm start **bit-for-bit** is gaussian **0.8956**, poisson **0.7401**,
binomial **0.0000**. Converged rates are 0.026–0.040.

So poisson's apparent agreement with Laplace is **not** statistical agreement — the optimisation did
not move. Already ruled at `decisions.md:1927-1938`: *"aghq_used = TRUE does not mean the quadrature
moved the answer, and no future claim may treat it as such."*

---

## 6 · Where AGHQ actually helps — binomial only, and only at large n

Binomial cells of `21-wide-inc.csv`, **315 fits per cell**. Error is |median σ − 1|, lower better:

| n | arm | \|σ−1\| | ρ err | runaway |
|---|---|---|---|---|
| 100 | laplace | 0.060 | 0.387 | 40% |
| 100 | **laplace + ridge** | **0.003** | 0.275 | **6%** |
| 100 | aghq | 0.290 | 0.340 | 58% |
| 100 | aghq + ridge | 0.149 | **0.272** | 14% |
| 400 | **laplace** | **0.039** | 0.244 | 26% |
| 400 | laplace + ridge | 0.064 | 0.185 | **6%** |
| 400 | aghq + ridge | 0.056 | **0.182** | 8% |
| 1600 | laplace | 0.063 | 0.158 | 22% |
| 1600 | **aghq + ridge** | **0.023** | **0.129** | 17% |

- **Latent SDs: AGHQ wins only at n = 1600.** At n = 100 it is 5× worse than Laplace.
- **Correlations: AGHQ + ridge ties at n ≤ 400, wins at n = 1600.**
- **Runaway: AGHQ is worse at every n.** The **ridge** is what fixes it, in both engines.
- The σ crossover sits between **n = 400 and n = 1600**. An earlier 15-fit read put it at 400; more
  data moved it, which is the standing warning about concluding from small cells.

**Family coverage is thin.** The family axis attempted four and returned three plus nbinom2:
gaussian, poisson, binomial, nbinom2 (10 fits each, bias-measured only). **Gamma produced zero
usable fits — because the harness used the unsupported default inverse link, not because the package
cannot do it.** Beta, tweedie, ordinal, lognormal, student, betabinomial, delta/hurdle and truncated
were never attempted. **13 of 16 families have no verification-grade evidence.**

---

## 7 · NOT ESTABLISHED

1. That the AGHQ optimiser lands at the AGHQ MLE — at any n, any family.
2. Whether the n=100 / n=1600 flip is statistics or an optimiser artifact. The bug explanation is
   refuted; the statistical one is consistent but unproven; the flat-objective/single-start one is
   untested.
3. Whether the shipped objective equals the exact marginal in the regime that matters (n ≥ 100,
   p = 6, q = 2). The only cross-instrument oracle check is at n=6, p=3, q=1, where Laplace's own
   error is 2.97e-10 — i.e. there is no quadrature work to do.
4. Correctness for 13 of 16 families.
5. Whether AGHQ standard errors are trustworthy outside a benign cell.
6. Anything at all about AGHQ on the **default** grammar (§5a).

**A retracted hypothesis, recorded so it is not re-derived:** this session proposed Laplace's bias is
O(1/T) in traits-per-unit (Breslow & Lin 1995 / Joe 2008), which is also
`12-crossover-vs-T.R`'s pre-registered prediction 1. The wide factorial does **not** support it —
median σ for laplace by p is 1.003 / 0.987 / 0.989 / 1.002 at p = 2/4/6/12, flat. The driver we
could measure is **‖Λ‖** (§3), not T. Campaign 12 ran 5 seeds instead of 20, timed out on 13 of 60
fits, and never reached the n=800 / T=16 cells where its prediction 2 lived; the ‖Λ‖ sweep in §3
answers the mechanism question directly in six objective evaluations, so **re-running campaign 12 is
not recommended**.

---

## 8 · Recommended next steps, in order

1. **Fix D1** (`is.finite(Inf)`) — one line, and until it lands every "AGHQ alone" number is
   single-start.
2. **Run a shipped-engine truth-start at n=100.** Start AGHQ from the true parameters: if it stays,
   the argmin is fine and the runaway is a start/flatness problem; if it walks away, the estimator is
   biased. The only existing truth-start (40/40 ties) was run on `dev/aghq-r-reference.R`, which
   `decisions.md:1706-1709` has since **invalidated** as not modelling the shipped AGHQ arm.
3. **Make the ridge's τ scale-aware, or warn.** This is the highest-value user-facing change
   regardless of engine: the ridge fixes the failure mode users actually hit, works in **both**
   engines, and — unlike AGHQ — works on the **default grammar**.
4. **Fix D4's false disclosure** (`penalised` from the request rather than the effect).
5. **Decide the Ψ gap** (§5a): build Stage 1b, or document loudly that AGHQ does not apply to
   ordinary `latent()`.
6. **Only then** consider routing. If it is built, prefer escalating on the *measured* correction —
   fit Laplace+ridge, evaluate the AGHQ objective at that optimum (one `fn()` call, no refit), and
   escalate only if the gap is material — rather than on an n threshold we cannot yet calibrate.

`aghq = FALSE` should remain the default until at least 1, 2 and 5 are resolved.
