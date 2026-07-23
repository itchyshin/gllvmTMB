# Design 86 — EVA sparse-binary scientific-admission contract

**Status:** **APPROVED by the maintainer, 2026-07-22 (chat).** The experimental design in this
document is approved. Two things this approval does **not** do, and both are recorded so the coding
lane cannot over-read it: (1) the Arc-1 coordinate-freeze receipt has now materialised the frozen
file and recorded its checksum (§2.5); this is not an approval of any later gate; (2) approval unlocks Gates 0–3 (algebra, anchor,
reference) only — **Gate-4 compute is a separate, later maintainer approval** (Totoro/DRAC), and
nothing here authorises it. The maintainer additionally directed that **Gate 1 be handed to Codex**;
see the handover at [`docs/dev-log/handover/2026-07-22-codex-handover-design86-gate1.md`](../dev-log/handover/2026-07-22-codex-handover-design86-gate1.md).

> **Ledger discrepancy, reported rather than resolved.** Amendment 3 states that
> `LOOP/decision-queue.md` "records it `NOT YET OPEN`". It does not. That file's Design 86 row
> currently reads **`CUT 2026-07-21`**, with the recommendation *"Superseded by the maintainer's
> EVA cut. Never written or approved — do not cite as a contract."* That row is stale: it records
> Amendment 1's cut of EVA from 0.6 and predates Amendment 3, which reopened this lane on
> 2026-07-22. **The maintainer approved the Design-86 experimental contract on 2026-07-22.**
> That approval is limited to the sequential private gates and does not authorise a public method,
> release claim, or Gate-4 campaign.

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
**was retrieved from exactly one** source — an entry of type `markdown` with **`url: null`**, titled
*"Computational Approaches for Frequentist Generalized Linear Latent Variable Models in
High-Dimensional Latent Spaces"*, carrying no bibliographic identity. It is a self-authored or
machine-generated synthesis that was added to the corpus as though it were a primary source. **No
peer-reviewed source in that corpus states a Laplace-versus-VA crossover at `q >= 4`.**
Korhonen et al. (2023) provide **no evidence either way**, running every simulation at `p = 2` — a
study that never varies `q` is uninformative about a `q`-crossover, and it would be an error to
enlist its silence as corroboration. Joe (2008), read directly, does bear on the question, and
attributes Laplace bias to discreteness, information per cluster, and random-effect variance —
**not** to latent dimension.

Note what an enumeration plus a citation-required query does and does not establish: it shows
**non-retrieval from one corpus**, not non-occurrence in the literature. That is sufficient here,
because the claim's *warrant* was always that corpus.

**The `q >= 4` claim is retired: it may not be cited by any gate or claim under this contract.**
A claim whose only support is an uncited synthesis is not weak evidence; it is no evidence.
Cleaning it out of any register row or public surface elsewhere in the project is a follow-up
**outside this lane's write fence** — noted, not performed here.

What the literature *does* support is a statement about **quadrature**, not about Laplace, and it
is the correct framing to keep. Joe (2008) identifies the Laplace approximation **as** adaptive
Gauss–Hermite quadrature with one node per dimension, and notes that AGHQ with ~5 nodes is
essentially asymptotically unbiased but that its cost is **exponential in the random-effect
dimension**. Two further sources in the audited corpus state the practical consequence directly: Gauss–Hermite
quadrature becomes *"unfeasible with more than three"* latent variables (an unattributed corpus
entry on fast GLLVM estimation), and *"computationally impractical if the number of latent
variables is moderate, e.g. 8"* (Niku et al. 2017). EVA's cost is `O(n q³ + n T q²)` — polynomial.

> **Both quotations are corpus-sourced and NOT read directly**, and neither carries the "read
> directly" status of Korhonen (2023) or Joe (2008) in §12. The first has no attribution beyond the
> corpus entry. This is stated because §1.4 retires another claim precisely for lacking
> bibliographic identity, and it would be self-refuting to lean on quotations of the same status
> while doing so. **The framing above rests on Joe (2008), which was read directly; these two
> quotations corroborate it and are not load-bearing.** Verifying them is a follow-up.

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
- **`n` denotes the number of units, i.e. `n ≡ N`.** It is the ladder variable of §11 Gate 4 and is
  written `n` there for continuity with Korhonen, whose `n` is likewise the unit count and whose
  `m` is the trait count (our `T`). Stated explicitly because §1.2 exists to stop exactly this kind
  of notation sliding, and the ladder is the contract's decision axis.
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

> **CONFIRMED by the maintainer, 2026-07-22.** The band `[0.90, 0.97]` stands as written.
> Its epistemic status is recorded honestly and does not change by being confirmed: it is a
> **judgement about typical presence–absence community matrices, not a cited figure**. It is
> adequate to define a predeclared regime — which is all a scope freeze requires — but it may not
> later be reported as an empirically grounded range. If a citation is found, it should be added;
> if one is found that contradicts the band, the band moves and the freeze is re-issued.

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

