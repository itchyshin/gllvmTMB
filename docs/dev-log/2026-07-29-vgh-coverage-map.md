# VGH coverage map — which families and structures are reachable, and at what cost

**2026-07-29 · Claude · carry-forward note for the next arc**

**Why this file exists.** The recorded position is that VA reaches *"4 of 16
families"* and cannot do phylogeny, spatial or missing data — and that this
coverage gap, not speed, is why VA was frozen (2026-07-28 morning brief:
*"Invest in Laplace + AGHQ. Freeze VA where it is."*). That number is **too
pessimistic**, and the reasons are already written down in Designs 104–107, just
never assembled in one place. This note assembles them so the next arc starts
from the real figure.

**Status: MAP, not a claim.** Nothing here is implemented. Provenance is marked
per row: **VERIFIED** = I read the source or measured it; **RELAYED** = stated by
a design doc I have read; **DERIVED** = derived this session, cross-checked.

---

## 1. Families

### 1.1 The general rule

**RELAYED (Designs 104–105), and consistent with everything measured this
session.** One 1-D Gauss-Hermite rule admits **any family whose latent variable
enters through a scalar linear predictor**. The integrand is always
`B(m,s) = E[b(m + sZ)]`; only `b()` changes. There is **no new derivation per
family** — no new bound, no new augmentation, no new quadrature.

Reachable by that single rule:

| family | route |
|---|---|
| nbinom (nbinom1, nbinom2) | GH on the shifted softplus |
| Beta, betabinomial | GH |
| ordinal (probit and logit) | GH — but see §1.4, this is the conditioning-hard case |
| lognormal | GH |
| gamma, inverse-Gaussian | GH, or exact — see §1.2 |
| Tweedie | GH, or exact — see §1.2 |
| binomial logit / cloglog / probit | GH |

Contrast with the incumbent: `gllvm` obtains closed forms by **model
reparameterisation** (Albert–Chib probit augmentation for Bernoulli;
Poisson–Gamma mixture for nbinom), which is why it is *probit-only* for binary
and needs EVA or Laplace elsewhere. **VERIFIED:** `gllvm` 2.0.13's
`src/gllvm.cpp` (5,346 lines) and `R/gllvm.R` contain **zero** occurrences of
`quadrature`, `hermite`, or `ghq`. Hui et al. (2017) explicitly considered the
quadrature route and declined it.

### 1.2 The exact subset — no quadrature at all

**RELAYED + independently derived.** Any family whose `eta`-dependence is a
finite sum of exponentials `sum_k c_k exp(alpha_k eta)` has an **exact** ELBO via
the Gaussian moment generating function,

```
E_q[exp(alpha * eta)] = exp( alpha*m + 0.5*alpha^2*s^2 )
```

so `B`, `B1` and `B2` are all closed form and the quadrature never runs:

* **gaussian** — `b = eta^2/2`, exact directly. **VERIFIED** to 1.26e-12 (the ELBO
  equals the exact marginal log-likelihood).
* **poisson-log** — `E[b] = exp(m + s^2/2)`. **VERIFIED** (implemented, matches TMB).
* **gamma-log** — `E[exp(-eta)] = exp(-m + s^2/2)`.
* **inverse-Gaussian-log**.
* **Tweedie-log** — non-obvious but real: the `eta`-dependent part is
  `( y*exp((1-p)eta)/(1-p) - exp((2-p)eta)/(2-p) ) / phi`, i.e. **two MGF
  evaluations**. The awkward Wright-function normaliser is `eta`-free and drops
  out of the expectation entirely.

**🔴 A hard precondition, easy to trip over.** In the *canonical* parameterisation
`b(theta)` for gamma, inverse-Gaussian and Tweedie (`p` in (1,2)) has a
**restricted domain** `theta < 0`, so `E_q[b(eta)] = +Inf` under any Gaussian `q`
and the ELBO is undefined. **This only works in the log-link / mean
parameterisation.** State it as a precondition, do not discover it at runtime.

### 1.3 The two genuine exceptions

* **delta / hurdle / zero-inflated — needs 2-D quadrature, not impossible.** Two
  linear predictors share `u_i`, so `(eta1, eta2)` is *bivariate* normal under `q`
  and the collapse gives a 2-D integral. Cost `Q^2` instead of `Q` — at `Q = 9`
  that is 81 nodes, entirely feasible. **Not** a structural barrier; a cost.
