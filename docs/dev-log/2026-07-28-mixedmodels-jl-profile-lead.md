# MixedModels.jl as prior art for the Σ-interval problem — 2026-07-28

Pointer from Shinichi: <https://github.com/JuliaStats/MixedModels.jl>. Claims below verified
against the package's own API documentation (<https://juliastats.org/MixedModels.jl/stable/api/>),
not from memory. **Status: UNVERIFIED against the source itself — API docs read, code not read.**

## Why this matters today

Three of this arc's dead ends have a counterpart in MixedModels.jl that is *not* dead.

### 1. 🔴 The "no finite boundary" blocker is a PARAMETERISATION CHOICE, not a law

S4b's blocking finding was that gllvmTMB parameterises variances as **log-SD**
(`src/gllvmTMB.cpp:995`, `sd_B = exp(theta_diag_B)`), so SD = 0 sits at **−∞** and "the optimum is
at the boundary" has no implementation.

MixedModels.jl does not have this problem, because it does not make that choice:

> `lowerbd(m::LinearMixedModel)` returns "the vector of **canonical lower bounds** on the
> parameters, `θ`"

and `profile()` continues *"until reaching a parameter bound or |ζ| exceeds `threshold`"*.

Its θ (the relative covariance factor) carries **finite** lower bounds — 0 on the diagonal — so
hitting the boundary is an observable, finite event. The completeness critic on the reframe panel
asked whether anyone had considered "changing the parameterisation so the boundary becomes
finite". **This is the existence proof that it works in a production mixed-model package.**

**Obstacle, stated plainly:** gllvmTMB's parameterisation is set in the TMB `.cpp`, so this is a
C++/model change with wide blast radius (every `theta_*` consumer, every extractor, the AGHQ
engine, all stored fits). It is a *lead*, not a cheap fix. But it converts S4b's "unimplementable"
into "implementable at a cost we have not yet priced".

### 2. `issingular()` is the missing optimizer-status ledger — and it sidesteps the real obstacle

> `issingular(m::MixedModel, θ = m.θ; atol::Real = 0, rtol::Real = ...)` tests "whether the model
> `m` is singular if the parameter vector is `θ`". Also defined for bootstrap collections.

`R/profile-route-matrix.R:136-137` names "an exposed optimizer-status ledger" as a required, missing
gate. S4b found the obstacle is that `TMB::tmbprofile()` **discards** its inner optimizer's
convergence code, returning only two columns.

`issingular()` shows that obstacle is avoidable: it is a **parameter-space** predicate — is θ at its
bound? — not an optimizer-internals predicate. You never have to ask the optimizer. Given finite
bounds (§1), the ledger is computable from θ alone.

### 3. `threshold = 4` on |ζ| — the same lesson as today's `e34176eb`, arrived at independently

`profile(m; threshold = 4)`. ζ is the signed square root of the LR statistic, so |ζ| ≤ 4 is a
deviance budget of ~16 — against ζ ≈ 1.96 for a 95% interval. **A budget roughly four times the
crossing point.**

Today's fix (`e34176eb`) set our budget to `crit + 1` after measuring that `crit` alone could not
bracket the crossing. MixedModels reaches the same conclusion far more generously. **Our margin of
1 is defensible but is the low end**; if the truncated-terminus rate proves high in practice, this
is the dial to turn, and there is precedent for turning it hard.

### 4. Interpolation splines, not linear interpolation on the deviance scale

> `MixedModelProfile{T}` — "a likelihood profile … including associated **interpolation splines**",
> with `confint(pr::MixedModelProfile; level = 0.95)`.

`.profile_bounds()` (`R/profile-ci.R`) linearly interpolates the sign change **on the deviance
scale**. MixedModels interpolates a spline **on the ζ scale**, where a near-quadratic log-likelihood
is close to *linear* — so interpolation error is far smaller for the same number of profile points.

This is the cheapest of the four to adopt and needs no parameterisation change: compute
ζ = sign(θ − θ̂)·√(2·(ℓ̂ − ℓ)) and interpolate there. It would improve bound accuracy at
identical compute cost.

## What this does NOT change

- It does **not** revive the boundary-correction plan. S2's arithmetic stands: χ̄²'s crit (2.706) is
  *below* χ²₁'s (3.841), so the mixture narrows intervals and worsens under-coverage. That is
  independent of parameterisation.
- It does **not** make us first. Combined with the SAS GLIMMIX `COVTEST … CL / TYPE=PLR` finding
  (factor-analytic `FA(q)`/`FA0(q)`, Jennrich & Schluchter 1986), the profile-a-covariance problem
  is well-trodden.
- MixedModels.jl profiles **σ, β and variance components of a mixed model**, not a low-rank
  Σ = ΛΛ' with rotation indeterminacy. The hardest part of our problem — choosing rotation-invariant
  Σ-functionals as targets — is not solved there.

## Recommended order, if this is pursued

1. **ζ-scale interpolation** — cheap, local to `.profile_bounds()`, no API change, testable on
   synthetic traces exactly as today's terminus tests are.
2. **Price the parameterisation change** — a read-only scoping pass over every `theta_*` consumer
   before anyone commits to it.
3. **Boundary ledger** — only meaningful after (2), since it depends on finite bounds existing.

Licence note: MixedModels.jl is MIT. Any *ported* code needs provenance in `inst/COPYRIGHTS` per
CLAUDE.md's reuse rule. Reading it for design ideas does not.
