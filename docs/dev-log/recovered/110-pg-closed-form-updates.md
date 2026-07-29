# Design 110 — Closed-form Polya-Gamma / Jaakkola-Jordan coordinate updates for the R3 variational block

**Status:** derived and numerically verified against the live objective.
**Scope:** `inst/tmb/gllvmTMB_va_r3.cpp` with `family = 1` (binomial-logit) and
`eval_method = 1` (JJ/PG bound). Nothing here applies to `eval_method = 0`
(Gauss-Hermite), nor to families 0/2/3.
**Verification scripts:** `dev/polya-cavi-verify.R`, `dev/polya-cavi-stress.R`.
No file under `R/`, `src/`, `inst/`, or `tests/` was modified.

---

## 0. Headline

The conjecture is **correct in structure and wrong in one term**. The canonical
logistic-regression CAVI form does *not* transfer unchanged: the fixed intercept
/ covariate offset `beta` enters the mean update through a term the conjecture
omits. With that term restored, the update drives the engine's own gradient
`obj$gr` on the variational block to **1.6e-15** and reaches a *lower* negative
ELBO than `nlminb` does.

The same derivation extends to `beta` and `theta_rr`. **The entire R3 JJ fit has
a closed form.** A full sweep — variational block, then `beta`, then `Lambda` —
needs no numerical optimiser at all and drives *every* gradient block to
&lt;= 1.3e-13.

---

## 1. The objective, exactly as coded

Read from `gllvmTMB_va_r3.cpp`: JJ evaluator at lines 96-113, likelihood
assembly at lines 297-375, KL at lines 259-269.

### Notation

| symbol | code | meaning |
|---|---|---|
| `Lambda` (T x q) | lines 220-233 | loadings; `lambda_t` is row `t` as a column vector |
| `m_i` (q) | `m(i, .)` | variational mean for unit `i` |
| `L_i` (q x q, lower) | `log_L_diag`, `L_off` | variational Cholesky |
| `S_i = L_i L_i'` | line 273 | variational covariance |
| `a_it = x_it' beta` | lines 301-303 | fixed linear offset |
| `mu_it = a_it + lambda_t' m_i` | lines 301-305 | |
| `v_it = \|\|L_i' lambda_t\|\|^2 = lambda_t' S_i lambda_t` | lines 307-319 | |
| `n_it` | `n_trials(r)` | trials, integer >= 1 |

### The three pieces

Per observation (line 343, with the JJ branch at line 340):

```
ell_it = log_choose_it + y_it * mu_it - n_it * G(mu_it, v_it)
G(mu, v) = log(2 cosh(xi/2)) + mu/2,      xi = sqrt(mu^2 + v)
```

Per unit (lines 268-269), i.e. the KL to a standard normal prior `N(0, I_q)`:

```
KL_i = 0.5 * ( tr S_i + m_i'm_i - log det S_i - q )
```

The template returns `negative_elbo = -(sum_it ell_it - sum_i KL_i)` (lines
377-380). **The engine minimises; the updates below maximise the ELBO.**

### The key structural fact: `G` is already xi-profiled

The Jaakkola-Jordan bound is, for any free `xi >= 0`,

```
softplus(eta) = eta/2 + log(2 cosh(eta/2))
              <= eta/2 + log(2 cosh(xi/2)) + (w(xi)/2) * (eta^2 - xi^2)
w(xi) := tanh(xi/2) / (2 xi)                                    (= E[PG(1, xi)])
```

because `z |-> log(2 cosh(sqrt(z)/2))` is concave in `z = eta^2`. Taking
`eta ~ N(mu, v)`:

```
E[softplus(eta)] <= mu/2 + log(2 cosh(xi/2)) + (w(xi)/2) * (mu^2 + v - xi^2)
                 =: G_xi(mu, v)
```

with equality iff `xi^2 = mu^2 + v`. **The template evaluates `G = min_xi G_xi`,
i.e. it has already maximised `xi` out analytically.** Write `u` for all the
model parameters and

```
ELBO_JJ(u, xi) = sum_it [ log_choose_it + y_it mu_it - n_it G_xi_it(mu_it, v_it) ] - sum_i KL_i
```

Since `n_it > 0`, `G_xi >= G` gives `ELBO_JJ(u, xi) <= ELBO_engine(u)`, with
equality at `xi_it = sqrt(mu_it^2 + v_it)`. Therefore

> **ELBO_engine(u) = max_xi ELBO_JJ(u, xi).**

