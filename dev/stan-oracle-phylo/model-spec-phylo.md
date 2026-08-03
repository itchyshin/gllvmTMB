# Mathematical specification — phylogenetic reduced-rank latent GLLVM, ordinary Gaussian, long format, loadings-only (`phylo_latent(species, d = K, unique = FALSE)`)

**Purpose.** A complete, self-contained mathematical statement of the phylogenetic
reduced-rank latent model, sufficient to implement it in Stan without ever reading
`gllvmTMB`'s implementation.

**Independence fence.** This document is an **independent oracle**. It was derived only from
the published comparative-methods and GLLVM literature (§11) and from `gllvmTMB`'s
*user-facing* design prose and generated roxygen documentation. **No file under `src/` was
read; no R file that constructs a TMB objective was read** (`R/fit-multi.R`, `R/eva-proto.R`,
`R/aghq-gate.R`, `R/brms-sugar.R` — the last only via its *generated* `man/*.Rd` output,
which is user-facing semantics); **neither `dev/stan-oracle-phylo/tmb-side-phylo.md` nor the
Arc 0 `dev/stan-oracle/tmb-side.R` was read.** It inherits the ordinary-Gaussian structure of
`dev/stan-oracle/model-spec.md` (the Arc 0 spec), which was written under the same fence.
Anything that could not be pinned down without reading the implementation is listed in §12
and must be resolved by *measurement or maintainer statement*, not by inspection.

Author role: Noether (math-vs-specification alignment).
Date: 2026-08-03.

---

## 0. The one thing to read first — the reduced-rank marginal has **no density**

The design prose states the phylogenetic tier marginally,

$$
\mathbf{g}_\text{phy} \sim \mathcal{N}\bigl(\mathbf{0},\ \boldsymbol\Sigma_\text{phy}\otimes A\bigr)
\qquad(\texttt{docs/design/04-random-effects.md}, \texttt{03-phylogenetic-gllvm.md}),
$$

and the roxygen for `phylo_latent()` gives the loadings-only case as
$\boldsymbol\Sigma_\text{phy} = \boldsymbol\Lambda\boldsymbol\Lambda^\top$ (the
$+\,\boldsymbol\Psi_\text{phy}\otimes A$ piece is what `unique = TRUE` adds, and is **out of
scope here**).

**In the loadings-only case that marginal statement is not a usable probability density.**
With $K < T$, $\boldsymbol\Lambda\boldsymbol\Lambda^\top$ has rank $K$, so
$(\boldsymbol\Lambda\boldsymbol\Lambda^\top)\otimes A$ has rank $KS < TS$ and is **singular**.
The $TS$-variate normal it names is degenerate: it is supported on a $KS$-dimensional
subspace and has no Lebesgue density on $\mathbb{R}^{TS}$. There is no number to compare.

This settles the Arc 0 marginal-vs-hierarchical question *a fortiori* for the phylogenetic
case. Arc 0 argued for the hierarchical form on three grounds (it is what the prose defines
generatively; a Laplace engine has no marginal $u$ in its objective; the marginal form
collapses $\Lambda$ into $\Lambda\Lambda^\top$ and hides assembly errors). Here there is a
fourth and decisive ground: **the marginal form does not exist.**

### RESOLUTION (binding for this oracle)

> **The fixed-parameter joint-density check MUST use the HIERARCHICAL form: latent
> phylogenetic factor scores $G$ as an explicit block, with $u = G\Lambda^\top$ formed
> deterministically on the linear predictor.**

Consequences carried over unchanged from Arc 0 §0, and they matter more here:

- The Stan program takes $G$ ($S\times K$) as **input** (data, or parameters held fixed) and
  does **not** integrate it out. The oracle returns $\log p(y, G\mid\theta)$.
- The comparison target must be the joint density *before* Laplace integration, at the same
  fixed $(\theta, G)$.
- **All Gaussian normalising constants are included**, and — new in the phylogenetic case —
  so is the $-\tfrac{K}{2}\log\lvert A\rvert$ term (§8.3). Do not silently drop it because it
  is parameter-free; it is not zero.
- **No Jacobian adjustments.** Densities are on the natural scale
  ($\sigma_\varepsilon>0$, $\lambda_{kk}>0$). Use `target += ..._lpdf(...)`, never `~`.
- The two sides must agree on the **latent parameterisation**. In the phylogenetic case this
  is not a formality: the latent block may be tips-only ($S$ scores per axis) or expanded over
  augmented tree nodes ($\approx 2S-1$ per axis). Those are the *same model* marginally and
  **different joint densities on different sample spaces**. See §8.5 and OPEN item 1.

---

## 1. Data layout and index sets

