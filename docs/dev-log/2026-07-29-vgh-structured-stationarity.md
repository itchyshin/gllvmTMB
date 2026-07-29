# The closed-form variational covariance under a STRUCTURED prior

**2026-07-29 · Claude · derivation + two cross-checks · NOT IMPLEMENTED**

**Why this file exists.** On 2026-07-27 the equivalent result for the JJ arm was
derived, verified, and left **uncommitted** in a `/private/tmp` worktree; the
committed record then said the problem was "unexplained" and the route was
frozen. This note exists so the same thing does not happen twice. It records a
*derivation*, not a change. Nothing is implemented, nothing is claimed.

---

## What Design 106 supplies, and what it stops short of

Design 106 proves **Proposition 1**: `mu` and `v` accumulate additively across
tiers, so `eta` stays univariate Gaussian and *"the entire quadrature layer is
untouched"* (`106:36-39`, proof `106:102-104`). It also gives:

* the general KL (`106:273-276`),
* the **trace collapse** (`106:321`), whose consequence is stated at `106:285` as
  *"only `diag(Q_p)` is needed"*,
* `logdet(S)` level-separable by construction (`106:366-368`),
* `m'Q_p m` and `logdet(Q_p)` containing no `S` at all (`106:282-287`).

Together these mean the KL's **entire `S`-dependence** is

```
0.5 * [ sum_g tr(Q_gg S_g)  -  sum_g logdet(S_g) ]
```

Design 106 never differentiates it. `grep -E "Stein|stationarit|stationary|fixed.point"`
across designs 72, 85, 104, 105, 106, 107, 108, 109 returns **zero hits in 106**.
The reason appears to be architectural: 106 assumes one joint AD optimisation with
the variational coordinates as ordinary TMB parameters, and under that architecture
there is no covariance *update* to write down. See §"the fence" below.

## The derivation

Let `q` be level-factorised, `S = blockdiag(S_1, ..., S_n)` (`106:80`), and write
`w_o = E_q[b''(eta_o)] / phi_{j(o)}`.

**Data term.** By Proposition 1, `v_o = a_o' S_g a_o` for the level `g` carrying
observation `o`, so `dv_o/dS_g = a_o a_o'`. With the Gaussian second-moment
identity `dB/dv = (1/2) E[b''(eta)]` — equivalently `dB/ds = s E[b''(m+sZ)]`, a
property of the Gaussian and not of the family, so untouched by anything
structural —

```
d(data)/dS_g = -(1/2) * sum_{o: g(o)=g} w_o * a_o a_o'
```

**KL term.** From the four ingredients above,

```
d(-KL)/dS_g = -(1/2) * [ Q_gg - S_g^{-1} ]
```

**Setting the sum to zero:**

```
    S_g^{-1}  =  Q_gg  +  sum_{o: g(o)=g} w_o a_o a_o'
```

**Only the diagonal block of the structured prior precision enters.** It is a
per-level `d_k x d_k` solve. No joint `(n*d) x (n*d)` inversion, no Takahashi
selected inversion.

The off-diagonals of `Q_p` vanish here because they multiply the off-diagonal
blocks of `S`, which the level-factorised `q` sets to zero. `Q`'s structure is
**not** absent from the problem — it is fully present in the mean equation and in
`m'Q_p m`. It is absent only from the *covariance* stationarity condition.

## Two cross-checks

**1. The iid case reduces verbatim.** Set `Q_p = I_{Nq}`, so `Q_gg = I_q`; then
`a_o = lambda_j` and `w_o = B2_ij/phi_j`, giving

```
S_i^{-1} = I_d + Lambda' W_i Lambda
```

which is exactly the form implemented at `dev/vgh/vgh-engine.R:21` and verified
numerically against the TMB template to 4.7e-15. The structured result is a strict
generalisation, `I -> Q_gg`.

**2. Phylo, standardized field, agrees with Design 106 from the other side.**
`106:293-298` gives `g ~ N(0, A)` so `Q_p = Sigma_c^{-1} (x) A^{-1}`; with
`Sigma_c = I`, `Q_gg = [A^{-1}]_gg * I_C`:

```
S_g^{-1} = [A^{-1}]_gg * I_C  +  sum_{o in g} w_o a_o a_o'
```

A **scalar multiple of the identity** plus data curvature — simpler than the iid
case. It consumes exactly `diag(A^{-1})`, the same `n`-vector Design 106 §3.3
identifies by a completely different route (the trace collapse). Two derivations,
same object.

## What erodes, stated honestly

**The mean does NOT decouple.** Differentiating in `m_g`:

```
sum_h Q_gh m_h  =  sum_{o in g} (y_o - E_q[b'(eta_o)]) a_o / phi_{j(o)}
```

The full row of `Q` appears. So the covariance decouples and the mean does not:
the free per-unit Newton step becomes a coupled sparse system. **Cost is modest
and Design 106 already prices it** — `106:374` gives `m'Q_p m` as a
`DATA_SPARSE_MATRIX` product, `O(nnz)`, exact AD, already used at
`src/gllvmTMB.cpp:728, 1038, 1285`. Under a coordinate-ascent architecture it is a
sparse solve or a Gauss-Seidel sweep, not a dense one.

**The restriction is real, and Design 106 says so.** Proposition 2 (`106:164-172`)
licenses zero blocks for free only when the prior precision is block-diagonal on
the same partition. For a structured tier partitioned by level, that condition
**fails by construction** — off-diagonal coupling is the whole point of `A^{-1}`.
`106:421-423` is explicit, and §3.6 is titled *"the uncomfortable part: a
level-factorised `q` fights the structure"*. So the engine stays fast and general;
**what you pay is bound tightness, not speed.** `106:450-455` offers a falsifiable
prediction of how much.

**Spatial is a different problem.** The SPDE projection spans ~3 mesh nodes, so a
node-factorised `q` keeps the closed form but *mis-states `v` for every
observation* (`106:429-431`). The structurally-matched alternative — variational
precision sharing `Q`'s sparsity — loses the closed form and needs a
differentiable partial inverse that `106:438-440` flags as *"an open engineering
question, not a plan."* Design 106 records this as a **reversal** of Design 72,
which had called spatial the easiest structured VA win.

## The fence — and it is now refuted by measurement

Design 106 defers the per-level coordinate-ascent architecture to a document that
does not exist. `106:586-588`:

> (c) is a named option, not a recommendation; it changes the optimisation
> architecture Design 160 settled and should not be opened without a separate
> decision.

"(c)" is described two lines earlier as *"cheap per-level updates of `(m_g, L_g)`,
which are independent `d x d` problems and embarrassingly parallel"* — i.e. exactly
this mechanism. **No Design 160 exists on any branch** (verified by
`git log --all --diff-filter=AD` over `docs/design/`; highest real number is 110).
It is cited **eight times** across designs 106, 107 and 108, three of them as
vetoes.

As of 2026-07-29 the architecture question no longer needs that citation, because
it has been **measured** — see `dev/vgh/ab-runs/`: the alternative the fence
protects (`random=` / `profile=`) is 6-12x SLOWER than the current joint
optimisation and degrading with n. The fence should be replaced by the evidence.

## Status

**NOT IMPLEMENTED. NOT CLAIMED.** `dev/vgh/vgh-engine.R` implements only the iid
case (`Q_gg = I`). This note records the extension so it is not rediscovered.
Actionable only if and when structured tiers are built; at that point the
first test should be cross-check 2 above, since it has an independent
counterpart in Design 106 §3.3.