`ELBO_JJ` is *quadratic* in `z_i` at fixed `xi`; `ELBO_engine` is not. This is
the whole mechanism, and it is also what makes the answer to §4 subtle.

---

## 2. Deriving the update

Fix `xi`. Set

```
c_it := y_it - n_it/2                    (T-vector c_i per unit)
w_it := n_it * w(xi_it) = n_it * tanh(xi_it/2) / (2 xi_it)   >= 0
W_i  := diag(w_i1, ..., w_iT)
a_i  := (a_i1, ..., a_iT)'               (the beta offset)
```

Restrict `ELBO_JJ` to unit `i` and drop everything free of `(m_i, S_i)`. Using
`E_q[eta_it] = mu_it` and `E_q[eta_it^2] = mu_it^2 + v_it`:

```
F_i = sum_t [ c_it * mu_it - (w_it/2) * (mu_it^2 + v_it) ] - KL_i + const
```

Substitute `mu_it = a_it + lambda_t' m_i` and `v_it = lambda_t' S_i lambda_t`,
and expand `sum_t w_it (a_it + lambda_t'm_i)^2`:

```
F_i = m_i' Lambda'(c_i - W_i a_i)
      - (1/2) m_i' (Lambda' W_i Lambda + I_q) m_i
      - (1/2) tr[ (Lambda' W_i Lambda + I_q) S_i ]
      + (1/2) log det S_i
      + const
```

The cross term `- sum_t w_it a_it (lambda_t' m_i) = - m_i' Lambda' W_i a_i` is
exactly the term the conjecture drops. `m_i` and `S_i` **separate**, and `F_i`
is concave in each (`-(1/2)m'Am` with `A` PD; `-(1/2)tr(AS) + (1/2)logdet S` is
concave on the PD cone). Setting the two gradients to zero:

```
d/dS_i:  -(1/2) A_i + (1/2) S_i^{-1} = 0
d/dm_i:  Lambda'(c_i - W_i a_i) - A_i m_i = 0
```

### 2.1 The updates

