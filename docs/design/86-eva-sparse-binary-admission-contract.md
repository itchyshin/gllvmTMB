# Design 86 — EVA sparse-binary scientific-admission contract

**Status:** **DRAFT — NOT APPROVED.** `LOOP/decision-queue.md` records Design 86 as `NOT YET OPEN`.
This document is a proposal; it becomes a contract only when the maintainer approves it in writing.
This lane may not treat its own brief, `LOOP/GOAL.md`, or its ultra-plan as that approval.

**Authority to write it:** `LOOP/GOAL.md` Maintainer Amendment 3 (2026-07-22), which authorised a
second, design-only lane on a disjoint write scope. **0.6 ships Laplace-only and is unaffected**
(Amendment 1). Nothing in this document may block, delay, or be cited as evidence by M1, M3, M4 or
M5. If this lane is unfinished when M3's freeze window arrives, 0.6 freezes without it — the
expected case, not a failure.

**Numbering note:** Designs 83–84 are allocated to multinomial work and 85 to the high-dimensional
Gaussian-VA contract. This is Design 86; no prior design is superseded or amended. **Design 85
remains a closed NO-GO and is READ-ONLY** — this document supersedes nothing in it and copies no
evidence from it.

---

## 1. What this is, and which estimator it specifies

### 1.1 The estimator, named

This contract specifies **EVA — the extended variational approximation** of Korhonen, Hui, Niku &
Taskinen (2023), *Statistics and Computing* **33**:26, `10.1007/s11222-022-10189-w`.

EVA replaces the complete-data log-likelihood with its **second-order Taylor expansion in the
latent variables `u`, expanded about `a_i`, the mean of the variational distribution**
(Korhonen §3, eq. 5). Because the expansion is quadratic and the variational family is Gaussian,
the expectation reduces to a trace and the objective is closed form for **any exponential-family
response with a twice-differentiable link** (their Theorem 1).

### 1.2 What it is NOT, and why that must be said

**EVA is not the estimator of Design 85.** Design 85 §5 specifies a full-covariance Gaussian
variational factor with the binomial-logit expectation evaluated by deterministic one-dimensional
**Gauss–Hermite quadrature**, and its own text is explicit that this "is a bounded alternative to
(not a silent rewrite of) the second-order EVA route recorded in Design 72"
[85 §5](85-highdim-nongaussian-va-formal-contract.md).

Planning across three documents has slid between these two estimators. They are different. This
contract fixes the ambiguity by naming EVA as the **candidate** and retaining the Gauss–Hermite VA
of Design 85 in a strictly different role — as a **fixed-coordinate accuracy reference**, the
yardstick against which EVA's Taylor error is *measured* rather than assumed (§9.2).

### 1.3 Why the target is sparse binary

Two facts, both read from primary sources, define the opportunity and the risk.

- **Laplace is badly behaved for binary-logit GLLVMs.** Korhonen Fig. 3 (m = 48, p = 2, R = 1000
  replicates): the Laplace 95 % Wald interval for the primary fixed effect attains **0.81**
  coverage at n = 50, with bias up to +4.7 and RMSE ≈ 31. EVA is near-unbiased across the same
  range. Joe (2008), *CSDA* **52**:5066–5074, explains why: Laplace bias is governed by **response
  discreteness**, **information per cluster**, and **random-effect variance magnitude** — and
  binary responses are the maximally discrete case.
- **EVA's own error is worst where the value is.** A fixed-order Taylor expansion has a bias that
  does **not** shrink with sample size. In the same figure EVA's coverage **decays** 0.968 → 0.940
  → 0.925 → **0.910** as n grows from 50 to 260, while standard errors shrink.

**The cell most worth shipping is the cell where this estimator is theoretically weakest.** This
document states that plainly and predeclares, in §11, the result that would CUT it.

### 1.4 The dimension argument, stated correctly

An internal claim that "Laplace degrades and VA wins at `q >= 4`" has been recorded as UNVERIFIED
with no source supplied. **It is now traced, and it is retired.**

A provenance audit (2026-07-22) enumerated the 66 sources of the notebook the claim came from and
put the question to that corpus directly with citations required. The result: the `q >= 4` boundary
appears in **exactly one** source — an entry of type `markdown` with **`url: null`**, titled
*"Computational Approaches for Frequentist Generalized Linear Latent Variable Models in
High-Dimensional Latent Spaces"*, carrying no bibliographic identity. It is a self-authored or
machine-generated synthesis that was added to the corpus as though it were a primary source. **No
peer-reviewed source in that corpus states a Laplace-versus-VA crossover at `q >= 4`.** This is
consistent with Korhonen et al. (2023), every one of whose simulations runs at `p = 2`, and with
Joe (2008), who attributes Laplace bias to discreteness, information per cluster, and random-effect
variance — **not** to latent dimension.

**The `q >= 4` claim is retired by this contract and may not be cited by any gate, article,
register row, or public surface.** A claim whose only support is an uncited synthesis is not weak
evidence; it is no evidence.

What the literature *does* support is a statement about **quadrature**, not about Laplace, and it
is the correct framing to keep. Joe (2008) identifies the Laplace approximation **as** adaptive
Gauss–Hermite quadrature with one node per dimension, and notes that AGHQ with ~5 nodes is
essentially asymptotically unbiased but that its cost is **exponential in the random-effect
dimension**. Two further sources in the audited corpus state the practical consequence directly:
Gauss–Hermite quadrature becomes *"unfeasible with more than three"* latent variables, and
*"computationally impractical if the number of latent variables is moderate, e.g. 8"*
(Niku et al. 2017). EVA's cost is `O(n q³ + n T q²)` — polynomial.

So the defensible dimension argument is: **at higher latent dimension the case for EVA is not that
Laplace gets worse, but that the standard remedy for Laplace — adding quadrature nodes — becomes
unaffordable while EVA does not.** This contract does not test that claim (§13.8); it records the
framing so the retired claim cannot reappear wearing a citation it never had.