> **CONFIRMED by the maintainer, 2026-07-22 — the calibration requirement stands as written.**
> Korhonen's realised prevalence and loading scale are not yet recovered from the paper, so the
> calibration is **not yet performed**. Recovering them is a Gate-0 task, not an approval condition.
>
> **The binding consequence is unchanged and may not be dropped silently: if they cannot be
> recovered, this contract must state that the distance from Korhonen is UNQUANTIFIED**, and every
> extrapolation in §11 — including the two-sided defence of the `0.900` coverage floor — is
> correspondingly weakened. In that case the floor becomes a predeclared convention rather than a
> calibrated distance from evidence, and §11 must say so in those words.

### 2.5 The frozen parameter file

Design 85's Gate-3 evidence was lost because its pilot **runner** implemented a different
experiment from the one its prose specified [85 §13](85-highdim-nongaussian-va-formal-contract.md).
Prose did not prevent that. Therefore:

**A scope freeze is not allowed to pretend it knows quantities that a prior gate must re-derive.**
Therefore this contract has three machine-readable freezes: (1) the **Gate-1 fixture file**, frozen
and checksummed in Arc 1; (2) a **Gate-2 information-rich anchor file**, separately approved and
checksummed before any Gate-2 input is generated; and (3) one **Gate-4 campaign file**, frozen
only after the required optimiser and Gate-3 tolerance re-derivations. The campaign file contains all campaign quantities —
the `n` ladder, the second ladders in `T` and `z`, replicate counts, the coverage floor, the margin
over Laplace, `T`, `q`, the planted `beta` and `Lambda`, the zero-fraction target, the `I_unit`
floor, the denominator rule (for coverage *and* for bias/RMSE), the named covariance estimator,
both arms' convergence-failure criteria (EVA's per §7.6 and Laplace's, with any asymmetry stated),
and the full per-replicate seed list. Each runner READS its applicable frozen file; it does not
restate those values. A run whose applicable checksum does not match the recorded value is not
evidence under this contract.

**The seed list is frozen, not merely the seed count.** Freezing `R` alone would leave the study
re-runnable from a fresh RNG state until a favourable curve appeared — a channel entirely distinct
from, and not closed by, the all-attempts denominator rule. Re-running against the frozen seeds
reproduces the same result or reveals a defect; re-running against new seeds is a new experiment and
must be declared as one.

**Locations and schemas are predeclared.** Arc 1 writes
[`docs/design/86-eva-gate1-parameters.json`](86-eva-gate1-parameters.json), containing only the
tiny Gate-1 fixtures, including the D3 quadrature orders and D4 Monte-Carlo seed, draw count, and
decision rule. Before Gate 4, a separately approved
`docs/design/86-eva-gate4-campaign-parameters.json` must contain every campaign quantity listed
above, including explicit expanded per-replicate seed arrays. Both files are canonical JSON (UTF-8,
two-space indentation, terminal newline) before their SHA-256 values are recorded. A root seed or a
seed-generating algorithm is not a substitute for the Gate-4 expanded arrays.

Before Gate 2, a separately maintainer-approved Gate-2 anchor parameter file
(docs/design/86-eva-gate2-anchor-parameters.json) must contain its
information-rich DGP, **all 500 expanded data-generation seeds**, the cell-level
I_unit functional and floor, exact restart and winner rules for both arms, the named
Schur-complement Wald covariance construction, collapse rule, all-attempt denominator/failure rule,
and Gate-2-only runner/output identities. Its SHA-256 is recorded only after the maintainer signs
off its values. Its runner and output root are distinct from Gate 4 by construction.

**Coordinate choice, approved for the first freeze.** The Gate-1 Bernoulli fixture is `q = 1` and
the values in the Gate-1 file. The proposed later baseline is `T = 48`, `q = 2`, an intercept-only
`X`, and `beta = -3.20`; it is explicitly **not frozen** until the Gate-4 campaign file exists.
`korhonen_calibration_status` is `"UNQUANTIFIED"` unless a primary-source recovery occurs before
that later freeze, in which case a new maintainer-approved campaign freeze is required. Thus the
`0.900` floor is a predeclared convention, not a calibrated distance from Korhonen, until that
recovery exists.

**Arc-1 checksum receipt (2026-07-22):** the Gate-1 fixture file SHA-256 is
`a3cb2b9302132b2a917639ac30ce070d5d0f67e9c21f50ffbcc232ead448b036`.

