# AGHQ coverage claim — adversarial verdict

**Lens: try to break it.** Default position was *not established*; every
"SURVIVES" below is a position I was moved to by measurement, not one I
started from.

**Status:** research note, `dev/` only. No package change, no public claim.
This slice implements nothing and edits nothing under `R/`, `src/`, `inst/`,
`tests/`, `NAMESPACE`, `DESCRIPTION` in any worktree.

---

## 0. The claim under test

> "AGHQ is a refinement layer on the Laplace objective, so it inherits all 16
> families, phylogeny, spatial and missing data."

This is the load-bearing premise of the redirection away from VA. It has four
separable parts. Verdicts:

| Axis | Verdict |
|---|---|
| 1. Family-agnosticism | **QUALIFIED** — genuinely agnostic at the attachment point; one measured family-specific defect |
| 2. Dimension | **BREAKS** — the quantity integrated is not `q`, and the stated node count is wrong for the *default* term |
| 3. Phylogeny / spatial | **BREAKS** — the field is one connected block; there is nothing to refine blockwise |
| 4. Missing data | **SURVIVES** |

**Overall: NOT ESTABLISHED as stated.** The claim is true of the *family
dispatch* and false of the *model surface*. §5 gives the narrower form that
the evidence does support, written as a quotable sentence.

---

## 0.1 Provenance and method

* Source claims cite the primary checkout `/Users/z3437171/Dropbox/Github
  Local/gllvmTMB`, **main @ `dc10fa6a`** (2026-07-27).
* Runtime probes ran against the **installed** `gllvmTMB 0.5.0`
  (`~/Library/R/arm64/4.6/library/gllvmTMB`, Built 2026-07-18, R 4.6.0,
  aarch64-darwin23).
* **Drift check:** `git log --since=2026-07-18 -- src/gllvmTMB.cpp
  R/fit-multi.R` returns **no commits**. The model engine in the installed
  build is byte-current with main @ `dc10fa6a`, so the probe numbers below are
  valid statements about main. (`dc10fa6a` itself touches `R/diagnose.R`, which
  is fenced and irrelevant here.)
* Probe scripts, all read-only against the package, live beside this file:
  `02-random-vector-probe.R`, `02-structured-random-probe.R`,
  `02-spde-missing-probe.R`, `02-spde-probe2.R`, `02-family-node-probe.R`,
  `02-crossed-block-probe.R`, `02-ordinal-clamp-probe.R`.
* Where a per-unit AGHQ block dimension is quoted, it was measured as the
  **connected components of the sparsity graph of
  `obj$env$spHess(theta, random = TRUE)`** — the conditional random-effects
  Hessian TMB itself builds. Components are exactly the factors the integral
  splits into; component size is exactly the tensor-grid dimension AGHQ would
  face. This is the right instrument, not a proxy.

---

## 1. THE HIGHEST-VALUE ANSWER: what TMB actually declares as random

**`random` is assembled block-by-block at `R/fit-multi.R:4474-4521` and handed
to `TMB::MakeADFun(..., random = random)` at `R/fit-multi.R:4541-4547`.** Up to
23 named blocks can join it. It is **not** the latent factor scores alone.

The two that matter for the ordinary `latent()` term:

| Block | Declared | Shape | Length |
|---|---|---|---|
| `z_B` | `src/gllvmTMB.cpp:480`, allocated `R/fit-multi.R:3450` | `d_B × n_sites` | `q · n` |
| `s_B` | `src/gllvmTMB.cpp:491`, allocated `R/fit-multi.R:3459` | `n_traits × n_sites` | `T · n` |

`s_B` joins `random` at **`R/fit-multi.R:4482`** whenever `use_diag_B`
(`R/fit-multi.R:679`) — i.e. whenever the term carries its diagonal Psi
companion, **which is the documented default for ordinary `latent()`**
(CLAUDE.md standing rule; `unique = FALSE` is the opt-out).

### Measured (`02-random-vector-probe.R`, n = 40 sites, T = 5 traits, q = 2)

```
latent(1|site, d = 2)   DEFAULT (Psi on)   z_B=80, s_B=200  -> length(env$random) = 280
latent(1|site, d = 2, unique = FALSE)      z_B=80           -> length(env$random) =  80
```

**This settles the maintainer's open question.** The smoke fit's "80 random
effects at n = 40, q = 2" is `z_B` **alone** = `q · n` = 2 × 40. That is the
`unique = FALSE` route. The package **default** `latent()` declares **280**.

So: the random vector is `n · q` at minimum, and `n · (q + T)` for the default
term. It is **never** `q`.