> **Cross-repo note, outside this lane's write fence:** `memory/PROJECT-NOTEBOOKS.md` row 29
> describes that notebook as holding an unknown number of sources under the title "GLLVM
> approximations — LA vs VA/EVA". Both are stale: it holds **66** sources and is titled
> *"gllvmTMB 1.0 high-dimensional non-Gaussian inference decision — 2026-07-19"*. Correcting the
> registry, and quarantining source `a84780d8`, are follow-ups for the brain, not for this lane.

### 1.5 Package-boundary position

`docs/design/04-sister-package-scope.md` places **variational approximation as the primary
inference engine** out of scope and names `gllvm` as the VA alternative. **This contract does not
approach that boundary.** It admits a research prototype only: no `method=` argument, no exported
surface, no default change. Whether an optional non-default estimator argument is consistent with
Design 04 is a separate question that this document deliberately does not decide (§13.10).

---

## 2. Symbols, and the Gate-0 data contract

### 2.1 Symbols

- `i = 1, …, N` indexes units; `t = 1, …, T` indexes traits.
- `q` is the fitted latent rank, `1 <= q <= T`. (Korhonen writes `p`; we retain the package's `q`.)
- `y_it ∈ {0, 1}` is the observed binary response; **`n_it = 1` identically**.
- `x_it ∈ R^d` is a fixed, finite design row; `beta ∈ R^d` its coefficient vector.
- `lambda_t ∈ R^q` is row `t` of the loading matrix `Lambda`; `u_i ∈ R^q` the unit latent score.
- `eta_it = x_it' beta + lambda_t' u_i`; `p_it = logit^{-1}(eta_it)`.
- `z` is the realised zero fraction, `z = #{y_it = 0} / (N T)`.

The model is

```
u_i  ~iid  N_q(0, I_q)
y_it | u_i  ~  Bernoulli(p_it),      logit(p_it) = x_it' beta + lambda_t' u_i
```

so the fitted ordinary latent covariance is exactly `Sigma_B = Lambda Lambda'`. There is no fitted
diagonal `Psi`. The logistic link residual convention `pi²/3` is not a free parameter and must not
be inserted into the objective.

### 2.2 The admitted data — a FRESH Gate-0 scope freeze

**This is a new scope freeze, not an extension of Design 85's.** Design 85 §2 admits *complete
multi-trial binomial* data with `n_it ∈ {2, 3, …}` in **every** unit-trait cell and explicitly
excludes single-trial Bernoulli rows. Sparse binary therefore lies **outside** it, and no Design 85
evidence transfers here.

Admitted:

- **single-trial Bernoulli**, `n_it = 1`, for every one of the `N T` cells;
- **logit link only**;
- a **complete** response matrix — no masks, no missing cells;
- **`latent(..., unique = FALSE)`** — the ordinary loadings-only subset;
- `X` fixed in advance and of full column rank;
- a realised zero fraction in the predeclared band of §2.3.

Excluded, and each must fail before the objective is constructed: any `unique = TRUE` or explicit
`+ unique()` term; any diagonal `Psi`; multi-trial binomial; any other family; probit, cloglog or
any non-logit link; trait-specific links; response masks, case weights, offsets, fractional
successes; phylogenetic, animal, spatial, kernel, within-unit, cluster, meta-`V`, missing-data,
mixed-family, random-slope, or predictor-informed-score terms; and any structured prior — the
prior here is exactly `N(0, I_q)`.

### 2.3 What "sparse" means, operationally

"Sparse binary" is meaningless without a number. It is defined here as the **realised zero
fraction** on the simulated data at the planted parameters:

```
z  =  #{ y_it = 0 } / (N T),      target band  z ∈ [0.90, 0.97]
```

The DGP intercept is tuned to hit the band; the **realised `z` is reported for every replicate**;
and band achievement is a **Gate-0 receipt only** — replicates falling outside the band are **still
analysed**. Excluding them would be post-hoc selection on an outcome-adjacent quantity.

> **TO CONFIRM BEFORE APPROVAL.** The band `[0.90, 0.97]` is an *inference* about typical
> presence–absence community matrices, not a cited figure. It must be either grounded in a citation
> or replaced by the maintainer before this contract is approved.

### 2.4 Information per unit — the criterion that replaces `q >= 4`

An earlier draft proposed an information floor of the form `T × median(n_it) / q`. **That
expression is vacuous under this contract:** since `n_it = 1` identically, it collapses to `T / q`,
a purely structural constant that is known before any data exist, is constant along every sample
size, is constant across every zero fraction, and is already implied by `1 <= q <= T`. It is a rank
side-condition, not an information measure, and it omits the response entirely — which is precisely
where sparsity acts.

The quantity that actually governs the approximation error is the observed information each unit
carries about its own latent score. For `n_it = 1`,

```
H_i  =  sum_t  p_it (1 - p_it) · lambda_t lambda_t'
I_unit  :=  lambda_min( H_i )
```

**`lambda_min`, not `trace/q`**: the approximation error is governed by the worst-conditioned latent
direction, and a trace average hides an unidentified axis behind a well-identified one.

Sparsity enters through `p_it(1 - p_it)`. At prevalence `p̄ = 1 - z`:

| `z` | `p̄(1-p̄)` | information per unit, relative to balanced |
|---|---|---|
| 0.50 | 0.2500 | 1.00× |
| 0.90 | 0.0900 | 0.36× |
| 0.95 | 0.0475 | **0.19×** |
| 0.98 | 0.0196 | **0.078×** |

A 95 %-zero matrix carries roughly **5.3× less** information per unit than a balanced one at the
same `T`. Every cell reports `T`, `q`, `z`, `I_unit`, and `trace(H_i)/q`.

**Calibration, not invention.** The admission cell's `I_unit` is set as a stated fraction of the
`I_unit` implied by **Korhonen's own Fig. 3 configuration** — the only regime where evidence
exists. This makes the extrapolation a measured distance rather than a rhetorical one, and it is
feasible on a single axis because Korhonen's binary simulations are *also* `n_it = 1`.

> **TO CONFIRM BEFORE APPROVAL.** Korhonen's realised prevalence and loading scale are not yet
> recovered from the paper. **If they cannot be recovered, this contract must state that the
> distance from Korhonen is UNQUANTIFIED**, which materially weakens every extrapolation in §11,
> including the defence of the coverage floor. This caveat may not be dropped silently.

### 2.5 The frozen parameter file

Design 85's Gate-3 evidence was lost because its pilot **runner** implemented a different
experiment from the one its prose specified [85 §13](85-highdim-nongaussian-va-formal-contract.md).
Prose did not prevent that. Therefore:

**All predeclared quantities — the `n` ladder, replicate counts, the coverage floor, the margin
over Laplace, `T`, `q`, the planted `beta` and `Lambda`, the zero-fraction target, the `I_unit`
floor, and the denominator rule — live in one machine-readable frozen file. Its checksum is
recorded in this contract at approval. The runner READS that file; it does not restate any of
these values.** A run whose parameter file checksum does not match the recorded value is not
evidence under this contract.

---

## 3. Rank is fixed, never selected by the objective

`q` is a **planted DGP constant**, predeclared per cell. This contract does **not** select rank, and
no fitted-`q` quantity may appear in any gate table.

This is a deliberate departure from Design 85, whose Gate 4 handed off to a BIC/ML rank selection
and whose pilot then conflated the fixed-rank comparison with the ML-selected-rank hand-off. That
conflation is the documented cause of its NO-GO. Removing rank selection from this contract
entirely removes the channel.

---

## 4. Fixed and optimised coordinates

| Stage | Fixed | Optimised | Produces |
|---|---|---|---|
| Gate-1 algebra | tiny fixtures; all coordinates | none | identities and AD agreement |
| Gate-2 correctness anchor | data, `X`, `q` | `beta`, packed `Lambda`, all `a_i`, `A_i` | recovery of `beta`, `Sigma_B` on an information-rich cell |
| Gate-3 reference comparison | data, `q`, **`beta` and `Lambda` held at common fixed values**, variational family | only `a_i`, `A_i` (EVA) and `m_i`, `L_i` (GH reference) | EVA-vs-GH discrepancy at identical coordinates |
| Gate-4 admission | data, `q`, ladder rung, seeds | `beta`, packed `Lambda`, all `a_i`, `A_i` | coverage, bias, attrition, per rung, EVA and Laplace arms |

**Gate 3 runs EVA in a non-default mode.** Korhonen's EVA optimises model and variational
parameters *jointly* with no inner step. To make Gate 3 a measurement of Taylor error rather than a
comparison of two different optima, EVA must be run with `(beta, Lambda)` **held fixed** at the same
values the reference uses, optimising only the variational coordinates. This mode exists solely for
Gate 3 and is not how EVA is used at Gate 4.

No coordinate is silently profiled, restricted, or integrated under another name. The variational
means and covariances are **ordinary optimiser parameters, never TMB `random` parameters** — this
is the structural property of the method (Korhonen §3.1: "there are no integrals in `ell_EVA`").

---

## 5. The objectives

### 5.1 EVA

With `mu_it = x_it' beta + lambda_t' a_i` and the variational factor `q_i(u_i) = N_q(a_i, A_i)`,

```
ell_EVA(beta, Lambda, a, A)
  = sum_i sum_t { log f(y_it | a_i) + 0.5 * tr( H_i(a_i) A_i ) }
    + 0.5 * sum_i { log det(A_i) - a_i' a_i - tr(A_i) }
```

where `H_i(a_i) = d² [ sum_t log f(y_it | u_i) ] / du_i du_i'` evaluated at `u_i = a_i`
(Korhonen eq. 5). For the Bernoulli-logit case their §4.2 gives the closed form directly:

```
ell_EVA = sum_i sum_t [ y_it * eta_it - log(1 + exp(eta_it)) ]
        - sum_i sum_t { exp(eta_it) / (2 (1 + exp(eta_it))²) } * lambda_t' A_i lambda_t
        + 0.5 * sum_i { log det(A_i) - a_i' a_i - tr(A_i) }
```

with `eta_it = x_it' beta + lambda_t' a_i`. Note the middle term is `-0.5 * p_it(1-p_it) *
lambda_t' A_i lambda_t`, i.e. the same `p(1-p)` weight that defines `I_unit` in §2.4 — the
information geometry and the objective's curvature term are the same object.

### 5.2 The Gauss–Hermite reference

The reference objective is Design 85 §5's `L_H` with the same `q_i` family, evaluated by
deterministic one-dimensional Gauss–Hermite quadrature. Under `n_it = 1` it reduces to

```
L_H = sum_i sum_t [ y_it * mu_it - G_H(mu_it, v_it) ]
    - 0.5 * sum_i [ tr(S_i) + m_i' m_i - log det(S_i) - q ]
```

with `v_it = lambda_t' S_i lambda_t` and `G_H` the stabilised quadrature expectation of
`softplus`.

**The reference is already implemented and is on `origin/main`.** Design 85's R3 prototype was
merged, not parked: `inst/tmb/gllvmTMB_va_r3.cpp` (323 lines), `R/va-r3-proto.R` (625 lines),
`tools/va-r3-pilot.R`, and `tests/testthat/test-va-r3-prototype.R`. It is internal, non-exported,
and outside the shipped `gllvmTMB()` surface. Its components are directly reusable as the reference
arm:

- `.va_r3_gh_rule(H)` — Golub–Welsch tridiagonal eigendecomposition for physicists' Hermite nodes,
  with weights from an explicit Hermite recursion because base `eigen()`'s eigenvector formula
  loses the extreme `H = 61` weights to exact zero. Admits only `H ∈ {15, 25, 61}`.
- `va_r3_softplus<Type>` — `max_x + logspace_add(zero, -abs_x)`, so the only exponential has a
  non-positive argument, including on AD tapes.
- `va_r3_softplus_expectation()` — a heat-kernel/Hermite expansion for `v <= 1e-6` and true
  quadrature above it, branch-selected by `CppAD::CondExpGt` so AD never differentiates `sqrt(v)`
  at `v = 0`.
- `PARAMETER_MATRIX(log_L_diag)` with `Li(k,k) = exp(log_L_diag(i,k))` — exactly the
  `L_i[k,k] = exp(rho_i[k])` parameterisation of §7.1 — and `random = NULL` in `MakeADFun`.

**The apparatus is reused; none of Design 85's results, receipts, or verdicts are.** Reuse is
conditional on the Gate-0 fresh-derivation audit (§11).

### 5.3 The bound property — NOT ESTABLISHED

The standard variational bound follows from Jensen's inequality applied to the exact integrand.
**EVA substitutes a second-order Taylor expansion for that integrand, and Jensen does not survive
the substitution.** Korhonen's prose describes the result as a "closed-form variational lower
bound", but this contract does not inherit that description as a proven property.

**Under this contract, until and unless a derivation establishes it:**

- `ell_EVA` is called **the EVA objective**. It is **not** called a bound, a lower bound, an ELBO,
  a likelihood, a marginal likelihood, a restricted likelihood, REML, or AGHQ.
- **No signed statement** may be made about `ell_EVA` relative to the marginal log-likelihood — not
  "understates", not "overstates". The direction is unknown.
- Consequently **Design 85 Gate 2's acceptance form cannot be reused here.** That test is a
  one-sided bound-violation check (`ELBO <= log marginal likelihood` up to quadrature error), and
  its validity is exactly the property in question. Gate 3 is therefore framed as a **two-sided
  magnitude comparison** (§11), not a directional inequality.

Establishing or refuting the bound property is a Gate-1 deliverable. Either outcome is acceptable;
an unexamined assumption is not.

---

## 6. Loading identification and the live-engine boundary

The prototype reconstructs `Lambda` from the same packed coordinates as the live ordinary B-tier
engine: the first `q` entries are the diagonal; the remaining `Tq − q(q+1)/2` fill the strict lower
triangle column-by-column; the strict upper triangle is exactly zero
([`src/gllvmTMB.cpp`](../../src/gllvmTMB.cpp), the live unpacker).

A pre-existing documentation/implementation discrepancy must not be hidden: Design 04 describes
positive, exponentiated loading diagonals, whereas the live TMB code copies `lam_diag(j)` without
`exp()`. Korhonen §2 states that `gllvm` constrains the diagonal to be **positive**. Under this
contract:

- loading diagonals remain **raw unconstrained live-engine coordinates**;
- the lower-triangular constraint removes continuous rotations but leaves axis-sign reflections;
- pass/fail targets are `Sigma_B = Lambda Lambda'`, fitted probabilities, and where needed
  Procrustes/sign-aligned loadings — **never** unaligned raw `Lambda` or raw scores;
- changing the diagonal to `exp(log_lambda_diag)` is a separate engine reparameterisation and doing
  it inside this prototype is a **NO-GO**;
- any claim that the live engine already has positive loading diagonals is a **NO-GO** until the
  source and the design prose are reconciled.

---

## 7. Numerical requirements

The apparatus of [Design 85 §7](85-highdim-nongaussian-va-formal-contract.md) is **reused as
apparatus**. Its *receipts* are not inherited: every tolerance below is a fresh predeclaration of
this contract that happens to take the same value, and each must be re-established against the EVA
objective in this code path.

1. Parameterise each variational Cholesky diagonal as `L_i[k,k] = exp(rho_i[k])`; compute
   `log det(S_i) = 2 sum_k rho_i[k]` and `tr(S_i) = sum_{j,k} L_i[j,k]²`. Never form a determinant
   or a matrix inverse.
2. Compute `v_it` as `|| L_i' lambda_t ||²`; do not form `S_i`. Implement the continuous `v -> 0`
   limit; a naively differentiated `sqrt(v)` at exactly zero is prohibited.
3. Compute `softplus(x)` as `max(x, 0) + log1p(exp(-|x|))`. Direct `log(1 + exp(x))`, explicit
   probabilities near zero or one, and clipping `eta` are prohibited. **In the sparse regime `eta`
   runs far negative by construction**, so this is load-bearing, not hygiene.
4. Every objective and gradient evaluation must remain finite. Non-finite values fail loudly with
   the unit, trait, and offending coordinate class; they are never replaced by a large constant and
   counted as convergence.
5. Quadrature nodes and weights for the §5.2 reference are immutable data; the `H = 15/25/61` ladder
   is required, evaluated at the **same parameter vector**, with the scalar oracle agreeing to
   `1e-10` on a frozen `mu × v` grid.
6. **The optimiser gate must be re-derived for `ell_EVA`.** Design 85 §7.6's constants (code zero,
   `max |grad| < 1e-4`, agreement of at least three of four deterministic starts within `1e-6`,
   bounded polishing) were calibrated on a bound with known geometry. `ell_EVA` may not be a bound
   (§5.3). The *form* of the gate is reused; its constants must be re-established, and the
   re-derivation recorded, before Gate 4 runs.

