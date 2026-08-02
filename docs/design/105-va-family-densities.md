# Design 105 — VA/EVA density spec: what each family must supply

**Status:** design, internal-research only. Authorises no export, no `method=`
argument, no public capability claim. No code, no `R/`, no `src/`, no `inst/tmb/`
change is implied by this document. `NAMESPACE c97ae039` untouched.

**Scope.** [Design 104](104-va-family-coverage.md) fixes the *architecture*: every
family sees the latent variable only through a scalar `eta_ij ~ N(mu_ij, v_ij)`, so
one 1-D Gauss-Hermite routine covers the whole surface, and a new family supplies
`log p(y | eta)` and nothing else. This document discharges that promise
family-by-family: the explicit density in `eta`, whether the expectation is closed
form, the EVA second derivative, the extra parameters, and the numerical form that
survives quadrature.

**One caveat inherited from Design 104 and repeated here because it governs
everything below:** all of this is *bound tightness and evaluation cost*. Nothing
here shows that a tighter bound gives better parameter estimates. That is a
separate, running test.

---

## 1. The per-family contract

A family is admitted to the VA/EVA surface by supplying **two scalar functions of
`eta`**, plus its own parameters:

```
g(eta)    = log p(y | eta, phi)          # the integrand
g2(eta)   = d2/deta2 log p(y | eta, phi) # the curvature
```

`g2` does **double duty** and that is the reason the contract is only two functions:

* it *is* the EVA correction — `EVA(mu, v) = g(mu) + (v/2) * g2(mu)`;
* it *is* the small-`v` branch — `E[g] = g(mu) + (v/2) g2(mu) + O(v^2 g4)`.

Everything else — the nodes, the weights, the `sqrt(2v)` scaling, the branch
switch — belongs to the shared routine and is written once.

### 1.1 The closed-form test

Before reaching for quadrature, apply this test. Under `eta ~ N(mu, v)`,

```
E[eta]        = mu
E[eta^2]      = mu^2 + v
E[exp(c*eta)] = exp(c*mu + c^2*v/2)      for any real c
```

**Therefore `E_q[log p]` is EXACT if and only if `log p(y | eta)` is a polynomial
in `eta` plus a finite linear combination of exponentials `exp(c*eta)`.** Nothing
else in the standard catalogue integrates in closed form.

This single criterion decides the tier for any future family without a derivation:

| `log p` contains | Tier |
|---|---|
| `y*eta - exp(eta)` (Poisson-log) | **EXACT** |
| `-(y-eta)^2 / 2sigma^2` (Gaussian-identity, lognormal) | **EXACT** |
| `-phi*eta - phi*y*exp(-eta)` (Gamma-log, exponential-log) | **EXACT** |
| `log(1 + exp(eta))` (any logit link) | GH |
| `log(theta + exp(eta))` (nbinom2) | GH |
| `lgamma(a + exp(eta))` (nbinom1) | GH |
| `lgamma(phi*plogis(eta))` (Beta, betabinomial) | GH |
| `log(F(c - eta) - F(c' - eta))` (ordinal) | GH |
| `log pgamma(exp(eta), L)` (censored counts) | GH |

**Two EXACT families Design 104 §2 did not list.** The `exp(-eta)` row above means
**Gamma with log link** and **exponential with log link** are closed form, not GH:

```
Gamma(log):  E[log p] = phi*log(phi) - lgamma(phi) + (phi-1)*log(y)
                        - phi*mu - phi*y*exp(-mu + v/2)
```

and **lognormal** is EXACT because it is Gaussian on `log y`. That matters for §8
(`delta_lognormal` / `delta_gamma`), where it collapses half of each family to a
closed form.

### 1.2 The small-`v` branch, generically

The shipped template (`inst/tmb/gllvmTMB_va_r3.cpp`) carries a four-term
heat-kernel expansion below `v = 1e-6`, using `f2, f4, f6` written out by hand for
softplus. A per-family hand-derived `f4` and `f6` is exactly the kind of
per-family derivation Design 104 exists to avoid.

**The expansion is not needed for accuracy — it is needed only because
`d sqrt(v)/dv` is singular at `v = 0`.** GH itself is perfectly accurate at small
`v`. So the generic contract should **lower the threshold and shorten the
expansion**, not lengthen it:

| Route | Threshold | Terms | Family must supply | Omitted `d/dv` error at threshold |
|---|---|---|---|---|
| shipped (binomial) | `1e-6` | 4 (`f2,f4,f6`) | `g2, g4, g6` | `~1e-18` |
| **generic (proposed)** | **`1e-8`** | **2 (`g2`)** | **`g2` only** | `v*g4/4 ~ 2.5e-9 * g4` |

