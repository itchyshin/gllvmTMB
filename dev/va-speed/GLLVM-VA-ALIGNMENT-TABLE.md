# Alignment table — the probit VA expectation, symbolic ↔ our C++ ↔ gllvm's C++

> **Landed 2026-08-05 from the arc's derivation slice. Read this header first: the
> body's own verdict was superseded later the same day by measurement.**
>
> **The body concludes `MECHANISM: PARTIALLY SUPPORTED (sign only)`** — the over-charge
> direction is rigorously derived, but the body could not derive the ~2x magnitude, and a
> toy ridge calibration it tried over-predicted GH's bias (0.57 vs an actual 0.922). That
> caution was correct *as far as algebra goes* and is preserved verbatim below.
>
> **What measurement later established** (`dev/va-usability/190-shared-grid-bias-vs-rmse.R`,
> probit n=150 p=20 q=2, **10 paired seeds**), in the controlled within-engine comparison
> where `ac` and `ac2` share parameterisation, optimiser, starts, KL, data and seed and
> differ ONLY in the curvature:
>
> | tier | curvature | trace | eta_var |
> |---|---|---|---|
> | `ac` | pinned to −1 | 0.528 | **0.441** |
> | `ac2` | exact `(log Φ)''` | 1.197 | **0.968** |
>
> Paired difference in `eta_var` **+0.527 [+0.438, +0.616]**, separating from zero. The
> harness reproduces BOTH published control figures exactly (`ac` 0.441, `gh` 0.922), which
> is what makes the `ac2` number trustworthy. **So the curvature constant IS a cause of the
> attenuation in our tiers** — the algebra simply could not predict the size in advance.
>
> **Three standing cautions, none of which the measurement removes:**
> 1. **gllvm uses the exact curvature and attenuates anyway** (trace ~0.53). Why, is OPEN.
>    It differs from us in ≥5 ways at once, so it cannot be compared one-variable.
> 2. **`ac2` is not worth shipping.** At 10 seeds it is statistically indistinguishable
>    from `gh` on both `eta_var` and `relfrob` while costing the same. `gh` already exists.
> 3. **`−v/2` IS a valid global lower bound** (proved in §1 below). The existing `ac` is
>    conservative-but-loose, **not wrong**. `ac2` is NOT a bound — hence `APPROX_AC2`.
>
> Convention note for anything below that scores gllvm: `Λ = theta %*% diag(sigma.lv)`,
> settled against gllvm's own linear predictor. See `dev/va-usability/CONVENTION-SETTLED.md`.

---

# S2 — Mathematical-consistency review: does AC's hard-coded curvature explain the ~2x loading attenuation?

**Reviewer:** Noether (mathematical-consistency lane) · **Repo (read-only):** `/private/tmp/gllvmtmb-va-lane2`
**Source file under review:** `inst/tmb/gllvmTMB_va_r3.cpp` (1071 lines)
**Tags:** QUOTED = copied from source · DERIVED = my own math, shown step by step ·
COMPUTED = printed by an R script I ran in this session (scripts: `noether_check.R`,
`noether_check2.R`, both in this scratchpad; full output re-read below) · INFERRED = a
reasoned conclusion that is *not* itself a proof.

Numbers describing the observed attenuation (`0.441`, `0.528`, `0.922`, `1.157`, `0.892`,
`1.071`, `0.535`) are QUOTED from `dev/va-usability/130-crux.log` and
`dev/va-usability/80-nladder-summary.csv`/`.log` in the repo, re-read directly for this
report (not taken on faith from the task prompt). Context: this repeats a hypothesis-test
against a **live handover**, `docs/dev-log/handover/2026-08-05-claude-handover-va-loading-bias.md`,
which records that **two prior mechanisms for this same bias were proposed and refuted**
("do not propose a third without a grep first"). This is the third. It is graded on
whether the grep-and-derive discipline was actually followed, not on getting a clean yes.

---

## 1. Does `−v/2` valid-lower-bound the exact `E_q[log Φ(η)]`?

### 1.1 The general expansion (DERIVED, then cross-checked against the codebase's own use of it)

For `η = μ + √v·Z`, `Z ~ N(0,1)`, and `g` smooth enough for term-by-term integration, Hermite
expansion gives the exact series

