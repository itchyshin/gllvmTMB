# Design 106 — VA structural extension: many tiers, slopes, structured priors

**Status:** design, internal-research only. Authorises no export, no `method=`
argument, no public capability claim. No code, no `R/`, no `src/`, no
`inst/tmb/` change is implied by this document.

**Scope.** [Design 104](104-va-family-coverage.md) fixed the *family* axis: every
family sees the latent variable only through a scalar `eta_ij ~ N(mu_ij, v_ij)`,
so one 1-D Gauss-Hermite rule covers the whole family surface.
[Design 105](105-va-family-densities.md) discharged that promise family by family.
This document does the orthogonal axis — the **structural** surface Laplace
already has: several random-intercept tiers (`unit`, `unit_obs`, `cluster`,
`cluster2`), random slopes, and structured priors (phylogenetic `A^-1`, spatial
SPDE `Q`).

**Inherited and not re-derived here** (established and measured 2026-07-26):

* the ELBO uses a per-unit full-covariance Gaussian `q(u_i) = N(m_i, S_i)`,
  `S_i = L_i L_i'`;
* the variational coordinates are **ordinary TMB parameters**, not `random=`
  (Design 72 §2) — so there is **one joint outer optimisation**, and this fact does
  real work in §3.4 and §4.3;
* `mu_ij = x_ij' beta + lambda_j' m_i`, `v_ij = || L_i' lambda_j ||^2`;
* Poisson and Gaussian are EXACT, binomial needs GH, EVA is a 2nd-order Taylor
  surrogate, default `H = 15`;
* per-unit KL against `N(0, I_q)` is
  `0.5*(tr(S_i) + m_i'm_i - logdet(S_i) - q)`;
* Design 105's breakages (multinomial; zero-inflated / `*_mix` with separate
  component predictors) are **family** obstructions. Nothing below repairs them
  and nothing below makes them worse — see §6.3;
* measured: GH-VA loses to `gllvm`'s JJ/EVA on Bernoulli, but **scales better
  than Laplace on Poisson as species count grows** (1.38 -> 2.07 over p=8/20/40).
  VA's demonstrated strength is Poisson-at-scale, which is exactly the regime
  §4 costs out.

**Headline result.** The Design 104 architecture survives the structural
extension **intact**. `eta` stays univariate Gaussian; `mu` and `v` simply
*accumulate* across tiers; the entire quadrature layer is untouched. All the new
work sits in the KL term, and only for structured priors.

---

## 0. Notation

An observation `o` has response `y_o`, trait `j(o)`, and — in each tier `k` — a
grouping index `g_k(o)`. Write

```
eta_o = x_o' beta + sum_{k=1..K} a_{k,o}' u_{k, g_k(o)}
```

where `u_{k,g}` is tier `k`'s latent block for level `g` (dimension `d_k`) and
`a_{k,o}` is the **known** loading vector that observation `o` applies to it.
Every tier gllvmTMB has is an instance of this one form:

| Tier | Levels `g` | `d_k` | `a_{k,o}` |
|---|---|---|---|
| `latent(1 \| unit, d=q)` | units | `q` | `lambda_{j(o)}` (trait loading) |
| `latent(0 + trait \| unit_obs)` | unit_obs levels | `q` | `lambda^{uo}_{j(o)}` |
| `unique()` / `indep()` (per-trait diagonal) | levels | `T` | `sd_{j(o)} * e_{j(o)}` |
| `cluster`, `cluster2` (diagonal) | cluster levels | `T` | `sd^{(c)}_{j(o)} * e_{j(o)}` |
| `scalar()` | levels | `1` | `sd` |
| `phylo_latent(d=d_phy)` | **augmented** nodes | `d_phy` | `lambda^{phy}_{j(o)}` |
| `phylo_unique` | augmented nodes | `T` | `sd^{phy}_{j(o)} * e_{j(o)}` |
| spatial SPDE (per-trait) | mesh nodes | `T` | `tau_j^{-1} * A_proj[o, .] (x) e_{j(o)}` |

Two entries in that table are load-bearing and non-obvious:

1. **`phylo_*` levels are augmented tree nodes, not species.** `n_aug_phy =
   nrow(Ainv)` (`R/fit-multi.R:3016`), and on the `phylo_tree` route that
   precision carries internal nodes as well as tips. §4.2 prices this.
2. **The SPDE loading is supported on ~3 mesh nodes, not one.** `A_proj` is the
   barycentric projection; one observation loads on the vertices of its
   triangle. This single fact is why spatial is the *hardest* of the three
   extensions, not the easiest — §3.6 and §5.

The variational family (the default; restrictions are §4):

```
q(u) = prod_k prod_g N( m_{k,g}, S_{k,g} ),   S_{k,g} = L_{k,g} L_{k,g}'
```

i.e. **Gaussian, factorised across tiers and across levels within a tier**, with
a full `d_k x d_k` covariance per level.

---

## 1. Multiple tiers: `mu` and `v` accumulate

### 1.1 The proposition

**Proposition 1 (tier accumulation).** Under the model and variational family of
§0, `eta_o` is univariate Gaussian with

