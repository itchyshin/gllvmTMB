# The non-Gaussian variance-component thread — what is known, what is not, what to test next

**Date:** 2026-07-22 · **Status:** open scientific question, parked for the maintainer
**Not a release blocker.** Nothing here is new breakage; it is the existing, documented
boundary of the package written down in one place so it does not have to be reconstructed
from three register rows and a chat log.

## 1. The shape of the problem

Three independent lines point at the same boundary: **non-Gaussian variance-component
inference**, not GLLVMs in general.

| Evidence | What it shows |
|---|---|
| `CI-08` (register :411) | M3.3 production coverage run: 15/15 jobs ran, **only Gaussian d=1 and Gaussian d=3 cleared the 94% gate; 13/15 cells remain below**, 236/3000 replicate fits failed. Recorded as `partial` — *production gate failed*. |
| `R-2` | Phylogenetic slope variance under binomial-logit over-estimated ~50–80%. **Does not shrink with n** (60/120/240 species all fail) on otherwise healthy fits. The *identical* fixture recovers cleanly under Gaussian. |
| `R-7` site (d) | nbinom2 × spatial: `log_tau_spde` effectively unidentified — one negative diagonal at −3.518e10, Hessian not positive-definite. Measured directly, not inferred. |

**The Gaussian control is the load-bearing fact.** Same design, same engine, same fixture —
Gaussian recovers, binomial-logit does not. That rules out a parser or engine regression and
localises the problem to the non-Gaussian likelihood.

## 2. Why "just implement EVA" is probably the wrong lever

`R-2`'s diagnosed root cause is **information starvation**, not approximation error. With 12
single-Bernoulli observations per species, the sampling variance of a per-species slope is
≈ `(pi^2/3)/12 ≈ 0.27` against a true between-species variance of `0.30` — **roughly half the
observed spread across species is sampling noise.** A partially-correcting estimator then
returns an inflated variance.

That is a property of **the likelihood**, not of how well we approximate it:

1. **A variational approximation approximates the same integral. It does not create
   information the data do not contain.**
2. **The sign is wrong.** VA characteristically biases variance components *downward*; the
   observed bias here is *upward*.
3. **Design 85 is a closed NO-GO on its own terms** — unproven with a known numerical
   weakness; its predeclared Gate-3 experiment was never obtained, and 8 applicable q1/q2
   fits failed the optimiser gate. It is an open research question that already failed once,
   not a shovel-ready fix.

**Epistemic status: AGENT-INFERRED.** Reasoned from the register and from this arc's
measurements. No Laplace-vs-VA comparison has been run in *this* package. Treat as a strong
hypothesis, not a result.

## 3. The better-evidenced lever: AGHQ

Laplace being inaccurate for binary and low-count responses with few observations per random
effect is standard; **adaptive Gauss-Hermite quadrature is the standard remedy**, and the
cross-repo record already supports it — drmTMB tracks a `glmer` oracle **to four decimals** on
exactly this class of problem.

This repository **already carries AGHQ scaffolding**: `test-aghq-o3-gllvmtmb-unit-hook`,
`test-aghq-o3-q2-coupled-spike`, `test-aghq-o3-scalar-spike`, and a substantial
`aghq-r2-reference-harness`. So the shortest credible path is to exercise what exists, not to
revive a closed NO-GO.

## 4. THE UNEXPLAINED PART — the cross-repo sign anomaly

This is the loose thread most worth pulling, and it is genuinely unresolved.

- **drmTMB** (validated against a `glmer`/lme4 **oracle**, single-trial Bernoulli, M=40, 80
  seeds): as information per cluster falls, the bias goes **monotonically more negative** —
  `n_each` 20/8/4/2 → **+0.32%, −9.88%, −13.68%, −23.14%**. drmTMB matches the oracle to four
  decimals.
- **gllvmTMB** sits *inside* that same low-information region and measures the bias going
  **UP**.

**Opposite sign, not merely larger magnitude.** The obvious explanation — that the bias flips
direction at very low information — was **tested against drmTMB's retained artifacts and
REFUTED the same day**.

**The leading remaining candidate:** drmTMB's sweep measured a random **intercept**. The
gllvmTMB cell that fails is a **correlated `(1 + x | species)` intercept-and-slope 2×2 block**
(`rho = 0.5`) — *a structure drmTMB has never measured.*

### The experiment that would settle it

Small and well-posed: fit the **same correlated 2×2 intercept-slope block** in a regime where
`glmer` can arbitrate, and compare gllvmTMB's Laplace estimate against the oracle.

- If gllvmTMB matches the oracle → the upward bias is a **real property of correlated blocks
  under low information**, and the package is behaving correctly at a hard boundary.
- If it does not → it is a **gllvmTMB defect**, and the sign anomaly is the symptom.

Either outcome is publishable-quality information about the estimator, and it decides whether
any of this is an engineering task at all.

**Note the glmer boundary:** `glmer` handles a correlated random intercept+slope for a *single*
response. The gllvmTMB cell is multi-trait and phylogenetically structured, so the honest
comparison is a **reduced** cell — one trait, no phylogeny, same 2×2 block — chosen so the
oracle is valid. Matching a reduced cell would not by itself clear the full phylogenetic
multi-trait case.

## 5. What this does NOT cover

- No experiment has been run. Every causal claim above is inference from existing artifacts.
- It does not establish that AGHQ would fix `R-2` — only that it is the better-supported
  hypothesis than VA.
- It says nothing about the **spatial** cell (`R-7` site (d)); an unidentified `log_tau_spde`
  is plausibly a separate identifiability problem, not the same information-starvation story.
- It does not revisit the `CI-08` coverage campaign, which is gated compute and D-50 territory.

## 6. Documentation recommendation (maintainer's call, not taken)

`NEWS.md:74–103` already documents the `R-2` case well — data-regime framing, all three
measured figures including the intercept bias, the no-shrinkage-with-n finding, the Gaussian
control, and a plain "do not read these as calibrated".

What is missing is **one general statement of the boundary** rather than a single worked
example. Suggested substance, for the maintainer to word and approve:

> Variance-component **point estimates** are the supported claim for non-Gaussian families.
> **Interval calibration** is established only for the Gaussian cells that cleared the
> coverage gate.

Not written into `NEWS.md` by the agent: it is a release-level claim about the whole package.

> Related: `docs/dev-log/known-residuals-register.md` (R-2, R-7, CI-08) ·
> `docs/design/35-validation-debt-register.md:411` ·
> `docs/design/75-inference-route-truth-matrix.md:99`