---

## 2. Axis 1 — FAMILY-AGNOSTICISM → **QUALIFIED**

### What is genuinely agnostic (this part of the claim holds, and holds well)

The whole family dispatch is a single lambda whose only latent-dependent
argument is a scalar linear predictor:

```
src/gllvmTMB.cpp:1994    auto obs_loglik = [&](int o, Type eta_o) -> Type {
src/gllvmTMB.cpp:2363      nll -= obs_loglik(o, eta(o));
```

Branches `fid == 0 … 15` (`src/gllvmTMB.cpp:1997 … 2185`, with a hard
`error()` on anything else at `:2198`) are **16 families**, and the latent
variables reach every one of them *only* through `eta(o)` (assembled at
`src/gllvmTMB.cpp:1842`, `:1858`). No family branch reads `z_B`, `s_B`,
`g_phy` or `omega_spde`. **Perturbing the latent to a quadrature node is a
family-independent operation by construction.**

Corroborated at runtime (`02-family-node-probe.R`): `obj$env$f(theta,
order = 0)` re-evaluated at the fitted `theta` with the entire random block
shifted by 0/1/3/5/8/12 units returns finite values for every family tried —

```
ordinal_probit     115.262 | 137.748 |  315.63 | 665.674 | 1509.73 | 2813.49
tweedie            138.931 | 157.212 | 316.395 | 699.262 | 2165.48 | 10820.5
delta_gamma         140.21 | 158.235 |  292.95 | 546.179 | 1133.34 | 2295.95
truncated_poisson  172.044 | 185.494 | 294.057 | 513.998 |  1061.1 | 2224.86
poisson            168.426 |  185.38 | 331.666 | 664.018 | 1698.27 | 5223.05
```

Three specific worries in the brief are **defused**, and I record that plainly
because the honest job is to report what the evidence did, not to find a kill:

* **"For a mixture likelihood, does a single adaptive mode + Hessian even give
  a sensible quadrature rule?"** — this is the sharpest question in the brief,
  and for gllvmTMB the answer is **yes, because the hurdle families are not
  mixtures in the integration variable**. `fid == 12/13`
  (`src/gllvmTMB.cpp:2119-2147`) branch on `y(o) > Type(0)` — on **observed
  data**, which is *fixed* while the latent is integrated. Conditional on the
  observed `y`, `log p(y | eta)` is a **sum of smooth terms in `eta`**
  (`dbinom_robust(x_pres, 1, eta_o)` plus, when `y > 0`, a smooth positive-part
  density), not a two-component mixture. The mixture lives across possible `y`,
  not across `u`. There is no kink to straddle.
* **Boundary modes.** For a site with all-zero responses the data term pushes
  `eta → -inf`, but the conditional Hessian is bounded below by the **prior**:
  `z_B` carries a spherical `N(0, I)` (`src/gllvmTMB.cpp:785-788`) and `s_B` an
  `N(0, sd_B)` (`src/gllvmTMB.cpp:877`). The conditional mode stays finite and
  the curvature stays ≥ the prior precision, so an adaptive rule is always
  well-posed. The prior regularises the boundary case away.
* **Zero-inflation is out of scope, not a risk.** There is **no** ZI family in
  gllvmTMB. The 16 supported families are enumerated at `R/fit-multi.R:286`;
  `gamma_mix` / `lognormal_mix` / `nbinom2_mix` exist in `R/families.R` but are
  **not** in the supported list and hit the `error()` at
  `src/gllvmTMB.cpp:2198`. The brief's ZI concern does not apply.
* **Nuisance parameters do not enter the rule.** Ordinal cutpoints
  (`src/gllvmTMB.cpp:2170-2174`), the Tweedie power `p_t`
  (`src/gllvmTMB.cpp:2057`), betabinomial `phi` (`:2079`) are all *outer*
  parameters, reconstructed from `PARAMETER`s, not latent. They are
  family-specific *parameters*, not family-specific *quadrature machinery*.

### The qualification (one measured, family-specific defect)

**`ordinal_probit` (`fid == 14`) floors its cell probability:**

```
src/gllvmTMB.cpp:2182      Type tiny_p = Type(1e-12);
src/gllvmTMB.cpp:2183      p_k = CppAD::CondExpLt(p_k, tiny_p, tiny_p, p_k);
src/gllvmTMB.cpp:2184      ll += log(p_k);
```

Under Laplace this is harmless — the objective is only ever evaluated at (or
adjacent to) the conditional mode, where `p_k` is not small. **AGHQ evaluates
in the tails on purpose.** Once the clamp binds, the integrand stops decaying
and is held at a constant `log(1e-12)`, so tail nodes receive **too much**
weight and the marginal is biased in a direction the node ladder will not
diagnose (adding nodes makes it worse, not better).

