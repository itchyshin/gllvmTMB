# Morning brief — VA/EVA overnight run (2026-07-26 → 27)

Read this first. Everything below is measured, nothing is promoted, nothing is
merged. Two private branches; `NAMESPACE` untouched throughout.

---

## The headline you did not want, and should have

**The core motivation for VA — that it is faster than Laplace at scale — is not
supported for this model class.** We tested the regime where the claim actually
lives (n up to 5000, p up to 50, on Totoro) and there is **no crossover**:

| | scaling in n | runtime vs Laplace |
|---|---|---|
| `gtmb_gh` (our VA) | ~n^1.90–1.94 | **9.9×–31× slower** |
| `gtmb_jj` (our VA) | ~n^2.51–2.66 | slower |
| `gllvm_va` | ~n^2.04–2.10 | slower |
| **`gtmb_laplace`** | **~n^0.93–1.04 (linear)** | — |

All three VA arms are roughly **quadratic** in n. Laplace is **linear**.

At n=2500 and n=5000 our VA engine **timed out 12/12 cells** against a 900 s
budget — it does not finish at all. `gllvm`'s VA degrades more gradually but also
reaches 0/12 at n=5000. 48 cells completed, 55 timed out.

**The O(m³)-in-species argument is visible only in direction.** Laplace does
scale worse in p (~p^1.40–1.53) — but its absolute runtime is lower than every
VA arm at *every single cell*, because the n-scaling gap dwarfs the p effect once
n reaches the thousands. As tested, the literature's argument for VA-over-Laplace
at scale would have to be argued in reverse for this model class.

**Direct consequence for the destination.** Ayumi's model is n = 5397. Our VA
engine cannot fit it — not slowly, at all. Any plan that routes her problem
through VA for speed is dead on this evidence.

---

## The warm start was a no-op, and that reinstates an earlier finding

I proposed the data-blind cold start (loadings initialised at an arbitrary ±0.1)
as the explanation for our worse `Sigma_B` recovery. **It is not.**

- `max |ELBO_warm − ELBO_cold| = 1.63e-08` across 6 seeds — **3 positive, 3
  negative.** Floating-point noise with no sign.
- `max |relFrob_warm − relFrob_cold| = 1.28e-04`, 4 negative / 2 positive.

Cold and warm reach the **identical stationary point to eight decimal places**.

**Therefore the earlier controlled result STANDS and is reinstated:** holding
engine, optimiser, starts and gates fixed and changing only the evaluation, the
looser **JJ bound recovers `Sigma_B` better than the tighter GH bound on 20/20
paired seeds**. That was not a starting-value artefact.

Two things survive from the warm-start work anyway:

1. It is **~21 % faster** (verified against call-order by reversing the run
   order), so keep it — just do not claim it fixes accuracy.
2. **The real defect is untouched and stranger than a bad start:** the *raw,
   unoptimised* eigen-guess beats the *converged* fit on 5/6 seeds
   (0.83–0.88 vs 0.82–2.03 relative Frobenius). The optimiser walks **away** from
   a good starting point to a worse fixed point — and it is not stuck, it is
   maximising an objective whose maximiser is a worse covariance estimator.

---

## The most useful thing for the package

**A degeneracy detector, and a recommendation not to ship it as a rule.**

From the 640-cell grid: gllvmTMB's Laplace — the shipping default — produced
**70/601 degenerate fits (12 %)**, and **59 of them reported `convergence = 0`
and `pdHess = TRUE`**. The user gets no signal.

A cross-arm quantity separates them perfectly. `log(attenuation_A /
attenuation_B)` cancels the unknown truth exactly, leaving a purely fit-time
ratio of traces:

| | &#124;log trace-ratio&#124; |
|---|---|
| 531 sane fits | ≤ 1.04 (2.8×) |
| 70 degenerate fits | ≥ 3.42 (30.5×) |

No overlap, an order-of-magnitude gap. But **the threshold was chosen in-sample**
— the reported 100 %/100 % is a resubstitution estimate, not a performance
estimate. It needs held-out validation before anyone quotes it.

**Recommended change, deliberately minimal (Noether's call, and I agree):**

1. **Persist `trace(Sigma_B)` and its eigenvalues** on the fit object for every
   engine. A few lines in the reporting path. No behaviour change, no threshold
   to defend, no API break, no public claim.
2. **One documented sentence** on the Laplace/binomial path: `convergence == 0`
   with `pdHess = TRUE` does **not** certify the `Sigma_B` estimate.

Point 2 is not even a new claim — `gllvm`'s own literature already states GLLVM
likelihoods are "highly complex and multimodal" and that a valid Hessian confirms
only a local maximum. gllvmTMB would be aligning with established doctrine.

**Where degeneracy lives:** 100 % of degenerate fits are Bernoulli, 0 % Poisson.
Within Bernoulli: 79 % at n=40, 33 % at n=100, 11 % at n=200, **1 % at n=400.**
Small-n sparse binary — Ayumi's regime.

---

## Incomplete, and I am not dressing it up

**Real data did not finish.** The benchmark ran out of time mid-sweep and the
script only writes its CSVs after the full loop, so **no** pairwise `Sigma_B`
agreement, **no** Procrustes correlations, and **no** bound-ordering verdict
exist. That was the run meant to answer "does any of this hold on data we did not
simulate", and it is unanswered. The agent also disclosed an accidental
double-launch of its own script.

What the partial run did establish, on `gllvm::eSpider` (100 sites × 12 real
spider species):

- `gllvm` EVA **errors on Poisson on real data too** — confirming the simulated
  finding.
- Our GH engine's **health gate rejected both real Poisson fits**
  (`failed_health_gate` / `failed_variance_domain`) even with the warm start.
  Honest, but not usable.
- `gllvm` EVA on real binary took **80.29 s and reported `not_converged`** — it
  failed **openly**, unlike the simulated pattern of 68 % degenerate-with-clean-
  convergence. So the silent-failure pattern may be a simulation artefact. That
  matters and is untested.

**Resuming this is the single highest-value next slice.**

---

## Scorecard

| Claim | Status |
|---|---|
| Our binomial VA uses a tighter bound than `gllvm`'s JJ | **established** (source-verified, 320/320 cells) |
| Tighter bound ⇒ better `Sigma_B` | **refuted** (JJ better 20/20, warm start cleared as confound) |
| VA is faster than Laplace at scale | **refuted** (no crossover; VA quadratic, Laplace linear) |
| Cold start explains our accuracy gap | **refuted** (identical optimum to 1.6e-08) |
| Laplace fails silently on small-n binary | **established on simulated data**; real-data status **unknown** |
| Cross-arm trace ratio detects it | **promising, in-sample only** |

Four claims retracted overnight, on top of four earlier. Every retraction came
from a controlled measurement rather than an argument.

---

## What needs you

1. **NEWS entry** for the merged binary/OLRE logLik defect (`v0.6.0`, `rc.1`,
   `rc.2` affected; not on CRAN).
2. **Whether to file the public GitHub issue** for it.
3. **A decision on VA's purpose.** It is not the speed play. On this evidence its
   defensible role is *disclosed failure* — it was the only arm that returned a
   number in all 640 cells and never reported a clean status on a degenerate fit.
   That is worth having, but it is a different product than "faster inference".

## Landing state

- `claude/va-wiring-20260726` @ `70f20adb` + overnight work — committed, **not
  pushed, not merged**, based on `dc79753a`. `main` is at `c3d11667`; **rebase
  required**.
- Results local under `dev/totoro-grid/`, `dev/degeneracy/`, `dev/scale/`,
  `dev/warmstart-result.md` (D-50 — never a GitHub artifact).
