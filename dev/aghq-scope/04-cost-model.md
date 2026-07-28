# AGHQ cost model across the family/structure surface

**Scope**: scoping and verification only. No implementation, no accuracy
claim. This document extends the single-family, single-structure cost
scoping already done in the sibling (read-only) worktree
`/private/tmp/gllvmtmb-va-wiring-20260726` (`dev/aghq-scope-cost.md`,
`dev/aghq-verify-cost.md`, adversarially reviewed there and PLAUSIBLE) to the
question this brief actually needs answered: does the AGHQ-as-refinement-
layer premise hold across all 16 families and all structured-RE variants, or
only for the one cell (Bernoulli-logit, ordinary `latent()`, q=2) that was
measured?

**Bottom line up front**: the node-count regime is **not** `k^q` on the
whole random vector. It is **`k^q` per conditionally-independent block**,
and which parameters form a block is structure-dependent. For ordinary
per-unit `latent()`/`indep()` random effects the blocks are small
(dimension = `d` or `n_traits`) and iid across sites, so AGHQ is cheap and
linear in `n_sites`. For phylogenetic and spatial structured random effects
the relevant block is the **entire correlated field** (all `n_species` or
all `n_mesh` nodes at once, because the prior itself is not separable across
units) — naive per-block AGHQ over that block is `k^(n_species·d)` or
`k^(n_mesh·traits)`, which is not merely expensive but computationally
impossible for realistic `n_species`/`n_mesh`. **AGHQ-as-refinement is
therefore NOT a uniform, family/structure-agnostic layer.** It is viable
for the ordinary-latent / iid-block part of the model and not viable, as a
naive per-block quadrature, for the phylogenetic/spatial correlated-field
part. A viable route for the latter (INLA-style: AGHQ over a handful of
hyperparameters, Laplace/GMRF machinery kept for the high-dimensional field
itself) is a fundamentally different, larger project, not a fence
adjustment.

---

## 1. Which node regime applies — read from the TMB `random` declaration

`R/fit-multi.R:4474-4521` builds the `random` character vector passed to
`TMB::MakeADFun()` (`R/fit-multi.R:4541-4547`). Cross-referencing each name
against its `PARAMETER_VECTOR`/`PARAMETER_MATRIX` declaration in
`src/gllvmTMB.cpp` gives the dimension of each random block:

| `random` entry (R/fit-multi.R line) | cpp declaration (src/gllvmTMB.cpp line) | shape | iid across units? |
|---|---|---|---|
| `z_B` (4480) | `PARAMETER_MATRIX(z_B)` (480) | `d_B x n_sites`, "spherical N(0,I)" | **yes** — per-site block |
| `s_B` (4482) | `PARAMETER_MATRIX(s_B)` (491) | `n_traits x n_sites` | **yes** |
| `z_W` (4484) | `PARAMETER_MATRIX(z_W)` (499) | `d_W x n_site_species` | **yes**, per site-species cell |
| `s_W` (4485) | `PARAMETER_MATRIX(s_W)` (503) | `n_traits x n_site_species` | **yes** |
| `u_re_int` (4509) | `PARAMETER_VECTOR(u_re_int)` (603) | `sum(re_int_n_groups)` | **yes**, per group level |
| `p_phy` (4486) | `PARAMETER_MATRIX(p_phy)` (509) | `n_species x n_traits`, prior `MVN(0, exp(loglambda_phy) * Cphy)` (506-509) | **no** — `Cphy` is dense `n_species x n_species` (line 129); the whole `n_species`-vector per trait is one correlated block |
| `g_phy` (4497) | `PARAMETER_MATRIX(g_phy)` (565), prior via sparse `Ainv_phy_rr` (`n_aug_phy x n_aug_phy`, line 297) | `n_aug_phy x d_phy` | **no** — sparse but not block-diagonal at unit scale; whole augmented tree is one correlated block |
| `g_phy_diag` (4498) | `PARAMETER_MATRIX(g_phy_diag)` (571) | `n_aug_phy x n_traits` | **no**, same `Ainv_phy_rr` structure |
| `omega_spde` (4491-4492) | `PARAMETER_MATRIX(omega_spde)` (529), GMRF prior via `spde_M0/M1/M2` (sparse, `n_mesh x n_mesh`, lines 182-184) | `n_mesh x n_traits` | **no** — GMRF neighbourhood structure, not iid per mesh node |
| `omega_spde_lv` / `omega_spde_aug` (4494-4495) | (536, 542) | `n_mesh x K_S` / `n_mesh x n_lhs_cols_spde` | **no**, same GMRF |
| `g_x` (4521, missing-data phylo covariate) | (466) | `n_aug_phy` | **no**, same `Ainv_phy_rr`/`A_proj` sparse-but-coupled structure |
| `x_mis` (4514) | (456) | length = number of missing units | **yes** — each `x_mis(u)` is a scalar Gaussian latent covariate value, conditionally independent given `beta_mi`/`log_sigma_mi` |
| `u_mi_group` (4517) | (459) | `n_group` | **yes**, per group level |