### 7.8 Implementation precedent — read from `gllvm`'s source, not from prose

`gllvm`'s actual implementation was read at `JenniNiku/gllvm@50a2bcc4` (2026-07-22). Design 72's
account of it was reconstructed from web summaries and carried an explicit TO-VERIFY list; the
following supersedes that reconstruction with source evidence. This is precedent, not obligation —
but a design that ignores a working implementation of the same estimator is choosing to re-derive
solved problems.

- **The structural claim is CONFIRMED.** Under `method = "VA"` and `"EVA"` the `MakeADFun` calls
  (`R/gllvm.TMB.R:1403-1406`, `1365-1368`, `1617-1620`) pass **no `random=` argument at all**; the
  variational parameters `u`, `Au`, `lg_Ar`, `Abb` are ordinary `parameters=` entries optimised
  jointly. Under `method = "LA"` the call at `R/gllvm.TMB.R:2121-2125` does pass
  `random = randomp` with `inner.control`. This is the *only* branch that invokes TMB's Laplace
  machinery.
- **A trap worth naming.** Under VA/EVA the `data.list` contains an entry *called* `random`
  (`R/gllvm.TMB.R:1398`), consumed in C++ as `DATA_IVECTOR(random)` (`src/gllvm.cpp:98`). It is a
  **modelling flag** marking which structural components carry a variance component. It is not
  TMB's `random=` mechanism, and reading it as such would invert the central conclusion.