Long format: **one row per `(species, trait)` observation**
(`docs/design/03-phylogenetic-gllvm.md`, "Reader Problem": "long data: one row per
`(species, trait)` observation"; `docs/design/01-formula-grammar.md`, "Long-format
trait-stacked grammar").

| index | ranges over | meaning |
|---|---|---|
| $i = 1,\dots,N$ | rows of the long data frame | one observation |
| $t = 1,\dots,T$ | traits | which trait row $i$ measures |
| $s = 1,\dots,S$ | species (tree tips) | which species row $i$ belongs to |
| $k = 1,\dots,K$ | phylogenetic latent axes ($K =$ `d`) | latent factor index |

Two index maps are given as data:

$$
t(i)\in\{1,\dots,T\},\qquad s(i)\in\{1,\dots,S\}.
$$

Balance is not required: $N$ need not equal $ST$. In the canonical comparative-methods
layout there is exactly one row per `(species, trait)` and $N = ST$, but the specification
below does not assume it. Every row contributes exactly one data-density term.

**Grouping-axis convention.** Phylogenetic keywords operate on the **cluster axis** (default
column name `species`), not on `unit` (`docs/design/01-formula-grammar.md`, "Phylogenetic axis
convention"). In the model in scope `unit = cluster = species`, which is the case the design
prose calls a *partition of the between-species variance* rather than a separate grouping
level (`docs/design/04-random-effects.md`, "Tier vs partition"). Nothing below depends on that
reading; it matters only for interpretation.

**Species-to-matrix alignment.** The levels of the species factor index the rows and columns
of $A$ in the same order. A permutation mismatch between the factor levels and
`dimnames(A)` silently changes the density (see OPEN item 3); the package's own example
does the alignment by hand
(`factor(sim$data$species, levels = tree$tip.label)`, `man/phylo_latent.Rd` `@examples`).

The model in scope has **no covariates** beyond the trait-specific intercepts:
`value ~ 0 + trait + phylo_latent(species, d = K, tree = tree)` with `unique = FALSE` (the
documented default, `man/phylo_latent.Rd` `\usage`).

---

## 2. Observation model

Family: `gaussian()`, identity link (`docs/design/03-likelihoods.md` §"Gaussian").

$$
y_i \mid \eta_i,\ \sigma_\varepsilon \;\sim\; \mathcal{N}\!\bigl(\eta_i,\ \sigma_\varepsilon^2\bigr),
\qquad i = 1,\dots,N,
$$

independently across rows given the latent variables. Identity link, so $\mu_i=\eta_i$.

**$\sigma_\varepsilon$ is a single scalar shared across all traits and all rows** — not
per-trait — because the model in scope carries no per-row `indep(0 + trait | obs)` term
(`man/gllvmTMB.Rd` §"Per-trait residual variance: when does it activate?"; established in
Arc 0 §2 and unchanged by the phylogenetic term).

Notation convention (`docs/design/03-likelihoods.md` §"Notation"): $\mathcal{N}(a,b)$ takes
**$b$ as a variance**; Stan's `normal_lpdf(y | mu, sigma)` takes an **SD**. Every conversion
is written out.

---

## 3. Linear predictor

$$
\boxed{\;\eta_i \;=\; \mu_{t(i)} \;+\; \sum_{k=1}^{K}\lambda_{t(i),k}\,g_{s(i),k}\;}
$$

equivalently, per `(species, trait)` cell,

$$
\eta_{st} \;=\; \mu_t \;+\; \boldsymbol\lambda_t^\top \mathbf{g}_s,
\qquad
\boldsymbol\lambda_t^\top = (\lambda_{t1},\dots,\lambda_{tK}) = \text{row } t \text{ of } \Lambda ,
$$

where $\mathbf{g}_s = (g_{s1},\dots,g_{sK})^\top$ is species $s$'s vector of phylogenetic
latent scores.

Term by term:

1. **$\mu_t$ — trait-specific intercepts.** `0 + trait` gives $T$ intercepts, no global
   intercept, no contrast coding (`docs/design/01-formula-grammar.md`;
   `docs/design/03-phylogenetic-gllvm.md` "R Syntax Alignment" row *Trait intercepts*). A
   plain length-$T$ unconstrained vector indexed by `t[i]`.
2. **$\boldsymbol\lambda_t^\top\mathbf{g}_s$ — the phylogenetic reduced-rank contribution.**
   This is verbatim the published-facing statement in `man/phylo_rr.Rd` `@details`
   (`phylo_rr` is the deprecated alias of `phylo_latent`, "same engine, new name",
   `man/phylo_latent.Rd` `@description`):
   $$
   p_{it} \;=\; \sum_{k=1}^{d}\Lambda_{\mathrm{phy},tk}\,g_{ik},
   \qquad g_{\cdot k}\sim\mathcal{N}(\mathbf{0},\ \mathbf{A}_{\mathrm{phy}}),
   $$
   with $i$ the species index there. $\Lambda \in \mathbb{R}^{T\times K}$ is
   lower-triangular with positive diagonal (`man/phylo_rr.Rd`: "a lower-triangular
   `n_traits x d` loading matrix"); see §7.
3. **There is no $q$ / $\Psi$ term.** The model in scope is `unique = FALSE`, "the
   loadings-only / rotation-invariant subset" (`man/phylo_latent.Rd` `@arguments`). This is
   the documented default for source-specific latent terms (`CLAUDE.md`, "Source-specific and
   kernel latent terms are loadings-only by default"), in deliberate contrast to ordinary
   `latent()`, which carries its diagonal $\Psi$ companion by default. **This single flag is
   the whole difference in the latent block between this spec and Arc 0's.**

Define the species-level random-effect matrix $U \in \mathbb{R}^{S\times T}$ by

$$
U \;=\; G\Lambda^\top,\qquad u_{st}=\boldsymbol\lambda_t^\top\mathbf g_s,
\qquad \eta_{st}=\mu_t+u_{st},
$$

with $G\in\mathbb{R}^{S\times K}$ the matrix of latent scores ($G_{sk}=g_{sk}$).

**With covariates (out of scope, for completeness):** $\eta_i = x_i^\top\beta +
\boldsymbol\lambda_{t(i)}^\top\mathbf g_{s(i)}$ with $x_i^\top\beta$ built from
`0 + trait + (0 + trait):x`. Nothing in §4–§8 changes.

---

## 4. How the phylogeny enters — the central question

### 4.1 The three candidate assemblies

Let $A\in\mathbb{R}^{S\times S}$ be the known phylogenetic relatedness matrix (§5).

- **(i) Phylogeny along species, independently within each latent axis.**
  $$
  g_{\cdot k}\;\stackrel{\text{indep}}{\sim}\;\mathcal{N}_S(\mathbf 0,\ A),\quad k=1,\dots,K,
  \qquad U = G\Lambda^\top .
  $$
- **(ii) Phylogeny along species with a free between-axis covariance.**
  $$
  \operatorname{vec}(G)\sim\mathcal{N}_{SK}\bigl(\mathbf 0,\ \Sigma_\text{axis}\otimes A\bigr),
  \qquad \Sigma_\text{axis}\in\mathbb{R}^{K\times K}\ \text{free p.d.}
  $$
- **(iii) Some other assembly** — e.g. a direct $TS$-variate statement on
  $\operatorname{vec}(U)$ with covariance $\Sigma_\text{phy}\otimes A$, or an assembly in
  which $A$ acts on the *axes* rather than the species.

### 4.2 RESOLUTION

> **The published formulation implies (i).** The phylogeny acts **along species, within each
> latent axis, with the axes independent and unit-scaled**; the loadings matrix carries all
> trait-level and all scale information.

Three independent reasons:

1. **It is what the documentation states, symbol for symbol.** `man/phylo_rr.Rd` `@details`
   writes $g_{\cdot k}\sim\mathcal N(\mathbf 0,\mathbf A_\mathrm{phy})$ — one $S$-variate
   normal *per axis*, covariance exactly $A$, no per-axis scale, no between-axis covariance.
   `man/phylo_latent.Rd` `@arguments` writes the assembled result as
   $\boldsymbol\Sigma_\text{phy}=\boldsymbol\Lambda\boldsymbol\Lambda^\top\otimes\mathbf A$
   ($+\,\boldsymbol\Psi_\text{phy}\otimes\mathbf A$ under `unique = TRUE`), which is precisely
   what (i) induces (§4.3). This is the same structure the ordinary GLLVM uses with
   $z_\ell\sim\mathcal N_K(\mathbf 0, I_K)$ (Arc 0 §4.1), with $I_S$ replaced by $A$ on the
   species axis.
2. **(ii) is not a different model — it is an unidentified reparameterisation of (i).**
   Under (ii), $\operatorname{Cov}(G_{sk},G_{s'k'}) = (\Sigma_\text{axis})_{kk'}A_{ss'}$, so
   $$
   \operatorname{Cov}(u_{st},u_{s't'})
   = \sum_{k,k'}\lambda_{tk}\lambda_{t'k'}(\Sigma_\text{axis})_{kk'}A_{ss'}
   = \bigl(\Lambda\Sigma_\text{axis}\Lambda^\top\bigr)_{tt'}A_{ss'} ,
   $$
   and $\Lambda\Sigma_\text{axis}\Lambda^\top=\tilde\Lambda\tilde\Lambda^\top$ with
   $\tilde\Lambda=\Lambda\Sigma_\text{axis}^{1/2}$. Every model in family (ii) is a model in
   family (i) with relabelled loadings. Estimating $\Sigma_\text{axis}$ alongside $\Lambda$
   adds $K(K+1)/2$ parameters and removes exactly that many degrees of identifiability. It is
   the same $(\Lambda,\operatorname{Var}(z))\mapsto(\Lambda C^{-1}, C\operatorname{Var}(z)C^\top)$
   indeterminacy that forces $\operatorname{Var}(z)=I_K$ in the ordinary GLLVM (Arc 0 §6.1).
   **(ii) must therefore be rejected on identifiability grounds, not merely on convention.**
3. **The (iii) variants are ruled out.** The direct $TS$-variate statement on
   $\operatorname{vec}(U)$ is the marginal form and is **degenerate** at $K<T$ (§0) — it is a
   correct description of the induced covariance and not a density. An assembly with $A$
   acting on the axes is dimensionally impossible ($A$ is $S\times S$, the axis index runs to
   $K$). No third live candidate remains.

**Reading of the design prose's marginal statement.** `docs/design/04-random-effects.md`'s
$\mathbf g_\text{phy}\sim\mathcal N(\mathbf 0,\boldsymbol\Sigma_\text{phy}\otimes A)$ is the
*induced covariance* of the assembled species-level effect, i.e. a **derived read-out** (what
`extract_Sigma(level = "phy")` reports), not the sampling statement. This is exactly the
role Arc 0 §3 assigned to $\Sigma_\text{unit}=\Lambda\Lambda^\top+\Psi$.

### 4.3 The induced covariance — the Kronecker expression

Fix the vectorisation convention: $\operatorname{vec}$ stacks **columns**, so
$\operatorname{vec}(G)$ runs species-fastest within axis, and $\operatorname{vec}(U)$ runs
species-fastest within trait.

Under (i), $\operatorname{Cov}(\operatorname{vec}(G)) = I_K\otimes A$. Since
$U = G\Lambda^\top$,

$$
\operatorname{vec}(U)=\operatorname{vec}\bigl(I_S\,G\,\Lambda^\top\bigr)=(\Lambda\otimes I_S)\operatorname{vec}(G),
$$

hence

$$
\boxed{\;
\operatorname{Cov}\bigl(\operatorname{vec}(U)\bigr)
=(\Lambda\otimes I_S)(I_K\otimes A)(\Lambda^\top\otimes I_S)
=\bigl(\Lambda\Lambda^\top\bigr)\otimes A
\;=\;\boldsymbol\Sigma_\text{phy}\otimes A ,
\qquad \boldsymbol\Sigma_\text{phy}=\Lambda\Lambda^\top .}
$$

Elementwise:

$$
\operatorname{Cov}(u_{st},\,u_{s't'})=\bigl(\Lambda\Lambda^\top\bigr)_{tt'}\;A_{ss'} .
$$

This reproduces `man/phylo_latent.Rd`'s
$\boldsymbol\Sigma_\text{phy}=\boldsymbol\Lambda\boldsymbol\Lambda^\top\otimes\mathbf A$
exactly, and the `unique = TRUE` extension
$+\,\boldsymbol\Psi_\text{phy}\otimes\mathbf A$ drops out of the same algebra by adding an
independent $q_{\cdot t}\sim\mathcal N_S(\mathbf 0,\psi_{\text{phy},t}A)$ block — which is
**not** part of the model in scope.

**Ordering caveat.** With row-stacking (trait-fastest) instead, the same law reads
$A\otimes\Lambda\Lambda^\top$. The two differ by a permutation, not by content; any harness
that transports covariance matrices between implementations must fix the convention first.

**Separability.** The structure is *separable*: one Kronecker factor per axis (traits ×
species), with the trait factor low-rank and the species factor known and fixed. Note the
model has **no free phylogenetic variance parameter**: the entire phylogenetic variance of
trait $t$ is $(\Lambda\Lambda^\top)_{tt}$. A separate $\sigma^2_\text{phy}$ multiplying $A$
would be exactly non-identified against $\Lambda$ (see OPEN item 4).

**Marginal implication for the data.** Integrating $G$ out (for reference only — the check
does not do this), the observations at one species pair $(s,s')$ satisfy
$$
\operatorname{Cov}(y_{st},y_{s't'})=(\Lambda\Lambda^\top)_{tt'}A_{ss'}+\sigma_\varepsilon^2\,
\mathbb 1\{s=s',\,t=t',\,\text{same row}\},
$$
i.e. $\operatorname{Cov}(\operatorname{vec}(Y))=(\Lambda\Lambda^\top)\otimes A+\sigma_\varepsilon^2 I$
in the balanced one-row-per-cell case. The per-trait phylogenetic signal is then
$H^2_t=(\Lambda\Lambda^\top)_{tt}\big/\bigl[(\Lambda\Lambda^\top)_{tt}+\sigma_\varepsilon^2\bigr]$,
which is the loadings-only special case of
`docs/design/13-phylo-signal-partition.md` §1 (there,
$\Sigma_\text{phy}=\Lambda_\text{phy}\Lambda_\text{phy}^\top+\operatorname{diag}(\psi_\text{phy})$
with the second piece absent here).

---

## 5. $A$ must be a **correlation** matrix, and why

**Statement.** $A$ is the phylogenetic **correlation** matrix: symmetric, positive definite,
with **unit diagonal** $A_{ss}=1$. The package's documented construction is
`ape::vcv(tree, corr = TRUE)` (`docs/design/01-formula-grammar.md` §"Phylogenetic axis
convention"; every `phylo_*` `@examples` block uses `vcv(tree, corr = TRUE)`), and the `vcv =`
/ `A =` arguments are documented as "a tip-only phylogenetic **correlation** matrix"
(`man/phylo_latent.Rd`, `man/phylo_dep.Rd`, `man/phylo_indep.Rd`, `man/phylo_unique.Rd`,
`man/phylo_scalar.Rd`).

**Why it matters for identifiability of the phylogenetic variance.**

1. **Global scale is exactly confounded with $\Lambda$.** For any $c>0$, replacing
   $A\mapsto cA$ and $\Lambda\mapsto c^{-1/2}\Lambda$ leaves
   $(\Lambda\Lambda^\top)\otimes A$ — and hence the entire marginal law, and (after the
   matching change $G\mapsto c^{1/2}G$) the joint density — unchanged. Only $A$'s *shape* is
   estimable; its scale must be fixed by fiat. Unit diagonal is that fiat.
2. **On an ultrametric tree the confounding is total.** $\operatorname{vcv}(\text{tree})$ has
   constant diagonal equal to root-to-tip depth, so the raw $A$ differs from the correlation
   matrix by a *pure* scalar. Feeding the unscaled matrix rescales every reported loading by
   $\sqrt{\text{depth}}$ with no other consequence — a silent units error that no diagnostic
   will flag.
3. **On a non-ultrametric tree it is worse than a scale error.** There $A_{ss}$ varies across
   tips, so a non-unit diagonal makes the *implied trait variance species-specific*:
   $\operatorname{Var}(u_{st})=(\Lambda\Lambda^\top)_{tt}A_{ss}$. That is a substantively
   different model (heteroscedastic across species) usually adopted by accident rather than
   by choice.
4. **$H^2$ is only interpretable with $A_{ss}=1$.** The phylogenetic-signal numerator in
   `docs/design/13-phylo-signal-partition.md` is $\Sigma_\text{phy}[t,t]$; it equals a
   variance proportion only when the species factor contributes $A_{ss}=1$.

**Practical corollary for the oracle.** Supply $A$ as `data`, already unit-diagonal, and pass
the *same numerical matrix* to both sides. Do not let either side re-derive $A$ from the tree
independently: `corr = TRUE` scaling, tip ordering, and floating-point Cholesky can all
differ. $A$ is a fixed input, not a modelled object.

---

## 6. Fixed parameters

$$
\theta=\bigl(\ \mu_1,\dots,\mu_T,\ \ \Lambda,\ \ \sigma_\varepsilon\ \bigr).
$$

Support: $\mu_t\in\mathbb R$; $\Lambda\in\mathbb R^{T\times K}$ subject to §7;
$\sigma_\varepsilon>0$.

| block | count |
|---|---|
| intercepts $\mu$ | $T$ |
| loadings $\Lambda$ | $TK-\tfrac{K(K-1)}{2}$ |
| residual SD $\sigma_\varepsilon$ | $1$ |
| **total** | $T+TK-\tfrac{K(K-1)}{2}+1$ |

Note what is **absent** relative to Arc 0: there is no $\psi$ block (loadings-only), and
there is no phylogenetic variance or scale parameter (§4.3). $A$ is **data**, not a
parameter — nothing in §8 differentiates through it.

**No priors.** This is a likelihood specification; adding any prior changes the number being
compared.

---

## 7. Identifiability constraints on $\Lambda$

Exactly the standard factor-analytic set, unchanged by the phylogeny. Keep requirement and
convention separate.

### 7.1 REQUIREMENT — the latent scale is fixed by $A$ having unit diagonal

In the ordinary GLLVM the requirement is $\operatorname{Var}(z_\ell)=I_K$ (Arc 0 §6.1). Here
the corresponding statement is $\operatorname{Cov}(\operatorname{vec}(G))=I_K\otimes A$ with
$\operatorname{diag}(A)=\mathbf 1$: **no free per-axis variance and no free between-axis
covariance** (§4.2 reason 2), and **no free overall scale on $A$** (§5 reason 1). Without
this the model is unidentified at the first order. **Must be imposed. Already imposed in
§4.2/§5.**

### 7.2 CONVENTION — the rotation constraint

An orthogonal rotation indeterminacy remains, exactly as in the ordinary case. For any
$K\times K$ orthogonal $Q$,

$$
\Lambda\mapsto\Lambda Q,\qquad G\mapsto GQ
$$

leaves $U=G\Lambda^\top$, hence $\eta$, hence the likelihood, unchanged; it also leaves the
latent law invariant, since
$\operatorname{Cov}(\operatorname{vec}(GQ))=(Q^\top\otimes I_S)(I_K\otimes A)(Q\otimes I_S)=I_K\otimes A$,
and it leaves $\Lambda\Lambda^\top$ (hence $\Sigma_\text{phy}$) unchanged. **The presence of
$A$ does not break rotation invariance**: $A$ acts on the species index, $Q$ on the axis
index, and the two Kronecker factors do not interact.

`gllvmTMB` resolves this the standard factor-analytic way (`man/phylo_rr.Rd`:
"lower-triangular `n_traits x d` loading matrix"; `docs/design/04-random-effects.md`
§"Internal parameterisation" and §"Numerical scales and constraints", citing the
`glmmTMB::rr()` parameterisation of McGillycuddy et al. 2025; Niku et al. 2019 for the
zero-upper-triangle/positive-diagonal convention):

- $\lambda_{tk}=0$ for $k>t$ when $t\le K$ (the $K(K-1)/2$ upper-triangular entries of the
  leading block are zero);
- $\lambda_{kk}>0$ (held on the log scale internally — an *implementation* detail, not part
  of the density);
- all remaining entries unconstrained real.

**This is a convention**: it selects one representative per rotation orbit. It never changes
the likelihood, $\Lambda\Lambda^\top$, or any fitted quantity.

> **Explicitly out of scope: whether the implementation enforces any of this.** This document
> states what the published formulation requires and what convention the user-facing prose
> says is adopted. Whether `src/` actually imposes the zero upper triangle, the positive
> diagonal, or the $K<T$ gate is a **separate question that this oracle does not answer and
> must not be read as answering.** It is answerable by measurement (fit and inspect the
> reported $\Lambda$) or by maintainer statement.

**For the check, concretely:** feed $\Lambda$ as a plain $T\times K$ `matrix` in `data`; do
**not** use a constrained Stan type (`cholesky_factor_*`, `positive_ordered`), which would
change the measure. And if the two sides use different rotation conventions, transport
$(\Lambda, G)$ **jointly**: $\Lambda\to\Lambda Q$ **requires** $G\to GQ$. Rotating one and not
the other changes $\eta$ and therefore the joint density, even though the marginal likelihood
would be unchanged.

### 7.3 CONVENTION (weaker) — column sign

Negating column $k$ of $\Lambda$ and column $k$ of $G$ together is invariant; the positive
diagonal in §7.2 fixes it. Purely a labelling choice.

### 7.4 REQUIREMENTS on rank and on the data

- **$K<T$.** Required for the rotation-resolution constraint to bind and for the loadings
  matrix not to be over-parameterised (`docs/design/04-random-effects.md` §"Rank deficiency"
  states the engine rejects $K\ge T$ for `latent()`; whether the same gate is applied to
  `phylo_latent()` is OPEN item 6). The density is well-defined at $K\ge T$; do not evaluate
  there anyway.
- **$A\ne I_S$ is required for the phylogenetic term to be distinguishable from a
  non-phylogenetic species effect.** At $A=I_S$ the model collapses to the ordinary
  loadings-only GLLVM and "phylogenetic" has no content. Weak phylogenetic signal is the
  practical version of this and is the documented reason level-3 identifiability (the split
  into $\Lambda\Lambda^\top$ and $\Psi$) is fragile
  (`docs/design/03-phylogenetic-gllvm.md` §"Identifiability Guidance";
  `docs/design/04-random-effects.md` §"Phylogenetic identifiability levels"). **Irrelevant to
  a fixed-parameter density check**, essential context for any recovery study on top of it.
- **With one row per `(species, trait)`, $\sigma_\varepsilon^2 I$ is the only non-phylogenetic
  variance.** It is identified as a scalar (it is shared, §2), but it plays the role a
  non-phylogenetic diagonal would; a per-trait residual would require the per-row `indep`
  term the model in scope does not have. Replication within species is what separates them.
- **Positivity.** $\sigma_\varepsilon>0$; $A$ positive definite. Choose fixed values well away
  from the boundary.

### 7.5 What is NOT constrained

$\mu$ is unconstrained (no sum-to-zero, no reference level — the grammar is `0 + trait`); $G$
is an unconstrained real matrix as an *input* to the check; and there is no constraint linking
$\Lambda$ to $A$.

---

## 8. The full joint log-density

### 8.1 Statement (tips-only latent block — the published formulation)

Let $\theta=(\mu,\Lambda,\sigma_\varepsilon)$ as in §6, let $A$ be the fixed $S\times S$
correlation matrix of §5, and let $G\in\mathbb R^{S\times K}$ be the fixed latent input. With

$$
\eta_i=\mu_{t(i)}+\boldsymbol\lambda_{t(i)}^\top\mathbf g_{s(i)},
$$

the joint log-density is the sum of **two** density terms:

$$
\boxed{
\begin{aligned}
\log p\bigl(y, G\mid\theta; A\bigr)
=\;&\underbrace{\sum_{i=1}^{N}\left[-\tfrac12\log(2\pi)-\log\sigma_\varepsilon
      -\frac{(y_i-\eta_i)^2}{2\sigma_\varepsilon^2}\right]}_{\text{(D) data / Gaussian observation term},\ N\ \text{terms}}\\[4pt]
&+\underbrace{\sum_{k=1}^{K}\left[-\tfrac{S}{2}\log(2\pi)-\tfrac12\log\lvert A\rvert
      -\tfrac12\,g_{\cdot k}^\top A^{-1} g_{\cdot k}\right]}_{\text{(G) phylogenetic latent-score term},\ K\ \text{multivariate terms}}
\end{aligned}}
$$

The (G) block written compactly:

$$
\text{(G)}=-\tfrac{SK}{2}\log(2\pi)\;-\;\tfrac{K}{2}\log\lvert A\rvert\;-\;\tfrac12\operatorname{tr}\!\bigl(G^\top A^{-1}G\bigr).
$$

**Number of distinct density terms in the joint: 2** — one data term (D) and one latent
term (G). This is itself a tripwire: the ordinary `latent()` model of Arc 0 has **3** (data,
$z$, $q$); adding `unique = TRUE` to `phylo_latent()` would restore a third,
$q_{\cdot t}\sim\mathcal N_S(\mathbf 0,\psi_{\text{phy},t}A)$; and the degenerate marginal
form of §0 has 2 but is not evaluable. Counting terms is a cheap first check that both sides
are speaking about the same model.

### 8.2 Equivalent Stan form

```stan
// L_A is the lower Cholesky factor of A, supplied as data: A = L_A * L_A'
target += normal_lpdf(y | eta, sigma_eps);                    // (D)
for (k in 1:K)
  target += multi_normal_cholesky_lpdf(col(G, k) | zeros_S, L_A);   // (G)
```

`multi_normal_cholesky_lpdf` contributes $-\tfrac S2\log 2\pi-\sum_s\log (L_A)_{ss}
-\tfrac12\lVert L_A^{-1}g_{\cdot k}\rVert^2$, and
$\sum_s\log(L_A)_{ss}=\tfrac12\log\lvert A\rvert$ — i.e. exactly the $k$-th summand of (G).
Use `_lpdf` (constants kept), never the `~` shorthand.

### 8.3 The log-determinant of $A$ — does it depend on the parameters?

**No.** $\log\lvert A\rvert$ enters the joint exactly once per latent axis, with coefficient
$-K/2$, and $A$ is **data**: it is built from the tree before fitting and never modified.
Therefore:

- It is **constant in $\theta$ and in $G$**. It cancels from every likelihood *ratio*, from
  every score, and from every Hessian; it is invisible to the optimiser.
- It is **not zero**, and it is **not a $2\pi$-type constant**. For a correlation matrix with
  any real phylogenetic structure $\lvert A\rvert<1$, so $-\tfrac K2\log\lvert A\rvert>0$,
  often substantially: for a moderately balanced tree of $S=20$ tips it is routinely of order
  $+5$ to $+20$ per axis. An absolute joint-density comparison that drops it will disagree by
  a large, structured amount that looks nothing like a rounding error.
- Consequently, **if the comparison target is an optimiser-oriented objective, it is a real
  possibility that it omits this term as an irrelevant constant.** This is the single most
  likely benign source of absolute disagreement. Diagnose it, do not assume it: the omission
  is exactly $-\tfrac K2\log\lvert A\rvert$, computable from the data alone.
- Contrast with a model where the phylogeny carries a free scale: if the latent law were
  $\mathcal N(\mathbf 0,\sigma^2_\text{phy}A)$, the determinant term would be
  $-\tfrac S2\log\sigma^2_\text{phy}-\tfrac12\log\lvert A\rvert$ per axis and the **first
  half would be parameter-dependent**. In the model in scope there is no such $\sigma^2$
  (§4.3, §6), which is why the whole determinant is constant. If a
  parameter-dependent determinant shows up on the other side, that is evidence of an extra
  scale parameter and is a finding, not a nuisance (OPEN item 4).

### 8.4 Constant offset, if the comparison target drops constants

$$
C \;=\; -\tfrac12\bigl(N+SK\bigr)\log(2\pi)\;-\;\tfrac K2\log\lvert A\rvert .
$$

A target dropping *all* constants returns $\log p - C$; one keeping $2\pi$ but dropping the
determinant differs by $-\tfrac K2\log\lvert A\rvert$; one keeping the determinant but
dropping $2\pi$ differs by $-\tfrac12(N+SK)\log 2\pi$. The three cases are numerically
distinguishable, so the offset is diagnosable rather than guessable.

**Do the constant-free comparison first.** Evaluate both sides at two different
$(\theta, G)$ and check that the **difference of differences** is zero. That isolates every
$\theta$- and $G$-dependent term and is immune to all of the above. Only then chase an
absolute match.

### 8.5 The augmented-node variant (same model, different sample space)

The Hadfield & Nakagawa (2010) sparse-$A^{-1}$ construction that the package documents
(`man/phylo_rr.Rd` `@details`: "builds the sparse inverse $\mathbf A_\mathrm{phy}^{-1}$ over
tips + internal nodes natively … and evaluates the prior through the quadratic form
$g^\top\mathbf A_\mathrm{phy}^{-1}g$"; `docs/design/04-random-effects.md`: "$A$ is dense … but
$A^{-1}$ is sparse when the tree has many internal nodes") is **not** in general a statement
about the $S\times S$ tip matrix. The inverse of the tip-only phylogenetic covariance is
generically **dense**; sparsity appears only when the latent vector is expanded over all tree
nodes.

The expanded representation is standard Brownian motion on a tree. Index all non-root nodes
$v\in\mathcal V$ (for a rooted bifurcating tree with $S$ tips, $\lvert\mathcal V\rvert=2S-2$
non-root nodes, or $2S-1$ including the root), with parent $p(v)$ and branch length $b_v$ on
the same scale that makes root-to-tip depth $1$. Then

$$
a_{vk}\mid a_{p(v),k}\ \sim\ \mathcal N\bigl(a_{p(v),k},\ b_v\bigr),\qquad a_{\text{root},k}\equiv 0,
$$

independently across $k$, and the tip subvector has marginal law exactly
$\mathcal N_S(\mathbf 0, A)$. Its log-density is

$$
\log p(a_{\cdot k}) = \sum_{v\in\mathcal V}\left[-\tfrac12\log(2\pi)-\tfrac12\log b_v-\frac{(a_{vk}-a_{p(v),k})^2}{2 b_v}\right],
$$

which is the sparse quadratic form (the precision is tree-structured, with nonzeros only on
parent–child pairs). $\eta$ then reads $g_{sk}=a_{\text{tip}(s),k}$.

**These two representations define the same model and give different joint densities.** They
are on sample spaces of different dimension ($SK$ vs $\approx(2S-2)K$); §8.1 evaluated at the
tip values is *not* equal to §8.5 evaluated at any completion of them. `docs/design/106-va-structural-extension.md`
§2 asserts, as design prose, that "`phylo_*` levels are augmented tree nodes, not species"
with `n_aug_phy = nrow(Ainv)`, and that on the `tree =` route the precision "carries internal
nodes as well as tips" — but that is an implementation-facing claim this oracle does not
verify and does not rely on. **Which representation the comparison target uses is OPEN item 1
and must be settled before any pointwise comparison is trusted.**

If the target is augmented and the oracle is tips-only, the check is still salvageable three
ways, in decreasing order of preference:
(a) run the comparison on the dense `vcv =` / `A =` route, if that route is tips-only
(OPEN item 2); (b) implement §8.5 in Stan too, given the branch lengths and parent map, and
fix the *internal-node* values as well (this is fully specified above, so it is oracle work,
not source-reading); (c) fall back to comparing marginal likelihoods after integration, at
the cost of the discriminating power argued in §0.

### 8.6 What the marginal form would give (reference only — not evaluable here)

$$
\log p(y,\operatorname{vec}(U)\mid\theta)=\sum_i\log\phi\bigl(y_i;\ \mu_{t(i)}+u_{s(i),t(i)},\ \sigma_\varepsilon^2\bigr)
+\log\phi_{TS}\bigl(\operatorname{vec}(U);\ \mathbf 0,\ (\Lambda\Lambda^\top)\otimes A\bigr).
$$

The second term does not exist at $K<T$ (§0). Included only to name the trap.

---

## 9. Symbol table

| Symbol | Meaning | Dimension | Support / constraint |
|---|---|---|---|
| $N$ | number of long-format rows | scalar | positive integer |
| $T$ | number of traits | scalar | integer $\ge 2$ |
| $S$ | number of species (tree tips) | scalar | positive integer |
| $K$ (`d`) | phylogenetic latent rank | scalar | integer, $1\le K<T$ |
| $y_i$ | response for row $i$ | $N$ | $\mathbb R$ |
| $t(i)$ | trait index of row $i$ | $N$ | $\{1,\dots,T\}$ |
| $s(i)$ | species index of row $i$ | $N$ | $\{1,\dots,S\}$ |
| $\mu_t$ | trait-specific intercept | $T$ | $\mathbb R$ (unconstrained; no reference level) |
| $\Lambda=(\lambda_{tk})$ | phylogenetic loadings matrix | $T\times K$ | $\lambda_{tk}=0$ for $k>t,\ t\le K$; $\lambda_{kk}>0$; else $\mathbb R$ (§7.2, convention) |
| $\boldsymbol\lambda_t$ | loadings of trait $t$ (row $t$ of $\Lambda$) | $K$ | as above |
| $\sigma_\varepsilon$ | residual SD, **shared across all traits and rows** | scalar | $>0$ |
| $A$ | phylogenetic **correlation** matrix over tips | $S\times S$ | symmetric p.d., $A_{ss}=1$; **data**, not a parameter |
| $L_A$ | lower Cholesky factor, $A=L_AL_A^\top$ | $S\times S$ | lower triangular, $(L_A)_{ss}>0$ |
| $A^{-1}$ | phylogenetic precision over tips | $S\times S$ | symmetric p.d.; generically dense (§8.5) |
| $\log\lvert A\rvert$ | log-determinant | scalar | $\le 0$ for a correlation matrix; **parameter-free** (§8.3) |
| $g_{sk}$ | phylogenetic latent score, species $s$, axis $k$ | $S\times K$ ($=G$) | $\mathbb R$; $g_{\cdot k}\sim\mathcal N_S(\mathbf 0,A)$, independent across $k$ |
| $u_{st}$ | species-level random effect $=\boldsymbol\lambda_t^\top\mathbf g_s$ | $S\times T$ ($=U=G\Lambda^\top$) | derived; $\operatorname{Cov}(\operatorname{vec}U)=(\Lambda\Lambda^\top)\otimes A$ |
| $\eta_i$ | linear predictor for row $i$ | $N$ | derived, $\mathbb R$ |
| $\Sigma_\text{phy}$ | $\Lambda\Lambda^\top$ (loadings-only; no $\Psi_\text{phy}$) | $T\times T$ | derived; PSD of rank $K<T$ — **singular** |
| $H^2_t$ | phylogenetic signal for trait $t$ | $T$ | $(\Lambda\Lambda^\top)_{tt}/[(\Lambda\Lambda^\top)_{tt}+\sigma_\varepsilon^2]$ in the balanced case |
| $\theta$ | $(\mu,\Lambda,\sigma_\varepsilon)$ | — | §6 |
| $C$ | $-\tfrac12(N+SK)\log 2\pi-\tfrac K2\log\lvert A\rvert$ | scalar | §8.4 |
| $\mathcal V,\ p(v),\ b_v$ | non-root nodes, parent map, branch lengths (augmented variant only) | $\lvert\mathcal V\rvert\approx 2S-2$ | $b_v>0$ (§8.5) |
| $a_{vk}$ | node-level BM value (augmented variant only) | $\lvert\mathcal V\rvert\times K$ | $\mathbb R$ (§8.5) |

---

## 10. Minimal reference implementation sketch (Stan, fixed-parameter oracle)

```stan
data {
  int<lower=1> N; int<lower=2> T; int<lower=1> S; int<lower=1> K;
  array[N] int<lower=1,upper=T> tt;      // trait index per row
  array[N] int<lower=1,upper=S> ss;      // species index per row
  vector[N] y;
  matrix[S, S] L_A;                      // lower Cholesky of the CORRELATION matrix A
  // fixed parameters
  vector[T] mu;
  matrix[T, K] Lambda;                   // plain matrix: NO constrained type
  real<lower=0> sigma_eps;               // shared residual SD
  // fixed latent values
  matrix[S, K] G;                        // phylogenetic latent scores, species x axis
}
transformed data {
  vector[S] zeros_S = rep_vector(0, S);
}
generated quantities {
  real lp;
  real lp_data;
  real lp_phylo;
  {
    vector[N] eta;
    for (i in 1:N)
      eta[i] = mu[tt[i]] + dot_product(Lambda[tt[i]], G[ss[i]]);
    lp_data = normal_lpdf(y | eta, sigma_eps);
    lp_phylo = 0;
    for (k in 1:K)
      lp_phylo += multi_normal_cholesky_lpdf(col(G, k) | zeros_S, L_A);
    lp = lp_data + lp_phylo;
  }
}
```

Everything is `data`; nothing is a `parameter`; therefore no constraint Jacobians exist and
`lp` is exactly the boxed expression of §8.1. Reporting `lp_data` and `lp_phylo` **separately**
is deliberate: the term-count tripwire of §8.1 and the determinant question of §8.3 are both
diagnosed from the split, not from the total. If the comparison disagrees, the first question
is always *which block*.

---

## 11. Sources used

**Repository design prose and generated documentation (user-facing semantics only):**

- `man/phylo_rr.Rd` `@details` — **the decisive statement**:
  $p_{it}=\sum_k\Lambda_{\mathrm{phy},tk}g_{ik}$ with
  $g_{\cdot k}\sim\mathcal N(\mathbf 0,\mathbf A_\mathrm{phy})$; "lower-triangular
  `n_traits x d` loading matrix"; the Hadfield–Nakagawa sparse $A^{-1}$ "over tips + internal
  nodes"; the dense `phylo_vcv` fallback.
- `man/phylo_latent.Rd` — `phylo_rr` is the same engine renamed; `unique = FALSE` is the
  default and "preserves the loadings-only / rotation-invariant subset"; the folded form
  $\boldsymbol\Sigma_{phy}=\boldsymbol\Lambda\boldsymbol\Lambda^\top\otimes\mathbf A+\boldsymbol\Psi_{phy}\otimes\mathbf A$;
  `tree =` canonical, `vcv =`/`A =`/`Ainv =` alternatives; `@examples` uses
  `ape::vcv(tree, corr = TRUE)` and aligns species levels to `tree$tip.label`.
- `man/phylo_dep.Rd`, `man/phylo_indep.Rd`, `man/phylo_unique.Rd`, `man/phylo_scalar.Rd` —
  `vcv =` documented uniformly as "a tip-only phylogenetic **correlation** matrix".
- `docs/design/04-random-effects.md` — §"Phylogenetic random effects":
  $\mathbf g_\text{phy}\sim\mathcal N(\mathbf 0,\Sigma_\text{phy}\otimes A)$, $A$ the
  correlation matrix, $A^{-1}$ sparse via internal nodes; §"Tier vs partition"; §"`phylo_latent
  + phylo_unique` paired decomposition"; §"Numerical scales and constraints" (log-scale
  $\lambda_{kk}$, lower-triangular off-diagonals, log-scale $\sigma^2_\text{phy}$);
  §"Phylogenetic identifiability levels"; §"Rank deficiency".
- `docs/design/03-phylogenetic-gllvm.md` — the mathematical contract
  `g_phy ~ MVN(0, Sigma_phy x A)`, `Sigma_phy = Lambda_phy Lambda_phy^T + Psi_phy`; the
  long-format "one row per `(species, trait)`" reader layout; the three-piece fallback; the
  three identifiability levels.
- `docs/design/01-formula-grammar.md` — §"Phylogenetic axis convention" (`phylo_*` act on the
  **cluster** axis; `tree =` triggers `ape::vcv(tree, corr = TRUE)` + the Hadfield–Nakagawa
  sparse $A^{-1}$; `vcv =` passes the correlation matrix directly); the `phylo_latent`
  covered-status row; `0 + trait` = $T$ trait-specific intercepts.
- `docs/design/03-likelihoods.md` — §"Notation" ($\mathcal N(a,b)$ takes a variance);
  §"Gaussian"; §"Phylogenetic A⁻¹ sparse integration"
  ($p(\mathbf a\mid\sigma^2_\text{phy},A)=\mathcal N(\mathbf a;\mathbf 0,\sigma^2_\text{phy}A)$
  — note this is the `phylo_scalar`-style single-variance statement, not the reduced-rank one).
- `docs/design/13-phylo-signal-partition.md` — the canonical $H^2$ numerator
  $\Sigma_\text{phy}=\Lambda_\text{phy}\Lambda_\text{phy}^\top+\operatorname{diag}(\psi_\text{phy})$
  and its reduction when the unique tier is absent; the phylo-signal literature anchors.
- `docs/design/106-va-structural-extension.md` §2 — the design-prose assertion that `phylo_*`
  levels are augmented tree nodes (cited in §8.5 as a *claim to be verified*, not as a basis
  for the specification).
- `man/gllvmTMB.Rd` §"Per-trait residual variance: when does it activate?" — one shared
  `sigma_eps` absent a per-row `indep` term.
- `CLAUDE.md` / `AGENTS.md` covariance-grid sections — source-specific latent terms are
  loadings-only by default; `phylo_latent(unique = TRUE)` is structured **plus diagonal
  $\Psi$**, not a non-phylo ordination.

**External literature:**

- Hadfield JD & Nakagawa S (2010), "General quantitative genetic methods for comparative
  biology", *J. Evol. Biol.* **23**: 494–508 — the phylogenetic mixed model with
  species-level effects of covariance $\sigma^2 A$, and the sparse node-level $A^{-1}$
  construction.
- Housworth EA, Martins EP & Lynch M (2004), "The phylogenetic mixed model", *Am. Nat.*
  **164**: 84–95 — the canonical statement that a species-level random effect has covariance
  proportional to the phylogenetic relatedness matrix, with an independent
  non-phylogenetic species effect alongside.
- Lynch M (1991), "Methods for the analysis of comparative data in evolutionary biology",
  *Evolution* **45**: 1065–1080 — the multivariate comparative model with the trait ⊗ species
  Kronecker covariance $G\otimes A$; the direct ancestor of §4.3.
- Felsenstein J (1985), "Phylogenies and the comparative method", *Am. Nat.* **125**: 1–15;
  and the pruning algorithm — the node-level BM factorisation used in §8.5.
- Freckleton RP, Harvey PH & Pagel M (2002), *Am. Nat.* **160**: 712–726; Pagel M (1999),
  *Nature* **401**: 877–884; Blomberg SP, Garland T & Ives AR (2003), *Evolution* **57**:
  717–745 — phylogenetic-signal definitions requiring a unit-diagonal $A$ (§5.4).
- Warton et al. (2015), *TREE* **30**(12); Hui et al. (2015), *MEE* **6**(4); Niku et al.
  (2019), *MEE* **10**(12) — the GLLVM formulation, the $\operatorname{Var}(z)=I$
  normalisation, the rotation indeterminacy, and the zero-upper-triangle /
  positive-diagonal resolution of it.
- McGillycuddy, Popovic, Bolker & Warton (2025), "Parsimoniously Fitting Large Multivariate
  Random Effects in glmmTMB", *JSS* **112**(1) — the `rr()` reduced-rank parameterisation the
  design prose says it adapts.
- Bollen (1989); Mulaik (2010) — classical factor analysis, rotation indeterminacy, the
  Ledermann bound.
- `dev/stan-oracle/model-spec.md` (Arc 0, same fence) — inherited ordinary-Gaussian
  structure: long-format indexing, the shared `sigma_eps` finding, the marginal-vs-hierarchical
  resolution, the constant-offset protocol.

**Not used, by design:** `src/gllvmTMB.cpp` and everything else under `src/`; `R/fit-multi.R`;
`R/eva-proto.R`; `R/aghq-gate.R`; `R/brms-sugar.R` (only its *generated* `man/*.Rd`);
`dev/stan-oracle-phylo/tmb-side-phylo.md`; `dev/stan-oracle/tmb-side.R`.

---

## 12. OPEN — must be measured or supplied

Stated as *unknowns*, not guesses. Each needs a maintainer statement or an empirical
measurement, **not** source inspection.

1. **Is the engine's phylogenetic latent block tips-only ($S$ scores per axis) or augmented
   over tree nodes ($\approx 2S-1$ per axis)?** `man/phylo_rr.Rd` says the sparse $A^{-1}$ is
   built "over tips + internal nodes", and `docs/design/106-va-structural-extension.md` §2
   asserts outright that `phylo_*` levels are augmented nodes with `n_aug_phy = nrow(Ainv)`.
   The tip-only $A^{-1}$ is generically **dense**, so sparsity essentially requires the
   augmented representation. The two representations are the same model with **different
   joint densities on sample spaces of different dimension** (§8.5). **This is the single item
   most likely to invalidate the comparison and must be answered before the check is trusted.**
   Answerable without reading `src/`: fit a toy model and read the length of the reported
   random-effect vector, or ask the maintainer.
2. **Do the `tree =` route and the `vcv =` / `A =` / `Ainv =` routes use the same latent
   dimension?** If `tree =` augments and `vcv =` stays tip-only, the oracle of §8.1 is directly
   comparable only on the dense `vcv =` route — which would be the cheapest fix for item 1, and
   is worth establishing first. Conversely, if a dense `vcv =` input is internally converted to
   an augmented representation, that conversion needs stating.
3. **Is $A$ guaranteed unit-diagonal, and are species factor levels aligned to $A$'s
   dimnames or assumed already aligned?** The `tree =` route documents `corr = TRUE`, so unit
   diagonal follows. The `vcv =` / `A =` route documents the *expectation* of a correlation
   matrix but nothing in the prose says it is checked or rescaled. Likewise the package's own
   example aligns levels by hand (`factor(..., levels = tree$tip.label)`), which suggests the
   engine may assume rather than enforce alignment. A permutation or a scale mismatch will
   look like a model error and is not one (§5).
4. **Does a free $\sigma^2_\text{phy}$ multiply $A$ for `phylo_latent`?**
   `docs/design/04-random-effects.md`'s numerical-scales table lists "Phylogenetic scaling
   ($\sigma^2_\text{phy}$), log, multiplies the sparse $A^{-1}$ precision", and
   `docs/design/03-likelihoods.md` writes the phylogenetic prior as
   $\mathcal N(\mathbf 0,\sigma^2_\text{phy}A)$. Both plausibly refer to `phylo_scalar` /
   `phylo_indep` rather than to the reduced-rank term — for `phylo_latent` such a parameter
   would be **exactly non-identified** against $\Lambda$ (§4.3, §5.1). If one is nevertheless
   present and free, the (G) block's determinant becomes parameter-dependent (§8.3), the
   parameter count in §6 is wrong, and the comparison must transport it.
5. **Storage order and orientation of $\Lambda$ and of the phylogenetic latent block.**
   Whether the reported loadings are $T\times K$ or its transpose, and whether the latent
   block is laid out species-major or axis-major. §3–§4 fix the mathematics unambiguously,
   which is all the oracle needs; any harness that *transports* fixed values must establish
   the storage order from the documented shape of `extract_Sigma()` / the loadings extractor,
   or from the maintainer.
6. **Is $K<T$ enforced for `phylo_latent()`?** The documented parse-time rejection of
   $K\ge T$ is stated for ordinary `latent()` (`docs/design/04-random-effects.md` §"Rank
   deficiency"). Whether the same gate applies on the phylogenetic path is not stated.
   Immaterial to the density; material to any recovery study.
7. **Does `phylo_latent(..., unique = FALSE)` really add no diagonal companion?** The
   documented default is loadings-only, and duplicate `unique = TRUE + phylo_unique()` is an
   error — but "no silent auto-fold on the phylo path" is an assumption the prose does not
   prove. If a $\Psi_\text{phy}$ block is present, the joint has **3** density terms, not 2,
   and the term-count tripwire of §8.1 will catch it.
8. **Does the comparison target include $-\tfrac K2\log\lvert A\rvert$?** An
   optimiser-oriented objective may legitimately drop it as parameter-free. Resolve
   empirically via the difference-of-differences protocol of §8.4, then reconcile the absolute
   offset; do not assume either way (§8.3).
9. **Is $\sigma_\varepsilon$ free (not mapped off or pinned) in this exact configuration?**
   It should be, since the model carries no per-row `indep` term (`man/gllvmTMB.Rd`), but this
   is an output-level check on the fitted object — no source reading required. Same as Arc 0
   OPEN item 6.
10. **Does the canonical `unit = cluster = species` configuration add any implicit
    species-level non-phylogenetic block?** The design prose reads `phylo_*` at
    `unit = species` as a *partition* of between-species variance rather than a separate tier
    (`docs/design/04-random-effects.md` §"Tier vs partition"), which implies no extra block is
    added — but "implies" is not "states". If an implicit ordinary species effect exists, the
    joint gains a term and $\sigma_\varepsilon$ is no longer the only non-phylogenetic
    variance (§7.4).