```
mu_o = x_o' beta + sum_{k=1..K} a_{k,o}' m_{k, g_k(o)}

v_o  = sum_{k=1..K} a_{k,o}' S_{k, g_k(o)} a_{k,o}
     = sum_{k=1..K} || L_{k, g_k(o)}' a_{k,o} ||^2
```

*Proof.* `eta_o` is a fixed offset plus a linear combination of `K` independent
Gaussian vectors. A linear combination of independent Gaussians is Gaussian;
means add; variances add because the covariances are zero. ∎

This is **textbook algebra**, not a design choice. The design choices are the
*shape of `q`* (Gaussian; factorised) and the *parameterisation* (`L` Cholesky).

### 1.2 What this buys

The ELBO's data term is
`sum_o E_q[ log p(y_o | eta_o) ]`, and it depends on `q` **only through
`(mu_o, v_o)`** — one univariate marginal per observation, never a joint. So:

* every family admitted by Design 105 is **automatically** admitted at any
  number of tiers, with no new derivation, no new integrand, no new quadrature;
* the EXACT routes stay exact — Poisson keeps `E[exp(eta)] = exp(mu + v/2)` and
  Gaussian keeps its closed form, with the *accumulated* `v` substituted in;
* the only code change in the data path is that `mu` and `v` are built by a loop
  over tiers instead of a single term.

The KL likewise decomposes:

```
KL(q || p) = sum_k sum_g KL( N(m_{k,g}, S_{k,g}) || p_{k,g} )
```

**provided the prior also factorises across tiers and across levels within a
tier.** It does across tiers (the tiers are a priori independent by
construction). It does *not* across levels within a **structured** tier — that
is the whole of §3.

### 1.3 The exact condition, and what breaks without it

Proposition 1 needs `Cov_q(u_{k,g}, u_{l,h}) = 0` for `(k,g) != (l,h)`.

If `q` is instead a **joint** Gaussian with non-zero cross blocks
`C_{kl} = Cov_q(u_k, u_l)`, then:

* **`eta` is still univariate Gaussian.** Joint Gaussianity alone suffices; the
  factorisation is not needed for that. `mu_o` is also unchanged.
* **`v` stops being a sum.** It becomes

```
v_o = sum_k a_{k,o}' S_{k} a_{k,o}  +  2 * sum_{k<l} a_{k,o}' C_{kl} a_{l,o}
```

  so the accumulation loop must carry, store, and differentiate the cross
  blocks.
* **The KL stops decomposing.** With a block-diagonal *prior* but a full `q`,
  the trace and quadratic terms still split per tier, but `logdet(S)` does not.

So the precise statement is: **factorisation across tiers is not needed for the
1-D architecture; it is needed for the *additive* accumulation of `v` and for
the additive KL.** That is a cost/accuracy trade, not a correctness boundary —
and §4.4 argues one specific cross-tier block is worth paying for.

### 1.4 The criterion that says which zero blocks are free

Not every zero block in `S` is an approximation. Some are exactly optimal.

**Proposition 2 (loading-support criterion).** Partition the stacked latent
vector `u` into groups `G_1, ..., G_B`. Suppose

  (i) every observation's loading vector `a_o` is supported inside a **single**
      group; and
  (ii) the prior precision `Q_p` is block-diagonal with respect to the same
      partition.

Then the ELBO, maximised over all Gaussian `q`, attains its maximum at a `q`
whose covariance `S` is block-diagonal with respect to the partition.
**Restricting `q` to that block-diagonal form loses nothing.**

*Proof.* By (i), `v_o = a_o' S a_o = a_o' S_{bb} a_o` for the one group `b`
containing `a_o`'s support, so the data term does not involve the off-diagonal
blocks of `S`. By (ii), `tr(Q_p S) = sum_b tr(Q_{p,bb} S_{bb})`, and `m' Q_p m`
does not involve `S` at all. The only remaining `S`-dependence in the KL is
`-logdet(S)`, and Fischer's inequality gives `det(S) <= prod_b det(S_{bb})` for
positive-definite `S`, with equality iff the off-diagonal blocks vanish. Since
the KL enters the ELBO with a minus sign and contains `-logdet(S)`, the ELBO is
maximised by maximising `logdet(S)` at fixed diagonal blocks — i.e. at
block-diagonal `S`. ∎

Fischer's inequality is textbook; the application is the design content. The
criterion is sharp and it answers, per block, "spend parameters here or not":

| Block | (i) support | (ii) prior | Verdict |
|---|---|---|---|
| Across traits within a `unique`/`indep`/`cluster`/`phylo_unique` tier | holds — each observation loads on **one** trait's field | holds — traits a priori independent, `diag(sd^2) (x) A` | **zero is EXACT.** Costs nothing. |
| Across the `q` latent coordinates within a `latent` tier | **fails** — `lambda_j` has all `q` entries non-zero | holds | zero is a real restriction (§4.3) |
| Across two tiers | **fails** — both tiers contribute to the same `eta_o` | holds | zero is a real restriction (§1.3, §4.4) |
| Across mesh nodes in an SPDE tier | **fails** — `A_proj` spans ~3 nodes | **fails** — `Q` couples neighbours | zero is a *severe* restriction (§3.6) |