* **multinomial — CANNOT be done by VA.** Needs a `K-1`-dimensional integral over
  the category contrasts; `log sum_t exp(eta_it)` does not reduce to a scalar
  linear predictor. **RELAYED, and the distinction matters:** mission control is
  explicit that this is *"a VA limit, not an AGHQ one"* — AGHQ quadratures the
  *latent* dimension `q`, which multinomial does not change, so its obstruction
  there is the grouped-softmax evaluation contract instead. Different families of
  reason; do not conflate them.

### 1.4 Where the quadrature itself gets hard

**RELAYED (adversarial review, not yet measured here).** Gauss-Hermite converges
geometrically at a rate set by the distance from the real axis to the nearest
complex singularity of `b`, divided by `s`. So:

* logit: singularities at `eta = i*pi*(2k+1)`, distance `pi` — fine for `s <~ 1`,
  degrades as `s -> pi`;
* nbinom: same distance but *shifted* to `log k + i*pi` — worse for small `k`;
* probit: `log Phi(eta) ~ -eta^2/2` in the left tail, nearly polynomial —
  **better** than logit;
* **ordinal**: `log(Phi(tau_c - eta) - Phi(tau_{c-1} - eta))` has zeros close to
  the real axis when a category is narrow. **This is where GH dies**, and it is
  the one to test first.

**MEASURED this session, and it cuts against intuition:** for binomial-logit the
quadrature order does **not** affect recovery at all — `Q` in {9,15,21,31} gives
relative error 0.2738 and attenuation 0.9908 identical to four decimals, with
only cost changing (2.37 s vs 6.11 s). **Use `Q = 9` until an ordinal case proves
otherwise.**

### 1.5 The honest count

**13–14 of 16, not 4** — with multinomial genuinely out and delta/hurdle costing
`Q^2`. The gap is a *derivation-and-wiring* gap, not a conceptual one. Mission
control already says as much: *"Most of the gap is not conceptual: one 1-D
Gauss–Hermite rule admits any family whose latent variable enters through a
scalar linear predictor."*

---

## 2. Structure

### 2.1 Multiple tiers, random slopes — free

**RELAYED, Design 106 Proposition 1, proved there.** `mu` and `v` simply
*accumulate* across tiers:

```
mu_o = x_o'beta + sum_k a_{k,o}' m_{k,g_k(o)}
v_o  = sum_k a_{k,o}' S_{k,g_k(o)} a_{k,o}
```

because a linear combination of independent Gaussians is Gaussian. Design 106
calls it *"textbook algebra, not a design choice"* and concludes *"the entire
quadrature layer is untouched."* Every family admitted at one tier is
**automatically** admitted at any number of tiers. Random slopes are just
`a_o = (1, x_o)'` — *"there is no new algebra in the slope extension."*

### 2.2 Phylogeny, animal, kernel, pedigree — reachable

**DERIVED this session** (see `docs/dev-log/2026-07-29-vgh-structured-stationarity.md`
for the full derivation and cross-checks). With a structured prior precision
`Q_p`, the variational-covariance stationarity condition is

```
S_g^{-1} = Q_gg + sum_{o in g} w_o a_o a_o'
```

**Only the diagonal block `Q_gg` enters.** It stays a small per-level solve — no
joint `(n*d) x (n*d)` inversion, no Takahashi selected inversion. Two
cross-checks: it reduces *verbatim* to the iid form at `Q_p = I`, and for a
standardized phylo field it becomes `[A^-1]_gg * I_C + data curvature`, consuming
exactly `diag(A^-1)` — the same `n`-vector Design 106 §3.3 identifies by a
completely different route (the trace collapse).

**What it costs — bound tightness, not correctness.** A level-factorised `q`
forces zero posterior correlation between every parent and child, *"which is
precisely the correlation the tree encodes"*. Design 106 titles that section
*"the uncomfortable part: a level-factorised `q` fights the structure"* and gives
a falsifiable prediction: the augmented-node ELBO should sit further below the
marginal log-likelihood than the tips-only one. **Test that prediction first.**

