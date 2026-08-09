# Design 104 — VA/EVA family coverage: one quadrature, many families

**Status:** historical architecture amended by Designs 108 and 110. The package
now exposes an opt-in, experimental `integration = "va"` route, while Laplace
remains the default. Design 110 and its Gate-E receipt are canonical for the
current scalar-family registry and H = 7 default. This document authorises no
accuracy, interval-calibration, or general-inference claim.

**Context.** Shinichi, 2026-07-26: *"match Laplace capabilities … I am flexible
about our VA families — as long as it is well documented and make the default
most reasonable."* This document fixes the architecture and the defaults, and
records the measurements they rest on.

## 1. The structural shortcut

In a GLLVM every family sees the latent variable **only through a scalar linear
predictor**

```
eta_ij = x_ij' beta + lambda_j' u_i ,     u_i ~ N(0, I_q)
```

Under a Gaussian variational family `q(u_i) = N(m_i, S_i)`, `eta_ij` is
univariate Gaussian with

```
mu_ij = x_ij' beta + lambda_j' m_i        v_ij = || L_i' lambda_j ||^2
```

so the only quantity any family needs is the **one-dimensional expectation**

```
E_q[ log p(y_ij | eta_ij) ] ,   eta_ij ~ N(mu_ij, v_ij).
```

**Therefore one 1-D Gauss-Hermite routine covers the entire family surface.** A
new family supplies `log p(y | eta)` and nothing else — no per-family bound, no
per-family derivation. This is what makes "match Laplace capabilities" tractable
rather than ~20 bespoke variational derivations.

## 2. Three evaluation tiers

| Tier | When | Cost | Accuracy |
|---|---|---|---|
| **EXACT** | the expectation has a closed form | cheapest | exact |
| **GH** | it does not | 1-D quadrature | tight, tunable |
| **EVA** | quadrature is unattractive, or as a fast path | closed form | 2nd-order Taylor surrogate |

**Exact and GH registry (superseded by measurement).** Design 110 and its
Gate-E receipt now replace the speculative family lists in this document. All
18 scalar family/link cells were attempted. Gaussian, Poisson, lognormal, and
Gamma use exact expectations; delta-lognormal and delta-Gamma use hybrid
exact/GH expectations; the remaining scalar cells use ordinary one-dimensional
GH with H = 7. This establishes arithmetic, compiled reachability, and light-fit
admission only—not broad recovery or interval calibration.

**EVA.** Second-order Taylor about `mu`:
`E[log p] ~= log p(y|mu) + (v/2) * d2/deta2 log p(y|eta)|_mu`. Cheap, and the
only route for families where even 1-D quadrature is awkward. It is a
**surrogate, not a bound** — it can sit either side of the truth.

## 3. What `gllvm` actually does (verified, not inferred)

`gllvm` 2.0.13 `src/gllvm.cpp:3271-3273`:

```cpp
Type wij = 0.5*sqrt(eta(i,j)*eta(i,j) + 2*cQ(i,j));
nll -= (y(i,j)-Ntrials(i,j)*0.5)*eta(i,j) - Ntrials(i,j)*logspace_add(wij, -wij);
```

This is the **Jaakkola–Jordan / Pólya-Gamma bound**: `wij = xi/2` with
`xi^2 = E_q[psi^2]`; `(y - N/2)` is the PG `kappa`; `logspace_add(w,-w) =
log(2 cosh(xi/2))`. So `gllvm`'s binomial `method="VA"` should be called **JJ**,
not VA — labelling it "VA" is what makes "EVA looks better than VA" seem
plausible when it is not.

Established with citations (notebook `89d8ce4a`): JJ **is** Pólya-Gamma
mean-field VB — they coincide update for update — and both are **strictly
looser** than Gauss-Hermite under the same Gaussian `q`, the slack being
`KL[PG(1,xi) || PG(1,psi)]`. Measured consequence: our binary ELBO sits **3–5
nats above** `gllvm`'s across 4/4 seeds, one-directionally. A tighter bound, not
a bug.

**Do not adopt the parked `design94/95/96` JJ prototypes.** They implement
`omega = tanh(xi/2)/(4*xi)`, the JJ coefficient at half the PG convention — the
same method, and looser than what we already have.

## 4. Defaults, and why

1. **Laplace stays the package default.** ~~0.6 ships Laplace-only. VA/EVA are
   internal research with no user-facing route.~~
   **AMENDED AGAIN BY DESIGN 110.** Laplace remains the **default**, while 0.6
   exposes an opt-in, hard-fenced `integration = "va"` route for the 18 scalar
   family/link cells in the Gate-E registry. The public route is restricted to
   the documented ordinary loadings-only grammar with `d <= 2`, `p <= 80`, and
   `n >= 100`. Gate E establishes compiled reachability and light-fit admission,
   not broad accuracy; intervals remain unavailable and
   `calibrated = FALSE`. The earlier `engine = "va"`, two-family, `q <= 4`
   paragraph was a superseded staging state, not current API truth.
2. **Within VA: EXACT where it exists, GH otherwise.** Poisson and Gaussian take
   the closed form — accuracy is free there, so there is no tradeoff to expose.