- **One template, one DLL, switched by a data flag.** `src/gllvm.cpp:95` declares
  `DATA_INTEGER(method); // 0=VA, 1=LA, 2=EVA`, dispatched by ordinary C++ branches
  (`src/gllvm.cpp:3215`, `3389`). **This contradicts Design 72 §2.3's recommendation of a separate
  VA template/DLL.** Two independent implementations — `gllvm` here, and drmTMB's own GVA design
  gate (`docs/design/160-gaussian-variational-approximation-gate.md`, which specifies a
  `DATA_INTEGER inference_method` flag in the same template with the variational parameters kept
  out of `random=`) — converge on the flag-in-one-template shape. Design 72's isolation argument
  should be revisited rather than inherited, though **no engine change is in this contract's
  scope** (§13.10).
- **The default variational covariance is full, not mean-field.** `Lambda.struc = "unstructured"`
  is the default (`R/gllvm.R:447`), a per-unit log-Cholesky factor with `exp()` on the diagonal
  (`src/gllvm.cpp:396-406`, comment "log-Cholesky parametrization for A_i:s"); `"diagonal"` is the
  alternative. **This matters for Gate 3:** matching the variational family across the EVA and
  reference arms (§9.2) is achievable with the field's default rather than a special mode.
  Parameter counts: `u` is `n × q`; `Au` is `q·n` diagonal or `q(q+1)/2 · n` unstructured.
