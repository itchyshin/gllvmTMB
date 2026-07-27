# For Ayumi — where VA stands for your model, and one caution that applies now

**Status: DRAFT for Shinichi.** Not sent. Nothing here should reach Ayumi until
Shinichi has read it, and the coverage number in §4 is not yet in.

Context: BIRDBASE_pcm issue #3, the all-species two-level GLLVM — 5,397 species,
27 responses, `missing = miss_control(response = "include")`, Clements 2024 tree.

---

## 1. The short version

We have been building a second estimation engine (a variational approximation,
"VA") so that a gllvmTMB fit can be checked against an independent algorithm
rather than trusted on its own. **It cannot fit your model, and it will not be
able to for some time.** That is worth saying plainly rather than letting you
wait for it.

But the work produced **one finding that applies to the fit you are running
today**, and that is §3. If you read only one section, read that one.

## 2. Why VA cannot fit your model

Your 27 responses against what the VA engine currently admits:

| Your model needs | VA admits | |
|---|---|---|
| binomial **probit** × 20 | binomial **logit** only | ✗ |
| lognormal × 3 | — | ✗ |
| ordinal probit × 1 | — | ✗ |
| gaussian × 2 | gaussian (internal calls only) | ~ |
| retained response missingness | requires one complete observation per unit-trait cell | ✗ |
| **phylogeny** | structured covariance rejected outright | ✗ |
| n = 5,397 | does not complete beyond n ≈ 2,500 | ✗ |

So VA reaches **2 of your 27 responses**, and cannot express the phylogeny or
the missingness at all — which are not incidental to your analysis, they are the
analysis. A VA fit on what remains would not be a second opinion on your model;
it would be a different model.

The two structural blockers (phylogeny, missingness) are harder than the family
gaps and are not scheduled. The family gaps are tractable — the engine was just
restructured so that adding a family is a declaration plus one likelihood
function — but probit alone would still leave the structural blockers standing.

**Recommendation: do not wait for VA.** Continue with Laplace.

## 3. The caution that does apply — convergence flags can be clean on a broken fit

This is the part that matters for your current work.

Across a 640-cell simulation grid, gllvmTMB's own Laplace route produced
degenerate fits — fits where the latent covariance had genuinely collapsed or
was unidentified — and **59 of 70 of those reported `convergence = 0` together
with `pdHess = TRUE`.** Both flags clean, simultaneously, on a fit that was
broken.

That is not a criticism of Laplace specifically; it is a property of reading
optimiser output as if it were a model diagnostic. But the practical consequence
for you is direct: **on a model of your size and complexity, `convergence = 0`
and a positive-definite Hessian are not sufficient evidence that the fit is
sound.**

What we suggest checking in addition, none of which is expensive:

1. **The gradient at the optimum** — near-zero componentwise, not just a small
   objective change. A stalled optimiser and a converged one look identical in
   `convergence`.
2. **The smallest eigenvalue of the Hessian**, not merely whether Cholesky
   succeeded. `pdHess = TRUE` can hold with an eigenvalue near machine zero,
   which is a ridge, not a maximum.
3. **Refit from several starting values** and confirm the objective agrees.
   Multi-start disagreement is the cheapest degeneracy detector there is, and
   with 27 responses and a rank-2 or rank-3 latent structure there is real scope
   for multiple optima.
4. **Look at the fitted Σ for near-zero eigenvalues / a collapsed trait.**
   Degeneracy in our grid showed up as variance collapsing toward zero long
   before any flag changed.

If a trait's unique variance has gone to the boundary, that is worth knowing
before interpretation, not after.

## 4. What we cannot tell you yet

- **No calibrated intervals, from either engine.** VA's standard errors were
  only built today and carry `calibrated = FALSE`; the coverage study is
  running. gllvmTMB's intervals are point-estimate-supported only — no cell has
  certified coverage. Treat all interval widths as indicative.
- **How much this matters at n = 5,397.** Our grid tops out far below your size.
  The degeneracy rate at your scale is unmeasured, and we should not extrapolate.
- **Whether the diagnostics in §3 would have caught the specific failures.**
  Our degeneracy detector's headline accuracy is an in-sample figure and has not
  been validated out of sample.

## 5. What we would find useful from you

If you are willing, the single most useful thing would be the **gradient vector
and the Hessian eigenvalue spectrum** from your current fit — not the data, just
those diagnostics. A real model at n = 5,397 with 27 mixed-family responses is
far beyond anything in our grid, and it would tell us whether the degeneracy
pattern we see in simulation appears at that scale.

---

*Prepared 2026-07-27. §3's 59/70 figure was independently re-verified against
the grid's raw per-fit status construction after a substring-matching bug was
found in the summary script; the figure survived that check. A separate
comparison against the `gllvm` package is being re-scored and is deliberately
not reported here.*