At `v = 1e-8` the GH branch has `sqrt(2v) = 1.4e-4`; the roundoff amplification in
`dE/dv` is `~1e-16 / sqrt(2v) = 7e-13`, far below the `g2/2` signal. The shipped
binomial route is a strict superset and need not change; the generic route is what
every new family gets.

### 1.3 The cross-cutting hazard: clamps written for a point evaluation

**This is the single most likely source of silent breakage in the whole
programme.** Every guard currently in the engine — the Beta / betabinomial `mu`
clamp at `[1e-6, 1-1e-6]` (the 2026-05-15 Gauss correctness flag), the ordinal
probability clamp via `CppAD::CondExpLt` (issue #658), the count-kernel hardening
— was written for a **single evaluation at `eta = mu`**. Under quadrature the
integrand is evaluated at

```
eta_h = mu + sqrt(2v) * x_h
```

and for the physicists' rule the extreme node reaches

| `H` | max node `x_H` | reach in SD of `eta` |
|---|---|---|
| 15 | 4.500 | **± 6.4 SD** |
| 25 | 6.164 | ± 8.7 SD |
| 61 | 10.252 | **± 14.50 SD** |

**Correction (2026-08-02):** this table previously read `H = 61 → max node
~11.09 → ± 15.7 SD`. That figure was wrong. `.va_r3_gh_rule(61)`
(`R/va-r3-proto.R`) computes the physicists' Gauss-Hermite nodes via
Golub-Welsch; the actual maximum node at `H = 61` is `10.2520`, which converts
to SD-of-`eta` reach as `10.2520 * sqrt(2) = 14.4985 ≈ ± 14.50 SD` (verified
by direct recomputation of the same eigendecomposition this session). This
matches the comment already present at `inst/tmb/gllvmTMB_va_r3.cpp:122`
("+/- 14.50 SD at H = 61"), which the design doc had drifted out of sync
with. The `H = 15` and `H = 25` rows were independently re-verified and are
correct as stated.

Two consequences, both non-obvious:

1. **Every clamp must move inside the integrand**, applied at each node. A clamp on
   `mu` does nothing for a node 6 SD away.
2. **Raising `H` makes boundary hazards worse, not better.** `H = 61` probes ~14.5
   SD out, where `plogis(eta)` underflows, `pgamma` underflows, and CDF differences
   cancel completely. This is an argument *against* `H = 61` as anything but a
   diagnostic, independent of the timing argument in Design 104 §4.

---

## 2. nbinom2 — log link, quadratic mean-variance

**(d) Parameters.** `mu` on log link; `sigma` on log scale, internal size
`theta = 1/sigma^2` (registry line 178; `03-likelihoods.md` "Negative binomial 2").
`theta` does **not** depend on `eta`. Work with `log_theta = -2*log_sigma` — never
form `theta` and `exp(eta)` separately.

**(a) Density.**

```
mu_y = exp(eta),   Var(y) = mu_y + mu_y^2 / theta

log p(y|eta) = lgamma(y+theta) - lgamma(theta) - lgamma(y+1)
             + theta*log(theta)
             + y*eta - (y+theta)*log(theta + exp(eta))
```

**The `eta`-dependent part reduces to softplus.** Since

```
log(theta + exp(eta)) = log(theta) + softplus(eta - log(theta))
```

we get

```
g(eta) = y*eta - (y+theta)*softplus(eta - log_theta) + const(y, theta)
```

**(b) Closed form? NO** — `softplus` fails the §1.1 test. **GH.**

But the expectation is *the routine that already exists*:

```
E[g] = y*mu - (y+theta)*E[softplus(eta')] + const,    eta' ~ N(mu - log_theta, v)
```

`va_r3_softplus_expectation(mu - log_theta, v, nodes, weights)` — **unchanged, no
new integrand**. nbinom2 is a two-line addition to the binomial path, not a new
family kernel. This is the strongest single piece of evidence for the Design 104
architecture and it should be the first family implemented.

**(c) EVA term.** With `s = plogis(eta - log_theta) = mu_y/(theta + mu_y)`:

```
g'(eta)  = y - (y+theta)*s
g2(eta)  = -(y+theta) * s * (1-s)
         = -(y+theta) * theta * exp(eta) / (theta + exp(eta))^2
```

so `EVA = g(mu) - (v/2)*(y+theta)*s(mu)*(1-s(mu))`.

Sanity: `theta -> Inf` gives `g2 -> -exp(eta)`, the Poisson curvature. At `y = mu_y`
it is `-1/(1/mu_y + 1/theta)`, the harmonic mean of mean and size — always a
downward correction, and always smaller in magnitude than Poisson's, which is the
right qualitative behaviour for an overdispersed count.

**Note the `y`-dependence.** For a *canonical* link `g2 = -Var(y|eta)`, independent
of `y`. The log link is not canonical for NB2, so `g2` carries `y`. EVA's
correction is therefore observation-dependent here in a way it is not for Poisson
or binomial. Not an error — but it means an EVA-vs-VA discrepancy will scale with
the spread of `y`, which is where to look first if EVA misbehaves on counts.

**(e) Hazards.** `exp(eta)` overflows at `eta > 709`; the softplus form never
exponentiates a positive argument and removes the hazard entirely. Do **not**
compute `theta + exp(eta)` directly at quadrature nodes. `theta` from
`1/sigma^2` overflows for small `sigma` — keep `log_theta` and never exponentiate
it.

---

## 3. nbinom1 — log link, linear mean-variance

**(d) Parameters.** `mu` on log link; `sigma` on log scale, `Var(y) = mu_y*(1+phi)`
with `phi = sigma` (registry line 177; `03-likelihoods.md` "Negative binomial 1",
which states `Var = mu(1+sigma)`). **Confirm this against the shipped kernel before
implementing** — nbinom1's dispersion convention differs between `glmmTMB` and some
texts, and the whole derivation below is `phi`-convention dependent.

**(a) Density.** NB with `size = mu_y/phi`. Write `a(eta) = exp(eta)/phi`. Then
`mu_y/(mu_y+size) = phi/(1+phi)` and `size/(mu_y+size) = 1/(1+phi)`, **both free of
`eta`**, which collapses the density to

```
log p(y|eta) = lgamma(y + a) - lgamma(a) - lgamma(y+1)
             - a*log(1+phi)
             + y*(log(phi) - log(1+phi))

g(eta) = lgamma(y + a) - lgamma(a) - a*log(1+phi) + const(y, phi),
         a = exp(eta - log(phi))
```

**(b) Closed form? NO.** `lgamma(y + exp(eta))` fails §1.1 decisively. **GH.**

This is the first family where `eta` enters the *shape*, not just the mean. It is
still a scalar function of `eta`, so the architecture holds — but it is the first
family that needs its own integrand, and it is the most expensive one on the list
(two `lgamma` calls per node).

**(c) EVA term.** With `da/deta = a`:

```
g'(eta)  = a * [ digamma(y+a) - digamma(a) - log(1+phi) ]
g2(eta)  = a * [ digamma(y+a) - digamma(a) - log(1+phi) ]
         + a^2 * [ trigamma(y+a) - trigamma(a) ]
         = g'(eta) + a^2 * [ trigamma(y+a) - trigamma(a) ]
```

The trigamma difference is `<= 0` for `y >= 0`, so the second term is a pure
downward correction; the first term inherits the sign of the score.

**(e) Hazards — the worst on the list, and they are cancellation, not overflow.**

1. `lgamma(y+a) - lgamma(a)` is a catastrophic cancellation for large `a`
   (i.e. small `phi`, the near-Poisson limit, exactly where users sit). For
   **integer `y`** use the exact identity

   ```
   lgamma(y+a) - lgamma(a) = sum_{k=0}^{y-1} log(a + k)
   ```

   which is stable for all `a > 0` and costs `O(y)`. For large `y` fall back to
   `y*log(a) + y*(y-1)/(2a) - ...` (the Stirling-ratio expansion) with a documented
   switch point.
2. `trigamma(y+a) - trigamma(a) -> -y/a^2` for large `a` — a difference of two
   nearly equal numbers producing a value ~`1e-2 * eps` of the operands. Multiplied
   by `a^2` in `g2` this is *pure noise* for large `a`. **Use the asymptotic
   `-y/a^2 + ...` directly whenever `a` exceeds a threshold**, so that
   `a^2 * (trigamma diff) -> -y` cleanly. Without this, EVA on nbinom1 will look
   fine at moderate `phi` and disintegrate as `phi -> 0`.
3. `a = exp(eta - log(phi))` overflows for `eta` 6 SD above `mu` with small `phi`.
   Guard `a` with `CppAD::CondExpGt` at each node, and route large `a` to the
   asymptotic branch in (1)–(2) — the same branch solves both.

**Recommendation: implement nbinom2 first and treat nbinom1 as a second,
separately-verified slice.** They look adjacent and are not.

---

## 4. Beta — logit link

**(d) Parameters.** `mu` on logit; `sigma` on log scale, internal precision
`phi = 1/sigma^2`; `a = mu*phi`, `b = (1-mu)*phi` (`03-likelihoods.md` "Beta").
Support is the **open** interval `(0,1)`.

**(a) Density.** With `p = plogis(eta)`:

```
log p(y|eta) = lgamma(phi) - lgamma(phi*p) - lgamma(phi*(1-p))
             + (phi*p - 1)*log(y) + (phi*(1-p) - 1)*log(1-y)

g(eta) = phi*p*L - lgamma(phi*p) - lgamma(phi*(1-p)) + const,
         L = logit(y) = log(y) - log(1-y)
```

**(b) Closed form? NO.** **GH.**

**(c) EVA term.** With `p1 = p*(1-p)`, `p2 = p*(1-p)*(1-2p)`, and
`D = L - digamma(phi*p) + digamma(phi*(1-p))`:

```
g'(eta) = phi * p1 * D
g2(eta) = phi * p2 * D  -  phi^2 * p1^2 * [ trigamma(phi*p) + trigamma(phi*(1-p)) ]
```

The second term is unconditionally negative; the first flips sign at `p = 1/2`.

**(e) Hazards — Beta is the family where the integrand is UNBOUNDED BELOW.**

As `p -> 0`, `lgamma(phi*p) ~ -log(phi*p) -> +Inf`, so `g(eta) -> -Inf`
logarithmically. The integral is finite (log divergence against a Gaussian tail),
but at a quadrature *node* the code will evaluate a very large negative number, and
at `H = 61` (~14.5 SD, corrected above) `phi*p` underflows to exactly `0` and `lgamma(0) = Inf`
poisons the sum.

Required form:

```
log(p)     = -softplus(-eta)          # never underflows to 0
log(1-p)   = -softplus( eta)
phi*p      = exp(log(phi) + log_p)    # clamp from below, e.g. 1e-10, via CondExp
```

and clamp **at every node**, per §1.3 — the existing `[1e-6, 1-1e-6]` clamp on `mu`
is not sufficient and was never meant to be.

Also: `L = logit(y)` is `eta`-free, computed once, but is `±Inf` for `y` at the
boundary — that is a *data* guard the Beta family already needs and quadrature does
not change it.

**`H = 15` is strongly preferred for Beta.** Its 6.4-SD reach keeps the integrand
in a regime where the clamp is never active for realistic `v`; `H = 61` guarantees
the clamp fires, which turns a tunable accuracy knob into a source of bias.

---

## 5. betabinomial — logit link

**(d) Parameters.** `mu` on logit; `sigma` on log, `phi = 1/sigma^2`; `n_trials`
per row (registry line 169).

**(a) Density.** With `p = plogis(eta)`:

```
log p(y|eta) = lchoose(n,y) + lbeta(y + phi*p, n-y + phi*(1-p)) - lbeta(phi*p, phi*(1-p))

g(eta) = lgamma(y + phi*p) - lgamma(phi*p)
       + lgamma(n-y + phi*(1-p)) - lgamma(phi*(1-p))
       + const(n, y, phi)
```

(the `lgamma(n+phi)` and `lgamma(phi)` terms are `eta`-free because `a + b = phi`
identically — a small but useful simplification).

**(b) Closed form? NO.** **GH.**

**(c) EVA term.** With `p1 = p*(1-p)`, `p2 = p*(1-p)*(1-2p)`, `A = phi*p`,
`B = phi*(1-p)`, and

```
D  = digamma(y+A) - digamma(A) - digamma(n-y+B) + digamma(B)
T  = trigamma(y+A) - trigamma(A) + trigamma(n-y+B) - trigamma(B)      # <= 0
```

```
g'(eta) = phi * p1 * D
g2(eta) = phi * p2 * D  +  phi^2 * p1^2 * T
```

Sanity check, `phi -> Inf` (binomial limit): `digamma(y+A)-digamma(A) -> y/A`, so
`phi*p1*D -> y*(1-p) - (n-y)*p = y - n*p`, the binomial score. Correct.

**(e) Hazards.** Same log divergence as Beta but **one-sided per tail** and
avoidable in the common case. Use the integer-difference identity:

```
lgamma(y+A) - lgamma(A)         = sum_{k=0}^{y-1}   log(A + k)
lgamma(n-y+B) - lgamma(B)       = sum_{k=0}^{n-y-1} log(B + k)
```

For `y = 0` the first sum is **empty and exactly zero** — no divergence at all.
For `y >= 1` the `k = 0` term is `log(A)`, which diverges as `p -> 0`, so the
same lower clamp on `A` and `B` is required at each node. Prefer the sum form for
small `n` (it is exact and monotone); fall back to `lgamma` differences with the
clamp for large `n`.

`lchoose(n,y)` is `eta`-free — hoist it out of the quadrature loop.

---

## 6. ordinal / cumulative link — and why the staging table was wrong

**(d) Parameters.** Latent `mu` (identity, no separate scale — the latent residual
variance is fixed at 1 by construction), plus `K-1` **shared ordered cutpoints**
`c_1 < ... < c_{K-1}`, estimated on the **log-difference scale** to preserve
ordering, with a mode-fixing convention exposed by `extract_cutpoints()`
(`03-likelihoods.md` "Ordinal probit"; `06-extractors-contract.md` §`extract_cutpoints`).
The shipped family is **`ordinal_probit`**; `cumulative_logit` is not currently a
gllvmTMB family and the §6.2 result below is an argument for adding one *for the VA
route specifically*.

**(a) Density.**

```
Pr(y = k | eta) = F(c_k - eta) - F(c_{k-1} - eta),   c_0 = -Inf, c_K = +Inf
g(eta)          = log[ F(c_k - eta) - F(c_{k-1} - eta) ]
```

### 6.1 The cutpoints do NOT add a quadrature dimension

Design 104 §6 stages this family as *"GH over cutpoints"*. **That phrasing is
wrong and should be corrected.** The cutpoints are fixed offsets *inside* the
integrand; `eta` is still the only random argument. The quadrature is the same 1-D
rule over `eta`, with `K-1` extra scalars in scope. Nothing about the routine
changes — no `K`-fold quadrature, no product rule, no extra nodes.

What *does* change is bookkeeping: the cutpoints are **shared across all rows of a
trait**, so their gradient accumulates over every observation of that trait. That
is a parameter-packing question, not a quadrature question.

**(b) Closed form? NO.** **GH** — one rule, over `eta`.

### 6.2 The cumulative-LOGIT link collapses to softplus, exactly

For `F = plogis` there is an exact stable identity. For `a > b`:

```
plogis(a) - plogis(b) = (exp(a) - exp(b)) / ((1+exp(a))*(1+exp(b)))
```

so, with `a = c_k - eta`, `b = c_{k-1} - eta`, `a - b = c_k - c_{k-1} = gap_k`:

```
g(eta) = (c_{k-1} - eta) + log(expm1(gap_k))
       - softplus(c_k - eta) - softplus(c_{k-1} - eta)          # interior k
g(eta) = -softplus(eta - c_1)                                   # k = 1
g(eta) = -softplus(c_{K-1} - eta)                               # k = K
```

Three properties, all of them good:

* **`log(expm1(gap_k))` is `eta`-free** — precomputed once per category. And the
  cutpoints are *already* parameterised on the log-difference scale, so `gap_k` is
  the natural quantity: `gap_k = exp(log_gap_k)`, strictly positive by
  construction, which is exactly the condition under which `expm1(gap) > 0`.
* **No CDF difference is ever formed.** The catastrophic cancellation that
  motivates the `CondExpLt` probability clamp (#658) does not arise.
* **The integrand is again softplus** — the same primitive as binomial, nbinom2,
  and the hurdle component. No new kernel.

`g` is unbounded below (linearly, in the far tail) but never `log(0)`: the
`(c_{k-1} - eta)` term simply becomes very negative, which is *correct*, not a
numerical failure.

**Recommendation.** Add `cumulative_logit` as the VA-route ordinal family. It is
the cheapest and safest family on this entire list, and it exists for free once
softplus is in hand.

### 6.3 The probit link is the hard case

For `F = pnorm`, with `z_k = c_k - eta`:

```
P       = pnorm(z_k) - pnorm(z_{k-1})
g'      = ( -dnorm(z_k) + dnorm(z_{k-1}) ) / P
g''     = ( -z_k*dnorm(z_k) + z_{k-1}*dnorm(z_{k-1}) ) / P  -  (g')^2
```

There is **no analogue of the `expm1(gap)` identity for the normal CDF.** `P` is a
genuine difference of two nearly-equal CDFs, and under quadrature the far nodes put
both `z` in the same tail where `P` underflows to `0` and `g -> -Inf` numerically.
This is the one family on the list where the shipped point-evaluation guard is
actively unsafe under GH.

Options, in order of preference:

1. **Route the VA ordinal path through `cumulative_logit`** (§6.2) and document
   `ordinal_probit` as Laplace-only.
2. Implement a log-scale `logspace_sub` on `pnorm`, using the scaled complementary
   error function in the tail so that `log P` is computed without ever forming `P`.
   Correct but genuinely fiddly, and needs its own AD-safety verification.
3. **EVA-only** for `ordinal_probit`. `g` and `g2` above are evaluated at `eta = mu`
   only, where the existing `CondExpLt` clamp is exactly the guard it was designed
   to be. This is a defensible fallback and matches `gllvm`'s own documented
   position (`method="EVA"` when VA is not applicable).

**Log-concavity note.** For any log-concave `F` (logit and probit both qualify),
`Pr(y=k | eta)` is log-concave in `eta`, so `g2 <= 0` everywhere. EVA's correction
on ordinal data is therefore always a downward penalty — a cheap invariant to
assert in tests.

---

## 7. censored_poisson

**(d) Parameters.** `mu` on log link only — no dispersion. Per row, a censoring
type and bounds (registry line 183: right-, left-, and interval-censoring).
Currently `blocked constructor-only`.

**(a) Density.** With `lam = exp(eta)`:

| Row type | `g(eta)` |
|---|---|
| exact, `y` observed | `y*eta - exp(eta) - lgamma(y+1)` |
| right-censored, `y >= L` | `log pgamma(exp(eta), shape = L)` |
| left-censored, `y <= U` | `log ppois(U, exp(eta))` = `log pgamma(exp(eta), U+1, lower=FALSE)` |
| interval, `L <= y <= U` | `log[ ppois(U, lam) - ppois(L-1, lam) ]` |

(the right-censored identity is the Poisson–gamma duality `P(Y >= L | lam) =
pgamma(lam, L)`.)

**(b) Closed form? PARTIAL — and this is the only family on the list that splits
row-by-row.** Exact rows satisfy §1.1 and integrate in closed form:

```
E[g] = y*mu - exp(mu + v/2) - lgamma(y+1)          # exact rows: EXACT
```

Censored rows do not. **So `censored_poisson` is EXACT on its uncensored rows and
GH on its censored rows.**

That is an efficiency worth taking — in a typical detection-limit dataset most rows
are uncensored — but it is an **architectural wrinkle worth naming**: the tier is a
property of the *row*, not of the *family*. The evaluation loop must therefore
branch per row, not per family. Everything else in this document tiers at the family
level. If that branch is judged not worth its complexity, the honest fallback is to
run every row through GH; the exact rows will be reproduced to quadrature accuracy
and the only cost is time.

**(c) EVA term.** Exact rows: `g2 = -exp(eta)`, the Poisson curvature.

Right-censored rows have a clean closed form. Let `S = pgamma(lam, L)` and
`G = lam * dpois(L-1, lam) / S = L * dpois(L, lam) / S`. Then

```
g'(eta)  = G
g2(eta)  = G * (L - lam - G)
```

(derived by `d/deta = lam * d/dlam` and `d/dlam dpois(L-1,lam) = dpois(L-1,lam)*((L-1)/lam - 1)`.)

Left-censored is the mirror image with the complementary tail; interval rows use
`g2 = P''/P - (P'/P)^2` with `P` the interval probability.

**(e) Hazards.** `pgamma(lam, L)` underflows for `lam << L`, and quadrature spans
`lam = exp(mu ± 6.4*sqrt(v))` — a factor of `e^12.8 ≈ 4e5` in `lam` at `v = 1`,
so underflow is not hypothetical. Required:

* small-`lam` branch: `log pgamma(lam, L) ≈ L*log(lam) - lam - lgamma(L+1)`, exact
  to leading order and stable to arbitrarily small `lam`;
* interval rows with small `U - L`: compute `log[sum_{k=L}^{U} dpois(k, lam)]` by
  `logspace_add` over the range rather than as a CDF difference. Exact, stable, and
  cheap when the interval is short — which is the usual case for interval-censored
  counts;
* never form `exp(eta)` when `eta` may exceed 709 at an outer node — clamp, or work
  from `eta` throughout.

---

## 8. The delta_* / hurdle group — two components, and why one quadrature still suffices

**(d) Parameters.** Two linear predictors: an occurrence/hurdle predictor `eta1`
(logit) and a positive-component predictor `eta2` (log for `delta_gamma`, identity
on `log y` for `delta_lognormal`), plus the positive component's own dispersion.
Status is `planned (post-CRAN)`; registry §"Hurdle / delta families" records that
**the binary occurrence submodel is fixed-effects only** in the current engine.

### 8.1 The structure

```
p(y | eta1, eta2) = (1 - pi) * 1{y = 0}  +  pi * 1{y > 0} * f(y | eta2)
pi = plogis(eta1)
```

so

```
y = 0:   g(eta1, eta2) = -softplus(eta1)
y > 0:   g(eta1, eta2) = -softplus(-eta1)  +  log f(y | eta2)
```

### 8.2 The key result: additive separability

**`log p` is additively separable in `(eta1, eta2)`.** Every term depends on exactly
one of them. Therefore, *whatever the correlation between `eta1` and `eta2` under
`q`*:

```
E_q[ log p ] = E[ g1(eta1) ] + E[ g2(eta2) ]
```

with `eta1 ~ N(mu1, v1)` and `eta2 ~ N(mu2, v2)` — **the marginals only.** The
covariance `Cov(eta1, eta2) = lambda1' S_i lambda2` **never enters the data term of
the ELBO**, even when both components load on the same `u_i`.

**So one 1-D routine suffices. It is called twice, on two different marginals, not
once on a bivariate rule.** No 2-D quadrature, no cross term. This is the answer to
the question the brief asks, and it is a positive result for the architecture.

(The covariance is not lost from the model — it still shapes `S_i` through the
entropy and prior KL terms, and it still determines the joint distribution of the
latent scores. It simply does not appear in the expected log-likelihood.)

### 8.3 The tiers, per component

| Component | `g` | Tier |
|---|---|---|
| hurdle, `y = 0` | `-softplus(eta1)` | GH (softplus routine, reused) |
| hurdle, `y > 0` | `-softplus(-eta1)` | GH (softplus routine, reused) |
| `delta_lognormal` positive | `-log y - 0.5*log(2*pi*s2) - (log y - eta2)^2/(2*s2)` | **EXACT** (quadratic) |
| `delta_gamma` positive | `phi*log phi - lgamma(phi) + (phi-1)log y - phi*eta2 - phi*y*exp(-eta2)` | **EXACT** (§1.1) |

```
E[delta_lognormal positive] = -log y - 0.5*log(2*pi*s2) - ((log y - mu2)^2 + v2)/(2*s2)
E[delta_gamma      positive] = phi*log phi - lgamma(phi) + (phi-1)*log y
                               - phi*mu2 - phi*y*exp(-mu2 + v2/2)
```

**Consequence.** Because the engine's hurdle submodel is currently
**fixed-effects only**, `v1 = 0`, and the hurdle term is `-softplus(mu1)` with no
expectation to take. **`delta_lognormal` and `delta_gamma` are therefore EXACT
end-to-end under the current engine** — no quadrature at all. They should be staged
alongside Poisson and Gaussian, not "later" as Design 104 §6 has them. If the
hurdle submodel later gains latent loadings, they become EXACT + one softplus GH.

**EVA terms.** `g2` for both hurdle branches is the same:
`-plogis(eta1)*(1-plogis(eta1))`. Positive components:
`g2 = -1/s2` (lognormal), `g2 = -phi*y*exp(-eta2)` (gamma).

---

## 9. Verdict table

| # | Family | Tier | Integrand | New kernel needed? |
|---|---|---|---|---|
| 1 | **nbinom2** | GH | `softplus(eta - log theta)` | **No** — existing routine, shifted |
| 2 | **nbinom1** | GH | `lgamma(y+a) - lgamma(a)`, `a = exp(eta)/phi` | Yes, and it is the hardest |
| 3 | **Beta** | GH | `phi*p*L - lgamma(phi*p) - lgamma(phi*(1-p))` | Yes |
| 4 | **betabinomial** | GH | `lgamma` quartet, or integer sums | Yes (shares Beta's guards) |
| 5 | **cumulative_logit** | GH | **softplus pair + `eta`-free `log expm1(gap)`** | **No** — existing routine |
| 5' | **ordinal_probit** | GH-hard / **EVA-recommended** | `pnorm` difference | Yes, or route to 5 |
| 6 | **censored_poisson** | **EXACT (exact rows) + GH (censored rows)** | `log pgamma(exp(eta), L)` | Yes, for censored rows only |
| 7 | **delta_lognormal / delta_gamma** | **EXACT** today (hurdle is fixed-effects-only); EXACT + softplus GH if the hurdle gains loadings | separable, two marginals | **No** |
| — | Gamma(log), exponential(log), lognormal | **EXACT** (§1.1; not in Design 104's list) | — | No |

**EXACT:** censored_poisson's uncensored rows; both `delta_*` families as currently
engineered; Gamma-log, exponential-log, lognormal.
**GH:** nbinom1, nbinom2, Beta, betabinomial, cumulative_logit, censored rows,
`ordinal_probit` if route (2) of §6.3 is taken.
**EVA-only (recommended, not forced):** `ordinal_probit`. Everything else on the
list is GH-reachable given the stable forms above — **no family here *requires*
EVA**, which supports Design 104 §4.4: EVA stays a fast path, never a default.

**Implementation order, revised from Design 104 §6:**
`delta_lognormal`/`delta_gamma` (EXACT, free) → nbinom2 (reuses softplus) →
cumulative_logit (reuses softplus) → betabinomial → Beta → censored_poisson →
nbinom1. Three of the first four need no new integrand.

---

## 10. Where the scalar-`eta` assumption BREAKS

This is the most important section. The architecture rests on `log p` depending on
`u_i` through **one** scalar. Four things break it. Two are already in the
repository.

### 10.1 BREAK — composition / multinomial families across traits

**The hard break.** A Dirichlet-multinomial or multinomial-composition response
couples all `T` traits of a row through a single normaliser:

```
log p(y_i. | eta_i1, ..., eta_iT) = sum_t y_it * eta_it
                                  - n_i * log( sum_t exp(eta_it) )  + const
```

The `log-sum-exp` term is a function of the **entire vector** `eta_i.`, which under
`q` is `T`-variate Gaussian with covariance `Lambda S_i Lambda'`. There is no
scalar reduction. `E[log sum_t exp(eta_it)]` requires a `T`-dimensional integral,
and one 1-D rule cannot touch it.

**This is live in the repository.** `dev/phylo-multinomial-harness-DRAFT.R` exists
in the working tree. Whatever else that lane does, **it must not be assumed
VA-reachable.** Options if it becomes a VA target: a bound on the log-sum-exp
(Bohning / Blei–Lafferty tangent bounds), or an explicitly `T`-dimensional
treatment — a different architecture, not a family addition.

### 10.2 BREAK — zero-INFLATED and mixture families (but not hurdle)

The `delta_*` separability of §8.2 is a property of the **hurdle** structure, where
the zero and the positive parts are on disjoint events. Zero-*inflation* is not:

```
p(y = 0) = pi + (1 - pi) * exp(-lam)        # a log of a SUM
log p(0) = log( plogis(eta1) + plogis(-eta1)*exp(-exp(eta2)) )
```

`log(A(eta1) + B(eta1)C(eta2))` is **not additively separable**. If both `eta1` and
`eta2` load on `u_i`, the ELBO needs the joint — 2-D quadrature.

The same argument applies to every `*_mix` family in the registry
(`nbinom2_mix`, `lognormal_mix`, `gamma_mix`, `delta_*_mix`): a mixture is a log of
a sum. **The distinction is precise:** if the mixture components share a *single*
linear predictor and differ only in fixed parameters, the integrand is still a
scalar function of `eta` and GH applies unchanged (just a `logspace_add` inside the
integrand). If the components carry *separate* predictors that both load on `u`, the
architecture breaks.

Most of these constructors are `blocked constructor-only` today, so this is a
future constraint, not a present defect — but it should be written into the family
registry now, so no one adds a two-predictor mixture to the VA surface by analogy
with `delta_*`.

### 10.3 BREAK — the Poisson-link delta parameterisation

`delta_poisson_link_gamma` / `delta_poisson_link_lognormal` (Thorson) set

```
n = 1 - exp(-exp(eta1)),    w = exp(eta1 + eta2) / n
```

so the positive component's mean depends on **both** predictors, non-separably. §8.2
does **not** apply. These constructors are already `blocked deprecated`; that block
should be understood as load-bearing for the VA route, not merely a deprecation.

### 10.4 BREAK — dispersion modelled with latent loadings

Every family above treats the dispersion (`theta`, `phi`, `sigma`) as a per-trait
constant. If a future "distributional GLLVM" lets the dispersion carry its own
linear predictor with latent loadings — `theta = exp(eta_phi)` with `eta_phi`
loading on `u_i` — then, e.g., nbinom2's `lgamma(y + exp(eta_phi))` and
`log(exp(eta_phi) + exp(eta_mu))` couple the two predictors non-separably. 2-D
quadrature.

This is not currently in gllvmTMB (it is `drmTMB`'s territory), but it is the most
likely direction of travel for a package whose sister does distributional
regression, and it is the cheapest break to guard against in advance: **the family
contract in §1 should state that the dispersion arguments are constants with
respect to `eta`.**

### 10.5 NOT breaks — recorded so they are not re-litigated

* **Ordinal cutpoints.** `K-1` extra parameters, one quadrature. §6.1.
* **Censoring.** A per-row tier split, not a dimensionality change. §7.
* **Hurdle / `delta_*`.** Two predictors, additively separable, two 1-D
  quadratures on the marginals. §8.2.
* **`eta`-dependent shape (nbinom1).** Still one scalar argument; a hard integrand,
  not a broken architecture. §3.
* **Trials / offsets / weights.** Multiplicative constants on `g`; no effect.

---

## 11. Open, not settled here

* The **nbinom1 dispersion convention** (`Var = mu*(1+sigma)` vs `Var = mu*(1+phi)`
  with `phi = sigma^2`) is taken from `03-likelihoods.md` and has not been checked
  against `src/gllvmTMB.cpp`. §3's algebra depends on it.
* Whether the **per-row tier split** for `censored_poisson` (§7) earns its
  complexity, or whether every row should go through GH.
* Whether **`cumulative_logit`** should be added as a family purely to give the VA
  route a safe ordinal path (§6.2–6.3), given that `ordinal_probit` is the
  `claimed`, validated, user-facing one.
* The **generic small-`v` threshold** (§1.2) proposes `1e-8` with a two-term
  expansion, against the shipped `1e-6` with four terms. This wants one numerical
  check — agreement of `dE/dv` across the branch switch — before it is fixed.
* Every EVA `g2` in this document is **derived, not verified**. Each should be
  checked against a finite-difference of its own `g` before use. That check is
  cheap, mechanical, and belongs in the same slice as the implementation.

> Related: [Design 104](104-va-family-coverage.md) (the architecture and the
> defaults) · [Design 85](85-highdim-nongaussian-va-formal-contract.md) (READ-ONLY,
> negative evidence; §10 forbids ELBO-derived inference) ·
> [Design 02](02-family-registry.md) (family status, parameter scales) ·
> [Design 03](03-likelihoods.md) (shipped densities and their guards)