- **Standard errors are corrected, and the mechanism is specific.** For VA/EVA the full joint
  Hessian is taken over *all* parameters including variational ones (`sdr <- objrFinal$he(...)`,
  `R/se.gllvm.R:94-99`) — possible precisely because there is no `random=` block — and the model
  parameters' covariance is then the **Schur complement** `I = A − B D^{-1} B'` followed by
  `MASS::ginv(I)` (`R/se.gllvm.R:201-212`), manually reproducing the generalised delta-method
  correction `sdreport` would supply for true random effects. Prediction intervals additionally use
  a **CMSEP** delta-method correction (`CMSEPf`, `R/gllvm.auxiliary.R:2439-2600`), with
  `CMSEP = FALSE` giving the naive variational-covariance intervals that are known to be
  anti-conservative.
- **Initialisation.** `starting.val = "res"` fits a model without latent variables and applies
  factor analysis to the residuals (`factanal_gllvm`, `R/gllvm.auxiliary.R:677-681`); variational
  log-SDs start at `log(Lambda.start)`, off-diagonals at zero; `diag.iter` runs a diagonal-covariance
  first pass and warm-starts the unstructured fit from it.
- **Optimiser.** Default `optim` with BFGS (`L-BFGS-B` for Tweedie), `reltol = 1e-10`,
  `maxit = 6000`; `nlminb`/`alabama`/`nloptr` for constrained ordination.

**None of this is evidence for any gate in §11.** It is recorded so that this contract's numerical
and interface choices are made in knowledge of a working implementation rather than in ignorance
of one.

---

## 8. Symbol-to-implementation alignment

| Symbol | R / formula contract | Known-DGP draw | Prototype coordinate | Recovery / reference target |
|---|---|---|---|---|
| `y_it` | binary, complete, logit only | `Bernoulli(logit^{-1}(eta_it))` | immutable integer data | exact cells match across arms |
| `z` | none | realised on the draw | reported per replicate | Gate-0 band receipt |
| `beta` | same fixed-effect RHS every rung | planted vector | unconstrained optimiser vector | bias, RMSE, **interval coverage** |
| `Lambda` | `latent(..., d = q, unique = FALSE)` | planted lower-triangular | exact live `theta_rr_B` pack/unpack | `Sigma_B`, Procrustes/sign-aligned |
| `u_i` | ordinary unit score | iid `N_q(0, I_q)` | represented by `a_i`, `A_i` | not a recovery target |
| `A_i` | no user-facing keyword | not a DGP parameter | unit-specific variational covariance, log-Cholesky | SPD; `tr(A_i)` vs `tr(S_i)` at Gate 3 |
| `H_i` | none | not a DGP parameter | analytic Hessian at `a_i` | agrees with finite differences |
| `I_unit` | none | computed from planted `Lambda`, realised `p_it` | `lambda_min(H_i)` | Gate-0 floor; reported per cell |
| `Sigma_B` | `extract_Sigma(..., part = "shared")` | `Lambda Lambda'` | `Lambda * Lambda'` | **co-equal coverage target with `beta`** |

An empty or differently implemented cell is a contract failure, not an invitation to reinterpret
the symbol.

---

## 9. Valid comparisons

1. **Gate-2 anchor.** On an information-rich cell built **in the GLLVM path** (loadings, `Sigma_B`,
   live packed `Lambda`), compare EVA's recovery of `beta` and `Sigma_B` against planted truth and
   against a Laplace fit on byte-identical data.
2. **Gate-3 reference comparison.** At identical fixed `(beta, Lambda)` **and the same variational
   family on both arms**, compare EVA's `a_i`, `A_i` with the reference's `m_i`, `S_i`. The
   load-bearing quantities are `tr(A_i)` vs `tr(S_i)`, the relative Frobenius error of the
   covariances, and the resulting Wald standard error for `beta`.
   - **The variational family must match.** Design 85 §5 mandates full covariance and rules
     mean-field out of scope; if EVA were run with a diagonal `A_i` against a full-covariance `S_i`,
     the difference would contain the Taylor error **plus** a mean-field restriction error and
     could not be attributed. The family is a fixed coordinate (§4) and must be recorded.
   - **What this measures.** Departure of EVA from the *exact Gaussian-VA objective* — i.e. Taylor
     error. It does **not** measure departure from the truth, because the reference is an ELBO, not
     a marginal likelihood. The two must not be conflated.
   - This comparison is also the measurement that **resolves the open tension in Korhonen §7**,
     where EVA is said to underestimate latent posterior covariances more than standard VA while
     §5 reports EVA's covariance traces are larger. It shall be reported whichever way it falls.
3. **Gate-4 admission.** Per ladder rung, EVA and Laplace on byte-identical data with identical
   seeds: interval coverage for `beta` and for `Sigma_B`, bias, RMSE, attrition, wall time.
4. **Within method.** The `H = 15/25/61` reference ladder at a common parameter vector;
   deterministic starts after reaching a common optimum.

---

## 10. Prohibited interpretations and outputs

- Calling `ell_EVA` a marginal log-likelihood, exact likelihood, restricted likelihood, REML,
  AI-REML, Cox–Reid adjustment, AGHQ, ELBO, or lower bound (§5.3).
- Any **signed** statement about `ell_EVA` relative to the marginal log-likelihood.
- Computing or exposing `logLik`, AIC, BIC, LRT, likelihood-ratio profiles, or model weights from
  the EVA objective.
- Selecting `q` by the objective, or comparing objective values across ranks as if the
  approximation gap were equal.
- Interpreting the inverse EVA Hessian as calibrated frequentist uncertainty without the coverage
  evidence this contract exists to obtain.
- Treating `a_i` or `A_i` as model parameters, true latent scores, or repeated-sampling uncertainty
  for `u_i`.
- Claiming variance-component, interval, coverage, rank-selection, or high-dimensional accuracy
  from optimiser convergence alone.
- Folding a diagonal `Psi`, the logistic `pi²/3`, an overdispersion term, or an observation-level
  random effect into `Sigma_B`.
- Widening to any other family, link, trial count, structured source, random slope, or public
  syntax **by analogy**.
- Using this prototype to weaken the package's Gaussian-only REML boundary
  ([Design 43](43-asreml-speed-techniques.md)).

Any prototype result object carries `research_only = TRUE`, `objective_type = "EVA_TAYLOR2"`, the
family, link, `unique = FALSE`, `q`, the realised `z`, the parameter-file checksum, and an exact
source commit only when the source is tracked and clean. It must not inherit class
`gllvmTMB_multi` or any method implying a marginal likelihood.

---

## 11. Gates

Gates are **sequential**. A later gate never compensates for an earlier failure, and tolerances are
never widened after a result is seen ([Design 72](72-variational-approximation-feasibility.md)).

### Gate 0 — scope and coordinate freeze

- The frozen parameter file (§2.5) exists; its checksum is recorded in this contract; the runner
  reads it and restates nothing.
- A byte-identity checksum confirms EVA, the reference, and the Laplace arm receive the same
  ordered response cells, trait IDs, unit IDs, and `X`.
- `n_it = 1` for every cell; `unique = FALSE` asserted; every excluded keyword, family, link and
  data shape fails **before** objective construction.
- Realised `z` reported per replicate; `I_unit` computed and reported per cell.
- **The correctness anchor and the admission experiment have no shared runner, no shared
  denominator, and no shared output directory.**

**NO-GO:** any implicit `Psi`, changed loading transform, missing cell, `n_it != 1`, a parameter
file whose checksum does not match, or **parked VA source copied without a fresh derivation audit**.

### Gate 1 — algebra, autodiff, and the bound question

- **The Gaussian exactness identity.** For a Gaussian response with identity link, `log f(y|u)` is
  exactly quadratic in `u`, so its second-order Taylor expansion is exact and `ell_EVA` coincides
  identically with the exact Gaussian-VA objective. Require agreement below `1e-10` **in this EVA
  GLLVM code path**. This is a cheap, strong test of the Taylor machinery. It is an **algebra
  check, not a recovery anchor**, and it does **not** transfer to any non-Gaussian family.
- The Bernoulli-logit `ell_EVA` of §5.1, its KL term, and the returned negative objective each
  agree with independent scalar calculations on tiny fixtures to `1e-10`.
- Analytic/autodiff gradients agree with central finite differences to relative error `1e-5` away
  from declared boundaries; the small-`v` routine is value- and first-derivative continuous.
- **The bound property (§5.3) is derived and its outcome recorded**, either way.

**NO-GO:** clipping needed for finiteness; a wrong KL sign; omitted constants; an inconsistent
negative-objective sign; or the Gaussian identity failing.

### Gate 2 — correctness anchor, information-rich

Built **fresh in the GLLVM path** with loadings, `Sigma_B`, and the live packed-`Lambda`
reconstruction. Deliberately **not** sparse: an information-rich cell asks *"is the implementation
right?"*, which is a different question from admission.

> **The parked Design 72 Phase-1 prototype does NOT satisfy this gate.** It is a two-random-effect
> GLMM with a mean-field diagonal *closed-form* VA — no `Lambda`, no `Sigma_B`, no packed
> coordinates, **no Taylor surrogate, and therefore not EVA** — in a separate template on an
> unmerged branch. Citing it as evidence here would inherit an artifact's status across a boundary
> its evidence does not cross, which is the error class that produced Design 85's NO-GO. It may be
> cited as **context only**.

**NO-GO:** recovery failure on an information-rich cell, or reliance on a single start.

### Gate 3 — EVA versus the reference, at fixed coordinates

Per §9.2, with the same variational family and `(beta, Lambda)` fixed on both arms. Predeclared
tolerances on the SE-relevant quantities: unit-level variational means RMSE below `0.05`; covariance
relative Frobenius error with median below `0.10` and no unit above `0.25`.

> These values are taken from Design 85 §11 Gate 2 and are **restated here as fresh
> predeclarations**. They were calibrated there against an AGHQ reference at `q <= 2` on
> non-separated fixtures; **their calibration in the sparse regime is unestablished**, and that is
> recorded rather than hidden.

The raw objective difference `L_H - ell_EVA` is **reported as a diagnostic and gates nothing** —
there is no known mapping from an objective discrepancy to a coverage loss.

**NO-GO:** a variational-family mismatch between arms; a directional/one-sided bound test used in
place of the two-sided magnitude comparison; or dependence of the conclusion on one start.

### Gate 4 — admission

**The ladder.** `n ∈ {100, 260, 600, 1200}` — equal steps in `sqrt(n)`, since a fixed bias relative
to a shrinking standard error scales in `sqrt(n)`. **`n = 260` is a replication anchor against
Korhonen**: the design must reproduce approximately 0.910 EVA coverage there before any
extrapolation from this ladder is believed.

**Replicates.** `R = 200` at `n ∈ {100, 260, 600}`; **`R = 1000` at `n = 1200`**, where the decision
is taken. Korhonen used `R = 1000`, giving `MCSE(0.95) = 0.0069`, so their 0.910-vs-0.950 gap is
about 5.8 MCSE — the basis for treating the decay as real rather than noise.

**Both arms, every rung.** EVA and Laplace on byte-identical data with identical seeds. Without the
Laplace arm the result is uninterpretable.

**Denominator.** **All attempted replicates.** A fit failing the optimiser gate counts as
**non-covering**; attrition is reported per rung. Sparse binary fails more often at small `n`, so
dropping failures would manufacture or mask a coverage trend out of differential attrition alone.

**Targets.** Two-sided 95 % Wald interval coverage for (i) the primary fixed-effect coefficient and
(ii) `Sigma_B`. Both are co-equal; a `beta`-only design measures EVA at its most flattering.

**THE ADMISSION RULE — and the CUT.**

> **EVA is admitted only if there exists a predeclared contiguous region of the ladder in which
> both (a) coverage is at least `0.900` and (b) coverage exceeds the Laplace arm's coverage by at
> least `0.02`. The CUT fires if no such region exists.**
>
> Decided on the **point estimate** against the floor, with MCSE printed beside it.

Why this shape, recorded now so it cannot be re-argued later:

- **A one-sided "coverage below a floor at the largest `n`" rule is not a gate.** If a fixed-order
  bias persists while standard errors shrink, coverage tends to zero for *any* such method, so that
  rule's verdict is a function of where the ladder stops — a dial the designer sets.
- **Laplace and EVA cross.** Korhonen Fig. 3 has Laplace improving (0.81 → 0.94) while EVA decays
  (0.968 → 0.910); they cross between `n = 190` and `n = 260`. The scientific claim is "better than
  the incumbent where the incumbent is weak", so the criterion must measure *that*.
- **The floor is defended two-sidedly.** `0.94` is **already breached by Korhonen's published
  n = 260 result**, so it would pre-decide a NO-GO before any code is written. `0.85` licenses a
  doubled error rate and fails the meaning test. Only `0.89–0.92` is informative, and `0.900` — the
  "error rate doubles" line — is the defensible point in it.
- **It is arithmetically decidable.** At `R = 1000`, coverage `0.91` is separated from `0.95` at
  about 3.5 standard errors. Distinguishing `0.91` from `0.90` would need `R ≈ 3300`, which is why
  the floor sits well away from the plausible truth.

**A second ladder.** Because `H_i` does **not** depend on `n`, an `n`-only design can only ever
confirm that a fixed per-unit error eventually dominates — a foregone conclusion. A second ladder
in `T` (or in `z`) at fixed `n` is therefore required, and it is the one that can answer whether the
per-unit error is small enough in the regime of interest.

**NO-GO:** success declared from convergence rate alone; failed fits excluded from denominators;
any fitted-`q` quantity in a gate table; bands widened post hoc; or `n_max` chosen by affordability
rather than on a stated scientific basis.

### Gate 5 — claim audit

No public API, reference page, NEWS entry, validation-register promotion, inference method, or rank
recommendation follows from Gates 0–4. A separate maintainer decision, simulation-review sign-off,
TMB likelihood review, documentation cascade, and public-object contract would each be required.

---

## 12. Evidence used

- **Korhonen, Hui, Niku & Taskinen (2023)**, *Statistics and Computing* **33**:26 — the EVA
  construction (§3, eq. 5), the Bernoulli-logit closed form (§4.2), the complexity statement, the
  simulation design and Fig. 1/Fig. 3 results, and the authors' own limitations (§7). Read directly.
- **Joe (2008)**, *CSDA* **52**:5066–5074 — what governs Laplace accuracy for discrete responses;
  the Laplace-as-one-node-AGHQ identification; AGHQ's exponential cost in random-effect dimension.
  Read directly.
- [Design 72](72-variational-approximation-feasibility.md) — the VA/EVA taxonomy, the sequential
  proof logic, and the bias/likelihood-comparison boundary. Its `gllvm` implementation claims were
  reconstructed from web summaries and are flagged TO-VERIFY in its own §8.
- [Design 85](85-highdim-nongaussian-va-formal-contract.md) — **apparatus only** (§7 numerical
  requirements, the reference objective, the gate-ladder discipline) and its §13 failure record.
  **No result, receipt, or verdict from it is inherited.**
- [VA Phase-1 report](../dev-log/after-task/2026-06-03-va-phase1-proof.md) — **context only**; see
  the boxed note under Gate 2.
- [Design 04](04-sister-package-scope.md), [Design 43](43-asreml-speed-techniques.md),
  [Design 05](05-testing-strategy.md) — package boundary, REML language reservation, and the
  known-DGP / all-attempt denominator discipline.

---

## 13. What this contract does NOT cover

Even if every gate passes, none of the following is licensed.

1. **Any other family or link.** Bernoulli-logit only. EVA's Theorem 1 covers other families
   *mathematically*; no coverage evidence would exist for any of them, and no family inherits
   another's evidence.
2. **Any structured prior — the entire gllvmTMB differentiator.** Everything here is at
   `p(u) = N(0, I)`. Nothing is licensed about the exact sparse phylogenetic `A^{-1}`
   (Design 47), the SPDE `Q` (Design 64), meta `V`, kernel terms, `dep`, or `unique = TRUE`.
   **The validation-debt rows that motivated Design 72 in the first place — PHY-18, SPA-10,
   SPA-09 — are untouched by this experiment.** This is the most likely over-reading.
3. **Rank selection.** Fixed planted rank only; no objective-based selection, no cross-rank
   comparison.
4. **Any likelihood-scale inference** — and, because the bound property is unsettled, not even a
   signed statement about the objective's relation to the marginal likelihood.
5. **Latent-score or ordination inference.** Coverage for `beta` says nothing about intervals for
   `u_i`; prediction regions would need CMSEP and separate evidence.
6. **Multi-trial binomial**, incomplete responses, mixed families, offsets, or weights.
7. **Any asymptotic claim, in either direction.** Korhonen §7 records that no large-sample theory
   for EVA exists. A ladder to `n_max` is an empirical statement about `n <= n_max` at the studied
   `I_unit`; it licenses neither consistency nor inconsistency.
8. **Any `q` other than the one planted.** A pass does **not** retire the `q >= 4` question by
   confirming it — §1.4 retires that claim as *unsourced*, and one measurement at one `q` does not
   convert it into a supported one.
9. **Speed.** Korhonen's ~5× advantage is their code on their configuration. No wall-clock claim
   about `gllvmTMB` follows.
10. **Any public surface.** No `method=` argument, NEWS entry, README or vignette change, or
    register promotion. The Design 04 boundary question (§1.5) is **not decided here**.
11. **Design 85's verdict.** A pass does not reopen its `q = 4/6` NO-GO: different estimator,
    different data contract, different gates.
12. **The incumbent's inadequacy.** **If the CUT does not fire, that is not evidence that Laplace
    is inadequate.** Korhonen's Laplace failure is in their configuration, not in `gllvmTMB`'s
    engine on `gllvmTMB`'s data shapes. A GO on EVA is not an argument to move off Laplace.

---

## 14. Roadmap — structured EVA over exact sparse priors

> **NON-BINDING. NOT EVIDENCE. This section predeclares no gate and may not be cited by §11.**
> If this section were deleted, the contract above would still stand complete. It is recorded
> because the maintainer asked for the direction of travel, not because anything here is approved.

The differentiator is **not** "do EVA" — that ground is taken, and Design 04 already concedes we
should not claim novelty for the estimator. The question is what `gllvm` does *not* have.

Read from source (`JenniNiku/gllvm@50a2bcc4`), `gllvm` already retains structure under VA/EVA
rather than falling back to Laplace: phylogenetic and spatial **column** effects use a
Matrix-Normal, **Kronecker-structured** variational covariance (`Ab.struct = "MNunstructured"`,
with Kronecker-product Cholesky determinants at `src/gllvm.cpp:907` and `:950`), and correlated
latent variables get banded / nearest-neighbour variational blocks (`Lambda.struc = "bdNN"`). So
"structured VA" per se is also taken, and Design 72's §1.3 framing of this as an open frontier was
too generous to us.

**The remaining, genuine difference is the prior, not the variational family.** `gllvm` approximates
the inverse of its column-correlation matrix with a **nearest-neighbour Gaussian process**
(`gllvmutils::nngp(...)` at `src/gllvm.cpp:814-835`; `nn.colMat` controls the neighbour count).
`gllvmTMB` does not approximate: it already holds the **exact sparse precision** in both cases that
matter — the Hadfield `A^{-1}` for phylogeny (Design 47) and the SPDE `Q` for space (Design 64).

So the defensible direction is **EVA whose KL term is taken against an exact sparse precision**,
with a variational covariance that stays sparse or Kronecker-structured so the cost does not
collapse back to dense — and whose claim is *"no nearest-neighbour ordering artefact"*, which is a
narrow, checkable statement rather than a novelty claim. Design 72 §3 works through that algebra and
names the make-or-break risk honestly: whether such a covariance can remain both cheap *and*
adequate for non-Gaussian families. That risk is unretired.

A second direction the EVA authors themselves flag as open (§7): **mixed-response GLLVMs**, where
response columns are of different types. `gllvmTMB`'s stacked-trait long format is already
mixed-family per trait, so the data structure exists here and does not in a matrix-in API.

Both directions require their own scope freeze, their own derivation, and their own gates. Neither
inherits anything from this contract.

---

## Approval

This document is **NOT APPROVED**. Approval requires the maintainer's explicit written act, at
which point the parameter-file checksum (§2.5) and the two `TO CONFIRM BEFORE APPROVAL` items
(§2.3 zero-fraction band; §2.4 Korhonen calibration) must be resolved and recorded here.
