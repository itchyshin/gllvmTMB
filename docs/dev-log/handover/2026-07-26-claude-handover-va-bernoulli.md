# Session Handoff — VA implementation arc: objective VERIFIED, Bernoulli widening PROHIBITED

**Meta:** written 2026-07-25 overnight · author = Claude · target = Shinichi + next Claude ·
**read the first section before anything else.**

---

## 🔴 DECISION NEEDED BEFORE ANY MORE VA WORK

**Design 85 §10 "Prohibited interpretations and outputs" forbids the thing we did last night.**
`docs/design/85-highdim-nongaussian-va-formal-contract.md:338-339`, verbatim:

> *"widening to **Bernoulli**, incomplete responses, mixed families, alternative links, structured
> sources, random slopes, or public syntax by analogy"*

The Bernoulli unblock on `claude/va-implementation-20260725` (`2392996b`) does exactly that. Its
reopening condition (`docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md:75-76`) requires *"a
genuinely new evidence source identifies a tractable alternative **and the maintainer approves a new
formal contract**"* — reusing va-r3's *code* does not exempt new work from a new contract.

**You authorised implementation in good faith; §10 was not surfaced to you, and I did not know it
either.** Nothing is merged, nothing is live, the branch is marked DO-NOT-MERGE.

**Your call, one of three:**
1. Approve a new formal contract for a Bernoulli VA arc (§10's own escape hatch), or
2. Revert the source change and keep only the research evidence, or
3. Park it — the evidence stands on its own either way (see below).

---

## The measurement that matters most

An **independent** 15-rep sweep (fresh seeds, fresh fixture, fresh truth code, no reuse of the
implementer's work) found:

> **The prototype's own domain gate refuses the regime that justifies the entire VA programme.**

`variance_domain_ok <- max_projected_variance <= 4` (`R/va-r3-proto.R:648`) returned `healthy` in
only **5 of 15** reps:

| sparsity | healthy | max projected variance |
|---|---|---|
| p̄ ≈ 0.35 | 4/5 | 4.20 |
| p̄ ≈ 0.18 | 1/5 | 5.95 – 7.36 |
| **p̄ ≈ 0.09** | **0/5** | **14.71 – 27.01** |

**Design 86's admission band is p̄ ∈ [0.03, 0.10]** — precisely where nothing is healthy. Every VA
"win" measured at p̄ ≤ 0.18 came from a fit the prototype itself marks `failed_variance_domain`.

**Removing the `n_trials` guard does not make the prototype reach sparse binary.** A second gate
stands behind it, and a third: sparse fixtures routinely produce all-zero trait columns (genuine
separation), so a separation guard must refuse *more* often exactly as the data approach the target.

## What IS established (independently verified, survives the NOT_SOUND verdict)

- **The VA objective is correct.** Both terms — closed-form KL and the Gauss-Hermite expectation —
  match the template to **machine precision**. `dev/va-elbo-bisection-RESULTS.md`.
- **The ELBO is a valid lower bound**, at multi-trial *and* at Bernoulli: **14/14** independently
  computed ELBO−truth gaps negative (worst −0.0693, largest −0.7509).
- **VA is closer to truth than Laplace, in direction**: 9 of 10 verdict-eligible reps.
- **`n_trials >= 1` is mathematically admissible**: `log C(1,y) = 0` exactly for y ∈ {0,1}, and
  `va_r3_softplus_expectation()` never receives `n`, so quadrature accuracy is independent of
  `n_trials` **by construction** (`inst/tmb/gllvmTMB_va_r3.cpp:288`). The old `n >= 2` bound was a
  **scope choice** — no corpus document records any mechanism for it.
- **Instruments were validated, not trusted**: brute-force GH truth vs nested adaptive
  `stats::integrate` (1.3e-15–5.3e-15); TMB ELBO re-derived in independent R (8.2e-13); Laplace
  re-implemented independently (2.1e-11).
- **Laplace's error changes SIGN with sparsity** — 5/10 eligible reps below truth, 5/10 **above** by
  up to **+3.38 nats** — while the ELBO stayed a valid bound throughout. Laplace stops being
  conservative at sparse binary; the bound does not. *This is the most genuinely promising VA
  argument produced all day, and it is qualitative rather than a magnitude claim.*

## What the adversarial review killed

Verdict **NOT_SOUND**, 9 problems. The load-bearing ones:

- **"19.5× closer than Laplace" is one seed, one cell.** Independent measurement: 9.7× and 14.9× on
  its own cell, median 11.0× moderate, **4.15× sparse** — and one rep (seed 202, p̄ = 0.2333) where
  **Laplace was closer** (0.78×). Direction replicates; **the multiplier does not**.
- **The VA advantage SHRINKS as data get sparser** — the *opposite* of the programme's motivation.
- **"The verification instrument survives" is false in the regime that matters.** At p̄ = 0.1028 the
  brute-force ladder does **not** converge (H = 151/301/501/801 → −212.997 / −217.984 / −214.919 /
  −216.638), and the gllvmTMB Laplace comparator itself diverges there (convergence 0, max|grad|
  4.6e-06, but Λ entries 13–70, Σ_B diagonal 2938–6788, reporting logLik −69.14 where truth ≈ −113).
- **The separation guard is defective and creeps.** It computes `converged` and never consults it;
  it varies `maxit` and `epsilon` *together* so its "drift" isn't attributable to tolerance; and it
  is called on the **whole binomial branch** unconditional on `n_trials`, so it can refuse
  `n_trials >= 2` designs the frozen prototype previously accepted — including Gate-2/Gate-3
  fixtures. **This is a regression risk on a validated path** and is reason enough not to merge.

## Landing state — 5 branches, 3 PRs, nothing merged

| Branch | PR | State |
|---|---|---|
| `claude/ayumi-usability-fixes-20260725` | **[#791](https://github.com/itchyshin/gllvmTMB/pull/791)** | ready — FAIL 0 |
| `claude/getlv-score-se-20260725` | **[#792](https://github.com/itchyshin/gllvmTMB/pull/792)** | ready — FAIL 0, freeze intact |
| earlier arc handover | **[#790](https://github.com/itchyshin/gllvmTMB/pull/790)** | ready |
| `claude/va-implementation-20260725` | none | **DO NOT MERGE** — §10 |
| `claude/eva-record-consolidation-20260725` | none | record rejected NOT_ESTABLISHED; needs a second pass |

Today's earlier arc (bug fixes, gllvm comparators, 5×3 grid correction) is **already on `main`**,
`a0f568d1..84ca8290`, full suite 7373 pass / 0 fail.

## Open decisions for you

1. **§10** — new contract, revert, or park (above).
2. **PR #791 / #792** — the only judgement calls are the new error's wording and the `getLV`
   user-facing argument + NEWS entry.
3. **`getLV` docs**: I suggested but did **not** add a line saying the SEs are **not
   coverage-validated**. Given CI-08 (13/15 cells below 94%) and the `wald_sdreport_no_ci_validation`
   flag elsewhere, one sentence would match your own standard.
4. **AGHQ** — I twice called it a usable oracle. It is not: `INFRASTRUCTURE_INCOMPLETE`, uncertified,
   external comparator only at q=1, fenced from repair. Making it usable is its own approved arc.

## What I'd do next, if the §10 decision is "proceed"

**Not more Bernoulli.** The blocker isn't the family guard, it's the **variance-domain gate**. The
honest next question is: *is `max_projected_variance <= 4` a real numerical limit, or another scope
choice like `n >= 2` turned out to be?* If it's a scope choice the target regime may be reachable;
if it's a genuine stability limit, the va-r3 route **cannot** serve sparse binary and a different
objective is needed — which is exactly what Design 86 was for.

That question is cheap to answer and decides whether this route has a future.

## Standing cautions (do not lose these)

- **No SEs from the VA Hessian** — §10 prohibits treating the inverse VA Hessian as calibrated
  frequentist uncertainty. Flagged as "the single most likely thing a VA implementer will build next".
- **No `logLik`/AIC/BIC/LRT from an ELBO**, and **no comparing ELBOs across ranks** (§85:325-330).
- **Compare against TRUTH, never against Laplace.** I made that exact error yesterday and it produced
  a wrong diagnosis that stood for an hour.
- **Every synthesis I ran was rejected by its adversarial reviewer, and every distortion leaned
  optimistic.** Two workflows, two rejections. Keep the adversarial step.
