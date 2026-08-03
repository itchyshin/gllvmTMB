# Albert–Chib closed-form VA evaluator — derivation and verdict

**Slice:** derivation only. No `R/`, `src/`, or `inst/` file was modified.
**Date:** 2026-08-03. **Worktree:** `/private/tmp/gllvmtmb-va-speed` (`claude/va-speed-arc`).

Every non-obvious claim below carries the algebra that produces it and, where a number is
quoted, the measurement that produced the number. Scripts:
`scratchpad/verify.R`, `scratchpad/verify2.R` (see §7 for what each check returned).

---

## 1. VERDICT

**OBJECTIVE SUBSTITUTION — for binary probit (A). The auxiliary `z` profiles out
analytically and exactly.** Maximising the augmented ELBO over a free-form `q(z)` at fixed
`q(a)` has a closed-form maximiser, `q*(z) = TN(mu, 1, H_y)`, and the profiled value collapses
to a two-term expression in `(mu, v)` alone:

> **E_AC(mu, v; y, n) = y·logPhi(mu) + (n−y)·logPhi(−mu) − n·v/2**

No residual free parameter survives. TMB never sees `z`; the variational parameter block
(`m`, `L_off`) is unchanged; the optimiser optimises the same vector it optimises today. The
new evaluator is **four lines of C++** in terms of primitives already merged
(`va_r3_log_pnorm`, `va_r3_inv_mills`) and needs **no GH nodes, no threshold, and no
`CondExp`** — because `v` enters *linearly*, the `sqrt(v)` unbounded-derivative-at-zero problem
that forces the GH evaluator's small-`v` branch does not arise at all. The distilled
literature note's "4-step CAVI cycle" describes gllvm's *optimisation algorithm*, not the
objective; the objective it ascends is the profiled one derived here (§7 confirms this against
gllvm's own source, three independent ways).

**Three qualifications, none of which changes the verdict but two of which change the arc's
scope and one of which changes its cost model:**

1. **(B) ordinal is NOT a branch in the `fam==4` block — it is a NEW FAMILY in the VA engine.**
   The AC *derivation* for ordinal is the same one line. But `inst/tmb/gllvmTMB_va_r3.cpp`
   contains **no ordinal support whatsoever** (`grep -in "ordinal|cutpoint|cuts"` → zero hits;
   family codes are validated to `0..4` at `:543-544`). Ordinal needs a new family code, two
   new `DATA_IVECTOR`s, a new `PARAMETER_VECTOR`, two new numerical helpers, and the whole
   R-side data/parameter/identifiability wiring. That is a materially larger slice than (A) and
   the touch-point list in the brief covers only (A).
2. **`MATURE-VA.md` §Item 1 is right about the conclusion and wrong about one premise** — see
   §6. It says the substitution "uses only Phi/phi — TMB-native smooth atomics". For binary
   that is true. For **ordinal it is false**: the ordinal term needs a *difference* of two
   nearly-equal normal CDFs, which is not a smooth atomic and is the single hardest numerical
   object in this arc (§5.7).
3. **Amdahl's law caps this item at ~4×, not the ~65× the arc's speed table implies.** If GH is
   75% of runtime, removing it entirely gives 45.6 s → ~11.4 s — still **16× slower than
   gllvm's 0.70 s**. Item 1 alone cannot hit the speed target. The derivation does, however,
   hand us the probable reason gllvm is fast, and it is *not* the closed form itself — see
   §8.2 and Risk R7.

---

## 2. Setup and notation

`eta_ij = beta_j + a_i' lambda_j`, variational `q(a_i) = N(m_i, A_i)`. Under `q`, `eta_ij` is
Gaussian:

```
mu_ij = beta_j + m_i' lambda_j          (already computed, mu_by_obs at :821)
v_ij  = lambda_j' A_i lambda_j          (already computed, v_by_obs  at :822)
```

Everything below is written in `(mu, v)`; the `ij` subscript is dropped. Write

```
phi(x)    standard normal density        Phi(x)  standard normal CDF
lam(x) = phi(x)/Phi(x)                   (inverse Mills; va_r3_inv_mills at :205-214)
logPhi(x)                                (tail-safe; va_r3_log_pnorm  at :181-197)
s = 2y - 1                               (+1 if y = 1, -1 if y = 0)
```

Two standard identities used throughout:

```
(d/dx) logPhi(x)     =  lam(x)
(d²/dx²) logPhi(x)   = -lam(x)·(x + lam(x))            [used already at :243-244]
```

---

## 3. (A) BINARY PROBIT

### A1 — the exact term, and why there is no closed form

For one Bernoulli trial the exact ELBO contribution is

```
F(mu, v) = E_{eta ~ N(mu,v)} [ log Phi(s·eta) ]
         = ∫ logPhi(s·e) · (1/sqrt(v)) phi((e-mu)/sqrt(v)) de                        (A1.1)
```

The near-miss that makes the intractability precise: the Gaussian convolution of `Phi` *is*
elementary,

```
∫ Phi(a + b·x) phi(x) dx = Phi( a / sqrt(1 + b²) )                                   (A1.2)
```

so `E[Phi(eta)] = Phi(mu/sqrt(1+v))` in closed form. But the likelihood needs
`E[log Phi(eta)]`, and the `log` destroys (A1.2): `logPhi` is not a polynomial, not an
exponential, and not a Gaussian-conjugate form, so no reproducing identity applies and (A1.1)
has no elementary antiderivative. **This is exactly why `va_r3_probit_expectation` (:231-260)
evaluates (A1.1) by Gauss–Hermite** — `H` calls to `va_r3_log_pnorm` per observation, which is
the ~75% the profile reports.

### A2 — the augmented ELBO

Albert–Chib: introduce `z ~ N(eta, 1)` with `y = 1{z > 0}`. The augmentation is exact,

```
P(y=1 | eta) = P(z > 0 | eta) = Phi(eta)     ✓                                       (A2.1)
```

Take mean-field `q(z, a) = q(z)·q(a)` with `q(z)` **free-form** (nonparametric — this matters;
see A3). The augmented ELBO is

```
L = E_q[ log p(y|z) ] + E_q[ log p(z|eta(a)) ] + E_q[log p(a)] - E_q[log q(z)] - E_q[log q(a)]
```

`log p(y|z)` is `0` on the half-line `H_y` (`{z>0}` if `y=1`, `{z≤0}` if `y=0`) and `-inf`
off it, so finiteness *forces* `supp q(z) ⊆ H_y` and then `E_q[log p(y|z)] = 0`. The
`a`-only terms are the existing KL. The **entire `z`-dependent part** is

```
L_z(q) = E_{q(z)} E_{q(a)}[ log p(z|eta) ] + H(q(z))
       = E_{q(z)}[ -½log(2pi) - ½·E_{q(a)}[(z - eta)²] ] + H(q(z))
```

and since `E_{q(a)}[(z-eta)²] = (z - mu)² + v` (the cross term vanishes, `z` ⟂ `a` under
mean-field),

```
L_z(q) = -½log(2pi) - ½·E_{q(z)}[(z-mu)²] - v/2 + H(q(z))                            (A2.2)
```

Note where `v` lands: it is **additively separated from `z`**. That separation is the whole
reason the profiling in A4 works.

### A3 — the optimal `q(z)`, in closed form

Apply the Gibbs variational principle (Donsker–Varadhan): for any `f`,
`max_q { E_q[f] + H(q) } = log ∫ exp(f(z)) dz`, attained at `q*(z) ∝ exp(f(z))`. Here

```
f(z) = E_{q(a)}[ log p(y|z) + log p(z|eta) ]
     = log 1{z ∈ H_y} - ½log(2pi) - ½[(z-mu)² + v]                                   (A3.1)
```

so

> **`q*(z) ∝ N(z; mu, 1) restricted to H_y`  —  a truncated normal with parent mean `mu` and
> parent variance `1` (not `1+v`; the `v` term is `z`-free and drops out of the shape).**

Its mean is the inverse-Mills-ratio expression expected:

```
E_{q*}[z] = mu + s·lam(s·mu)                                                         (A3.2)
          = mu + phi(mu)/Phi(mu)        if y = 1
          = mu - phi(mu)/Phi(-mu)       if y = 0
Var_{q*}(z) = 1 - lam(s·mu)·(lam(s·mu) + s·mu)                                       (A3.3)
```

`q*` is a truncated normal, and the free-form maximiser lies *inside* any parametric
truncated-normal family with a free location — so nothing is lost by taking `q(z)` free-form,
and a parametric TN family gives the same profiled value.

### A4 — substitute back: does anything survive? **NO.**

Two independent routes, both to the same answer.

**Route 1 (Gibbs principle, direct).** Plug (A3.1) into `max_q = log ∫ exp(f)`:

```
L_z* = log ∫_{H_y} (2pi)^{-1/2} exp(-½(z-mu)²) · exp(-v/2) dz
     = -v/2 + log ∫_{H_y} N(z; mu, 1) dz
     = -v/2 + log Phi(s·mu)                                                          (A4.1)
```

**Route 2 (explicit moments + entropy, as a check that the cancellation is real).** With
`alpha = s·mu`, `L = lam(alpha)`:

```
E_{q*}[(z-mu)²] = Var_{q*}(z) + (E_{q*}[z] - mu)²
                = [1 - L(L + alpha)] + L²  =  1 - L·alpha                            (A4.2)

H(q*)  = -E[log(phi(z-mu)/Phi(alpha))]
       = ½log(2pi) + ½·E[(z-mu)²] + log Phi(alpha)
       = ½log(2pi) + ½(1 - L·alpha) + log Phi(alpha)                                 (A4.3)
```

Substituting (A4.2) and (A4.3) into (A2.2):

```
L_z* = -½log(2pi) - ½(1 - L·alpha) - v/2  +  ½log(2pi) + ½(1 - L·alpha) + log Phi(alpha)
        \_____________  cancels  ______________/  \_______ cancels ________/
     = log Phi(s·mu) - v/2                                                    ✓ = (A4.1)
```

**The `½log(2pi)` terms and the `½(1 - L·alpha)` terms cancel identically between the
quadratic term and the entropy. That exact cancellation IS the profiling.** Every trace of
the truncated normal — its mean, its variance, its normalising constant's interaction with the
entropy — annihilates, leaving only `log Phi(s·mu)` and the separated `-v/2`.

**Answer to the deciding question: YES.** The result depends only on `(mu, v)` and constants.
Moreover it depends on `v` *only through the linear term* `-v/2`.

**`n`-trial generalisation** (the shipped evaluator's interface takes `y`, `n`): `n`
conditionally-independent latent `z`'s share one `eta`, `y` of them positive. Each contributes
its own `-v/2`, so

> **E_AC(mu, v; y, n) = y·logPhi(mu) + (n−y)·logPhi(−mu) − n·v/2**                   (A4.4)

This matches the units of `va_r3_probit_expectation` term-for-term (§8.1). **`n·v/2`, not
`v/2` — this is where the derivation disagrees with gllvm; see §6.2.**

### A5 — lower bound, and it is STRICT

**Claim.** `F(mu,v) ≥ E_AC(mu,v)`, with equality iff `v = 0`.

**Proof 1 (variational — gives the exact gap).** For each fixed `a`,

```
E_{q(z)}[log p(y,z|a) - log q(z)] = log p(y|a) - KL( q(z) ‖ p(z|y,a) )
```

Averaging over `q(a)`:

```
L_z*  =  E_{q(a)}[log p(y|a)]  -  E_{q(a)}[ KL( q*(z) ‖ p(z|y,a) ) ]
      =  F(mu,v)               -  (a non-negative gap)                               (A5.1)
```

`p(z|y,a) = TN(eta(a), 1, H_y)` **depends on `a`**, whereas `q*(z) = TN(mu, 1, H_y)` is a
single fixed distribution. So the KL vanishes for `q(a)`-a.e. `a` iff `eta` is `q(a)`-a.s.
constant, i.e. **iff `v = 0`**. Strict lower bound for `v > 0`. ∎

**Proof 2 (heat equation — gives the *mechanism*, and is the more useful one).**
`F(·, v)` is a Gaussian convolution of `logPhi`, so it satisfies the heat equation

```
∂F/∂v = ½ · ∂²F/∂mu² = ½ · E_{eta~N(mu,v)}[ (logPhi)''(s·eta) ]                     (A5.2)
```

A general identity for `p(mu) = ∫ w(z) N(z; mu, 1) dz` with `w ≥ 0`: writing `q*(z) ∝ w(z)N(z;mu,1)`,

```
(d/dmu) log p    = E_{q*}[z - mu]
(d²/dmu²) log p  = (d/dmu) E_{q*}[z] - 1 = Cov_{q*}(z, z-mu) - 1 = Var_{q*}(z) - 1   (A5.3)
```

For `w = 1{z ∈ H_y}`, `q*` is `N(mu,1)` restricted to an **interval** (a half-line is an
interval). By Brascamp–Lieb, a density `∝ e^{-V}` with `V'' ≥ c` has `Var ≤ 1/c`; here `V''=1`
on the interval and `+inf` outside, so

```
0 < Var_{q*}(z) ≤ 1     ⟹     -1 < (logPhi)'' ≤ 0     ⟹     ∂F/∂v ≥ -½              (A5.4)
```

Integrating from `v = 0` where `F(mu,0) = logPhi(s·mu)`:

```
F(mu,v) = logPhi(s·mu) + ∫_0^v (∂F/∂v') dv'  ≥  logPhi(s·mu) - v/2  = E_AC          ∎
```

**What Proof 2 tells us that Proof 1 does not: the AC bound is exactly the WORST-CASE
CURVATURE bound.** It replaces the true curvature `(logPhi)'' ∈ (-1, 0)` by its infimum `-1`.
Combining (A5.3) and (A5.4), the exact gap is

```
F(mu,v) - E_AC(mu,v) = ½ ∫_0^v E_{eta~N(mu,v')}[ Var(z | y, eta) ] dv'  ∈ [0, v/2]   (A5.5)
```

**Read (A5.5) — it is the statistically important line of this document.** The bound is
*tight* when the observation pins `z` down (`Var → 0`: `s·mu → -inf`, a surprising
observation) and *loose*, losing the full `v/2`, when the observation is uninformative about
`z` (`Var → 1`: `s·mu → +inf`, a **well-fitted** observation). Measured: at `s·mu = 3`, the
true `∂F/∂v ≈ -0.0067` against the bound's `-0.5` — a **75× over-penalty on `v`** on a
well-predicted cell. Since a converged model fits most cells well, **the AC objective
systematically over-penalises the variational variances.** §4 shows exactly what that does.

### A6 — analytic derivatives

From (A4.4), directly:

```
∂E_AC/∂mu = y·lam(mu) - (n-y)·lam(-mu)
          = y·va_r3_inv_mills(mu) - (n-y)·va_r3_inv_mills(-mu)                       (A6.1)

∂E_AC/∂v  = -n/2                                        (an exact constant)          (A6.2)
```

Both are AD-clean: (A6.1) is a difference of two `va_r3_inv_mills` calls, which by
construction never divides by an underflowed probability (`:205-214`), and (A6.2) is a
constant. Finite-difference check target: `(A6.1)` at `mu ∈ {-6,-3,-1,0,0.5,2,5}`,
`(A6.2)` should return `-n/2` to machine precision **for every `(mu, v, y, n)`** — a
distinctive, easily-falsified signature.

**(A6.2) is the load-bearing structural fact of this whole derivation.** Because
`∂E_AC/∂v` is a data-free constant, *all* curvature information about `A_i` now comes from the
KL term alone. §4 works out the consequence.

---

## 4. The structural consequence of `∂E/∂v = -n/2` (and its independent confirmation)

Stationarity of the ELBO in `A_i`. With `v_ij = lambda_j' A_i lambda_j` so
`∂v_ij/∂A_i = lambda_j lambda_j'`, and
`KL = ½[tr(Sigma^{-1}A_i) + m_i'Sigma^{-1}m_i - q - log|A_i| + log|Sigma|]` so
`∂KL/∂A_i = ½[Sigma^{-1} - A_i^{-1}]`:

```
Σ_j (-n_ij/2)·lambda_j lambda_j'  -  ½Sigma^{-1}  +  ½A_i^{-1}  =  0

  ⟹   A_i^{-1} = Sigma^{-1} + Σ_j n_ij · lambda_j lambda_j'                          (4.1)
```

For complete data with `n_ij ≡ 1`, `A_i^{-1} = Sigma^{-1} + Lambda'Lambda` — **independent of
`i` and independent of the data `y` entirely.** Every unit gets the identical variational
covariance.

**This prediction is confirmed verbatim in gllvm's source**, which I derived independently and
then checked (`gllvm:::gllvm.VA`, deparsed):

```
line 1142-1144:  if (family %in% c("binomial","ordinal"))
                   new.lambda.mat <- solve(diag(rep(1,num.lv)) + matrix(apply(theta2,2,sum),...))
line 1188-1190:  if ((family %in% c("binomial","ordinal")) & i == 1) break
line 1192-1198:  for (i2 in 2:n) new.lambda[i2,] <- new.lambda[1,]
```

`theta2 = Σ_j theta_j theta_j'`, so line 1143 is **exactly (4.1) with `Sigma = I`**. gllvm
computes `A_1`, **breaks out of the per-unit loop**, and copies it to all `n` units. Contrast
lines 1138-1141/1148-1151, where Poisson and negative-binomial *do* depend on `mu.mat[i,]` —
those families get a per-unit, data-dependent `A_i`; probit and ordinal do not. That
asymmetry is precisely what (A6.2) predicts and nothing else explains.

Two consequences, one good and one that must be fenced:

- **(good) This is very likely where gllvm's speed actually comes from** — not from the closed
  form per se, but from collapsing `N × q(q+1)/2` variational-covariance parameters to
  `q(q+1)/2`. At the reference cell (`N=250, q=1`) that is **250 free parameters → 1**. See
  §8.2 and Risk R7.
- **(fence) The variational covariance under AC is structurally data-independent.** Per-unit
  variational SDs carry no per-unit information. Any interval, coverage, or
  `latent_uncertainty` claim built on VA-AC posterior SDs is on far weaker ground than the same
  claim under GH. This must be stated wherever the AC tier's output is surfaced.

**Caveat (scope of (4.1)):** constancy across units requires complete data, `n_ij` constant,
a pure-probit trait set, and the *unstructured single-tier* KL. Missing cells make `A_i`
constant only within a missingness pattern; varying `n_ij` breaks it; the Stage-7 structured
tiers change the KL and the fixed point is **UNVERIFIED** there. The *objective* (A4.4) is
unaffected by any of this — only the `A_i`-constancy corollary is.

---

## 5. (B) CUMULATIVE-PROBIT ORDINAL

### B1-B4 — the derivation is structurally identical

`P(y = k | eta) = Phi(zeta_k - eta) - Phi(zeta_{k-1} - eta)`, `zeta_0 = -inf`, `zeta_K = +inf`.

Augment with the *same* `z ~ N(eta, 1)`, now with `y = k iff z ∈ I_k = (zeta_{k-1}, zeta_k]`.
Exactness is immediate: `P(z ∈ I_k | eta) = Phi(zeta_k - eta) - Phi(zeta_{k-1} - eta)` ✓.

Everything from A2 onward goes through with `H_y` replaced by `I_k`, because **nothing in A2-A4
used the fact that `H_y` was a half-line** — only that it was a fixed `a`-free set. So (A3.1)
gives `q*(z) = TN(mu, 1, I_k)` (now *doubly* truncated), with

```
E_{q*}[z] = mu + [ phi(zeta_{k-1} - mu) - phi(zeta_k - mu) ]
                 / [ Phi(zeta_k - mu) - Phi(zeta_{k-1} - mu) ]                       (B3.1)
```

and (A4.1) gives the profiled value

> **E_AC_ord(mu, v) = log[ Phi(zeta_k − mu) − Phi(zeta_{k−1} − mu) ] − v/2**          (B4.1)

Again: only `(mu, v)` and the cutpoints. No residual free parameter. **Objective substitution.**

The lower-bound proof needs no change either: (A5.3) was stated for a general `w ≥ 0`, and
`I_k` is an interval, so Brascamp–Lieb gives `Var_{q*}(z) ≤ 1` exactly as before, hence
`(d²/dmu²) log p_k ∈ (-1, 0]` and `E_AC_ord ≤ F_ord`, strict for `v > 0`. Measured: max
`Var` over doubly-truncated normals on `(-1,1)` is `0.291 ≤ 1` ✓ (§7).

Derivatives:

```
∂E_AC_ord/∂mu = [ phi(zeta_{k-1}-mu) - phi(zeta_k-mu) ] / [ Phi(zeta_k-mu) - Phi(zeta_{k-1}-mu) ]
              = E_{q*}[z] - mu           (identical to (B3.1) minus mu — the (A5.3) identity)
∂E_AC_ord/∂v  = -1/2                                                                 (B6.1)
```

**Cross-check against the reference:** this `∂/∂mu` is *literally* gllvm's `deriv.trunnorm`
(deparsed lines 620-623):
`(-dnorm(zeta_k - eta) + dnorm(zeta_{k-1} - eta)) / (pnorm(zeta_k - eta) - pnorm(zeta_{k-1} - eta))`.
Measured agreement with a numerical derivative of (B4.1): **6.07e-11** (§7). So gllvm's
ordinal gradient is exactly the gradient of the objective derived here — a third independent
confirmation.

### 5.7 — the CDF difference: how to compute `log(Phi(a) − Phi(b))` stably

(B4.1) breaks the VA template's standing invariant (`:176-180`: *"the cancellation-prone
difference of two nearly-equal CDFs … is never formed at all"*). It must now be formed. Two
mitigating facts first:

- It is formed **once per cell at `eta = mu`**, not at `H` quadrature nodes. This is the *same*
  regime `src/gllvmTMB.cpp` already handles under Laplace, not the harder AGHQ regime its
  comment at `:2291-2297` warns about.
- Consequently the `log(1e-300)` floor at `:2309-2310`, which that comment says *"BINDS at AGHQ
  quadrature nodes"*, is back to being effectively non-binding under AC — there are no nodes.
  This is a genuine point in AC's favour and should be reused.

**The algorithm.** Factor out the larger of the two probabilities, and pick the branch by
`sign(a+b)` so the *smaller* of the two candidate leading terms is used:

```
a > b.   left  form  (a + b ≤ 0):  logPhi(a)  + log1mexp( logPhi(b)  - logPhi(a)  )
         right form  (a + b > 0):  logPhi(-b) + log1mexp( logPhi(-a) - logPhi(-b) )
```

Both `log1mexp` arguments are `≤ 0` by construction (`a > b` ⟹ `Phi(b) ≤ Phi(a)` and
`Phi(-a) ≤ Phi(-b)`). Measured necessity of the branch (§7) — the naive
`log(pnorm(a) - pnorm(b))` is fine in the left tail and **dies in the right tail**:

| `a` | `b` | naive `log(pnorm(a)-pnorm(b))` | stable form |
|---:|---:|---:|---:|
| −9.00 | −9.20 | −43.800817 | −43.800817 |
| **+9.20** | **+9.00** | **−Inf** | **−43.800817** |
| −30.00 | −30.20 | −454.323660 | −454.323660 |
| **+30.20** | **+30.00** | **−Inf** | **−454.323660** |

**Can `gll_log_pnorm_diff` (`src/gllvmTMB.cpp:105-124`) be ported as-is? NO — the algorithm is
correct and should be kept verbatim, but two changes are required.**

**Change 1 (primitive quality).** It calls `gll_log_pnorm`, which switches at `x = -20` to a
**4-term asymptotic** Mills series (`:95-99`). The VA template's `va_r3_log_pnorm` (`:181-197`)
switches at `-10` to a **20-term convergent continued fraction**, documented as 0 ULP over
`z ∈ [10,200]` and correct to `x = -145`. The VA tier must use the *better* primitive it
already owns. Re-point `gll_log_pnorm` → `va_r3_log_pnorm`.

**Change 2 (AD-safety — this is the real one).** `gll_log_pnorm_diff` selects with
`CppAD::CondExpLe`, and **`CondExp` evaluates BOTH branches**. The template's own comment
(`:163-175`) documents, with measurements, that an unselected branch computing a non-finite
value leaves `fn` and `gr` finite **and correct** while producing a **NaN Hessian** — and warns
that any check must call `obj$he()`, not just `obj$gr()`.

The unselected branch here *is* non-finite, and it is reachable. `gll_log_pnorm`'s direct
branch is `log(pnorm(xd))` — **not** `pnorm(xd, log.p=TRUE)` — and `pnorm(x)` rounds to exactly
`1.0` in double for `x > 8.2924` (measured). So when `a` and `b` are both below `−8.2924`,
`logPhi(-a)` and `logPhi(-b)` are both exactly `0.0`, their difference is exactly `0`, and
`gll_log1mexp(0)` takes its series branch with `series_arg = 0` → `log(0) = −Inf`.
Reproduced with the exact C++ formulae (§7):

| `a` | `b` | selected | unselected branch |
|---:|---:|:---|:---|
| −7.0 | −8.0 | left | finite |
| **−8.5** | **−9.0** | left | **−Inf** |
| **−9.0** | **−10.0** | left | **−Inf** |
| **+9.0** | **+8.5** | right | **−Inf** |

An ordinal cell whose category bounds sit more than ~8.3 units from `eta` is not exotic — a
rare extreme category with a moderately large linear predictor reaches it.

**The fix, in the template's own idiom: clamp the INPUT of each branch, never its output.**
The clamp must make *both* `log1mexp` branches finite, so the floor is set at the unit
roundoff, not at `1e-300`:

```cpp
// log(1 - exp(a)) for a <= 0.  The input is clamped to a <= -1.2e-16 (just past the
// double unit roundoff) so that NEITHER branch can return -inf on an UNSELECTED
// CondExp path -- same discipline as va_r3_log_pnorm (:154-180).  A 1e-300 floor is
// NOT sufficient: it rescues the series branch but leaves the direct branch computing
// log(1 - exp(-1e-300)) = log(0).
template <class Type>
Type va_r3_log1mexp(const Type &a)
{
  const Type ceil_a = Type(-1.2e-16);
  Type ac  = CppAD::CondExpGt(a, ceil_a, ceil_a, a);        // min(a, -1.2e-16)
  Type u   = -ac;                                            // u >= 1.2e-16
  Type series = log(u - u*u/Type(2.0) + u*u*u/Type(6.0));    // > 0 for all u > 0
  Type direct = log(Type(1.0) - exp(ac));                    // >= log(1.11e-16)
  return CppAD::CondExpLt(u, Type(1e-6), series, direct);
}
```

Three notes on why this is safe. (i) The cubic `u - u²/2 + u³/6` has derivative
`((u-1)² + 1)/2 > 0` for all `u`, so it is strictly increasing from `0` and **strictly positive
for every `u > 0`** — the unselected *series* branch is finite at any `u`, including large `u`.
(ii) Where the clamp binds, `CondExp` returns a constant, so the propagated partial is exactly
`0` — correct for a branch that must not contribute. (iii) The clamp binds only when the two
probabilities agree to within one unit roundoff, i.e. a degenerate/empty category; it floors
the *ratio*, not the absolute probability, degrading gracefully to `logPhi(a) − 36.7` rather
than `−inf`.

### 5.8 — cutpoint parameterisation: PINNED

**The VA tier must use the Laplace engine's parameterisation, unchanged**
(`src/gllvmTMB.cpp:2282-2285`):

```
zeta_1 = 0 (fixed, identifiability);   zeta_j = zeta_{j-1} + exp(log_increment_{j-1})
per-trait blocks via n_ordinal_cuts_per_trait(t) / ordinal_offset_per_trait(t)
free parameters: K_t - 2 per ordinal trait t
```

Four reasons, in decreasing order of force:

1. **The ordering constraint must be structural, not hoped-for.** (B4.1) contains
   `log[Phi(zeta_k − mu) − Phi(zeta_{k−1} − mu)]`. If the optimiser ever puts
   `zeta_{k-1} > zeta_k`, the argument of the `log` goes **negative** → `NaN`, not a large
   penalty. The log-increment form makes crossing *impossible by construction*. This is a
   harder requirement under AC than under GH: AC has no quadrature averaging to smooth over a
   boundary excursion, and the VA path optimises unconstrained (`nlminb`/`optim`), so there is
   no box constraint to lean on.
2. **Cross-engine comparability is the arc's validation strategy.** The AC tier will be checked
   against Laplace on the same fit. A different cutpoint parameterisation makes the two
   parameter vectors incomparable and forces a reparameterisation map into every test.
3. **`zeta_1 = 0` with a free trait intercept `beta_j`** (rather than free cutpoints with no
   intercept) is the choice Laplace already made; the probit link already fixes the residual
   scale at 1, so only the location needs pinning. Match it.
4. **Reuse the `log(1e-300)` floor** at `:2309-2310` for the same reason it exists — with the
   §5.7 caveat that under AC it is essentially non-binding.

---

## 6. Where this disagrees with `MATURE-VA.md` and with gllvm

### 6.1 — `MATURE-VA.md` §Item 1: conclusion right, one premise wrong

> *"Uses only `Phi`/`phi` — TMB-native smooth atomics, so it is an objective substitution, not
> an architecture change."*

The **conclusion is correct and now proved** (§3, §5). The **premise is wrong for ordinal**:
`Phi` and `phi` being smooth atomics does not make `log(Phi(a) − Phi(b))` safe — the difference
is a cancellation-prone construction that returns `−Inf` from a naive implementation at
`|a|,|b| ≳ 8.3` on the same side (§5.7, measured), and importing the existing Laplace helper
verbatim would put a `−Inf` on an unselected `CondExp` branch and produce a **NaN Hessian**.
For **binary probit the premise holds exactly** — that path really is only `logPhi` and a
linear term.

Second correction, to scope rather than to premise: the document treats ordinal as part of one
item. **The VA engine has no ordinal family at all**, so (B) is a new family, not a branch.

### 6.2 — gllvm: the derivation agrees on the objective and DISAGREES on the `n>1` coefficient

Agreement is exact on three independent points (§7): the objective evaluates `Phi` at `mu`
(deparsed lines 382, 401-403); `calc.quad` returns `0.5 * theta_j' Lambda_i theta_j` — i.e.
**exactly `v_ij/2`** — and lines 386-388/408-410 subtract it, which is the `−v/2` term; and the
`A_i` fixed point (4.1) appears verbatim at lines 1142-1144/1188-1198.

**The disagreement:** gllvm subtracts `calc.quad(...)$mat.sum` **once per cell**, i.e. `−v/2`,
regardless of `trial.size`. The derivation gives **`−n·v/2`** (A4.4) — `n` independent latent
`z`'s, each charging `v/2`. At `trial.size = 1` the two coincide. At `trial.size > 1` gllvm's
form is **not a lower bound at all**. Measured (§7), over `mu ∈ {−2,−0.5,0,0.5,2}`,
`v ∈ {0.05,0.5,2}`:

| form | `min(exact − bound)` | verdict |
|:--|--:|:--|
| `− n·v/2` (this derivation) | **+0.00287** | valid lower bound |
| `− v/2` (gllvm's) at `n = 1` | +0.00287 | valid (coincides) |
| `− v/2` (gllvm's) at `n = 20` | **−10.976** | **INVALID — exceeds the true value by up to 11 nats** |

`gllvmTMB`'s template carries `n_trials` and supports `n > 1`, so **it must use `−n·v/2`.**
Whether gllvm actually admits `trial.size > 1` through its VA path (as opposed to erroring or
being untested there) is **UNVERIFIED** — I read the objective, not the argument validation.
Either way this is a place where copying the reference would be wrong for us.

A second, smaller improvement over the reference: gllvm's probit gradient (deparsed lines
557-559) is
`dnorm(eta)*(y - trial.size*probs)/(probs*(1-probs) + 1e-05)` — a `+1e-05` ridge in the
denominator, which **biases the gradient** wherever `Phi(1-Phi) ≲ 1e-5`, i.e. `|eta| ≳ 4.4`.
Form (A6.1) needs no such ridge: it is `y·lam(mu) − (n−y)·lam(−mu)`, and `va_r3_inv_mills`
returns the continued-fraction denominator directly rather than dividing by a probability that
has underflowed (`:199-214`). **The AC tier in gllvmTMB will be strictly more accurate in the
tails than gllvm's own implementation of the same theorem** — which is exactly the "our
accuracy" side of the arc's target.

---

## 7. Verification log (what was actually measured)

`scratchpad/verify.R`, `scratchpad/verify2.R`. Reference `E[·]` by 200-node Gauss–Hermite.

| # | check | result |
|:--|:--|:--|
| 1 | `argmax_c L_z(c)` over TN location `c` equals `mu` | max abs deviation **1.76e-05** (optimiser tol) ✓ |
| 2 | `max_c L_z(c)` equals `logPhi(s·mu) − v/2` | max abs deviation **6.17e-11** ✓ **(A4) confirmed** |
| 3 | `exact − bound ≥ 0` (lower bound), 70 cells | min **+1.20e-10** (at `v=1e-8`) ✓ |
| 4 | strictness for `v > 1e-6` | min gap **+6.01e-04** ✓ |
| 5 | `gap ≤ v/2` (A5.5) | max `gap/(v/2)` = **1.000** ✓ |
| 6 | `(logPhi)''` range over `x ∈ [−40,10]` | **(−0.99938, −7.7e-22)** ⊂ (−1,0) ✓ |
| 7 | `n>1`: `−n·v/2` valid / `−v/2` invalid | **+0.00287** / **−10.976** ✓ §6.2 |
| 8 | ordinal bound (stable log-difference), 60 cells | all finite; min gap **+1.03e-12**; max `gap/(v/2)` **0.552** ✓ |
| 9 | ordinal `∂/∂mu` vs gllvm `deriv.trunnorm` | **6.07e-11** ✓ |
| 10 | `Var` of doubly-truncated normal ≤ 1 (Brascamp–Lieb) | max **0.291** ✓ |
| 11 | naive CDF difference fails in the RIGHT tail | `−Inf` at `(9.2, 9.0)` and `(30.2, 30.0)` ✓ §5.7 |
| 12 | `gll_log_pnorm_diff` unselected branch, exact C++ formulae | **`−Inf` for `|a|,|b| > 8.2924`** ✓ §5.7 |

Not verified: nothing in this document was checked by compiling TMB code — all checks are
R-level evaluations of the same formulae. The AD-safety claims in §5.7 are *predictions* from
the template's own documented `CondExp` semantics plus double-precision reproduction of the
branch values; they become facts only when `obj$he()` is run. Marked **UNVERIFIED** until then.
The Hui et al. (2017) JCGS paper itself was **not** retrieved — the derivation stands on its own
algebra and on the three independent agreements with gllvm's source (§6.2). Theorem numbering
attributed to it in `MATURE-VA.md` is therefore **UNVERIFIED** here.

---

## 8. Alignment table (house format, per `AGENTS.md` symbolic-alignment discipline)

| symbolic math | R syntax | TMB implementation | what it means | how it will be checked |
|:--|:--|:--|:--|:--|
| `z_ij ~ N(eta_ij, 1)`, `y_ij = 1{z_ij>0}`; `q*(z) = TN(mu,1,H_y)`, `E[z]=mu+s·lam(s·mu)` | *(never materialised in R — no user-facing object)* | *(never materialised in C++ — profiled out analytically, (A4.1))* | The Albert–Chib auxiliary. It is an **intermediate of the derivation, not of the code**: the `½log2pi` and `½(1−L·alpha)` terms cancel identically between the quadratic term and the entropy. | Parameter count and `obj$par` names must be **byte-identical** to the GH tier for the same model; `REPORT()` must expose no `z`. A new VA parameter appearing = derivation violated. |
| `E_AC = y·logPhi(mu) + (n−y)·logPhi(−mu) − n·v/2` | `eval_method = "ac"` | `va_r3_probit_ac_expectation(mu, v, y, n)`, new helper beside `:231-260` | The replacement evaluator. Same units as `va_r3_probit_expectation`, so `ell = log_choose + <evaluator>` at `:886-887` is unchanged. | Against the R oracle of §7 check 2 (agreement `6.2e-11`); and `E_AC ≤ E_GH(H=61)` cell-wise for `n ∈ {1,5,20}` (§7 check 7). |
| `∂E/∂mu = y·lam(mu) − (n−y)·lam(−mu)`;  `∂E/∂v = −n/2` | `TMB::MakeADFun(...)$gr` | `va_r3_inv_mills(mu)`, `va_r3_inv_mills(-mu)` (`:205-214`); `v` enters linearly | AD-differentiability. No `sqrt(v)` anywhere ⟹ **no small-`v` branch, no `CondExp`, no threshold** — unlike the GH evaluator. | Finite difference on `∂/∂mu` at `mu ∈ {−6,−3,−1,0,0.5,2,5}`; `∂/∂v` must return **exactly `−n/2`** for every `(mu,v,y,n)` — a distinctive signature. Plus `obj$he()` finite (not just `gr()`), per `:163-175`. |
| `E_AC_ord = log[Phi(zeta_k−mu) − Phi(zeta_{k−1}−mu)] − v/2`, `zeta_j = zeta_{j−1} + exp(inc_{j−1})`, `zeta_1 = 0` | `family = "ordinal_probit"`, `ordinal_log_increments` | `va_r3_log_pnorm_diff` (port of `gll_log_pnorm_diff` with **both** §5.7 changes) + `va_r3_log1mexp` | The ordinal tier. Breaks the "never form a CDF difference" invariant (`:176-180`) — deliberately, and only at `eta = mu`, never at quadrature nodes. | Both tails: `(a,b) = (±9.2, ±9.0)` and `(±30.2, ±30.0)` must match the stable oracle to `< 1e-10` where naive gives `−Inf` (§7 check 11). Cutpoints must be **non-crossing by construction** — assert `diff(zeta) > 0` at every optimiser trace point. |
| `A_i^{-1} = Sigma^{-1} + Σ_j n_ij·lambda_j lambda_j'` (data-independent) | `latent_uncertainty(fit)$sd` | *(emergent property of the optimum, not coded)* | Consequence of `∂E/∂v ≡ −n/2`. Confirms the derivation **and** fences the honesty claim: VA-AC per-unit SDs carry no per-unit information. | On a complete-data pure-probit fit, per-unit `A_i` must be **numerically identical across all `i`** (matches gllvm lines 1188-1198). Heterogeneity ⟹ derivation wrong. Fences: no interval/coverage claim from AC SDs without its own evidence. |

---

## 9. Implementation sketch

### 9.1 — the new evaluator (binary probit)

```cpp
// Albert-Chib closed-form replacement for va_r3_probit_expectation.
//
// Returns E[y logPhi(eta) + (n-y) logPhi(-eta)] in the SAME UNITS as the GH
// evaluator above, so both plug into the identical
//   ell = log_choose + <evaluator>
// formula at the fam == 4 dispatch -- the same contract
// va_r3_jj_softplus_expectation() honours for fam == 1.
//
// This is a strict LOWER BOUND on the GH value, not an approximation to it
// (proof: dev/va-speed/ALBERT-CHIB-DERIVATION.md A5).  It is therefore a
// DIFFERENT OBJECTIVE and must carry its own accuracy evidence.
//
// No gh_nodes, no threshold, no CondExp: v enters LINEARLY, so the sqrt(v)
// unbounded-derivative-at-zero problem that forces the GH evaluator's small-v
// expansion branch does not arise.  n*v/2, NOT v/2 -- one latent z per TRIAL
// (see s6.2: the v/2 form is not a lower bound for n > 1).
template <class Type>
Type va_r3_probit_ac_expectation(const Type &mu, const Type &v,
                                 const Type &y, const Type &n)
{
  return y * va_r3_log_pnorm(mu) + (n - y) * va_r3_log_pnorm(-mu)
    - n * v / Type(2.0);
}
```

### 9.2 — touch points

Confirmed against the tree; the brief's list is accurate for (A), with three additions marked **+**.

| # | site | change | risk |
|:--|:--|:--|:--|
| 1 | `inst/tmb/gllvmTMB_va_r3.cpp` new helper beside `:231-260` | add `va_r3_probit_ac_expectation` | low |
| 2 | `:876-888` (`fam == 4` block) | `eval_method == 2 ? va_r3_probit_ac_expectation(mu,v,y(r),n) : va_r3_probit_expectation(...)`, mirroring the `fam == 1` pattern at `:847-849` | low |
| 3 | `:523-524` | `eval_method != 0 && != 1 && != 2`; update the message | low |
| 4 | `:530-533` / `:534-560` | the `n_non_jj` counter guards JJ against non-binomial. AC needs the **mirror-image** guard: AC is defined for family **4 only** (and later 5), i.e. exactly the families JJ rejects | **medium — easy to get backwards** |
| 5 | `R/va-r3-proto.R:1231` registry | `tiers = c("gh","ac")`, `optimizer_by_tier = list(gh="nlminb", ac=...)`. **Keep `default_tier = "gh"`** — AC is a different objective and must not become the default before it carries accuracy evidence (`MATURE-VA.md` §Item 1) | low |
| 6 | `:1268-1271` `.va_r3_eval_method_code()` | currently `if (resolved == "jj") 1L else 0L` — a **boolean collapse**. Must become a 3-way map | **HIGH — "ac" silently maps to `0L` (GH). A silently wrong-tier fit, not an error.** |
| 7 | `:1272-1274` `.va_r3_objective_type()` | `if (jj) "ELBO_JJ" else "ELBO_GH"` → add `"ELBO_AC"`. Same silent collapse | **HIGH — mislabels the objective, enabling invalid cross-tier value comparison** |
| **+8** | `:1252` and `:1268` `match.arg` signatures | `c("auto","jj","gh")` → add `"ac"` in **both** `.va_r3_resolve_eval_method` and `.va_r3_eval_method_code` | low (hard error today, so it fails loudly) |
| **+9** | `:1254-1261` mixed-family guard | decide whether `"ac"` is legal in mixed-family fits. `eval_method` is a single global scalar, so simplest is to treat AC like JJ (pure-family only). **Maintainer decision** | low |
| **+10** | `REPORT(eval_method)` at `:905` | already reports; the round-trip `eval_method="ac"` → `REPORT` returns `2` is the cheapest falsifier for #6/#7 | — |

For (B) ordinal, additionally: a new family code `5` (validation `:543-544`, dispatch
`:831-888`), `DATA_IVECTOR(n_ordinal_cuts_per_trait)`, `DATA_IVECTOR(ordinal_offset_per_trait)`,
`PARAMETER_VECTOR(ordinal_log_increments)`, `va_r3_log1mexp` + `va_r3_log_pnorm_diff`, and the
R-side family registry entry, data assembly, parameter packing, and identifiability gate.
**This is a separate slice.**

---

## 10. RISKS, each with a falsifier

**R1 — accuracy regression (the arc's binding constraint).** AC is a *strictly looser* bound,
and (A5.5) shows it is loosest exactly on **well-fitted** cells — which, at convergence, is
most of them. `MATURE-VA.md` sets `rel_frob ≤ 0.298`.
*Falsifier:* planted-truth recovery at the reference cell (N=250, T=20, q=1, binomial-probit),
4 seeds. `rel_frob > 0.298` on any seed ⟹ Item 1 fails the arc's constraint regardless of speed.

**R2 — variance collapse.** (4.1): `A_i` is data-independent and identical across units.
Variational SDs carry no per-unit information; interval/coverage behaviour should be expected
to *degrade* relative to GH.
*Falsifier of the derivation:* fit AC on complete pure-probit data and compare per-unit `A_i` —
they must be numerically identical. **Heterogeneity ⟹ §4 is wrong.**
*Fence (not falsifiable, must simply be honoured):* no interval or coverage claim from AC SDs
without its own evidence.

**R3 — the `n > 1` coefficient.** Copying gllvm's `−v/2` gives an expression that is **not a
lower bound** for `n > 1`.
*Falsifier:* `E_AC ≤ E_GH(H=61)` cell-wise for `n ∈ {1,5,20}`. With `−v/2` this fails by up to
**10.976 nats** at `n=20` (already measured, §7 check 7). With `−n·v/2` it passes.

**R4 — cross-tier value comparison.** `ELBO_AC < ELBO_GH < loglik`. Comparing objective values
across tiers (AIC, likelihood-ratio, convergence diagnostics) is meaningless.
*Falsifier:* any code path that compares a fit's objective without checking `objective_type`.
Grep for consumers of `objective_type`; touch point #7 must land before any such comparison.

**R5 — NaN Hessian from the ported CDF difference.** §5.7, measured for `|a|,|b| > 8.2924`.
*Falsifier:* an ordinal fit with a category whose cutpoints sit > 8.3 from `eta`; **`obj$he()`
must be finite**. `obj$gr()` alone will NOT catch this — the template documents (`:166-175`)
that the gradient stays finite *and correct* while the Hessian dies.

**R6 — silent tier collapse.** Touch points #6/#7 are boolean collapses; `"ac"` falls through
to `0L`/`"ELBO_GH"` with no error. A user asks for AC, gets GH, and the benchmark measures
nothing.
*Falsifier:* round-trip `eval_method="ac"` → `REPORT(eval_method)` must return `2` **and**
`objective_type` must be `"ELBO_AC"`. Run this **before** any timing.

**R7 — Amdahl: the speed target is not reachable by this item alone.** GH at 75% of runtime
caps the speedup at **4×**: 45.6 s → ~11.4 s, still **16×** slower than gllvm's 0.70 s.
*Falsifier:* re-profile after the substitution. If runtime is ≫ 0.70 s, Item 1 does not deliver
the arc's speed goal and the remaining cost is elsewhere.
*Where it probably is:* §4. gllvm collapses the variational-covariance block from
`N × q(q+1)/2` parameters to `q(q+1)/2` (250 → 1 at the reference cell) by exploiting
`A_i ≡ A`. **That**, not the closed form, is the plausible source of the 65× gap — and (4.1)
now licenses the same collapse for us, as a follow-on slice. Its validity is bounded by the §4
caveat (complete data, constant `n_ij`, pure probit; **UNVERIFIED for the Stage-7 structured
tiers**).

**R8 — the bound is loose exactly where the JJ tier is also loose.** Both AC (probit) and JJ
(logit) are worst-case-curvature bounds. If the JJ tier already shows a measured accuracy
penalty, that is the closest available prior for AC's.
*Falsifier:* compare AC-vs-GH accuracy degradation against the recorded JJ-vs-GH degradation;
a much larger AC penalty than JJ's would indicate an implementation error rather than the
expected bound slack.