Measured reach (`02-ordinal-clamp-probe.R`, adaptive rule
`u = mode + √2 · R⁻¹x_h`):

```
                                                       min cell p
k= 5  |eta| shift 1.849                                  3.2e-02
k= 9  |eta| shift 2.920                                  1.8e-03
k=15  |eta| shift 4.118                                  1.9e-05
k=25  |eta| shift 5.642                                  8.4e-09
clamp binds once |eta - tau| > 7.03
```

At this fixture (`max|Lambda_B| = 0.821`, `max conditional SD = 0.788`) the
clamp does **not** bind, even at k = 25. But the reach scales as
`√2 · x_max · s_cond · |λ|`, so at the converged ladder (k = 5–9) it binds once
`s_cond · |λ| > 7.03 / 4.513 ≈ 1.56`. That is an ordinary regime, not an exotic
one. **Verdict: not a blocker, but a real per-family guard the layer must
carry, and one that Laplace never needed.**

**UNVERIFIED:** `dtweedie`'s series *accuracy* (as opposed to finiteness) at
far nodes with extreme `mu`. The values above are finite; I did not check them
against an independent evaluation. Truncated Poisson / NB2 (`fid 10/11`) same
caveat.

**Verdict: QUALIFIED.** The Laplace objective *is* family-agnostic at the point
AGHQ attaches, and the two generic TMB primitives needed (`obj$env$f(theta,
order = 0)` for the integrand, `obj$env$spHess(theta, random = TRUE)` for the
adaptive rule) are family-generic. One family (`ordinal_probit`) needs a
node-safe density path before it can be quadratured.

---

## 3. Axis 2 — DIMENSION → **BREAKS**

The claim's cost basis — "`H^q` is 81 nodes at q = 2" — is only defensible if
the integral factorises into per-unit blocks of dimension `q`. It does not,
for the default term.

### Measured block structure (`02-family-node-probe.R`, `02-crossed-block-probe.R`)

Connected components of `spHess(theta, random = TRUE)`:

```
latent(1|site, d=2), T=4, n=20      dim(H)=120   20 blocks, all size 6   ( = q + T )
latent(1|site, d=1), T=3, n=20      dim(H)= 80   20 blocks, all size 4   ( = q + T )
latent(1|site, d=1) + (1|region)    dim(H)= 84    4 blocks, largest 21
```

Two independent breaks:

**(a) The default `latent()` block is `q + T`, not `q`.** `z_B(·, s)` and
`s_B(·, s)` both feed the same rows' `eta` (`src/gllvmTMB.cpp:1842`, `:1858`),
so they are conditionally *dependent* within a site. Measured: one component of
size exactly `q + T` per site. Node count per unit is therefore `k^(q+T)`, not
`k^q`.

At the collaborator's cell (q = 2, **T = 20**, n = 5397) that is `k^22` per
site: at the converged ladder k = 9 that is `9^22 ≈ 9.8e20` nodes **per site**,
and even the cheapest k = 5 is `5^22 ≈ 2.4e15`. Not computable by any margin.
The advertised 81 is `k^q` = `9^2`, which is the `unique = FALSE` number.

**(b) A single crossed grouping factor destroys blockwise AGHQ outright.**
Ordinary `(1 | group)` random intercepts join `random` at
`R/fit-multi.R:4509` (`u_re_int`). Because one `u_re_int` entry enters `eta`
for rows spanning many sites, it welds those sites' blocks together. Measured
above: adding `(1 | region)` with 4 regions collapsed **20 blocks of size 4
into 4 blocks of size 21**. Any crossed factor with few levels merges nearly
everything.

Also in `random` and enlarging the per-unit block: `e_eq` (OLRE), length
`n_obs` (`src/gllvmTMB.cpp:524`, `R/fit-multi.R:4490`); `x_mis`, the continuous
missing-predictor latent (`R/fit-multi.R:4514`); `s_B_slope`, `z_B_slope`,
`r_c2`, `q_sp` (`R/fit-multi.R:4481-4489`).

### On the existing spike's cost basis

The q = 2 spike (`/private/tmp/gllvmtmb-va-wiring-20260726/dev/aghq-crux-q2-transfer.R`,
read-only) already assumes per-unit factorisation — `aghq-scope-gap.md:19`,
"For each unit `i` independently" — and its DGP has **only** the q-dimensional
score (no Psi, no ordinary RE, no structure). So its `81` is *nodes per unit*
under `latent(..., unique = FALSE)`, which is internally consistent. The error
is not in that spike; it is in **generalising its node count to the package's
default term**. That is the sentence the claim actually makes, and it is false.