**So both regimes coexist in this codebase, and the dispatch is per random
block, not per model.** For the **iid-block** rows (`z_B`, `s_B`, `z_W`,
`s_W`, `u_re_int`, `x_mis`, `u_mi_group`), the joint density factors over
units (site, site-species cell, group level, or missing observation), so a
per-unit AGHQ quadrature of dimension `d` (the block's own row-count — `d_B`,
`n_traits`, `d_W`, or 1) is a valid refinement: total node cost is
`n_units x k^d`, i.e. **linear in the number of units**, exactly the regime
the sibling worktree's cost scoping measured (its cell was `z_B`-only,
`d_B = q = 2`, `n = n_sites`). That scoping's headline numbers (§3 of
`aghq-scope-cost.md`: ≈22-35 min at Ayumi's n=5397, q=2, CONDITIONAL on an
AD-native gradient existing — which is separately reported there as **not
demonstrated to exist**, with a ~20x finite-difference fallback penalty)
transfer directly to this row of the table and are not re-derived here.

For the **correlated-field** rows (`p_phy`, `g_phy`, `g_phy_diag`,
`omega_spde*`, `g_x`), the prior is a single dense (`Cphy`, `n_species x
n_species`) or GMRF-sparse (`Ainv_phy_rr`, `spde_M0/1/2`) precision over
**all** species or **all** mesh nodes simultaneously — there is no
unit-level factorization to exploit. A literal application of "AGHQ over
the random block" would need `k^(n_species x n_traits)` or `k^(n_mesh x
n_traits)` nodes: for `n_species = 50` and one trait that is already
`k^50`, which is not a large-but-affordable number, it is combinatorially
unreachable at any `k >= 2`. **This is the regime split the brief asked to
settle, and it settles as: naive per-block AGHQ is viable for the iid-block
random effects and impossible for the phylogenetic/spatial correlated-field
random effects.** The only way AGHQ nonetheless touches the correlated-field
part of the model is indirectly, through the *fixed*/hyperparameters that
govern it (`loglambda_phy`, `log_tau_spde`, `log_kappa_spde`, factor
loadings) — those remain part of the FIXED (non-random) parameter vector
already handled by Laplace/quadrature over the small iid blocks; the
correlated field itself would still need to be integrated out by Laplace
(or kept fixed at its conditional mode), not by a literal quadrature grid.
This is architecturally the same move classical INLA makes (AGHQ/grid over
a handful of hyperparameters, nested Laplace over the GMRF field) — but
implementing that nested structure inside `gllvmTMB`'s single joint
`MakeADFun` call is new engineering, not a parameter to an existing
per-unit quadrature loop, and is out of scope for this cost brief to size.

**UNVERIFIED / not settled here**: whether the `Ainv_phy_rr`/`spde_M0-2`
sparsity pattern could support a *nested*-Laplace-style AGHQ variant (AGHQ
over few field hyperparameters + inner Laplace over the field) at
acceptable cost. That is a different, larger design question than "does
AGHQ replace Laplace for the whole random vector," and this brief does not
attempt to size it.

---

## 2. Per-family multipliers (qualitative ordering)

`src/gllvmTMB.cpp:224-243` enumerates all 16 `family_id` values (fid 0-15).
Per-node AGHQ cost is dominated by the cost of one density evaluation (the
`ll +=` term for that `fid`) at a proposed random-effect value, since (per
§1) the mode/Hessian solve is shared across nodes and paid once per block.
Ordering families by expected **marginal per-node evaluation cost**,
qualitatively, from cheapest to most expensive:

| tier | families (fid) | why |
|---|---|---|
| **cheapest** | Gaussian (0), Poisson (2, log-link) | closed-form log-density, no extra per-trait parameter lookup beyond `mu`; Poisson has one `log(y!)`-type term folded into a constant, no dispersion loop |
| **cheap** | Bernoulli/binomial (1), truncated Poisson (10) | closed-form; truncated Poisson adds one `log1p(-exp(-mu))`-type normalizing term per node, still O(1) extra ops |
| **moderate** | Lognormal (3), Gamma (4), NB2 (5), NB1 (15), Beta (7) | each carries **one extra per-trait dispersion parameter** (`log_sigma_eps`/`log_phi_*`/`log_phi_beta`) that must be exponentiated and folded into `lgamma`/`dnorm`-style calls per node; NB2/NB1 also carry a `lgamma(y + 1/phi)`-type term, more expensive than Poisson's, but still O(1) per observation per node |
| **moderate-high** | Beta-binomial (8), truncated NB2 (11) | beta-binomial needs two `lgamma` combinatorial terms (trials, successes) per node in addition to the dispersion parameter; truncated NB2 adds a truncation-normalizing term on top of NB2's own cost |
| **higher** | Tweedie (6) | `dtweedie()` (src/gllvmTMB.cpp:2058) is itself an infinite (or truncated) series/saddlepoint evaluation per observation — **the single most expensive per-node density call among the 16**, multiplying node count and Tweedie-series cost together; a node grid that is otherwise cheap for other families becomes materially more expensive here |
| **higher (structural, not per-observation)** | Delta/hurdle: lognormal (12), gamma (13) | each observation evaluates **two** component densities (Bernoulli presence + lognormal-or-gamma positive part) sharing one linear predictor (src/gllvmTMB.cpp:275-277) — roughly 2x the per-node cost of the single-component family it hurdles, not a new order of complexity |
| **higher (structural, cutpoint loop)** | Ordinal probit (14) | src/gllvmTMB.cpp:2148-2185: a per-trait cutpoint reconstruction loop (`K_t - 2` free increments, cumulative sum, `pnorm` difference) runs **inside** the per-node, per-observation density evaluation; cost scales with `K_t` (number of ordinal categories), so a high-`K` ordinal trait is more expensive per node than any of the continuous/count families above, and this multiplies the already-large per-node grid |
| **highest** | Student-t (9) | per-trait `sigma` **and** a degrees-of-freedom parameter (src/gllvmTMB.cpp:2096-2104 area) — `dt`-style evaluation is the heaviest single closed-form density call in the family list, and (unlike dispersion-only families) an extra hyperparameter (df) also needs its own care if it is ever allowed to vary per node under Laplace-refined uncertainty |

**Caveat, stated as an assumption, not measured**: this ordering is read
directly off the `ll +=` code paths (extra `lgamma`/`pnorm`/series calls per
family) and is a reasonable qualitative ranking, but **no per-family timing
was run** in this brief (out of scope — no fits beyond what already exists
in the sibling worktree). The Tweedie/ordinal/Student-t "highest cost" claim
is AGENT-INFERRED from code-path complexity, not measured; if TMB's AD tape
compiles these branches to comparable machine cost (plausible for the
closed-form ones; less plausible for Tweedie's series and the cutpoint
loop), the spread across tiers could be smaller than implied here.

---

## 3. What phylogeny / spatial SPDE / missing data each do to cost

- **Phylogeny (dense `Cphy`, sparse `Ainv_phy_rr`)**: as established in §1,
  the phylogenetic random effect is a single correlated block over all
  `n_species` (or `n_aug_phy` augmented nodes). It does **not** add a
  per-node multiplier to the iid-block AGHQ cost — it is architecturally
  outside that mechanism entirely under a naive per-block quadrature. Its
  cost impact on an AGHQ-refined fit is therefore not "more expensive nodes"
  but "this random block cannot be quadrature-refined the same way"; it
  either stays fully Laplace (current behaviour, unchanged) or requires the
  separate nested-Laplace engineering noted in §1.
- **Spatial SPDE (sparse `spde_M0/M1/M2`, GMRF over `n_mesh` nodes)**:
  identical structural point to phylogeny — a GMRF is sparse but globally
  coupled through its neighbourhood graph, not block-diagonal at a size
  small enough for per-block quadrature. Same conclusion: outside the naive
  AGHQ mechanism, unchanged from current Laplace behaviour unless a nested
  design is built.
- **Missing data (`x_mis`, `u_mi_group`, `g_x`)**: `x_mis` and `u_mi_group`
  are iid-block latents (§1 table) — each missing unit's `x_mis(u)` and
  each group's `u_mi_group` level is a scalar, conditionally independent
  given the covariate-model fixed effects, so they fall into the cheap
  per-unit AGHQ regime (`d=1` blocks; `k` nodes per missing unit or group
  level, linear in the count of missing units/groups). `g_x` (the
  phylogenetic covariate field) inherits the phylogeny caveat above: it is
  governed by the same `Ainv_phy_rr`/`A_proj` coupled structure and is
  therefore in the correlated-field, not iid-block, category.

---

## 4. What the 3.40x figure does and does not license

The 3.40x cost multiplier (q=2, n=2000, 5 seeds, per the brief's recorded
evidence) and the sibling worktree's more granular §3 table
(`aghq-scope-cost.md`: 2.27x-3.60x at H=5/H=9, q=2, Ayumi's n=5397,
Bernoulli-logit, ordinary `latent()`) are both measurements of **one
family (Bernoulli/Gaussian-adjacent), one structure (ordinary iid-block
`latent()`), one dimension (q=2)**. They license:

- A **within-regime** extrapolation across `n` for the *same* family and
  structure (the ratio model in `aghq-scope-cost.md` §2b-3 is built to do
  exactly this, and its own §3.5 caveat about the AD-native-gradient
  assumption governs how far to trust it).
- **Nothing** about Tweedie, ordinal-probit, or Student-t families, whose
  per-node cost is qualitatively higher (§2) — the 3.40x multiplier is a
  ratio against *that family's* Laplace cost, and both numerator and
  denominator would shift for a costlier family. The ratio itself is not
  guaranteed to transfer; a family with a much more expensive `ll +=` term
  could see the fixed mode-solve cost amortized *worse* (if node cost grows
  faster than solve cost) or *better* (if the solve itself also gets more
  expensive, e.g. via extra dispersion parameters entering the Hessian) —
  the direction is not derivable without measuring that family directly.
- **Nothing** about phylogenetic or spatial structured fits, which are
  outside the measured mechanism per §1/§3, not merely a scaled version of
  it.

**Shape of a defensible extrapolation, with its risk stated**: multiply the
measured per-family-independent ratio (2.27x-3.60x at q=2) by a per-family
cost-tier factor read qualitatively off §2 (e.g. treat Tweedie/ordinal as
"2-4x a baseline family's per-node cost" — not measured, a placeholder for
"materially more, order unknown") to get a rough ceiling, and treat q as a
separate, multiplicative exponent per §1's node-count table already derived
in the sibling worktree (viable at q=1-2, borderline at q=3, dead by q=4).
The compounding risk: two unmeasured multipliers (family-tier factor x
q-exponent) stacked on top of an already-DERIVED single-cell measurement is
a genuinely wide uncertainty band — treat any number from this chain as
order-of-magnitude only, not a plan input.

---

## 5. Fence recommendation

Given §1-4, a concrete, conservative fence:

**Offer AGHQ refinement (with the current architecture) only when ALL of:**

1. The random-effect structure requested is **iid-block only** —
   ordinary `latent()`/`indep()` (site- or site-species-level), simple
   grouped random intercepts (`u_re_int`), and/or a missing-covariate model
   using `x_mis`/`u_mi_group`. **Refuse (not merely warn) when any
   phylogenetic (`phylo_*`), spatial (`spatial_*`/SPDE), or animal-model
   term is present** — these are architecturally outside the per-block
   quadrature mechanism per §1, and offering AGHQ there would silently do
   nothing useful (or worse, silently fall back to a full un-refined
   Laplace while claiming a refinement was applied).
2. The per-unit block dimension is **q <= 2**, warn at q = 3 (borderline,
   node-count dependent per the sibling worktree's §4 table — viable only
   if H=5 nodes prove sufficient, unverified at q=3), refuse at **q >= 4**
   (already worse than the VA baseline at H=5 per the sibling worktree's
   measured cell, before even reaching q=5's multi-hour/multi-day cost).
3. The family is in the cheap-to-moderate tier of §2 (Gaussian, Poisson,
   Bernoulli/binomial, truncated Poisson, Lognormal, Gamma, NB1/NB2, Beta).
   **Warn** for Beta-binomial, truncated NB2, and delta/hurdle families
   (moderate-high/structural-2x tier — likely still affordable but
   unmeasured). **Warn strongly / require explicit opt-in** for Tweedie,
   ordinal-probit (especially high-`K`), and Student-t — the qualitatively
   most expensive per-node evaluations, not measured at all in this brief,
   and stacked on top of an already-uncertain q-scaling.
4. An AD-native gradient path for the AGHQ objective actually exists in the
   implementation being shipped. Per the sibling worktree's §3.5 (checked,
   not found, in this same codebase's `spHess(random=FALSE)` cross-block),
   this is currently the single largest risk to any of the above numbers:
   without it, the finite-difference fallback (~20x) pushes even the
   cheapest, most favourable cell (q=2, Bernoulli) past both measured VA
   baselines. **Do not ship AGHQ as "on by default" or "recommended" until
   this gradient path is built and measured** — ship it, if at all, as an
   explicit opt-in with the cost multiplier surfaced to the user, not a
   silent refinement.

**Be conservative about extrapolating past measured cells.** Everything in
this fence beyond the single measured cell (Bernoulli, ordinary `latent()`,
q=2, n up to ~5400) is qualitative ordering or arithmetic extrapolation, not
new measurement gathered in this brief. Treat the fence itself as a
starting proposal for where to spend the *next* measurement, not a final
gate.

---

## Assumptions and confidence labels

- **MEASURED** (inherited by citation from the sibling worktree, not
  re-run here): §1's iid-block per-unit cost model and the 2.27x-3.60x
  ratios at q=2; the q-scaling viability table (q=1-2 viable, q=3
  borderline, q>=4 dead); the AD-native-gradient absence and ~20x
  finite-difference penalty. All independently re-derivable from that
  worktree's `.rds`/log files per its own adversarial review
  (`aghq-verify-cost.md`, verdict PLAUSIBLE with one confirmed
  characterization error not material to these conclusions).
- **VERIFIED HERE, file:line** (this brief's own contribution): the
  iid-block vs. correlated-field regime split (§1 table), read directly
  from `R/fit-multi.R:4474-4521` and `src/gllvmTMB.cpp` parameter/prior
  declarations — not assumed, not measured by timing, but a structural
  fact about the TMB template that settles which cost model applies to
  which random block.
- **AGENT-INFERRED / qualitative, not measured**: the §2 per-family
  ordering (read from code-path complexity, no timing run); the §4
  extrapolation shape and its compounding-uncertainty warning; the §5
  fence thresholds for families and q not directly measured.
- **UNVERIFIED**: whether a nested (INLA-style) AGHQ-over-hyperparameters
  design could make phylogenetic/spatial fields tractable; this brief
  identifies it as the only structural escape route without sizing it.