**What erodes — the mean does NOT decouple.** `sum_h Q_gh m_h` pulls in the full
row of `Q`, so the free per-unit Newton step becomes a coupled sparse system.
Cost is modest and already priced by Design 106 as an `O(nnz)` sparse matvec,
machinery in use today at `src/gllvmTMB.cpp:728, 1038, 1285`.

**A sizing trap:** `phylo_*` levels are **augmented tree nodes, not species**, so
`n_aug ~ 2N-1`. The phylo tier costs roughly **twice** what the species count
suggests, *"and it is invisible from the model formula."*

### 2.3 Spatial — stays hard, and this is a reversal

**RELAYED, Design 106.** Two independent problems:

1. The SPDE projection `A_proj` spans **~3 mesh nodes**, so a node-factorised `q`
   *"both loosens the bound and mis-states `v` for every single observation."* It
   is the only tier that fails **both** conditions of Proposition 2 at once.
2. `kappa` is estimated, so `logdet(Q(kappa))` must be recomputed every
   evaluation via a sparse Cholesky — *"the only genuine log-determinant cost in
   the whole structural extension."* Note Design 106's fair caveat: VA does not
   *introduce* this; the Laplace engine already pays it.

The structurally-correct fix — a variational precision sharing `Q`'s sparsity —
**loses the closed form** and needs a differentiable partial inverse (Takahashi).
Design 106: *"TMB performs such partial inverses internally (`sdreport`), but I
have not verified that a differentiable partial inverse is usable from inside a
template. Treat this as an open engineering question, not a plan."*

**This reverses Design 72**, which called spatial *"likely the EASIEST structured
VA win"* on the grounds of code reuse. On per-evaluation cost and approximation
quality, **phylo is strictly the easier case.**

### 2.4 Missing data — Design 107 argues it is nearly free

**RELAYED, NOT VERIFIED by me.** The KL term is **per-unit, not per-cell**, so
introducing a missingness indicator leaves it bit-for-bit identical; the data sum
simply drops the missing cells. If that holds it is exact and cheap — which
matters, because mission control calls missing data *"the one gap that blocks
real datasets outright today."* **Verify before relying on it.**

---

## 3. What is NOT fixable by engineering

| item | why |
|---|---|
| **multinomial under VA** | Structural — needs a `K-1`-dim integral (§1.3) |
| **model selection from the ELBO** | The ELBO is a *bound*; a better bound does not mean a better marginal fit. Design 85 §10 prohibits selecting `q` by ELBO. Fixable only by evaluating the true marginal likelihood at the VA optimum with AGHQ — i.e. by borrowing the other engine |
| **spatial done properly** | Open engineering question (§2.3) |
| **"is it a better estimate?"** | Not a coverage question at all. Design 102's 2,304 attempts measured loading-covariance relative error 0.67–3.36 for sparse binary. Fixing coverage makes VA *available*, not *preferable* |

**Intervals are a package-wide gap, not a VA-specific one.** Nothing in gllvmTMB
has certified coverage — the shipped Laplace default covers **0.023 at n = 1600**
with large loadings. VA's measured profile-style SEs (0.935–0.950) are not
obviously worse than what ships.

---

## 4. Why this changes the plan less than it might seem

The hand-off architecture (VGH approaches, Laplace/AGHQ finishes, **Laplace's
estimate is reported**) makes coverage **non-binding**. You get value in
proportion to whatever coverage exists, on the families already covered, and can
extend one family at a time without ever needing parity. A family VGH lacks
cannot hurt you — you simply do not warm-start there.

So this map is a **roadmap for later phases**, not a prerequisite for Phase 0–3.
Design 108 prices full parity at 26–42 working days; the plan in
`2026-07-29-vgh-implementation-plan.md` deliberately does not spend them.

---

## 5. First three things to do when this arc resumes

1. **Test Design 106's falsifiable prediction** (§2.2): does the augmented-node
   ELBO sit further below the marginal log-likelihood than the tips-only one? That
   measures the phylo mean-field cost before any code is written for it.
2. **Try ordinal before any other new family** (§1.4). It is the predicted
   quadrature-conditioning failure. If GH survives ordinal, the family map is
   safe; if it does not, the map needs a caveat exactly there.
3. **Verify the Design 107 missing-data claim** (§2.4) rather than relaying it.
   It is the single highest-value item on this map if true, because it is the one
   gap that blocks real datasets outright.