**Verdict: BREAKS as stated.** The dimension story survives only for
`latent(..., unique = FALSE)` under a single nested grouping factor.

---

## 4. Axis 3 — PHYLOGENY / SPATIAL → **BREAKS**

### Phylogeny

`g_phy` is `n_aug_phy × d_phy` (`src/gllvmTMB.cpp:565`, allocated
`R/fit-multi.R:3521`) — the field lives on the **augmented** tree (tips **and**
internal nodes), and its prior is a joint MVN through the sparse `Ainv`
(`src/gllvmTMB.cpp:1217`ff for the closed-form path; `GMRF` for the latent
path).

Measured (`02-structured-random-probe.R`, `02-family-node-probe.R`):

```
phylo_latent(1|species, d=2), 30 tips              g_phy=116          random dim 116
phylo_latent(1|species, d=2, unique=TRUE)          g_phy=116, g_phy_diag=232   random dim 348
phylo_indep(1|species)                             g_phy=232          random dim 232
phylo_latent(1|species, d=1), 20 tips  -> spHess components: 2 blocks, sizes 3 and 35
```

`n_aug_phy = 2·n_tip − 2` (58 for 30 tips, 38 for 20 tips) — confirmed by the
`116 = 58 × 2` and `38 = 38 × 1` arithmetic. **The 20-tip case has one
connected block of 35 of 38 coordinates.** There is no per-species
factorisation to exploit. AGHQ dimension = the field size, so `k^35` at 20
tips — `5^35 ≈ 3e24`.

### Spatial (SPDE)

`omega_spde` is `n_mesh × n_traits` (`src/gllvmTMB.cpp:529`, allocated
`R/fit-multi.R:3477`), with a joint GMRF prior per trait column
(`src/gllvmTMB.cpp:1468` `nll += SCALE(GMRF(Q_base), 1/tau)(omega_t)`;
`:1497` for the latent path).

Measured (`02-spde-probe2.R`, 60 sites, 52-node mesh, 3 traits):

```
spatial_indep(0+trait|site)          omega_spde    = 156  ( = 52 × 3 )
spatial_latent(0+trait|site, d=2)    omega_spde_lv = 104  ( = 52 × 2 )
```

A GMRF over a mesh is one connected field by construction. AGHQ dimension is
`n_mesh · n_traits`. At a *toy* 52-node mesh that is 104–156; real meshes are
hundreds to thousands of nodes.

### The one honest nuance

A tree precision is Markov *on a tree*, so a sequential quadrature (belief
propagation over the tree) is theoretically possible for the phylo case. An
SPDE GMRF on a 2-D mesh has treewidth ~`√n_mesh`, so even that route is
infeasible there. Neither is a "refinement layer over the existing Laplace
objective" — both are a different estimator with its own derivation, its own
code, and its own validation burden. Claiming inheritance here is claiming
something that does not exist.

**Verdict: BREAKS.** Phylogeny and spatial are not inherited; they are not
even reachable by the same mechanism.

---

## 5. Axis 4 — MISSING DATA → **SURVIVES**

Two routes, `miss_control(response = c("drop", "include"))`
(`R/gllvmTMB.R:1101-1104`).

* **`drop`** (default): rows are removed before the objective is built.
  Measured (`02-random-vector-probe.R`): masking 12 of 200 cells produced
  `n_obs = 188` with `is_y_observed` all-ones. Nothing about the latent changes.
* **`include`**: a per-row mask (`DATA_IVECTOR(is_y_observed)`,
  `src/gllvmTMB.cpp:88`) gates the likelihood term —
  `if (is_y_observed(o) && !mi_missing_row) nll -= obs_loglik(o, eta(o));`
  (`src/gllvmTMB.cpp:2355-2363`). Measured (`02-spde-missing-probe.R`):
  `n_obs = 200`, 12 zeros in `is_y_observed`, **random dim unchanged at 280**.

Neither route changes the random vector, the block structure, or the smoothness
of the integrand — a masked row simply contributes nothing at every node. AGHQ
composes with both without special handling.

**INFERRED-FROM-CODE (not separately measured):** a unit with *all* responses
missing has a data-free conditional block, whose Hessian is exactly the prior
precision (`src/gllvmTMB.cpp:788`, `:877`). Its integrand is exactly Gaussian,
so AGHQ is exact there at any `k ≥ 1`. No hazard — but I did not run this cell.