```
E[g(μ+√v·Z)] = Σ_{k=0}^∞  g^{(2k)}(μ) · v^k / (2^k k!)
             = g(μ) + (v/2) g''(μ) + (v²/8) g''''(μ) + (v³/48) g^(6)(μ) + O(v⁴)
```

(`2^k k!` = 2, 8, 48 for k=1,2,3.) This is not a private derivation — it is **QUOTED**
verbatim as the structure the codebase already documents and implements for the softplus
case:

```
// At small v, the heat-kernel expansion
//   f + v f''/2 + v^2 f''''/8 + v^3 f^(6)/48 + O(v^4)
```
(`inst/tmb/gllvmTMB_va_r3.cpp:39-40`)

and, for `log Φ` specifically, the GH tier's own small-`v` branch documents and implements
exactly the second-order term I need:

```
//     E[g(mu + sqrt(v) Z)] = g(mu) + v g''(mu)/2 + O(v^2),
// with g''(x) obtained from the standard identity
//     d^2/dx^2 log Phi(x) = -lambda(x) (x + lambda(x)).
```
(`inst/tmb/gllvmTMB_va_r3.cpp:292-295`), implemented at

```cpp
Type lam_p = va_r3_inv_mills(mu);
Type lam_q = va_r3_inv_mills(-mu);
Type d2_p = -lam_p * (mu + lam_p);
Type d2_q = -lam_q * (-mu + lam_q);
Type expansion = y * va_r3_log_pnorm(mu) + (n - y) * va_r3_log_pnorm(-mu)
  + v * (y * d2_p + (n - y) * d2_q) / Type(2.0);
```
(`inst/tmb/gllvmTMB_va_r3.cpp:309-316`, function `va_r3_probit_expectation`, the GH tier).

So the "TRUE curvature" claim in the task brief is not a new proposal — **the codebase's
own GH evaluator already computes it**, for `v` below a `1e-6` threshold. What follows
derives it independently and checks it is right.

### 1.2 Deriving `(log Φ)''(μ) = −h(μ)(μ+h(μ))` (DERIVED)

Let `g(x) = log Φ(x)`, `φ` the standard normal density, `h(x) = φ(x)/Φ(x)` (inverse Mills
ratio). `g'(x) = φ(x)/Φ(x) = h(x)`.

```
g''(x) = d/dx [φ(x)/Φ(x)]
       = [φ'(x)Φ(x) − φ(x)²] / Φ(x)²          (φ'(x) = −x φ(x))
       = −x·φ(x)/Φ(x) − [φ(x)/Φ(x)]²
       = −x h(x) − h(x)²
       = −h(x)(x + h(x))
```

matching the task's claim and the code's own comment exactly.

**COMPUTED** (`noether_check.R` Block 1, using the log-space-stable
`h <- function(m) exp(dnorm(m,log=TRUE) - pnorm(m,log.p=TRUE))` specified in the brief):

```
gpp(0)      = -0.636619772367581
-2/pi       = -0.636619772367581
abs diff    = 1.110e-16
```

`g''(0) = −2/π` exactly, to machine precision. **COMPUTED** cross-check against a
central finite-difference of `pnorm(x, log.p=TRUE)` over `μ ∈ [−40,40]` (Block 2): max
absolute deviation `1.315e-07`, consistent with `O(eps²)` truncation error at
`eps=1e-3` — the closed form and an independent numerical derivative agree.

### 1.3 Is `g''(μ) ∈ (−1, 0)` for *every* real `μ`? (DERIVED + COMPUTED, with a diagnosed numerical pitfall)

