# DRAFT for review — what users should be told about loading runaway

**2026-07-31 · Claude (Fable 5) · 🔴 DRAFT. Not shipped to any user-facing surface.**
**Reader-facing content is reviewed one-by-one with Shinichi (CLAUDE.md). This is the
proposed text and the evidence behind it, for that review — not a merged doc.**

---

## Why users need this at all

From the 12,000-fit campaign (binomial, p = 6, q = 2, all-fits):

| σ_λ | n = 100 | n = 400 | n = 1600 |
|---|---|---|---|
| 1 | 49% | 13% | 6% |
| **3** | **99%** | **99%** | **98%** |

That is the **runaway rate under plain `gllvmTMB()` defaults** — fits whose estimated
loading norm exceeds twice the truth. At realistic loading sizes it is **the common case, not
the edge case.**

And the fit does not look wrong: `convergence = 0`, a positive-definite Hessian, no warning.
The user has no signal unless we give them one.

---

## Proposed user-facing text

> ### Checking for runaway loadings
>
> In latent-variable models with binary data, the likelihood can be nearly flat in the
> direction that inflates the loadings, and the optimiser can settle on a solution with
> implausibly large loadings while reporting every conventional sign of health —
> `convergence = 0` and a positive-definite Hessian. This is a property of the model and the
> data, not a bug, and it is **common** rather than exceptional when the true trait
> correlations are strong.
>
> **How to check.** Run `gllvmTMB_diagnose(fit)`, which reports the implied loading scale and
> flags implausible values. As a quick manual check, the latent standard deviations implied
> by the fit should be comparable to the variation you would expect on the link scale — a
> logit-scale loading of 1 moves occurrence from about 0.27 to 0.73 across ±1 SD; a loading
> of 10 saturates.
>
> **What to do if it has run away.** Add a penalty on the loadings:
>
> ```r
> fit <- gllvmTMB(..., control = gllvmTMBcontrol(aghq_ridge = 2))
> ```
>
> This is a Gaussian prior with standard deviation `tau` on each loading and it substantially
> reduces runaway. **Two honest limits:**
>
> - A penalised fit is a **maximum-a-posteriori estimate, not a maximum-likelihood one**, so
>   `logLik()`, `AIC()` and `BIC()` no longer mean what they usually mean. Set
>   `aghq_ridge = Inf` and refit if you need likelihood-based comparison.
> - `tau` is a **fixed** value on the scale of the loadings themselves, so it is not
>   automatically right for your data. If your true loadings are much smaller than `tau` the
>   penalty is inert; if much larger, it shrinks them — and in our testing the default
>   `tau = 2` did not prevent runaway in every regime. **Inspect the fit after penalising;
>   do not assume the penalty has fixed it.**
>
> We are actively working on making `tau` adapt to the data. Until then, treat the penalty
> as a tool you check the result of, not one you set and trust.

---

## What this text deliberately does NOT say

- **It does not recommend `aghq`.** AGHQ only runs on the loadings-only grammar
  (`latent(..., unique = FALSE)`), so it is not available to most users, and its advantage is
  not established as an estimator claim.
- **It does not promise the ridge works.** It measurably does not, at n = 1600, σ_λ = 3
  (67% runaway). Telling users "add the ridge and you're fine" would be false.
- **It makes no comparative claim about AGHQ vs Laplace.** That remains unestablished.

## Open question for the review

Should `gllvmTMB()` **warn by default** when the fitted loading scale is implausible? The
evidence says the failure is common and silent, and detection is cheap and reliable
(the loading norm is right there). My view: **yes, warn — but do not auto-fix**, because
today's penalty has a measured failure regime and a fix users trust that silently fails is
worse than no fix. That is the #847 sequencing.