**Out-of-scope note, flagged rather than smoothed:** missing *predictors* are a
different matter. The **discrete** route marginalises exactly by a finite-state
sum inside the objective (`src/gllvmTMB.cpp:2208`ff) and adds no latent — it
composes with AGHQ for free. The **continuous** route adds `x_mis` to `random`
(`R/fit-multi.R:4514`), which *enlarges the per-unit quadrature block* and so
belongs to the §3 problem, not this one.

**Verdict: SURVIVES.**

---

## 6. Overall verdict

**NOT ESTABLISHED as stated.** The claim conflates two different kinds of
inheritance:

* **Inherited (real):** the *family dispatch*. Every family sees the latent
  only through `eta`, so one quadrature implementation serves all 16 — modulo
  `ordinal_probit`'s probability floor.
* **NOT inherited (the claim's failure):** the *model surface*. What AGHQ must
  integrate is the **whole declared random vector** (`R/fit-multi.R:4474-4521`)
  — `n·(q+T)` for the default `latent()`, `n_aug_phy·d` for phylogeny,
  `n_mesh·T` for SPDE — and its cost is governed by the **connected-component
  size of the conditional Hessian**, not by `q`. Two of the four axes fail on
  that single fact.

The redirection away from VA was argued on **coverage**. On coverage the
measured picture is: AGHQ's family coverage is broad and genuine (16 of 16,
one guard needed), and that is a real advantage over VA's 4 of 16. But AGHQ's
**structural** coverage is *narrower than the claim*: phylogeny and spatial —
the two things VA was faulted for rejecting — are equally out of reach for
AGHQ, for a different but no less hard reason. **The strongest single
argument for the redirection does not survive contact with the code.** That is
not an argument for VA; it is an argument that the comparison was scored on a
premise that was never checked.

None of this touches the accuracy evidence (attenuation 0.951 / 1.044, the
`c_full` band, the node ladder). That evidence stands on its own and is about a
regime — `latent(..., unique = FALSE)`, single grouping factor, low `q` — where
AGHQ genuinely is computable.

---

## 7. The narrower form the project can quote

> AGHQ attaches to the Laplace objective without family-specific machinery: the
> latent variables reach every one of gllvmTMB's 16 families only through the
> linear predictor `eta` (`src/gllvmTMB.cpp:1994`, `:2363`), so a single
> implementation serves all of them — with one exception, `ordinal_probit`,
> whose `1e-12` probability floor (`src/gllvmTMB.cpp:2182-2183`) is safe under
> Laplace but must be widened or guarded before the density is evaluated at
> quadrature nodes.
>
> It does **not** inherit the model surface. AGHQ is computable only where the
> conditional random-effects Hessian is block-diagonal with small blocks, which
> in gllvmTMB means a **single nested grouping factor with
> `latent(..., unique = FALSE)`** — there the integral factorises into `n`
> blocks of dimension `d`, costing `k^d` nodes per unit. It is **not**
> computable for the **default** `latent()`, whose diagonal Psi companion
> raises the per-unit block from `d` to `d + n_traits`; nor with any crossed
> ordinary random effect, which merges the per-unit blocks; nor for any
> phylogenetic or SPDE spatial term, where the latent field is a single
> connected block of size `n_aug_phy · d` or `n_mesh · n_traits`. Missing
> **response** data is orthogonal and carries over unchanged under both
> `drop` and `include`; missing **continuous predictors** enlarge the per-unit
> block and inherit the same limit.

---

## 8. What I could not determine

* **Tweedie / truncated-count integrand *accuracy* at far nodes.** Finiteness
  measured; accuracy not checked against an independent evaluation.
  **UNVERIFIED.**
* **Whether the `spHess(random = TRUE)` component structure is stable away from
  the optimum.** All component analyses above were run at
  `env$last.par.best`. TMB fixes the sparsity pattern structurally at
  construction, so it *should* be `theta`-independent, but I did not
  re-measure at a perturbed `theta`. **UNVERIFIED.**
* **The prior lane's `spHess(theta, random = FALSE)` finding**
  (`aghq-scope-gap.md:159`: structurally zero at cross-block positions that are
  genuinely nonzero) I read but did **not** independently reproduce. If it
  holds, the outer-optimiser gradient chain is a separate unsolved problem on
  top of everything above. **NOT RE-VERIFIED HERE.**
* **Whether any AGHQ-in-a-subspace variant** (quadrature over `z_B` only, with
  `s_B` left at its Laplace approximation) is statistically defensible. That is
  a design question this slice did not attempt, and it is the obvious next one
  if the layer is still wanted.