`g'' < 0` everywhere is the classical **log-concavity of the Gaussian CDF** (standard;
e.g. surveyed in Bagnoli & Bergstrom 2005, "Log-concave probability and its
applications"). The task's harder question is the **lower** bound `g'' > −1`, i.e. that
`h(x)` decreases with slope bounded above by 1 in magnitude — equivalently that
`−log Φ(x)` is convex with a **1-Lipschitz gradient** (the standard curvature bound
behind quadratic-majorization/MM algorithms for probit regression).

DERIVED via the classical Mills-ratio bound (Gordon 1941 / Sampford 1953, Ann. Math.
Statist.): for `z > 0`, `z/(1+z²) < Φ(−z)/φ(z) < 1/z`, hence `h(−z) ∈ (z, z+1/z)`. Writing
`k(x) = h(x)+x`, this gives `k(x) ∈ (0, 1/(-x))` for `x<0`, so `k(x) → 0⁺` as `x → −∞`, and
`g''(x) = −h(x)·k(x) → −1` **from above**. So `g''(x) > −1` in the asymptotic regime, never
reaching or crossing it.

**A numerical pitfall was caught and fixed, per the task's warning.** The naive
`−h(μ)(μ+h(μ))` computed from the log-space-stable `h()` **breaks down** for very negative
μ — not from underflow (the brief's warning), but from **catastrophic cancellation** in
`μ+h(μ)`, since `h(μ) ≈ −μ` there and the sum of two large near-equal-magnitude numbers of
opposite sign amplifies any relative floating error in `h(μ)` into a large absolute error
in the (small) sum:

```
mu=-1e4         gpp_naive = -0.869246      (garbage; should be ≈ -0.9999999...)
mu=-3e4         gpp_naive = -25.67         (garbage, not even in (-1,0))
mu=-1e5         gpp_naive = 3169.6         (garbage, positive)
```
(COMPUTED, `noether_check2.R` Block 3b)

This is exactly the shape of error the task warned against ("a previous session ...
published nine wrong numbers by skipping this discipline"). The fix mirrors what the
**actual C++ source already does**: `va_r3_mills_cf` (`inst/tmb/gllvmTMB_va_r3.cpp:140-147`)
returns the continued-fraction tail `c(z)` such that `h(μ) = z + c(z)` for `z=−μ`, so
`μ + h(μ) = c(z)` **directly, with no subtraction of large numbers at all**. Re-deriving
`g''` that way (COMPUTED, Block 3c/3b-residual):

```
mu       one_plus_gpp   positive   asympt_1/mu^2
-1e+02   9.994e-05      TRUE       1e-04
-1e+03   9.9999e-07     TRUE       1e-06
-1e+04   9.99999938e-09 TRUE       1e-08
-1e+05   1.0000012e-10  TRUE       1e-10
-1e+06   1.0000889e-12  TRUE       1e-12
-1e+07   9.881e-15      TRUE       1e-14
-1e+08   0.0 (underflows to the -1 boundary from above; residual < double precision)
```

`1+g''(μ)` stays **strictly positive** out to `μ=−10⁷`, tracks the `1/μ²` asymptotic rate
my hand expansion predicts to within a small constant, and never goes negative — it
underflows *to* zero, not past it. Cross-check: the continued-fraction `h()` agrees with
the naive ratio to `~1e-13` in the region `μ∈[−30,−10]` where both are still trustworthy
(Block 3c), so the two methods are validated against each other before the naive one is
retired. **Conclusion: `g''(μ) ∈ (−1,0)` for every finite μ**, `→ −2/π` at 0, `→ 0⁻` as
`μ→+∞`, `→ −1⁺` as `μ→−∞`, monotonically (consistent with the classical fact that `h` is
convex).

### 1.4 The global bound (DERIVED — Jensen, not just a local Taylor argument)

Let `ψ(x) = log Φ(x) + x²/2`. `ψ''(x) = g''(x)+1 > 0` everywhere (§1.3) ⟹ **ψ is convex**
on all of ℝ (growth is at most quadratic, so `E[ψ(η)]` is finite for Gaussian η — Jensen
applies cleanly). By Jensen's inequality for a convex function,

```
E[ψ(η)] ≥ ψ(E[η]) = ψ(μ)
E[log Φ(η)] + E[η²]/2 ≥ log Φ(μ) + μ²/2
E[log Φ(η)] ≥ log Φ(μ) + μ²/2 − (v+μ²)/2 = log Φ(μ) − v/2
```

**This holds for every `v ≥ 0`, not just small `v`** — it is not a truncated Taylor
approximation, it is an exact global inequality contingent only on `g''≥−1` everywhere
(§1.3). **COMPUTED** direct-quadrature confirmation (`integrate()` against the Gaussian
density, Block 4/4b) across `μ∈{−100,...,10}`, `v∈{0.01,...,500}`:

```
min slack over 81 (mu,v) pairs = 4.723311e-05   (>= 0 required)
Any negative slack (bound violated)?  FALSE
... extended to mu in {-100,-50,-30}, v up to 500: min slack 4.998e-05, no violations.
```

The **n-trial extension** (`−n·v/2`, not `−v/2`) is DERIVED directly from the same
argument, without needing the code's own "one latent per trial" story: apply the bound
once to `η` (`E[logΦ(η)] ≥ logΦ(μ)−v/2`) and once to `−η` (`E[logΦ(−η)] ≥ logΦ(−μ)−v/2`,
same argument by symmetry), then combine linearly with the fixed nonnegative weights `y`
and `(n−y)` (linearity of expectation needs no independence assumption between the two
terms):
```
y·E[logΦ(η)] + (n−y)·E[logΦ(−η)] ≥ y(logΦ(μ)−v/2) + (n−y)(logΦ(−μ)−v/2)
                                  = y·logΦ(μ) + (n−y)·logΦ(−μ) − n·v/2
```
— exactly the AC formula, confirming the code comment's `n·v/2` scaling
(`inst/tmb/gllvmTMB_va_r3.cpp:351-355`) is correct.

### 1.5 Verdict on Deliverable 1

**`−v/2` (hence `−n·v/2`) IS a valid GLOBAL lower bound on the exact
`E_q[y logΦ(η)+(n−y)logΦ(−η)]`, for every μ and every v ≥ 0.** This is DERIVED (Jensen,
§1.4) and COMPUTED-confirmed (§1.3–1.4). The code's own comment already asserts this
informally:

```
// THIS IS A DIFFERENT OBJECTIVE.  It is a strict LOWER BOUND on the GH value,
// not an approximation to it, ...
```
(`inst/tmb/gllvmTMB_va_r3.cpp:346-349`) — my derivation makes that claim rigorous rather
than asserted. **So the AC surrogate is CONSERVATIVE-but-LOOSE, not WRONG.** It is a
legitimate ELBO term (optimizing it still optimizes a valid variational lower bound on the
marginal likelihood). The looseness is real and quantifiable (§4), and — per the
hypothesis under test — a *loose* bound can still distort *where* the optimum over Λ sits,
even though it never invalidates the bound itself. The write-up must carry both halves:
valid bound, and (separately) a plausible source of point-estimate bias.

---

## 2. Is `v_ij` really `λ_j' S_i λ_j`? (the load-bearing structural claim)

### 2.1 Lambda reconstruction (QUOTED, `inst/tmb/gllvmTMB_va_r3.cpp:702-722`)

```cpp
std::vector<matrix<Type> > Lambda_tier(n_tiers);
for (int k = 0; k < n_tiers; ++k) {
  const int d = tier_dim(k);
  if (tier_kind(k) != 0) { Lambda_tier[k] = matrix<Type>(0, 0); continue; }
  matrix<Type> Lk(T, d);
  Lk.setZero();
  ...
  for (int j = 0; j < d; ++j) {
    for (int t = j; t < T; ++t) {
      if (t == j) { Lk(t, j) = lam_diag(j); }
      else        { ... Lk(t, j) = lam_lower(pos); }
    }
  }
  Lambda_tier[k] = Lk;
}
matrix<Type> Lambda = Lambda_tier[0];
```

`Lambda_tier[k]` is a genuine `T × d` loadings matrix (T = traits, d = latent dimension);
`Lam(t, c)` used later is row `t` (trait/species `j`, in the task's notation), column `c`
(latent axis).

### 2.2 The per-level Cholesky factor of `S_i` (QUOTED, `inst/tmb/gllvmTMB_va_r3.cpp:819-830`, `850`, `858`)

```cpp
matrix<Type> Li(d, d);
Li.setZero();
for (int c = 0; c < d; ++c)
  Li(c, c) = exp(log_L_diag(mo + c * nk + g));
int off_pos = 0;
for (int col = 0; col < d; ++col) {
  for (int row = col + 1; row < d; ++row) {
    Li(row, col) = L_off(oo + off_pos * nk + g);
    ++off_pos;
  }
}
```
— `Li` is filled diagonal + **strict lower triangle only** (row > col), i.e. a genuine
Cholesky factor. Confirmed by the KL term computed from the same `Li`,

```cpp
kl = Type(0.5) * (trace_S + mean_sq - logdet_S - Type(d));   // line 850
```
which is exactly the standard `KL[N(m,S) ‖ N(0,I_d)] = ½(tr S + m'm − log det S − d)`, and
by the explicit materialization

```cpp
matrix<Type> Si = Li * Li.transpose();     // line 858
...
S_flat(g, row * d + col) = Si(row, col);   // line 862
```

So `S_i = L_i L_i'` is the unit/level `g`'s variational posterior covariance, exactly as
claimed, not merely named that way.

### 2.3 The `v` accumulation (QUOTED, `inst/tmb/gllvmTMB_va_r3.cpp:895-932`)

```cpp
Type v = Type(0.0);
for (int k = 0; k < n_tiers; ++k) {
  ...
  if (tier_kind(k) == 1) {                       // diagonal ("indep") tier
    Type sd = sd_tier(sd_offset[k] + t);
    ...
    Type projected = sd * exp(log_L_diag(pos));
    v += projected * projected;
    continue;
  }
  const matrix<Type> &Lam = Lambda_tier[k];
  for (int c = 0; c < d; ++c)
    mu += Lam(t, c) * m(mo + c * nk + g);

  // v contribution = ||L_{k,g}' a_{k,o}||^2, without forming S.
  for (int col = 0; col < d; ++col) {
    Type projected = Type(0.0);
    projected += exp(log_L_diag(mo + col * nk + g)) * Lam(t, col);
    int off_pos = 0;
    for (int prior_col = 0; prior_col < col; ++prior_col)
      off_pos += d - prior_col - 1;
    for (int row = col + 1; row < d; ++row) {
      projected += L_off(oo + (off_pos + row - col - 1) * nk + g) * Lam(t, row);
    }
    v += projected * projected;
  }
}
```

### 2.4 DERIVED: this is exactly `λ_j' S_i λ_j`

For a fixed `col`, `projected` sums `L(col,col)·Λ(t,col)` plus `L(row,col)·Λ(t,row)` for
every `row > col` — i.e. `projected_col = Σ_row L(row,col)·Λ_t(row) = (L' Λ_t)_col`, where
`Λ_t` is the trait-`t` row of `Lambda_tier[k]` (a `d`-vector) and `L` is exactly the
Cholesky factor of §2.2 (same `log_L_diag`/`L_off` arrays, same index scheme, both tied to
the level `g = level_id(r,k)`). Then

```
v = Σ_col projected_col²  = ‖L' Λ_t‖²  =  Λ_t' L L' Λ_t  =  Λ_t' S_i Λ_t
```

using `S_i = L L'` from §2.2. This is **exactly** the quadratic form `λ_j' S_i λ_j` the
hypothesis requires (`j = t`, the trait/species index; `i = g`, the unit/level index for
that tier) — confirmed by the code's own comment at the site, `// v contribution =
||L_{k,g}' a_{k,o}||^2, without forming S` (line 919), which names the identity directly.

The diagonal (`tier_kind==1`, e.g. an `indep()` term) branch is the `d=1` special case of
the same formula: `Λ_j = sd_j·e_j`, `S = L_diag²` (scalar), and `v = sd_j²·L_diag² =
Λ_j'·S·Λ_j` reduces identically — not a different mechanism, the same one at `d=1`.

### 2.5 Verdict on Deliverable 2

**CONFIRMED, with quoted code at every step.** `v_ij` is genuinely quadratic in the
loadings row `λ_j`, mediated by the real (Cholesky-parameterized, KL-linked) posterior
covariance `S_i`. The structural premise the whole ridge-penalty mechanism depends on
holds; nothing here collapses the hypothesis.

---

## 3. The alignment table

| | Symbolic math | R/user-facing meaning | C++ implementation (file:line) | What it should be | Consequence if wrong/mismatched |
|---|---|---|---|---|---|
| **(a) Exact expectation** | `E_q[y logΦ(η)+(n−y)logΦ(−η)]`, `η~N(μ,v)` | The quantity the ELBO's binomial-probit term is supposed to approximate/bound | *(no code — the reference target)* | N/A — defines correctness | N/A |
| **(b) AC surrogate (as implemented)** | `y logΦ(μ)+(n−y)logΦ(−μ) − n·v/2` | `eval_method = 2` ("Albert-Chib closed form"), binomial-probit only | `va_r3_probit_ac_expectation`, `gllvmTMB_va_r3.cpp:361-366` | A valid global lower bound (§1) — CONFIRMED it is | Systematically **over**-charges the variance-penalty term everywhere except `μ→−∞` (§1.3, §4) → acts as an inflated, μ-blind ridge penalty on Λ via the quadratic form of §2 |
| **(c) Proposed exact-curvature variant** | `y logΦ(μ)+(n−y)logΦ(−μ) + (v/2)[y·g''(μ)+(n−y)·g''(−μ)]`, `g''(x)=−h(x)(x+h(x))` | Not currently wired to any `eval_method` for probit at general `v` | **Does not exist as a standalone path.** The identical expression is already computed inside `va_r3_probit_expectation`'s small-`v` branch, `gllvmTMB_va_r3.cpp:309-316`, but only used below the `v<1e-6` threshold before the code switches to GH quadrature (`:318-329`) | A second-order-accurate, still-`O(1)`-cost (no quadrature) closed form, correctly weighting curvature by `μ` instead of hard-coding `1` | This is the concrete, buildable falsifier — see §5 |
| **(d) GH tier** | Same exact expectation as (a), evaluated by physicists' Gauss-Hermite quadrature (`H` nodes) for `v>1e-6`, else the 1st-order-in-`v` expansion using the true `g''` | `eval_method = 0` (default) | `va_r3_probit_expectation`, `gllvmTMB_va_r3.cpp:301-330` | Numerically exact to quadrature-node accuracy | None measured for bias (QUOTED measured `eta_var=0.922`, `trace=1.157`, close to the target 1); ~33× runtime cost is the quoted price (handover, §"OPEN") |
| **(e) JJ tier** | Jaakkola–Jordan/Pólya-Gamma bound on `E[softplus(η)]`, `η~N(μ,v)`, via `ξ=√(μ²+v)`: `log(2cosh(ξ/2))+μ/2` | `eval_method = 1`, **binomial-logit only** (family 1, not the probit family this hypothesis targets) | `va_r3_jj_softplus_expectation`, `gllvmTMB_va_r3.cpp:97-113` | A tangent quadratic-in-`ξ²` bound, tight only at the point `ξ` was fit at | See §3.1 below — a *related but distinct* over-charge, quantitatively worse in the tails |

### 3.1 Does JJ show the same over-charge logic? (DERIVED + COMPUTED)

JJ bounds a different quantity for a different family (softplus/logit, not logΦ/probit),
so this is a secondary, exploratory check, not the primary target. The "curvature of `v`"
comparison is: true `E[softplus(μ+√v Z)] = softplus(μ) + v·c_true(μ) + O(v²)` with
`c_true(μ) = p(1−p)/2`, `p=σ(μ)` (this coefficient, `pq`, is QUOTED verbatim as `f2` in
the codebase's own softplus GH branch, `gllvmTMB_va_r3.cpp:59`). DERIVED: differentiating
JJ's closed form `h(v)=log(2cosh(√(μ²+v)/2))+μ/2` at `v=0` gives
`c_JJ(μ) = tanh(μ/2)/(4μ)` (limit `1/8` at `μ=0`).

**COMPUTED** (`noether_check.R` Block 6, closed form cross-checked against a numerical
derivative of the exact JJ formula, max abs diff `5.2e-9`):

```
mu     jj_coef    true_coef    ratio(jj/true)
0.0    0.1250     0.1250       1.000   (exact match — JJ is tangent at mu=0)
1.0    0.1155     0.0983       1.175
2.0    0.0952     0.0525       1.813
5.0    0.0493     0.00332      14.84
8.0    0.0312     0.000168     186.3
```

and the tail rates diverge in *kind*, not just degree: `true_coef` decays **exponentially**
in `|μ|` (`~e^{-|μ|}/2`), while `c_JJ` decays only **polynomially** (`~1/(4|μ|)`). So the
ratio `c_JJ/c_true → ∞` as `|μ|` grows, at a much faster rate than AC's own over-charge
ratio (§4) diverges. **This is consistent with (not proof of) the same general mechanism —
a `v`-charge that is tangent/exact at one reference point and increasingly wrong away from
it — but it is a structurally different bound (tangent-in-`ξ²`, not flat-additive), so
this is offered as a plausibility note for JJ's own measured plateau (trace ≈0.535,
QUOTED from `dev/va-usability/80-nladder-summary.csv`), not a claim that AC's mechanism
and JJ's mechanism are the same mechanism.** Confirming it for JJ specifically would need
the same stationarity-equation treatment done for AC in §4, which was not undertaken here
(out of scope — the task's primary target is AC).

---

## 4. Predicted attenuation factor

### 4.1 The over-charge ratio (DERIVED formula, COMPUTED values)

`1/|g''(μ)|` — how many times larger AC's flat charge is than the true local curvature:

```
mu      g''(mu)         overcharge = 1/|g''|
-1000   -0.9999990       1.0000010
-100    -0.9999001       1.0000999
-20     -0.9975367       1.0024693
-10     -0.9905546       1.0095354
-5      -0.9673036       1.0338016
-2      -0.8857209       1.1290238
-1      -0.8009023       1.2485917
0       -0.6366198       1.5707963   ( = pi/2, exact )
1       -0.3703137       2.7004131
2       -0.1135481       8.8068442
5       -7.43e-06        1.35e+05
```
(COMPUTED, `noether_check2.R` Block 7b, using the cancellation-free tail formula for
`μ ≤ −10`.)

### 4.2 A general-`d`, DERIVED (no assumptions beyond §1–§2) structural consequence: AC's `S_i` is uniformly smaller

Holding `Λ` fixed, differentiating the AC objective w.r.t. `S_i` (data term `−½ tr(S_i M_i)`
with `M_i = Σ_j n_ij λ_j λ_j'`, from §2; KL term `½(tr S_i − log det S_i − d)`, §2.2) and
setting the gradient to zero reproduces the standard variational-Gaussian stationary point

```
S_i,AC = (I_d + M_i)^{-1},         M_i = Σ_j n_ij λ_j λ_j'
```

— **exactly gllvm's own update** `A_i = (I_d + Σ_j θ_j θ_j')^{-1}`, independently re-derived
here from AC's own stationarity condition (cf. `GLLVM-REFERENCE-READ.md:403-420`, cited in
the handover). Repeating the same derivation with the curvature-correct data term (`−½
Σ_j c_ij n_ij λ_j'S_iλ_j`, `c_ij=|g''(μ_ij)|<1`) gives

```
S_i,true = (I_d + M_i,true)^{-1},   M_i,true = Σ_j c_ij n_ij λ_j λ_j'   ⪯   M_i   (Loewner order, since c_ij<1)
```

so `S_i,true ⪰ S_i,AC` (PSD/Loewner order) for **every** unit `i` — AC's posterior
covariance is never larger than a curvature-correct evaluator's. A free, unplanned
cross-check falls out of this: under the fully-observed balanced design the crux script
actually uses (`n_trials = rep(1L, ...)`, so `n_ij ≡ 1` for all `i,j`), `M_i` in the AC
formula **does not depend on `i` at all** (no `c_ij(μ_ij)` term to carry `i`-dependence),
so `S_i,AC` is the same matrix for every unit **by construction** — which is exactly what
the handover independently measured empirically ("the per-unit SD... constant to machine
zero (8.36e-17)... structural to Albert–Chib, not a configuration", handover §"THE
COLLAPSE SUSPECT IS DEAD", lines 57-61) and explains why GH does *not* show this
(`c_ij(μ_ij)` genuinely varies with `i` through `μ_ij`). This is a correct, independently-derived
reproduction of a previously-measured fact — a real point of support for treating `v`'s
curvature handling as the operative difference between AC and GH.

### 4.3 Toy quantitative calibration — EXPLICITLY LABELLED HAND-WAVING

Turning §4.1–4.2 into the observed *point-estimate* numbers requires solving the joint
`(Λ, m, S)` fixed point, which was **not** attempted (excluded by scope: no fits). One toy,
clearly flagged as illustrative only: model the linear-scale shrinkage of a single loading
as `ρ = I/(I+c)` (I = a frozen "data-signal" curvature, `c` = the `v`-penalty curvature
competing against it — the standard ridge-shrinkage identity for a quadratically penalized
optimum).

**COMPUTED** (`noether_check.R` Block 8), using the measured `eta_var` (QUOTED,
`dev/va-usability/130-crux.log`) and `ρ = √eta_var` (justified because `sd(ẑ)` is
measured close to 1 and comparable across arms — 0.895 AC / 0.883 GH / 0.895 gllvm — so the
attenuation lives almost entirely in `Λ`, not in `z`):

```
rho_AC = sqrt(0.441) = 0.664078
rho_GH = sqrt(0.922) = 0.960208

Calibrate I from AC (c_AC = 1):           I = rho_AC/(1-rho_AC) = 1.976884
Predict rho_true using c_true(mu=0)=2/pi: rho_true_predicted = I/(I+2/pi) = 0.756411
                                            -> predicted eta_var = 0.572158

OBSERVED  eta_var_GH = 0.922    <-- predicted 0.572 is far below this
```

**This toy, calibrated to reproduce AC's own bias, over-predicts GH's bias by a wide
margin** (predicts eta_var≈0.57 for GH; GH is actually measured at 0.922). So a single
scalar "data signal vs. penalty curvature" toy, using the `μ=0` reference curvature, does
**not** cleanly reproduce the magnitude. Plausible reasons, none checked here: the
realized `μ` distribution in the fitted data may sit well away from `0` (curvature ratio
falls fast with `|μ|` per §4.1, so a `μ`-averaged effective ratio could differ a lot from
the `μ=0` value); the "frozen `I`" assumption ignores that `S_i` itself changes between AC
and true (§4.2), which the score equation for `Λ` (not derived in closed form here) would
also need to absorb; and higher-dimensional (`d=2`) rotation/identifiability effects in the
KL term are not captured by a 1-D toy.

### 4.4 Verdict on Deliverable 4

**No clean predicted number.** What is DERIVED and solid: (i) AC's charge is provably `≥`
the true charge in magnitude everywhere except the deep left tail (§4.1), so AC is
predicted to shrink `Λ` **at least as much as**, and generically **more than**, a
curvature-correct evaluator — the **sign** of the effect is unconditionally right; (ii)
this independently reproduces the previously-measured "AC's posterior SD is unit-invariant"
fact for free (§4.2), a genuine, non-trivial corroboration. What is **not** established:
a derivation that lands on `0.528`/`0.441` specifically. The one numeric attempt (§4.3),
honestly reported, misses by a wide margin when calibrated the other direction. **A
mechanism that explains the sign but not the magnitude — reported as exactly that, per the
task's own framing of what overclaiming would look like here.**

---

## 5. The falsifier (stated in advance)

**Falsifier A (primary, requires one new `eval_method` — NOT implemented or run in this
review):** wire up alignment-table row (c) — literally lift the already-existing
expression at `gllvmTMB_va_r3.cpp:313-316` out from behind its `v<1e-6` gate and use it for
all `v`, as a new `O(1)`-cost `eval_method` for family 4. Refit the **identical** DGP/seeds
as `dev/va-usability/130-scale-convention-crux.R` (probit, n=150, T=20, q=2, 10 seeds) and
recompute `eta_var`/`trace_ratio`.

- **Mechanism predicts:** `eta_var` moves *materially* toward GH's 0.922 — a reasonable
  pre-registered bar is "closes more than half the gap", i.e. `eta_var > ~0.68`, while
  remaining `O(1)` cost (no quadrature, so this is not just "becomes GH").
- **REFUTED if:** `eta_var` stays statistically indistinguishable from plain AC's 0.441
  under a **paired**, same-seed comparison (the lane's own stated methodology — see the
  handover's "An internal control is not a comparator" lesson) — that would show the
  hard-coded curvature is not a material driver, and the true cause lies elsewhere (e.g.
  in the AC closed form's treatment of the auxiliary latent itself, or an interaction with
  `S_i`'s already-established unit-invariance under AC that survives even after the
  curvature is fixed).
- **Ambiguous / needs a third mechanism:** `eta_var` moves partway but stalls well short of
  GH — consistent with curvature being *a* contributor but not the whole story (matches
  §4.3's honest miss), which would sharpen rather than settle the question.

**Falsifier B (fast, diagnostic, not run here — needs one cheap single-seed fit-and-report,
which this review's "no model fits" constraint excludes):** the TMB template already
`REPORT()`s `mu_by_obs` (`gllvmTMB_va_r3.cpp:1050`). Pull it from one AC fit and look at
where the realized `μ` values actually sit. If they cluster deep in the left tail
(`μ ≪ −5`, overcharge ratio `≈1`, §4.1), the mechanism is **refuted** — the over-charge
barely engages in the regime the data actually occupies, so it cannot be responsible for a
~2× effect. If they cluster near `0` or into the right tail (overcharge ratio `≥1.5`–large),
that is **consistent with** (not proof of) the mechanism being live.

---

## Summary of tags used, for audit

Every non-trivial numeric or structural claim above is tagged QUOTED / DERIVED / COMPUTED
/ INFERRED at first use. The two R scripts that produced every COMPUTED number are at
`noether_check.R` and `noether_check2.R` in this scratchpad; both were executed with
`Rscript` and their console output is reproduced verbatim in the relevant sections above —
no number in this file was asserted without having been printed first.