3. **GH order: `H = 7` in the current public route.** Design 110 supersedes the
   earlier H = 15 proposal: its H ladder and Gate E admitted H = 7 as the
   automatic scalar-family GH order, while H = 61 remains a diagnostic. The
   earlier interleaved H = 15 versus H = 61 Bernoulli benchmark remains useful
   historical timing evidence, but it is not the current default or a list of
   the only permitted orders. Gate E establishes compiled reachability and
   light-fit admission, not general VA accuracy or calibration.
4. **EVA is research-only and has no public estimator route.** Gate E found no
   EVA-only cell among the 18 scalar family/link cells: even Tweedie, Beta, and
   ordinal-probit reached the ordinary one-dimensional GH evaluator. This does
   not prove EVA has no future use, but it removes the old claim that those
   families require it. See Design 110 for the per-cell table and evidence.

### Measurement lesson recorded

The first H sweep ran each order **once, sequentially**, and reported `H=15` as
*slower* (20.4 s vs 9.9 s) — which briefly overturned the correct conclusion. The
confound is a **~3x first-fit-in-session penalty**: whichever order runs first
wears it. Interleaving `61, 15, 61, 15` exposed it immediately — the same `H=61`
job took 27.89 s first and 9.74 s third.

**Rule: never compare fit timings from a single sequential pass.** Interleave
replicates and report objective evaluations alongside wall clock; `evaluations`
is already in `best$evaluations` and is the confound-free signal (19 vs 28 here).

Separately, the variational parameters — `N*(2q + q(q-1)/2)` extra coordinates —
remain an intrinsic VA cost that no quadrature setting removes. Both facts hold;
only the `H` half was mismeasured.

## 5. Uncertainty — what VA does and does not give

**Only `u` carries a variational distribution.** `beta` and `Lambda` are
point-estimated; there is no `q(beta)`, so **no parameter CI can be read off the
fit**. `q(u_i) = N(m_i, S_i)` gives latent-score uncertainty, which Laplace also
supplies via mode + curvature (`getLV(se = TRUE)` already exposes it).

Design 85 §10 forbids reading the inverse VA Hessian as calibrated frequentist
uncertainty, and the notebook records that JJ/PG **severely underestimates**
posterior variance. Measured corroboration: `gllvm`'s own `sd.errors` returned
`Hessian … na/nan` and 19 negative variance estimates on ordinary simulated data.

**Wald / profile / bootstrap remain the interval routes.** VA adds no fourth one.
The genuine opportunity is that under-dispersion is *measurable*: comparing
VA/EVA/JJ interval widths against Laplace and bootstrap across a grid turns a
textbook caveat into an owned number.

### 5.1 Proposed uncertainty surface (design only — nothing implemented)

The compatibility question has a clean answer *because* VA's distribution is over
`u` and not over `beta`. That splits the surface in two, and only one half is
touched:

| Quantity | Route | Changes under VA? |
|---|---|---|
| `beta`, `Lambda`, `Sigma_B` intervals | Wald / profile / bootstrap (the existing trio) | **No.** Unchanged, and no VA-derived alternative is offered. |
| Latent scores `u_i` | `getLV(se = TRUE)` | **Same slot, different estimator.** Laplace fills it from mode + curvature; VA fills it from `S_i`. |

So VA plugs into the **existing** latent-score SE surface rather than adding a
parallel one. `getLV(se = TRUE)` keeps its signature and return shape; only the
provenance differs.

**Display rules.**
1. The returned object records **which engine produced the latent SEs**
   (`laplace` / `va_gh` / `eva`), so a printed interval is never ambiguous about
   its origin.
2. Latent-score SEs are labelled as **latent-score uncertainty**, never as
   parameter uncertainty, and never aggregated into a coefficient table.
3. No `logLik` / AIC / BIC / LRT is derived from an ELBO (Design 85 s10), so the
   VA path contributes nothing to any model-comparison display.
4. If a user asks for parameter intervals on a VA fit, the honest response is to
   route them to the trio — not to invert the ELBO Hessian.

**Why not offer VA-Hessian intervals at all.** Three independent lines say they
would be wrong: Design 85 s10 prohibits the reading; the PG literature records
severe posterior-variance underestimation; and `gllvm`'s own `sd.errors`
returned `Hessian ... na/nan` with 19 negative variance estimates on ordinary
simulated data in this session. A silently-too-narrow interval is worse than an
absent one.

## 6. Staging

| Stage | Families | Route |
|---|---|---|
| **Gate E passed** | Gaussian, Poisson, lognormal, Gamma | EXACT |
| **Gate E passed** | delta-lognormal, delta-Gamma | HYBRID exact + GH |
| **Gate E passed** | remaining 12 scalar family/link cells | GH, H = 7 |
| **blocked** | multinomial and other coupled/non-scalar likelihoods | separate design required |

Design 110 is the canonical registry. Gate-E passage is implementation and
light-fit evidence, not a general accuracy or calibration certificate.

## 7. Open, not settled here

- The **ELBO-vs-Laplace sign check** has still not been run under matched models;
  our VA fits `Lambda Lambda^T` only while `gllvmTMB_wide` adds `diag(psi)`.
- `gllvmTMB_wide(Y, family = binomial(), d = 2)` returned `logLik() = +3933.80`
  on 0/1 data. A Bernoulli log-likelihood cannot be positive; this is under
  diagnosis and may be a package defect rather than misuse.

> Related: [Design 85](85-highdim-nongaussian-va-formal-contract.md) (READ-ONLY,
> negative evidence) · [Design 86](86-eva-gate1-parameters.json) · Design 72
> (VA feasibility)