**Arc-2 Gate-2 freeze receipt (2026-07-22):** the maintainer approved
`docs/design/86-eva-gate2-anchor-parameters.json`, SHA-256
`fb71826c84cf94ee288e8843d8997423247da9459cdb83a3ed8e1bb4373034d6`.
Its expanded 500-seed array SHA-256 is
`9ab57cfb07f29e16a648088bbdfb4ebe6bb848a42b43ff3c48e7c76a67c4e29a`.
It is a Gate-2-only information-rich anchor freeze; it does not authorise
Gate 3, Gate 4, any public surface, or a changed shipped engine.

**Arc-1 apparatus and derivation receipt (2026-07-22):** direct reuse is limited to
`.va_r3_gh_rule()` from `R/va-r3-proto.R` at
`c38b3e8c87d1210ec7d3be90bdb95ee84a76a3a7`.  The stable-softplus formula and
log-Cholesky parameterisation were freshly re-derived from §§5.1 and 7.1 and
independently implemented in `R/eva-proto.R` / `inst/tmb/gllvmTMB_eva.cpp`; no
Design-85 C++ or R softplus/expectation code was copied.  The independent
scalar oracle and q=2/permuted-row tests are the equation-to-code audit of the
EVA likelihood, variance, KL, and packed-Cholesky terms.  No source was copied
from parked `origin/claude/va-phase1-proof` (`R/va-proto.R`,
`inst/tmb/gllvmTMB_va.cpp`); its mean-field, closed-form VA is context only.

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
    + 0.5 * sum_i { log det(A_i) - a_i' a_i - tr(A_i) + q }
```

where `H_i(a_i) = d² [ sum_t log f(y_it | u_i) ] / du_i du_i'` evaluated at `u_i = a_i`
(Korhonen eq. 5). For the Bernoulli-logit case their §4.2 gives the closed form directly:

```
ell_EVA = sum_i sum_t [ y_it * eta_it - log(1 + exp(eta_it)) ]
        - sum_i sum_t { exp(eta_it) / (2 (1 + exp(eta_it))²) } * lambda_t' A_i lambda_t
        + 0.5 * sum_i { log det(A_i) - a_i' a_i - tr(A_i) + q }
```

with `eta_it = x_it' beta + lambda_t' a_i`. Note the middle term is `-0.5 * p_it(1-p_it) *
lambda_t' A_i lambda_t`, i.e. the same `p(1-p)` weight that defines `I_unit` in §2.4 — the
information geometry and the objective's curvature term are the same object.

> **The `+ q` is REQUIRED and is a correction to Korhonen's printed form.** Korhonen eq. 5 omits it,
> stating that constants with respect to the model and variational parameters are dropped. That is
> harmless *within* EVA — the constant shifts the objective but not its argmax — and fatal the
> moment the objective is differenced against anything else. The exact
> `-KL(N(a_i, A_i) ‖ N(0, I_q))` is `0.5[log det A_i - a_i'a_i - tr A_i + q]`, and §5.2's `L_H`
> carries the `q`. Dropping it here would put the two objectives on additive scales differing by
> `N·q/2` — **at `n = 1200`, `q = 2` a spurious `+1200` nats** in the `L_H - ell_EVA` diagnostic of
> §11 Gate 3, which a reader would naturally interpret as `ell_EVA` sitting *below* the
> Gauss–Hermite ELBO. That is the bound property re-entering through a units error, in the one
> quantity §5.3 exists to neutralise. Gate 1's NO-GO already names "omitted constants"; this
> contract must not fail its own gate.

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

### 5.3 The bound property — REFUTED IN THE TARGET REGIME

The standard variational bound follows from Jensen's inequality applied to the exact integrand.
**EVA substitutes a second-order Taylor expansion for that integrand, and the bound does not survive
the substitution.** Korhonen's prose describes the result as a "closed-form variational lower
bound"; that is a description, not a theorem, and this contract does not inherit it.

**The derivation (adversarial review, 2026-07-22). It is worse than "unestablished".**

Write `ℓ(u) = log f(y_i | u)` and let `L_exact(q_i) = E_q[ℓ(u)] − KL(q_i ‖ φ)` be the exact ELBO, so
`L_exact <= log p(y_i)` by Jensen. EVA replaces `E_q[ℓ(u)]` by `ℓ(a_i) + ½ tr(H_i(a_i) A_i)` — which
is exactly `E_q` of the second-order Taylor polynomial about `a_i`, the first-order term vanishing
because `a_i = E_q[u]`. Hence, **exactly**:

```
ell_EVA  =  L_exact  −  E_q[R],     R(u) = ℓ(u) − [ℓ(a) + g'(u−a) + ½(u−a)'H(u−a)]
```

So `ell_EVA <= log p(y)` is guaranteed **only if `E_q[R] >= 0`**.

Concavity is not sufficient. `ℓ` is concave in `u` (a linear term minus a softplus of an affine
map), so `H ⪯ 0` — but concavity constrains the *first*-order remainder, not the second-order one.
Pointwise `R >= 0` would require `p(1−p)|_η <= p(1−p)|_{η_a}` for all `η`, which holds only at
`η_a = 0`, i.e. `p = ½`. Under a symmetric `q` the third-order term integrates to zero, so with
`s = softplus` the leading contribution is fourth order:

```
s''''(η) = p(1−p)(1 − 6p + 6p²),        roots at p ≈ 0.2113 and 0.7887
E_q[R]  ≈  −(1/8) · sum_t s''''(η_t) · v_t²,        v_t = lambda_t' A_i lambda_t
```

- **Balanced data** (`0.211 < p < 0.789`): the *local small-variance* term has `s'''' < 0`, so
  `E_q[R] > 0` and `ell_EVA < L_exact` to fourth order.
- **Sparse data** (`p < 0.211`): the *local small-variance* term has `s'''' > 0`, so
  `E_q[R] < 0` and **`ell_EVA > L_exact` to fourth order.** The frozen D4 fixture verifies this
  local overshoot numerically. It is not a theorem for arbitrary `A_i`: at large variance higher
  terms can reverse the sign. Whether EVA also overshoots `log p(y)` always depends on the
  `KL(q ‖ posterior)` slack.

**The fourth-order local sign flips at `p ≈ 0.211`, and this contract's admitted regime is
`z ∈ [0.90, 0.97]`, i.e. `p̄ ∈ [0.03, 0.10]` — entirely on the sparse side of that local result.**
It does not license a universal sign claim outside its small-variance domain.

**This strengthens, rather than weakens, the case for the experiment** — a non-bound objective is
exactly why interval coverage must be measured empirically rather than inferred from the objective's
geometry. But it forecloses any argument that rests on bound-ness.

**Under this contract:**

- `ell_EVA` is called **the EVA objective**. It is **not** called a bound, a lower bound, an ELBO,
  a likelihood, a marginal likelihood, a restricted likelihood, REML, or AGHQ.
- **No signed evidential statement** may be made about `ell_EVA` relative to the **marginal** log-likelihood.
  The derivation above signs `ell_EVA − L_exact` (positive in the sparse regime), but
  `L_exact − log p(y)` carries the `KL(q ‖ posterior)` slack, whose magnitude is unknown, so the
  composite direction remains open. Signing the relation to the *exact ELBO* is permitted and
  established; signing the relation to the *marginal likelihood* is not.
- Consequently **Design 85 Gate 2's acceptance form cannot be reused here.** That test is a
  one-sided bound-violation check (`ELBO <= log marginal likelihood` up to quadrature error), and
  its validity is exactly the property now refuted in this regime. Gate 3 is therefore framed as a
  **two-sided magnitude comparison** (§11), not a directional inequality.

Gate 1 must **reproduce or refute this derivation**, and additionally run the cheap numerical bound
probe against a high-order AGHQ marginal at `q = 1` (§11 Gate 1) — because no other gate in this
contract compares `ell_EVA` to an exact marginal likelihood at all.

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
     error. It does **not** measure departure from the truth: the reference is itself an
     approximation to the marginal likelihood, not the marginal likelihood. The two must not be
     conflated. (`L_H` genuinely does satisfy the Jensen bound, since it applies no Taylor
     substitution — but that property belongs to the reference and is not inherited by `ell_EVA`.)
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
- Any **signed evidential statement** about `ell_EVA` relative to the marginal log-likelihood.
  A frozen, internal Gate-1 AGHQ diagnostic may retain its signed numeric value solely to detect
  implementation drift; it neither predicts a direction nor supports an interpretation or claim.
- **Describing a larger `ell_EVA` — or a smaller negative objective — as better fit than the
  Laplace or Gauss–Hermite objective on the same data.** `ell_EVA`, the Laplace objective, and
  `L_H` are not on a comparable scale, and no ordering among them carries evidential content. This
  prohibition is load-bearing because Gate 4 runs a Laplace arm on byte-identical data at every
  rung, which makes the comparison a one-line temptation.
- Computing or exposing `logLik`, AIC, BIC, LRT, likelihood-ratio profiles, or model weights from
  the EVA objective.
- Selecting `q` by the objective, or comparing objective values across ranks as if the
  approximation gap were equal.
- Interpreting the inverse EVA Hessian as calibrated frequentist uncertainty. (Gate 5, not this
  clause, is where any future relaxation would be argued; a prohibition that carries its own
  exception licenses itself.)
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

- **Arc-1 coordinate-freeze receipt:** the frozen parameter file (§2.5) exists; its checksum is
  recorded in this contract; the Gate-1 driver reads the applicable fixture fields and restates
  none. `n_it = 1`, `unique = FALSE`, and the excluded data/model shapes are asserted before
  objective construction. The receipt also lists each reused Design-85 apparatus component, its
  source path and commit, the fresh equation-to-code audit, and confirms that no parked Phase-1 VA
  source was copied.
- **Later-runner provenance receipt (required before Gate 2 or Gate 4 is scored, not falsely
  claimed complete by Arc 1):** a byte-identity checksum confirms EVA, the reference, and Laplace
  receive the same ordered response cells, trait IDs, unit IDs, and `X`; realised `z` and `I_unit`
  are reported; and each Gate-2/Gate-4 runner emits an independently checkable source checksum,
  output path, and denominator rule. The two runners must not share a checksum, denominator, or
  output directory.

**NO-GO:** any implicit `Psi`, changed loading transform, missing cell, `n_it != 1`, a parameter
file whose checksum does not match, **a shared runner, denominator, or output directory between
Gate 2 and Gate 4 — or the absence of the provenance records that would show it**, or **parked VA
source copied without a fresh derivation audit**.

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
- **The bound property (§5.3) is derived and its outcome recorded**, either way. A derivation
  already exists and is recorded in §5.3; Gate 1 must reproduce or refute it, not restate it.
- **A numerical marginal probe, labelled a measurement and not a gate.** Evaluate `ell_EVA` against
  a high-order AGHQ **marginal** log-likelihood at `q = 1` on a tiny sparse fixture and record the
  observed signed difference with its quadrature-convergence receipt. §5.3 does **not** predict
  this marginal sign: it signs `ell_EVA - L_exact`, while the unknown posterior-KL slack remains.
  The probe is the only place in the contract where the objective meets a marginal likelihood;
  Gate 3's reference is itself an approximation.

**NO-GO:** clipping needed for finiteness; a wrong KL sign; **omitted constants — including the
`+ q` per unit in the KL term of §5.1**; an inconsistent negative-objective sign; the Gaussian
identity failing; or **the bound question left unresolved**.

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

**"Recovery" is given a number.** Design 85's analogous gate specified tolerances; leaving this one
qualitative would be a regression. On the information-rich cell, with `R = 500` replicates:

- relative bias of the primary `beta` below `0.05`;
- relative bias of every `Sigma_B` diagonal element below `0.10`;
- two-sided 95 % Wald coverage for `beta` within `[0.93, 0.97]` — this cell is information-rich, so
  a correct implementation should be *calibrated* here, and failure to be is an implementation
  defect rather than an approximation limit;
- no planted latent axis collapsing in more than 5 % of replicates.

Unlike Gate 3's tolerances, these are **not** carried over from Design 85 and are not
regime-sensitive in the same way: an information-rich cell is the easy regime, where a correct
implementation should recover cleanly by any reasonable standard. That is what makes fixed numbers
defensible here and placeholders indefensible there.

**NO-GO:** any tolerance above exceeded; reliance on a single start; or a Gate-2 cell that is not
demonstrably information-rich by the reported `I_unit`.

### Gate 3 — EVA versus the reference, at fixed coordinates

Per §9.2, with the same variational family and `(beta, Lambda)` fixed on both arms. Predeclared
tolerances on the SE-relevant quantities: unit-level variational means RMSE below `0.05`; covariance
relative Frobenius error with median below `0.10` and no unit above `0.25`.

> **These three numbers are a Design 85 receipt, and calling them a "fresh predeclaration" does not
> make them one.** They were calibrated in Design 85 §11 Gate 2 against an **AGHQ reference at
> `q <= 2` on non-separated fixtures** — a materially different reference in a materially different
> regime from sparse Bernoulli at the ranks this contract targets. Restating a number is not
> re-deriving it.
>
> **Therefore, binding, and mirroring §7.6's treatment of the optimiser gate: these tolerances must
> be RE-DERIVED against the EVA objective in the sparse regime, and the re-derivation recorded,
> BEFORE Gate 3 is scored.** Until that happens the values above are placeholders carried forward
> for continuity, not predeclarations this contract stands behind. This is the third
> `TO CONFIRM BEFORE APPROVAL` item (see Approval).
>
> This distinction is the whole apparatus-versus-evidence line. Design 85's *machinery* — the
> comparison design, the quantities compared — transfers. Its *calibrated constants* do not, any
> more than its Gate-3 verdict does.

The raw objective difference `L_H - ell_EVA` is **reported as a diagnostic and gates nothing** —
there is no known mapping from an objective discrepancy to a coverage loss.

**NO-GO:** **any SE-relevant quantity exceeding its re-derived tolerance**; scoring Gate 3 against
tolerances that have not been re-derived for this regime; a variational-family mismatch between
arms; a directional/one-sided bound test used in place of the two-sided magnitude comparison; or
dependence of the conclusion on one start.

### Gate 4 — admission

**The ladder.** `n ∈ {100, 260, 600, 1200}` — equal steps in `sqrt(n)`, since a fixed bias relative
to a shrinking standard error scales in `sqrt(n)`. **`n = 260` is a replication anchor against
Korhonen**: the design must reproduce approximately 0.910 EVA coverage there before any
extrapolation from this ladder is believed.

**Replicates.** **`R = 1000` at every rung.** An earlier draft used `R = 200` at the three lower
rungs; that is withdrawn. `MCSE` near `p = 0.90` at `R = 200` is `sqrt(0.9·0.1/200) = 0.0212` —
**larger than the `0.02` margin it was being asked to gate.** At `R = 1000` it is `0.0095`. The
`n = 260` Korhonen replication anchor in particular must run at Korhonen's own `R = 1000`, or the
word "replication" is not earned.

**Both arms, every rung, and the margin is PAIRED.** EVA and Laplace run on byte-identical data with
identical seeds, so each replicate yields a *pair* of covered/not indicators. The margin in (b)
below is therefore a **paired** difference and its uncertainty is McNemar-based —
`MCSE_paired = sqrt(b + c)/R`, with `b` and `c` the discordant counts — **not** the
independent-samples `sqrt(SE_EVA² + SE_Lap²) ≈ 0.0131`. Because the arms share data, their coverage
indicators are strongly positively correlated and the discordant counts are small, so the paired
MCSE is materially smaller than the independent figure. **The design already mandates the pairing;
the analysis must use it.** Reporting an unpaired margin SE understates the design's own power and
is a NO-GO.

**Both arms' convergence gates are frozen, and symmetrically.** §7.6 requires EVA's optimiser gate
to be re-derived, because `ell_EVA` is not a bound with known geometry. **The Laplace arm needs its
own named, frozen convergence-failure criterion, recorded in the same parameter file** — because
criterion (b) is a *paired* margin over Laplace and a failed fit counts as non-covering in both
arms' denominators, so an unstated asymmetry in what counts as a "failed" Laplace fit versus a
"failed" EVA fit would move the margin for a reason having nothing to do with either estimator's
accuracy. The byte-identical data and seeds control the data side of the pairing; this controls the
convergence-gate side. The two criteria need not be numerically identical — Laplace and EVA have
different objective geometries — but each must be predeclared, and any deliberate asymmetry between
them must be stated and justified, not left implicit.

**Denominator.** **All attempted replicates**, for coverage, bias and RMSE alike. A fit failing its
arm's frozen convergence gate counts as **non-covering**. For bias and RMSE the failed-fit
contribution follows a predeclared rule in the frozen file; **the default, absent a stated reason
otherwise, is that bias and RMSE are reported on the all-attempts denominator with failed fits'
point estimates included**, so that a method which fails often cannot post a flattering accuracy
number on a self-selected subset. Attrition is reported per rung per arm. Sparse binary fails more
often at small `n`, so a converged-only denominator would let a flattering "when it converges it is
accurate" narrative ride alongside an honestly denominated coverage number.

**Targets, and the interval is NAMED.** Two-sided 95 % Wald interval coverage for (i) the primary
fixed-effect coefficient and (ii) `Sigma_B`, **both co-equal**.

> **The covariance estimator is part of the claim, not an implementation detail.** Under EVA there
> is no `random=` block, so the naive variational covariance and the corrected one differ
> materially, and §7.8 establishes from `gllvm`'s source that the naive intervals are known to be
> **anti-conservative**. This contract predeclares the **Schur complement of the joint Hessian over
> all coordinates including the variational ones**, `I = A − B D^{-1} B'` followed by a
> pseudo-inverse — the construction `gllvm` uses at `R/se.gllvm.R:201-212`. It is recorded in the
> frozen parameter file (§2.5). A coverage number from an unnamed interval construction does not
> earn the sentence "EVA attains ≥ 0.900 coverage", and no result here transfers to any other
> construction (§13.13).

**THE ADMISSION RULE — and the CUT.**

> **EVA is admitted only if BOTH hold, for `beta` AND for `Sigma_B`:**
>
> **(a) DURABILITY — at `n_max = 1200`, `R = 1000`: coverage is at least `0.900`.**
>
> **(b) USER VALUE — at some rung of the ladder: coverage exceeds the Laplace arm's paired
> coverage by at least `0.02`.**
>
> **The CUT fires if either fails.** Decided on the **point estimate**, with MCSE printed beside it;
> the paired MCSE for (b).

**Why a conjunction, and why the CUT can actually fire** — recorded now so it cannot be re-argued
after a result:

- **Neither half is a gate on its own, and the two failures are mirror images.** A rule biting only
  at the largest `n` tests EVA only where a fixed-order bias must eventually dominate — its verdict
  is a function of where the ladder stops, a dial the designer sets. But a rule satisfiable by *any*
  contiguous region is worse: at the lowest rung `n = 100`, sitting essentially on Korhonen's
  published `n = 120` anchor, **both criteria are already met by about 3 percentage points before a
  single simulation runs** (EVA 0.940 vs Laplace 0.910). That version admits EVA regardless of what
  happens at 600 or 1200 — decided in advance, in the opposite direction. **The conjunction is
  falsifiable precisely because (a) and (b) probe opposite ends of the ladder.**
- **The CUT fires in the expected case.** Korhonen's EVA coverage decays 0.968 → 0.940 → 0.925 →
  0.910 across `n = 50 … 260`. Continued decay past `n = 1200` puts it below `0.900`, failing (a)
  while (b) still passes at small `n`. **That is a GO-shaped result that this rule correctly
  refuses** — and it is the single most likely outcome given the estimator's known behaviour.
- **Laplace and EVA cross.** Korhonen Fig. 3 has Laplace improving while EVA decays; they cross
  between `n = 190` and `n = 260` (a value read from the published figure, not a tabulated number).
  The scientific claim is "better than the incumbent where the incumbent is weak", so (b) must
  measure *that*, at whichever rung it occurs.
- **The floor is defended two-sidedly.** `0.94` is **already breached by Korhonen's published
  `n = 260` result**, so it would pre-decide a NO-GO before any code is written. At the other end:
  nominal error is `0.05`, so coverage `0.900` **doubles** it and coverage `0.85` **triples** it —
  a tripled error rate fails the meaning test outright. Only `0.89–0.92` is informative, and
  `0.900`, the error-rate-doubles line, is the defensible point in it.
- **It is arithmetically decidable where it matters.** At `R = 1000`, `MCSE(0.90) = 0.0095`, so a
  true coverage of `0.87` or below is separated from the `0.900` floor by more than 3 MCSE.
  Resolving `0.91` from `0.90` would need `R ≈ 3300` and is **not** attempted — which is why the
  floor is set well away from the plausible truth rather than adjacent to it.

**THE SECOND LADDER — predeclared, not gestured at.** Because `H_i` does **not** depend on `n`, an
`n`-only design can only confirm that a fixed per-unit error eventually dominates — a foregone
conclusion. The second ladder is therefore **the test of the actual scientific question**, and is
specified here in full rather than left to the runner:

- **`T`-ladder:** `T ∈ {24, 48, 96}` at fixed `n = 600`, `z` at the band midpoint `0.95`, `R = 1000`.
- **`z`-ladder:** `z ∈ {0.90, 0.95, 0.97}` at fixed `n = 600`, `T = 48`, `R = 1000`.
- **Rule:** the admission rule above applies unchanged to every cell of both ladders, with **both
  criteria evaluated in-cell** — (a) durability against the `0.900` floor and (b) the paired margin
  over Laplace are each computed within the single cell, not borrowed from another cell of the
  ladder. (The `n`-ladder's (b) is satisfied "at some rung" because it is one experiment sampled at
  four sample sizes; a second-ladder cell is its own experiment, so "some rung" has no meaning there
  and in-cell is the only coherent reading.) **EVA is admitted only if it satisfies the rule on the
  `n`-ladder AND on a predeclared contiguous majority of each second ladder** — at least two of the
  three cells, including the `z = 0.95` midpoint in the `z`-ladder.
- Every cell reports realised `z`, `I_unit`, and `trace(H_i)/q` alongside coverage, so a failure can
  be attributed to information starvation rather than merely observed.

**NO-GO:** success declared from convergence rate alone; failed fits excluded from any denominator;
**an unpaired margin SE reported for criterion (b)**; **a coverage figure reported without naming
its covariance estimator**; **only one arm's convergence-failure criterion frozen, or an
undocumented asymmetry between the two arms' criteria**; any fitted-`q` quantity in a gate table;
bands widened post hoc; `n_max` chosen by affordability rather than on a stated scientific basis;
or **the second ladder skipped, reduced, or reported after the `n`-ladder verdict has been
formed**.

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
- **Niku, Warton, Hui & Taskinen (2017)**, GLLVMs for multivariate count and biomass data —
  quoted in §1.4 for the quadrature-infeasibility statement. **NOT read directly**; the quotation
  is corpus-sourced and is corroborative, not load-bearing (§1.4 says so in place).
- **The `q >= 4` provenance audit (2026-07-22)** — enumeration of the 66 sources of notebook
  `9b5e85d7-…` plus a citation-required query against it. Establishes **non-retrieval from that
  corpus**, which is the claim's own warrant; it does not and cannot establish non-occurrence in
  the wider literature.
- **The bound-property derivation (adversarial review, 2026-07-22)** — reproduced in full at §5.3.
  It is a derivation recorded in this document, not an external source, and Gate 1 must reproduce
  or refute it rather than cite it.
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
4. **Any likelihood-scale inference** — and, because the bound property is **refuted** in the target
   regime (§5.3), not even a signed statement about the objective's relation to the marginal
   likelihood, nor any comparison of objective values across the EVA, Laplace and `L_H` arms.
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
13. **Any other interval construction.** Coverage is reported for the predeclared covariance
    estimator of §11 Gate 4 — the Schur complement of the joint Hessian — and for that estimator
    only. Nothing transfers to naive variational-covariance intervals, to a sandwich estimator, to
    profile or bootstrap intervals, or to CMSEP-style prediction intervals. §7.8 records that the
    naive construction is known to be anti-conservative, so this is a live distinction with a known
    sign, not a formality.
14. **Any other sparsity, breadth, or information level.** Results are confined to the realised `z`
    band of §2.3, the studied `T`, and the achieved `I_unit`. **The band is a predeclared
    convention, not a cited range** (§2.3 records exactly that), so a pass inside it is not a claim
    about any other sparsity — and in particular not about the `z > 0.97` matrices common in
    large-scale presence–absence data, where §2.4's table shows information per unit falling below
    8 % of balanced.

---

## 14. Roadmap — structured EVA over exact sparse priors

> **NON-BINDING. NOT EVIDENCE. This section predeclares no gate and may not be cited by §11.**
> If this section were deleted, the contract above would still stand. It is recorded because the
> maintainer asked for the direction of travel, not because anything here is approved.

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

**Resolved by the maintainer, 2026-07-22:**

- **§2.3, the zero-fraction band `[0.90, 0.97]`** — CONFIRMED as written, with its status as a
  judgement rather than a cited figure recorded in place.
- **§2.4, the Korhonen calibration** — the requirement is CONFIRMED as written. Performing it is a
  Gate-0 task; the UNQUANTIFIED fallback and its consequence for the `0.900` floor remain binding.

- **§11 Gate 3's tolerances** (`0.05` RMSE; `0.10` median / `0.25` maximum relative Frobenius error)
  — raised as a third precondition by the D-43 scope lens and **CONFIRMED by the maintainer,
  2026-07-22**. They are a Design 85 receipt calibrated against an AGHQ reference at `q <= 2` on
  non-separated fixtures, so they must be **re-derived for the EVA objective in the sparse regime,
  with the re-derivation recorded, before Gate 3 is scored** — mirroring §7.6's treatment of the
  optimiser gate. Until then they are placeholders, not predeclarations. The panel found this had
  been disclosed in prose but neither elevated to precondition status nor named in Gate 3's own
  NO-GO list; both are now corrected.

**Resolved by the maintainer, 2026-07-22 — the Gate-4 admission rule (D-43 falsifiability lens):**

- The single-region rule was **satisfiable at `n = 100` from Korhonen's published numbers before any
  simulation ran**, and is replaced by the **conjunction** in §11 Gate 4: durability at `n_max`
  AND a margin over Laplace somewhere, both for `beta` and for `Sigma_B`. The CUT now fires in the
  most likely case — continued coverage decay past `n = 1200` — which the previous rule would have
  passed. Supporting corrections: `R = 1000` at every rung; the margin computed as a **paired**
  difference exploiting the byte-identical design; the covariance estimator **named**; and the
  second ladder in `T` and `z` **fully specified** rather than gestured at.

**APPROVED by the maintainer, 2026-07-22 (chat).** The three confirmed preconditions above are
resolved as recorded, and the maintainer approved the experimental design and directed that Gate 1
be handed to Codex. What approval carries and what it does not:

- **Carried into the coding lane, not resolved here:** the **bound property is refuted in the target
  regime** (§5.3 — a finding, not a blocker) and the **parameter-file checksum** (§2.5) does not yet
  exist because the frozen file does not exist. **Building and checksumming that file is Gate 0** —
  the coding lane's first action — and the checksum is recorded then. Approval of the *design* does
  not require the file to pre-exist.
- **Scope of the approval:** it unlocks **Gates 0–3** (freeze, algebra, correctness anchor,
  reference comparison). **Gate-4 compute is a separate, later maintainer approval** (Totoro/DRAC);
  nothing here authorises it, and the coding lane must stop at the Gate-3 boundary and return for it.
- **The ledger** (`LOOP/decision-queue.md:10`, still reading `CUT 2026-07-21`) lies outside this
  lane's write fence; correcting it to reflect the approval is a release-lane action, flagged not
  performed.

Compute requires a separate approval **after** the coding reaches the Gate-4 boundary. This approval
is not that.