Row 1 is worth its own line in the cost table: a `phylo_unique` tier at `T = 26`
costs `2T = 52` variational numbers per level, not `T + T(T+1)/2 = 377`, and
that reduction is **free** rather than approximate. §4.2 shows it is the
difference between 2.0 million and 0.28 million coordinates in Ayumi's model.

---

## 2. Random slopes

### 2.1 The contribution

A slope tier is Proposition 1 with an **observation-dependent** loading. For a
correlated random intercept + slope on covariate `x` at grouping factor `g`,
the level block is `u_g = (b_{g,0}, b_{g,1})'` and

```
a_o = (1, x_o)'
```

Hence

```
mu_o += m_{g,0} + x_o * m_{g,1}

v_o  += S_{g,00} + 2 * x_o * S_{g,01} + x_o^2 * S_{g,11}
      = || L_g' (1, x_o)' ||^2
```

`eta_o` remains scalar and Gaussian — it is still a linear functional of a
Gaussian vector. Nothing in the family surface changes.

### 2.2 The cross term, precisely

**Yes, `v` picks up a cross term, and it is `2 * x_o * S_{g,01}`**, with
`S_{g,01} = Cov_q(b_{g,0}, b_{g,1})`.

Three points that are easy to get wrong:

1. **The cross term comes from `q`, not from the prior.** It is present whenever
   the *variational* `2x2` block is unstructured, whether or not the prior
   correlates intercept and slope. Prior correlation appears only in the KL
   (`Q_p` is then a `2x2` inverse of the unstructured within-tier covariance,
   Kronecker'd over levels).
2. **It falls out of the existing kernel for free.** The template already
   computes `|| L_i' lambda_j ||^2`; substituting `a_o = (1, x_o)'` for
   `lambda_j` produces the cross term automatically. There is **no new algebra**
   in the slope extension — only the supply of `a_o` and the level index.
3. **Dropping it (mean-field within the tier) is scale-dependent.** With
   diagonal `S_g`, `v` loses `2 x_o S_{g,01}`. Since the posterior intercept–
   slope covariance is a function of where `x = 0` sits, an *uncentred* `x`
   makes `|S_{g,01}|` large and the omission correspondingly bad. **Centring `x`
   shrinks the term you are dropping** — but does not remove it, and does not
   remove it uniformly across levels in unbalanced data. Recommendation: keep
   the full `2x2` block (it costs one extra number per level) rather than rely
   on centring.

### 2.3 Match the Laplace surface, do not exceed it

Design 04 caps the shipped surface at **one ordinary random slope**, with the
augmented `(intercept, slope) x trait` LHS grammar of Designs 55/56/60. The VA
slope target should be that same cell — parity, not overreach. For `s` slopes
the algebra above generalises verbatim with `a_o = (1, x_{1o}, ..., x_{so})'`
and `d_k = s + 1`; the cost is §4's formula, which grows quadratically in
`d_k`. There is no derivation obstacle to `s > 1` in VA; there is a *policy*
obstacle, and it belongs to Design 04, not here.

---

## 3. Structured priors (phylogenetic `A^-1`, spatial SPDE `Q`)

Here the prior for a tier is `u ~ N(0, Sigma_struct)` with `Sigma_struct` not
proportional to the identity, and the whole point is that we hold its **inverse**
sparsely and must never touch `Sigma_struct` itself.

### 3.1 The general KL

For prior `N(0, Sigma_p)` with precision `Q_p = Sigma_p^{-1}` on a vector of
dimension `n`, and `q = N(m, S)`:

```
KL( N(m,S) || N(0, Sigma_p) )
    = 0.5 * [ tr(Q_p S) + m' Q_p m - n - logdet(S) - logdet(Q_p) ]
```

Textbook. This is Design 72 §3.1 with `logdet(Q_p S)` expanded into
`logdet(S) + logdet(Q_p)`, which is the form that makes §3.4 decidable. Four
quantities are needed and **`Sigma_p` is not one of them**:

| Quantity | Depends on | Notes |
|---|---|---|
| `m' Q_p m` | `m`, `Q_p` | sparse quadratic form |
| `tr(Q_p S)` | `S`, `Q_p` | see §3.3 — **only `diag(Q_p)` is needed** |
| `logdet(S)` | `S` | free from the Cholesky parameterisation |
| `logdet(Q_p)` | `Q_p` only | constant in the variational coordinates; see §3.4 |

### 3.2 The engine's standardized-field convention makes this cleaner than expected

`src/gllvmTMB.cpp` does **not** write the phylo prior as `u ~ N(0, sd^2 A)`. It
uses a unit-scale field with the scale moved into the linear predictor
(the "STANDARDIZED-field convention", `src/gllvmTMB.cpp:710-730`):

```
g ~ N(0, A),          eta += sd * g[node(o)]
-log p(g) = 0.5 * ( n_aug*log(2pi) + log_det_A_phy_rr + g' Ainv g )
```

The two conventions are **exactly equivalent** as variational problems: putting
`m' = sd*m`, `S' = sd^2 S` maps one ELBO onto the other, and KL is invariant
under a common linear map applied to `q` and `p`. So adopting the engine's
convention costs nothing and buys a real simplification:

> **Under the standardized-field convention the phylogenetic/kernel KL contains
> no model hyperparameters at all.** `Q_p = A^{-1}` is pure DATA; the scale `sd`
> lives in `a_o` and therefore in `mu` and `v`, where quadrature already handles
> it.

That is the cleanest possible arrangement, and it is already how the shipped
engine is written. Adopt it; do not reinvent a `sd^2 A` prior for VA.

### 3.3 The trace term needs only the diagonal of the precision

Let a structured tier hold an `n x C` array `U` (rows = levels/nodes,
columns = traits or latent coordinates) with matrix-normal prior
`Cov(vec U) = Sigma_c (x) A`, and let `q` factorise across **rows**, row `g`
being `N(m_g, S_g)` with `S_g` of size `C x C`. Then

```
tr( (Sigma_c^{-1} (x) A^{-1}) S ) = sum_g [A^{-1}]_{gg} * tr( Sigma_c^{-1} S_g )
```

*Derivation.* Write `S`'s `(c,c')` block as `diag_g( S_g[c,c'] )`. Then
`tr(Q_p S) = sum_{c,c'} [Sigma_c^{-1}]_{cc'} tr(A^{-1} diag_g(S_g[c',c]))
= sum_{c,c'} [Sigma_c^{-1}]_{cc'} sum_g [A^{-1}]_{gg} S_g[c',c]`, and collecting
on `g` gives the stated form by symmetry of `S_g`. ∎

**Consequence: with a level-factorised `q`, the trace term never performs a
sparse matrix product.** It needs `diag(A^{-1})` — an `n`-vector — and a
`C x C` trace per level. Cost `O(n C^2)`, no linear algebra, trivially
differentiable. For the common `Sigma_c = I` (standardized field) it collapses
further to `sum_g [A^{-1}]_{gg} * tr(S_g)`.

For the SPDE the same identity applies with `A^{-1} -> Q(kappa)`, and even the
parameter dependence stays closed form:

```
diag(Q) = kappa^4 * diag(M0) + 2*kappa^2 * diag(M1) + diag(M2)
```

so passing **three diagonal `DATA_VECTOR`s** gives the trace term exactly, with
exact AD in `kappa`, and still no sparse machinery.

### 3.4 The log-determinant: is it the bottleneck? Mostly no — with one exception

`logdet(Q_p)` **is constant in the variational coordinates `(m, L)` always** —
it contains neither. So under a hypothetical inner optimisation over `q` alone
it could be dropped outright.

But Design 72 §2 makes the variational coordinates **ordinary parameters**, so
there is a single joint optimisation over `(beta, Lambda, sd, kappa, m, L)`.
The rule is therefore sharper than "constant, drop it":

| Tier | `logdet(Q_p)` | Constant in **all** parameters? | Verdict |
|---|---|---|---|
| phylo / animal / kernel, standardized field | `-logdet(A)`, already precomputed as `DATA_SCALAR log_det_A_phy_rr` | **Yes** (fixed tree/pedigree) | Droppable — but it is one scalar. **Keep it**, so the ELBO sits on the same absolute scale as the Laplace objective and the sign check of Design 104 §7 stays meaningful. |
| `meta_V` (known `V`) | `-logdet(V)`, data | Yes | same |
| SPDE | `logdet(Q(kappa))` | **No** — `kappa` is estimated (`PARAMETER(log_kappa_spde)`, `src/gllvmTMB.cpp:541`) | **Must be recomputed every evaluation**, via a sparse Cholesky of an `n_mesh x n_mesh` matrix. |

**So the only genuine log-determinant cost in the whole structural extension is
the SPDE one — and VA does not introduce it.** The Laplace engine already pays
exactly that cost through `density::GMRF(Q)`
(`src/gllvmTMB.cpp:1445-1449, 1686-1690`). VA inherits it unchanged.

`logdet(S)` is never a bottleneck: `S` is block-diagonal by construction and
Cholesky-parameterised, so `logdet(S) = 2 * sum_g sum_c log L_g[c,c]`, already
in the template.

### 3.5 What TMB supplies cheaply, and the one identity to use

| Quantity | Form | TMB facility | Cost |
|---|---|---|---|
| `m' Q_p m` | sparse quadratic | `DATA_SPARSE_MATRIX` product — already used at `src/gllvmTMB.cpp:728, 1038, 1285` | `O(nnz)`, exact AD |
| `tr(Q_p S)` | `sum_g Q_{gg} tr(Sigma_c^{-1} S_g)` | `DATA_VECTOR` of `diag(Q_p)` (phylo) or 3 diagonals + `kappa` (SPDE) | `O(n C^2)`, no matmul |
| `logdet(S)` | `2 sum log L_gg` | already in the VA template | `O(nC)` |
| `logdet(Q_p)` | data scalar (phylo) / `density::GMRF` (SPDE) | `DATA_SCALAR log_det_A_phy_rr` / existing GMRF object | `O(1)` / sparse Cholesky |

Two practical notes.

**(a) The quadratic form already exists in the Laplace engine.** The block at
`src/gllvmTMB.cpp:1285-1294`

```cpp
matrix<Type> AinvB = Ainv_phy_rr * Bmat;
matrix<Type> Q     = Bmat.transpose() * AinvB;
// ... + tr(Sigma_b^{-1} Q) ...
```

is *exactly* the KL's quadratic term with `Bmat` replaced by the variational
mean matrix `M`. **The VA structured KL = the Laplace prior block evaluated at
`m`, plus a trace term and `logdet(S)`.** That is the single most useful
implementation identity in this document: the risky part is already written and
tested.

**(b) For the SPDE, one `GMRF` call supplies two of the four terms.**
`density::GMRF(Q)(m)` returns the negative log density
`0.5 m'Qm - 0.5 logdet(Q) + (n/2) log 2pi`, so

```
KL = GMRF(Q)(m) + 0.5*( tr(Q S) - n - logdet(S) ) - (n/2)*log(2pi)
```

*Caveat, must be verified against the TMB source before use:* the exact
normalising-constant convention of `GMRF_t::operator()` (and whether the
normalisation flag is set) determines the trailing constant. The engine
currently writes its phylo priors out explicitly rather than through `GMRF`;
for phylo, follow that existing explicit style and reserve the `GMRF` identity
for the SPDE path, where the object already exists.

### 3.6 The uncomfortable part: a level-factorised `q` fights the structure

Everything above assumed `q` factorises across levels/nodes. That assumption is
cheap and it is what makes §3.3's trace collapse. It is also, on its face, in
tension with the reason the structured prior exists.

* **Phylogenetic, augmented route.** `Ainv` from the tree is sparse *because*
  the augmented representation introduces conditionally-independent innovations
  along edges. A `q` that factorises across augmented nodes forces zero
  posterior correlation between every parent and child — which is precisely the
  correlation the tree encodes. Proposition 2 does **not** rescue this: internal
  nodes carry no data, but they are coupled to their children through `Q_p`'s
  off-diagonals, so condition (ii) fails.
* **Phylogenetic, tips-only route.** The legacy dense path
  (`R/fit-multi.R:3068`) sets `n_aug_phy = n_species` and holds a dense
  `A^{-1}`. A tip-factorised `q` there is *also* an approximation, but a
  different one: it drops tip–tip posterior correlation directly rather than
  paying a mean-field penalty on every internal edge.
* **Spatial SPDE.** Worst case. An observation loads on ~3 mesh nodes
  simultaneously (`A_proj`), so a node-factorised `q` both loosens the bound
  *and* mis-states `v` for every single observation. Here the structurally
  matched choice is a **variational precision `S^{-1}` sharing `Q`'s sparsity
  pattern** — and note that the three nodes of a triangle are mutually adjacent
  in the mesh graph, so `Q`'s pattern contains exactly the blocks `v` needs.
  That is elegant, and it is expensive: `logdet(S)` then requires a sparse
  Cholesky per evaluation, and both `tr(Q S)` and `v` require entries of `S` at
  `Q`'s pattern, i.e. a **sparse inverse subset** (Takahashi recursions).
  *Uncertain:* TMB performs such partial inverses internally (`sdreport`), but I
  have **not verified** that a differentiable partial inverse is usable from
  inside a template. Treat this as an open engineering question, not a plan.

**This reverses one line of Design 72.** Design 72 §3.3 called spatial "likely
the EASIEST structured VA win" because TMB's GMRF machinery is already in the
template. That reasoning weighs *code reuse*, and on that axis it is right. On
the two axes that decide whether the answer is any good — per-evaluation cost
(§3.4: SPDE is the only recurring logdet) and approximation quality (§3.6: the
`A_proj` multi-node loading) — **phylo is strictly the easier case.** The two
statements are compatible; the ranking in §5 states which axis is being used.

**Falsifiable prediction (augmented vs tips-only).** At equal tip-level
variational flexibility, the augmented-node factorised ELBO should sit
*further below* the marginal log-likelihood than the tips-only factorised ELBO,
because the mean-field penalty is paid on every internal edge of the tree rather
than only between tips. Testable on a small tree where both routes are
affordable, comparing both ELBOs to a common Laplace reference. **Standing
caution (Design 104 §3):** that comparison is legitimate only because it is the
*same model on the same data* with two variational families; it licenses no
model or rank selection, and neither ELBO may legitimately exceed the Laplace
value.

---

## 4. The variational cost

### 4.1 The formula

Per level of tier `k` with variational block dimension `d_k`: `d_k` means plus
`d_k(d_k+1)/2` Cholesky entries. Over `K` tiers with `n_k` levels:

```
P_var = sum_{k=1..K}  n_k * ( d_k + d_k(d_k+1)/2 )
```

For a single tier this is the `N*(q + q(q+1)/2)` of the brief, and the same
number as Design 104 §4's `N*(2q + q(q-1)/2)` — the template's actual layout is
`m` (`N x q`), `log_L_diag` (`N x q`), `L_off` (`N x q(q-1)/2`).

Restricted families:

| Family | Per level | At `q=2` | At `T=26` |
|---|---|---|---|
| Full `S_g` | `d + d(d+1)/2` | 5 | 377 |
| Mean-field (diagonal `S_g`) | `2d` | 4 | 52 |
| Low-rank `S_g = D_g + W_g W_g'`, rank `r` | `d(2 + r)` | 6 (r=1) | 130 (r=3) |

Read the `q=2` column carefully: **mean-field saves one number per level and
low-rank costs more than full.** At `q = 2` the "scalable" families are not
scalable — they are noise.

### 4.2 Ayumi's case

`N = 5397` species, `q = 2`, two tiers (ordinary + phylogenetic), `T = 26`
responses (BIRDBASE; `docs/dev-log/2026-07-24-performance-audit-plan.md`).

**Base arithmetic, as posed (two rank-2 tiers, tips-only phylo):**

```
ordinary latent tier : 5397 * (2 + 3) = 26,985
phylo   latent tier  : 5397 * (2 + 3) = 26,985
                                        -------
TOTAL                                    53,970 variational coordinates
```

**With the augmented tree route** (`phylo_tree` -> `Ainv` including internal
nodes; a rooted bifurcating tree gives `n_aug ~ 2N - 1 = 10,793` — verify
against `nrow(Ainv)` for the actual tree):

```
ordinary : 5397  * 5 = 26,985
phylo    : 10793 * 5 = 53,965
                       ------
TOTAL                  80,950
```

The phylo tier costs **twice** what the species count suggests. This is a direct
consequence of the augmented representation and it is invisible from the model
formula.

**If the model is the realistic `phylo_latent(unique = TRUE)`** — structured
low-rank **plus** a diagonal `Psi` (the standing guard in `CLAUDE.md`; the
engine's `g_phy_diag` is `n_aug_phy x n_traits`, `R/fit-multi.R:3711`) — a third
tier of dimension `T = 26` per level appears:

| `Psi` tier treatment | Per level | Tips-only | Augmented |
|---|---|---|---|
| Naive full `T x T` block | 377 | 2,034,669 | 4,068,961 |
| **Trait-diagonal (EXACT by Prop. 2)** | 52 | **280,644** | **561,236** |

Proposition 2 applies exactly here — each observation loads on one trait's
field, and the `Psi` prior is trait-independent — so the trait-diagonal `q` is
**not** an approximation. It is a 7.25x reduction bought with a proof rather
than an assumption. This is the single largest cost lever in the model, and it
costs no accuracy at all.

For orientation on the data term: `5397 * 26 = 140,322` observations, so at
`H = 15` each ELBO evaluation performs about `2.1 x 10^6` integrand
evaluations — large but linear, and the regime where GH-VA was measured to
scale better than Laplace.

### 4.3 Is mean-field or low-rank NECESSARY at that scale? No — and both are
### the wrong economy

**Mean-field (diagonal `S_i`): not necessary, and not advisable.**
At `q = 2` it saves `1` number per level — 20% of the tier's variational
coordinates, `10,794` of `53,970`. What it gives up is `S_{i,12}`, which enters
every single observation through

```
v_ij = lambda_{j1}^2 S_{i,11} + 2 lambda_{j1} lambda_{j2} S_{i,12}
       + lambda_{j2}^2 S_{i,22}
```

and the loadings are not orthogonal in general, so the omitted term is
first-order, not a rounding correction. The known direction of VB error is
**downward bias in variance components** (mean-field ignores posterior
correlation, shrinking apparent latent spread) — and Ayumi's science *is* a
variance partition. Paying a 20% coordinate saving with the estimand is a bad
trade. **Verdict: keep the full `2x2` blocks.**

**Low-rank: not applicable.** A rank-1-plus-diagonal `S_g` at `q = 2` costs 8
numbers against the full 5. Low-rank only begins to pay above roughly `q = 8`,
which is far outside gllvmTMB's operating range for these models. **Verdict:
irrelevant here; revisit only if a high-`q` cell ever appears.**

**What *is* binding at this scale is the optimiser, not the covariance shape.**
Design 72 §2 makes the variational coordinates ordinary parameters, so the outer
optimiser must carry `P ~ 5.4 x 10^4` (or `8.1 x 10^4` augmented) coordinates
*in addition to* the structural parameters. A dense quasi-Newton stores an
`O(P^2)` approximation:

| `P` | dense quasi-Newton memory | L-BFGS (`m = 5`) |
|---|---|---|
| 53,970 | `~23 GB` | `~4 MB` |
| 80,950 | `~52 GB` | `~6 MB` |

*(`P^2 * 8` bytes versus `2mP * 8` bytes. This is arithmetic over standard
optimiser implementations — an **inference**, cheap to verify by inspecting what
`nlminb`/`optim(method="BFGS")` allocate, and it should be verified before it is
relied on.)*

**Verdict:** the honest scaling answer at Ayumi's size is *not* "restrict `S`".
It is: (a) take Proposition 2's free reductions; (b) use a **limited-memory**
optimiser (L-BFGS-type) rather than a dense quasi-Newton; and (c) consider a
two-loop scheme — cheap per-level updates of `(m_g, L_g)`, which are
independent `d x d` problems and embarrassingly parallel, inside an outer loop
over `(beta, Lambda, sd, kappa)`. (c) is a named option, not a recommendation;
it changes the optimisation architecture inherited from Design 72 §2 (lines
145–154) and should not be opened without a separate decision.

> **Correction, 2026-07-29.** This paragraph, and seven other citations across
> Designs 106, 107 and 108, previously deferred to **"Design 160"**,
> which **does not exist** on any branch (verified by `git log --all
> --diff-filter=AD` over `docs/design/`; the highest real number is 110). The real
> origin of the "variational coordinates as ordinary TMB parameters, NOT
> `random=`" decision is **Design 72 §2, lines 145–154**, which states it *with its
> reasoning*: no inner Laplace mode-find, no inner Hessian factorisation, and
> "the structural reason VA can be more stable".
>
> **The architecture question no longer needs a citation, because it has been
> measured.** Three-arm A/B on the existing `va_r3` engine — binomial-logit, T=20,
> q=2, H=15, identical inputs (`dev/vgh/ab-runs/`, 2026-07-29):
>
> | arm | N=200 | N=400 | N=800 | outer par |
> |---|---:|---:|---:|---:|
> | A `random = NULL` (status quo) | 11.3 s | 28.2 s | 80.3 s | 1060 → 4060 |
> | B `random = c(...)` | 140.0 s | 83.2 s | 458.4 s | 60 |
> | C `profile = c(...)` | 73.2 s | 347.2 s | 588.8 s | 60 |
>
> Arm C reaches the **same objective** as arm A to ~1e-10, so `profile=` is the
> semantically correct route (arm B returns a Laplace-*marginalised* objective and
> is not comparable). The outer parameter count collapses exactly as predicted —
> and the fit is **7.3× slower at N=800**. Moving the variational block into
> `random=`/`profile=` is therefore refuted as a speed fix.
>
> That does **not** endorse (c) either; it removes the phantom fence around it. A
> block coordinate-ascent prototype using closed-form per-level updates is at
> `dev/vgh/`, its objective verified identical to this package's TMB template to
> 4.7e-15. See `docs/dev-log/2026-07-29-vgh-report.md`.

### 4.4 One cross-tier block worth buying

Ayumi's two tiers are indexed by the **same** grouping factor (species). That is
unusual and it is an opportunity: instead of two independent `2`-vectors per
species, carry one merged `4`-vector per species with a full `4 x 4` covariance.

```
factorised : 5397 * (5 + 5)          = 53,970
merged     : 5397 * (4 + 4*5/2 = 14) = 75,558      (+40%)
```

Why this specific block and no other: the ordinary and phylogenetic tiers are
**a posteriori confounded** — they compete to explain the same species-level
variance, which is exactly the phylogenetic-signal identification problem. Their
cross-covariance is the largest one in the model, and it is the one that
propagates into the variance partition.

Two things are guaranteed and one is not:

* **Guaranteed:** the merged family strictly contains the factorised one, so the
  ELBO is `>=` — a tighter bound by construction, at fixed model and data.
* **Guaranteed:** the prior stays block-diagonal across tiers, so `tr(Q_p S)`
  and `m' Q_p m` still split per tier; only `logdet(S)` becomes the merged
  `4 x 4` determinant. Implementation cost is small.
* **Not guaranteed:** better parameter estimates. A tighter bound is not a
  better estimator (Design 104's standing caution). The falsifiable prediction
  is that the merged family *widens* the reported uncertainty on the
  phylo-versus-residual partition relative to the factorised one; if it does not
  move at all, the confound is weaker than assumed and the block can be dropped.

On the augmented route only the tips can be merged (internal nodes have no
ordinary counterpart); merge over tips, keep internal nodes factorised.

---

## 5. Implementation order

Given a template that already computes `v = || L_i' lambda_j ||^2`:

**1. Multiple unstructured tiers (§1) — cheapest by a wide margin.**
The existing kernel is *already* the general one. The change is: loop tiers when
accumulating `mu` and `v`; loop tiers and levels when accumulating the KL. No
new integrand, no new quadrature, no new linear algebra, no new DATA structures
beyond per-tier level indices and loading vectors. Proposition 2 additionally
tells you that per-trait tiers (`unique`, `indep`, `cluster`, `cluster2`) cost
`2T` per level rather than `T + T(T+1)/2`, with no accuracy loss.

**2. Random slopes (§2) — second, and only barely harder than 1.**
Same kernel, same KL (`N(0, I)` after standardization), same accumulation. The
intercept–slope cross term `2 x_o S_{g,01}` is produced automatically by
`|| L' a_o ||^2`. The *only* new work is that `a_o` now depends on the
observation's covariate value rather than only on its trait, so the loading can
no longer be cached per trait — an indexing and parser change, not a
mathematical one. Gated by Design 04's one-slope cap.

**3. Structured priors (§3) — hardest, and it presupposes 1.**
The data term is completely unchanged; every new line is in the KL. New DATA
inputs (`Ainv`, `diag(Ainv)`, `log_det_A`, or the SPDE assembly), the augmented
node-set question (§4.2), and the level-factorisation tension (§3.6). Note the
dependency: **a structured tier *is* just another tier in the accumulation** —
it differs only in which KL it uses — so step 1 is a prerequisite, not a
parallel track. Within step 3:

  **3a. Phylo / animal / kernel** — fixed `A`, `logdet` a data constant, KL free
  of hyperparameters under the standardized-field convention, trace needs only
  `diag(A^{-1})`, and the quadratic form already exists in the Laplace engine at
  `src/gllvmTMB.cpp:1285-1294`.

  **3b. Spatial SPDE** — `Q(kappa)` is parameter-dependent so `logdet(Q)` is
  recomputed every evaluation; the `A_proj` multi-node loading makes the
  node-factorised `q` a poor approximation, and the structurally correct fix
  (sparse variational precision + partial inverse) is an open engineering
  question.

*Axis disclosure:* this ranks by **derivation risk and per-evaluation cost**. If
one ranks instead by **new C++ written**, 3b moves up, because
`density::GMRF(Q)` is already in the template while the phylo KL's trace term is
not. Both readings are defensible; they answer different questions, and Design
72 §3.3 answered the second one.

---

## 6. Standard algebra vs design choice — and what is uncertain

### 6.1 Textbook, not up for debate

* Linear combinations of independent Gaussians are Gaussian; means and variances
  add (Prop. 1).
* The Gaussian–Gaussian KL formula of §3.1.
* Fischer's inequality `det(S) <= prod_b det(S_bb)`, with equality iff the
  off-diagonal blocks vanish (used in Prop. 2).
* Invariance of KL under a common invertible linear map (used in §3.2).
* The trace identity of §3.3 (index manipulation only).

### 6.2 Design choices made here

* Gaussian `q` with a **full covariance per level**, factorised across levels
  and tiers, as the default (§0) — with two deliberate exceptions: the free
  trait-diagonal restriction (Prop. 2) and the paid cross-tier merge (§4.4).
* Adopt the engine's **standardized-field convention** for structured tiers, so
  the structured KL carries no hyperparameters (§3.2).
* Compute the trace from **`diag(Q_p)` as a DATA vector** rather than via sparse
  products (§3.3).
* **Retain** `logdet(Q_p)` even where it is constant, to keep the ELBO on the
  Laplace scale for the Design 104 §7 sign check (§3.4).
* Match Design 04's **one-slope cap** rather than deriving ahead of the shipped
  surface (§2.3).
* Rank phylo **ahead of** spatial, disclosing the axis (§5).

### 6.3 What this document does NOT do

* It does not touch Design 105's family obstructions. Multinomial still needs a
  `T`-dimensional integral through `log sum_t exp(eta_it)`; with several tiers
  the covariance of `eta_i.` is simply a sum of per-tier covariances, so the
  obstruction is unchanged in kind and in difficulty. Zero-inflated / `*_mix`
  families with separate component predictors are likewise untouched — though
  note that each component predictor is separately covered by Prop. 1, so what
  is missing is the *joint* over two correlated predictors, not the structure.
* It authorises nothing. No export, no `method=`, no capability claim.

### 6.4 Uncertain — flagged rather than asserted

1. **Sparse partial inverse inside a TMB template** (§3.6). Needed for the
   structurally-correct SPDE variational family. TMB does Takahashi recursions
   internally; whether a differentiable partial inverse is reachable from a
   template is **unverified**.
2. **`density::GMRF` normalising-constant convention** (§3.5b). The trailing
   constant in the KL identity depends on it. Verify against the TMB source
   before writing the SPDE KL.
3. **Optimiser memory arithmetic** (§4.3). The `O(P^2)` claim follows from how
   dense quasi-Newton methods are normally implemented; it should be confirmed
   against what `nlminb` / `optim(method="BFGS")` actually allocate at
   `P ~ 5 x 10^4` before it drives a decision.
4. **`n_aug` for Ayumi's actual tree** (§4.2). `2N - 1 = 10,793` assumes rooted
   and fully bifurcating. Read `nrow(Ainv)` for the real tree; polytomies reduce
   it.
5. **Whether the augmented route is worth its cost at all** (§3.6). The
   tips-only dense route costs `O(N^2)` per quadratic form (`~2.9 x 10^7` flops
   at `N = 5397`, tolerable) plus a one-off `O(N^3)` factorisation, and it needs
   only `diag(A^{-1})` for the trace. It may be the better VA route even though
   it is the worse Laplace route. **This is a genuine open question, not a
   recommendation** — it needs measurement, and it inverts an assumption the
   package has held since Design 47.
6. **Direction of the mean-field bias on the variance partition** (§1.3, §4.4).
   That mean-field understates posterior *variance* is well established. That it
   biases the phylo-versus-residual *point* partition in a specific direction is
   **not** established here and should not be asserted.

---

> Related: [Design 104](104-va-family-coverage.md) (architecture, defaults) ·
> [Design 105](105-va-family-densities.md) (family densities, the multinomial
> break) · [Design 72](72-variational-approximation-feasibility.md) §3
> (structured-prior feasibility; §3.3 partially reversed here, see §3.6) ·
> [Design 47](47-sparse-pedigree-ainv.md) (sparse `A^-1`) ·
> [Design 64](64-spatial-dep-latent-derivation.md) (SPDE `Q`) ·
> [Design 04](04-random-effects.md) (tier vocabulary, slope cap) ·
> [Design 85](85-highdim-nongaussian-va-formal-contract.md) (READ-ONLY negative
> evidence; no ELBO-based inference)