> **A_i = Lambda' W_i Lambda + I_q**
>
> **S_i = A_i^{-1}**
>
> **m_i = S_i Lambda' ( c_i - W_i a_i )
>       = S_i Lambda' [ (y_i - n_i/2) - W_i X_i beta ]**
>
> **w_it = n_it * tanh(xi_it/2) / (2 xi_it)**
>
> **xi_it = sqrt( mu_it^2 + v_it ) = sqrt( (a_it + lambda_t'm_i)^2 + lambda_t' S_i lambda_t )**

Differences from the conjecture in the brief:

1. **`- W_i a_i` is required.** The conjecture's `m_i = S_i Lambda'(y_i - n_i/2)`
   is correct only when `X beta = 0`. Numerically (§5) its fixed point sits
   **11.9 nats worse** with engine gradient **2.16**, not zero. The regression
   form does not transfer unchanged, exactly as the brief warned.
2. **`n_it` enters only through `w_it = n_it * w(xi_it)`**, and *not* through
   `c_it`'s scale — `c_it = y_it - n_it/2` already carries it. Multi-trial is
   handled exactly; no binary-expansion argument is needed.
3. **The prior contributes `+I_q`, not `Sigma_0^{-1}`**, because the KL as coded
   (line 268) is against `N(0, I_q)`. Hence `A_i >= I` always.
4. `S_i` is a *full* unstructured `q x q` covariance, matching the engine's
   unstructured Cholesky. No structural restriction is imposed or needed.

### 2.2 The xi update — yes, it is what the template already computes

Maximising `G_xi(mu, v)`'s negative over `xi` gives `xi^2 = mu^2 + v`, i.e.
`xi_it = sqrt(mu_it^2 + v_it)` with `mu_it` and `v_it` recomputed from the
**new** `(m_i, S_i)`. This is **identical** to the `xi2 = mu*mu + v` the template
forms at line 100. The template's `xi` is not an extra parameter to track; it is
this update, already inlined.

The consistent small-`xi` limit is `w(xi) = 1/4 - xi^2/48 + xi^4/480 + O(xi^6)`,
which is exactly `2 * dG/d(xi^2)` for *both* branches of
`va_r3_jj_softplus_expectation` (the exact branch gives `tanh(xi/2)/(4 xi)`; the
Taylor branch at line 106-110 gives `(1/4)(1/2 - t/6 + t^2/15)` with
`t = xi^2/4`, and the two agree term by term). Use the series below
`xi^2 ~ 1e-6`, matching the template's own threshold.

### 2.3 Bonus: `beta` and `Lambda` are closed form too

The same surrogate is quadratic in `beta` and, row-wise, in `Lambda`. At fixed
`xi` and `(m, S)`:

```
beta:      ( sum_it w_it x_it x_it' ) beta = sum_it x_it ( c_it - w_it lambda_t' m_i )
Lambda:    ( sum_i w_it (m_i m_i' + S_i) ) lambda_t = sum_i m_i ( c_it - w_it a_it )
```

one `p x p` weighted-least-squares solve for `beta` and one `q x q` solve per
trait for `Lambda`. The lower-triangular constraint on `Lambda` is honoured by
solving only the free sub-block `1..min(t, q)` of row `t`. The `Lambda` system
matrix is PD whenever `w_it > 0` and `S_i > 0`, so no ridge is needed. Note that
`v_it = lambda_t' S_i lambda_t` depends on `Lambda`; the `+ S_i` inside the
system matrix is precisely that contribution — it is not an approximation.

**Verified (§5B): a full sweep drives every gradient block, including `beta`
and `theta_rr`, to <= 1.3e-13, and beats `nlminb` on the full parameter vector.
The R3 JJ fit needs no numerical optimiser anywhere.**

---

## 3. Is this EXACT coordinate ascent on the engine's objective?

**No — and the distinction matters. It is exact block coordinate ascent on the
*augmented* objective `ELBO_JJ(u, xi)`, which makes it a monotone MM
(minorise-maximise) algorithm on the engine's objective, not exact coordinate
maximisation of it.**

Precisely:

- The `(m_i, S_i)` step **globally maximises** `ELBO_JJ(., xi)` at the current
  `xi` — that part is exact, and it is a *global* max because the surrogate is
  jointly concave in `(m_i, S_i)`.
- It does **not** maximise `ELBO_engine` over `(m_i, S_i)`. `ELBO_engine` is the
  `xi`-profiled objective, and maximising a minorant is not the same as
  maximising the function.

Three consequences, all of which matter operationally:

**(a) Monotone.** With `xi_1 = xi*(u_0)` (exact) and
`u_1 = argmax_u ELBO_JJ(u, xi_1)`,

```
ELBO_engine(u_1) >= ELBO_JJ(u_1, xi_1) >= ELBO_JJ(u_0, xi_1) = ELBO_engine(u_0)
```

so the engine's negative ELBO never increases. Measured worst per-sweep increase
across all cases: **<= 2.2e-12** (floating point).

**(b) The fixed points are exactly the stationary points of the engine
objective.** By Danskin's theorem, since `xi*(u)` is the unique maximiser,

```
grad_u ELBO_engine(u) = grad_u ELBO_JJ(u, xi*(u))
```

The surrogate is *tangent*, not merely below. So if a sweep returns `u_1 = u_0`,
then `grad_u ELBO_JJ(u_0, xi*(u_0)) = 0` and hence
`grad_u ELBO_engine(u_0) = 0`. **This is the checkable claim, and it is the one
the brief demanded**: the engine's own `obj$gr` must vanish at the fixed point.
Measured: **1.6e-15** on the variational block. Confirmed.

**(c) Rate, not correctness, is what is given up.** MM converges linearly, with
rate set by the tightness of the JJ bound; Newton-type optimisation of the
profiled objective would be superlinear. In practice the sweeps here reached
machine-precision stationarity in 4-5 sweeps. **AGENT-INFERRED:** that this
sweep count holds at `n = 5397, q = 2` is *not* tested here — per instruction no
timings were run, and sweep count at scale is unmeasured.

A note on what would be exact: nothing simple. `ELBO_engine` restricted to
`(m_i, S_i)` is a sum of `log(2 cosh(sqrt(mu^2+v)/2))` terms — not quadratic,
with no closed-form maximiser. The closed form exists *only* on the augmented
objective. That is the honest statement of what the augmentation buys.

---

## 4. Cost

Per unit `i` per sweep, with `T >= q` guaranteed by validation
(`q > T` is rejected at line 152-153):

| step | flops |
|---|---|
| `mu_i = a_i + Lambda m_i` | `2 T q` |
| `v_it = lambda_t' S_i lambda_t`, all `t` | `~T q(q+1)` |
| `xi_i`, `w_i` | `O(T)` (one `tanh` + one `sqrt` per cell) |
| `A_i = Lambda' W_i Lambda + I` (symmetric) | `~T q(q+1)` |
| `chol(A_i)` | `q^3/3` |
| `S_i = A_i^{-1}` (`chol2inv`) | `~q^3` |
| `Lambda'(c_i - W_i a_i)`, then `S_i * (.)` | `2 T q + 2 q^2` |
| `chol(S_i)` to repack `log_L_diag`, `L_off` | `q^3/3` |

Per unit: **`~2 T q^2 + (5/3) q^3`**, dominated by `2 T q^2` since `T >= q`.

Over all units: **`~2 N T q^2 = 2 * n_obs * q^2` flops per sweep** — genuinely
`O(N)`, and linear in the data size `n_obs = N T`. All the `q x q` work is on
matrices of size at most `6 x 6` (`q <= 6`, validated at line 160-163), so it is
BLAS-1/2 territory with no memory pressure: peak extra storage is one `q x q`
work matrix, or `O(N q^2)` if `S` is cached.

**Why this attacks the measured problem.** The observation that "cost tracks
parameter count, not `n`" is exactly what the closed form removes. The
variational block is `N * q(q+3)/2` parameters — 27,040 of the 27,044 at
`n = 5397, q = 2`. Under the closed form it leaves the optimiser entirely:

- variational block only in closed form -> optimiser sees `p + Tq - q(q-1)/2`
  parameters (single digits to low tens), with each objective evaluation
  requiring an inner MM loop;
- full sweep (§2.3) -> the optimiser sees **zero** parameters.

Both replace a quasi-Newton search in `O(N q^2)` dimensions with a fixed number
of `O(N T q^2)` sweeps. **AGENT-INFERRED:** the resulting wall-clock improvement
is not measured here and must not be claimed until it is.

---

## 5. Numerical verification

### 5A. Variational block, `beta` and `Lambda` held fixed at deliberately non-optimal values

`N = 60, T = 5, q = 2`, `p = 3` (intercept + a covariate varying over unit *and*
trait + a trait dummy), `n_it` drawn from `1:6`, `beta` and `Lambda` perturbed
off the truth. Started from `m = 0.3`, `S = 0.7 I` (engine `max|grad| = 6.86`).

```
negative ELBO by sweep : 570.151  413.005  412.315  412.277  412.274  412.2738 ...
worst per-sweep increase        :  7.96e-13
max |obj$gr| at the fixed point :  1.5543e-15
   m           1.5543e-15
   log_L_diag  6.1422e-16
   L_off       2.7756e-16
nlminb from the same start      : 412.273807187765
CAVI                            : 412.273807184783   (CAVI is 3.0e-09 LOWER)
max |CAVI par - nlminb par|     : 1.67e-05
```

### 5A'. The conjectured update without `- W_i a_i` — the negative control

```
objective at its fixed point : 424.191952   (11.918 nats WORSE)
max |obj$gr| there           : 2.1615        (not a stationary point)
```

### 5B. Full sweep — variational block + `beta` + `Lambda`, nothing optimised numerically

`N = 80, T = 5, q = 2`, started from `beta = 0`, `Lambda = I + 0.1` (lower),
`m = 0`, `S = I`.

```
full-sweep negative ELBO : 535.383707901     worst per-sweep increase 2.16e-12
   max |grad beta      |  1.3205e-13
   max |grad theta_rr  |  1.9056e-14
   max |grad m         |  1.5543e-15
   max |grad log_L_diag| 5.4612e-16
   max |grad L_off     | 2.7756e-16
nlminb, full parameter vector, same start : 535.383707910  (convergence 0)
full-sweep - nlminb : -8.89e-09             (the sweep is LOWER)
```

### 5C. Stress and degeneracy

All run to 200 sweeps from `m = 0.4`, `S = 0.6 I`; `max eig(S_i)` reported to
check the `S_i <= I` bound of §6.2.

| case | negative ELBO | `max|obj$gr|` | worst step-up | `max eig(S)` |
|---|---|---|---|---|
| `q=1, T=4, n=1` (Bernoulli) | 210.388164 | 4.44e-16 | 1.71e-13 | 0.6796 |
| `q=4, T=6, n in 2:4` | 377.128822 | 1.33e-15 | 5.12e-13 | 0.9415 |
| complete separation (`y == n`) | 399.740241 | 1.33e-15 | 1.59e-12 | 0.6304 |
| near-zero `xi` (`mu ~ 0, v ~ 0`) | 138.629436 | 2.37e-16 | 0.00e+00 | 1.0000 |
| large `n` (`n in 2:200`) | 864.055809 | 3.60e-14 | 2.96e-12 | 0.0607 |

The near-zero-`xi` cell is an exact analytic check: `200 * log 2 = 138.629436`,
`S_i = I` to machine precision, converged in one sweep. Both the template's
Taylor branch and the `w` series were exercised there and agree.

---

## 6. Where it fails or degenerates

**6.1 It is the wrong update for `eval_method = 0` (Gauss-Hermite).** The whole
derivation is the JJ surrogate. Under GH the expected log-likelihood is not
quadratic in `z_i` and no closed form of this kind exists. Any wiring must be
fenced on `family == 1 && eval_method == 1` and fail closed otherwise.

**6.2 It cannot degenerate in `S_i`.** `w_it >= 0` gives `A_i >= I_q`, hence
`0 < S_i <= I_q` unconditionally, with `cond(A_i) <= 1 + lmax(Lambda'W_i Lambda)`
and `w_it <= n_it/4`. No `Lambda` rank deficiency, no collinearity, and no
separation can make the solve fail — the standard-normal prior regularises it.
Verified: `max eig(S_i) <= 1` in every cell of §5C, and exactly 1 when
`Lambda -> 0`. This is a genuinely stronger guarantee than the regression case,
where `Sigma_0^{-1}` may be small.

**6.3 `xi -> 0` is a removable singularity that must be handled.**
`w(xi) = tanh(xi/2)/(2 xi)` is `0/0` at `xi = 0`. Use
`w = 1/4 - xi^2/48 + xi^4/480` below the template's own `xi^2 <= 1e-6`
threshold. `xi = 0` occurs whenever `mu_it = 0` and `v_it = 0` — reachable at
`beta = 0` with `Lambda -> 0`, i.e. exactly the null start. Not exotic.

**6.4 Separation is a hazard for the `beta` / `Lambda` blocks, not for
`(m_i, S_i)`.** With `y_it == n_it` the variational block is fine (§5C), but
the unpenalised weighted-least-squares `beta` step of §2.3 has the usual
divergence behaviour of a logistic MLE under separation. If the full sweep is
adopted, `beta` needs the same safeguard any logistic fit needs.

**6.5 Stationary, not global.** The step is a *global* max of the surrogate in
`(m_i, S_i)` at fixed `(beta, Lambda, xi)`, but the joint problem in `Lambda` is
non-convex, and the rotational non-identifiability `Lambda -> Lambda Q`,
`z -> Q'z` is unchanged (pinned only by the lower-triangular packing). Multi-start
remains necessary; the closed form removes the optimiser, not the multimodality.

**6.6 The fixed point optimises the JJ ELBO, not the true ELBO.** This is a
pre-existing property of `eval_method = "jj"`, not something the closed form
introduces — but it means the closed form cannot be used to accelerate a fit
whose *reported* objective is `ELBO_GH`. `.va_r3_objective_type()` already
distinguishes `ELBO_JJ` from `ELBO_GH`; that fence must be respected.

**6.7 Assumptions inherited from R3's validation.** The derivation uses the
complete `N*T` cell grid, `n_it >= 1`, prior `N(0, I_q)`, and no `Psi`,
structured/provider, `lv`, or missing-data term — all of which
`.va_r3_validate_data()` already enforces. Two are relaxable rather than
fundamental: missing cells simply drop from the `sum_t`, and a general prior
`N(0, Sigma_0)` replaces `+ I_q` with `+ Sigma_0^{-1}` in `A_i` and adds
`Sigma_0^{-1} mu_0` to the `m_i` right-hand side. A diagonal `Psi` on the
*trait* side is a different matter and is **not** covered by this derivation.

**6.8 Repacking cost is real but small.** The engine stores `L_i`, not `S_i`.
`A_i = C_i C_i'` does not give the lower Cholesky of `A_i^{-1}` by transposition
(`C_i^{-T}` is upper). The practical route is
`chol(chol2inv(chol(A_i)))` — two extra `q^3/3` factorisations per unit, already
counted in §4 and negligible at `q <= 6`.

---

## 7. Reproduce

```r
Rscript dev/polya-cavi-verify.R    # 5A, 5A'
Rscript dev/polya-cavi-stress.R    # 5B, 5C
```
